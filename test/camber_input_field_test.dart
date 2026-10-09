import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rc_setting_manager/utils/setting_number_input.dart';
import 'package:rc_setting_manager/widgets/camber_input_field.dart';

const _inputKey = Key('frontCamber');

SegmentedButton<bool> _direction(WidgetTester tester) {
  return tester.widget<SegmentedButton<bool>>(
    find.byKey(const Key('frontCamber_direction')),
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
            child: CamberInputField(
              settingKey: 'frontCamber',
              initialValue: value,
              onChanged: onChanged ?? (_) {},
            ),
          ),
        ),
      ),
    ),
  ));
}

void main() {
  testWidgets('符号選択と全角角度入力で方向を指定できる', (tester) async {
    final changes = <String>[];
    await _pumpField(tester, onChanged: changes.add);
    expect(_direction(tester).selected, {true});
    await tester.enterText(find.byKey(_inputKey), '２．５');
    await tester.pump();
    expect(_text(tester), '2.5');
    expect(parseSettingNumberInput('frontCamber', changes.last), -2.5);

    await tester.tap(find.text('+'));
    await tester.pump();
    expect(_direction(tester).selected, {false});
    expect(parseSettingNumberInput('frontCamber', changes.last), 2.5);
    await tester.enterText(find.byKey(_inputKey), '３．０');
    await tester.pump();
    expect(parseSettingNumberInput('frontCamber', changes.last), 3);

    await tester.enterText(find.byKey(_inputKey), '−２．５');
    await tester.pump();
    expect(_direction(tester).selected, {true});
    expect(_text(tester), '2.5');
    expect(parseSettingNumberInput('frontCamber', changes.last), -2.5);

    await tester.enterText(find.byKey(_inputKey), '＋２．５');
    await tester.pump();
    expect(_direction(tester).selected, {false});
    expect(_text(tester), '2.5');
    expect(parseSettingNumberInput('frontCamber', changes.last), 2.5);
  });

  testWidgets('IMEの変換中を保持し、確定した全角文字だけを表示上も正規化する', (tester) async {
    final changes = <String>[];
    await _pumpField(tester, onChanged: changes.add);
    await tester.tap(find.byKey(_inputKey));
    tester.testTextInput.updateEditingValue(const TextEditingValue(
      text: '＋２．５',
      selection: TextSelection.collapsed(offset: 4),
      composing: TextRange(start: 0, end: 4),
    ));
    await tester.pump();
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.controller.text, '＋２．５');
    expect(
        editable.controller.value.composing, const TextRange(start: 0, end: 4));

    tester.testTextInput.updateEditingValue(const TextEditingValue(
      text: '＋２．５',
      selection: TextSelection.collapsed(offset: 4),
    ));
    await tester.pump();
    expect(_text(tester), '2.5');
    expect(_direction(tester).selected, {false});
    expect(parseSettingNumberInput('frontCamber', changes.last), 2.5);
    expect(tester.takeException(), isNull);
  });

  for (final value in [-2.0, 2.0]) {
    testWidgets('保存済みの方向$valueを値の変更なしで復元する', (tester) async {
      final changes = <String>[];
      await _pumpField(tester, value: value, onChanged: changes.add);
      expect(_text(tester), '2.0');
      expect(_direction(tester).selected, {value < 0});
      expect(changes, isEmpty);
    });
  }

  testWidgets('長音や符号だけを数値に変換せず、修正後にエラーが消える', (tester) async {
    final changes = <String>[];
    await _pumpField(tester, onChanged: changes.add);
    await tester.enterText(find.byKey(_inputKey), 'ー２');
    await tester.pump();
    expect(find.text('有効な数値を入力してください'), findsOneWidget);
    expect(parseSettingNumberInput('frontCamber', changes.last), isNull);
    await tester.tap(find.text('+'));
    await tester.pump();
    expect(find.text('有効な数値を入力してください'), findsOneWidget);
    await tester.enterText(find.byKey(_inputKey), '０');
    await tester.pump();
    expect(find.text('有効な数値を入力してください'), findsNothing);
    expect(parseSettingNumberInput('frontCamber', changes.last), 0);
    expect(_direction(tester).selected, {false});
  });

  testWidgets('狭い幅・文字拡大・ダークテーマでも操作欄が収まる', (tester) async {
    await _pumpField(tester, value: -2, dark: true, width: 240, textScale: 2);
    expect(find.text('−'), findsOneWidget);
    expect(find.text('+'), findsOneWidget);
    await tester.tap(find.text('+'));
    await tester.pump();
    expect(_direction(tester).selected, {false});
    expect(tester.takeException(), isNull);
  });
}
