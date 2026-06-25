import 'package:cloud_functions/cloud_functions.dart';

import 'firebase_security_service.dart';

class FirebaseFunctionsService {
  FirebaseFunctionsService._();

  static const String _region = String.fromEnvironment(
    'FIREBASE_FUNCTIONS_REGION',
    defaultValue: 'asia-northeast1',
  );

  static FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: _region);

  static Future<Map<String, dynamic>> call(
    String functionName,
    Map<String, dynamic> data,
  ) async {
    await FirebaseSecurityService.ensureReady(
      authenticateAnonymously: true,
    );

    final callable = _functions.httpsCallable(
      functionName,
      options: HttpsCallableOptions(
        timeout: const Duration(seconds: 120),
      ),
    );

    final result = await callable.call(data);
    if (result.data is! Map) {
      throw FirebaseFunctionsException(
        code: 'invalid-response',
        message: 'Firebase Function returned an invalid response.',
        details: result.data,
      );
    }

    return Map<String, dynamic>.from(result.data as Map);
  }
}
