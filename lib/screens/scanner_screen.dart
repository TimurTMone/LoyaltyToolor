import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _ctrl = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  bool _isProcessing = false;
  _ScanResult? _result;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing || _result != null) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || code.isEmpty) return;

    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    try {
      final resp = await ApiService.dio.post(
        '/api/v1/loyalty/scan',
        data: {'qr_token': code},
      );
      final data = resp.data;
      if (!mounted) return;
      setState(() {
        _result = _ScanResult(
          valid: data['valid'] == true,
          reason: data['reason'],
          customer: data['valid'] == true && data['customer'] != null
              ? _Customer.fromJson(data['customer'])
              : null,
        );
        _isProcessing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _result = _ScanResult(valid: false, reason: 'network_error');
        _isProcessing = false;
      });
    }
  }

  void _reset() {
    setState(() {
      _result = null;
      _isProcessing = false;
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Сканер QR', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: _result != null ? _resultView() : _cameraView(),
    );
  }

  Widget _cameraView() {
    return Stack(
      children: [
        MobileScanner(controller: _ctrl, onDetect: _onDetect),
        // Scan overlay
        Center(
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 2),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        // Instructions
        Positioned(
          bottom: 80,
          left: 0,
          right: 0,
          child: Text(
            _isProcessing ? 'Проверка...' : 'Наведите на QR код клиента',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
        if (_isProcessing)
          const Center(child: CircularProgressIndicator(color: Colors.white)),
      ],
    );
  }

  Widget _resultView() {
    final r = _result!;
    return Container(
      color: AppColors.background,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              if (r.valid && r.customer != null) _validCard(r.customer!) else _invalidCard(r.reason),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Сканировать снова', style: TextStyle(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _validCard(_Customer c) {
    final tierColors = {
      'bronze': Colors.orange,
      'silver': Colors.grey,
      'gold': Colors.amber,
      'platinum': Colors.purple,
    };
    final tierNames = {
      'bronze': 'Бронза',
      'silver': 'Серебро',
      'gold': 'Золото',
      'platinum': 'Платина',
    };
    final color = tierColors[c.tier] ?? Colors.grey;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: Colors.green.withValues(alpha: 0.1), blurRadius: 20)],
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 56),
          const SizedBox(height: 16),
          Text(c.name, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(c.phone, style: TextStyle(fontSize: 15, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              tierNames[c.tier] ?? c.tier,
              style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 14),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _stat('Баллы', '${c.points}'),
              _stat('Потрачено', '${c.totalSpent.toStringAsFixed(0)} сом'),
              _stat('Кешбэк', '${c.cashbackPercent}%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
        ],
      ),
    );
  }

  Widget _invalidCard(String? reason) {
    final messages = {
      'expired': 'QR код истёк.\nПопросите клиента обновить.',
      'invalid_signature': 'QR код поддельный.',
      'invalid_format': 'Неверный формат QR кода.',
      'user_not_found': 'Пользователь не найден.',
      'network_error': 'Ошибка сети. Проверьте интернет.',
    };
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.cancel_rounded, color: Colors.red, size: 56),
          const SizedBox(height: 16),
          Text('Недействителен', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text(
            messages[reason] ?? 'Неизвестная ошибка',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ScanResult {
  final bool valid;
  final String? reason;
  final _Customer? customer;
  _ScanResult({required this.valid, this.reason, this.customer});
}

class _Customer {
  final String name;
  final String phone;
  final String tier;
  final int points;
  final double totalSpent;
  final int cashbackPercent;

  _Customer({
    required this.name,
    required this.phone,
    required this.tier,
    required this.points,
    required this.totalSpent,
    required this.cashbackPercent,
  });

  factory _Customer.fromJson(Map<String, dynamic> json) {
    return _Customer(
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      tier: json['tier'] ?? 'bronze',
      points: json['points'] ?? 0,
      totalSpent: double.tryParse(json['total_spent']?.toString() ?? '0') ?? 0,
      cashbackPercent: json['cashback_percent'] ?? 3,
    );
  }
}
