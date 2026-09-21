import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rc_setting_manager/models/ai_advisor.dart';
import 'package:rc_setting_manager/models/car_setting_definition.dart';
import 'package:rc_setting_manager/services/ai_advisor_service.dart';
import 'package:rc_setting_manager/services/ai_configuration_service.dart';
import 'package:rc_setting_manager/services/ocr_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('default advisor uses Firebase without a local key', () async {
    final service = AIAdvisorService(
      configurationService:
          AiConfigurationService(secretStore: MemorySecretStore()),
      clientFactory: (_) => throw StateError('Direct API must not be used'),
      functionCaller: (name, data) async {
        expect(name, 'generateSettingAdvice');
        expect(data['phase'], 'chat');
        expect(data['locale'], 'ja');
        expect(data.containsKey('apiKey'), isFalse);
        return {
          'message': '進入時の状態を教えてください。',
          'readyForAdvice': false,
          'missingTopics': <String>[],
        };
      },
    );
    final turn = await service.continueStructuredConversation(
      context: const AIAdvisorContext(
        vehicle: {'name': 'Car'},
        settingName: 'Base',
        definitionVerified: true,
        settings: [],
        settingCatalog: [],
      ),
      intake: const AIAdvisorIntake(
        symptoms: ['push'],
        phases: ['corner_entry'],
        severity: 'medium',
        trackGrip: 'medium',
        goal: 'rotation',
      ),
      messages: const [],
      isEnglish: false,
      includeHistory: false,
    );
    expect(turn.message, '進入時の状態を教えてください。');
  });

  test('default OCR uses the dedicated Firebase function without a local key',
      () async {
    final directory = await Directory.systemTemp.createTemp('gemini_ocr_test');
    addTearDown(() => directory.delete(recursive: true));
    final bytes = [0xff, 0xd8, 0xff, 0x00];
    final file = await File('${directory.path}/image.jpg').writeAsBytes(bytes);
    var called = false;
    final service = OCRService(
      configurationService:
          AiConfigurationService(secretStore: MemorySecretStore()),
      clientFactory: (_) => throw StateError('Direct API must not be used'),
      functionCaller: (name, data) async {
        called = true;
        expect(name, 'extractSettingSheet');
        expect(data['carId'], 'tamiya/trf421');
        expect(data['profileId'], 'trf421');
        expect(data['image'], {
          'mimeType': 'image/jpeg',
          'data': base64Encode(bytes),
        });
        expect(data.containsKey('apiKey'), isFalse);
        return {
          'result': {
            'detectedModel': 'TRF421',
            'candidates': [
              {
                'key': 'camber',
                'rawValue': '-1.5°',
                'points': <Map<String, int>>[],
                'confidence': 'high',
                'evidence': '入力欄',
              },
            ],
            'warnings': <String>[],
          },
        };
      },
    );
    final result = await service.extractSettingsFromImage(
      file,
      carId: 'tamiya/trf421',
      carName: 'TRF421',
      settingDefinitions: [
        SettingItem(
          key: 'camber',
          type: 'number',
          category: 'front',
          label: 'キャンバー',
          unit: '°',
          constraints: const {'min': -10, 'max': 10, 'step': 0.1},
        ),
      ],
    );
    expect(result.candidates.single.value, '-1.5');
    expect(called, isTrue);
  });
}
