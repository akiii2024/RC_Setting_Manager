import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_mode_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../services/auth_service.dart';
import '../utils/app_logger.dart';
import 'app.dart';
import 'app_error_view.dart';

/// Initializes framework services and assembles the application's root
/// dependencies.
///
/// The current release deliberately remains offline-only. Firebase-backed
/// implementations stay wired behind [AppModeProvider] so they can be enabled
/// without changing the widget tree when online mode is released again.
Future<void> bootstrapApplication() async {
  FlutterError.onError = (details) {
    debugLog('Flutter Error: ${details.exception}');
    debugLog('Stack trace: ${details.stack}');
  };

  try {
    WidgetsFlutterBinding.ensureInitialized();
  } catch (error) {
    debugLog('WidgetsFlutterBinding initialization error: $error');
  }

  ErrorWidget.builder = AppErrorView.build;

  const preferredOnline = false;
  const firebaseInitialized = false;
  final appModeProvider = AppModeProvider(
    preferredOnline: preferredOnline,
    isFirebaseReady: firebaseInitialized,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppModeProvider>.value(value: appModeProvider),
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
          lazy: false,
        ),
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(),
          lazy: false,
        ),
      ],
      child: Consumer<AppModeProvider>(
        builder: (context, mode, child) {
          if (mode.isFirebaseReady) {
            return ChangeNotifierProvider(
              create: (_) => AuthService(),
              lazy: false,
              child: child,
            );
          }

          return Provider<AuthService?>.value(
            value: null,
            child: child,
          );
        },
        child: MyApp(
          onRetry: () {
            bootstrapApplication();
          },
        ),
      ),
    ),
  );
}
