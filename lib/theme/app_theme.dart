import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Central design system for Sinhala Office Assist.
///
/// Clean, professional, office/government feel: deep trustworthy blue as
/// primary, muted teal as accent, white/light-gray backgrounds, and
/// Noto Sans Sinhala throughout with extra line-height for legibility.
class AppTheme {
  AppTheme._();

  static const Color primaryBlue = Color(0xFF1B3A5C);
  static const Color primaryBlueLight = Color(0xFF2C5079);
  static const Color accentTeal = Color(0xFF3E8E8A);
  static const Color backgroundLight = Color(0xFFF7F8FA);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1C2530);
  static const Color textSecondary = Color(0xFF5B6470);
  static const Color divider = Color(0xFFE1E4E8);

  static const double borderRadius = 8.0;
  static const double sinhalaLineHeight = 1.5;

  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.notoSansSinhalaTextTheme();

    final textTheme = baseTextTheme.copyWith(
      headlineLarge: baseTextTheme.headlineLarge?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        height: sinhalaLineHeight,
      ),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        height: sinhalaLineHeight,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        height: sinhalaLineHeight,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        height: sinhalaLineHeight,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: textPrimary,
        height: sinhalaLineHeight,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: textSecondary,
        height: sinhalaLineHeight,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: surfaceWhite,
        height: sinhalaLineHeight,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: backgroundLight,
      colorScheme: const ColorScheme.light(
        primary: primaryBlue,
        secondary: accentTeal,
        surface: surfaceWhite,
        error: Color(0xFFB3261E),
        onPrimary: surfaceWhite,
        onSecondary: surfaceWhite,
        onSurface: textPrimary,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: primaryBlue,
        foregroundColor: surfaceWhite,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: surfaceWhite,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceWhite,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentTeal,
          foregroundColor: surfaceWhite,
          disabledBackgroundColor: accentTeal.withValues(alpha: 0.4),
          elevation: 1,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryBlue,
          side: const BorderSide(color: primaryBlue, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          textStyle: textTheme.labelLarge?.copyWith(color: primaryBlue),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: divider,
        thickness: 1,
        space: 1,
      ),
      iconTheme: const IconThemeData(color: primaryBlue),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );
  }
}
