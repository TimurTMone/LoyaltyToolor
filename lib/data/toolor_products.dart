// Product data fetched and parsed from toolorkg.com
// Toolor - International brand of functional outerwear and accessories
// inspired by digital nomad aesthetics and lifestyle.
// Based in Bishkek, Kyrgyzstan.
//
// Currency: Kyrgyzstani Som (KGS)
// Last fetched: 2026-03-23
// Total products: 113

class Toolor {
  static const String brandName = 'Toolor';
  static const String brandDescription =
      'Международный бренд функциональной верхней одежды и аксессуаров, '
      'вдохновленный эстетикой и стилем жизни digital-номадов';
  static const String phone = '+996 998 844 444';
  static const String email = 'salestoolor@coolgroup.kg';
  static const String address = 'Бишкек, AsiaMall, 2 этаж, бутик 19(1)';
  static const String workingHours = 'Ежедневно 10:00–22:00';
  static const String currency = 'сом';
  static const String baseUrl = 'https://toolorkg.com';
}

// ---------------------------------------------------------------------------
// Category & subcategory constants
// ---------------------------------------------------------------------------

class ProductCategory {
  static const String men = 'Мужчинам';
  static const String women = 'Женщинам';
  static const String accessories = 'Аксессуары';
  static const String sale = 'Скидки';
}

class ProductSubcategory {
  // Shared clothing
  static const String tshirts = 'Футболки';
  static const String longsleeves = 'Лонгсливы';
  static const String sweatshirts = 'Свитшоты';
  static const String hoodies = 'Худи';
  static const String shirts = 'Рубашки';
  static const String knitwear = 'Вязаный трикотаж';
  static const String pants = 'Брюки';
  static const String shorts = 'Шорты';
  static const String jackets = 'Куртки';
  static const String downJackets = 'Пуховики';
  static const String windbreakers = 'Ветровки';
  static const String fleece = 'Флис';
  static const String vests = 'Жилеты';
  static const String sets = 'Костюмы';
  static const String cardigans = 'Кардиган';
  static const String sweaters = 'Свитер';
  static const String turtlenecks = 'Водолазки';
  static const String lightdown = 'Лайтдаун';
  static const String zippers = 'Зипки';
  static const String trench = 'Тренчи';
  static const String bodies = 'Боди';

  // Accessories
  static const String scarves = 'Шарфы';
  static const String bags = 'Сумки';
  static const String caps = 'Кепки';
  static const String hats = 'Шапки';
  static const String cases = 'Чехлы';
  static const String other = 'Другое';
}

// ---------------------------------------------------------------------------
// Product data is now fetched from the API (GET /api/v1/products).
// This empty list is kept as a fallback for offline/error scenarios.
// The constants above (Toolor, ProductCategory, ProductSubcategory) are still
// used throughout the app for category names and brand info.
// ---------------------------------------------------------------------------

final List<Map<String, dynamic>> toolorProducts = [];

// ---------------------------------------------------------------------------
// Helper functions (operate on the now-empty local list; kept for compat)
// ---------------------------------------------------------------------------

/// Returns products filtered by category
List<Map<String, dynamic>> getProductsByCategory(String category) =>
    toolorProducts.where((p) => p['category'] == category).toList();

/// Returns products filtered by subcategory
List<Map<String, dynamic>> getProductsBySubcategory(String subcategory) =>
    toolorProducts.where((p) => p['subcategory'] == subcategory).toList();

/// Returns products on sale
List<Map<String, dynamic>> get saleProducts =>
    toolorProducts.where((p) => p['originalPrice'] != null).toList();

/// Returns a product by id
Map<String, dynamic>? getProductById(String id) {
  try {
    return toolorProducts.firstWhere((p) => p['id'] == id);
  } catch (_) {
    return null;
  }
}

/// Search products by query string
List<Map<String, dynamic>> searchProducts(String query) {
  final lowerQuery = query.toLowerCase();
  return toolorProducts
      .where(
        (p) =>
            (p['name'] as String).toLowerCase().contains(lowerQuery) ||
            (p['description'] as String).toLowerCase().contains(lowerQuery) ||
            (p['category'] as String).toLowerCase().contains(lowerQuery) ||
            (p['subcategory'] as String).toLowerCase().contains(lowerQuery),
      )
      .toList();
}

/// Returns all unique categories
List<String> get allCategories =>
    toolorProducts.map((p) => p['category'] as String).toSet().toList();

/// Returns all unique subcategories for a given category
List<String> getSubcategoriesForCategory(String category) =>
    toolorProducts
        .where((p) => p['category'] == category)
        .map((p) => p['subcategory'] as String)
        .toSet()
        .toList();

/// Returns the price range for the entire catalog
Map<String, int> get priceRange {
  final prices = toolorProducts.map((p) => p['price'] as int).toList();
  if (prices.isEmpty) return {'min': 0, 'max': 0};
  prices.sort();
  return {'min': prices.first, 'max': prices.last};
}
