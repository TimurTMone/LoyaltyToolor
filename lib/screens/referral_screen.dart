import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  String? _referralCode;
  int _totalReferrals = 0;
  int _totalPointsEarned = 0;
  List<Map<String, dynamic>> _referredFriends = [];
  bool _isLoading = true;
  final _codeController = TextEditingController();
  bool _isApplying = false;

  @override
  void initState() {
    super.initState();
    _fetchReferralData();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _fetchReferralData() async {
    setState(() => _isLoading = true);

    try {
      final codeResponse =
          await ApiService.dio.get('/api/v1/referrals/my-code');
      final codeData = codeResponse.data as Map<String, dynamic>;
      _referralCode = codeData['code'] as String? ?? '';

      final referralsResponse =
          await ApiService.dio.get('/api/v1/referrals/my-referrals');
      final referralsData = referralsResponse.data as Map<String, dynamic>;
      _totalReferrals =
          (referralsData['total_referrals'] as num?)?.toInt() ?? 0;
      _totalPointsEarned =
          (referralsData['total_points_earned'] as num?)?.toInt() ?? 0;
      final friends = referralsData['referrals'] as List<dynamic>? ?? [];
      _referredFriends = friends
          .map((e) => e as Map<String, dynamic>)
          .toList();
    } catch (e) {
      debugPrint('[ReferralScreen] fetch error: $e');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _applyCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() => _isApplying = true);

    try {
      await ApiService.dio
          .post('/api/v1/referrals/apply', data: {'referral_code': code});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Код "$code" успешно применён!')),
      );
      _codeController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось применить код')),
      );
    }

    if (mounted) setState(() => _isApplying = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Пригласить друга')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(S.x16),
                child: Column(
                  children: [
                    _codeCard(),
                    const SizedBox(height: S.x20),
                    _statsRow(),
                    const SizedBox(height: S.x20),
                    _shareButton(),
                    const SizedBox(height: S.x24),
                    _applyCodeSection(),
                    if (_referredFriends.isNotEmpty) ...[
                      const SizedBox(height: S.x24),
                      _friendsList(),
                    ],
                    const SizedBox(height: S.x32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _codeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(S.x24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accent.withValues(alpha: 0.12),
            AppColors.accent.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(R.lg),
        border:
            Border.all(color: AppColors.accent.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Icon(Icons.card_giftcard_rounded,
              size: 36, color: AppColors.accent),
          const SizedBox(height: S.x12),
          Text('ВАШ РЕФЕРАЛЬНЫЙ КОД',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: AppColors.textTertiary)),
          const SizedBox(height: S.x12),
          GestureDetector(
            onTap: () {
              if (_referralCode != null) {
                Clipboard.setData(ClipboardData(text: _referralCode!));
                HapticFeedback.lightImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Код скопирован')),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: S.x20, vertical: S.x12),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(R.md),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _referralCode ?? '...',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accent,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(width: S.x12),
                  Icon(Icons.copy_rounded,
                      size: 18, color: AppColors.textTertiary),
                ],
              ),
            ),
          ),
          const SizedBox(height: S.x8),
          Text('Нажмите чтобы скопировать',
              style: TextStyle(
                  fontSize: 11, color: AppColors.textTertiary)),
        ],
      ),
    );
  }

  Widget _statsRow() {
    return Row(
      children: [
        _statCard('$_totalReferrals', 'ПРИГЛАШЕНО'),
        const SizedBox(width: S.x12),
        _statCard('$_totalPointsEarned', 'БАЛЛОВ ПОЛУЧЕНО'),
      ],
    );
  }

  Widget _statCard(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: S.x16),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(R.md),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            const SizedBox(height: S.x4),
            Text(label,
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1,
                    color: AppColors.textTertiary)),
          ],
        ),
      ),
    );
  }

  Widget _shareButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: () {
          HapticFeedback.mediumImpact();
          SharePlus.instance.share(ShareParams(
            text:
                'Используй мой код ${_referralCode ?? ''} в TOOLOR и получи 500 баллов!\n\ntoolorkg.com',
          ));
        },
        icon: const Icon(Icons.share_rounded, size: 18),
        label: const Text('ПОДЕЛИТЬСЯ'),
      ),
    );
  }

  Widget _applyCodeSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(S.x16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(R.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ВВЕСТИ КОД ДРУГА',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: AppColors.textTertiary)),
          const SizedBox(height: S.x12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeController,
                  style: TextStyle(
                      fontSize: 14, color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Введите реферальный код',
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
              ),
              const SizedBox(width: S.x12),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isApplying ? null : _applyCode,
                  child: _isApplying
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('ОК'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _friendsList() {
    final fmt = DateFormat('dd.MM.yyyy');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(S.x16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(R.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ПРИГЛАШЁННЫЕ ДРУЗЬЯ',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: AppColors.textTertiary)),
          const SizedBox(height: S.x12),
          ..._referredFriends.map((friend) {
            final name =
                friend['name'] as String? ?? friend['full_name'] as String? ?? 'Друг';
            final date =
                DateTime.tryParse(friend['created_at'] as String? ?? '');
            return Padding(
              padding: const EdgeInsets.only(bottom: S.x12),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(R.sm),
                    ),
                    child: Center(
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.blueAccent),
                      ),
                    ),
                  ),
                  const SizedBox(width: S.x12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textPrimary)),
                        if (date != null)
                          Text(fmt.format(date),
                              style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textTertiary)),
                      ],
                    ),
                  ),
                  Icon(Icons.check_circle_rounded,
                      size: 16, color: Colors.green.withValues(alpha: 0.7)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
