import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rc_setting_manager/models/ocr.dart';
import 'package:rc_setting_manager/pages/ocr_import_page.dart';

void main() {
  testWidgets('候補の確信度・検証状態を反映し、候補単位で選択できる', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final result = _reviewResult();
    final selectedKeys = <String>{
      for (final candidate in result.candidates)
        if (candidate.isInitiallySelected) candidate.key,
    };
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          brightness: Brightness.dark,
          colorSchemeSeed: Colors.blue,
        ),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 780),
            textScaler: TextScaler.linear(1.4),
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) => Column(
                  children: [
                    OcrCandidateReviewList(
                      result: result,
                      selectedKeys: selectedKeys,
                      onSelectionChanged: (key, selected) {
                        setState(() {
                          if (selected) {
                            selectedKeys.add(key);
                          } else {
                            selectedKeys.remove(key);
                          }
                        });
                      },
                    ),
                    Text('選択件数: ${selectedKeys.length}'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('2行3列'), findsOneWidget);
    expect(find.text('車種定義にない項目です'), findsOneWidget);
    expect(find.text('選択件数: 2'), findsOneWidget);

    final lowTile = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, 'リア ホイールハブ'),
    );
    expect(lowTile.value, isFalse);
    final rejectedTile = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, '不明な候補'),
    );
    expect(rejectedTile.onChanged, isNull);

    await tester.tap(find.text('リア ホイールハブ'));
    await tester.pump();
    expect(find.text('選択件数: 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('選択された検証済み候補だけを動的な取り込みマップにする', () {
    final result = _reviewResult();
    expect(
      result.selectedSettings({
        'frontWheelHub',
        'rearWheelHub',
        'motorMountScrewPositions',
        'unknown',
      }),
      {
        'frontWheelHub': '4mmナロー',
        'rearWheelHub': '4mm',
        'motorMountScrewPositions': [
          {'row': 1, 'col': 2},
        ],
      },
    );
  });
}

OcrExtractionResult _reviewResult() {
  return const OcrExtractionResult(
    detectedModel: 'TRF421',
    modelMismatch: false,
    warnings: [],
    candidates: [
      OcrCandidate(
        key: 'frontWheelHub',
        label: 'フロント ホイールハブ',
        rawValue: '4mmナロー',
        points: [],
        confidence: OcrConfidence.high,
        evidence: '赤いX',
        value: '4mmナロー',
      ),
      OcrCandidate(
        key: 'rearWheelHub',
        label: 'リア ホイールハブ',
        rawValue: '4mm',
        points: [],
        confidence: OcrConfidence.low,
        evidence: '印が薄い',
        value: '4mm',
      ),
      OcrCandidate(
        key: 'motorMountScrewPositions',
        label: 'モーターマウントスクリュー',
        rawValue: '',
        points: [OcrGridPoint(row: 1, col: 2)],
        confidence: OcrConfidence.medium,
        evidence: '選択位置',
        value: [
          {'row': 1, 'col': 2},
        ],
      ),
      OcrCandidate(
        key: 'unknown',
        label: '不明な候補',
        rawValue: '1',
        points: [],
        confidence: OcrConfidence.high,
        evidence: '',
        rejectionReason: '車種定義にない項目です',
      ),
    ],
  );
}
