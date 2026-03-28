import 'product.dart';

class CartItem {
  final Product product;
  final String selectedSize;
  final String selectedColor;
  int quantity;

  CartItem({
    required this.product,
    required this.selectedSize,
    required this.selectedColor,
    this.quantity = 1,
  });

  double get totalPrice => product.price * quantity;

  String get formattedTotal => '${Product.formatPrice(totalPrice)} сом';

  /// Serialize cart item for syncing to the backend.
  Map<String, dynamic> toJson() => {
        'product_id': product.id,
        'selected_size': selectedSize,
        'selected_color': selectedColor,
        'quantity': quantity,
      };
}
