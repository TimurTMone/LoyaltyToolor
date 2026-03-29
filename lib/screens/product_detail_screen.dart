import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../providers/favorites_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/locations_sheet.dart';
import '../services/analytics_service.dart';

/// Product detail following Nike/SSENSE patterns:
/// - Immersive image (50%+ of viewport)
/// - Sticky bottom CTA bar
/// - Size/color chips with animated selection
/// - Social proof cashback badge
/// - Delivery/returns info in grouped card
class ProductDetailScreen extends StatefulWidget {
  final Product product;
  final String? heroTag;
  const ProductDetailScreen({super.key, required this.product, this.heroTag});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late String _size;
  late String _color;
  bool _added = false;
  bool _tryHome = false;

  @override
  void initState() {
    super.initState();
    _size = widget.product.sizes.isNotEmpty ? widget.product.sizes[0] : '';
    _color = widget.product.colors.isNotEmpty ? widget.product.colors[0] : '';
    Analytics.productView(widget.product.id, widget.product.name, widget.product.price);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final bot = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Image ──
              SliverAppBar(
                expandedHeight: MediaQuery.of(context).size.height * 0.52,
                pinned: true,
                stretch: true,
                backgroundColor: AppColors.surfaceElevated,
                leading: _pill(Icons.arrow_back_rounded, () => Navigator.pop(context)),
                actions: [
                  _pill(Icons.share_rounded, () => _shareProduct(p)),
                  Consumer<FavoritesProvider>(
                    builder: (_, fav, _) {
                      final on = fav.isFavorite(p.id);
                      return _pill(
                        on ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        () { HapticFeedback.selectionClick(); fav.toggleFavorite(p); },
                        color: on ? AppColors.sale : Colors.white,
                      );
                    },
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [StretchMode.zoomBackground],
                  background: _heroImage(p),
                ),
              ),

              // ── Details ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(S.x20, S.x20, S.x20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Breadcrumb
                      Text(
                        '${p.category}  /  ${p.subcategory}'.toUpperCase(),
                        style: TextStyle(fontSize: 10, color: AppColors.textTertiary, letterSpacing: 1.5),
                      ),
                      const SizedBox(height: S.x8),
                      Text(p.name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary, height: 1.25)),
                      const SizedBox(height: S.x16),

                      // Price
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            p.formattedPrice,
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: p.isOnSale ? AppColors.sale : AppColors.textPrimary),
                          ),
                          if (p.isOnSale) ...[
                            const SizedBox(width: S.x8),
                            Text(p.formattedOriginalPrice, style: TextStyle(fontSize: 14, color: AppColors.textTertiary, decoration: TextDecoration.lineThrough)),
                            const SizedBox(width: S.x8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: S.x6, vertical: S.x2),
                              decoration: BoxDecoration(color: AppColors.saleSoft, borderRadius: BorderRadius.circular(R.xs)),
                              child: Text('-${p.discountPercent}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.sale)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: S.x8),

                      // Badges row
                      Wrap(
                        spacing: S.x8,
                        runSpacing: S.x6,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: S.x8, vertical: S.x4),
                            decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(R.xs)),
                            child: Text(
                              '+${(p.price * 0.05).toStringAsFixed(0)} баллов',
                              style: TextStyle(fontSize: 11, color: AppColors.accent, fontWeight: FontWeight.w500),
                            ),
                          ),
                          if (p.stock != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: S.x8, vertical: S.x4),
                              decoration: BoxDecoration(color: AppColors.goldSoft, borderRadius: BorderRadius.circular(R.xs)),
                              child: Text(
                                'Осталось ${p.stock} шт',
                                style: TextStyle(fontSize: 11, color: AppColors.gold, fontWeight: FontWeight.w600),
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: S.x24),

                      // Size
                      if (p.sizes.isNotEmpty) ...[
                        _label('РАЗМЕР'),
                        const SizedBox(height: S.x8),
                        Wrap(
                          spacing: S.x8,
                          runSpacing: S.x8,
                          children: p.sizes.map((s) => _chip(s, s == _size, () { HapticFeedback.selectionClick(); setState(() => _size = s); })).toList(),
                        ),
                        const SizedBox(height: S.x20),
                      ],

                      // Color
                      if (p.colors.isNotEmpty) ...[
                        _label('ЦВЕТ'),
                        const SizedBox(height: S.x8),
                        Wrap(
                          spacing: S.x8,
                          runSpacing: S.x8,
                          children: p.colors.map((c) => _chip(c, c == _color, () { HapticFeedback.selectionClick(); setState(() => _color = c); })).toList(),
                        ),
                        const SizedBox(height: S.x20),
                      ],

                      // Description
                      _label('ОПИСАНИЕ'),
                      const SizedBox(height: S.x8),
                      Text(p.description, style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.6)),

                      const SizedBox(height: S.x24),

                      // Try at Home
                      GestureDetector(
                        onTap: () { HapticFeedback.selectionClick(); setState(() => _tryHome = !_tryHome); },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: double.infinity,
                          padding: const EdgeInsets.all(S.x16),
                          decoration: BoxDecoration(
                            color: _tryHome ? AppColors.accentSoft : AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(R.md),
                            border: Border.all(color: _tryHome ? AppColors.accent.withValues(alpha: 0.3) : Colors.transparent),
                          ),
                          child: Row(
                            children: [
                              Icon(_tryHome ? Icons.check_circle_rounded : Icons.checkroom_outlined, size: 20, color: _tryHome ? AppColors.accent : AppColors.textSecondary),
                              const SizedBox(width: S.x12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Примерка дома', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _tryHome ? AppColors.accent : AppColors.textPrimary)),
                                    const SizedBox(height: S.x2),
                                    Text(_tryHome ? 'Закажите 2 размера — оставьте лучший, возврат бесплатно' : 'Закажите несколько размеров, верните бесплатно',
                                        style: TextStyle(fontSize: 11, color: _tryHome ? AppColors.accent.withValues(alpha: 0.7) : AppColors.textTertiary)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: S.x12),

                      // WhatsApp button
                      GestureDetector(
                        onTap: () => _openWhatsApp(p),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(S.x16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF25D366).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(R.md),
                            border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_rounded, size: 18, color: const Color(0xFF25D366)),
                              const SizedBox(width: S.x8),
                              Text('Написать в WhatsApp', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF25D366))),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: S.x12),

                      // Info card
                      Container(
                        padding: const EdgeInsets.all(S.x16),
                        decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(R.md)),
                        child: Column(
                          children: [
                            _infoRow(Icons.local_shipping_outlined, 'Бесплатная доставка по Бишкеку'),
                            _infoDivider(),
                            _infoRow(Icons.refresh_rounded, 'Возврат 14 дней'),
                            _infoDivider(),
                            GestureDetector(
                              onTap: () => showLocationsSheet(context),
                              behavior: HitTestBehavior.opaque,
                              child: Row(
                                children: [
                                  Icon(Icons.location_on_outlined, size: 16, color: AppColors.textTertiary),
                                  const SizedBox(width: S.x12),
                                  Expanded(child: Text('7 точек примерки в Бишкеке', style: TextStyle(fontSize: 12, color: AppColors.accent))),
                                  Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.accent),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 80 + bot),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── Bottom CTA ──
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(S.x16, S.x12, S.x16, S.x12 + bot),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _added ? null : () => _addToCart(p),
                  style: _added
                      ? ElevatedButton.styleFrom(backgroundColor: AppColors.accentSoft, foregroundColor: AppColors.accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.pill)))
                      : null,
                  child: Text(_added ? 'ДОБАВЛЕНО  \u2713' : _tryHome ? 'ПРИМЕРКА ДОМА  \u2014  ${p.formattedPrice}' : 'В КОРЗИНУ  \u2014  ${p.formattedPrice}'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroImage(Product p) {
    final img = CachedNetworkImage(
      imageUrl: p.displayImageUrl,
      fit: BoxFit.cover,
      placeholder: (_, _) => Container(color: AppColors.surfaceElevated),
      errorWidget: (_, _, _) => Container(color: AppColors.surfaceElevated, child: Icon(Icons.image_not_supported_outlined, size: 40, color: AppColors.textTertiary)),
    );
    return widget.heroTag != null ? Hero(tag: widget.heroTag!, child: img) : img;
  }

  Widget _pill(IconData icon, VoidCallback onTap, {Color color = Colors.white}) {
    return Padding(
      padding: const EdgeInsets.all(S.x8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.5, color: AppColors.textTertiary));
  }

  Widget _chip(String text, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: S.x16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.textPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(R.sm),
          border: Border.all(color: selected ? AppColors.textPrimary : AppColors.surfaceBright, width: 1),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: selected ? AppColors.textInverse : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textTertiary),
        const SizedBox(width: S.x12),
        Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: AppColors.textSecondary))),
      ],
    );
  }

  Widget _infoDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: S.x12),
      child: Divider(color: AppColors.divider, height: 0.5),
    );
  }

  void _shareProduct(Product p) {
    HapticFeedback.selectionClick();
    final price = p.isOnSale ? '${p.formattedPrice} (было ${p.formattedOriginalPrice})' : p.formattedPrice;
    SharePlus.instance.share(ShareParams(text: '${p.name} — $price\n\nСмотри в TOOLOR 👉 toolorkg.com'));
  }

  void _openWhatsApp(Product p) {
    HapticFeedback.selectionClick();
    final message = Uri.encodeComponent('Здравствуйте! Хочу узнать про "${p.name}" (${p.formattedPrice})');
    launchUrl(Uri.parse('https://wa.me/996999955000?text=$message'), mode: LaunchMode.externalApplication);
  }

  void _addToCart(Product p) {
    HapticFeedback.mediumImpact();
    context.read<CartProvider>().addItem(p, _size, _color);
    setState(() => _added = true);
    Future.delayed(const Duration(seconds: 2), () { if (mounted) setState(() => _added = false); });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Добавлено в корзину'),
        backgroundColor: AppColors.surfaceOverlay,
        duration: const Duration(seconds: 2),
        action: SnackBarAction(label: 'Корзина', textColor: AppColors.accent, onPressed: () { if (mounted) Navigator.pop(context); }),
      ),
    );
  }
}
