import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/settings_repository.dart';

final themeModeProvider = StateProvider<bool>((ref) {
  return SettingsRepository.instance.isDarkMode;
});

class AppTheme {
  // Color Palette
  static const Color primaryColor = Color(0xFF1A56FF);
  static const Color primaryDark = Color(0xFF0A3BCC);
  static const Color accentColor = Color(0xFF00E5FF);
  static const Color successColor = Color(0xFF00C853);
  static const Color warningColor = Color(0xFFFFAB00);
  static const Color errorColor = Color(0xFFFF3D00);

  static const Color darkBg = Color(0xFF0D0D0F);
  static const Color darkSurface = Color(0xFF1A1A1F);
  static const Color darkCard = Color(0xFF242429);
  static const Color darkBorder = Color(0xFF2E2E35);

  static const Color lightBg = Color(0xFFF5F7FF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFEEF1FF);

  static TextTheme _buildTextTheme(bool isDark) {
    final baseColor = isDark ? Colors.white : const Color(0xFF0D0D0F);
    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 32, fontWeight: FontWeight.w700, color: baseColor,
      ),
      displayMedium: TextStyle(
        fontSize: 26, fontWeight: FontWeight.w700, color: baseColor,
      ),
      titleLarge: TextStyle(
        fontSize: 20, fontWeight: FontWeight.w600, color: baseColor,
      ),
      titleMedium: TextStyle(
        fontSize: 16, fontWeight: FontWeight.w500, color: baseColor,
      ),
      bodyLarge: TextStyle(
        fontSize: 16, fontWeight: FontWeight.w400, color: baseColor,
      ),
      bodyMedium: TextStyle(
        fontSize: 14, fontWeight: FontWeight.w400,
        color: baseColor.withOpacity(0.7),
      ),
      labelLarge: TextStyle(
        fontSize: 14, fontWeight: FontWeight.w600, color: baseColor,
      ),
    );
  }

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
    ).copyWith(
      primary: primaryColor,
      secondary: accentColor,
      surface: lightSurface,
      background: lightBg,
      error: errorColor,
    ),
    scaffoldBackgroundColor: lightBg,
    textTheme: _buildTextTheme(false),
    appBarTheme: AppBarTheme(
      backgroundColor: lightSurface,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: const TextStyle(
        fontSize: 18, fontWeight: FontWeight.w700,
        color: Color(0xFF0D0D0F),
      ),
      iconTheme: const IconThemeData(color: Color(0xFF0D0D0F)),
    ),
    cardTheme: CardThemeData(
      color: lightSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE0E4F0), width: 1),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 15, fontWeight: FontWeight.w600,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
  );

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
    ).copyWith(
      primary: primaryColor,
      secondary: accentColor,
      surface: darkSurface,
      background: darkBg,
      error: errorColor,
    ),
    scaffoldBackgroundColor: darkBg,
    textTheme: _buildTextTheme(true),
    appBarTheme: AppBarTheme(
      backgroundColor: darkBg,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: const TextStyle(
        fontSize: 18, fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
      iconTheme: const IconThemeData(color: Colors.white),
    ),
    cardTheme: CardThemeData(
      color: darkCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: darkBorder, width: 1),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 15, fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}
