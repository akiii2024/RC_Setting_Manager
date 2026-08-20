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
              ((style.fontWeight ?? FontWeight.w400).index + 1) * 100.0;
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
