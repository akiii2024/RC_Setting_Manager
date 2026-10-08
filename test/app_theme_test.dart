import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rc_setting_manager/app/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppTheme fonts', () {
    for (final entry in <String, ThemeData Function()>{
      'light': AppTheme.light,
      'dark': AppTheme.dark,
    }.entries) {
      testWidgets('${entry.key} theme configures bundled fonts',
          (tester) async {
        final textTheme = entry.value().textTheme;

        await tester.pumpWidget(
          Theme(
            data: entry.value(),
            child: const Directionality(
              textDirection: TextDirection.ltr,
              child: Text('設定 車高 調整 ABC'),
            ),
          ),
        );
        await tester.pump();

        for (final style in _allTextStyles(textTheme)) {
          expect(
            style.fontFamilyFallback,
            contains('NotoSansJP'),
            reason:
                '${style.debugLabel} must render Japanese with Noto Sans JP',
          );

          final expectedWeight =
              (style.fontWeight ?? FontWeight.w400).value.toDouble();
          final weightVariation = style.fontVariations?.singleWhere(
            (variation) => variation.axis == 'wght',
          );
          expect(
            weightVariation?.value,
            expectedWeight,
            reason: '${style.debugLabel} must apply its weight to Noto Sans JP',
          );
        }

        expect(textTheme.bodyMedium?.fontFamily, startsWith('Inter_'));
        expect(textTheme.titleMedium?.fontFamily, startsWith('Inter_'));
        expect(textTheme.headlineSmall?.fontFamily, startsWith('Inter_'));
        expect(
          textTheme.headlineMedium?.fontFamily,
          startsWith('SpaceGrotesk_'),
        );
        expect(
          textTheme.titleLarge?.fontFamily,
          startsWith('SpaceGrotesk_'),
        );
      });
    }
  });

  group('AppTheme input visibility', () {
    test('dark input boundaries have at least 3:1 contrast', () {
      final theme = AppTheme.dark();
      final decoration = theme.inputDecorationTheme;

      for (final border in [decoration.border, decoration.enabledBorder]) {
        final side = (border! as OutlineInputBorder).borderSide;
        expect(side.style, BorderStyle.solid);
        expect(side.width, 1);
        expect(side.color, theme.colorScheme.outline);
        for (final background in [
          decoration.fillColor!,
          theme.colorScheme.surface,
          theme.colorScheme.surfaceContainerLow,
          theme.colorScheme.surfaceContainerHigh,
        ]) {
          expect(
              _contrastRatio(side.color, background), greaterThanOrEqualTo(3));
        }
      }
    });

    test('light inputs retain their borderless appearance', () {
      final decoration = AppTheme.light().inputDecorationTheme;
      expect(decoration.fillColor, const Color(0xFFE6E8F2));
      for (final border in [decoration.border, decoration.enabledBorder]) {
        expect((border! as OutlineInputBorder).borderSide, BorderSide.none);
      }
    });

    for (final entry in <String, ThemeData Function()>{
      'light': AppTheme.light,
      'dark': AppTheme.dark,
    }.entries) {
      test('${entry.key} inputs preserve focus and error boundaries', () {
        final theme = entry.value();
        final decoration = theme.inputDecorationTheme;
        for (final entry in {
          decoration.focusedBorder!:
              BorderSide(color: theme.colorScheme.primary, width: 2),
          decoration.errorBorder!: BorderSide(color: theme.colorScheme.error),
          decoration.focusedErrorBorder!:
              BorderSide(color: theme.colorScheme.error, width: 2),
        }.entries) {
          final border = entry.key as OutlineInputBorder;
          expect(border.borderRadius, BorderRadius.circular(18));
          expect(border.borderSide, entry.value);
          expect(_contrastRatio(border.borderSide.color, decoration.fillColor!),
              greaterThanOrEqualTo(3));
        }
      });
    }
  });

  group('AppTheme expressive components', () {
    for (final entry in <String, ThemeData Function()>{
      'light': AppTheme.light,
      'dark': AppTheme.dark,
    }.entries) {
      test('${entry.key} theme shares the expressive shape system', () {
        final theme = entry.value();
        final cardShape = theme.cardTheme.shape! as RoundedRectangleBorder;
        final inputBorder =
            theme.inputDecorationTheme.border! as OutlineInputBorder;
        final buttonShape =
            theme.filledButtonTheme.style!.shape!.resolve(<WidgetState>{});

        expect(theme.useMaterial3, isTrue);
        expect(theme.navigationBarTheme.height, 80);
        expect(theme.navigationBarTheme.indicatorShape, isA<StadiumBorder>());
        expect(cardShape.borderRadius, BorderRadius.circular(24));
        expect(inputBorder.borderRadius, BorderRadius.circular(18));
        expect(buttonShape, isA<StadiumBorder>());
        expect(theme.bottomSheetTheme.showDragHandle, isTrue);
      });
    }
  });
}

List<TextStyle> _allTextStyles(TextTheme textTheme) => [
      textTheme.displayLarge,
      textTheme.displayMedium,
      textTheme.displaySmall,
      textTheme.headlineLarge,
      textTheme.headlineMedium,
      textTheme.headlineSmall,
      textTheme.titleLarge,
      textTheme.titleMedium,
      textTheme.titleSmall,
      textTheme.bodyLarge,
      textTheme.bodyMedium,
      textTheme.bodySmall,
      textTheme.labelLarge,
      textTheme.labelMedium,
      textTheme.labelSmall,
    ].whereType<TextStyle>().toList(growable: false);

double _contrastRatio(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final lighter =
      firstLuminance > secondLuminance ? firstLuminance : secondLuminance;
  final darker =
      firstLuminance < secondLuminance ? firstLuminance : secondLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}
