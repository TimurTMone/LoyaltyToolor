class OrderItem {
  final String id;
  final String productId;
  final String productName;
  final String? productImageUrl;
  final String? size;
  final String? color;
  final int quantity;
  final double price;

  OrderItem({
    required this.id,
    required this.productId,
    required this.productName,
    this.productImageUrl,
    this.size,
    this.color,
    required this.quantity,
    required this.price,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      productName: json['product_name'] as String? ?? '',
      productImageUrl: json['product_image_url'] as String?,
      size: json['size'] as String?,
      color: json['color'] as String?,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      price: (json['price'] as num?)?.toDouble() ?? 0,
    );
  }
}

class OrderTimeline {
  final String status;
  final DateTime? timestamp;
  final String? note;

  OrderTimeline({
    required this.status,
    this.timestamp,
    this.note,
  });

  factory OrderTimeline.fromJson(Map<String, dynamic> json) {
    return OrderTimeline(
      status: json['status'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String)
          : null,
      note: json['note'] as String?,
    );
  }
}

class AppOrder {
  final String id;
  final String orderNumber;
  final String status;
  final double total;
  final double? discount;
  final int? pointsRedeemed;
  final int? pointsEarned;
  final String? paymentMethod;
  final String? deliveryType;
  final String? deliveryAddress;
  final String? pickupLocationName;
  final List<OrderItem> items;
  final List<OrderTimeline> timeline;
  final DateTime createdAt;

  AppOrder({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.total,
    this.discount,
    this.pointsRedeemed,
    this.pointsEarned,
    this.paymentMethod,
    this.deliveryType,
    this.deliveryAddress,
    this.pickupLocationName,
    this.items = const [],
    this.timeline = const [],
    required this.createdAt,
  });

  factory AppOrder.fromJson(Map<String, dynamic> json) {
    final itemsList = json['items'] as List<dynamic>? ?? [];
    final timelineList = json['timeline'] as List<dynamic>? ?? [];

    return AppOrder(
      id: json['id']?.toString() ?? '',
      orderNumber: json['order_number'] as String? ?? '',
      status: json['status'] as String? ?? 'created',
      total: (json['total'] as num?)?.toDouble() ?? 0,
      discount: (json['discount'] as num?)?.toDouble(),
      pointsRedeemed: (json['points_redeemed'] as num?)?.toInt(),
      pointsEarned: (json['points_earned'] as num?)?.toInt(),
      paymentMethod: json['payment_method'] as String?,
      deliveryType: json['delivery_type'] as String?,
      deliveryAddress: json['delivery_address'] as String?,
      pickupLocationName: json['pickup_location_name'] as String?,
      items: itemsList
          .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      timeline: timelineList
          .map((e) => OrderTimeline.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  /// Human-readable status label in Russian.
  String get statusLabel => switch (status) {
        'created' => 'Создан',
        'payment_confirmed' => 'Оплата подтверждена',
        'processing' => 'В обработке',
        'ready_for_pickup' => 'Готов к выдаче',
        'shipped' => 'Отправлен',
        'delivered' => 'Доставлен',
        'cancelled' => 'Отменён',
        _ => status,
      };
}
