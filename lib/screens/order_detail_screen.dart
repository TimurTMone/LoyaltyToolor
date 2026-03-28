import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../theme/app_theme.dart';

class OrderDetailScreen extends StatelessWidget {
  final AppOrder order;

  const OrderDetailScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Заказ ${order.orderNumber}')),
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
              if (order.items.isNotEmpty) ...[
                _itemsList(),
                const SizedBox(height: S.x20),
              ],
              _deliveryInfo(),
              if (order.pointsEarned != null && order.pointsEarned! > 0) ...[
                const SizedBox(height: S.x20),
                _pointsInfo(),
              ],
              const SizedBox(height: S.x32),
            ],
          ),
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
          _infoRow('Номер', order.orderNumber),
          _infoRow('Дата', fmt.format(order.createdAt)),
          _infoRow('Сумма', '${Product.formatPrice(order.total)} сом'),
          if (order.discount != null && order.discount! > 0)
            _infoRow('Скидка баллами',
                '-${Product.formatPrice(order.discount!)} сом'),
          if (order.paymentMethod != null)
            _infoRow('Оплата', _paymentLabel(order.paymentMethod!)),
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

    // Find the current status index
    final currentIdx =
        allStatuses.indexWhere((s) => s.$1 == order.status);
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
            final timelineEntry = order.timeline
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
          ...order.items.map((item) => Padding(
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
    final isPickup = order.deliveryType == 'pickup';
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
          if (order.pickupLocationName != null) ...[
            const SizedBox(height: S.x4),
            Text(order.pickupLocationName!,
                style:
                    TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
          if (order.deliveryAddress != null) ...[
            const SizedBox(height: S.x4),
            Text(order.deliveryAddress!,
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
              'Начислено ${order.pointsEarned} баллов за покупку',
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
        'mbank_qr' => 'MBank QR',
        'cash' => 'Наличные',
        'card' => 'Карта',
        _ => method,
      };
}
