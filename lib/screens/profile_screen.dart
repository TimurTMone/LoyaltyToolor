import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/theme_provider.dart';
import '../models/user.dart';
import 'auth_screen.dart';
import '../models/loyalty.dart';
import '../theme/app_theme.dart';
import '../widgets/locations_sheet.dart';
import '../services/api_service.dart';
import '../models/product.dart';
import 'edit_profile_screen.dart';
import 'notifications_screen.dart';
import 'orders_screen.dart';
import 'referral_screen.dart';

/// Profile/Loyalty screen following premium brand patterns:
/// - Stats dashboard (3 cols)
/// - QR card with tap-to-expand
/// - Tier ladder with active highlight
/// - Loyalty milestones progress
/// - Birthday reward
/// - Transaction feed
/// - Grouped menu list
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (!auth.isLoggedIn) return _loggedOut(context, auth);
        return _profile(context, auth);
      },
    );
  }

  Widget _loggedOut(BuildContext context, AuthProvider auth) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: S.x40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_outline_rounded, size: 36, color: AppColors.textTertiary),
              const SizedBox(height: S.x16),
              Text('Войдите для доступа', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              const SizedBox(height: S.x24),
              SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthScreen())), child: const Text('ВОЙТИ'))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profile(BuildContext context, AuthProvider auth) {
    final user = auth.user;
    if (user == null) return const SizedBox.shrink();
    final loyalty = auth.loyalty;
    if (loyalty == null) return const SizedBox.shrink();

    return SafeArea(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(S.x16),
              child: Column(
                children: [
                  _userRow(context, user),
                  const SizedBox(height: S.x20),
                  _birthdaySection(context, user, auth),
                  _stats(loyalty),
                  const SizedBox(height: S.x20),
                  _qrCard(context, loyalty),
                  const SizedBox(height: S.x20),
                  _milestoneCard(loyalty),
                  const SizedBox(height: S.x20),
                  _tiers(loyalty),
                  const SizedBox(height: S.x20),
                  _history(loyalty),
                  const SizedBox(height: S.x20),
                  _menu(context),
                  const SizedBox(height: S.x16),
                  GestureDetector(
                    onTap: () { HapticFeedback.lightImpact(); auth.logout(); },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: S.x12),
                      child: Text('Выйти', style: TextStyle(fontSize: 13, color: AppColors.textTertiary)),
                    ),
                  ),
                  const SizedBox(height: S.x32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _userRow(BuildContext context, AppUser user) {
    return Row(
      children: [
        Container(
          width: 50, height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [AppColors.accent, Color(0xFF7AB8F5)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(R.md),
          ),
          child: Center(child: Text(user.name.isNotEmpty ? user.name[0] : '?', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white))),
        ),
        const SizedBox(width: S.x12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              Text(user.phone, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
        ),
        // Notification bell
        Consumer<NotificationProvider>(
          builder: (context, notifProvider, _) {
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
              },
              child: Badge(
                isLabelVisible: notifProvider.unreadCount > 0,
                backgroundColor: AppColors.sale,
                label: Text(
                  '${notifProvider.unreadCount}',
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white),
                ),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(R.sm),
                  ),
                  child: Icon(Icons.notifications_outlined, size: 20, color: AppColors.textSecondary),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ── Birthday Section ──────────────────────────────────────────────

  Widget _birthdaySection(BuildContext context, AppUser user, AuthProvider auth) {
    // Birthday banner if today is user's birthday
    final now = DateTime.now();
    final isBirthday = user.birthDate != null &&
        user.birthDate!.month == now.month &&
        user.birthDate!.day == now.day;

    if (isBirthday) {
      return Padding(
        padding: const EdgeInsets.only(bottom: S.x20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(S.x16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.pinkAccent.withValues(alpha: 0.15), Colors.purpleAccent.withValues(alpha: 0.08)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(R.lg),
            border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Text('\u{1F382}', style: TextStyle(fontSize: 28)),
              const SizedBox(width: S.x12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('С Днём рождения!', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    Text('Проверьте бонусные баллы в подарок', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Birthday prompt if not set
    if (user.birthDate == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: S.x20),
        child: GestureDetector(
          onTap: () => _pickBirthday(context, auth),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(S.x16),
            decoration: BoxDecoration(
              color: AppColors.goldSoft,
              borderRadius: BorderRadius.circular(R.lg),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Icon(Icons.cake_rounded, size: 24, color: AppColors.gold),
                const SizedBox(width: S.x12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Укажите дату рождения', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      Text('и получите 1000 баллов!', style: TextStyle(fontSize: 12, color: AppColors.gold)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textTertiary),
              ],
            ),
          ),
        ),
      );
    }

    // Birthday is set — show it in a compact row
    final fmt = DateFormat('dd MMMM yyyy', 'ru');
    return Padding(
      padding: const EdgeInsets.only(bottom: S.x20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: S.x16, vertical: S.x12),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(R.md),
        ),
        child: Row(
          children: [
            Icon(Icons.cake_outlined, size: 18, color: AppColors.textTertiary),
            const SizedBox(width: S.x8),
            Text('Дата рождения: ', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            Text(fmt.format(user.birthDate!), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }

  void _pickBirthday(BuildContext context, AuthProvider auth) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1940),
      lastDate: now,
      helpText: 'ДАТА РОЖДЕНИЯ',
      cancelText: 'ОТМЕНА',
      confirmText: 'СОХРАНИТЬ',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.accent,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(picked);
      await ApiService.dio.patch(
        '/api/v1/users/me/birthday',
        data: {'birth_date': dateStr},
      );
      // Refresh profile to get the updated birthDate
      await auth.fetchProfile();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Дата рождения сохранена! +1000 баллов')),
        );
        // Also refresh loyalty to see updated points
        auth.fetchLoyalty();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось сохранить дату рождения')),
        );
      }
    }
  }

  Widget _stats(LoyaltyAccount l) {
    return Row(
      children: [
        _stat('${l.points}', 'БАЛЛОВ', AppColors.accent),
        const SizedBox(width: S.x8),
        _stat('${l.cashbackPercent}%', 'КЭШБЭК', AppColors.gold),
        const SizedBox(width: S.x8),
        _stat('${(l.totalSpent / 1000).toStringAsFixed(0)}K', 'ПОТРАЧЕНО', AppColors.textSecondary),
      ],
    );
  }

  Widget _stat(String value, String label, Color c) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: S.x16),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(R.md),
          border: Border.all(color: c.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c)),
            const SizedBox(height: S.x4),
            Text(label, style: TextStyle(fontSize: 9, color: AppColors.textTertiary, letterSpacing: 1, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _qrCard(BuildContext context, LoyaltyAccount l) {
    final auth = context.watch<AuthProvider>();
    final qrData = auth.qrToken ?? l.qrCode;
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); _showQR(context, l); },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: S.x24),
        decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(R.lg)),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('НАЖМИТЕ ДЛЯ УВЕЛИЧЕНИЯ', style: TextStyle(fontSize: 9, letterSpacing: 1.5, color: AppColors.textTertiary, fontWeight: FontWeight.w500)),
                const SizedBox(width: S.x8),
                _ProfileQrPulseIndicator(),
              ],
            ),
            const SizedBox(height: S.x16),
            Container(
              padding: const EdgeInsets.all(S.x8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(R.md)),
              child: auth.qrToken != null
                  ? QrImageView(data: qrData, version: QrVersions.auto, size: 140, backgroundColor: Colors.white)
                  : const SizedBox(width: 140, height: 140, child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)))),
            ),
            const SizedBox(height: S.x12),
            Text(
              auth.qrToken != null ? 'QR обновляется автоматически' : 'Загрузка...',
              style: TextStyle(fontSize: 11, color: AppColors.textTertiary, letterSpacing: 1.5, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  void _showQR(BuildContext context, LoyaltyAccount l) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Consumer<AuthProvider>(
        builder: (ctx, auth, _) {
          final qrData = auth.qrToken ?? l.qrCode;
          return Container(
            margin: const EdgeInsets.fromLTRB(S.x16, 0, S.x16, S.x16),
            padding: const EdgeInsets.symmetric(horizontal: S.x32, vertical: S.x32),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(R.xl)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('ПОКАЖИТЕ НА КАССЕ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 2, color: AppColors.textSecondary)),
                    const SizedBox(width: S.x8),
                    _ProfileQrPulseIndicator(),
                  ],
                ),
                const SizedBox(height: S.x24),
                Container(
                  padding: const EdgeInsets.all(S.x16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(R.lg)),
                  child: auth.qrToken != null
                      ? QrImageView(data: qrData, version: QrVersions.auto, size: 220, backgroundColor: Colors.white)
                      : const SizedBox(width: 220, height: 220, child: Center(child: CircularProgressIndicator())),
                ),
                const SizedBox(height: S.x16),
                Text(
                  auth.qrToken != null ? 'QR обновляется автоматически' : 'Загрузка...',
                  style: TextStyle(fontSize: 13, color: AppColors.textTertiary, letterSpacing: 2, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Loyalty Milestones ───────────────────────────────────────────

  Widget _milestoneCard(LoyaltyAccount l) {
    final (Color tierColor, String tierLabel) = _tierInfo(l.tier);
    final nextTierLabel = _nextTierName(l.tier);
    final nextTierColor = _nextTierColor(l.tier);
    final remaining = l.nextTierThreshold - l.totalSpent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(S.x16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(R.md),
        border: Border.all(color: tierColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('ПРОГРЕСС УРОВНЯ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.5, color: AppColors.textTertiary)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: S.x8, vertical: S.x2),
                decoration: BoxDecoration(
                  color: tierColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded, size: 12, color: tierColor),
                    const SizedBox(width: S.x4),
                    Text(tierLabel.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: tierColor, letterSpacing: 0.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: S.x16),
          if (l.tier != LoyaltyTier.platinum) ...[
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: l.progressToNextTier.clamp(0.0, 1.0),
                backgroundColor: AppColors.surfaceBright,
                valueColor: AlwaysStoppedAnimation(nextTierColor),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: S.x12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.star_rounded, size: 14, color: tierColor),
                    const SizedBox(width: S.x4),
                    Text(tierLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tierColor)),
                  ],
                ),
                Row(
                  children: [
                    Text(nextTierLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: nextTierColor)),
                    const SizedBox(width: S.x4),
                    Icon(Icons.star_rounded, size: 14, color: nextTierColor),
                  ],
                ),
              ],
            ),
            const SizedBox(height: S.x8),
            Text(
              'До уровня $nextTierLabel осталось ${Product.formatPrice(remaining)} сом',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ] else ...[
            // Platinum — max level
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded, size: 20, color: AppColors.platinum),
                const SizedBox(width: S.x8),
                Expanded(
                  child: Text('Максимальный уровень достигнут!', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.platinum)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  (Color, String) _tierInfo(LoyaltyTier tier) => switch (tier) {
    LoyaltyTier.bronze => (AppColors.bronze, 'Bronze'),
    LoyaltyTier.silver => (AppColors.silver, 'Silver'),
    LoyaltyTier.gold => (AppColors.goldTier, 'Gold'),
    LoyaltyTier.platinum => (AppColors.platinum, 'Platinum'),
  };

  String _nextTierName(LoyaltyTier tier) => switch (tier) {
    LoyaltyTier.bronze => 'Silver',
    LoyaltyTier.silver => 'Gold',
    LoyaltyTier.gold => 'Platinum',
    LoyaltyTier.platinum => 'Platinum',
  };

  Color _nextTierColor(LoyaltyTier tier) => switch (tier) {
    LoyaltyTier.bronze => AppColors.silver,
    LoyaltyTier.silver => AppColors.goldTier,
    LoyaltyTier.gold => AppColors.platinum,
    LoyaltyTier.platinum => AppColors.platinum,
  };

  Widget _tiers(LoyaltyAccount l) {
    final tiers = [
      ('BRONZE', '3%', '0', LoyaltyTier.bronze, AppColors.bronze),
      ('SILVER', '5%', '50K', LoyaltyTier.silver, AppColors.silver),
      ('GOLD', '8%', '150K', LoyaltyTier.gold, AppColors.goldTier),
      ('PLATINUM', '12%', '300K', LoyaltyTier.platinum, AppColors.platinum),
    ];

    return Container(
      padding: const EdgeInsets.all(S.x16),
      decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(R.md)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('УРОВНИ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.5, color: AppColors.textTertiary)),
          const SizedBox(height: S.x12),
          ...tiers.map((t) {
            final active = t.$4 == l.tier;
            final c = t.$5;
            return Container(
              margin: const EdgeInsets.only(bottom: S.x6),
              padding: const EdgeInsets.symmetric(horizontal: S.x12, vertical: S.x8),
              decoration: BoxDecoration(
                color: active ? c.withValues(alpha: 0.08) : Colors.transparent,
                borderRadius: BorderRadius.circular(R.sm),
                border: active ? Border.all(color: c.withValues(alpha: 0.2)) : null,
              ),
              child: Row(
                children: [
                  Icon(active ? Icons.star_rounded : Icons.star_border_rounded, size: 16, color: c),
                  const SizedBox(width: S.x8),
                  Expanded(child: Text(t.$1, style: TextStyle(fontSize: 12, fontWeight: active ? FontWeight.w600 : FontWeight.w400, color: active ? c : AppColors.textSecondary, letterSpacing: 0.5))),
                  Text(t.$2, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: active ? c : AppColors.textTertiary)),
                  const SizedBox(width: S.x12),
                  Text('от ${t.$3}', style: TextStyle(fontSize: 10, color: active ? c.withValues(alpha: 0.5) : AppColors.textTertiary)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _history(LoyaltyAccount l) {
    final fmt = DateFormat('dd.MM.yyyy');
    return Container(
      padding: const EdgeInsets.all(S.x16),
      decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(R.md)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ИСТОРИЯ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.5, color: AppColors.textTertiary)),
          const SizedBox(height: S.x12),
          ...l.transactions.map((tx) {
            final (IconData ic, Color c) = switch (tx.type) {
              TransactionType.purchase => (Icons.shopping_bag_rounded, AppColors.accent),
              TransactionType.pointsRedeemed => (Icons.redeem_rounded, AppColors.sale),
              TransactionType.bonus => (Icons.card_giftcard_rounded, AppColors.gold),
              TransactionType.referral => (Icons.people_rounded, Colors.blueAccent),
            };
            return Padding(
              padding: const EdgeInsets.only(bottom: S.x12),
              child: Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(R.sm)),
                    child: Icon(ic, size: 14, color: c),
                  ),
                  const SizedBox(width: S.x12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tx.description, style: TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                        Text(fmt.format(tx.date), style: TextStyle(fontSize: 10, color: AppColors.textTertiary)),
                      ],
                    ),
                  ),
                  Text(
                    '${tx.pointsEarned > 0 ? '+' : ''}${tx.pointsEarned}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tx.pointsEarned >= 0 ? AppColors.accent : AppColors.sale),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _menu(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(R.md)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _menuRow(Icons.edit_outlined, 'Редактировать профиль', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
          }),
          _div(),
          _menuRow(Icons.favorite_outline_rounded, 'Избранное', () => _showFav(context)),
          _div(),
          _menuRow(Icons.receipt_long_outlined, 'Мои заказы', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen()));
          }),
          _div(),
          _menuRow(Icons.card_giftcard_rounded, 'Пригласить друга', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ReferralScreen()));
          }),
          _div(), _menuRow(Icons.card_giftcard_rounded, 'Box подписка', () => _showBox(context)),
          _div(), _menuRow(Icons.local_offer_outlined, 'Промокоды', () {}),
          _div(), _menuRow(Icons.location_on_outlined, 'Наши точки', () => showLocationsSheet(context)),
          _div(), _menuRow(Icons.notifications_outlined, 'Уведомления', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
          }),
          _div(), _menuRow(Icons.info_outline_rounded, 'О Toolor', () => _showAbout(context)),
          _div(), _menuRow(Icons.brightness_6_outlined, 'Тема оформления', () => _showThemePicker(context)),
        ],
      ),
    );
  }

  Widget _menuRow(IconData icon, String title, VoidCallback onTap) {
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: S.x16, vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: S.x12),
            Expanded(child: Text(title, style: TextStyle(fontSize: 13, color: AppColors.textPrimary))),
            Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _div() => Padding(padding: const EdgeInsets.symmetric(horizontal: S.x16), child: Divider(color: AppColors.divider, height: 0.5));

  // ── Bottom Sheets ──────────────────────────────────────────────

  void _showFav(BuildContext context) {
    final favs = context.read<FavoritesProvider>().favorites;
    _sheet(context, 'ИЗБРАННОЕ (${favs.length})', favs.isEmpty
        ? Center(child: Text('Пусто', style: TextStyle(color: AppColors.textTertiary)))
        : ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: S.x20),
            itemCount: favs.length,
            separatorBuilder: (_, _) => Divider(color: AppColors.divider, height: 1),
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: S.x12),
              child: Row(
                children: [
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(favs[i].name, style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                      Text(favs[i].formattedPrice, style: TextStyle(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.w600)),
                    ],
                  )),
                  Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textTertiary),
                ],
              ),
            ),
          ),
    );
  }

  void _showBox(BuildContext context) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.fromLTRB(S.x16, 0, S.x16, S.x16),
        padding: const EdgeInsets.all(S.x24),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(R.xl)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('TOOLOR BOX', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 2, color: AppColors.textPrimary)),
            const SizedBox(height: S.x8),
            Text('Стилисты подберут комплект\nиз 3\u20135 вещей каждый месяц', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
            const SizedBox(height: S.x20),
            Row(children: [_boxCard('Basic', '4 990', '3 вещи'), const SizedBox(width: S.x12), _boxCard('Premium', '8 990', '5 вещей')]),
            const SizedBox(height: S.x20),
            SizedBox(width: double.infinity, height: 50, child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('СКОРО'))),
          ],
        ),
      ),
    );
  }

  Widget _boxCard(String name, String price, String desc) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(S.x16),
      decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(R.md), border: Border.all(color: AppColors.gold.withValues(alpha: 0.15))),
      child: Column(children: [
        Text(name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.gold, letterSpacing: 0.5)),
        const SizedBox(height: S.x4),
        Text('$price сом', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        Text(desc, style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
      ]),
    ));
  }

  void _showAbout(BuildContext context) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(S.x16, 0, S.x16, S.x16),
        padding: const EdgeInsets.all(S.x24),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(R.xl)),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Text('TOOLOR', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 6, color: AppColors.textPrimary))),
          const SizedBox(height: S.x16),
          Text('Международный бренд функциональной верхней одежды, вдохновленный эстетикой digital-номадов.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
          const SizedBox(height: S.x16),
          _aboutRow(Icons.location_on_outlined, 'AsiaMall, 2 этаж, бутик 19(1)'),
          const SizedBox(height: S.x8),
          _aboutRow(Icons.phone_outlined, '+996 998 844 444'),
          const SizedBox(height: S.x8),
          _aboutRow(Icons.language_rounded, 'toolorkg.com'),
          const SizedBox(height: S.x16),
          Center(child: Text('v1.0.0', style: TextStyle(fontSize: 11, color: AppColors.textTertiary))),
        ]),
      ),
    );
  }

  Widget _aboutRow(IconData ic, String t) => Row(children: [Icon(ic, size: 16, color: AppColors.textTertiary), const SizedBox(width: S.x8), Text(t, style: TextStyle(fontSize: 13, color: AppColors.textSecondary))]);

  void _showThemePicker(BuildContext context) {
    final themeProv = context.read<ThemeProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final options = [
          (ThemePreference.system, 'Авто (по системе)', Icons.brightness_auto_outlined),
          (ThemePreference.light, 'Светлая', Icons.light_mode_outlined),
          (ThemePreference.dark, 'Тёмная', Icons.dark_mode_outlined),
        ];
        return StatefulBuilder(
          builder: (ctx, setSheetState) => Container(
            margin: const EdgeInsets.fromLTRB(S.x16, 0, S.x16, S.x16),
            padding: const EdgeInsets.all(S.x24),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(R.xl)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('ТЕМА ОФОРМЛЕНИЯ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.5, color: AppColors.textSecondary)),
                const SizedBox(height: S.x16),
                ...options.map((o) {
                  final active = themeProv.pref == o.$1;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      themeProv.set(o.$1);
                      setSheetState(() {});
                      Navigator.pop(ctx);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: S.x12),
                      child: Row(
                        children: [
                          Icon(o.$3, size: 20, color: active ? AppColors.accent : AppColors.textSecondary),
                          const SizedBox(width: S.x12),
                          Expanded(child: Text(o.$2, style: TextStyle(fontSize: 14, color: active ? AppColors.accent : AppColors.textPrimary, fontWeight: active ? FontWeight.w600 : FontWeight.w400))),
                          if (active) Icon(Icons.check_rounded, size: 18, color: AppColors.accent),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _sheet(BuildContext context, String title, Widget body) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.55,
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(R.xl))),
        child: Column(children: [
          const SizedBox(height: S.x12),
          Container(width: 32, height: 3, decoration: BoxDecoration(color: AppColors.surfaceBright, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: S.x16),
          Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.5, color: AppColors.textSecondary)),
          const SizedBox(height: S.x16),
          Expanded(child: body),
        ]),
      ),
    );
  }
}

/// A small pulsing dot that indicates the QR code is live/rotating.
class _ProfileQrPulseIndicator extends StatefulWidget {
  @override
  State<_ProfileQrPulseIndicator> createState() =>
      _ProfileQrPulseIndicatorState();
}

class _ProfileQrPulseIndicatorState extends State<_ProfileQrPulseIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            'LIVE',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: Colors.green,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
