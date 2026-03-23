import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';
import '../models/cart_item.dart';

class CartProvider extends ChangeNotifier {
  static const _key = 'cart_items';
  final List<CartItem> _items = [];

  CartProvider() {
    _load();
  }

  List<CartItem> get items => List.unmodifiable(_items);

  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  double get totalPrice => _items.fold(0, (sum, item) => sum + item.totalPrice);

  String get formattedTotal => '${Product.formatPrice(totalPrice)} сом';

  bool get isEmpty => _items.isEmpty;

  void addItem(Product product, String size, String color) {
    final existingIndex = _items.indexWhere(
      (item) =>
          item.product.id == product.id &&
          item.selectedSize == size &&
          item.selectedColor == color,
    );

    if (existingIndex >= 0) {
      _items[existingIndex].quantity++;
    } else {
      _items.add(CartItem(
        product: product,
        selectedSize: size,
        selectedColor: color,
      ));
    }
    notifyListeners();
    _save();
  }

  void removeItem(int index) {
    _items.removeAt(index);
    notifyListeners();
    _save();
  }

  void updateQuantity(int index, int quantity) {
    if (quantity <= 0) {
      _items.removeAt(index);
    } else {
      _items[index].quantity = quantity;
    }
    notifyListeners();
    _save();
  }

  void clear() {
    _items.clear();
    notifyListeners();
    _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _items.map((item) => jsonEncode({
        'product': {
          'id': item.product.id,
          'name': item.product.name,
          'price': item.product.price,
          'originalPrice': item.product.originalPrice,
          'imageUrl': item.product.imageUrl,
          'category': item.product.category,
          'subcategory': item.product.subcategory,
          'description': item.product.description,
          'sizes': item.product.sizes,
          'colors': item.product.colors,
        },
        'selectedSize': item.selectedSize,
        'selectedColor': item.selectedColor,
        'quantity': item.quantity,
      })).toList();
      await prefs.setStringList(_key, list);
    } catch (_) {
      // Silently fail — persistence is best-effort
    }
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_key);
      if (list == null) return;
      _items.clear();
      for (final raw in list) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final product = Product.fromMap(map['product'] as Map<String, dynamic>);
        _items.add(CartItem(
          product: product,
          selectedSize: map['selectedSize'] as String? ?? 'M',
          selectedColor: map['selectedColor'] as String? ?? '',
          quantity: map['quantity'] as int? ?? 1,
        ));
      }
      notifyListeners();
    } catch (_) {
      // Corrupt data — start fresh
    }
  }
}
