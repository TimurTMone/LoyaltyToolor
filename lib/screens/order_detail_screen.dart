import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class OrderDetailScreen extends StatefulWidget {
  final AppOrder order;

  const OrderDetailScreen({super.key, required this.order});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late AppOrder _order;
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
  }

  bool get _canCancel =>
      _order.status == 'pending' || _order.status == 'created';

  Future<void> _cancelOrder() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Отменить заказ?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text('Заказ ${_order.orderNumber} будет отменён.',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Нет', style: TextStyle(color: AppColors.textTertiary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Отменить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isCancelling = true);

    try {
      final response = await ApiService.dio.post(
        '/api/v1/orders/${_order.id}/cancel',
      );

      if (!mounted) return;

      // Refresh order from response if available, otherwise update locally
      if (response.data is Map<String, dynamic>) {
        setState(() {
          _order = AppOrder.fromJson(response.data as Map<String, dynamic>);
          _isCancelling = false;
        });
      } else {
        // Refetch order
        try {
          final refreshResp = await ApiService.dio.get('/api/v1/orders/${_order.id}');
          if (mounted) {
            setState(() {
              _order = AppOrder.fromJson(refreshResp.data as Map<String, dynamic>);
              _isCancelling = false;
            });
          }
        } catch (_) {
          if (mounted) setState(() => _isCancelling = false);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Заказ отменён')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCancelling = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось отменить заказ: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Заказ ${_order.orderNumber}')),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(S.x16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _orderInfo(),
              const SizedBox(height: S.x20),
              _statusTimeline(),
              const SizedBox(height: S.x20),
              if (_order.items.isNotEmpty) ...[
                _itemsList(),
                const SizedBox(height: S.x20),
              ],
              _deliveryInfo(),
              if (_order.pointsEarned != null && _order.pointsEarned! > 0) ...[
                const SizedBox(height: S.x20),
                _pointsInfo(),
              ],
              if (_canCancel) ...[
                const SizedBox(height: S.x20),
                _cancelButton(),
              ],
              const SizedBox(height: S.x32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cancelButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: _isCancelling ? null : _cancelOrder,
        icon: _isCancelling
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
            : const Icon(Icons.cancel_outlined, size: 18),
        label: Text(_isCancelling ? 'Отмена...' : 'Отменить заказ'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.md)),
        ),
      ),
    );
  }

  Widget _orderInfo() {
    final fmt = DateFormat('dd.MM.yyyy HH:mm');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(S.x16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(R.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ИНФОРМАЦИЯ О ЗАКАЗЕ',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: AppColors.textTertiary)),
          const SizedBox(height: S.x12),
          _infoRow('Номер', _order.orderNumber),
          _infoRow('Дата', fmt.format(_order.createdAt)),
          _infoRow('Сумма', '${Product.formatPrice(_order.total)} сом'),
          if (_order.discount != null && _order.discount! > 0)
            _infoRow('Скидка баллами',
                '-${Product.formatPrice(_order.discount!)} сом'),
          if (_order.paymentMethod != null)
            _infoRow('Оплата', _paymentLabel(_order.paymentMethod!)),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: S.x8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _statusTimeline() {
    final allStatuses = [
      ('created', 'Создан'),
      ('payment_confirmed', 'Оплата подтверждена'),
      ('processing', 'В обработке'),
      ('ready_for_pickup', 'Готов к выдаче'),
      ('shipped', 'Отправлен'),
      ('delivered', 'Доставлен'),
    ];

    // If cancelled, show a single-item timeline
    if (_order.status == 'cancelled') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(S.x16),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(R.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('СТАТУС',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                    color: AppColors.textTertiary)),
            const SizedBox(height: S.x16),
            Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded,
                      size: 12, color: Colors.red),
                ),
                const SizedBox(width: S.x12),
                Text('Отменён',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.red)),
              ],
            ),
          ],
        ),
      );
    }

    // Find the current status index
    final currentIdx =
        allStatuses.indexWhere((s) => s.$1 == _order.status);
    final activeIdx = currentIdx >= 0 ? currentIdx : 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(S.x16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(R.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('СТАТУС',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: AppColors.textTertiary)),
          const SizedBox(height: S.x16),
          ...List.generate(allStatuses.length, (i) {
            final completed = i <= activeIdx;
            final isCurrent = i == activeIdx;
            final isLast = i == allStatuses.length - 1;

            // Try to find a timeline entry for this status
            final timelineEntry = _order.timeline
                .where((t) => t.status == allStatuses[i].$1)
                .toList();
            final timestamp = timelineEntry.isNotEmpty
                ? timelineEntry.first.timestamp
                : null;

            return _timelineStep(
              label: allStatuses[i].$2,
              completed: completed,
              isCurrent: isCurrent,
              isLast: isLast,
              timestamp: timestamp,
            );
          }),
        ],
      ),
    );
  }

  Widget _timelineStep({
    required String label,
    required bool completed,
    required bool isCurrent,
    required bool isLast,
    DateTime? timestamp,
  }) {
    final fmt = DateFormat('dd.MM HH:mm');

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: completed
                        ? Colors.green.withValues(alpha: 0.15)
                        : AppColors.surfaceBright,
                    shape: BoxShape.circle,
                    border: isCurrent
                        ? Border.all(color: Colors.green, width: 2)
                        : null,
                  ),
                  child: completed
                      ? const Icon(Icons.check_rounded,
                          size: 12, color: Colors.green)
                      : null,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      color: completed
                          ? Colors.green.withValues(alpha: 0.3)
                          : AppColors.divider,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: S.x12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : S.x16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isCurrent ? FontWeight.w600 : FontWeight.w400,
                      color: completed
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                    ),
                  ),
                  if (timestamp != null)
                    Padding(
                      padding: const EdgeInsets.only(top: S.x2),
                      child: Text(
                        fmt.format(timestamp),
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textTertiary),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemsList() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(S.x16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(R.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ТОВАРЫ',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: AppColors.textTertiary)),
          const SizedBox(height: S.x12),
          ..._order.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: S.x12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceOverlay,
                        borderRadius: BorderRadius.circular(R.sm),
                      ),
                      child: Icon(Icons.shopping_bag_outlined,
                          size: 16, color: AppColors.textTertiary),
                    ),
                    const SizedBox(width: S.x12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.productName,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textPrimary)),
                          Row(
                            children: [
                              if (item.size != null)
                                Text('${item.size}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textTertiary)),
                              if (item.size != null && item.color != null)
                                Text(' / ',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textTertiary)),
                              if (item.color != null)
                                Text('${item.color}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textTertiary)),
                              if (item.quantity > 1)
                                Text(' x${item.quantity}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textTertiary)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${Product.formatPrice(item.price * item.quantity)} сом',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _deliveryInfo() {
    final isPickup = _order.deliveryType == 'pickup';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(S.x16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(R.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ДОСТАВКА',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: AppColors.textTertiary)),
          const SizedBox(height: S.x12),
          Row(
            children: [
              Icon(
                isPickup
                    ? Icons.storefront_rounded
                    : Icons.local_shipping_rounded,
                size: 18,
                color: AppColors.accent,
              ),
              const SizedBox(width: S.x8),
              Text(
                isPickup ? 'Самовывоз' : 'Доставка',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary),
              ),
            ],
          ),
          if (_order.pickupLocationName != null) ...[
            const SizedBox(height: S.x4),
            Text(_order.pickupLocationName!,
                style:
                    TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
          if (_order.deliveryAddress != null) ...[
            const SizedBox(height: S.x4),
            Text(_order.deliveryAddress!,
                style:
                    TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }

  Widget _pointsInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(S.x16),
      decoration: BoxDecoration(
        color: AppColors.goldSoft,
        borderRadius: BorderRadius.circular(R.md),
      ),
      child: Row(
        children: [
          Icon(Icons.star_rounded, size: 20, color: AppColors.gold),
          const SizedBox(width: S.x8),
          Expanded(
            child: Text(
              'Начислено ${_order.pointsEarned} баллов за покупку',
              style: TextStyle(
                  fontSize: 13,
                  color: AppColors.gold,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  String _paymentLabel(String method) => switch (method) {
        'finik' => 'Finik Pay',
        'cash' => 'Наличные',
        'card' => 'Карта',
        _ => method,
      };
}
