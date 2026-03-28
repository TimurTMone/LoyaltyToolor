import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';
import '../services/api_service.dart';

class FavoritesProvider extends ChangeNotifier {
  static const _idsKey = 'favorite_ids';
  static const _productsKey = 'favorite_products';
  final Set<String> _favoriteIds = {};
  final List<Product> _favorites = [];

  FavoritesProvider() {
    _load();
  }

  List<Product> get favorites => List.unmodifiable(_favorites);

  bool isFavorite(String productId) => _favoriteIds.contains(productId);

  void toggleFavorite(Product product) {
    if (_favoriteIds.contains(product.id)) {
      _favoriteIds.remove(product.id);
      _favorites.removeWhere((p) => p.id == product.id);
      _syncRemoveFromBackend(product.id);
    } else {
      _favoriteIds.add(product.id);
      _favorites.add(product);
      _syncAddToBackend(product.id);
    }
    notifyListeners();
    _save();
  }

  // ── Local persistence ─────────────────────────────────────────────────

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_idsKey, _favoriteIds.toList());
      // Also persist full product objects so we don't depend on toolorProducts
      final productJsonList = _favorites
          .map((p) => jsonEncode({
                'id': p.id,
                'name': p.name,
                'price': p.price,
                'originalPrice': p.originalPrice,
                'imageUrl': p.imageUrl,
                'category': p.category,
                'subcategory': p.subcategory,
                'description': p.description,
                'sizes': p.sizes,
                'colors': p.colors,
                'stock': p.stock,
              }))
          .toList();
      await prefs.setStringList(_productsKey, productJsonList);
    } catch (_) {
      // Silently fail — persistence is best-effort
    }
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Try loading full product objects first
      final productJsonList = prefs.getStringList(_productsKey);
      if (productJsonList != null && productJsonList.isNotEmpty) {
        _favoriteIds.clear();
        _favorites.clear();
        for (final raw in productJsonList) {
          try {
            final map = jsonDecode(raw) as Map<String, dynamic>;
            final product = Product.fromMap(map);
            _favoriteIds.add(product.id);
            _favorites.add(product);
          } catch (_) {
            // Skip corrupt entries
          }
        }
        notifyListeners();
        return;
      }

      // Fallback: load just IDs (backwards compat with old data)
      final ids = prefs.getStringList(_idsKey);
      if (ids == null || ids.isEmpty) return;
      _favoriteIds.addAll(ids);
      // Products will be populated when loadFromBackend() is called
      notifyListeners();
    } catch (_) {
      // Corrupt data — start fresh
    }
  }

  // ── Backend sync ──────────────────────────────────────────────────────

  /// Load favorites from backend. Replaces local state with backend data
  /// for logged-in users (backend is source of truth for favorites list).
  Future<void> loadFromBackend() async {
    try {
      final loggedIn = await ApiService.isLoggedIn();
      if (!loggedIn) return;

      final response = await ApiService.dio.get('/api/v1/favorites');
      final data = response.data as List<dynamic>;

      // Merge: keep local favorites, add any from backend not already present
      final backendIds = <String>{};
      for (final raw in data) {
        try {
          final map = raw as Map<String, dynamic>;
          final product = Product.fromJson(map);
          backendIds.add(product.id);

          if (!_favoriteIds.contains(product.id)) {
            _favoriteIds.add(product.id);
            _favorites.add(product);
          } else {
            // Update the product data from backend (fresher info)
            final idx = _favorites.indexWhere((p) => p.id == product.id);
            if (idx >= 0) {
              _favorites[idx] = product;
            }
          }
        } catch (e) {
          debugPrint('[FavoritesProvider] parse product error: $e');
        }
      }

      // Also sync local-only favorites up to backend
      for (final localId in _favoriteIds.toList()) {
        if (!backendIds.contains(localId)) {
          _syncAddToBackend(localId);
        }
      }

      notifyListeners();
      _save();
    } catch (e) {
      debugPrint('[FavoritesProvider] loadFromBackend error: $e');
      // Non-fatal — keep local state
    }
  }

  // ── Individual backend operations (fire-and-forget) ───────────────────

  Future<void> _syncAddToBackend(String productId) async {
    try {
      final loggedIn = await ApiService.isLoggedIn();
      if (!loggedIn) return;

      await ApiService.dio.post('/api/v1/favorites/$productId');
    } catch (e) {
      debugPrint('[FavoritesProvider] _syncAddToBackend error: $e');
    }
  }

  Future<void> _syncRemoveFromBackend(String productId) async {
    try {
      final loggedIn = await ApiService.isLoggedIn();
      if (!loggedIn) return;

      await ApiService.dio.delete('/api/v1/favorites/$productId');
    } catch (e) {
      debugPrint('[FavoritesProvider] _syncRemoveFromBackend error: $e');
    }
  }
}
