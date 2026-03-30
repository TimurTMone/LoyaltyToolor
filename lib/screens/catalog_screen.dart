import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../data/toolor_products.dart';
import '../models/product.dart';
import '../providers/store_provider.dart';
import '../services/api_service.dart';
import '../widgets/product_card.dart';
import 'product_detail_screen.dart';

/// Catalog following ZARA/SSENSE pattern:
/// - Full-width search → category pills → product grid
/// - Product count shown for context
/// - Clean 2-col grid with generous image space
class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  String _query = '';
  String? _sub;

  final _cats = ['Все', ProductCategory.women, ProductCategory.men, ProductCategory.accessories, ProductCategory.sale];

  List<Product> _products = [];
  List<Map<String, dynamic>> _apiCategories = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _loadError = false;
  int _currentPage = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _cats.length, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        setState(() => _sub = null);
        _fetchProducts(reset: true);
      }
    });
    _scrollCtrl.addListener(_onScroll);
    _fetchCategories();
    _fetchProducts(reset: true);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _fetchCategories() async {
    try {
      final response = await ApiService.dio.get('/api/v1/products/categories');
      if (!mounted) return;
      setState(() {
        _apiCategories = (response.data as List).cast<Map<String, dynamic>>();
      });
    } catch (_) {
      // Categories fetch failed — subcategory chips will be empty
    }
  }

  Future<void> _fetchProducts({bool reset = false}) async {
    if (reset) {
      setState(() {
        _currentPage = 1;
        _isLoading = true;
      });
    }

    try {
      final cat = _cats[_tabCtrl.index];
      final Map<String, dynamic> params = {
        'per_page': 20,
        'page': _currentPage,
      };

      // Pass selected store location_id
      final storeId = context.read<StoreProvider>().selectedStoreId;
      if (storeId != null) {
        params['location_id'] = storeId;
      }

      if (_query.isNotEmpty) {
        params['search'] = _query;
      }

      // Map category tab to API category_id if available
      if (cat != 'Все' && cat != ProductCategory.sale) {
        final match = _apiCategories.where((c) => c['name'] == cat);
        if (match.isNotEmpty) {
          params['category_id'] = match.first['id'];
        }
      }

      final response = await ApiService.dio.get(
        '/api/v1/products',
        queryParameters: params,
      );

      final data = response.data;
      var items = (data['items'] as List)
          .map((json) => Product.fromJson(json as Map<String, dynamic>))
          .where((p) => p.price > 0)
          .toList();

      // Client-side filtering for sale tab and subcategory
      if (cat == ProductCategory.sale) {
        items = items.where((p) => p.originalPrice != null).toList();
      }
      if (_sub != null) {
        items = items.where((p) => p.subcategory == _sub).toList();
      }

      if (!mounted) return;
      setState(() {
        if (reset) {
          _products = items;
        } else {
          _products.addAll(items);
        }
        _totalPages = data['pages'] as int? ?? 1;
        _isLoading = false;
        _isLoadingMore = false;
        _loadError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _loadError = _products.isEmpty;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _currentPage >= _totalPages) return;
    _isLoadingMore = true;
    _currentPage++;
    await _fetchProducts();
  }

  void _showStorePicker(BuildContext context, StoreProvider storeProv) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(S.x16),
                child: Text('Выберите магазин', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              ),
              ...storeProv.stores.map((store) {
                final selected = store.id == storeProv.selectedStoreId;
                return ListTile(
                  leading: Icon(
                    selected ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: selected ? AppColors.accent : AppColors.textTertiary,
                    size: 20,
                  ),
                  title: Text(store.name, style: TextStyle(fontSize: 14, fontWeight: selected ? FontWeight.w600 : FontWeight.w400, color: AppColors.textPrimary)),
                  subtitle: store.hours != null ? Text(store.hours!, style: TextStyle(fontSize: 12, color: AppColors.textTertiary)) : null,
                  onTap: () {
                    storeProv.selectStore(store);
                    Navigator.pop(ctx);
                    _fetchProducts(reset: true);
                  },
                );
              }),
              const SizedBox(height: S.x16),
            ],
          ),
        );
      },
    );
  }

  List<String> _subs() {
    final cat = _cats[_tabCtrl.index];
    if (cat == 'Все' || cat == ProductCategory.sale) return [];
    // Derive subcategories from API categories data
    final match = _apiCategories.where((c) => c['name'] == cat);
    if (match.isNotEmpty) {
      final subcats = match.first['subcategories'] as List?;
      if (subcats != null) {
        return subcats.map((s) => s['name'] as String).toList()..sort();
      }
    }
    // Fallback: derive from loaded products
    return _products.map((p) => p.subcategory).where((s) => s.isNotEmpty).toSet().toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    final storeProv = context.watch<StoreProvider>();

    return SafeArea(
      child: Column(
        children: [
          // Store selector
          Padding(
            padding: const EdgeInsets.fromLTRB(S.x16, S.x8, S.x16, 0),
            child: GestureDetector(
              onTap: () => _showStorePicker(context, storeProv),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: S.x12, vertical: S.x8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(R.md),
                ),
                child: Row(
                  children: [
                    Icon(Icons.storefront_rounded, size: 16, color: AppColors.accent),
                    const SizedBox(width: S.x8),
                    Expanded(
                      child: Text(
                        storeProv.selectedStoreName ?? 'Выберите магазин',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.expand_more_rounded, size: 18, color: AppColors.textTertiary),
                  ],
                ),
              ),
            ),
          ),

          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(S.x16, S.x8, S.x16, 0),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) {
                setState(() => _query = v);
                _fetchProducts(reset: true);
              },
              style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Поиск',
                prefixIcon: Icon(Icons.search_rounded, color: AppColors.textTertiary, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? GestureDetector(
                        onTap: () { _searchCtrl.clear(); setState(() => _query = ''); _fetchProducts(reset: true); },
                        child: Icon(Icons.close_rounded, color: AppColors.textTertiary, size: 18),
                      )
                    : null,
              ),
            ),
          ),

          // Category tabs — underline indicator, uppercase
          TabBar(
            controller: _tabCtrl,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: AppColors.textPrimary,
            unselectedLabelColor: AppColors.textTertiary,
            indicatorColor: AppColors.textPrimary,
            indicatorSize: TabBarIndicatorSize.label,
            indicatorWeight: 1.5,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, letterSpacing: 1),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 12, letterSpacing: 1),
            dividerColor: Colors.transparent,
            padding: const EdgeInsets.only(left: S.x12, top: S.x4),
            tabs: _cats.map((c) => Tab(text: c.toUpperCase())).toList(),
            onTap: (_) => setState(() {}),
          ),

          // Subcategory chips
          AnimatedBuilder(
            animation: _tabCtrl,
            builder: (_, _) {
              final subs = _subs();
              if (subs.isEmpty) return const SizedBox(height: S.x4);
              return SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(S.x16, S.x4, S.x16, S.x4),
                  itemCount: subs.length + 1,
                  itemBuilder: (_, i) {
                    final isAll = i == 0;
                    final label = isAll ? 'Все' : subs[i - 1];
                    final val = isAll ? null : subs[i - 1];
                    final sel = _sub == val;
                    return Padding(
                      padding: const EdgeInsets.only(right: S.x6),
                      child: GestureDetector(
                        onTap: () { HapticFeedback.selectionClick(); setState(() => _sub = val); _fetchProducts(reset: true); },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: S.x12, vertical: S.x6),
                          decoration: BoxDecoration(
                            color: sel ? AppColors.textPrimary : AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(R.pill),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 11,
                              color: sel ? AppColors.textInverse : AppColors.textSecondary,
                              fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),

          // Product count
          Padding(
            padding: const EdgeInsets.fromLTRB(S.x16, S.x8, S.x16, S.x4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('${_products.length} товаров', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
            ),
          ),

          // Grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _loadError
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.textTertiary.withValues(alpha: 0.4)),
                            const SizedBox(height: S.x12),
                            Text('Не удалось загрузить товары', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                            const SizedBox(height: S.x16),
                            ElevatedButton.icon(
                              onPressed: () {
                                setState(() { _isLoading = true; _loadError = false; });
                                _fetchProducts(reset: true);
                              },
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text('Повторить'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.md)),
                              ),
                            ),
                          ],
                        ),
                      )
                    : _products.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.search_off_rounded, size: 40, color: AppColors.textTertiary.withValues(alpha: 0.4)),
                                const SizedBox(height: S.x12),
                                Text('Ничего не найдено', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                              ],
                            ),
                          )
                        : GridView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(S.x16, S.x8, S.x16, S.x24),
                        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.56,
                          crossAxisSpacing: S.x12,
                          mainAxisSpacing: S.x20,
                        ),
                        itemCount: _products.length + (_isLoadingMore ? 2 : 0),
                        itemBuilder: (_, i) {
                          if (i >= _products.length) {
                            return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2)));
                          }
                          final p = _products[i];
                          return ProductCard(
                            product: p,
                            heroTag: 'cat_${p.id}',
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(product: p, heroTag: 'cat_${p.id}'))),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
