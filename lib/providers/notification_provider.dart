import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/app_notification.dart';
import '../services/api_service.dart';

class NotificationProvider extends ChangeNotifier {
  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  Timer? _pollTimer;

  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;

  /// Start polling unread count every 30 seconds.
  void startPolling() {
    stopPolling();
    fetchUnreadCount();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => fetchUnreadCount(),
    );
  }

  /// Stop the periodic poll timer.
  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// GET /api/v1/notifications
  Future<void> fetchNotifications() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await ApiService.dio.get('/api/v1/notifications');
      final data = response.data;
      final List<dynamic> items =
          data is List ? data : (data['items'] as List? ?? []);
      _notifications = items
          .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
          .toList();
      _unreadCount = _notifications.where((n) => !n.read).length;
    } catch (e) {
      debugPrint('[NotificationProvider] fetchNotifications error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// GET /api/v1/notifications/unread-count
  Future<void> fetchUnreadCount() async {
    try {
      final loggedIn = await ApiService.isLoggedIn();
      if (!loggedIn) return;

      final response =
          await ApiService.dio.get('/api/v1/notifications/unread-count');
      final data = response.data as Map<String, dynamic>;
      _unreadCount = (data['count'] as num?)?.toInt() ?? 0;
      notifyListeners();
    } catch (e) {
      debugPrint('[NotificationProvider] fetchUnreadCount error: $e');
    }
  }

  /// PATCH /api/v1/notifications/{id}/read
  Future<void> markAsRead(String id) async {
    // Optimistic update
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx >= 0 && !_notifications[idx].read) {
      _notifications[idx] = _notifications[idx].copyWith(read: true);
      _unreadCount = (_unreadCount - 1).clamp(0, _unreadCount);
      notifyListeners();
    }

    try {
      await ApiService.dio.patch('/api/v1/notifications/$id/read');
    } catch (e) {
      debugPrint('[NotificationProvider] markAsRead error: $e');
      // Revert on failure
      if (idx >= 0) {
        _notifications[idx] = _notifications[idx].copyWith(read: false);
        _unreadCount++;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
