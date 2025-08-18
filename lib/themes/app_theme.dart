import 'package:flutter/material.dart';
import 'package:foxfunds/services/settings_service.dart';

class AppTheme {
  static ThemeData _base({required bool dark, required Color accent}) {
    // Start from default light/dark scheme and force primary and related roles to the exact accent
    final baseScheme = dark ? const ColorScheme.dark() : const ColorScheme.light();
    final scheme = baseScheme.copyWith(
      primary: accent,
      secondary: accent,
      tertiary: accent,
      primaryContainer: accent,
      secondaryContainer: accent,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onTertiary: Colors.white,
    );

    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: scheme.brightness,
      scaffoldBackgroundColor: dark ? Colors.grey[900] : Colors.grey[50],
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      iconTheme: IconThemeData(color: scheme.primary),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) => scheme.primary),
        trackColor: WidgetStateProperty.resolveWith((states) => scheme.primary.withOpacity(0.4)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.primary,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
    );
    return theme;
  }

  static ThemeData lightTheme() => _base(dark: false, accent: SettingsService.instance.accentColor);
  static ThemeData darkTheme() => _base(dark: true, accent: SettingsService.instance.accentColor);
  static ThemeData getTheme() => SettingsService.instance.isDarkMode ? darkTheme() : lightTheme();
}