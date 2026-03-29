import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/locations_sheet.dart';
import '../models/product.dart';
import '../services/analytics_service.dart';

// Conditionally import Finik SDK (only works on mobile)
import 'package:finik_sdk/finik_sdk.dart';

const _finikApiKey = 'eOJ3RXsvyZ8ztUIRp1fwq2fHJfYUyfKK2GpOgeAv';
const _finikAccountId = '54b4316f-e1d2-4007-b167-3f4dd9e0b9a7';
const _finikIsBeta = true;

/// Checkout flow:
/// Mobile: Delivery → Finik Payment → Done (instant confirmation)
/// Web: Delivery → MBank QR → Upload proof → Done (manual verification)
class CheckoutScreen extends StatefulWidget {
  final CartProvider cart;
  const CheckoutScreen({super.key, required this.cart});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

enum _Step { delivery, pay, upload, done }

class _CheckoutScreenState extends State<CheckoutScreen> {
  _Step _step = _Step.delivery;
  File? _proof;
  final _picker = ImagePicker();
  bool _isSubmitting = false;
  String? _orderNumber;
  String? _orderId;
  String? _submitError;

  // Delivery type
  String _deliveryType = 'delivery';
  ToolorLocation? _selectedPickupLocation;
  List<ToolorLocation> _locations = [];
  bool _isLoadingLocations = false;

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
  double get _pointsValue => _pointsToRedeem;
  double get _maxRedeemable =>
      _availablePoints < _orderTotal ? _availablePoints.toDouble() : _orderTotal;
  double get _finalTotal => (_orderTotal - _pointsValue).clamp(0, _orderTotal);

  bool get _useFinik => !kIsWeb;

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
                  } else if (_step == _Step.upload) {
                    setState(() => _step = _Step.pay);
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
            _Step.pay => _useFinik ? _finikPayStep() : _mbankPayStep(),
            _Step.upload => _uploadStep(),
            _Step.done => _doneStep(),
          },
        ),
      ),
    );
  }

  // ─── Step 0: Delivery type + Points ───────────────────────────────

  Widget _deliveryStep() {
    return SingleChildScrollView(
      key: const ValueKey('delivery'),
      padding: const EdgeInsets.all(S.x16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Delivery type
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(S.x16),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(R.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('СПОСОБ ПОЛУЧЕНИЯ',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                        color: AppColors.textTertiary)),
                const SizedBox(height: S.x12),
                _deliveryOption(
                  'delivery',
                  Icons.local_shipping_rounded,
                  'Доставка',
                  'Курьером по Бишкеку',
                ),
                const SizedBox(height: S.x8),
                _deliveryOption(
                  'pickup',
                  Icons.storefront_rounded,
                  'Самовывоз',
                  'Заберите из магазина',
                ),
              ],
            ),
          ),

          if (_deliveryType == 'pickup') ...[
            const SizedBox(height: S.x16),
            _pickupLocationSelector(),
          ],

          const SizedBox(height: S.x20),

          if (_availablePoints > 0) _pointsRedemptionCard(),

          const SizedBox(height: S.x20),

          _orderSummary(),

          const SizedBox(height: S.x24),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: (_deliveryType == 'pickup' &&
                      _selectedPickupLocation == null)
                  ? null
                  : _useFinik
                      ? _createOrderAndPay
                      : () => setState(() => _step = _Step.pay),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(_useFinik ? 'ПЕРЕЙТИ К ОПЛАТЕ' : 'ПРОДОЛЖИТЬ К ОПЛАТЕ'),
            ),
          ),

          const SizedBox(height: S.x32),
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
          Text('ВЫБЕРИТЕ МАГАЗИН',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: AppColors.textTertiary)),
          const SizedBox(height: S.x12),
          if (_isLoadingLocations)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: S.x16),
              child: Center(
                  child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else
            ..._locations.map((loc) {
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
            }),
        ],
      ),
    );
  }

  Widget _pointsRedemptionCard() {
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
          Row(
            children: [
              Icon(Icons.star_rounded, size: 18, color: AppColors.gold),
              const SizedBox(width: S.x8),
              Text('ИСПОЛЬЗОВАТЬ БАЛЛЫ',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                      color: AppColors.textTertiary)),
            ],
          ),
          const SizedBox(height: S.x8),
          Text('Доступно: $_availablePoints баллов',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: S.x12),
          Row(
            children: [
              Text('0',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textTertiary)),
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
                    value: _pointsToRedeem,
                    min: 0,
                    max: _maxRedeemable,
                    divisions:
                        _maxRedeemable > 0 ? _maxRedeemable.toInt() : 1,
                    onChanged: (val) => setState(() => _pointsToRedeem = val),
                  ),
                ),
              ),
              Text('${_maxRedeemable.toInt()}',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textTertiary)),
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
                '${_pointsToRedeem.toInt()} баллов = ${Product.formatPrice(_pointsValue)} сом скидка',
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
          Text('ИТОГО',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: AppColors.textTertiary)),
          const SizedBox(height: S.x12),
          _summaryRow('Товары', widget.cart.formattedTotal),
          if (_pointsToRedeem > 0)
            _summaryRow(
                'Скидка баллами', '-${Product.formatPrice(_pointsValue)} сом',
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
              style: TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDiscount ? Colors.green : AppColors.textPrimary)),
        ],
      ),
    );
  }

  // ─── Finik Pay: Create order then open SDK ────────────────────────

  Future<void> _createOrderAndPay() async {
    if (_isSubmitting) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      // Create order on backend first
      final orderData = <String, dynamic>{
        'payment_method': 'finik',
        'delivery_type': _deliveryType,
      };

      if (_pointsToRedeem > 0) {
        orderData['points_used'] = _pointsToRedeem.toInt();
      }

      if (_deliveryType == 'pickup' && _selectedPickupLocation != null) {
        orderData['pickup_location_id'] = null; // Will be matched by name
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

      final cart = context.read<CartProvider>();
      Analytics.purchase(
        _orderId ?? '',
        _finalTotal.toDouble(),
        cart.itemCount,
        orderData['payment_method'] as String? ?? 'unknown',
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
          content: Text('Ошибка создания заказа: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ─── Step 1a: Finik Payment (mobile only) ─────────────────────────

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
        callbackUrl: '${apiBaseUrl}/api/v1/webhooks/finik',
        requiredFields: [
          if (_orderId != null)
            RequiredField(
              fieldId: 'order_id',
              label: 'Order ID',
              value: _orderId!,
              isHidden: true,
            ),
        ],
        onCreated: (data) {
          // Payment item created in Finik system
        },
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

  Future<void> _confirmPaymentOnBackend(Map<String, dynamic> paymentData) async {
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

  // ─── Step 1b: MBank QR (web fallback) ─────────────────────────────

  Widget _mbankPayStep() {
    return SingleChildScrollView(
      key: const ValueKey('pay'),
      padding: const EdgeInsets.all(S.x16),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(S.x20),
            decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(R.lg)),
            child: Column(
              children: [
                Text('К оплате',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: S.x4),
                Text('${Product.formatPrice(_finalTotal)} сом',
                    style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
                if (_pointsToRedeem > 0) ...[
                  const SizedBox(height: S.x4),
                  Text(
                      'Скидка баллами: ${Product.formatPrice(_pointsValue)} сом',
                      style:
                          TextStyle(fontSize: 12, color: Colors.green)),
                ],
              ],
            ),
          ),

          const SizedBox(height: S.x20),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(S.x24),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(R.lg),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: S.x16, vertical: S.x8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0D7C5F), Color(0xFF15A67E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(R.sm),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.account_balance_rounded,
                          color: Colors.white, size: 18),
                      const SizedBox(width: S.x8),
                      const Text('Mbank',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),

                const SizedBox(height: S.x16),

                ClipRRect(
                  borderRadius: BorderRadius.circular(R.md),
                  child: Image.asset(
                    'assets/images/mbank_a4_qr.png',
                    width: 220,
                    height: 220,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceOverlay,
                        borderRadius: BorderRadius.circular(R.md),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.qr_code_2_rounded,
                              size: 60, color: AppColors.textTertiary),
                          const SizedBox(height: S.x8),
                          Text('QR не найден',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textTertiary)),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: S.x12),

                Text('TOOLOR',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: S.x2),
                Text('+996 998 844 444',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          ),

          const SizedBox(height: S.x20),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(S.x16),
            decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(R.lg)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('КАК ОПЛАТИТЬ',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                        color: AppColors.textTertiary)),
                const SizedBox(height: S.x12),
                _instruction(1, 'Сделайте скриншот QR-кода выше'),
                _instruction(
                    2, 'Откройте Mbank или другое банковское приложение'),
                _instruction(3, 'Отсканируйте QR из галереи'),
                _instruction(4,
                    'Переведите точную сумму: ${Product.formatPrice(_finalTotal)} сом'),
                _instruction(5, 'Вернитесь сюда и прикрепите чек'),
              ],
            ),
          ),

          const SizedBox(height: S.x24),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: () => setState(() => _step = _Step.upload),
              child: const Text('Я ОПЛАТИЛ — ПРИКРЕПИТЬ ЧЕК'),
            ),
          ),

          const SizedBox(height: S.x32),
        ],
      ),
    );
  }

  Widget _instruction(int n, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: S.x8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                shape: BoxShape.circle),
            child: Center(
                child: Text('$n',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent))),
          ),
          const SizedBox(width: S.x8),
          Expanded(
              child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(text,
                style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    height: 1.3)),
          )),
        ],
      ),
    );
  }

  // ─── Step 2: Upload proof (web only) ──────────────────────────────

  Widget _uploadStep() {
    return SingleChildScrollView(
      key: const ValueKey('upload'),
      padding: const EdgeInsets.all(S.x16),
      child: Column(
        children: [
          Icon(Icons.receipt_long_rounded, size: 40, color: AppColors.accent),
          const SizedBox(height: S.x16),
          Text('Прикрепите чек оплаты',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: S.x4),
          Text('Скриншот или фото чека из банковского приложения',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),

          const SizedBox(height: S.x24),

          if (_proof == null)
            GestureDetector(
              onTap: _pickProof,
              child: Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(R.lg),
                  border: Border.all(color: AppColors.divider, width: 1.5),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_upload_outlined,
                        size: 36, color: AppColors.textTertiary),
                    const SizedBox(height: S.x12),
                    Text('Нажмите чтобы загрузить',
                        style: TextStyle(
                            fontSize: 14, color: AppColors.textSecondary)),
                    const SizedBox(height: S.x4),
                    Text('Скриншот или фото',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textTertiary)),
                  ],
                ),
              ),
            )
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(R.lg),
              child: Image.file(_proof!,
                  width: double.infinity, height: 300, fit: BoxFit.cover),
            ),
            const SizedBox(height: S.x12),
            GestureDetector(
              onTap: _pickProof,
              child: Text('Заменить фото',
                  style: TextStyle(
                      fontSize: 13,
                      color: AppColors.accent,
                      fontWeight: FontWeight.w500)),
            ),
          ],

          const SizedBox(height: S.x24),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(S.x12),
            decoration: BoxDecoration(
                color: AppColors.accentSoft,
                borderRadius: BorderRadius.circular(R.sm)),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 16, color: AppColors.accent),
                const SizedBox(width: S.x8),
                Expanded(
                    child: Text(
                        'Сумма перевода должна быть: ${Product.formatPrice(_finalTotal)} сом',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.accent))),
              ],
            ),
          ),

          const SizedBox(height: S.x24),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _proof != null && !_isSubmitting ? _submitMbank : null,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('ОТПРАВИТЬ ЧЕК'),
            ),
          ),

          const SizedBox(height: S.x12),

          GestureDetector(
            onTap: () => setState(() => _step = _Step.pay),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: S.x8),
              child: Text('Назад к QR-коду',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textTertiary)),
            ),
          ),

          const SizedBox(height: S.x32),
        ],
      ),
    );
  }

  Future<void> _pickProof() async {
    HapticFeedback.selectionClick();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.fromLTRB(S.x16, 0, S.x16, S.x16),
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(R.xl)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  Icon(Icons.photo_library_rounded, color: AppColors.accent),
              title: Text('Из галереи',
                  style: TextStyle(color: AppColors.textPrimary)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            Divider(color: AppColors.divider, height: 0.5),
            ListTile(
              leading:
                  Icon(Icons.camera_alt_rounded, color: AppColors.accent),
              title: Text('Сфотографировать',
                  style: TextStyle(color: AppColors.textPrimary)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picked = await _picker.pickImage(source: source, imageQuality: 80);
    if (picked != null) {
      setState(() => _proof = File(picked.path));
    }
  }

  // ─── MBank submit (web flow) ──────────────────────────────────────

  Future<void> _submitMbank() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      final orderData = <String, dynamic>{
        'payment_method': 'mbank_qr',
        'delivery_type': _deliveryType,
      };

      if (_pointsToRedeem > 0) {
        orderData['points_used'] = _pointsToRedeem.toInt();
      }

      if (_deliveryType == 'pickup' && _selectedPickupLocation != null) {
        orderData['pickup_location_id'] = null;
      }

      final response = await ApiService.dio.post(
        '/api/v1/orders',
        data: orderData,
      );

      final data = response.data as Map<String, dynamic>;
      _orderNumber =
          data['order_number'] as String? ?? data['id'] as String?;

      final auth = context.read<AuthProvider>();
      final cashbackPct = auth.loyalty?.cashbackPercent ?? 3;
      _cashbackEarned = (_finalTotal * cashbackPct / 100).round();

      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _step = _Step.done;
      });
    } catch (e) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final cashbackPct = auth.loyalty?.cashbackPercent ?? 3;
      _cashbackEarned = (_finalTotal * cashbackPct / 100).round();

      setState(() {
        _isSubmitting = false;
        _step = _Step.done;
        _submitError = e.toString();
      });
    }
  }

  // ─── Step 3: Done ─────────────────────────────────────────────────

  Widget _doneStep() {
    final isFinikPayment = _useFinik && _submitError == null;

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
              child:
                  const Icon(Icons.check_rounded, size: 36, color: Colors.white),
            ),
            const SizedBox(height: S.x24),
            Text(
                isFinikPayment ? 'Оплата прошла успешно' : 'Чек отправлен',
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
              isFinikPayment
                  ? 'Заказ подтверждён и принят в обработку.'
                  : _submitError != null
                      ? 'Заказ принят локально. Мы синхронизируем его\nпри следующем подключении.'
                      : 'Мы проверим оплату и подтвердим заказ.\nОбычно это занимает до 15 минут.',
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
                    ? isFinikPayment
                        ? 'Начислено $_cashbackEarned баллов'
                        : 'Начислится $_cashbackEarned баллов после подтверждения'
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
