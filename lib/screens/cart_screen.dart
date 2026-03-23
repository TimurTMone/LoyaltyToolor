import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'checkout_screen.dart';

/// Cart following Shopify/Apple Store pattern:
/// - Swipe-to-delete with red background
/// - Sticky checkout footer with total + cashback
/// - Clean item cards with quantity stepper
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cart, _) {
        if (cart.isEmpty) return _empty();
        return _content(context, cart);
      },
    );
  }

  Widget _empty() {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_bag_outlined, size: 40, color: AppColors.textTertiary),
            SizedBox(height: S.x16),
            Text('Корзина пуста', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
            SizedBox(height: S.x4),
            Text('Добавьте товары из каталога', style: TextStyle(fontSize: 13, color: AppColors.textTertiary)),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context, CartProvider cart) {
    final auth = context.watch<AuthProvider>();
    final pct = auth.loyalty?.cashbackPercent ?? 3;
    final cb = (cart.totalPrice * pct / 100).round();
    final bot = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(S.x16, S.x16, S.x16, S.x8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('КОРЗИНА', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 2, color: AppColors.textPrimary)),
                GestureDetector(
                  onTap: () => _clearDialog(context, cart),
                  child: Text('Очистить (${cart.itemCount})', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                ),
              ],
            ),
          ),

          // Items
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: S.x16, vertical: S.x8),
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              itemCount: cart.items.length,
              separatorBuilder: (_, _) => const SizedBox(height: S.x12),
              itemBuilder: (context, i) {
                final item = cart.items[i];
                return Dismissible(
                  key: ValueKey('${item.product.id}_${item.selectedSize}_${item.selectedColor}_$i'),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) { HapticFeedback.mediumImpact(); cart.removeItem(i); },
                  background: Container(
                    decoration: BoxDecoration(color: AppColors.saleSoft, borderRadius: BorderRadius.circular(R.md)),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: S.x20),
                    child: Icon(Icons.delete_outline_rounded, color: AppColors.sale, size: 22),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(S.x12),
                    decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(R.md)),
                    child: Row(
                      children: [
                        // Image
                        ClipRRect(
                          borderRadius: BorderRadius.circular(R.sm),
                          child: CachedNetworkImage(
                            imageUrl: item.product.displayImageUrl,
                            width: 70, height: 88, fit: BoxFit.cover,
                            errorWidget: (_, _, _) => Container(width: 70, height: 88, color: AppColors.surfaceOverlay),
                          ),
                        ),
                        const SizedBox(width: S.x12),
                        // Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.product.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary, height: 1.3)),
                              const SizedBox(height: S.x2),
                              Text('${item.selectedSize} \u2022 ${item.selectedColor}', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                              const SizedBox(height: S.x12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(item.formattedTotal, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                  _stepper(cart, i, item.quantity),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Footer
          Container(
            padding: EdgeInsets.fromLTRB(S.x16, S.x16, S.x16, S.x16 + bot),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Cashback
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: S.x12, vertical: S.x8),
                  decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(R.sm)),
                  child: Text(
                    '+$cb баллов ($pct% cashback)',
                    style: TextStyle(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: S.x16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Итого', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                    Text(cart.formattedTotal, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  ],
                ),
                const SizedBox(height: S.x12),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    onPressed: () => _checkout(context, cart),
                    child: const Text('ОФОРМИТЬ ЗАКАЗ'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepper(CartProvider cart, int index, int qty) {
    return Container(
      decoration: BoxDecoration(color: AppColors.surfaceOverlay, borderRadius: BorderRadius.circular(R.sm)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepBtn(Icons.remove_rounded, () { HapticFeedback.selectionClick(); cart.updateQuantity(index, qty - 1); }),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: S.x12),
            child: Text('$qty', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ),
          _stepBtn(Icons.add_rounded, () { HapticFeedback.selectionClick(); cart.updateQuantity(index, qty + 1); }),
        ],
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(padding: const EdgeInsets.all(S.x8), child: Icon(icon, size: 16, color: AppColors.textSecondary)),
    );
  }

  void _clearDialog(BuildContext context, CartProvider cart) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.lg)),
        title: const Text('Очистить корзину?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Отмена', style: TextStyle(color: AppColors.textTertiary))),
          TextButton(onPressed: () { cart.clear(); Navigator.pop(ctx); }, child: Text('Очистить', style: TextStyle(color: AppColors.sale))),
        ],
      ),
    );
  }

  void _checkout(BuildContext context, CartProvider cart) {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CheckoutScreen(cart: cart)),
    );
  }
}
