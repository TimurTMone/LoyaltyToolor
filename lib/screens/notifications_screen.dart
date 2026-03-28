import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';
import '../models/app_notification.dart';
import '../theme/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<NotificationProvider>().fetchNotifications();
  }

  Future<void> _refresh() async {
    await context.read<NotificationProvider>().fetchNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Уведомления')),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.notifications.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.notifications.isEmpty) {
            return _emptyState();
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            color: AppColors.accent,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.symmetric(
                  horizontal: S.x16, vertical: S.x12),
              itemCount: provider.notifications.length,
              separatorBuilder: (_, _) => const SizedBox(height: S.x8),
              itemBuilder: (_, i) => _NotificationTile(
                notification: provider.notifications[i],
                onTap: () {
                  HapticFeedback.selectionClick();
                  provider.markAsRead(provider.notifications[i].id);
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_rounded,
              size: 48, color: AppColors.textTertiary),
          const SizedBox(height: S.x16),
          Text('Нет уведомлений',
              style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: S.x4),
          Text('Здесь появятся новые сообщения',
              style: TextStyle(fontSize: 13, color: AppColors.textTertiary)),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd.MM.yyyy HH:mm');
    final (IconData icon, Color color) = _iconForType(notification.type);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(S.x16),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(R.md),
          border: !notification.read
              ? Border.all(color: AppColors.accent.withValues(alpha: 0.2))
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(R.sm),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: S.x12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: notification.read
                                ? FontWeight.w400
                                : FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (!notification.read)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: S.x4),
                  Text(
                    notification.body,
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: S.x4),
                  Text(
                    fmt.format(notification.createdAt),
                    style: TextStyle(
                        fontSize: 10, color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  (IconData, Color) _iconForType(String type) => switch (type) {
        'order' => (Icons.shopping_bag_rounded, AppColors.accent),
        'promo' => (Icons.local_offer_rounded, AppColors.gold),
        'loyalty' => (Icons.star_rounded, AppColors.goldTier),
        'referral' => (Icons.people_rounded, Colors.blueAccent),
        'birthday' => (Icons.cake_rounded, Colors.pinkAccent),
        _ => (Icons.notifications_rounded, AppColors.accent),
      };
}
