import 'package:flutter_test/flutter_test.dart';
import 'package:rc_setting_manager/models/car_setting_definition.dart';
import 'package:rc_setting_manager/services/ocr_mapping_helper.dart';

void main() {
  test('レーベンシュタイン距離と類似度を決定的に計算する', () {
    expect(OcrMappingHelper.levenshteinDistance('kitten', 'sitting'), 3);
    expect(
      OcrMappingHelper.calculateStringSimilarity('kitten', 'sitting'),
      closeTo(4 / 7, 0.000001),
    );
    expect(OcrMappingHelper.calculateStringSimilarity('', 'value'), 0);
  });

  test('完全一致、数値一致、類似文字列から既存オプションを返す', () {
    expect(
      OcrMappingHelper.findLocalMatch('CARPET', ['Asphalt', 'Carpet']),
      'Carpet',
    );
    expect(
      OcrMappingHelper.findLocalMatch('Tire 32 shore', ['Tire 36', 'Tire 32']),
      'Tire 32',
    );
    expect(
      OcrMappingHelper.findLocalMatch('medum', ['soft', 'medium', 'hard']),
      'medium',
    );
    expect(
      OcrMappingHelper.findLocalMatch('unrelated', ['soft', 'hard']),
      isNull,
    );
  });

  test('OCR値から囲み文字と末尾単位を除去する', () {
    expect(OcrMappingHelper.cleanValue(' (3.5mm) '), '3.5');
    expect(OcrMappingHelper.cleanValue('42ポイント'), '42');
    expect(OcrMappingHelper.cleanValue('Soft spring'), 'Soft spring');
  });

  test('定義に存在し、制約内にある値だけをインポート対象にする', () {
    final definitions = [
      SettingItem(
        key: 'rideHeight',
        type: 'number',
        category: 'basic',
        label: '車高',
        unit: 'mm',
        constraints: const {'min': 2, 'max': 8, 'step': 0.5},
      ),
      SettingItem(
        key: 'surface',
        type: 'select',
        category: 'basic',
        label: '路面',
        options: const ['アスファルト', 'カーペット'],
      ),
      SettingItem(
        key: 'memo',
        type: 'text',
        category: 'memo',
        label: 'メモ',
      ),
    ];

    final result = OcrMappingHelper.validateSettingsForImport(
      {
        'rideHeight': '3,5mm',
        'surface': 'カーペット',
        'memo': '基準セット',
        'unknown': '1',
        '_unmatched_0': '架空: 100',
      },
      definitions,
    );

    expect(result, {
      'rideHeight': '3.5',
      'surface': 'カーペット',
      'memo': '基準セット',
    });
  });
}
