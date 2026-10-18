import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rc_setting_manager/models/ai_advisor.dart';
import 'package:rc_setting_manager/models/ai_provider.dart';
import 'package:rc_setting_manager/models/car_setting_definition.dart';
import 'package:rc_setting_manager/models/telemetry_ai.dart';
import 'package:rc_setting_manager/services/ai_advisor_service.dart';
import 'package:rc_setting_manager/services/ai_configuration_service.dart';
import 'package:rc_setting_manager/services/ai_provider_client.dart';
import 'package:rc_setting_manager/services/ocr_service.dart';
import 'package:rc_setting_manager/services/telemetry_ai_analysis_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _reply(String schema) => switch (schema) {
      'rc_advisor_chat' => {
          'message': '確認します。',
          'readyForAdvice': false,
          'missingTopics': <String>[]
        },
      'setting_sheet_ocr' => {
          'detectedModel': 'TRF421',
          'candidates': [
            {
              'key': 'camber',
              'rawValue': '-1.5',
              'points': <Map<String, int>>[],
              'confidence': 'high',
              'evidence': '記載値'
            }
          ],
          'warnings': <String>[],
        },
      _ => {
          'summary': '確認します。',
          'confidence': 'low',
          'strengthEvidenceIds': <String>[],
          'focusAreas': <Object>[],
          'limitations': <String>[]
        },
    };

class _ReplyClient extends AiProviderClient {
  _ReplyClient(AiConfiguration configuration, this.onCall)
      : super(configuration: configuration);
  final void Function() onCall;

  @override
  Future<Map<String, dynamic>> generateStructured({
    required String system,
    required String prompt,
    required Map<String, dynamic> schema,
    required String schemaName,
    Uint8List? imageBytes,
    String? mimeType,
    int maxTokens = 4096,
  }) async {
    onCall();
    return _reply(schemaName);
  }
}

void main() {
  for (final provider in AiProvider.values) {
    test(
        '${provider.value}: all features use explicit mode and stop personal requests when disabled',
        () async {
      SharedPreferences.setMockInitialValues({});
      final configuration =
          AiConfigurationService(secretStore: MemorySecretStore());
      await configuration.unlockDeveloperMode();
      await configuration.setDeveloperModeEnabled(true);
      await configuration.saveConfiguration(
          provider: provider,
          model: provider == AiProvider.openCodeGo
              ? provider.defaultModel
              : 'personal-model',
          apiKey: 'test-key');
      final restored = AiConfigurationService(secretStore: MemorySecretStore());
      expect(await restored.isDeveloperModeEnabled, isTrue);
      expect((await restored.activeSettings).provider, provider);
      expect(await restored.usesManagedGemini, isFalse);
      var directCalls = 0;
      var managedCalls = 0;
      AiProviderClient factory(AiConfiguration value) {
        expect(value.provider, provider);
        expect(value.apiKey, 'test-key');
        return _ReplyClient(value, () => directCalls++);
      }

      Future<Map<String, dynamic>> managed(
          String name, Map<String, dynamic> data) async {
        managedCalls++;
        expect(data.containsKey('apiKey'), isFalse);
        return switch (name) {
          'generateSettingAdvice' => _reply('rc_advisor_chat'),
          'extractSettingSheet' => {'result': _reply('setting_sheet_ocr')},
          _ => {'analysis': _reply('telemetry_driving_coach')},
        };
      }

      final advisor = AIAdvisorService(
          configurationService: configuration,
          clientFactory: factory,
          functionCaller: managed);
      final ocr = OCRService(
          configurationService: configuration,
          clientFactory: factory,
          functionCaller: managed);
      final telemetry = TelemetryAiAnalysisService(
          configurationService: configuration,
          clientFactory: factory,
          functionCaller: managed);
      final directory =
          await Directory.systemTemp.createTemp('developer_ai_routing');
      addTearDown(() => directory.delete(recursive: true));
      final image = await File('${directory.path}/image.jpg')
          .writeAsBytes([0xff, 0xd8, 0xff, 0]);
      final operations = <Future<void> Function()>[
        () async {
          await advisor.continueStructuredConversation(
            context: const AIAdvisorContext(
                vehicle: {'name': 'Car'},
                settingName: 'Base',
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
        },
        () async {
          await ocr.extractSettingsFromImage(image,
              carId: 'tamiya/trf421',
              carName: 'TRF421',
              settingDefinitions: [
                SettingItem(
                    key: 'camber',
                    type: 'number',
                    category: 'front',
                    label: 'キャンバー',
                    unit: '°',
                    constraints: const {'min': -10, 'max': 10, 'step': 0.1}),
              ]);
        },
        () async {
          await telemetry.analyze(
              const TelemetryFeatureReport(
                  sensorStatus: {},
                  laps: [],
                  selectedLapNumbers: [],
                  evidence: [],
                  excludedLaps: [],
                  inputFingerprint: 'test'),
              isEnglish: false);
        },
      ];
      for (final operation in operations) {
        await operation();
      }
      expect(directCalls, 3);
      expect(managedCalls, 0);
      await configuration.setDeveloperModeEnabled(false);
      for (final operation in operations) {
        await operation();
      }
      expect(directCalls, 3);
      expect(managedCalls, 3);
      await configuration.setDeveloperModeEnabled(true);
      for (final operation in operations) {
        await operation();
      }
      expect(directCalls, 3);
      expect(managedCalls, 6);
      await configuration.selectPersonalProvider(
          provider: provider,
          model: provider == AiProvider.openCodeGo
              ? provider.defaultModel
              : 'personal-model');
      await configuration.deleteApiKey(provider);
      for (final operation in operations) {
        await expectLater(operation(), throwsStateError);
      }
      expect(managedCalls, 6);
      expect(directCalls, 3);
    });
  }
}
