import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rc_setting_manager/models/ai_provider.dart';
import 'package:rc_setting_manager/services/ai_provider_client.dart';

const _schema = <String, dynamic>{
  'type': 'object',
  'additionalProperties': false,
  'properties': {
    'answer': {'type': 'string'},
  },
  'required': ['answer'],
};

String? _header(http.Request request, String name) {
  final normalizedName = name.toLowerCase();
  for (final entry in request.headers.entries) {
    if (entry.key.toLowerCase() == normalizedName) {
      return entry.value;
    }
  }
  return null;
}

AiConfiguration _configuration(
  AiProvider provider, {
  String? model,
  String apiKey = 'provider-secret-key',
}) {
  return AiConfiguration(
    provider: provider,
    model: model ?? provider.defaultModel,
    apiKey: apiKey,
  );
}

void main() {
  test('OpenAI Responses sends json_schema payload and parses output text',
      () async {
    late http.Request capturedRequest;
    final transport = MockClient((request) async {
      capturedRequest = request;
      return http.Response(
        jsonEncode({
          'output': [
            {
              'type': 'message',
              'content': [
                {
                  'type': 'output_text',
                  'text': jsonEncode({'answer': 'openai-ok'}),
                },
              ],
            },
          ],
        }),
        200,
      );
    });
    final client = AiProviderClient(
      configuration: _configuration(AiProvider.openAI),
      client: transport,
    );

    final result = await client.generateStructured(
      system: 'System instruction',
      prompt: 'Question',
      schema: _schema,
      schemaName: 'advisor_response',
      maxTokens: 123,
    );

    expect(result, {'answer': 'openai-ok'});
    expect(capturedRequest.method, 'POST');
    expect(
        capturedRequest.url.toString(), 'https://api.openai.com/v1/responses');
    expect(
      _header(capturedRequest, 'authorization'),
      'Bearer provider-secret-key',
    );
    final body = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
    expect(body['model'], AiProvider.openAI.defaultModel);
    expect(body['instructions'], 'System instruction');
    expect(body['input'], 'Question');
    expect(body['max_output_tokens'], 123);
    expect(body['store'], isFalse);
    final format = ((body['text'] as Map)['format'] as Map);
    expect(format['type'], 'json_schema');
    expect(format['name'], 'advisor_response');
    expect(format['strict'], isTrue);
    expect(format['schema'], _schema);
    expect(
        capturedRequest.url.toString(), isNot(contains('provider-secret-key')));
    expect(capturedRequest.body, isNot(contains('provider-secret-key')));
  });

  test('OpenAI Responses sends image as a data URL and parses output_text',
      () async {
    late http.Request capturedRequest;
    final transport = MockClient((request) async {
      capturedRequest = request;
      return http.Response(jsonEncode({'output_text': 'vision-ok'}), 200);
    });
    final client = AiProviderClient(
      configuration: _configuration(AiProvider.openAI),
      client: transport,
    );

    final result = await client.generateText(
      'Read this image',
      imageBytes: Uint8List.fromList([1, 2, 3]),
      mimeType: 'image/png',
      maxTokens: 50,
    );

    expect(result, 'vision-ok');
    final body = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
    final input = body['input'] as List;
    final content = (input.single as Map)['content'] as List;
    expect((content.first as Map)['type'], 'input_text');
    expect((content.last as Map)['type'], 'input_image');
    expect(
      (content.last as Map)['image_url'],
      'data:image/png;base64,AQID',
    );
    expect(body['store'], isFalse);
  });

  test('Anthropic Messages sends output_config json_schema and parses content',
      () async {
    late http.Request capturedRequest;
    final transport = MockClient((request) async {
      capturedRequest = request;
      return http.Response(
        jsonEncode({
          'content': [
            {
              'type': 'text',
              'text': jsonEncode({'answer': 'anthropic-ok'}),
            },
          ],
        }),
        200,
      );
    });
    final client = AiProviderClient(
      configuration: _configuration(AiProvider.anthropic),
      client: transport,
    );

    final result = await client.generateStructured(
      system: 'System instruction',
      prompt: 'Question',
      schema: _schema,
      schemaName: 'advisor_response',
    );

    expect(result, {'answer': 'anthropic-ok'});
    expect(capturedRequest.url.toString(),
        'https://api.anthropic.com/v1/messages');
    expect(_header(capturedRequest, 'x-api-key'), 'provider-secret-key');
    expect(_header(capturedRequest, 'anthropic-version'), '2023-06-01');
    expect(
      _header(capturedRequest, 'anthropic-dangerous-direct-browser-access'),
      'true',
    );
    final body = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
    expect(body['system'], 'System instruction');
    expect(((body['output_config'] as Map)['format'] as Map)['type'],
        'json_schema');
    expect(
      ((body['output_config'] as Map)['format'] as Map)['schema'],
      _schema,
    );
    expect(
        capturedRequest.url.toString(), isNot(contains('provider-secret-key')));
    expect(capturedRequest.body, isNot(contains('provider-secret-key')));
  });

  test('Anthropic Messages encodes image source and joins text parts',
      () async {
    late http.Request capturedRequest;
    final transport = MockClient((request) async {
      capturedRequest = request;
      return http.Response(
        jsonEncode({
          'content': [
            {'type': 'text', 'text': 'first'},
            {'type': 'text', 'text': 'second'},
          ],
        }),
        200,
      );
    });
    final client = AiProviderClient(
      configuration: _configuration(AiProvider.anthropic),
      client: transport,
    );

    final result = await client.generateText(
      'Read this image',
      imageBytes: Uint8List.fromList([1, 2, 3]),
      mimeType: 'image/jpeg',
    );

    expect(result, 'first\nsecond');
    final body = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
    final messages = body['messages'] as List;
    final content = (messages.single as Map)['content'] as List;
    final source = (content.last as Map)['source'] as Map;
    expect(source['type'], 'base64');
    expect(source['media_type'], 'image/jpeg');
    expect(source['data'], 'AQID');
  });

  test('Gemini uses header authentication and responseFormat schema', () async {
    late http.Request capturedRequest;
    final transport = MockClient((request) async {
      capturedRequest = request;
      return http.Response(
        jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {
                    'text': jsonEncode({'answer': 'gemini-ok'})
                  },
                ],
              },
            },
          ],
        }),
        200,
      );
    });
    final client = AiProviderClient(
      configuration: _configuration(AiProvider.gemini),
      client: transport,
    );

    final result = await client.generateStructured(
      system: 'System instruction',
      prompt: 'Question',
      schema: _schema,
      schemaName: 'advisor_response',
    );

    expect(result, {'answer': 'gemini-ok'});
    expect(
      capturedRequest.url.toString(),
      'https://generativelanguage.googleapis.com/v1beta/'
      'models/gemini-3.5-flash:generateContent',
    );
    expect(_header(capturedRequest, 'x-goog-api-key'), 'provider-secret-key');
    expect(capturedRequest.url.query, isEmpty);
    final body = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
    expect(((body['systemInstruction'] as Map)['parts'] as List), isNotEmpty);
    final generationConfig = body['generationConfig'] as Map;
    final textFormat =
        ((generationConfig['responseFormat'] as Map)['text'] as Map);
    expect(textFormat['mimeType'], 'application/json');
    expect(textFormat['schema'], _schema);
    expect(capturedRequest.body, isNot(contains('provider-secret-key')));
  });

  test('testConnection uses model endpoint without a generation request',
      () async {
    late http.Request capturedRequest;
    final transport = MockClient((request) async {
      capturedRequest = request;
      return http.Response(jsonEncode({'name': 'models/test'}), 200);
    });
    final client = AiProviderClient(
      configuration: _configuration(AiProvider.gemini),
      client: transport,
    );

    expect(await client.testConnection(), isTrue);
    expect(capturedRequest.method, 'GET');
    expect(
      capturedRequest.url.toString(),
      'https://generativelanguage.googleapis.com/v1beta/'
      'models/gemini-3.5-flash',
    );
    expect(_header(capturedRequest, 'x-goog-api-key'), 'provider-secret-key');
  });

  test('Gemini accepts a models/ resource-name prefix', () async {
    late http.Request capturedRequest;
    final client = MockClient((request) async {
      capturedRequest = request;
      return http.Response('{"name":"models/gemini-3.5-flash"}', 200);
    });
    final providerClient = AiProviderClient(
      configuration: _configuration(
        AiProvider.gemini,
        model: 'models/gemini-3.5-flash',
      ),
      client: client,
    );

    await providerClient.testConnection();

    expect(
      capturedRequest.url.path,
      '/v1beta/models/gemini-3.5-flash',
    );
    providerClient.close();
  });

  test('non-2xx errors do not expose API key or response body', () async {
    const secret = 'do-not-leak-this-key';
    late http.Request capturedRequest;
    final transport = MockClient((request) async {
      capturedRequest = request;
      return http.Response(
        jsonEncode({'error': 'request failed for $secret'}),
        401,
      );
    });
    final client = AiProviderClient(
      configuration: _configuration(
        AiProvider.openAI,
        apiKey: secret,
      ),
      client: transport,
    );

    Object? error;
    try {
      await client.generateText('Hello');
    } catch (caught) {
      error = caught;
    }

    expect(error, isA<AiProviderException>());
    final providerError = error! as AiProviderException;
    expect(providerError.kind, AiProviderErrorKind.authentication);
    expect(providerError.statusCode, 401);
    expect(providerError.toString(), isNot(contains(secret)));
    expect(providerError.toString(), isNot(contains('request failed')));
    expect(capturedRequest.url.toString(), isNot(contains(secret)));
    expect(capturedRequest.body, isNot(contains(secret)));
  });

  test('invalid JSON and empty output errors do not expose API key', () async {
    const secret = 'another-private-key';
    var callCount = 0;
    final transport = MockClient((request) async {
      callCount += 1;
      if (callCount == 1) {
        return http.Response('invalid json containing $secret', 200);
      }
      return http.Response(jsonEncode({'content': []}), 200);
    });
    final client = AiProviderClient(
      configuration: _configuration(
        AiProvider.anthropic,
        apiKey: secret,
      ),
      client: transport,
    );

    for (var index = 0; index < 2; index += 1) {
      Object? error;
      try {
        await client.generateText('Hello');
      } catch (caught) {
        error = caught;
      }

      expect(error, isA<AiProviderException>());
      final providerError = error! as AiProviderException;
      expect(providerError.kind, AiProviderErrorKind.invalidResponse);
      expect(providerError.toString(), isNot(contains(secret)));
    }
  });

  test('validates blank configuration, prompts, image metadata, and tokens',
      () async {
    expect(
      () => AiProviderClient(
        configuration: const AiConfiguration(
          provider: AiProvider.openAI,
          model: ' ',
          apiKey: 'key',
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => AiProviderClient(
        configuration: const AiConfiguration(
          provider: AiProvider.openAI,
          model: 'model',
          apiKey: ' ',
        ),
      ),
      throwsArgumentError,
    );

    final client = AiProviderClient(
      configuration: _configuration(AiProvider.gemini),
      client: MockClient((_) async => http.Response('{}', 200)),
    );
    expect(client.generateText(' '), throwsArgumentError);
    expect(
      client.generateText(
        'prompt',
        imageBytes: Uint8List.fromList([1]),
      ),
      throwsArgumentError,
    );
    expect(
      client.generateText(
        'prompt',
        imageBytes: Uint8List.fromList([1]),
        mimeType: 'image/svg+xml',
      ),
      throwsArgumentError,
    );
    expect(
      client.generateText('prompt', maxTokens: 0),
      throwsArgumentError,
    );
  });
}
