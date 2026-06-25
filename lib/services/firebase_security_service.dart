import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

class FirebaseSecurityService {
  FirebaseSecurityService._();

  static const String _webSiteKey = String.fromEnvironment(
    'FIREBASE_APP_CHECK_WEB_KEY',
  );

  static Future<void>? _initialization;

  static Future<void> ensureReady(
      {bool authenticateAnonymously = false}) async {
    final initialization = _initialization ??= _initialize();
    try {
      await initialization;
    } catch (_) {
      _initialization = null;
      rethrow;
    }

    if (authenticateAnonymously && FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  }

  static Future<void> _initialize() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: kIsWeb
            ? DefaultFirebaseOptions.web
            : DefaultFirebaseOptions.currentPlatform,
      );
    }

    if (kIsWeb) {
      if (_webSiteKey.isEmpty) {
        throw StateError(
          'FIREBASE_APP_CHECK_WEB_KEY is required for protected API calls.',
        );
      }

      await FirebaseAppCheck.instance.activate(
        webProvider: ReCaptchaV3Provider(_webSiteKey),
      );
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      await FirebaseAppCheck.instance.activate(
        androidProvider:
            kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      );
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      await FirebaseAppCheck.instance.activate(
        appleProvider: kDebugMode
            ? AppleProvider.debug
            : AppleProvider.appAttestWithDeviceCheckFallback,
      );
      return;
    }

    throw UnsupportedError(
      'Protected Firebase API calls are supported on Web, Android, iOS, and '
      'macOS only.',
    );
  }
}
