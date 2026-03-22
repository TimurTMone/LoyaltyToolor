import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/favorites_provider.dart';
import '../theme/app_theme.dart';

/// E-commerce product card following Shopify/SSENSE patterns:
/// - Image-first ratio (3:4 portrait)
/// - Minimal text — name + price only
/// - Subtle fav icon, no visual clutter
/// - Sale badge only when relevant
class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final String? heroTag;

  const ProductCard({super.key, required this.product, required this.onTap, this.heroTag});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image — fills available height, 3:4 ratio preserved by parent
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(R.md),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _image(),
                  if (product.isOnSale) _saleBadge(),
                  _favButton(),
                ],
              ),
            ),
          ),
          // Text area — tight, no card background
          Padding(
            padding: const EdgeInsets.only(top: S.x8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textSecondary, height: 1.3),
                ),
                const SizedBox(height: S.x2),
                _price(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _image() {
    final img = CachedNetworkImage(
      imageUrl: product.displayImageUrl,
      fit: BoxFit.cover,
      placeholder: (_, _) => Container(color: AppColors.surfaceElevated),
      errorWidget: (_, _, _) => Container(
        color: AppColors.surfaceElevated,
        child: const Icon(Icons.image_not_supported_outlined, color: AppColors.textTertiary, size: 24),
      ),
    );
    return heroTag != null ? Hero(tag: heroTag!, child: img) : img;
  }

  Widget _saleBadge() {
    return Positioned(
      top: S.x8,
      left: S.x8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: S.x6, vertical: S.x2),
        decoration: BoxDecoration(
          color: AppColors.sale,
          borderRadius: BorderRadius.circular(R.xs),
        ),
        child: Text(
          '-${product.discountPercent}%',
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.3),
        ),
      ),
    );
  }

  Widget _favButton() {
    return Positioned(
      top: S.x6,
      right: S.x6,
      child: Consumer<FavoritesProvider>(
        builder: (context, fav, _) {
          final isFav = fav.isFavorite(product.id);
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              fav.toggleFavorite(product);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: isFav ? AppColors.textPrimary : Colors.black38,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                size: 14,
                color: isFav ? AppColors.sale : Colors.white70,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _price() {
    if (product.isOnSale) {
      return Row(
        children: [
          Text(
            product.formattedPrice,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.sale),
          ),
          const SizedBox(width: S.x6),
          Text(
            product.formattedOriginalPrice,
            style: const TextStyle(fontSize: 11, color: AppColors.textTertiary, decoration: TextDecoration.lineThrough),
          ),
        ],
      );
    }
    return Text(
      product.formattedPrice,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
    );
  }
}
