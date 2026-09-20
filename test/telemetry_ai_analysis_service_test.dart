import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rc_setting_manager/models/ai_provider.dart';
import 'package:rc_setting_manager/models/telemetry_ai.dart';
import 'package:rc_setting_manager/services/ai_configuration_service.dart';
import 'package:rc_setting_manager/services/ai_provider_client.dart';
import 'package:rc_setting_manager/services/telemetry_ai_analysis_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

TelemetryFeatureReport _report() => const TelemetryFeatureReport(
      sensorStatus: {
        'ST(%)': TelemetrySensorStatus(
          quality: TelemetrySensorQuality.dynamic,
          min: -80,
          max: 90,
          average: 2,
        ),
      },
      laps: [
        TelemetryLapFeatures(
          number: 2,
          startMillis: 10000,
          endMillis: 20000,
          fullThrottleRatio: 0.4,
          neutralRatio: 0.1,
          brakeRatio: 0.08,
          fullBrakeRatio: 0.02,
          fullSteeringRatio: 0.2,
          steeringCenterRatio: 0.1,
        ),
      ],
      selectedLapNumbers: [2],
      evidence: [
        TelemetryEvidence(
          id: 'lap_2_full_throttle',
          metric: 'fullThrottleRatio',
          value: 0.4,
          lap: 2,
          unit: 'ratio',
        ),
      ],
      excludedLaps: [],
      inputFingerprint: '0123abcd',
      referenceLapNumber: 2,
    );

Map<String, dynamic> _analysis() => {
      'summary': 'Lap 99で0.2秒の差があり、操作入力の再現性を確認できます。',
      'confidence': 'medium',
      'strengthEvidenceIds': ['lap_2_full_throttle', 'unknown'],
      'focusAreas': [
        {
          'title': '全開区間',
          'evidenceIds': ['unknown', 'lap_2_full_throttle'],
          'inference': '全開区間を比較できます。',
          'coachingTip': '同じラインで再現性を確認します。',
          'verification': '次の走行でも同じ条件で記録します。',
        },
        {
          'title': '根拠なし',
          'evidenceIds': ['unknown'],
          'inference': '根拠のない推定です。',
          'coachingTip': '採用されません。',
          'verification': '採用されません。',
        },
      ],
      'limitations': ['速度センサーはありません。'],
    };

void main() {
  test('direct provider sends only feature JSON and filters unknown evidence',
      () async {
    late http.Request captured;
    final transport = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'output': [
            {
              'type': 'message',
              'content': [
                {
                  'type': 'output_text',
                  'text': jsonEncode(_analysis()),
                },
              ],
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final client = AiProviderClient(
      configuration: const AiConfiguration(
        provider: AiProvider.openAI,
        model: 'test-model',
        apiKey: 'private-key',
      ),
      client: transport,
    );
    final service = TelemetryAiAnalysisService(providerClient: client);

    final result = await service.analyze(_report(), isEnglish: false);

    expect(result.provider, 'openai');
    expect(result.model, 'test-model');
    expect(result.confidence, 'low');
    expect(result.limitations, contains(contains('1周')));
    expect(result.summary, isNot(matches(RegExp(r'\d'))));
    expect(result.summary, isNot(contains('Lap 99')));
    expect(result.strengthEvidenceIds, ['lap_2_full_throttle']);
    expect(result.focusAreas.single.evidenceIds, ['lap_2_full_throttle']);
    expect(result.focusAreas, hasLength(1));
    expect(captured.body, isNot(contains('private-key')));
    expect(captured.body, isNot(contains('.csv')));
    expect(captured.body, isNot(contains('rawCsv')));
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['store'], isFalse);
    expect(((body['text'] as Map)['format'] as Map)['type'], 'json_schema');
    client.close();
  });

  test('standard Gemini uses the managed telemetry function', () async {
    SharedPreferences.setMockInitialValues({});
    var called = false;
    final service = TelemetryAiAnalysisService(
      configurationService: AiConfigurationService(
        secretStore: MemorySecretStore(),
      ),
      functionCaller: (name, data) async {
        called = true;
        expect(name, 'generateTelemetryAnalysis');
        expect(data.keys, containsAll(['locale', 'report']));
        expect(jsonEncode(data), isNot(contains('.csv')));
        return {
          'analysis': _analysis(),
          'modelVersion': 'managed-gemini-test',
        };
      },
    );

    final result = await service.analyze(_report(), isEnglish: true);

    expect(called, isTrue);
    expect(result.provider, 'gemini');
    expect(result.model, 'managed-gemini-test');
  });
}
