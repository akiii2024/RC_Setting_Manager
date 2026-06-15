import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../firebase_options.dart';

class FirebaseFunctionsService {
  FirebaseFunctionsService._();

  static const Map<String, String> _functionNameAliases = {
    'generateGeminiContent': 'generateGeminiContentPublic',
    'getCurrentWeather': 'getCurrentWeatherPublic',
    'validateOpenWeatherApiKey': 'validateOpenWeatherApiKeyPublic',
  };

  static const String _region = String.fromEnvironment(
    'FIREBASE_FUNCTIONS_REGION',
    defaultValue: 'asia-northeast1',
  );

  static FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: _region);

  static Future<void> ensureInitialized() async {
    if (Firebase.apps.isNotEmpty) {
      return;
    }

    final options = kIsWeb
        ? DefaultFirebaseOptions.web
        : DefaultFirebaseOptions.currentPlatform;

    await Firebase.initializeApp(options: options);
  }

  static Future<Map<String, dynamic>> call(
    String functionName,
    Map<String, dynamic> data,
  ) async {
    final deployedFunctionName =
        _functionNameAliases[functionName] ?? functionName;

    if (kIsWeb && _functionNameAliases.containsKey(functionName)) {
      return _callPublicHttpFunction(deployedFunctionName, data);
    }

    await ensureInitialized();

    final callable = _functions.httpsCallable(
      deployedFunctionName,
      options: HttpsCallableOptions(
        timeout: const Duration(seconds: 120),
      ),
    );

    final result = await callable.call(data);
    return Map<String, dynamic>.from(result.data as Map);
  }

  static Future<Map<String, dynamic>> _callPublicHttpFunction(
    String functionName,
    Map<String, dynamic> data,
  ) async {
    final uri = Uri.https(
      '$_region-${DefaultFirebaseOptions.web.projectId}.cloudfunctions.net',
      '/$functionName',
    );

    final response = await http
        .post(
          uri,
          headers: const {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'data': data,
          }),
        )
        .timeout(const Duration(seconds: 120));

    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded['error'];
      if (error is Map) {
        throw FirebaseFunctionsException(
          code: error['status']?.toString().toLowerCase() ??
              error['code']?.toString() ??
              'unknown',
          message: error['message']?.toString() ?? 'Function request failed.',
          details: error['details'],
        );
      }

      throw FirebaseFunctionsException(
        code: 'http-${response.statusCode}',
        message: response.body,
      );
    }

    final result = decoded['result'];
    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }

    throw FirebaseFunctionsException(
      code: 'invalid-response',
      message: 'Firebase Function returned an invalid response.',
      details: decoded,
    );
  }
}
