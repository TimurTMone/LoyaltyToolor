import '../services/api_service.dart' show apiBaseUrl;

class Product {
  final String id;
  final String name;
  final double price;
  final double? originalPrice;
  final String imageUrl;
  final String category;
  final String subcategory;
  final String description;
  final List<String> sizes;
  final List<String> colors;
  final int? stock; // null = no scarcity shown

  Product({
    required this.id,
    required this.name,
    required this.price,
    this.originalPrice,
    required this.imageUrl,
    required this.category,
    required this.subcategory,
    required this.description,
    required this.sizes,
    required this.colors,
    this.stock,
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    try {
      final id = (map['id'] ?? '').toString();
      // Show scarcity on ~25% of products, deterministic by ID hash
      final hash = id.hashCode.abs();
      final int? stock = (hash % 4 == 0) ? (hash % 5) + 1 : null; // 1-5 items

      return Product(
        id: id,
        name: map['name'] as String? ?? 'Без названия',
        price: (map['price'] as num?)?.toDouble() ?? 0,
        originalPrice: map['originalPrice'] != null
            ? (map['originalPrice'] as num?)?.toDouble()
            : null,
        imageUrl: map['imageUrl'] as String? ?? '',
        category: map['category'] as String? ?? '',
        subcategory: map['subcategory'] as String? ?? '',
        description: map['description'] as String? ?? '',
        sizes: (map['sizes'] as List?)?.cast<String>() ?? ['M'],
        colors: (map['colors'] as List?)?.cast<String>() ?? [],
        stock: stock,
      );
    } catch (e) {
      throw FormatException('Product.fromMap failed for id=${map['id']}: $e');
    }
  }

  /// Create a Product from the FastAPI backend JSON response.
  /// Maps nested category/subcategory objects to their name strings.
  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  static double? _toDoubleOrNull(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? 'Без названия',
      price: _toDouble(json['price']),
      originalPrice: _toDoubleOrNull(json['original_price']),
      imageUrl: json['image_url'] as String? ?? '',
      category: json['category_name'] as String?
          ?? (json['category'] is Map ? json['category']['name'] as String? ?? '' : json['category']?.toString() ?? ''),
      subcategory: json['subcategory_name'] as String?
          ?? (json['subcategory'] is Map ? json['subcategory']['name'] as String? ?? '' : json['subcategory']?.toString() ?? ''),
      description: json['description'] as String? ?? '',
      sizes: (json['sizes'] as List?)?.map((e) => e.toString()).toList() ?? [],
      colors: (json['colors'] as List?)?.map((e) => e.toString()).toList() ?? [],
      stock: json['stock'] != null ? int.tryParse(json['stock'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'original_price': originalPrice,
        'image_url': imageUrl,
        'category': category,
        'subcategory': subcategory,
        'description': description,
        'sizes': sizes,
        'colors': colors,
        'stock': stock,
      };

  String get displayImageUrl {
    if (imageUrl.startsWith('https://toolorkg.com/')) {
      return '${apiBaseUrl}/api/v1/img?url=${Uri.encodeComponent(imageUrl)}';
    }
    return imageUrl;
  }

  bool get isOnSale => originalPrice != null && originalPrice! > price;

  int get discountPercent {
    if (!isOnSale) return 0;
    return ((1 - price / originalPrice!) * 100).round();
  }

  String get formattedPrice => '${formatPrice(price)} сом';

  String get formattedOriginalPrice =>
      originalPrice != null ? '${formatPrice(originalPrice!)} сом' : '';

  static String formatPrice(double v) {
    final s = v.toStringAsFixed(0);
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('\u{00A0}');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
