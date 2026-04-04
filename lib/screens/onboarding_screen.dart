import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../main.dart';

const _brandBlue = Color(0xFF0033A0);
const _brandBlueLight = Color(0xFF1A5EC7);

/// Shown once after first OTP login when the user profile is incomplete.
/// Collects first name, last name, and date of birth, then patches /users/me.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  DateTime? _birthDate;
  bool _isSaving = false;
  bool _success = false;

  late final AnimationController _entranceCtrl;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeIn = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );
    _slideUp = Tween(begin: const Offset(0, 0.12), end: Offset.zero).animate(
      CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.15, 0.75, curve: Curves.easeOutCubic)),
    );
    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _entranceCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1920),
      lastDate: now,
      locale: const Locale('ru'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: _brandBlue,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  Future<void> _save() async {
    final firstName = _firstNameCtrl.text.trim();
    final lastName = _lastNameCtrl.text.trim();

    if (firstName.isEmpty) {
      _showError('Введите имя');
      return;
    }
    if (lastName.isEmpty) {
      _showError('Введите фамилию');
      return;
    }
    if (_birthDate == null) {
      _showError('Укажите дату рождения');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final fullName = '$firstName $lastName';
      final birthStr = _birthDate!.toIso8601String().split('T').first;

      await ApiService.dio.patch('/api/v1/users/me', data: {
        'full_name': fullName,
      });

      await ApiService.dio.patch('/api/v1/users/me/birthday', data: {
        'birth_date': birthStr,
      });

      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      await auth.fetchProfile();
      await auth.fetchLoyalty();

      if (!mounted) return;

      // Show success before leaving
      setState(() {
        _isSaving = false;
        _success = true;
      });
      HapticFeedback.mediumImpact();

      await Future.delayed(const Duration(milliseconds: 1000));
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showError('Ошибка сохранения: $e');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(msg, style: const TextStyle(fontSize: 13))),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.5),
                radius: 1.4,
                colors: [
                  isDark ? const Color(0xFF0A1628) : const Color(0xFFE2ECF8),
                  isDark ? const Color(0xFF060C16) : const Color(0xFFF0F0EE),
                  AppColors.background,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: const SizedBox.expand(),
          ),

          // Decorative
          Positioned(
            top: -60,
            left: -80,
            child: Opacity(
              opacity: 0.04,
              child: Container(
                width: 240,
                height: 240,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: _brandBlue),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: FadeTransition(
                  opacity: _fadeIn,
                  child: SlideTransition(
                    position: _slideUp,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: _success ? _buildSuccess() : _buildForm(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return Column(
      key: const ValueKey('success'),
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 500),
          curve: Curves.elasticOut,
          builder: (_, val, child) => Transform.scale(scale: val, child: child),
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF2E7D32).withValues(alpha: 0.12),
            ),
            child: const Icon(Icons.check_rounded, size: 44, color: Color(0xFF2E7D32)),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Профиль готов!',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          'Добро пожаловать в TOOLOR',
          style: TextStyle(fontSize: 14, color: AppColors.textTertiary),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      key: const ValueKey('form'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset('assets/images/toolor_logo.png', width: 100),
        const SizedBox(height: 28),

        // Step indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _brandBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Шаг 2 из 2',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _brandBlue,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        Text(
          'Расскажите о себе',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Чтобы начать копить баллы лояльности',
          style: TextStyle(fontSize: 14, color: AppColors.textTertiary, height: 1.4),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 36),

        // First name
        _buildLabel('Имя'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _firstNameCtrl,
          hint: 'Иван',
          icon: Icons.person_outline,
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 20),

        // Last name
        _buildLabel('Фамилия'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _lastNameCtrl,
          hint: 'Иванов',
          icon: Icons.person_outline,
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 20),

        // Birth date
        _buildLabel('Дата рождения'),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickBirthDate,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: _birthDate != null
                  ? Border.all(color: _brandBlue.withValues(alpha: 0.3))
                  : null,
              boxShadow: _birthDate != null
                  ? [BoxShadow(color: _brandBlue.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 3))]
                  : null,
            ),
            child: Row(
              children: [
                Icon(Icons.cake_outlined, size: 20, color: _birthDate != null ? _brandBlue : AppColors.textTertiary),
                const SizedBox(width: 12),
                Text(
                  _birthDate != null
                      ? DateFormat('dd MMMM yyyy', 'ru').format(_birthDate!)
                      : 'Выберите дату',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: _birthDate != null ? FontWeight.w500 : FontWeight.w400,
                    color: _birthDate != null ? AppColors.textPrimary : AppColors.textTertiary,
                  ),
                ),
                const Spacer(),
                Icon(Icons.chevron_right, size: 20, color: AppColors.textTertiary),
              ],
            ),
          ),
        ),
        const SizedBox(height: 36),

        // Save button
        SizedBox(
          width: double.infinity,
          height: 54,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: [_brandBlue, _brandBlueLight],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: _brandBlue.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isSaving ? null : () {
                HapticFeedback.mediumImpact();
                _save();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 1.2),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text('НАЧАТЬ'),
            ),
          ),
        ),

        // Bonus hint
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF2E7D32).withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.card_giftcard, size: 16, color: Color(0xFF2E7D32)),
              const SizedBox(width: 8),
              Text(
                '+1000 бонусных баллов за заполнение!',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2E7D32),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: _brandBlue.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        textCapitalization: textCapitalization,
        style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: AppColors.textTertiary, fontWeight: FontWeight.w400),
          prefixIcon: Icon(icon, size: 20, color: AppColors.textTertiary),
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _brandBlue, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}
