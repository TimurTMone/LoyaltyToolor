import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../data/toolor_products.dart';
import '../models/product.dart';
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
  String _query = '';
  String? _sub;

  final _cats = ['Все', ProductCategory.women, ProductCategory.men, ProductCategory.accessories, ProductCategory.sale];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _cats.length, vsync: this);
    _tabCtrl.addListener(() { if (!_tabCtrl.indexIsChanging) setState(() => _sub = null); });
  }

  @override
  void dispose() { _tabCtrl.dispose(); _searchCtrl.dispose(); super.dispose(); }

  List<Product> _products() {
    var list = toolorProducts.where((p) => (p['price'] as num) > 0).toList();
    final cat = _cats[_tabCtrl.index];
    if (cat != 'Все') {
      list = cat == ProductCategory.sale
          ? list.where((p) => p['originalPrice'] != null).toList()
          : list.where((p) => p['category'] == cat).toList();
    }
    if (_sub != null) list = list.where((p) => p['subcategory'] == _sub).toList();
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((p) => (p['name'] as String).toLowerCase().contains(q)).toList();
    }
    return list.map((p) => Product.fromMap(p)).toList();
  }

  List<String> _subs() {
    final cat = _cats[_tabCtrl.index];
    if (cat == 'Все' || cat == ProductCategory.sale) return [];
    return toolorProducts.where((p) => p['category'] == cat).map((p) => p['subcategory'] as String).toSet().toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(S.x16, S.x8, S.x16, 0),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Поиск',
                prefixIcon: Icon(Icons.search_rounded, color: AppColors.textTertiary, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? GestureDetector(
                        onTap: () { _searchCtrl.clear(); setState(() => _query = ''); },
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
                        onTap: () { HapticFeedback.selectionClick(); setState(() => _sub = val); },
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
          AnimatedBuilder(
            animation: _tabCtrl,
            builder: (_, _) {
              final count = _products().length;
              return Padding(
                padding: const EdgeInsets.fromLTRB(S.x16, S.x8, S.x16, S.x4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('$count товаров', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                ),
              );
            },
          ),

          // Grid
          Expanded(
            child: AnimatedBuilder(
              animation: _tabCtrl,
              builder: (_, _) {
                final prods = _products();
                if (prods.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off_rounded, size: 40, color: AppColors.textTertiary.withValues(alpha: 0.4)),
                        const SizedBox(height: S.x12),
                        Text('Ничего не найдено', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                      ],
                    ),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(S.x16, S.x8, S.x16, S.x24),
                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.56,
                    crossAxisSpacing: S.x12,
                    mainAxisSpacing: S.x20,
                  ),
                  itemCount: prods.length,
                  itemBuilder: (_, i) {
                    final p = prods[i];
                    return ProductCard(
                      product: p,
                      heroTag: 'cat_${p.id}',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(product: p, heroTag: 'cat_${p.id}'))),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
