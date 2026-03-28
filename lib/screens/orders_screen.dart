import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/order.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../models/product.dart';
import 'order_detail_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<AppOrder> _orders = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ApiService.dio.get('/api/v1/orders/me');
      final data = response.data;
      final List<dynamic> items =
          data is List ? data : (data['items'] as List? ?? []);
      if (!mounted) return;
      setState(() {
        _orders = items
            .map((e) => AppOrder.fromJson(e as Map<String, dynamic>))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Не удалось загрузить заказы';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Мои заказы')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorState()
              : _orders.isEmpty
                  ? _emptyState()
                  : RefreshIndicator(
                      onRefresh: _fetchOrders,
                      color: AppColors.accent,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics()),
                        padding: const EdgeInsets.all(S.x16),
                        itemCount: _orders.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: S.x12),
                        itemBuilder: (_, i) => _OrderTile(
                          order: _orders[i],
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    OrderDetailScreen(order: _orders[i]),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_rounded,
              size: 48, color: AppColors.textTertiary),
          const SizedBox(height: S.x16),
          Text('Нет заказов',
              style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: S.x4),
          Text('Ваши заказы появятся здесь',
              style: TextStyle(fontSize: 13, color: AppColors.textTertiary)),
        ],
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded,
              size: 48, color: AppColors.textTertiary),
          const SizedBox(height: S.x16),
          Text(_error!,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(height: S.x16),
          OutlinedButton(
              onPressed: _fetchOrders, child: const Text('Повторить')),
        ],
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final AppOrder order;
  final VoidCallback onTap;

  const _OrderTile({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd.MM.yyyy');
    final (Color badgeColor, Color badgeBg) = _statusColors(order.status);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(S.x16),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(R.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Заказ ${order.orderNumber}',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: S.x8, vertical: S.x4),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(R.xs),
                  ),
                  child: Text(
                    order.statusLabel,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: badgeColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: S.x8),
            Row(
              children: [
                Text(
                  fmt.format(order.createdAt),
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textTertiary),
                ),
                const Spacer(),
                Text(
                  '${Product.formatPrice(order.total)} сом',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(width: S.x8),
                Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppColors.textTertiary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  (Color, Color) _statusColors(String status) => switch (status) {
        'created' => (AppColors.textSecondary,
            AppColors.textSecondary.withValues(alpha: 0.1)),
        'payment_confirmed' =>
          (AppColors.accent, AppColors.accent.withValues(alpha: 0.1)),
        'processing' =>
          (AppColors.accent, AppColors.accent.withValues(alpha: 0.1)),
        'ready_for_pickup' =>
          (AppColors.gold, AppColors.gold.withValues(alpha: 0.1)),
        'shipped' => (Colors.blueAccent, Colors.blueAccent.withValues(alpha: 0.1)),
        'delivered' => (Colors.green, Colors.green.withValues(alpha: 0.1)),
        'cancelled' => (AppColors.sale, AppColors.sale.withValues(alpha: 0.1)),
        _ => (AppColors.textSecondary,
            AppColors.textSecondary.withValues(alpha: 0.1)),
      };
}
