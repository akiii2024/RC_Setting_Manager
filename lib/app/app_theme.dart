import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppTheme {
  static const _japaneseFontFamily = 'NotoSansJP';
  static const _japaneseFontFallback = <String>[_japaneseFontFamily];

  static TextStyle _withJapaneseFallback(TextStyle style) {
    final fontWeight = style.fontWeight ?? FontWeight.w400;

    return style.copyWith(
      fontFamilyFallback: _japaneseFontFallback,
      // Flutter 3.35 does not map FontWeight to a variable font's wght axis.
      // Noto Sans JP defaults to 100, so set the effective weight explicitly.
      fontVariations: <FontVariation>[
        FontVariation('wght', (fontWeight.index + 1) * 100.0),
      ],
    );
  }

  static ThemeData light() {
    const primaryColor = Color(0xFF3F56C5);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
    ).copyWith(
      primary: primaryColor,
      secondary: const Color(0xFF006B75),
      tertiary: const Color(0xFF8B5000),
      primaryContainer: const Color(0xFFDEE1FF),
      onPrimaryContainer: const Color(0xFF111A52),
      secondaryContainer: const Color(0xFF9EF0FA),
      onSecondaryContainer: const Color(0xFF002F34),
      tertiaryContainer: const Color(0xFFFFDDB8),
      onTertiaryContainer: const Color(0xFF2D1600),
      surface: const Color(0xFFF9F9FF),
      surfaceContainerLowest: const Color(0xFFFFFFFF),
      surfaceContainerLow: const Color(0xFFF2F3FB),
      surfaceContainer: const Color(0xFFECEEF7),
      surfaceContainerHigh: const Color(0xFFE6E8F2),
      surfaceContainerHighest: const Color(0xFFDFE1EC),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onTertiary: Colors.white,
      onSurface: const Color(0xFF1A1B24),
      onSurfaceVariant: const Color(0xFF454651),
      outline: const Color(0xFF767681),
      outlineVariant: const Color(0xFFC6C6D1),
      error: const Color(0xFFBA1A1A),
      onError: Colors.white,
    );

    return _buildThemeData(
      colorScheme: colorScheme,
      brightness: Brightness.light,
    );
  }

  static ThemeData dark() {
    const primaryColor = Color(0xFFBCC3FF);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
    ).copyWith(
      primary: primaryColor,
      secondary: const Color(0xFF82D3DD),
      tertiary: const Color(0xFFFFB86B),
      primaryContainer: const Color(0xFF3E4A9A),
      onPrimaryContainer: const Color(0xFFE0E2FF),
      secondaryContainer: const Color(0xFF174F56),
      onSecondaryContainer: const Color(0xFF9EF0FA),
      tertiaryContainer: const Color(0xFF663A00),
      onTertiaryContainer: const Color(0xFFFFDDB8),
      surface: const Color(0xFF11121A),
      surfaceContainerLowest: const Color(0xFF0C0D14),
      surfaceContainerLow: const Color(0xFF191A23),
      surfaceContainer: const Color(0xFF1D1E27),
      surfaceContainerHigh: const Color(0xFF272831),
      surfaceContainerHighest: const Color(0xFF32323D),
      onPrimary: const Color(0xFF202864),
      onSecondary: const Color(0xFF00363C),
      onTertiary: const Color(0xFF492900),
      onSurface: const Color(0xFFE5E1EC),
      onSurfaceVariant: const Color(0xFFC8C5D0),
      outline: const Color(0xFF918F9A),
      outlineVariant: const Color(0xFF474651),
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
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 72,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 20,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        indicatorColor: colorScheme.secondaryContainer,
        indicatorShape: const StadiumBorder(),
        height: 80,
        surfaceTintColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return textTheme.labelSmall?.copyWith(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? colorScheme.onSecondaryContainer
                : colorScheme.onSurfaceVariant,
            letterSpacing: 0.2,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final color = states.contains(WidgetState.selected)
              ? colorScheme.onSecondaryContainer
              : colorScheme.onSurfaceVariant;
          return IconThemeData(color: color);
        }),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerLow,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.38),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const StadiumBorder(),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const StadiumBorder(),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.72),
          ),
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: const StadiumBorder(),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: const StadiumBorder(),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(48),
          shape: const CircleBorder(),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        elevation: 3,
        focusElevation: 4,
        hoverElevation: 4,
        highlightElevation: 5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHigh,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 17,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        minTileHeight: 64,
        iconColor: colorScheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        titleTextStyle: textTheme.titleMedium?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        thickness: 1,
        space: 1,
        indent: 20,
        endIndent: 20,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        titleTextStyle: textTheme.headlineSmall?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        modalBackgroundColor: colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),
      chipTheme: baseTheme.chipTheme.copyWith(
        backgroundColor: colorScheme.surfaceContainerHigh,
        selectedColor: colorScheme.secondaryContainer,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        labelStyle: textTheme.labelLarge?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        secondaryLabelStyle: textTheme.labelLarge?.copyWith(
          color: colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? colorScheme.onPrimary
              : colorScheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? Colors.transparent
              : colorScheme.outline;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: BorderSide(color: colorScheme.outline, width: 2),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? colorScheme.primary
              : colorScheme.outline;
        }),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colorScheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: ShapeDecoration(
          color: colorScheme.inverseSurface,
          shape: const StadiumBorder(),
        ),
        textStyle: textTheme.labelMedium?.copyWith(
          color: colorScheme.onInverseSurface,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: colorScheme.surfaceContainerHighest,
        circularTrackColor: colorScheme.surfaceContainerHighest,
        linearMinHeight: 8,
      ),
      iconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onInverseSurface,
        ),
        actionTextColor: colorScheme.inversePrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        insetPadding: const EdgeInsets.all(16),
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
      return _withJapaneseFallback(
        GoogleFonts.inter(
          textStyle: style,
          color: textColor,
          fontWeight: fontWeight,
          letterSpacing: letterSpacing,
          fontSize: fontSize,
        ),
      );
    }

    TextStyle headlineStyle(
      TextStyle? style, {
      FontWeight? fontWeight,
      double? letterSpacing,
      double? fontSize,
    }) {
      return _withJapaneseFallback(
        GoogleFonts.spaceGrotesk(
          textStyle: style,
          color: textColor,
          fontWeight: fontWeight,
          letterSpacing: letterSpacing,
          fontSize: fontSize,
        ),
      );
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
