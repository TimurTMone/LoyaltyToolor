import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/store_provider.dart';
import '../models/loyalty.dart';
import '../models/product.dart';
import '../screens/product_detail_screen.dart';
import '../services/api_service.dart';
import '../screens/auth_screen.dart';
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
  bool _loadError = false;
  bool _loyaltyRetried = false;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    try {
      final Map<String, dynamic> params = {'per_page': 20};
      final storeId = context.read<StoreProvider>().selectedStoreId;
      if (storeId != null) params['location_id'] = storeId;

      final response = await ApiService.dio.get(
        '/api/v1/products',
        queryParameters: params,
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
        _loadError = false;
      });
    } catch (e) {
      debugPrint('[HomeScreen] Failed to fetch products: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = _saleProducts.isEmpty && _newProducts.isEmpty;
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
        // Show loading splash while restoring session
        if (auth.isLoading && !auth.isLoggedIn) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/images/toolor_logo.png', width: 160),
                const SizedBox(height: 24),
                const CircularProgressIndicator(),
              ],
            ),
          );
        }
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
                    Image.asset('assets/images/toolor_logo.png', width: 200),
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
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthScreen()));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0033A0),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 1),
                        ),
                        child: const Text('ВОЙТИ'),
                      ),
                    ),
                    const SizedBox(height: S.x12),
                    TextButton(
                      onPressed: () { HapticFeedback.lightImpact(); Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthScreen())); },
                      child: Text('Создать аккаунт', style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
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

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Loyalty may be null if fetch failed during onboarding — retry once
    if (loyalty == null) {
      if (!_loyaltyRetried) {
        _loyaltyRetried = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          auth.fetchLoyalty().then((_) {
            if (mounted) setState(() {});
          });
        });
      }
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: S.x40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.textTertiary.withValues(alpha: 0.4)),
              const SizedBox(height: S.x12),
              Text('Не удалось загрузить товары', style: TextStyle(color: AppColors.textSecondary, fontSize: 14), textAlign: TextAlign.center),
              const SizedBox(height: S.x16),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() { _isLoading = true; _loadError = false; });
                  _fetchProducts();
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
        ),
      );
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
                  'Привет, ${(auth.user?.name ?? '').isNotEmpty ? auth.user!.name.split(' ').first : ''}',
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
              child: Text((auth.user?.name ?? '').isNotEmpty ? auth.user!.name[0] : '?', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Loyalty Card ────────────────────────────────────────────────
  Widget _loyaltyCard(BuildContext context, LoyaltyAccount loyalty) {
    final auth = context.watch<AuthProvider>();
    final qrData = auth.qrToken ?? loyalty.qrCode;
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
                      Image.asset('assets/images/toolor_logo.png', height: 16),
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
                  if (loyalty.tier != LoyaltyTier.at) ...[
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
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(S.x6),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(R.md)),
                  child: auth.qrToken != null
                      ? QrImageView(data: qrData, version: QrVersions.auto, size: 80, backgroundColor: Colors.white)
                      : const SizedBox(width: 80, height: 80, child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)))),
                ),
                const SizedBox(height: S.x4),
                _QrPulseIndicator(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showQR(BuildContext context, LoyaltyAccount loyalty) {
    final tierIndex = LoyaltyTier.values.indexOf(loyalty.tier);
    final tiers = [
      ('Кулун', '3% кэшбэк', 'Пройти регистрацию', LoyaltyTier.kulun, AppColors.bronze),
      ('Тай', '5% кэшбэк', 'от 50 000 сом', LoyaltyTier.tai, AppColors.silver),
      ('Кунан', '8% кэшбэк', 'от 150 000 сом', LoyaltyTier.kunan, AppColors.goldTier),
      ('Ат', '12% кэшбэк', 'от 300 000 сом', LoyaltyTier.at, AppColors.platinum),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Consumer<AuthProvider>(
        builder: (ctx, auth, _) {
          final qrData = auth.qrToken ?? loyalty.qrCode;
          final tc = _tierColor(loyalty.tier);
          final remaining = loyalty.tier != LoyaltyTier.at
              ? (loyalty.nextTierThreshold - loyalty.totalSpent).toStringAsFixed(0)
              : '';

          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
                ),

                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Current tier header ──
                        Text(loyalty.tierName, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                        const SizedBox(height: 8),
                        if (loyalty.tier != LoyaltyTier.at)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: tc.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                            child: Text(
                              '$remaining сом до ${_nextTier(loyalty.tier)}',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tc),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: tc.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                            child: Text('Максимальный уровень', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tc)),
                          ),

                        const SizedBox(height: 20),
                        Divider(color: AppColors.divider),
                        const SizedBox(height: 16),

                        // ── QR Code ──
                        Center(
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('ПОКАЖИТЕ НА КАССЕ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 2, color: AppColors.textSecondary)),
                                  const SizedBox(width: S.x8),
                                  _QrPulseIndicator(),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(R.lg)),
                                child: auth.qrToken != null
                                    ? QrImageView(data: qrData, version: QrVersions.auto, size: 180, backgroundColor: Colors.white)
                                    : const SizedBox(width: 180, height: 180, child: Center(child: CircularProgressIndicator())),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),
                        Divider(color: AppColors.divider),
                        const SizedBox(height: 16),

                        // ── Description ──
                        Text(
                          'Каждый наш покупатель автоматически становится участником бонусной программы. Совершайте покупки и получайте кэшбэк баллами!',
                          style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
                        ),
                        const SizedBox(height: 24),

                        // ── Tier roadmap ──
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Column(
                            children: List.generate(tiers.length, (i) {
                              final (name, cashback, condition, tier, color) = tiers[i];
                              final isActive = i <= tierIndex;
                              final isCurrent = i == tierIndex;
                              final isLast = i == tiers.length - 1;

                              return Column(
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // ── Timeline column ──
                                      SizedBox(
                                        width: 32,
                                        child: Column(
                                          children: [
                                            Container(
                                              width: 28, height: 28,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: isActive ? color : AppColors.surfaceBright,
                                                border: isCurrent ? Border.all(color: color, width: 2.5) : null,
                                              ),
                                              child: Center(
                                                child: Text(
                                                  '${i + 1}',
                                                  style: TextStyle(
                                                    fontSize: 13, fontWeight: FontWeight.w700,
                                                    color: isActive ? Colors.white : AppColors.textTertiary,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 14),

                                      // ── Tier info ──
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(name, style: TextStyle(
                                                  fontSize: 16, fontWeight: FontWeight.w700,
                                                  color: isActive ? AppColors.textPrimary : AppColors.textTertiary,
                                                )),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: isActive ? color.withValues(alpha: 0.15) : AppColors.surfaceBright,
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Text(cashback, style: TextStyle(
                                                    fontSize: 12, fontWeight: FontWeight.w600,
                                                    color: isActive ? color : AppColors.textTertiary,
                                                  )),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(condition, style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  // ── Connecting line ──
                                  if (!isLast)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 13),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Container(
                                          width: 2, height: 32,
                                          color: i < tierIndex ? color : AppColors.surfaceBright,
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            }),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── Rules link ──
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const _LoyaltyRulesScreen()));
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              border: Border(top: BorderSide(color: AppColors.divider)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Правила программы лояльности', style: TextStyle(fontSize: 15, color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
                                Icon(Icons.arrow_forward, size: 18, color: AppColors.textTertiary),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
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
    LoyaltyTier.kulun => AppColors.bronze,
    LoyaltyTier.tai => AppColors.silver,
    LoyaltyTier.kunan => AppColors.goldTier,
    LoyaltyTier.at => AppColors.platinum,
  };

  String _nextTier(LoyaltyTier t) => switch (t) {
    LoyaltyTier.kulun => 'Тай',
    LoyaltyTier.tai => 'Кунан',
    LoyaltyTier.kunan => 'Ат',
    LoyaltyTier.at => '',
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

/// A small pulsing dot that indicates the QR code is live/rotating.
class _QrPulseIndicator extends StatefulWidget {
  @override
  State<_QrPulseIndicator> createState() => _QrPulseIndicatorState();
}

class _QrPulseIndicatorState extends State<_QrPulseIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'LIVE',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: Colors.green,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Loyalty Rules Screen
// ═══════════════════════════════════════════════════════════════════

class _LoyaltyRulesScreen extends StatelessWidget {
  const _LoyaltyRulesScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Правила программы')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Правила программы лояльности TOOLOR',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 24),

            _rule('1', 'С момента регистрации Участник безоговорочно принимает настоящие Правила и имеет право на получение Привилегий.'),
            _rule('2', 'При совершении покупки товаров с использованием баллов, кэшбэк начисляется только за ту часть покупки, которая была оплачена денежными средствами.'),
            _rule('3', 'Для участия в Программе необходимо скачать приложение и пройти регистрацию.'),
            _rule('4', 'Процент кэшбэка увеличивается в зависимости от уровня Участника.'),
            _rule('5', 'При каждой покупке необходимо показать QR-код на кассе для начисления баллов.'),

            const SizedBox(height: 28),
            Text('УРОВНИ И КЭШБЭК', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: AppColors.textPrimary)),
            const SizedBox(height: 16),

            _tierRow('Кулун', '3%', 'Пройти регистрацию', AppColors.bronze),
            _tierRow('Тай', '5%', 'от 50 000 сом покупок', AppColors.silver),
            _tierRow('Кунан', '8%', 'от 150 000 сом покупок', AppColors.goldTier),
            _tierRow('Ат', '12%', 'от 300 000 сом покупок', AppColors.platinum),

            const SizedBox(height: 28),
            Text('СРОК ДЕЙСТВИЯ БАЛЛОВ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            Text(
              'Накопленные баллы должны быть потрачены в течение 90 календарных дней. По истечению 90 дней после последней покупки с использованием QR-кода все накопленные баллы сгорают.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rule(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.accent.withValues(alpha: 0.1)),
            child: Center(child: Text(number, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accent))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
          ),
        ],
      ),
    );
  }

  Widget _tierRow(String name, String cashback, String condition, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                Text(condition, style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
              ],
            ),
          ),
          Text(cashback, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}
