import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rc_setting_manager/models/ai_advisor.dart';
import 'package:rc_setting_manager/services/ai_configuration_service.dart';
import 'package:rc_setting_manager/services/ai_advisor_service.dart';
import 'package:rc_setting_manager/services/ocr_service.dart';

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
          'missingTopics': <String>[]
        };
      },
    );
    final turn = await service.continueStructuredConversation(
      context: const AIAdvisorContext(
          vehicle: {'name': 'Car'},
          settingName: 'Base',
          definitionVerified: true,
          settings: [],
          settingCatalog: []),
      intake: const AIAdvisorIntake(
          symptoms: ['push'],
          phases: ['corner_entry'],
          severity: 'medium',
          trackGrip: 'medium',
          goal: 'rotation'),
      messages: const [],
      isEnglish: false,
      includeHistory: false,
    );
    expect(turn.message, '進入時の状態を教えてください。');
  });

  test('default OCR sends image to Firebase without a local key', () async {
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
        expect(name, 'generateGeminiContent');
        final contents = data['contents'] as List;
        expect(contents.single['parts'][1]['inlineData'],
            {'mimeType': 'image/jpeg', 'data': base64Encode(bytes)});
        return {'text': 'キャンバー: -1.5°'};
      },
    );
    expect(await service.recognizeTextFromImage(file), 'キャンバー: -1.5°');
    expect(called, isTrue);
  });
}
