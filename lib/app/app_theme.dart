import 'package:flutter/material.dart';

/// สีหลักของแอป (โทนมืดนุ่มตา — ใช้หลังเข้าแอป)
abstract final class AppColors {
  static const Color canvas = Color(0xFF13141A);
  static const Color surface = Color(0xFF1B1C24);
  static const Color surfaceElevated = Color(0xFF23242E);
  static const Color border = Color(0xFF343648);
  static const Color textPrimary = Color(0xFFE6E8EF);
  static const Color textSecondary = Color(0xFF9CA3B8);
  static const Color textMuted = Color(0xFF6B7288);
  static const Color accent = Color(0xFFE3001B);
  static const Color accentSoft = Color(0xFF2A2226);
  static const Color topBar = Color(0xFF0E0F14);
  static const Color topBarFg = Color(0xFFE8E9F0);
}

abstract final class AppTheme {
  /// ธีมหลักของแอป (มืด)
  static ThemeData mainDark() {
    final ThemeData base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.canvas,
      colorScheme: ColorScheme.dark(
        primary: AppColors.accent,
        onPrimary: Color(0xFFFFFFFF),
        secondary: AppColors.accent,
        onSecondary: Color(0xFFFFFFFF),
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        onSurfaceVariant: AppColors.textSecondary,
        surfaceContainerHighest: AppColors.surfaceElevated,
        error: Color(0xFFFF6B6B),
        onError: Color(0xFF1A0505),
        outline: AppColors.border,
        outlineVariant: Color(0xFF2A2B36),
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.canvas,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.topBar,
        foregroundColor: AppColors.topBarFg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: AppColors.topBarFg,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 1,
        shadowColor: Colors.black54,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: DividerThemeData(color: AppColors.border.withValues(alpha: 0.55)),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppColors.surfaceElevated,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 10,
        showUnselectedLabels: true,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceElevated,
        contentTextStyle: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
        ),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      primaryTextTheme: base.primaryTextTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      listTileTheme: ListTileThemeData(
        titleTextStyle: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
        subtitleTextStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        iconColor: AppColors.textSecondary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
        hintStyle: const TextStyle(color: AppColors.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent, width: 2),
        ),
      ),
    );
  }
}

/// พื้นดำ + ตัวอักษรขาว — ใช้เฉพาะ Splash และหน้า Login
abstract final class SplashTheme {
  static const Color background = Color(0xFF000000);
  static const Color text = Color(0xFFFFFFFF);

  static ThemeData overlay() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.dark(
        primary: AppColors.accent,
        onPrimary: Colors.white,
        surface: Color(0xFF121212),
        onSurface: text,
      ),
    );
  }
}
