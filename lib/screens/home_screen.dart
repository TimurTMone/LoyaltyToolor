import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../models/loyalty.dart';
import '../models/product.dart';
import '../screens/product_detail_screen.dart';
import '../services/api_service.dart';
import '../widgets/product_card.dart';

/// Home screen following editorial e-commerce patterns:
/// - Loyalty card as hero (key differentiator)
/// - Editorial banner carousel (lifestyle feel)
/// - Horizontal product rail for sale (urgency)
/// - 2-column grid for new arrivals (browse)
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _entryCtrl;

  List<Product> _saleProducts = [];
  List<Product> _newProducts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    try {
      final response = await ApiService.dio.get(
        '/api/v1/products',
        queryParameters: {'per_page': 20},
      );
      final items = (response.data['items'] as List)
          .map((json) => Product.fromJson(json as Map<String, dynamic>))
          .where((p) => p.price > 0)
          .toList();

      if (!mounted) return;
      setState(() {
        _saleProducts = items.where((p) => p.originalPrice != null).take(8).toList();
        _newProducts = items.take(10).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[HomeScreen] Failed to fetch products: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (!auth.isLoggedIn) return _welcome(auth);
        return _home(context, auth);
      },
    );
  }

  // ─── Welcome / Login ─────────────────────────────────────────────
  Widget _welcome(AuthProvider auth) {
    final fade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    final slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.3),
          radius: 1.2,
          colors: [
            isDark ? const Color(0xFF0F1620) : const Color(0xFFEAF1F8),
            AppColors.background,
          ],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: fade,
            child: SlideTransition(
              position: slide,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: S.x40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
                      ),
                      child: Icon(Icons.diamond_outlined, size: 28, color: AppColors.accent),
                    ),
                    const SizedBox(height: S.x32),
                    Text(
                      'TOOLOR',
                      style: TextStyle(fontSize: 44, fontWeight: FontWeight.w800, letterSpacing: 14, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: S.x8),
                    Text(
                      'LOYALTY  &  STORE',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400, letterSpacing: 6, color: AppColors.textTertiary),
                    ),
                    const SizedBox(height: S.x64),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () { HapticFeedback.mediumImpact(); auth.demoLogin(); },
                        child: const Text('ВОЙТИ'),
                      ),
                    ),
                    const SizedBox(height: S.x12),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton(
                        onPressed: () { HapticFeedback.lightImpact(); auth.demoLogin(); },
                        child: const Text('ДЕМО'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Main Home ───────────────────────────────────────────────────
  Widget _home(BuildContext context, AuthProvider auth) {
    final loyalty = auth.loyalty;
    if (loyalty == null) return const SizedBox.shrink();

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final saleProducts = _saleProducts;
    final newProducts = _newProducts;

    return SafeArea(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          // Greeting — minimal, left-aligned
          SliverToBoxAdapter(child: _header(auth, loyalty)),

          // Loyalty card
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: S.x16),
            child: _loyaltyCard(context, loyalty),
          )),

          // Editorial banners
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.only(top: S.x24),
            child: _editorialBanners(),
          )),

          // Sale rail
          if (saleProducts.isNotEmpty) ...[
            SliverToBoxAdapter(child: _sectionTitle('SALE', trailing: '${saleProducts.length} items')),
            SliverToBoxAdapter(child: _horizontalRail(saleProducts, 'sale')),
          ],

          // New arrivals grid
          SliverToBoxAdapter(child: _sectionTitle('НОВИНКИ', trailing: 'Смотреть все')),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: S.x16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.56,
                crossAxisSpacing: S.x12,
                mainAxisSpacing: S.x20,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final p = newProducts[i];
                  return ProductCard(product: p, heroTag: 'new_${p.id}', onTap: () => _open(context, p, 'new_${p.id}'));
                },
                childCount: newProducts.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: S.x32)),
        ],
      ),
    );
  }

  Widget _header(AuthProvider auth, LoyaltyAccount loyalty) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(S.x16, S.x16, S.x16, S.x16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Привет, ${auth.user?.name.split(' ').first ?? ''}',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                const SizedBox(height: S.x2),
                Text(
                  '${loyalty.tierName} \u2022 ${loyalty.cashbackPercent}% cashback',
                  style: TextStyle(fontSize: 12, color: _tierColor(loyalty.tier), fontWeight: FontWeight.w500, letterSpacing: 0.3),
                ),
              ],
            ),
          ),
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.accent, Color(0xFF7AB8F5)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(R.sm),
            ),
            child: Center(
              child: Text(auth.user?.name[0] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Loyalty Card ────────────────────────────────────────────────
  Widget _loyaltyCard(BuildContext context, LoyaltyAccount loyalty) {
    final tc = _tierColor(loyalty.tier);
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); _showQR(context, loyalty); },
      child: Container(
        padding: const EdgeInsets.all(S.x20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.surfaceElevated, tc.withValues(alpha: 0.06)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(R.lg),
          border: Border.all(color: tc.withValues(alpha: 0.2)),
          boxShadow: [BoxShadow(color: tc.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('TOOLOR', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 3, color: AppColors.textPrimary)),
                      const SizedBox(width: S.x8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: S.x6, vertical: 1),
                        decoration: BoxDecoration(color: tc.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(3)),
                        child: Text(loyalty.tierName.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: tc, letterSpacing: 1)),
                      ),
                    ],
                  ),
                  const SizedBox(height: S.x16),
                  Text('${loyalty.points}', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1)),
                  const SizedBox(height: S.x2),
                  Text('баллов', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  if (loyalty.tier != LoyaltyTier.platinum) ...[
                    const SizedBox(height: S.x12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: loyalty.progressToNextTier.clamp(0.0, 1.0),
                        backgroundColor: AppColors.surfaceBright,
                        valueColor: AlwaysStoppedAnimation(tc),
                        minHeight: 3,
                      ),
                    ),
                    const SizedBox(height: S.x4),
                    Text(
                      '${(loyalty.nextTierThreshold - loyalty.totalSpent).toStringAsFixed(0)} сом до ${_nextTier(loyalty.tier)}',
                      style: TextStyle(fontSize: 10, color: AppColors.textTertiary),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: S.x16),
            Container(
              padding: const EdgeInsets.all(S.x6),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(R.md)),
              child: QrImageView(data: loyalty.qrCode, version: QrVersions.auto, size: 80, backgroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  void _showQR(BuildContext context, LoyaltyAccount loyalty) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(S.x16, 0, S.x16, S.x16),
        padding: const EdgeInsets.symmetric(horizontal: S.x32, vertical: S.x32),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(R.xl)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('ПОКАЖИТЕ НА КАССЕ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 2, color: AppColors.textSecondary)),
            const SizedBox(height: S.x24),
            Container(
              padding: const EdgeInsets.all(S.x16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(R.lg)),
              child: QrImageView(data: loyalty.qrCode, version: QrVersions.auto, size: 220, backgroundColor: Colors.white),
            ),
            const SizedBox(height: S.x16),
            Text(loyalty.qrCode, style: TextStyle(fontSize: 13, color: AppColors.textTertiary, letterSpacing: 2, fontWeight: FontWeight.w500)),
            const SizedBox(height: S.x8),
          ],
        ),
      ),
    );
  }

  // ─── Editorial Banners ───────────────────────────────────────────
  Widget _editorialBanners() {
    final banners = [
      _BannerData('ВЕСЕННЯЯ\nКОЛЛЕКЦИЯ', 'Новые поступления 2026', AppColors.accent),
      _BannerData('TOOLOR BOX', 'Подписка от 4 990 сом', AppColors.gold),
      _BannerData('ПРИМЕРКА\nДОМА', 'Закажи 2 размера бесплатно', Colors.blueAccent),
    ];
    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: S.x16),
        itemCount: banners.length,
        separatorBuilder: (_, _) => const SizedBox(width: S.x12),
        itemBuilder: (_, i) {
          final b = banners[i];
          return Container(
            width: 220,
            padding: const EdgeInsets.all(S.x20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [b.color.withValues(alpha: 0.22), b.color.withValues(alpha: 0.04)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(R.lg),
              border: Border.all(color: b.color.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(b.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary, height: 1.25)),
                Row(
                  children: [
                    Expanded(child: Text(b.subtitle, style: TextStyle(fontSize: 11, color: b.color, fontWeight: FontWeight.w500))),
                    Icon(Icons.arrow_forward_rounded, size: 16, color: b.color.withValues(alpha: 0.6)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── Section Title ───────────────────────────────────────────────
  Widget _sectionTitle(String title, {String? trailing}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(S.x16, S.x32, S.x16, S.x12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 2, color: AppColors.textPrimary)),
          if (trailing != null)
            Text(trailing, style: TextStyle(fontSize: 11, color: AppColors.textTertiary, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  // ─── Horizontal Product Rail ─────────────────────────────────────
  Widget _horizontalRail(List<Product> products, String prefix) {
    return SizedBox(
      height: 240,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: S.x16),
        itemCount: products.length,
        separatorBuilder: (_, _) => const SizedBox(width: S.x12),
        itemBuilder: (context, i) {
          final p = products[i];
          return SizedBox(
            width: 150,
            child: ProductCard(product: p, heroTag: '${prefix}_${p.id}', onTap: () => _open(context, p, '${prefix}_${p.id}')),
          );
        },
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────
  Color _tierColor(LoyaltyTier t) => switch (t) {
    LoyaltyTier.bronze => AppColors.bronze,
    LoyaltyTier.silver => AppColors.silver,
    LoyaltyTier.gold => AppColors.goldTier,
    LoyaltyTier.platinum => AppColors.platinum,
  };

  String _nextTier(LoyaltyTier t) => switch (t) {
    LoyaltyTier.bronze => 'Silver',
    LoyaltyTier.silver => 'Gold',
    LoyaltyTier.gold => 'Platinum',
    LoyaltyTier.platinum => '',
  };

  void _open(BuildContext context, Product p, String tag) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(product: p, heroTag: tag)));
  }
}

class _BannerData {
  final String title, subtitle;
  final Color color;
  const _BannerData(this.title, this.subtitle, this.color);
}
