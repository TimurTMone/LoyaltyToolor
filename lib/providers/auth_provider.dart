import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../models/loyalty.dart';
import '../services/api_service.dart';
import '../services/analytics_service.dart';

class AuthProvider extends ChangeNotifier {
  AppUser? _user;
  LoyaltyAccount? _loyalty;
  bool _isLoggedIn = false;
  bool _isLoading = false;
  String? _error;

  // ── Rotating QR token ─────────────────────────────────────────────────
  String? _qrToken;
  Timer? _qrRefreshTimer;

  AppUser? get user => _user;
  LoyaltyAccount? get loyalty => _loyalty;
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get qrToken => _qrToken;

  // ── Real auth ─────────────────────────────────────────────────────────

  /// Login with phone + password via FastAPI backend.
  Future<void> login(String phone, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await ApiService.login(phone, password);
    } catch (e) {
      _error = 'Ошибка входа: $e';
      _isLoggedIn = false;
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      await fetchProfile();
    } catch (e) {
      _error = 'Ошибка профиля: $e';
      _isLoggedIn = false;
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      await fetchLoyalty();
    } catch (e) {
      // Non-fatal — continue login even if loyalty fails
      debugPrint('[AuthProvider] fetchLoyalty error: $e');
    }

    _isLoggedIn = true;
    startQrRefresh();
    if (_user != null) {
      Analytics.identify(_user!.id, phone: _user!.phone, name: _user!.name, tier: _loyalty?.tierName);
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Register a new account, then auto-login.
  Future<void> register(String phone, String password, String name,
      {String? referralCode}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await ApiService.dio.post(
        '/api/v1/auth/register',
        data: {
          'phone': phone,
          'password': password,
          'full_name': name,
          if (referralCode != null) 'referral_code': referralCode,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final access = data['access_token'] as String?;
      final refresh = data['refresh_token'] as String?;

      if (access != null && refresh != null) {
        await ApiService.setTokens(access, refresh);
      }
    } catch (e) {
      _error = 'Ошибка регистрации: $e';
      _isLoggedIn = false;
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      await fetchProfile();
    } catch (e) {
      _error = 'Ошибка профиля: $e';
      _isLoggedIn = false;
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      await fetchLoyalty();
    } catch (e) {
      debugPrint('[AuthProvider] fetchLoyalty error: $e');
    }

    _isLoggedIn = true;
    startQrRefresh();
    if (_user != null) {
      Analytics.identify(_user!.id, phone: _user!.phone, name: _user!.name, tier: _loyalty?.tierName);
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Fetch user profile from GET /api/v1/users/me.
  Future<void> fetchProfile() async {
    try {
      final response = await ApiService.dio.get('/api/v1/users/me');
      final data = response.data as Map<String, dynamic>;
      _user = AppUser.fromJson(data);
    } catch (e) {
      debugPrint('[AuthProvider] fetchProfile error: $e');
      rethrow;
    }
  }

  /// Fetch loyalty account from GET /api/v1/loyalty/me.
  Future<void> fetchLoyalty() async {
    try {
      final response = await ApiService.dio.get('/api/v1/loyalty/me');
      final data = response.data as Map<String, dynamic>;
      _loyalty = LoyaltyAccount.fromJson(data);

      // Also fetch transactions and attach them
      try {
        final txnResponse =
            await ApiService.dio.get('/api/v1/loyalty/me/transactions');
        final txnData = txnResponse.data as Map<String, dynamic>;
        final items = txnData['items'] as List<dynamic>? ?? [];
        final transactions = items
            .map((t) =>
                LoyaltyTransaction.fromJson(t as Map<String, dynamic>))
            .toList();

        // Rebuild loyalty with transactions
        _loyalty = LoyaltyAccount(
          id: _loyalty!.id,
          qrCode: _loyalty!.qrCode,
          tier: _loyalty!.tier,
          points: _loyalty!.points,
          totalSpent: _loyalty!.totalSpent,
          transactions: transactions,
        );
      } catch (e) {
        debugPrint('[AuthProvider] fetchLoyalty transactions error: $e');
        // Non-fatal: loyalty account still available without transactions
      }
    } catch (e) {
      debugPrint('[AuthProvider] fetchLoyalty error: $e');
      // Non-fatal during login — loyalty is secondary
    }
  }

  // ── Rotating QR token methods ──────────────────────────────────────────

  /// Fetch a signed, rotating QR token from GET /api/v1/loyalty/me/qr.
  /// Falls back to loyalty.qrCode on failure.
  Future<void> fetchQrToken() async {
    try {
      final response = await ApiService.dio.get('/api/v1/loyalty/me/qr');
      final data = response.data as Map<String, dynamic>;
      _qrToken = data['qr_token'] as String?;
      notifyListeners();
    } catch (e) {
      debugPrint('[AuthProvider] fetchQrToken error: $e');
      // Fallback: use the static loyalty QR code if the rotating endpoint fails
      if (_qrToken == null && _loyalty != null) {
        _qrToken = _loyalty!.qrCode;
        notifyListeners();
      }
    }
  }

  /// Start periodic QR token refresh every 25 seconds (before the 30s expiry).
  void startQrRefresh() {
    stopQrRefresh();
    // Fetch immediately, then repeat every 25 seconds
    fetchQrToken();
    _qrRefreshTimer = Timer.periodic(
      const Duration(seconds: 25),
      (_) => fetchQrToken(),
    );
  }

  /// Cancel the QR refresh timer.
  void stopQrRefresh() {
    _qrRefreshTimer?.cancel();
    _qrRefreshTimer = null;
  }

  /// Try to restore session from stored tokens on app start.
  Future<void> tryRestoreSession() async {
    _isLoading = true;
    notifyListeners();

    try {
      final loggedIn = await ApiService.isLoggedIn();
      if (loggedIn) {
        await fetchProfile();
        await fetchLoyalty();
        _isLoggedIn = true;
        startQrRefresh();
      }
    } catch (e) {
      debugPrint('[AuthProvider] tryRestoreSession error: $e');
      // Token may be expired / invalid — clear and stay logged out
      await ApiService.logout();
      _isLoggedIn = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Demo fallback ─────────────────────────────────────────────────────

  /// Demo login for MVP — uses hardcoded data. Prefer login() for real auth.
  void demoLogin() {
    debugPrint(
        '[AuthProvider] WARNING: demoLogin() used — this is a fallback with '
        'fake data. Use login(phone, password) for real authentication.');

    _user = AppUser(
      id: 'usr_001',
      name: 'Алия Садыкова',
      phone: '+996 555 123 456',
      email: 'aliya@example.com',
      birthDate: DateTime(1995, 6, 15),
    );

    _loyalty = LoyaltyAccount(
      id: 'loy_001',
      qrCode: 'TOOLOR-USR001-2026',
      tier: LoyaltyTier.silver,
      points: 2450,
      totalSpent: 78500,
      transactions: [
        LoyaltyTransaction(
          id: 'txn_001',
          date: DateTime(2026, 3, 20),
          amount: 8990,
          pointsEarned: 450,
          description: 'Куртка женская TOOLOR Wind',
          type: TransactionType.purchase,
        ),
        LoyaltyTransaction(
          id: 'txn_002',
          date: DateTime(2026, 3, 15),
          amount: 5490,
          pointsEarned: 275,
          description: 'Худи мужская TOOLOR Urban',
          type: TransactionType.purchase,
        ),
        LoyaltyTransaction(
          id: 'txn_003',
          date: DateTime(2026, 3, 10),
          amount: 3990,
          pointsEarned: 200,
          description: 'Футболка женская TOOLOR Basic',
          type: TransactionType.purchase,
        ),
        LoyaltyTransaction(
          id: 'txn_004',
          date: DateTime(2026, 3, 5),
          amount: 0,
          pointsEarned: 500,
          description: 'Бонус за регистрацию',
          type: TransactionType.bonus,
        ),
        LoyaltyTransaction(
          id: 'txn_005',
          date: DateTime(2026, 2, 28),
          amount: 12990,
          pointsEarned: 650,
          description: 'Пуховик TOOLOR Nomad',
          type: TransactionType.purchase,
        ),
        LoyaltyTransaction(
          id: 'txn_006',
          date: DateTime(2026, 2, 20),
          amount: -1500,
          pointsEarned: -300,
          description: 'Списание баллов',
          type: TransactionType.pointsRedeemed,
        ),
        LoyaltyTransaction(
          id: 'txn_007',
          date: DateTime(2026, 2, 14),
          amount: 0,
          pointsEarned: 200,
          description: 'Реферальный бонус',
          type: TransactionType.referral,
        ),
      ],
    );

    _isLoggedIn = true;
    _error = null;
    startQrRefresh();
    notifyListeners();
  }

  // ── Logout ────────────────────────────────────────────────────────────

  Future<void> logout() async {
    stopQrRefresh();
    try {
      await ApiService.logout();
    } catch (e) {
      debugPrint('[AuthProvider] logout error: $e');
    }
    Analytics.reset();
    _user = null;
    _loyalty = null;
    _qrToken = null;
    _isLoggedIn = false;
    _error = null;
    notifyListeners();
  }

  /// Clear the current error message.
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  String _extractErrorMessage(dynamic e) {
    if (e is Exception) {
      // Try to extract backend detail from DioException
      try {
        final dynamic err = e;
        final response = err.response;
        if (response != null && response.data is Map) {
          final detail = response.data['detail'];
          if (detail is String) return detail;
        }
      } catch (_) {}
    }
    return e.toString();
  }
}
