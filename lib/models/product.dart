import 'package:flutter/foundation.dart' show kIsWeb;

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
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'].toString(),
      name: map['name'] as String,
      price: (map['price'] as num).toDouble(),
      originalPrice: map['originalPrice'] != null
          ? (map['originalPrice'] as num).toDouble()
          : null,
      imageUrl: map['imageUrl'] as String,
      category: map['category'] as String,
      subcategory: map['subcategory'] as String,
      description: map['description'] as String,
      sizes: List<String>.from(map['sizes'] as List),
      colors: List<String>.from(map['colors'] as List),
    );
  }

  /// On web, proxy images through Vercel to avoid CORS
  String get displayImageUrl {
    if (kIsWeb && imageUrl.startsWith('https://toolorkg.com/wp-content/uploads/')) {
      return imageUrl.replaceFirst('https://toolorkg.com/wp-content/uploads/', '/cdn/');
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
