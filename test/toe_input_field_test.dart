import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rc_setting_manager/widgets/signed_angle_input_field.dart';

const _inputKey = Key('frontToe');

SegmentedButton<bool> _direction(WidgetTester tester) {
  return tester.widget<SegmentedButton<bool>>(
    find.byKey(const Key('frontToe_direction')),
  );
}

String _text(WidgetTester tester) {
  return tester.widget<EditableText>(find.byType(EditableText)).controller.text;
}

Future<void> _pumpField(
  WidgetTester tester, {
  Object? value,
  ValueChanged<String>? onChanged,
  bool dark = false,
  double width = 360,
  double textScale = 1,
}) async {
  await tester.pumpWidget(MaterialApp(
    theme: dark ? ThemeData.dark() : ThemeData.light(),
    home: Scaffold(
      body: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Center(
          child: SizedBox(
            width: width,
            child: SignedAngleInputField(
              settingKey: 'frontToe',
              initialValue: value,
              onChanged: onChanged ?? (_) {},
              negativeLabel: 'トーアウト',
              positiveLabel: 'トーイン',
              negativeByDefault: false,
            ),
          ),
        ),
      ),
    ),
  ));
}

void main() {
  testWidgets('トーイン・トーアウトの選択と入力値を符号付きで通知する', (tester) async {
    final changes = <String>[];
    await _pumpField(tester, onChanged: changes.add);
    expect(_direction(tester).selected, {false});

    await tester.enterText(find.byKey(_inputKey), '２．５');
    await tester.pump();
    expect(_text(tester), '2.5');
    expect(changes.last, '+2.5');

    await tester.tap(find.text('−'));
    await tester.pump();
    expect(_direction(tester).selected, {true});
    expect(changes.last, '-2.5');
    await tester.enterText(find.byKey(_inputKey), '３．０');
    await tester.pump();
    expect(changes.last, '-3.0');
  });

  testWidgets('全角のマイナス・プラス貼り付けで方向を同期する', (tester) async {
    final changes = <String>[];
    await _pumpField(tester, onChanged: changes.add);

    await tester.enterText(find.byKey(_inputKey), '－２．５');
    await tester.pump();
    expect(_text(tester), '2.5');
    expect(_direction(tester).selected, {true});
    expect(changes.last, '-2.5');

    await tester.enterText(find.byKey(_inputKey), '＋２．５');
    await tester.pump();
    expect(_text(tester), '2.5');
    expect(_direction(tester).selected, {false});
    expect(changes.last, '+2.5');
  });

  testWidgets('初期値ゼロはプラス方向として通知する', (tester) async {
    final changes = <String>[];
    await _pumpField(tester, value: 0, onChanged: changes.add);
    await tester.enterText(find.byKey(_inputKey), '０');
    await tester.pump();
    expect(_direction(tester).selected, {false});
    expect(changes.last, '+0');
  });

  testWidgets('ゼロ入力でも選択したマイナス方向を保持する', (tester) async {
    final changes = <String>[];
    await _pumpField(tester, onChanged: changes.add);
    await tester.tap(find.text('−'));
    await tester.enterText(find.byKey(_inputKey), '０');
    await tester.pump();
    expect(_direction(tester).selected, {true});
    expect(changes.last, '-0');
    await tester.enterText(find.byKey(_inputKey), '２');
    await tester.pump();
    expect(changes.last, '-2');
  });
  for (final value in [-1.0, 3.0]) {
    testWidgets('保存済みのトー値$valueを値の変更なしで復元する', (tester) async {
      final changes = <String>[];
      await _pumpField(tester, value: value, onChanged: changes.add);
      expect(_text(tester), value.abs().toStringAsFixed(1));
      expect(_direction(tester).selected, {value < 0});
      expect(changes, isEmpty);
    });
  }

  testWidgets('無効値から有効値へ修正するとエラーが消える', (tester) async {
    final changes = <String>[];
    await _pumpField(tester, onChanged: changes.add);
    await tester.enterText(find.byKey(_inputKey), 'ー２');
    await tester.pump();
    expect(find.text('有効な数値を入力してください'), findsOneWidget);
    await tester.enterText(find.byKey(_inputKey), '０');
    await tester.pump();
    expect(find.text('有効な数値を入力してください'), findsNothing);
    expect(changes.last, '+0');
  });

  testWidgets('狭い幅・文字拡大・ダークテーマでも操作欄が収まる', (tester) async {
    await _pumpField(tester, value: -2, dark: true, width: 240, textScale: 2);
    expect(find.text('トーアウト'), findsOneWidget);
    expect(find.text('−'), findsOneWidget);
    expect(find.text('+'), findsOneWidget);
    await tester.tap(find.text('+'));
    await tester.pump();
    expect(find.text('トーイン'), findsOneWidget);
    expect(_direction(tester).selected, {false});
    expect(tester.takeException(), isNull);
  });
}
