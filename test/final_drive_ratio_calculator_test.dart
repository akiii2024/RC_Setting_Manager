import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rc_setting_manager/data/built_in_car_catalog.dart';
import 'package:rc_setting_manager/data/car_drive_ratios.dart';
import 'package:rc_setting_manager/widgets/final_drive_ratio_calculator.dart';

Finder _internalField() => find.widgetWithText(TextFormField, '内部減速比');
String _internalValue(WidgetTester tester) =>
    tester.widget<TextFormField>(_internalField()).controller!.text;

Future<void> _pump(WidgetTester tester,
    {String? carId,
    ValueChanged<double>? onCalculated,
    bool english = false}) async {
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: SingleChildScrollView(
    child: FinalDriveRatioCalculator(
        carId: carId,
        spurTeeth: 100,
        pinionTeeth: 40,
        isEnglish: english,
        onCalculated: onCalculated),
  ))));
  await tester.pumpAndSettle();
}

void main() {
  test('登録済み車種の標準内部減速比と未知車種を区別する', () {
    for (final car in BuiltInCarCatalog.create()) {
      final expected = car.id.startsWith('tamiya/')
          ? 1.85
          : car.id == 'yokomo/ms2_0'
              ? 2.0
              : 1.9;
      expect(CarDriveRatios.forCarId(car.id), expected, reason: car.id);
    }
    expect(CarDriveRatios.forCarId('custom/car'), isNull);
    expect(CarDriveRatios.forCarId(null), isNull);
  });

  testWidgets('車種の標準値が入力され、そのまま計算できる', (tester) async {
    double? calculated;
    await _pump(tester,
        carId: 'tamiya/trf421', onCalculated: (value) => calculated = value);
    expect(_internalValue(tester), '1.85');
    await tester.tap(find.text('最終減速比を計算'));
    await tester.pump();
    expect(calculated, 4.625);
  });

  testWidgets('手動修正は同じ車種の再描画で上書きしない', (tester) async {
    await _pump(tester, carId: 'tamiya/trf421');
    await tester.enterText(_internalField(), '2.2');
    await tester.pump();
    await _pump(tester, carId: 'tamiya/trf421');
    expect(_internalValue(tester), '2.2');
  });

  testWidgets('親画面の車種変更で標準値を更新し、未知車種は空欄にする', (tester) async {
    await _pump(tester, carId: 'tamiya/trf421');
    await tester.enterText(_internalField(), '2.2');
    await _pump(tester, carId: 'yokomo/ms2_0');
    expect(_internalValue(tester), '2.0');
    await _pump(tester, carId: 'custom/car');
    expect(_internalValue(tester), isEmpty);
    await tester.enterText(_internalField(), '2.4');
    await tester.tap(find.text('最終減速比を計算'));
    await tester.pump();
    expect(find.text('最終減速比: 6.0000'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('計算ツール内で車両を選び直すと標準値を更新する', (tester) async {
    final cars = BuiltInCarCatalog.create();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
      child: FinalDriveRatioCalculator(carId: cars.first.id, cars: cars),
    ))));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MS2.0').last);
    await tester.pumpAndSettle();
    expect(_internalValue(tester), '2.0');
    expect(tester.takeException(), isNull);
  });
}
