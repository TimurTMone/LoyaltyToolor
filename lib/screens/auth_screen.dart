import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  bool _obscurePassword = true;

  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _referralCtrl = TextEditingController();

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    _referralCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = _phoneCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (phone.isEmpty || password.isEmpty) {
      _showError('Заполните все поля');
      return;
    }

    if (password.length < 4) {
      _showError('Пароль минимум 4 символа');
      return;
    }

    final auth = context.read<AuthProvider>();

    if (_isLogin) {
      await auth.login(phone, password);
    } else {
      final name = _nameCtrl.text.trim();
      if (name.isEmpty) {
        _showError('Введите имя');
        return;
      }
      final referral = _referralCtrl.text.trim();
      await auth.register(phone, password, name, referralCode: referral.isNotEmpty ? referral : null);
    }

    if (!mounted) return;

    if (auth.error != null) {
      _showError(auth.error!);
      auth.clearError();
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.3),
            radius: 1.2,
            colors: [
              isDark ? const Color(0xFF0F1620) : const Color(0xFFEAF1F8),
              AppColors.background,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/images/toolor_logo.png', width: 180),
                  const SizedBox(height: 6),
                  Text(
                    'LOYALTY  &  STORE',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w400, letterSpacing: 6, color: AppColors.textTertiary),
                  ),
                  const SizedBox(height: 40),

                  // Tab toggle
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        _tab('Вход', _isLogin),
                        _tab('Регистрация', !_isLogin),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Phone
                  _field(
                    controller: _phoneCtrl,
                    hint: '+996 ...',
                    label: 'Телефон',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 14),

                  // Name (register only)
                  if (!_isLogin) ...[
                    _field(
                      controller: _nameCtrl,
                      hint: 'Ваше имя',
                      label: 'Имя',
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Password
                  _field(
                    controller: _passwordCtrl,
                    hint: '••••••',
                    label: 'Пароль',
                    icon: Icons.lock_outline,
                    obscure: _obscurePassword,
                    suffix: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 20,
                        color: AppColors.textTertiary,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),

                  // Referral (register only)
                  if (!_isLogin) ...[
                    const SizedBox(height: 14),
                    _field(
                      controller: _referralCtrl,
                      hint: 'Код друга (необязательно)',
                      label: 'Реферальный код',
                      icon: Icons.card_giftcard_outlined,
                    ),
                  ],

                  const SizedBox(height: 28),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: auth.isLoading ? null : () {
                        HapticFeedback.mediumImpact();
                        _submit();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0033A0),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 1),
                      ),
                      child: auth.isLoading
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(_isLogin ? 'ВОЙТИ' : 'СОЗДАТЬ АККАУНТ'),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Demo mode link
                  TextButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      auth.demoLogin();
                    },
                    child: Text(
                      'Попробовать демо',
                      style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tab(String label, bool active) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _isLogin = label == 'Вход');
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? AppColors.accent.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? AppColors.accent : AppColors.textTertiary,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    Widget? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscure,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.textTertiary),
            prefixIcon: Icon(icon, size: 20, color: AppColors.textTertiary),
            suffixIcon: suffix,
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}
