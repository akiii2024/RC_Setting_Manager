import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../pages/car_selection_page.dart';
import '../pages/home_page.dart';
import '../pages/login_page.dart';
import '../pages/settings_page.dart';
import '../providers/app_mode_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../services/auth_service.dart';
import '../utils/app_logger.dart';
import 'app_theme.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<AppModeProvider, AuthService?>(
      builder: (context, mode, authService, child) {
        if (mode.preferredOnline == false) {
          return const HomePage();
        }

        if (mode.preferredOnline == true && !mode.isFirebaseReady) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Loading online mode...',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          );
        }

        if (authService == null) {
          return const LoginPage();
        }

        return StreamBuilder<User?>(
          stream: authService.firebaseAuth?.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.data == null) {
              return const LoginPage();
            }

            return const HomePage();
          },
        );
      },
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    try {
      return Consumer<SettingsProvider>(
        builder: (context, settingsProvider, child) {
          return Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return MaterialApp(
                title: 'Engineering Precision',
                theme: AppTheme.light(),
                darkTheme: AppTheme.dark(),
                themeMode:
                    themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: const [
                  Locale('ja', 'JP'),
                  Locale('en', 'US'),
                ],
                locale: settingsProvider.isEnglish
                    ? const Locale('en', 'US')
                    : const Locale('ja', 'JP'),
                debugShowCheckedModeBanner: false,
                initialRoute: '/',
                routes: {
                  '/': (context) => const AuthWrapper(),
                  '/car-selection': (context) => const CarSelectionPage(),
                  '/settings': (context) => const SettingsPage(),
                },
                onGenerateRoute: (settings) {
                  if (settings.name?.startsWith('/') ?? false) {
                    return MaterialPageRoute(
                      builder: (context) => const HomePage(),
                    );
                  }
                  return null;
                },
              );
            },
          );
        },
      );
    } catch (error) {
      debugLog('MaterialApp build error: $error');
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text('Application failed to start.'),
                if (kDebugMode) ...[
                  const SizedBox(height: 8),
                  Text('$error'),
                ],
                if (onRetry != null) ...[
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: onRetry,
                    child: const Text('Retry'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }
  }
}
