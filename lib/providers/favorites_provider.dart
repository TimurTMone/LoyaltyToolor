import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';
import '../data/toolor_products.dart';

class FavoritesProvider extends ChangeNotifier {
  static const _key = 'favorite_ids';
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
    } else {
      _favoriteIds.add(product.id);
      _favorites.add(product);
    }
    notifyListeners();
    _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, _favoriteIds.toList());
    } catch (_) {
      // Silently fail — persistence is best-effort
    }
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_key);
      if (ids == null) return;
      _favoriteIds.addAll(ids);
      // Rebuild _favorites from product data
      for (final id in ids) {
        final match = toolorProducts.where((p) => p['id'].toString() == id);
        if (match.isNotEmpty) {
          _favorites.add(Product.fromMap(match.first));
        }
      }
      notifyListeners();
    } catch (_) {
      // Corrupt data — start fresh
    }
  }
}
