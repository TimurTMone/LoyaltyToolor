import 'package:flutter/material.dart';

/// Design tokens following 8pt grid.
/// Dual palette — warm light by day, dark by night.

class AppColors {
  // ── Light palette ──
  static const Color backgroundLight = Color(0xFFF7F5F3);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceElevatedLight = Color(0xFFFFFFFF);
  static const Color surfaceOverlayLight = Color(0xFFF0EDEA);
  static const Color surfaceBrightLight = Color(0xFFE8E4E0);
  static const Color accentLight = Color(0xFF2C5F8A);
  static const Color accentSoftLight = Color(0xFFE8F0F8);
  static const Color goldLight = Color(0xFFB8922D);
  static const Color goldSoftLight = Color(0xFFF5F0E0);
  static const Color textPrimaryLight = Color(0xFF1A1A1A);
  static const Color textSecondaryLight = Color(0xFF6B6B6B);
  static const Color textTertiaryLight = Color(0xFFA0A0A0);
  static const Color textInverseLight = Color(0xFFFFFFFF);
  static const Color saleLight = Color(0xFFD32F2F);
  static const Color saleSoftLight = Color(0xFFFDE8E8);
  static const Color dividerLight = Color(0xFFE5E1DD);
  static const Color shimmerLight = Color(0xFFEDE9E5);

  // ── Dark palette ──
  static const Color backgroundDark = Color(0xFF0A0A0A);
  static const Color surfaceDark = Color(0xFF111111);
  static const Color surfaceElevatedDark = Color(0xFF1A1A1A);
  static const Color surfaceOverlayDark = Color(0xFF222222);
  static const Color surfaceBrightDark = Color(0xFF2C2C2C);
  static const Color accentDark = Color(0xFF4A90E2);
  static const Color accentSoftDark = Color(0xFF14202E);
  static const Color goldDark = Color(0xFFCFAA45);
  static const Color goldSoftDark = Color(0xFF2A2418);
  static const Color textPrimaryDark = Color(0xFFF2F2F2);
  static const Color textSecondaryDark = Color(0xFF999999);
  static const Color textTertiaryDark = Color(0xFF5A5A5A);
  static const Color textInverseDark = Color(0xFF0A0A0A);
  static const Color saleDark = Color(0xFFFF3B30);
  static const Color saleSoftDark = Color(0xFF3A1512);
  static const Color dividerDark = Color(0xFF1E1E1E);
  static const Color shimmerDark = Color(0xFF1A1A1A);

  // ── Shared (same in both) ──
  static const Color bronze = Color(0xFFCD7F32);
  static const Color silver = Color(0xFFB8B8B8);
  static const Color goldTier = Color(0xFFCFAA45);
  static const Color platinum = Color(0xFFDCDAD8);

  // ── Resolved by brightness ──
  static Color background = backgroundLight;
  static Color surface = surfaceLight;
  static Color surfaceElevated = surfaceElevatedLight;
  static Color surfaceOverlay = surfaceOverlayLight;
  static Color surfaceBright = surfaceBrightLight;
  static Color accent = accentLight;
  static Color accentSoft = accentSoftLight;
  static Color gold = goldLight;
  static Color goldSoft = goldSoftLight;
  static Color textPrimary = textPrimaryLight;
  static Color textSecondary = textSecondaryLight;
  static Color textTertiary = textTertiaryLight;
  static Color textInverse = textInverseLight;
  static Color sale = saleLight;
  static Color saleSoft = saleSoftLight;
  static Color divider = dividerLight;
  static Color shimmer = shimmerLight;

  static void applyBrightness(Brightness b) {
    final dark = b == Brightness.dark;
    background = dark ? backgroundDark : backgroundLight;
    surface = dark ? surfaceDark : surfaceLight;
    surfaceElevated = dark ? surfaceElevatedDark : surfaceElevatedLight;
    surfaceOverlay = dark ? surfaceOverlayDark : surfaceOverlayLight;
    surfaceBright = dark ? surfaceBrightDark : surfaceBrightLight;
    accent = dark ? accentDark : accentLight;
    accentSoft = dark ? accentSoftDark : accentSoftLight;
    gold = dark ? goldDark : goldLight;
    goldSoft = dark ? goldSoftDark : goldSoftLight;
    textPrimary = dark ? textPrimaryDark : textPrimaryLight;
    textSecondary = dark ? textSecondaryDark : textSecondaryLight;
    textTertiary = dark ? textTertiaryDark : textTertiaryLight;
    textInverse = dark ? textInverseDark : textInverseLight;
    sale = dark ? saleDark : saleLight;
    saleSoft = dark ? saleSoftDark : saleSoftLight;
    divider = dark ? dividerDark : dividerLight;
    shimmer = dark ? shimmerDark : shimmerLight;
  }
}

/// 8pt spatial scale
class S {
  static const double x2 = 2;
  static const double x4 = 4;
  static const double x6 = 6;
  static const double x8 = 8;
  static const double x12 = 12;
  static const double x16 = 16;
  static const double x20 = 20;
  static const double x24 = 24;
  static const double x32 = 32;
  static const double x40 = 40;
  static const double x48 = 48;
  static const double x56 = 56;
  static const double x64 = 64;
}

class R {
  static const double xs = 6;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double pill = 100;
}

class AppTheme {
  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final bg = dark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final surf = dark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final surfEl = dark ? AppColors.surfaceElevatedDark : AppColors.surfaceElevatedLight;
    final surfBr = dark ? AppColors.surfaceBrightDark : AppColors.surfaceBrightLight;
    final acc = dark ? AppColors.accentDark : AppColors.accentLight;
    final gld = dark ? AppColors.goldDark : AppColors.goldLight;
    final txt1 = dark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final txt3 = dark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;
    final sl = dark ? AppColors.saleDark : AppColors.saleLight;
    final div = dark ? AppColors.dividerDark : AppColors.dividerLight;

    final colorScheme = dark
        ? ColorScheme.dark(primary: acc, secondary: gld, surface: surf, error: sl)
        : ColorScheme.light(primary: acc, secondary: gld, surface: surf, error: sl);

    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      colorScheme: colorScheme,
      fontFamily: '.SF Pro Display',
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(color: txt1, fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.3),
        iconTheme: IconThemeData(color: txt1, size: 22),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surf,
        selectedItemColor: acc,
        unselectedItemColor: txt3,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5),
        unselectedLabelStyle: const TextStyle(fontSize: 10, letterSpacing: 0.5),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: acc,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: S.x24, vertical: S.x16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.pill)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: txt1,
          side: BorderSide(color: surfBr),
          padding: const EdgeInsets.symmetric(horizontal: S.x24, vertical: S.x16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.pill)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.3),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfEl,
        contentPadding: const EdgeInsets.symmetric(horizontal: S.x16, vertical: S.x12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(R.sm), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(R.sm), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(R.sm),
          borderSide: BorderSide(color: txt3, width: 1),
        ),
        hintStyle: TextStyle(color: txt3, fontSize: 14, fontWeight: FontWeight.w400),
      ),
      dividerTheme: DividerThemeData(color: div, thickness: 0.5, space: 0),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfEl,
        contentTextStyle: TextStyle(color: txt1, fontSize: 13),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.sm)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);
}
