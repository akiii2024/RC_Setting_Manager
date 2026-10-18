import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rc_setting_manager/models/ai_provider.dart';
import 'package:rc_setting_manager/services/ai_provider_client.dart';

const _schema = <String, dynamic>{
  'type': 'object',
  'properties': {
    'answer': {'type': 'string'}
  },
  'required': ['answer'],
};

String? _header(http.Request request, String name) {
  for (final entry in request.headers.entries) {
    if (entry.key.toLowerCase() == name.toLowerCase()) return entry.value;
  }
  return null;
}

Map<String, dynamic> _responseFor(String model, String text) {
  if (model == 'gpt-6-luna') return {'output_text': text};
  if (model == 'claude-haiku-5-5' || model == 'minimax-m3') {
    return {
      'content': [
        {'type': 'text', 'text': text}
      ]
    };
  }
  return {
    'choices': [
      {
        'message': {'content': text}
      }
    ]
  };
}

String _pathFor(String model) {
  if (model == 'gpt-6-luna') return '/inference/go/openai/v1/responses';
  if (model == 'claude-haiku-5-5' || model == 'minimax-m3') {
    return '/inference/go/anthropic/v1/messages';
  }
  return '/inference/go/openai/v1/chat/completions';
}

void main() {
  const models = [
    'glm-5.3-flash',
    'glm-5.3',
    'kimi-k3',
    'gpt-6-luna',
    'claude-haiku-5-5',
    'minimax-m3',
  ];

  for (final model in models) {
    test('Go $model generates text and structured output', () async {
      final requests = <http.Request>[];
      final transport = MockClient((request) async {
        requests.add(request);
        final text = request.body.contains('answer')
            ? jsonEncode({'answer': 'structured'})
            : 'plain';
        return http.Response(jsonEncode(_responseFor(model, text)), 200);
      });
      final client = AiProviderClient(
        configuration: AiConfiguration(
          provider: AiProvider.openCodeGo,
          model: model,
          apiKey: 'secret-go-key',
          sessionId: 'session-fixed',
        ),
        client: transport,
        isWeb: false,
      );

      expect(await client.generateText('hello'), 'plain');
      expect(
        await client.generateStructured(
          system: 'system',
          prompt: 'question',
          schema: _schema,
          schemaName: 'answer',
        ),
        {'answer': 'structured'},
      );
      expect(requests, hasLength(2));
      expect(requests[0].url.host, 'opencode.ai');
      expect(requests[0].url.path, _pathFor(model));
      expect(requests[1].url.path, _pathFor(model));
      expect(_header(requests[0], 'authorization'), 'Bearer secret-go-key');
      expect(_header(requests[0], 'x-opencode-session'), 'session-fixed');
      expect(requests[0].body, isNot(contains('secret-go-key')));

      if (model != 'glm-5.3') {
        expect(
          await client.generateStructured(
            system: 'system',
            prompt: 'image',
            schema: _schema,
            schemaName: 'answer',
            imageBytes: Uint8List.fromList([1, 2]),
            mimeType: 'image/jpeg',
          ),
          {'answer': 'structured'},
        );
        final imageBody = requests.last.body;
        expect(imageBody, contains('image'));
        expect(imageBody, contains('image/jpeg'));
      }
    });
  }

  test('Go image payloads are sent for supported models', () async {
    late http.Request request;
    final client = AiProviderClient(
      configuration: const AiConfiguration(
        provider: AiProvider.openCodeGo,
        model: 'glm-5.3-flash',
        apiKey: 'key',
      ),
      client: MockClient((value) async {
        request = value;
        return http.Response('{"choices":[{"message":{"content":"ok"}}]}', 200);
      }),
      isWeb: false,
    );
    expect(
      await client.generateText(
        'read',
        imageBytes: Uint8List.fromList([1, 2, 3]),
        mimeType: 'image/png',
      ),
      'ok',
    );
    expect(request.body, contains('data:image/png;base64,AQID'));
  });

  test('GLM-5.3 image request is rejected before transport', () async {
    var calls = 0;
    final client = AiProviderClient(
      configuration: const AiConfiguration(
        provider: AiProvider.openCodeGo,
        model: 'glm-5.3',
        apiKey: 'key',
      ),
      client: MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }),
      isWeb: false,
    );
    await expectLater(
      client.generateText(
        'read',
        imageBytes: Uint8List.fromList([1]),
        mimeType: 'image/png',
      ),
      throwsA(isA<AiProviderException>()),
    );
    expect(calls, 0);
  });

  for (final status in [401, 403, 429, 500]) {
    test('Go HTTP $status is mapped without exposing secrets', () async {
      const secret = 'hidden-go-secret';
      final client = AiProviderClient(
        configuration: const AiConfiguration(
          provider: AiProvider.openCodeGo,
          model: 'glm-5.3-flash',
          apiKey: secret,
        ),
        client: MockClient((_) async => http.Response('error $secret', status)),
        isWeb: false,
      );
      Object? caught;
      try {
        await client.generateText('hello');
      } catch (error) {
        caught = error;
      }
      expect(caught, isA<AiProviderException>());
      expect(caught.toString(), isNot(contains(secret)));
    });
  }

  test('Go timeout, network, invalid JSON, and empty output are safe errors',
      () async {
    final timeoutClient = AiProviderClient(
      configuration: const AiConfiguration(
        provider: AiProvider.openCodeGo,
        model: 'glm-5.3-flash',
        apiKey: 'key',
      ),
      client: MockClient((_) async => Future<http.Response>.delayed(
            const Duration(milliseconds: 50),
            () => http.Response('{}', 200),
          )),
      timeout: const Duration(milliseconds: 1),
      isWeb: false,
    );
    await expectLater(
        timeoutClient.generateText('x'), throwsA(isA<AiProviderException>()));

    final invalidClient = AiProviderClient(
      configuration: const AiConfiguration(
        provider: AiProvider.openCodeGo,
        model: 'glm-5.3-flash',
        apiKey: 'key',
      ),
      client: MockClient((_) async => http.Response('invalid', 200)),
      isWeb: false,
    );
    await expectLater(
        invalidClient.generateText('x'), throwsA(isA<AiProviderException>()));

    final networkClient = AiProviderClient(
      configuration: const AiConfiguration(
        provider: AiProvider.openCodeGo,
        model: 'glm-5.3-flash',
        apiKey: 'key',
      ),
      client: MockClient((_) async => throw http.ClientException('offline')),
      isWeb: false,
    );
    await expectLater(
        networkClient.generateText('x'), throwsA(isA<AiProviderException>()));

    final emptyClient = AiProviderClient(
      configuration: const AiConfiguration(
        provider: AiProvider.openCodeGo,
        model: 'glm-5.3-flash',
        apiKey: 'key',
      ),
      client: MockClient((_) async => http.Response('{"choices":[]}', 200)),
      isWeb: false,
    );
    await expectLater(
        emptyClient.generateText('x'), throwsA(isA<AiProviderException>()));
  });

  test('Go testConnection uses POST and rejects invalid envelope', () async {
    late http.Request request;
    final client = AiProviderClient(
      configuration: const AiConfiguration(
        provider: AiProvider.openCodeGo,
        model: 'gpt-6-luna',
        apiKey: 'key',
      ),
      client: MockClient((value) async {
        request = value;
        return http.Response('{"output_text":"ok"}', 200);
      }),
      isWeb: false,
    );
    expect(await client.testConnection(), isTrue);
    expect(request.method, 'POST');
    expect(request.body, contains('"max_output_tokens":128'));
  });

  for (final model in models) {
    test('Go $model testConnection sends POST with auth and session', () async {
      late http.Request request;
      final client = AiProviderClient(
        configuration: AiConfiguration(
          provider: AiProvider.openCodeGo,
          model: model,
          apiKey: 'key',
          sessionId: 'connection-session',
        ),
        client: MockClient((value) async {
          request = value;
          return http.Response(jsonEncode(_responseFor(model, 'ok')), 200);
        }),
        isWeb: false,
      );
      expect(await client.testConnection(), isTrue);
      expect(request.method, 'POST');
      expect(request.url.path, _pathFor(model));
      expect(_header(request, 'authorization'), 'Bearer key');
      expect(_header(request, 'x-opencode-session'), 'connection-session');
      expect(request.body, anyOf(contains('128')));
    });
  }

  for (final envelope in [
    {'choices': null},
    {'content': 'text'},
    {'output': null},
    {
      'output_text': 'ok',
      'error': {'message': 'bad'}
    },
  ]) {
    test('Go testConnection rejects invalid envelope ${envelope.keys}',
        () async {
      final client = AiProviderClient(
        configuration: const AiConfiguration(
          provider: AiProvider.openCodeGo,
          model: 'glm-5.3-flash',
          apiKey: 'key',
        ),
        client:
            MockClient((_) async => http.Response(jsonEncode(envelope), 200)),
        isWeb: false,
      );
      await expectLater(
          client.testConnection(), throwsA(isA<AiProviderException>()));
    });
  }

  test('Go generateText rejects valid output mixed with error envelope',
      () async {
    final client = AiProviderClient(
      configuration: const AiConfiguration(
        provider: AiProvider.openCodeGo,
        model: 'glm-5.3-flash',
        apiKey: 'key',
      ),
      client: MockClient((_) async => http.Response(
            '{"choices":[{"message":{"content":"ok"}}],"error":{"message":"bad"}}',
            200,
          )),
      isWeb: false,
    );
    await expectLater(
        client.generateText('x'), throwsA(isA<AiProviderException>()));
  });

  test('Go testConnection accepts token-limit envelopes by API family',
      () async {
    const envelopes = <String, Map<String, dynamic>>{
      'glm-5.3-flash': {
        'choices': [
          {
            'finish_reason': 'length',
            'message': {
              'role': 'assistant',
              'content': null,
              'reasoning_content': 'thinking',
            },
          }
        ],
      },
      'gpt-6-luna': {
        'status': 'incomplete',
        'incomplete_details': {'reason': 'max_output_tokens'},
        'output': [
          {'type': 'reasoning', 'summary': []}
        ],
      },
      'claude-haiku-5-5': {
        'stop_reason': 'max_tokens',
        'content': [
          {'type': 'thinking', 'thinking': '...'}
        ],
      },
    };
    for (final entry in envelopes.entries) {
      final client = AiProviderClient(
        configuration: AiConfiguration(
          provider: AiProvider.openCodeGo,
          model: entry.key,
          apiKey: 'key',
        ),
        client: MockClient(
            (_) async => http.Response(jsonEncode(entry.value), 200)),
        isWeb: false,
      );
      expect(await client.testConnection(), isTrue);
      await expectLater(
        client.generateText('x'),
        throwsA(isA<AiProviderException>()),
      );
    }
  });
}
