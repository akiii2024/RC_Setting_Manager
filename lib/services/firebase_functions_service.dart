import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

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
    await ensureInitialized();

    final deployedFunctionName =
        _functionNameAliases[functionName] ?? functionName;
    final callable = _functions.httpsCallable(
      deployedFunctionName,
      options: HttpsCallableOptions(
        timeout: const Duration(seconds: 120),
      ),
    );

    final result = await callable.call(data);
    return Map<String, dynamic>.from(result.data as Map);
  }
}
