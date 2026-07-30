import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/ai_provider.dart';

enum AiProviderErrorKind {
  authentication,
  rateLimit,
  invalidRequest,
  serviceUnavailable,
  timeout,
  network,
  invalidResponse,
}

/// プロバイダのレスポンス本文やAPIキーを公開しない共通例外。
class AiProviderException implements Exception {
  const AiProviderException({
    required this.provider,
    required this.kind,
    required this.message,
    this.statusCode,
  });

  final AiProvider provider;
  final AiProviderErrorKind kind;
  final String message;
  final int? statusCode;

  @override
  String toString() {
    final status = statusCode == null ? '' : ', statusCode: $statusCode';
    return 'AiProviderException(provider: ${provider.value}, '
        'kind: ${kind.name}$status, message: $message)';
  }
}

/// OpenAI・Anthropic・GeminiのREST APIを同じインターフェースで扱う。
///
/// APIキーはすべてHTTPヘッダーへ設定し、URL・本文・例外には含めない。
class AiProviderClient {
  static const int maxImageBytes = 10 * 1024 * 1024;
  static const int maxPromptCharacters = 50000;
  static const int maxSystemCharacters = 20000;
  static const int maxSchemaCharacters = 100000;
  static const int maxOutputTokens = 8192;

  AiProviderClient({
    required AiConfiguration configuration,
    http.Client? client,
    this.timeout = const Duration(seconds: 120),
    Uri? openAiBaseUri,
    Uri? anthropicBaseUri,
    Uri? geminiBaseUri,
  })  : provider = configuration.provider,
        model = _normalizedModel(
          configuration.provider,
          configuration.model,
        ),
        _apiKey = _requiredValue(
          configuration.apiKey,
          'APIキー',
          maxLength: 2048,
        ),
        _client = client ?? http.Client(),
        _ownsClient = client == null,
        _openAiBaseUri =
            openAiBaseUri ?? Uri.parse('https://api.openai.com/v1'),
        _anthropicBaseUri =
            anthropicBaseUri ?? Uri.parse('https://api.anthropic.com/v1'),
        _geminiBaseUri = geminiBaseUri ??
            Uri.parse('https://generativelanguage.googleapis.com/v1beta') {
    if (timeout <= Duration.zero) {
      throw ArgumentError('タイムアウト時間は0秒より長くしてください。');
    }
  }

  final AiProvider provider;
  final String model;
  final Duration timeout;
  final String _apiKey;
  final http.Client _client;
  final bool _ownsClient;
  final Uri _openAiBaseUri;
  final Uri _anthropicBaseUri;
  final Uri _geminiBaseUri;

  static String _requiredValue(
    String value,
    String label, {
    int? maxLength,
  }) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError('$labelを空白だけにすることはできません。');
    }
    if (maxLength != null && normalized.length > maxLength) {
      throw ArgumentError('$labelが長すぎます。');
    }
    return normalized;
  }

  static String _normalizedModel(AiProvider provider, String value) {
    final normalized = _requiredValue(value, 'モデル名', maxLength: 200);
    if (provider == AiProvider.gemini && normalized.startsWith('models/')) {
      return _requiredValue(
        normalized.substring('models/'.length),
        'モデル名',
        maxLength: 200,
      );
    }
    return normalized;
  }

  Future<Map<String, dynamic>> generateStructured({
    required String system,
    required String prompt,
    required Map<String, dynamic> schema,
    required String schemaName,
    int maxTokens = 4096,
  }) async {
    final normalizedSystem = _requiredValue(
      system,
      'システム指示',
      maxLength: maxSystemCharacters,
    );
    final normalizedPrompt = _requiredValue(
      prompt,
      'プロンプト',
      maxLength: maxPromptCharacters,
    );
    final normalizedSchemaName = _validateSchemaName(schemaName);
    if (jsonEncode(schema).length > maxSchemaCharacters) {
      throw ArgumentError('レスポンススキーマが大きすぎます。');
    }
    _validateMaxTokens(maxTokens);

    final response = switch (provider) {
      AiProvider.openAI => await _postJson(
          _endpoint(_openAiBaseUri, 'responses'),
          _headers(),
          {
            'model': model,
            'instructions': normalizedSystem,
            'input': normalizedPrompt,
            'max_output_tokens': maxTokens,
            'store': false,
            'text': {
              'format': {
                'type': 'json_schema',
                'name': normalizedSchemaName,
                'strict': true,
                'schema': schema,
              },
            },
          },
        ),
      AiProvider.anthropic => await _postJson(
          _endpoint(_anthropicBaseUri, 'messages'),
          _headers(),
          {
            'model': model,
            'system': normalizedSystem,
            'max_tokens': maxTokens,
            'messages': [
              {
                'role': 'user',
                'content': normalizedPrompt,
              },
            ],
            'output_config': {
              'format': {
                'type': 'json_schema',
                'schema': schema,
              },
            },
          },
        ),
      AiProvider.gemini => await _postJson(
          _geminiGenerateContentUri(),
          _headers(),
          {
            'systemInstruction': {
              'parts': [
                {'text': normalizedSystem},
              ],
            },
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {'text': normalizedPrompt},
                ],
              },
            ],
            'generationConfig': {
              'maxOutputTokens': maxTokens,
              'responseFormat': {
                'text': {
                  'mimeType': 'application/json',
                  'schema': schema,
                },
              },
            },
          },
        ),
    };

    return _decodeStructuredOutput(_extractText(response));
  }

  Future<String> generateText(
    String prompt, {
    Uint8List? imageBytes,
    String? mimeType,
    int maxTokens = 4096,
  }) async {
    final normalizedPrompt = _requiredValue(
      prompt,
      'プロンプト',
      maxLength: maxPromptCharacters,
    );
    final normalizedMimeType = _validateImage(imageBytes, mimeType);
    _validateMaxTokens(maxTokens);

    final response = switch (provider) {
      AiProvider.openAI => await _postJson(
          _endpoint(_openAiBaseUri, 'responses'),
          _headers(),
          {
            'model': model,
            'input': imageBytes == null
                ? normalizedPrompt
                : [
                    {
                      'role': 'user',
                      'content': [
                        {
                          'type': 'input_text',
                          'text': normalizedPrompt,
                        },
                        {
                          'type': 'input_image',
                          'image_url': _dataUrl(
                            imageBytes,
                            normalizedMimeType!,
                          ),
                        },
                      ],
                    },
                  ],
            'max_output_tokens': maxTokens,
            'store': false,
          },
        ),
      AiProvider.anthropic => await _postJson(
          _endpoint(_anthropicBaseUri, 'messages'),
          _headers(),
          {
            'model': model,
            'max_tokens': maxTokens,
            'messages': [
              {
                'role': 'user',
                'content': imageBytes == null
                    ? normalizedPrompt
                    : [
                        {
                          'type': 'text',
                          'text': normalizedPrompt,
                        },
                        {
                          'type': 'image',
                          'source': {
                            'type': 'base64',
                            'media_type': normalizedMimeType,
                            'data': base64Encode(imageBytes),
                          },
                        },
                      ],
              },
            ],
          },
        ),
      AiProvider.gemini => await _postJson(
          _geminiGenerateContentUri(),
          _headers(),
          {
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {'text': normalizedPrompt},
                  if (imageBytes != null)
                    {
                      'inlineData': {
                        'mimeType': normalizedMimeType,
                        'data': base64Encode(imageBytes),
                      },
                    },
                ],
              },
            ],
            'generationConfig': {
              'maxOutputTokens': maxTokens,
            },
          },
        ),
    };

    return _extractText(response);
  }

  /// モデル取得APIを使用し、生成料金を発生させずに接続を確認する。
  Future<bool> testConnection() async {
    final encodedModel = Uri.encodeComponent(model);
    final uri = switch (provider) {
      AiProvider.openAI => _endpoint(_openAiBaseUri, 'models/$encodedModel'),
      AiProvider.anthropic =>
        _endpoint(_anthropicBaseUri, 'models/$encodedModel'),
      AiProvider.gemini => _endpoint(_geminiBaseUri, 'models/$encodedModel'),
    };

    await _getJson(uri, _headers());
    return true;
  }

  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }

  Map<String, String> _headers() {
    return switch (provider) {
      AiProvider.openAI => {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
      AiProvider.anthropic => {
          'Content-Type': 'application/json',
          'x-api-key': _apiKey,
          'anthropic-version': '2023-06-01',
          'anthropic-dangerous-direct-browser-access': 'true',
        },
      AiProvider.gemini => {
          'Content-Type': 'application/json',
          'x-goog-api-key': _apiKey,
        },
    };
  }

  Uri _geminiGenerateContentUri() {
    final encodedModel = Uri.encodeComponent(model);
    return _endpoint(
      _geminiBaseUri,
      'models/$encodedModel:generateContent',
    );
  }

  Uri _endpoint(Uri baseUri, String path) {
    final base = baseUri.toString().replaceFirst(RegExp(r'/+$'), '');
    final relative = path.replaceFirst(RegExp(r'^/+'), '');
    return Uri.parse('$base/$relative');
  }

  String _validateSchemaName(String schemaName) {
    final normalized = _requiredValue(schemaName, 'スキーマ名');
    if (normalized.length > 64 ||
        !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(normalized)) {
      throw ArgumentError('スキーマ名には英数字、ハイフン、アンダースコアだけを使用してください。');
    }
    return normalized;
  }

  void _validateMaxTokens(int maxTokens) {
    if (maxTokens <= 0 || maxTokens > maxOutputTokens) {
      throw ArgumentError(
        '最大トークン数は1以上$maxOutputTokens以下にしてください。',
      );
    }
  }

  String? _validateImage(Uint8List? imageBytes, String? mimeType) {
    if (imageBytes == null) {
      if (mimeType != null && mimeType.trim().isNotEmpty) {
        throw ArgumentError('MIMEタイプを指定する場合は画像データも指定してください。');
      }
      return null;
    }
    if (imageBytes.isEmpty) {
      throw ArgumentError('画像データが空です。');
    }
    if (imageBytes.lengthInBytes > maxImageBytes) {
      throw ArgumentError('画像は10 MiB以下にしてください。');
    }

    final normalized = mimeType?.trim().toLowerCase() ?? '';
    const supportedImageTypes = {
      'image/jpeg',
      'image/png',
      'image/webp',
      'image/gif',
    };
    if (!supportedImageTypes.contains(normalized)) {
      throw ArgumentError('JPEG、PNG、WebP、GIFの画像を指定してください。');
    }
    return normalized;
  }

  String _dataUrl(Uint8List bytes, String mimeType) {
    return 'data:$mimeType;base64,${base64Encode(bytes)}';
  }

  Future<Map<String, dynamic>> _postJson(
    Uri uri,
    Map<String, String> headers,
    Map<String, dynamic> body,
  ) async {
    final response = await _performRequest(
      () => _client.post(uri, headers: headers, body: jsonEncode(body)),
    );
    return _decodeSuccessfulResponse(response);
  }

  Future<Map<String, dynamic>> _getJson(
    Uri uri,
    Map<String, String> headers,
  ) async {
    final response = await _performRequest(
      () => _client.get(uri, headers: headers),
    );
    return _decodeSuccessfulResponse(response);
  }

  Future<http.Response> _performRequest(
    Future<http.Response> Function() request,
  ) async {
    try {
      final response = await request().timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _httpException(response.statusCode);
      }
      return response;
    } on AiProviderException {
      rethrow;
    } on TimeoutException {
      throw AiProviderException(
        provider: provider,
        kind: AiProviderErrorKind.timeout,
        message: '${provider.displayName}への接続がタイムアウトしました。',
      );
    } on http.ClientException {
      throw AiProviderException(
        provider: provider,
        kind: AiProviderErrorKind.network,
        message: '${provider.displayName}へ接続できませんでした。',
      );
    } catch (_) {
      throw AiProviderException(
        provider: provider,
        kind: AiProviderErrorKind.network,
        message: '${provider.displayName}との通信中にエラーが発生しました。',
      );
    }
  }

  AiProviderException _httpException(int statusCode) {
    if (statusCode == 401 || statusCode == 403) {
      return AiProviderException(
        provider: provider,
        kind: AiProviderErrorKind.authentication,
        statusCode: statusCode,
        message: '${provider.displayName}のAPIキーまたは利用権限を確認してください。',
      );
    }
    if (statusCode == 429) {
      return AiProviderException(
        provider: provider,
        kind: AiProviderErrorKind.rateLimit,
        statusCode: statusCode,
        message: '${provider.displayName}の利用上限に達しました。しばらく待って再試行してください。',
      );
    }
    if (statusCode >= 400 && statusCode < 500) {
      return AiProviderException(
        provider: provider,
        kind: AiProviderErrorKind.invalidRequest,
        statusCode: statusCode,
        message: '${provider.displayName}へのリクエストを処理できませんでした。モデル設定を確認してください。',
      );
    }
    return AiProviderException(
      provider: provider,
      kind: AiProviderErrorKind.serviceUnavailable,
      statusCode: statusCode,
      message: '${provider.displayName}のサービスを現在利用できません。',
    );
  }

  Map<String, dynamic> _decodeSuccessfulResponse(http.Response response) {
    if (response.bodyBytes.isEmpty) {
      throw _invalidResponse('AIサービスから空の応答が返されました。');
    }

    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) {
        throw const FormatException();
      }
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      throw _invalidResponse('AIサービスから不正なJSON応答が返されました。');
    }
  }

  String _extractText(Map<String, dynamic> response) {
    final parts = switch (provider) {
      AiProvider.openAI => _openAiTextParts(response),
      AiProvider.anthropic => _anthropicTextParts(response),
      AiProvider.gemini => _geminiTextParts(response),
    };
    final text = parts.map((part) => part.trim()).where((part) {
      return part.isNotEmpty;
    }).join('\n');
    if (text.isEmpty) {
      throw _invalidResponse('AIサービスから空のテキスト応答が返されました。');
    }
    return text;
  }

  Iterable<String> _openAiTextParts(Map<String, dynamic> response) sync* {
    final directText = response['output_text'];
    if (directText is String) {
      yield directText;
    }

    final output = response['output'];
    if (output is! List) {
      return;
    }
    for (final item in output.whereType<Map>()) {
      final directItemText = item['text'];
      if (directItemText is String) {
        yield directItemText;
      }
      final content = item['content'];
      if (content is! List) {
        continue;
      }
      for (final part in content.whereType<Map>()) {
        final text = part['text'];
        if (text is String) {
          yield text;
        }
      }
    }
  }

  Iterable<String> _anthropicTextParts(Map<String, dynamic> response) sync* {
    final content = response['content'];
    if (content is! List) {
      return;
    }
    for (final part in content.whereType<Map>()) {
      if (part['type'] != null && part['type'] != 'text') {
        continue;
      }
      final text = part['text'];
      if (text is String) {
        yield text;
      }
    }
  }

  Iterable<String> _geminiTextParts(Map<String, dynamic> response) sync* {
    final candidates = response['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      return;
    }
    final firstCandidate = candidates.first;
    if (firstCandidate is! Map) {
      return;
    }
    final content = firstCandidate['content'];
    if (content is! Map) {
      return;
    }
    final parts = content['parts'];
    if (parts is! List) {
      return;
    }
    for (final part in parts.whereType<Map>()) {
      final text = part['text'];
      if (text is String) {
        yield text;
      }
    }
  }

  Map<String, dynamic> _decodeStructuredOutput(String text) {
    var normalized = text.trim();
    if (normalized.startsWith('```')) {
      final firstLineEnd = normalized.indexOf('\n');
      if (firstLineEnd >= 0) {
        normalized = normalized.substring(firstLineEnd + 1);
      }
      if (normalized.trimRight().endsWith('```')) {
        normalized = normalized.trimRight();
        normalized = normalized.substring(0, normalized.length - 3).trim();
      }
    }

    try {
      final decoded = jsonDecode(normalized);
      if (decoded is! Map) {
        throw const FormatException();
      }
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      throw _invalidResponse('AIサービスの構造化出力が不正なJSONでした。');
    }
  }

  AiProviderException _invalidResponse(String message) {
    return AiProviderException(
      provider: provider,
      kind: AiProviderErrorKind.invalidResponse,
      message: message,
    );
  }
}
