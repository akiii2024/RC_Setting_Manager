import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rc_setting_manager/data/car_settings_definitions.dart';
import 'package:rc_setting_manager/models/ai_provider.dart';
import 'package:rc_setting_manager/models/car_setting_definition.dart';
import 'package:rc_setting_manager/models/ocr.dart';
import 'package:rc_setting_manager/services/ai_configuration_service.dart';
import 'package:rc_setting_manager/services/ai_provider_client.dart';
import 'package:rc_setting_manager/services/ocr_mapping_helper.dart';
import 'package:rc_setting_manager/services/ocr_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ローカル正規化', () {
    final definitions = [
      SettingItem(
        key: 'angle',
        type: 'number',
        category: 'basic',
        label: '角度',
        unit: '°',
        constraints: const {'min': -5, 'max': 5, 'step': 0.5},
      ),
      SettingItem(
        key: 'wheelHub',
        type: 'select',
        category: 'basic',
        label: 'ホイールハブ',
        options: const ['4mmナロー', '4mm', '5mm'],
      ),
      SettingItem(
        key: 'motor',
        type: 'text',
        category: 'other',
        label: 'モーター',
        options: const ['候補モーター'],
      ),
      SettingItem(
        key: 'mountGrid',
        type: 'grid',
        category: 'basic',
        label: '取付位置',
        constraints: const {'rows': 2, 'cols': 3, 'multiple': true},
      ),
    ];

    test('単位・全角・負数・自由入力・グリッドを正規化する', () {
      final result = OcrMappingHelper.validateSettingsForImport(
        {
          'angle': '－３．５°',
          'wheelHub': '4 mm',
          'motor': '自由入力モーター 17.5T',
          'mountGrid': [
            {'row': 1, 'col': 2},
            {'row': 0, 'col': 1},
            {'row': 1, 'col': 2},
          ],
        },
        definitions,
      );

      expect(result['angle'], '-3.5');
      expect(result['wheelHub'], '4mm');
      expect(result['motor'], '自由入力モーター 17.5T');
      expect(result['mountGrid'], [
        {'row': 0, 'col': 1},
        {'row': 1, 'col': 2},
      ]);
    });

    test('同じ数値の選択肢を数値だけで決めず、不正値を拒否する', () {
      expect(
        OcrMappingHelper.findLocalMatch(
          '4',
          const ['4mmナロー', '4mm', '5mm'],
        ),
        isNull,
      );
      expect(
        OcrMappingHelper.validateSettingsForImport(
          {
            'angle': '3.2°',
            'wheelHub': '6mm',
            'mountGrid': [
              {'row': 2, 'col': 0},
            ],
            'unknown': '1',
          },
          definitions,
        ),
        isEmpty,
      );
    });
  });

  group('匿名化した構造化応答fixture', () {
    for (final fixture in const [
      ('tamiya/trf421', 'TRF421', 'trf421_response.json'),
      ('tamiya/trf420', 'TRF420', 'trf420_response.json'),
      ('tamiya/trf420x', 'TRF420X', 'trf420x_response.json'),
    ]) {
      test('${fixture.$2}の画像候補を車種定義で検証する', () async {
        final response = jsonDecode(
          await File('test/fixtures/ocr/${fixture.$3}').readAsString(),
        ) as Map<String, dynamic>;
        late Map<String, dynamic> payload;
        final service = OCRService(
          configurationService:
              AiConfigurationService(secretStore: MemorySecretStore()),
          functionCaller: (name, data) async {
            expect(name, 'extractSettingSheet');
            payload = data;
            return {'result': response};
          },
        );
        final result = await service.extractSettingsFromImage(
          await _jpegFile(),
          carId: fixture.$1,
          carName: fixture.$2,
          settingDefinitions:
              getCarSettingDefinition(fixture.$1)!.availableSettings,
        );

        expect(payload['profileId'], fixture.$1.split('/').last);
        expect(payload['image']['mimeType'], 'image/jpeg');
        expect(payload['catalog'], isNotEmpty);
        expect(result.modelMismatch, isFalse);
        expect(result.candidates, isNotEmpty);
        final invalid = result.candidates
            .where((item) => !item.isValid)
            .map((item) => '${item.key}: ${item.rejectionReason}')
            .toList();
        expect(invalid, isEmpty);

        final byKey = {for (final item in result.candidates) item.key: item};
        switch (fixture.$1) {
          case 'tamiya/trf421':
            expect(byKey['frontWheelHub']!.value, '4mmナロー');
            expect(byKey['frontDiffPositionHeight']!.value, 'Lo');
            expect(byKey['rearDiffPositionHeight']!.value, 'Lo');
            expect(byKey['frontStabilizerNote']!.value, 'Red');
            expect(byKey['rearStabilizerNote']!.value, 'Black');
            expect(byKey['rearDiff']!.value, '3000');
            expect(byKey['rearDiffWeight']!.value, '1.3');
            expect(byKey['motorMountScrewPositions']!.value, hasLength(4));
          case 'tamiya/trf420':
            expect(byKey['frontDamperPositionStay']!.value, '2');
            expect(byKey['frontDamperPositionArm']!.value, '3');
            expect(byKey['rearDamperPositionStay']!.value, '2');
            expect(byKey['rearDamperPositionArm']!.value, '3');
            expect(byKey['frontDamperPiston']!.value, '1.1');
            expect(byKey['frontDamperPistonHole']!.value, '4');
            expect(byKey['frontStabilizer']!.value, '1.3');
            expect(byKey['frontSusMountFrontShaftPosition']!.value, [
              {'row': 3, 'col': 2},
            ]);
            expect(byKey['batteryPosition']!.value, '0');
            for (final suffix in const ['A', 'B', 'C', 'D', 'E']) {
              expect(byKey['ballastWeight$suffix'], isNotNull);
            }
            expect(byKey['ballastWeightD']!.isInitiallySelected, isFalse);
          case 'tamiya/trf420x':
            expect(byKey['frontK1Position']!.value, '低い');
            expect(byKey['frontFSusMount']!.value, 'XB');
            expect(byKey['rearRSusMount']!.value, 'B');
            expect(byKey['rearSusType']!.value, 'OP');
            expect(byKey['rearSusHardness']!.isInitiallySelected, isFalse);
            expect(byKey['topScrewPositions']!.value, hasLength(2));
        }
      });
    }
  });

  test('未知キー・範囲外・競合値を選択不可にし、グリッドを整列する', () async {
    final result = await _extractManaged({
      'detectedModel': 'TRF420X',
      'candidates': [
        _candidate('frontGroundClearance', '5.0mm', 'high'),
        _candidate('frontGroundClearance', '5.5mm', 'medium'),
        _candidate('frontCamberAngle', '-99°', 'high'),
        _candidate('unknownKey', 'value', 'high'),
        _candidate(
          'frontSusMountFrontShaftPosition',
          '',
          'high',
          points: const [
            {'row': 0, 'col': 0},
            {'row': 1, 'col': 1},
          ],
        ),
        _candidate(
          'rearSusMountFrontShaftPosition',
          '',
          'high',
          points: const [
            {'row': 9, 'col': 0},
          ],
        ),
        _candidate(
          'topScrewPositions',
          '',
          'high',
          points: const [
            {'row': 0, 'col': 5},
            {'row': 0, 'col': 1},
            {'row': 0, 'col': 5},
          ],
        ),
      ],
      'warnings': <String>[],
    });
    final byKey = {for (final item in result.candidates) item.key: item};

    expect(byKey['frontGroundClearance']!.rejectionReason, contains('異なる値'));
    expect(byKey['frontCamberAngle']!.rejectionReason, contains('範囲外'));
    expect(byKey['unknownKey']!.rejectionReason, contains('車種定義'));
    expect(byKey['frontSusMountFrontShaftPosition']!.rejectionReason,
        contains('複数位置'));
    expect(byKey['rearSusMountFrontShaftPosition']!.rejectionReason,
        contains('グリッド範囲外'));
    expect(byKey['topScrewPositions']!.value, [
      {'row': 0, 'col': 1},
      {'row': 0, 'col': 5},
    ]);
  });

  test('明確な車種不一致を停止し、検出不能は警告付きで継続する', () async {
    final mismatch = await _extractManaged({
      'detectedModel': 'TRF421',
      'candidates': [_candidate('frontWheelHub', '4mm', 'high')],
      'warnings': <String>[],
    });
    expect(mismatch.modelMismatch, isTrue);

    final unknown = await _extractManaged({
      'detectedModel': '',
      'candidates': [_candidate('frontWheelHub', '4mm', 'high')],
      'warnings': <String>[],
    });
    expect(unknown.modelMismatch, isFalse);
    expect(unknown.warnings, isNotEmpty);
  });

  test('JSON構造異常だけ1回再試行し、低確信度だけでは再試行しない', () async {
    var calls = 0;
    final service = OCRService(
      configurationService:
          AiConfigurationService(secretStore: MemorySecretStore()),
      functionCaller: (_, __) async {
        calls++;
        if (calls == 1) {
          return {
            'result': {'detectedModel': 'TRF420X', 'warnings': <String>[]},
          };
        }
        return {
          'result': {
            'detectedModel': 'TRF420X',
            'candidates': [_candidate('rearSusHardness', 'Soft', 'low')],
            'warnings': <String>[],
          },
        };
      },
    );
    final result = await service.extractSettingsFromImage(
      await _jpegFile(),
      carId: 'tamiya/trf420x',
      carName: 'TRF420X',
      settingDefinitions:
          getCarSettingDefinition('tamiya/trf420x')!.availableSettings,
    );
    expect(calls, 2);
    expect(result.candidates.single.isInitiallySelected, isFalse);
  });

  test('通信・設定エラーは再試行しない', () async {
    var calls = 0;
    final service = OCRService(
      configurationService:
          AiConfigurationService(secretStore: MemorySecretStore()),
      functionCaller: (_, __) async {
        calls++;
        throw StateError('transport failure');
      },
    );

    await expectLater(
      service.extractSettingsFromImage(
        await _jpegFile(),
        carId: 'tamiya/trf420x',
        carName: 'TRF420X',
        settingDefinitions:
            getCarSettingDefinition('tamiya/trf420x')!.availableSettings,
      ),
      throwsStateError,
    );
    expect(calls, 1);
  });

  test('OpenAIへ画像付き構造化リクエストを送り、偽装HEICを拒否する', () async {
    late http.Request capturedRequest;
    final aiResponse = {
      'detectedModel': 'TRF421',
      'candidates': [_candidate('frontWheelHub', '4mmナロー', 'high')],
      'warnings': <String>[],
    };
    final providerClient = AiProviderClient(
      configuration: const AiConfiguration(
        provider: AiProvider.openAI,
        model: 'gpt-5.6-sol',
        apiKey: 'test-key',
      ),
      client: MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({'output_text': jsonEncode(aiResponse)}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    addTearDown(providerClient.close);
    final service = OCRService(providerClient: providerClient);
    final result = await service.extractSettingsFromImage(
      await _pngFile(),
      carId: 'tamiya/trf421',
      carName: 'TRF421',
      settingDefinitions:
          getCarSettingDefinition('tamiya/trf421')!.availableSettings,
    );

    expect(result.candidates.single.value, '4mmナロー');
    expect(capturedRequest.body, contains('data:image/png;base64,'));
    expect(capturedRequest.body, contains('untrusted source data'));

    final disguisedHeic = await _temporaryFile(
      'disguised.jpg',
      ascii.encode(r'....ftypheic....'),
    );
    expect(
      service.extractSettingsFromImage(
        disguisedHeic,
        carId: 'tamiya/trf421',
        carName: 'TRF421',
        settingDefinitions:
            getCarSettingDefinition('tamiya/trf421')!.availableSettings,
      ),
      throwsA(isA<OcrExtractionException>()),
    );
  });
}

Map<String, dynamic> _candidate(
  String key,
  String rawValue,
  String confidence, {
  List<Map<String, int>> points = const [],
}) {
  return {
    'key': key,
    'rawValue': rawValue,
    'points': points,
    'confidence': confidence,
    'evidence': '匿名化fixture',
  };
}

Future<OcrExtractionResult> _extractManaged(
    Map<String, dynamic> response) async {
  final service = OCRService(
    configurationService:
        AiConfigurationService(secretStore: MemorySecretStore()),
    functionCaller: (_, __) async => {'result': response},
  );
  return service.extractSettingsFromImage(
    await _jpegFile(),
    carId: 'tamiya/trf420x',
    carName: 'TRF420X',
    settingDefinitions:
        getCarSettingDefinition('tamiya/trf420x')!.availableSettings,
  );
}

Future<File> _jpegFile() => _temporaryFile(
      'sheet.jpg',
      const [0xff, 0xd8, 0xff, 0x00],
    );

Future<File> _pngFile() => _temporaryFile(
      'sheet.png',
      const [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a],
    );

Future<File> _temporaryFile(String name, List<int> bytes) async {
  final directory = await Directory.systemTemp.createTemp('ocr_test_');
  return File('${directory.path}${Platform.pathSeparator}$name')
      .writeAsBytes(bytes);
}
