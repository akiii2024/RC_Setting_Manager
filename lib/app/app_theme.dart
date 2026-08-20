import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppTheme {
  static const _japaneseFontFamily = 'NotoSansJP';
  static const _japaneseFontFallback = <String>[_japaneseFontFamily];

  static ThemeData light() {
    const primaryColor = Color(0xFF005BCF);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
    ).copyWith(
      primary: primaryColor,
      secondary: const Color(0xFF475E8C),
      tertiary: const Color(0xFF9E4300),
      primaryContainer: const Color(0xFF1A73E8),
      secondaryContainer: const Color(0xFFD8E2FF),
      tertiaryContainer: const Color(0xFFFFDBCB),
      surface: const Color(0xFFF8F9FA),
      surfaceContainerLowest: const Color(0xFFFFFFFF),
      surfaceContainerLow: const Color(0xFFF3F4F5),
      surfaceContainerHighest: const Color(0xFFE1E3E4),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onTertiary: Colors.white,
      onSurface: const Color(0xFF191C1D),
      onSurfaceVariant: const Color(0xFF414754),
      outline: const Color(0xFF727785),
      outlineVariant: const Color(0xFFC1C6D6),
      error: const Color(0xFFBA1A1A),
      onError: Colors.white,
    );

    return _buildThemeData(
      colorScheme: colorScheme,
      brightness: Brightness.light,
    );
  }

  static ThemeData dark() {
    const primaryColor = Color(0xFFADC7FF);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
    ).copyWith(
      primary: primaryColor,
      secondary: const Color(0xFFB8C8E8),
      tertiary: const Color(0xFFFFB691),
      primaryContainer: const Color(0xFF004493),
      secondaryContainer: const Color(0xFF2E4673),
      tertiaryContainer: const Color(0xFF783100),
      surface: const Color(0xFF101417),
      surfaceContainerLowest: const Color(0xFF151A1C),
      surfaceContainerLow: const Color(0xFF1D2327),
      surfaceContainerHighest: const Color(0xFF2A3136),
      onPrimary: const Color(0xFF001A41),
      onSecondary: const Color(0xFF0F1B2D),
      onTertiary: const Color(0xFF341100),
      onSurface: const Color(0xFFF0F1F2),
      onSurfaceVariant: const Color(0xFFC1C7D0),
      outline: const Color(0xFF8A9099),
      outlineVariant: const Color(0xFF424954),
      error: const Color(0xFFFFB4AB),
      onError: const Color(0xFF690005),
    );

    return _buildThemeData(
      colorScheme: colorScheme,
      brightness: Brightness.dark,
    );
  }

  static ThemeData _buildThemeData({
    required ColorScheme colorScheme,
    required Brightness brightness,
  }) {
    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
    );
    final textTheme = _buildTechnicalTextTheme(
      baseTheme.textTheme,
      colorScheme.onSurface,
    );

    return baseTheme.copyWith(
      scaffoldBackgroundColor: colorScheme.surface,
      canvasColor: colorScheme.surface,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surface.withValues(alpha: 0.94),
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surfaceContainerLowest,
        indicatorColor: colorScheme.primary.withValues(
          alpha: brightness == Brightness.light ? 0.12 : 0.16,
        ),
        height: 72,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final color = states.contains(WidgetState.selected)
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant;
          return IconThemeData(color: color);
        }),
      ),
      cardTheme: CardThemeData(
        color: brightness == Brightness.light
            ? colorScheme.surfaceContainerLowest
            : colorScheme.surfaceContainerLow,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: brightness == Brightness.light
            ? colorScheme.onSurface.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.18),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(
              alpha: brightness == Brightness.light ? 0.35 : 0.6,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        shape: const CircleBorder(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.primary, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Colors.transparent,
        thickness: 0,
        space: 0,
      ),
      iconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: brightness == Brightness.light
            ? const Color(0xFF2E3132)
            : const Color(0xFF1E2529),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: brightness == Brightness.light
              ? Colors.white
              : colorScheme.onSurface,
        ),
        actionTextColor: brightness == Brightness.light
            ? colorScheme.primaryContainer
            : colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  static TextTheme _buildTechnicalTextTheme(
    TextTheme base,
    Color textColor,
  ) {
    final bodyTheme = GoogleFonts.interTextTheme(base).apply(
      bodyColor: textColor,
      displayColor: textColor,
    );

    TextStyle bodyStyle(
      TextStyle? style, {
      FontWeight? fontWeight,
      double? letterSpacing,
      double? fontSize,
    }) {
      return GoogleFonts.inter(
        textStyle: style,
        color: textColor,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
        fontSize: fontSize,
      ).copyWith(fontFamilyFallback: _japaneseFontFallback);
    }

    TextStyle headlineStyle(
      TextStyle? style, {
      FontWeight? fontWeight,
      double? letterSpacing,
      double? fontSize,
    }) {
      return GoogleFonts.spaceGrotesk(
        textStyle: style,
        color: textColor,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
        fontSize: fontSize,
      ).copyWith(fontFamilyFallback: _japaneseFontFallback);
    }

    return bodyTheme.copyWith(
      displayLarge: headlineStyle(
        bodyTheme.displayLarge,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.8,
      ),
      displayMedium: headlineStyle(
        bodyTheme.displayMedium,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.4,
      ),
      displaySmall: headlineStyle(
        bodyTheme.displaySmall,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.0,
      ),
      headlineLarge: headlineStyle(
        bodyTheme.headlineLarge,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.9,
      ),
      headlineMedium: headlineStyle(
        bodyTheme.headlineMedium,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
      ),
      headlineSmall: bodyStyle(bodyTheme.headlineSmall),
      titleLarge: headlineStyle(
        bodyTheme.titleLarge,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleMedium:
          bodyStyle(bodyTheme.titleMedium, fontWeight: FontWeight.w600),
      titleSmall: bodyStyle(bodyTheme.titleSmall, fontWeight: FontWeight.w600),
      bodyLarge: bodyStyle(bodyTheme.bodyLarge),
      bodyMedium: bodyStyle(bodyTheme.bodyMedium),
      bodySmall: bodyStyle(bodyTheme.bodySmall),
      labelLarge: bodyStyle(
        bodyTheme.labelLarge,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
      labelMedium: bodyStyle(
        bodyTheme.labelMedium,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
        fontSize: 12,
      ),
      labelSmall: bodyStyle(
        bodyTheme.labelSmall,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.3,
        fontSize: 10,
      ),
    );
  }
}
