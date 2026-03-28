import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';
import '../models/cart_item.dart';
import '../services/api_service.dart';

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
    _syncAddToBackend(product.id, size, color, 1);
  }

  void removeItem(int index) {
    if (index < 0 || index >= _items.length) return;
    final item = _items[index];
    _items.removeAt(index);
    notifyListeners();
    _save();
    _syncRemoveFromBackend(item.product.id, item.selectedSize, item.selectedColor);
  }

  void updateQuantity(int index, int quantity) {
    if (index < 0 || index >= _items.length) return;
    if (quantity <= 0) {
      final item = _items[index];
      _items.removeAt(index);
      notifyListeners();
      _save();
      _syncRemoveFromBackend(item.product.id, item.selectedSize, item.selectedColor);
    } else {
      _items[index].quantity = quantity;
      notifyListeners();
      _save();
      _syncUpdateToBackend(
          _items[index].product.id,
          _items[index].selectedSize,
          _items[index].selectedColor,
          quantity);
    }
  }

  void clear() {
    _items.clear();
    notifyListeners();
    _save();
    _syncClearBackend();
  }

  // ── Local persistence ─────────────────────────────────────────────────

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

  // ── Backend sync ──────────────────────────────────────────────────────

  /// Load cart from backend and merge with local state.
  /// Backend items that don't exist locally are added;
  /// local items that don't exist on backend are kept.
  Future<void> loadFromBackend() async {
    try {
      final loggedIn = await ApiService.isLoggedIn();
      if (!loggedIn) return;

      final response = await ApiService.dio.get('/api/v1/cart');
      final data = response.data as List<dynamic>;

      for (final raw in data) {
        final map = raw as Map<String, dynamic>;
        final productId = map['product_id']?.toString() ?? '';
        final size = map['selected_size'] as String? ?? 'M';
        final color = map['selected_color'] as String? ?? '';
        final quantity = (map['quantity'] as num?)?.toInt() ?? 1;

        // Check if we already have this item locally
        final existingIndex = _items.indexWhere(
          (item) =>
              item.product.id == productId &&
              item.selectedSize == size &&
              item.selectedColor == color,
        );

        if (existingIndex >= 0) {
          // Use the larger quantity (merge strategy)
          if (quantity > _items[existingIndex].quantity) {
            _items[existingIndex].quantity = quantity;
          }
        } else {
          // Build a minimal Product from backend cart data
          _items.add(CartItem(
            product: Product(
              id: productId,
              name: map['product_name'] as String? ?? '',
              price: (map['product_price'] as num?)?.toDouble() ?? 0,
              imageUrl: map['product_image_url'] as String? ?? '',
              category: '',
              subcategory: '',
              description: '',
              sizes: [size],
              colors: color.isNotEmpty ? [color] : [],
            ),
            selectedSize: size,
            selectedColor: color,
            quantity: quantity,
          ));
        }
      }

      notifyListeners();
      _save(); // Persist merged state locally
    } catch (e) {
      debugPrint('[CartProvider] loadFromBackend error: $e');
      // Non-fatal — keep local state
    }
  }

  /// Push entire local cart to backend (full sync).
  Future<void> syncToBackend() async {
    try {
      final loggedIn = await ApiService.isLoggedIn();
      if (!loggedIn) return;

      // Clear backend cart first, then push all local items
      try {
        await ApiService.dio.delete('/api/v1/cart');
      } catch (_) {
        // May 404 if already empty — that's fine
      }

      for (final item in _items) {
        await ApiService.dio.post('/api/v1/cart', data: {
          'product_id': item.product.id,
          'selected_size': item.selectedSize,
          'selected_color': item.selectedColor,
          'quantity': item.quantity,
        });
      }
    } catch (e) {
      debugPrint('[CartProvider] syncToBackend error: $e');
      // Non-fatal — local state is primary
    }
  }

  // ── Individual backend operations (fire-and-forget) ───────────────────

  Future<void> _syncAddToBackend(
      String productId, String size, String color, int quantity) async {
    try {
      final loggedIn = await ApiService.isLoggedIn();
      if (!loggedIn) return;

      await ApiService.dio.post('/api/v1/cart', data: {
        'product_id': productId,
        'selected_size': size,
        'selected_color': color,
        'quantity': quantity,
      });
    } catch (e) {
      debugPrint('[CartProvider] _syncAddToBackend error: $e');
    }
  }

  Future<void> _syncRemoveFromBackend(
      String productId, String size, String color) async {
    try {
      final loggedIn = await ApiService.isLoggedIn();
      if (!loggedIn) return;

      // Find the backend cart item by fetching cart and matching
      final response = await ApiService.dio.get('/api/v1/cart');
      final data = response.data as List<dynamic>;
      for (final raw in data) {
        final map = raw as Map<String, dynamic>;
        if (map['product_id']?.toString() == productId &&
            (map['selected_size'] ?? '') == size &&
            (map['selected_color'] ?? '') == color) {
          final backendId = map['id']?.toString();
          if (backendId != null) {
            await ApiService.dio.delete('/api/v1/cart/$backendId');
          }
          break;
        }
      }
    } catch (e) {
      debugPrint('[CartProvider] _syncRemoveFromBackend error: $e');
    }
  }

  Future<void> _syncUpdateToBackend(
      String productId, String size, String color, int quantity) async {
    try {
      final loggedIn = await ApiService.isLoggedIn();
      if (!loggedIn) return;

      // Find the backend cart item by fetching cart and matching
      final response = await ApiService.dio.get('/api/v1/cart');
      final data = response.data as List<dynamic>;
      for (final raw in data) {
        final map = raw as Map<String, dynamic>;
        if (map['product_id']?.toString() == productId &&
            (map['selected_size'] ?? '') == size &&
            (map['selected_color'] ?? '') == color) {
          final backendId = map['id']?.toString();
          if (backendId != null) {
            await ApiService.dio.patch('/api/v1/cart/$backendId', data: {
              'quantity': quantity,
            });
          }
          break;
        }
      }
    } catch (e) {
      debugPrint('[CartProvider] _syncUpdateToBackend error: $e');
    }
  }

  Future<void> _syncClearBackend() async {
    try {
      final loggedIn = await ApiService.isLoggedIn();
      if (!loggedIn) return;

      await ApiService.dio.delete('/api/v1/cart');
    } catch (e) {
      debugPrint('[CartProvider] _syncClearBackend error: $e');
    }
  }
}
