import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rc_setting_manager/models/ai_advisor.dart';
import 'package:rc_setting_manager/models/ai_provider.dart';
import 'package:rc_setting_manager/models/car_setting_definition.dart';
import 'package:rc_setting_manager/services/ai_advisor_service.dart';
import 'package:rc_setting_manager/services/ai_configuration_service.dart';
import 'package:rc_setting_manager/services/ai_provider_client.dart';
import 'package:rc_setting_manager/services/ocr_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _context = AIAdvisorContext(
  vehicle: {'name': 'TRF421'},
  settingName: 'Base',
  settings: [],
  settingCatalog: [],
);
const _intake = AIAdvisorIntake(
  symptoms: ['push'],
  phases: ['corner_entry'],
  severity: 'medium',
  trackGrip: 'medium',
  goal: 'rotation',
);
final _catalog = [
  SettingItem(
    key: 'camber',
    label: 'キャンバー',
    category: 'front',
    type: 'number',
    constraints: {'min': -5, 'max': 0, 'step': 0.5},
  ),
];

http.Response _chatReply(Map<String, dynamic> value) => http.Response(
      jsonEncode({
        'choices': [
          {
            'message': {'content': jsonEncode(value)}
          },
        ],
      }),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Future<AiConfigurationService> _configured(
    {String model = 'glm-5.3-flash'}) async {
  final service = AiConfigurationService(secretStore: MemorySecretStore());
  await service.unlockDeveloperMode();
  await service.setDeveloperModeEnabled(true);
  await service.saveConfiguration(
    provider: AiProvider.openCodeGo,
    model: model,
    apiKey: 'go-service-key',
  );
  return service;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
      'advisor preserves a session across initial retry, chat, and final advice',
      () async {
    final configuration = await _configured();
    final sessions = <String>[];
    var calls = 0;
    final transport = MockClient((request) async {
      sessions.add(request.headers['x-opencode-session']!);
      calls++;
      if (calls == 1) return _chatReply({'not': 'valid chat'});
      final body = jsonDecode(request.body) as Map;
      final name =
          ((body['response_format'] as Map)['json_schema'] as Map)['name'];
      return _chatReply(name == 'rc_advisor_chat'
          ? {
              'message': '進入時の状態を確認します。',
              'readyForAdvice': true,
              'missingTopics': <String>[]
            }
          : {
              'summary': '一つずつ確認してください。',
              'confidence': 'low',
              'evidence': <String>[],
              'missingInformation': <String>[],
              'changes': <Object>[],
              'manualTips': <String>[],
              'testPlan': '次の走行で確認してください。',
              'drivingTips': '',
            });
    });
    addTearDown(transport.close);
    final service = AIAdvisorService(
      configurationService: configuration,
      clientFactory: (value) =>
          AiProviderClient(configuration: value, client: transport),
      functionCaller: (_, __) =>
          throw StateError('Managed API must not be called'),
    );
    Future<AdvisorChatTurn> chat(List<AdvisorMessage> messages) =>
        service.continueStructuredConversation(
          context: _context,
          intake: _intake,
          messages: messages,
          isEnglish: false,
          includeHistory: false,
        );
    await expectLater(chat(const []), throwsStateError);
    final initial = await chat(const []);
    await chat([
      AdvisorMessage(role: AdvisorMessageRole.model, text: initial.message)
    ]);
    await service.generateStructuredAdvice(
      context: _context,
      intake: _intake,
      messages: const [],
      isEnglish: false,
      includeHistory: false,
    );
    expect(sessions.take(4).toSet(), hasLength(1));
    expect(sessions.first, matches(RegExp(r'^[a-f0-9]{32}$')));
    await chat(const []);
    expect(sessions.last, isNot(sessions.first));
  });

  test('OCR retry shares a session and the next import receives a new session',
      () async {
    final configuration = await _configured();
    final sessions = <String>[];
    final transport = MockClient((request) async {
      sessions.add(request.headers['x-opencode-session']!);
      if (sessions.length == 1) return http.Response('{invalid json', 200);
      return _chatReply({
        'detectedModel': 'TRF421',
        'candidates': [
          {
            'key': 'camber',
            'rawValue': '-1.5',
            'points': <Object>[],
            'confidence': 'high',
            'evidence': '記載値'
          },
        ],
        'warnings': <String>[],
      });
    });
    addTearDown(transport.close);
    final service = OCRService(
      configurationService: configuration,
      clientFactory: (value) =>
          AiProviderClient(configuration: value, client: transport),
      functionCaller: (_, __) =>
          throw StateError('Managed API must not be called'),
    );
    addTearDown(service.dispose);
    final image = XFile.fromData(Uint8List.fromList([0xff, 0xd8, 0xff, 0]));
    final result = await service.extractSettingsFromImage(image,
        carId: 'trf421', carName: 'TRF421', settingDefinitions: _catalog);
    expect(result.candidates, hasLength(1));
    expect(sessions, hasLength(2));
    expect(sessions[0], sessions[1]);
    await service.extractSettingsFromImage(image,
        carId: 'trf421', carName: 'TRF421', settingDefinitions: _catalog);
    expect(sessions[2], isNot(sessions[0]));
  });

  test(
      'text-only Go model stops OCR before reading the image or contacting any API',
      () async {
    final configuration = await _configured(model: 'glm-5.3');
    var calls = 0;
    final service = OCRService(
      configurationService: configuration,
      clientFactory: (_) {
        calls++;
        throw StateError('Must not construct a client');
      },
      functionCaller: (_, __) {
        calls++;
        throw StateError('Must not call Firebase');
      },
    );
    addTearDown(service.dispose);
    await expectLater(
      service.extractSettingsFromImage(Object(),
          carId: 'trf421', carName: 'TRF421', settingDefinitions: _catalog),
      throwsA(isA<OcrExtractionException>()
          .having((error) => error.message, 'message', contains('画像対応モデル'))),
    );
    expect(calls, 0);
    expect(
        (await configuration.activeSettings).provider, AiProvider.openCodeGo);
  });

  test('saved Go selection on web stops advice and OCR without reading the key',
      () async {
    final native = await _configured();
    final web =
        AiConfigurationService(isWeb: true, secretStore: _NoReadSecretStore());
    var calls = 0;
    AiProviderClient factory(AiConfiguration _) {
      calls++;
      throw StateError('Must not construct a client');
    }

    final advisor =
        AIAdvisorService(configurationService: web, clientFactory: factory);
    await expectLater(
        advisor.continueStructuredConversation(
          context: _context,
          intake: _intake,
          messages: const [],
          isEnglish: false,
          includeHistory: false,
        ),
        throwsA(isA<StateError>()
            .having((error) => error.message, 'message', contains('CORS'))));
    final ocr = OCRService(configurationService: web, clientFactory: factory);
    addTearDown(ocr.dispose);
    await expectLater(
        ocr.extractSettingsFromImage(Object(),
            carId: 'trf421', carName: 'TRF421', settingDefinitions: _catalog),
        throwsA(isA<OcrExtractionException>()
            .having((error) => error.message, 'message', contains('CORS'))));
    expect(calls, 0);
    expect((await native.activeSettings).provider, AiProvider.openCodeGo);
  });
}

class _NoReadSecretStore extends MemorySecretStore {
  @override
  Future<String?> read(String key) =>
      throw StateError('Must not read a secret on web');
}
