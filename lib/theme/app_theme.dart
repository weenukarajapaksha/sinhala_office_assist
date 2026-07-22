import 'package:flutter/material.dart';

/// Central design system for Sinhala Office Assist ("E-Lekam").
///
/// Clean, professional, office/government feel: deep trustworthy blue as
/// primary, muted teal as accent, and Noto Sans Sinhala throughout with
/// extra line-height for legibility. Both a light and dark variant share
/// the same structure via [_themeFor].
///
/// The font is bundled locally (assets/fonts) rather than fetched at
/// runtime via google_fonts, so text renders correctly offline.
class AppTheme {
  AppTheme._();

  static const String fontFamily = 'NotoSansSinhala';

  static const Color primaryBlue = Color(0xFF1B3A5C);
  static const Color primaryBlueLight = Color(0xFF2C5079);
  static const Color accentTeal = Color(0xFF3E8E8A);
  static const Color backgroundLight = Color(0xFFF7F8FA);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1C2530);
  static const Color textSecondary = Color(0xFF5B6470);
  static const Color divider = Color(0xFFE1E4E8);

  static const Color backgroundDark = Color(0xFF10161D);
  static const Color surfaceDark = Color(0xFF1B232C);
  static const Color textPrimaryDark = Color(0xFFE7EAED);
  static const Color textSecondaryDark = Color(0xFF9AA5B1);
  static const Color dividerDark = Color(0xFF2B333C);

  static const double borderRadius = 12.0;
  static const double sinhalaLineHeight = 1.5;

  /// Standard duration/curve for the app's subtle, professional motion —
  /// list entrances, AppBar crossfades, and expand/collapse transitions.
  static const Duration motionDuration = Duration(milliseconds: 220);
  static const Curve motionCurve = Curves.easeOutCubic;

  static ThemeData get lightTheme => _themeFor(isDark: false);
  static ThemeData get darkTheme => _themeFor(isDark: true);

  static ThemeData _themeFor({required bool isDark}) {
    final background = isDark ? backgroundDark : backgroundLight;
    final surface = isDark ? surfaceDark : surfaceWhite;
    final onSurfacePrimary = isDark ? textPrimaryDark : textPrimary;
    final onSurfaceSecondary = isDark ? textSecondaryDark : textSecondary;
    final dividerColor = isDark ? dividerDark : divider;
    final appBarBackground = isDark ? surfaceDark : primaryBlue;
    final appBarForeground = isDark ? textPrimaryDark : surfaceWhite;

    final baseTextTheme = isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme;

    final textTheme = baseTextTheme.copyWith(
      headlineLarge: baseTextTheme.headlineLarge?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: onSurfacePrimary,
        height: sinhalaLineHeight,
      ),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: onSurfacePrimary,
        height: sinhalaLineHeight,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: onSurfacePrimary,
        height: sinhalaLineHeight,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: onSurfacePrimary,
        height: sinhalaLineHeight,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: onSurfacePrimary,
        height: sinhalaLineHeight,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: onSurfaceSecondary,
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
      brightness: isDark ? Brightness.dark : Brightness.light,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: background,
      colorScheme: isDark
          ? ColorScheme.dark(
              primary: primaryBlueLight,
              secondary: accentTeal,
              surface: surface,
              error: const Color(0xFFCF6679),
              onPrimary: surfaceWhite,
              onSecondary: surfaceWhite,
              onSurface: onSurfacePrimary,
            )
          : const ColorScheme.light(
              primary: primaryBlue,
              secondary: accentTeal,
              surface: surfaceWhite,
              error: Color(0xFFB3261E),
              onPrimary: surfaceWhite,
              onSecondary: surfaceWhite,
              onSurface: textPrimary,
            ),
      textTheme: textTheme,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: appBarBackground,
        foregroundColor: appBarForeground,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: appBarForeground,
          fontWeight: FontWeight.w600,
        ),
        toolbarTextStyle: textTheme.bodyMedium,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.35 : 0.10),
        clipBehavior: Clip.antiAlias,
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
          animationDuration: motionDuration,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? textPrimaryDark : primaryBlue,
          side: BorderSide(
            color: isDark ? textPrimaryDark : primaryBlue,
            width: 1.2,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            color: isDark ? textPrimaryDark : primaryBlue,
          ),
          animationDuration: motionDuration,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          highlightColor: accentTeal.withValues(alpha: 0.12),
          hoverColor: accentTeal.withValues(alpha: 0.08),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accentTeal,
        foregroundColor: surfaceWhite,
        elevation: 2,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius + 4),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: accentTeal.withValues(alpha: 0.16),
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.bodyMedium?.copyWith(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected
                ? (isDark ? textPrimaryDark : primaryBlue)
                : onSurfaceSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected
                ? (isDark ? textPrimaryDark : primaryBlue)
                : onSurfaceSecondary,
          );
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accentTeal;
          return null;
        }),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accentTeal;
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accentTeal.withValues(alpha: 0.5);
          }
          return null;
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accentTeal,
        linearTrackColor: dividerColor,
        circularTrackColor: dividerColor,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? surfaceDark : primaryBlue,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: isDark ? textPrimaryDark : surfaceWhite,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        actionTextColor: accentTeal,
      ),
      dividerTheme: DividerThemeData(
        color: dividerColor,
        thickness: 1,
        space: 1,
      ),
      iconTheme: IconThemeData(color: isDark ? textPrimaryDark : primaryBlue),
      splashColor: accentTeal.withValues(alpha: 0.10),
      highlightColor: accentTeal.withValues(alpha: 0.06),
    );
  }
}
