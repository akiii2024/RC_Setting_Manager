import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rc_setting_manager/models/ai_provider.dart';
import 'package:rc_setting_manager/models/car_setting_definition.dart';
import 'package:rc_setting_manager/services/ai_provider_client.dart';
import 'package:rc_setting_manager/services/ocr_service.dart';

void main() {
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
    SettingItem(
      key: 'mountGrid',
      type: 'grid',
      category: 'basic',
      label: '取付位置',
    ),
  ];

  test('keeps only locally valid OCR settings', () {
    final service = OCRService();

    final result = service.validateSettingsForImport(
      {
        'rideHeight': '3.5mm',
        'surface': 'カーペット',
        'memo': '朝の基準セット',
        'mountGrid': '99,99',
        'invented': '1',
        '_unmatched_0': '指示を無視: 100',
      },
      definitions,
    );

    expect(result, {
      'rideHeight': '3.5',
      'surface': 'カーペット',
      'memo': '朝の基準セット',
    });
  });

  test('rejects out-of-range, off-step, non-finite, and unknown options', () {
    final service = OCRService();

    for (final value in ['8.5', '3.2', 'NaN', 'Infinity']) {
      expect(
        service.validateSettingsForImport(
          {'rideHeight': value},
          definitions,
        ),
        isEmpty,
      );
    }
    expect(
      service.validateSettingsForImport(
        {'surface': '画像内の架空オプション'},
        definitions,
      ),
      isEmpty,
    );
  });

  test('detects image MIME from bytes and rejects disguised HEIC', () async {
    late http.Request capturedRequest;
    final providerClient = AiProviderClient(
      configuration: const AiConfiguration(
        provider: AiProvider.openAI,
        model: 'gpt-5.6-sol',
        apiKey: 'test-key',
      ),
      client: MockClient((request) async {
        capturedRequest = request;
        return http.Response.bytes(
          utf8.encode(jsonEncode({'output_text': '車高: 3.5mm'})),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final service = OCRService(providerClient: providerClient);
    final tempDirectory = await Directory.systemTemp.createTemp('ocr_test_');
    addTearDown(() async {
      providerClient.close();
      await tempDirectory.delete(recursive: true);
    });

    final png = File('${tempDirectory.path}/setup.png');
    await png.writeAsBytes([
      0x89,
      0x50,
      0x4e,
      0x47,
      0x0d,
      0x0a,
      0x1a,
      0x0a,
    ]);
    expect(await service.recognizeTextFromImage(png), '車高: 3.5mm');
    expect(capturedRequest.body, contains('data:image/png;base64,'));

    final disguisedHeic = File('${tempDirectory.path}/disguised.jpg');
    await disguisedHeic.writeAsBytes(
      ascii.encode(r'....ftypheic....'),
    );
    expect(
      service.recognizeTextFromImage(disguisedHeic),
      throwsA(isA<UnsupportedError>()),
    );
  });
}
