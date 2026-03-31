import 'package:mixpanel_flutter/mixpanel_flutter.dart';

/// Mixpanel analytics wrapper. Call [init] once in main() before runApp().
/// All methods are safe to call even if Mixpanel fails to initialize.
class Analytics {
  Analytics._();

  static Mixpanel? _mp;

  /// Initialize with your Mixpanel project token.
  /// Pass empty string to disable tracking (dev mode).
  static Future<void> init(String token) async {
    if (token.isEmpty) return;
    try {
      _mp = await Mixpanel.init(token, trackAutomaticEvents: true);
    } catch (_) {
      // Silently fail — analytics should never crash the app
    }
  }

  /// Identify the user after login/register.
  static void identify(String userId, {String? phone, String? name, String? tier}) {
    _mp?.identify(userId);
    if (phone != null) _mp?.getPeople().set('\$phone', phone);
    if (name != null) _mp?.getPeople().set('\$name', name);
    if (tier != null) _mp?.getPeople().set('tier', tier);
  }

  /// Reset on logout.
  static void reset() {
    _mp?.reset();
  }

  // ── Event tracking ──────────────────────────────────────────────────

  static void track(String event, [Map<String, dynamic>? properties]) {
    _mp?.track(event, properties: properties);
  }

  static void screenView(String screenName) {
    track('screen_view', {'screen': screenName});
  }

  static void productView(String productId, String name, double price) {
    track('product_view', {'product_id': productId, 'product_name': name, 'price': price});
  }

  static void addToCart(String productId, String name, double price) {
    track('add_to_cart', {'product_id': productId, 'product_name': name, 'price': price});
  }

  static void purchase(String orderId, double total, int itemsCount, String paymentMethod) {
    track('purchase', {
      'order_id': orderId,
      'total': total,
      'items_count': itemsCount,
      'payment_method': paymentMethod,
    });
  }

  static void chatMessage() {
    track('chat_message_sent');
  }

  static void loyaltyQrScanned() {
    track('qr_scanned');
  }

  // ── Session & engagement ────────────────────────────────────────────
  static void appOpen() {
    track('app_open');
  }

  static void sessionStart() {
    track('session_start', {'timestamp': DateTime.now().toIso8601String()});
  }

  static void removeFromCart(String productId, String name, double price) {
    track('remove_from_cart', {'product_id': productId, 'product_name': name, 'price': price});
  }

  static void search(String query, int resultsCount) {
    track('search', {'query': query, 'results_count': resultsCount});
  }

  static void shareProduct(String productId, String name) {
    track('share_product', {'product_id': productId, 'product_name': name});
  }

  static void referralShared() {
    track('referral_shared');
  }

  static void notificationOpened(String type) {
    track('notification_opened', {'type': type});
  }
}
