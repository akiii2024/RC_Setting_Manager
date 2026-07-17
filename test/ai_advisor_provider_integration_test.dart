import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rc_setting_manager/models/ai_advisor.dart';
import 'package:rc_setting_manager/models/ai_provider.dart';
import 'package:rc_setting_manager/services/ai_advisor_service.dart';
import 'package:rc_setting_manager/services/ai_provider_client.dart';

void main() {
  test('keeps only safe one-step setting changes from a direct provider',
      () async {
    final output = {
      'summary': 'Front grip can be tested conservatively.',
      'confidence': 'medium',
      'evidence': ['Entry push was reported.'],
      'missingInformation': <String>[],
      'changes': [
        {
          'settingKey': 'frontCamber',
          'settingLabel': 'ignored model label',
          'currentValue': '-99',
          'proposedValue': '-1.5',
          'reason': 'Test a single small change.',
          'expectedEffect': 'May improve entry response.',
          'tradeoff': 'Check tire temperature.',
          'priority': 1,
        },
        {
          'settingKey': 'frontCamber',
          'settingLabel': 'Front camber',
          'currentValue': '-1.0',
          'proposedValue': '-3.0',
          'reason': 'Unsafe jump.',
          'expectedEffect': 'Unknown.',
          'tradeoff': '',
          'priority': 2,
        },
        {
          'settingKey': 'inventedSetting',
          'settingLabel': 'Invented',
          'currentValue': '0',
          'proposedValue': '1',
          'reason': 'Invented.',
          'expectedEffect': 'Unknown.',
          'tradeoff': '',
          'priority': 3,
        },
      ],
      'manualTips': <String>[],
      'testPlan': 'Run five laps before comparing.',
      'drivingTips': '',
    };
    final httpClient = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['store'], isFalse);
      expect(body['text'], isA<Map>());
      return http.Response(
        jsonEncode({
          'output': [
            {
              'type': 'message',
              'content': [
                {
                  'type': 'output_text',
                  'text': jsonEncode(output),
                },
              ],
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final providerClient = AiProviderClient(
      configuration: const AiConfiguration(
        provider: AiProvider.openAI,
        model: 'gpt-5.6-sol',
        apiKey: 'secret-test-key',
      ),
      client: httpClient,
    );
    final service = AIAdvisorService(providerClient: providerClient);
    const context = AIAdvisorContext(
      vehicle: {'name': 'Test car'},
      settingName: 'Base',
      definitionVerified: true,
      settings: [
        {'key': 'frontCamber', 'value': -1.0},
      ],
      settingCatalog: [
        {
          'key': 'frontCamber',
          'label': 'Front camber',
          'autoApplicable': true,
          'min': -5,
          'max': 5,
          'step': 0.5,
        },
      ],
    );
    const intake = AIAdvisorIntake(
      symptoms: ['push'],
      phases: ['corner_entry'],
      severity: 'medium',
      trackGrip: 'medium',
      goal: 'rotation',
    );

    final advice = await service.generateStructuredAdvice(
      context: context,
      intake: intake,
      messages: const [],
      isEnglish: true,
      includeHistory: false,
    );

    expect(advice.changes, hasLength(1));
    expect(advice.changes.single.settingKey, 'frontCamber');
    expect(advice.changes.single.settingLabel, 'Front camber');
    expect(advice.changes.single.currentValue, '-1.0');
    expect(advice.changes.single.proposedValue, '-1.5');
    expect(advice.testPlan, 'Run five laps before comparing.');
    providerClient.close();
  });
}
