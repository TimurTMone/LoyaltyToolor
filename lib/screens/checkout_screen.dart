import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/store_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/locations_sheet.dart';
import '../models/product.dart';
import '../services/analytics_service.dart';

// Conditionally import Finik SDK (only works on mobile)
import 'package:finik_sdk/finik_sdk.dart';

const _finikApiKey = String.fromEnvironment('FINIK_API_KEY',
    defaultValue: 'eOJ3RXsvyZ8ztUIRp1fwq2fHJfYUyfKK2GpOgeAv');
const _finikAccountId = String.fromEnvironment('FINIK_ACCOUNT_ID',
    defaultValue: '54b4316f-e1d2-4007-b167-3f4dd9e0b9a7');
const _finikIsBeta = bool.fromEnvironment('FINIK_BETA', defaultValue: true);

/// Checkout flow:
/// Delivery/Pickup → Finik Payment → Done
class CheckoutScreen extends StatefulWidget {
  final CartProvider cart;
  const CheckoutScreen({super.key, required this.cart});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

enum _Step { delivery, pay, done }

class _CheckoutScreenState extends State<CheckoutScreen> {
  _Step _step = _Step.delivery;
  bool _isSubmitting = false;
  String? _orderNumber;
  String? _orderId;

  // Delivery
  String _deliveryType = 'pickup';
  ToolorLocation? _selectedPickupLocation;
  List<ToolorLocation> _locations = [];
  bool _isLoadingLocations = false;
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  // Promo code
  final _promoCtrl = TextEditingController();
  String? _promoError;
  double _promoDiscount = 0;
  String? _appliedPromo;

  // Points redemption
  double _pointsToRedeem = 0;
  int _availablePoints = 0;

  // Cashback earned
  int? _cashbackEarned;

  @override
  void initState() {
    super.initState();
    _loadPoints();
    _fetchLocations();
  }

  void _preselectStore() {
    final storeProv = context.read<StoreProvider>();
    if (storeProv.selectedStoreId != null && _locations.isNotEmpty) {
      final match = _locations.where((l) => l.id == storeProv.selectedStoreId);
      if (match.isNotEmpty && _selectedPickupLocation == null) {
        setState(() => _selectedPickupLocation = match.first);
      }
    }
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    _promoCtrl.dispose();
    super.dispose();
  }

  void _loadPoints() {
    final auth = context.read<AuthProvider>();
    _availablePoints = auth.loyalty?.points ?? 0;
  }

  Future<void> _fetchLocations() async {
    setState(() => _isLoadingLocations = true);
    try {
      final response = await ApiService.dio.get('/api/v1/locations');
      final data = response.data;
      final List<dynamic> items =
          data is List ? data : (data['items'] as List? ?? data as List);
      if (!mounted) return;
      setState(() {
        _locations = items
            .map((json) =>
                ToolorLocation.fromJson(json as Map<String, dynamic>))
            .where((loc) => loc.type == LocationType.store)
            .toList();
        _isLoadingLocations = false;
      });
      _preselectStore();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locations = [
          const ToolorLocation(
            name: 'TOOLOR AsiaMall',
            address: 'AsiaMall, 2 этаж, бутик 19(1)',
            type: LocationType.store,
            hours: '10:00-22:00',
          ),
        ];
        _isLoadingLocations = false;
      });
    }
  }

  double get _orderTotal => widget.cart.totalPrice;
  double get _maxRedeemable {
    final afterPromo = _orderTotal - _promoDiscount;
    return _availablePoints < afterPromo ? _availablePoints.toDouble() : afterPromo;
  }
  double get _finalTotal =>
      (_orderTotal - _promoDiscount - _pointsToRedeem).clamp(0, _orderTotal);

  bool get _canProceed {
    if (_deliveryType == 'pickup' && _selectedPickupLocation == null) return false;
    if (_deliveryType == 'delivery' && _addressCtrl.text.trim().isEmpty) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_step == _Step.done
            ? 'Готово'
            : _step == _Step.delivery
                ? 'Оформление'
                : 'Оплата'),
        leading: _step == _Step.done
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () {
                  if (_step == _Step.pay) {
                    setState(() => _step = _Step.delivery);
                  } else {
                    Navigator.pop(context);
                  }
                }),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: switch (_step) {
            _Step.delivery => _deliveryStep(),
            _Step.pay => _finikPayStep(),
            _Step.done => _doneStep(),
          },
        ),
      ),
    );
  }

  // ─── Step 0: Delivery type + Points + Promo ──────────────────────

  Widget _deliveryStep() {
    return SingleChildScrollView(
      key: const ValueKey('delivery'),
      padding: const EdgeInsets.all(S.x16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Delivery type
          _sectionCard(
            title: 'СПОСОБ ПОЛУЧЕНИЯ',
            child: Column(
              children: [
                _deliveryOption(
                  'pickup',
                  Icons.storefront_rounded,
                  'Самовывоз',
                  'Заберите из магазина',
                ),
                const SizedBox(height: S.x8),
                _deliveryOption(
                  'delivery',
                  Icons.local_shipping_rounded,
                  'Доставка',
                  'Курьером по Бишкеку',
                ),
              ],
            ),
          ),

          if (_deliveryType == 'pickup') ...[
            const SizedBox(height: S.x16),
            _pickupLocationSelector(),
          ],

          if (_deliveryType == 'delivery') ...[
            const SizedBox(height: S.x16),
            _deliveryAddressInput(),
          ],

          const SizedBox(height: S.x16),

          // Delivery notes
          _sectionCard(
            title: 'КОММЕНТАРИЙ К ЗАКАЗУ',
            child: TextField(
              controller: _notesCtrl,
              style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Позвоните перед доставкой, этаж, домофон...',
                hintStyle: TextStyle(fontSize: 13, color: AppColors.textTertiary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(R.sm),
                  borderSide: BorderSide(color: AppColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(R.sm),
                  borderSide: BorderSide(color: AppColors.divider),
                ),
                contentPadding: const EdgeInsets.all(S.x12),
              ),
            ),
          ),

          const SizedBox(height: S.x16),

          // Promo code
          _promoCodeInput(),

          const SizedBox(height: S.x16),

          if (_availablePoints > 0) _pointsRedemptionCard(),

          const SizedBox(height: S.x16),

          _orderSummary(),

          const SizedBox(height: S.x24),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _canProceed && !_isSubmitting
                  ? _createOrderAndPay
                  : null,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('ПЕРЕЙТИ К ОПЛАТЕ'),
            ),
          ),

          const SizedBox(height: S.x32),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(S.x16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(R.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: AppColors.textTertiary)),
          const SizedBox(height: S.x12),
          child,
        ],
      ),
    );
  }

  Widget _deliveryOption(
      String value, IconData icon, String title, String subtitle) {
    final selected = _deliveryType == value;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _deliveryType = value;
          if (value != 'pickup') _selectedPickupLocation = null;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(S.x12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.06)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(R.md),
          border: Border.all(
              color: selected
                  ? AppColors.accent.withValues(alpha: 0.3)
                  : AppColors.divider),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 22,
                color: selected ? AppColors.accent : AppColors.textTertiary),
            const SizedBox(width: S.x12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? AppColors.accent
                              : AppColors.textPrimary)),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textTertiary)),
                ],
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: selected ? AppColors.accent : AppColors.textTertiary,
                    width: selected ? 6 : 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pickupLocationSelector() {
    return _sectionCard(
      title: 'ВЫБЕРИТЕ МАГАЗИН',
      child: _isLoadingLocations
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: S.x16),
              child: Center(
                  child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2))),
            )
          : Column(
              children: _locations.map((loc) {
                final selected = _selectedPickupLocation?.name == loc.name;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedPickupLocation = loc);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: S.x8),
                    padding: const EdgeInsets.all(S.x12),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.accent.withValues(alpha: 0.06)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(R.sm),
                      border: Border.all(
                          color: selected
                              ? AppColors.accent.withValues(alpha: 0.3)
                              : AppColors.divider),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.storefront_rounded,
                            size: 18,
                            color: selected
                                ? AppColors.accent
                                : AppColors.textTertiary),
                        const SizedBox(width: S.x12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(loc.name,
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textPrimary)),
                              Text(loc.address,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textTertiary)),
                              if (loc.hours != null)
                                Text(loc.hours!,
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textTertiary)),
                            ],
                          ),
                        ),
                        if (selected)
                          Icon(Icons.check_circle_rounded,
                              size: 20, color: AppColors.accent),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _deliveryAddressInput() {
    return _sectionCard(
      title: 'АДРЕС ДОСТАВКИ',
      child: TextField(
        controller: _addressCtrl,
        style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Улица, дом, квартира',
          hintStyle: TextStyle(fontSize: 13, color: AppColors.textTertiary),
          prefixIcon: Icon(Icons.location_on_outlined,
              size: 20, color: AppColors.textTertiary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(R.sm),
            borderSide: BorderSide(color: AppColors.divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(R.sm),
            borderSide: BorderSide(color: AppColors.divider),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: S.x12, vertical: S.x12),
        ),
      ),
    );
  }

  Widget _promoCodeInput() {
    return _sectionCard(
      title: 'ПРОМОКОД',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _promoCtrl,
                  style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                  textCapitalization: TextCapitalization.characters,
                  enabled: _appliedPromo == null,
                  decoration: InputDecoration(
                    hintText: 'Введите промокод',
                    hintStyle:
                        TextStyle(fontSize: 13, color: AppColors.textTertiary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(R.sm),
                      borderSide: BorderSide(color: AppColors.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(R.sm),
                      borderSide: BorderSide(color: AppColors.divider),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: S.x12, vertical: S.x12),
                  ),
                ),
              ),
              const SizedBox(width: S.x8),
              if (_appliedPromo == null)
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _promoCtrl.text.trim().isNotEmpty
                        ? _applyPromoCode
                        : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: S.x16),
                    ),
                    child: const Text('OK'),
                  ),
                )
              else
                IconButton(
                  onPressed: () {
                    setState(() {
                      _appliedPromo = null;
                      _promoDiscount = 0;
                      _promoCtrl.clear();
                      _promoError = null;
                    });
                  },
                  icon: Icon(Icons.close_rounded,
                      color: AppColors.textTertiary),
                ),
            ],
          ),
          if (_promoError != null)
            Padding(
              padding: const EdgeInsets.only(top: S.x8),
              child: Text(_promoError!,
                  style: const TextStyle(fontSize: 12, color: Colors.red)),
            ),
          if (_appliedPromo != null)
            Padding(
              padding: const EdgeInsets.only(top: S.x8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(S.x8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(R.sm),
                ),
                child: Text(
                  'Промокод $_appliedPromo применён: -${Product.formatPrice(_promoDiscount)} сом',
                  style: const TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _applyPromoCode() async {
    final code = _promoCtrl.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _promoError = null;
    });

    try {
      final response = await ApiService.dio.post(
        '/api/v1/promo-codes/validate',
        data: {'code': code, 'order_total': _orderTotal},
      );
      final data = response.data as Map<String, dynamic>;
      final discount = (data['discount_amount'] as num?)?.toDouble() ?? 0;
      setState(() {
        _appliedPromo = code;
        _promoDiscount = discount;
        // Reset points if they exceed new max
        if (_pointsToRedeem > _maxRedeemable) {
          _pointsToRedeem = _maxRedeemable;
        }
      });
    } catch (e) {
      setState(() {
        _promoError = 'Промокод не найден или истёк';
      });
    }
  }

  Widget _pointsRedemptionCard() {
    final maxPts = _maxRedeemable;
    return _sectionCard(
      title: 'ИСПОЛЬЗОВАТЬ БАЛЛЫ',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star_rounded, size: 18, color: AppColors.gold),
              const SizedBox(width: S.x8),
              Text('Доступно: $_availablePoints баллов',
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: S.x12),
          Row(
            children: [
              Text('0',
                  style:
                      TextStyle(fontSize: 11, color: AppColors.textTertiary)),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: AppColors.accent,
                    inactiveTrackColor: AppColors.surfaceBright,
                    thumbColor: AppColors.accent,
                    overlayColor: AppColors.accent.withValues(alpha: 0.1),
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 8),
                  ),
                  child: Slider(
                    value: _pointsToRedeem.clamp(0, maxPts),
                    min: 0,
                    max: maxPts > 0 ? maxPts : 1,
                    divisions: maxPts > 100 ? 100 : (maxPts > 0 ? maxPts.toInt() : 1),
                    onChanged: maxPts > 0
                        ? (val) => setState(() => _pointsToRedeem = val)
                        : null,
                  ),
                ),
              ),
              Text('${maxPts.toInt()}',
                  style:
                      TextStyle(fontSize: 11, color: AppColors.textTertiary)),
            ],
          ),
          if (_pointsToRedeem > 0)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: S.x8),
              padding: const EdgeInsets.all(S.x12),
              decoration: BoxDecoration(
                color: AppColors.accentSoft,
                borderRadius: BorderRadius.circular(R.sm),
              ),
              child: Text(
                '${_pointsToRedeem.toInt()} баллов = ${Product.formatPrice(_pointsToRedeem)} сом скидка',
                style: TextStyle(
                    fontSize: 13,
                    color: AppColors.accent,
                    fontWeight: FontWeight.w500),
              ),
            ),
        ],
      ),
    );
  }

  Widget _orderSummary() {
    return _sectionCard(
      title: 'ИТОГО',
      child: Column(
        children: [
          _summaryRow('Товары', widget.cart.formattedTotal),
          if (_promoDiscount > 0)
            _summaryRow(
                'Промокод', '-${Product.formatPrice(_promoDiscount)} сом',
                isDiscount: true),
          if (_pointsToRedeem > 0)
            _summaryRow(
                'Скидка баллами', '-${Product.formatPrice(_pointsToRedeem)} сом',
                isDiscount: true),
          const Divider(height: S.x24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('К оплате',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              Text(
                '${Product.formatPrice(_finalTotal)} сом',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: S.x8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDiscount ? Colors.green : AppColors.textPrimary)),
        ],
      ),
    );
  }

  // ─── Create order then open Finik ────────────────────────────────

  Future<void> _createOrderAndPay() async {
    if (_isSubmitting) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _isSubmitting = true;
    });

    try {
      // Sync local cart to backend
      await context.read<CartProvider>().syncToBackend();

      final orderData = <String, dynamic>{
        'payment_method': 'finik',
        'delivery_type': _deliveryType,
      };

      if (_pointsToRedeem > 0) {
        orderData['points_used'] = _pointsToRedeem.toInt();
      }

      if (_appliedPromo != null) {
        orderData['promo_code'] = _appliedPromo;
      }

      if (_deliveryType == 'pickup' && _selectedPickupLocation != null) {
        if (_selectedPickupLocation!.id != null) {
          orderData['pickup_location_id'] = _selectedPickupLocation!.id;
        }
      }

      if (_deliveryType == 'delivery') {
        orderData['delivery_address'] = _addressCtrl.text.trim();
      }

      if (_notesCtrl.text.trim().isNotEmpty) {
        orderData['delivery_notes'] = _notesCtrl.text.trim();
      }

      final response = await ApiService.dio.post(
        '/api/v1/orders',
        data: orderData,
      );

      final data = response.data as Map<String, dynamic>;
      _orderId = data['id'] as String?;
      _orderNumber = data['order_number'] as String? ?? data['id'] as String?;

      final auth = context.read<AuthProvider>();
      final cashbackPct = auth.loyalty?.cashbackPercent ?? 3;
      _cashbackEarned = (_finalTotal * cashbackPct / 100).round();

      Analytics.purchase(
        _orderId ?? '',
        _finalTotal,
        widget.cart.itemCount,
        'finik',
      );

      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _step = _Step.pay;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ─── Finik Payment ───────────────────────────────────────────────

  Widget _finikPayStep() {
    final requestId = const Uuid().v4();

    return FinikProvider(
      key: const ValueKey('finik_pay'),
      apiKey: _finikApiKey,
      isBeta: _finikIsBeta,
      locale: FinikSdkLocale.RU,
      textScenario: TextScenario.REPLENISHMENT,
      paymentMethods: const [
        PaymentMethod.APP,
        PaymentMethod.QR,
        PaymentMethod.VISA,
      ],
      widget: CreateItemHandlerWidget(
        accountId: _finikAccountId,
        nameEn: 'TOOLOR Order ${_orderNumber ?? ""}',
        amount: FixedAmount(_finalTotal),
        requestId: requestId,
        callbackUrl: '$apiBaseUrl/api/v1/webhooks/finik',
        requiredFields: [
          if (_orderId != null)
            RequiredField(
              fieldId: 'order_id',
              label: 'Order ID',
              value: _orderId!,
              isHidden: true,
            ),
        ],
        onCreated: (data) {},
      ),
      onPayment: (Map<String, dynamic>? data) {
        if (data == null) return;
        final status = data['status'] as String?;
        if (status == 'SUCCEEDED') {
          _confirmPaymentOnBackend(data);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Оплата не прошла. Попробуйте ещё раз.'),
                backgroundColor: Colors.red,
              ),
            );
            setState(() => _step = _Step.delivery);
          }
        }
      },
      onBackPressed: () {
        setState(() => _step = _Step.delivery);
      },
    );
  }

  Future<void> _confirmPaymentOnBackend(
      Map<String, dynamic> paymentData) async {
    if (_orderId == null) return;

    try {
      await ApiService.dio.post(
        '/api/v1/orders/$_orderId/confirm-payment',
        data: paymentData,
      );
    } catch (_) {
      // Webhook will confirm as backup
    }

    if (!mounted) return;
    setState(() => _step = _Step.done);
  }

  // ─── Done ────────────────────────────────────────────────────────

  Widget _doneStep() {
    return Center(
      key: const ValueKey('done'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: S.x32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [AppColors.accent, const Color(0xFF7AB8F5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  size: 36, color: Colors.white),
            ),
            const SizedBox(height: S.x24),
            Text('Оплата прошла успешно',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            if (_orderNumber != null) ...[
              const SizedBox(height: S.x4),
              Text('Заказ $_orderNumber',
                  style: TextStyle(
                      fontSize: 13,
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: S.x8),
            Text(
              'Заказ подтверждён и принят в обработку.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5),
            ),
            if (_pointsToRedeem > 0) ...[
              const SizedBox(height: S.x12),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: S.x16, vertical: S.x8),
                decoration: BoxDecoration(
                    color: AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(R.sm)),
                child: Text(
                  'Списано ${_pointsToRedeem.toInt()} баллов',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.accent,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
            const SizedBox(height: S.x12),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: S.x16, vertical: S.x8),
              decoration: BoxDecoration(
                  color: AppColors.goldSoft,
                  borderRadius: BorderRadius.circular(R.sm)),
              child: Text(
                _cashbackEarned != null && _cashbackEarned! > 0
                    ? 'Начислено $_cashbackEarned баллов'
                    : 'Баллы начислятся после подтверждения',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.gold,
                    fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: S.x32),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () {
                  widget.cart.clear();
                  Navigator.pop(context);
                },
                child: const Text('ВЕРНУТЬСЯ В МАГАЗИН'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
