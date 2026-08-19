import 'package:firebase_auth/firebase_auth.dart' show User;
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
        if (!mode.onlineCapabilityEnabled || mode.preferredOnline == false) {
          return const HomePage();
        }

        if (!mode.isOnlineActive && mode.preferredOnline == true) {
          return _OnlineModeRecoveryView(
            modeProvider: mode,
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

class _OnlineModeRecoveryView extends StatefulWidget {
  const _OnlineModeRecoveryView({required this.modeProvider});

  final AppModeProvider modeProvider;

  @override
  State<_OnlineModeRecoveryView> createState() =>
      _OnlineModeRecoveryViewState();
}

class _OnlineModeRecoveryViewState extends State<_OnlineModeRecoveryView> {
  var _isBusy = false;
  var _initializationFailed = false;

  Future<void> _retryOnlineMode() async {
    if (_isBusy || widget.modeProvider.isInitializingFirebase) {
      return;
    }
    setState(() {
      _isBusy = true;
      _initializationFailed = false;
    });

    try {
      await widget.modeProvider.setOnlineAndInit();
    } catch (error, stackTrace) {
      debugLog('Online mode initialization failed: $error');
      debugLog('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _initializationFailed = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _useOfflineMode() async {
    if (_isBusy || widget.modeProvider.isInitializingFirebase) {
      return;
    }
    setState(() {
      _isBusy = true;
      _initializationFailed = false;
    });

    try {
      await widget.modeProvider.setOffline();
    } catch (error, stackTrace) {
      debugLog('Offline mode selection failed: $error');
      debugLog('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _initializationFailed = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final initializing = _isBusy || widget.modeProvider.isInitializingFirebase;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (initializing) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Loading online mode...',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ] else ...[
                const Icon(Icons.cloud_off, size: 56, color: Colors.orange),
                const SizedBox(height: 16),
                Text(
                  _initializationFailed
                      ? 'Online mode could not be initialized.'
                      : 'Online mode is not ready.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    ElevatedButton(
                      key: const Key('online-mode-retry'),
                      onPressed: _retryOnlineMode,
                      child: const Text('Retry'),
                    ),
                    OutlinedButton(
                      key: const Key('online-mode-use-offline'),
                      onPressed: _useOfflineMode,
                      child: const Text('Use offline'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
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
  }
}
