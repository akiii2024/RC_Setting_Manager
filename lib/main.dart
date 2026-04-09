// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'pages/car_selection_page.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'pages/settings_page.dart';
import 'providers/app_mode_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/theme_provider.dart';
import 'services/auth_service.dart';

void main() async {
  FlutterError.onError = (FlutterErrorDetails details) {
    print('Flutter Error: ${details.exception}');
    print('Stack trace: ${details.stack}');
  };

  try {
    WidgetsFlutterBinding.ensureInitialized();
  } catch (e) {
    print('WidgetsFlutterBinding initialization error: $e');
  }

  final storedMode = await AppModeProvider.loadStoredPreference();
  var firebaseInitialized = false;

  if (storedMode == true) {
    firebaseInitialized = await _initializeFirebaseWithLogging();
  }

  final appModeProvider = AppModeProvider(
    preferredOnline: storedMode,
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
        child: const MyApp(),
      ),
    ),
  );
}

Future<bool> _initializeFirebaseWithLogging() async {
  var firebaseInitialized = false;

  try {
    print('=== Firebase Configuration Check ===');
    print('Platform: ${kIsWeb ? 'Web' : 'Mobile'}');

    if (Firebase.apps.isEmpty) {
      print('No Firebase apps found, initializing...');

      final options = kIsWeb
          ? DefaultFirebaseOptions.web
          : DefaultFirebaseOptions.currentPlatform;

      print('Project ID: ${options.projectId}');
      print('App ID: ${options.appId}');
      print('API Key: ${options.apiKey.substring(0, 10)}...');

      await Firebase.initializeApp(options: options);
      print('Firebase initialized successfully');
    } else {
      print('Firebase already initialized (${Firebase.apps.length} apps)');
    }

    try {
      final auth = FirebaseAuth.instance;
      print('Firebase Auth instance created successfully');
      print('Current user: ${auth.currentUser?.uid ?? 'None'}');
    } catch (e) {
      print('Firebase Auth test failed: $e');
    }

    try {
      FirebaseFirestore.instance;
      print('Firebase Firestore instance created successfully');
    } catch (e) {
      print('Firebase Firestore test failed: $e');
    }

    print('=== Firebase Configuration Check Complete ===');
    firebaseInitialized = true;
  } catch (e) {
    print('Firebase initialization error: $e');
    print('Error type: ${e.runtimeType}');
    if (e is FirebaseException) {
      print('Firebase Error Code: ${e.code}');
      print('Firebase Error Message: ${e.message}');
    }
    firebaseInitialized = false;
  }

  return firebaseInitialized;
}

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
                body: Center(
                  child: CircularProgressIndicator(),
                ),
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
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    try {
      return Consumer<SettingsProvider>(
        builder: (context, settingsProvider, child) {
          return Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return MaterialApp(
                title: 'Engineering Precision',
                theme: _buildLightTheme(),
                darkTheme: _buildDarkTheme(),
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
                  '/login': (context) => const LoginPage(),
                },
                onGenerateRoute: (settings) {
                  if (settings.name != null && settings.name!.startsWith('/')) {
                    return MaterialPageRoute(
                      builder: (context) => const HomePage(),
                    );
                  }
                  return null;
                },
                builder: (context, widget) {
                  ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
                    return _buildErrorWidget(errorDetails);
                  };
                  return widget!;
                },
              );
            },
          );
        },
      );
    } catch (e) {
      print('MaterialApp build error: $e');
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text('Application failed to start.'),
                const SizedBox(height: 8),
                Text('$e'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    main();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  Widget _buildErrorWidget(FlutterErrorDetails errorDetails) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('An unexpected UI error occurred.'),
              const SizedBox(height: 8),
              Text('${errorDetails.exception}'),
              if (kDebugMode) ...[
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text('${errorDetails.stack}'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  ThemeData _buildLightTheme() {
    const primaryColor = Color(0xFF005BCF);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
    ).copyWith(
      primary: primaryColor,
      secondary: const Color(0xFF475E8C),
      tertiary: const Color(0xFF9E4300),
      primaryContainer: const Color(0xFF1A73E8),
      secondaryContainer: const Color(0xFFD8E2FF),
      tertiaryContainer: const Color(0xFFFFDBCB),
      surface: const Color(0xFFF8F9FA),
      surfaceContainerLowest: const Color(0xFFFFFFFF),
      surfaceContainerLow: const Color(0xFFF3F4F5),
      surfaceContainerHighest: const Color(0xFFE1E3E4),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onTertiary: Colors.white,
      onSurface: const Color(0xFF191C1D),
      onSurfaceVariant: const Color(0xFF414754),
      outline: const Color(0xFF727785),
      outlineVariant: const Color(0xFFC1C6D6),
      error: const Color(0xFFBA1A1A),
      onError: Colors.white,
    );

    return _buildThemeData(
      colorScheme: colorScheme,
      brightness: Brightness.light,
    );
  }

  ThemeData _buildDarkTheme() {
    const primaryColor = Color(0xFFADC7FF);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
    ).copyWith(
      primary: primaryColor,
      secondary: const Color(0xFFB8C8E8),
      tertiary: const Color(0xFFFFB691),
      primaryContainer: const Color(0xFF004493),
      secondaryContainer: const Color(0xFF2E4673),
      tertiaryContainer: const Color(0xFF783100),
      surface: const Color(0xFF101417),
      surfaceContainerLowest: const Color(0xFF151A1C),
      surfaceContainerLow: const Color(0xFF1D2327),
      surfaceContainerHighest: const Color(0xFF2A3136),
      onPrimary: const Color(0xFF001A41),
      onSecondary: const Color(0xFF0F1B2D),
      onTertiary: const Color(0xFF341100),
      onSurface: const Color(0xFFF0F1F2),
      onSurfaceVariant: const Color(0xFFC1C7D0),
      outline: const Color(0xFF8A9099),
      outlineVariant: const Color(0xFF424954),
      error: const Color(0xFFFFB4AB),
      onError: const Color(0xFF690005),
    );

    return _buildThemeData(
      colorScheme: colorScheme,
      brightness: Brightness.dark,
    );
  }

  ThemeData _buildThemeData({
    required ColorScheme colorScheme,
    required Brightness brightness,
  }) {
    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
    );

    final textTheme = _buildTechnicalTextTheme(
      baseTheme.textTheme,
      colorScheme.onSurface,
    );

    return baseTheme.copyWith(
      scaffoldBackgroundColor: colorScheme.surface,
      canvasColor: colorScheme.surface,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surface.withValues(alpha: 0.94),
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surfaceContainerLowest,
        indicatorColor: colorScheme.primary.withValues(
          alpha: brightness == Brightness.light ? 0.12 : 0.16,
        ),
        height: 72,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final color = states.contains(WidgetState.selected)
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant;
          return IconThemeData(color: color);
        }),
      ),
      cardTheme: CardThemeData(
        color: brightness == Brightness.light
            ? colorScheme.surfaceContainerLowest
            : colorScheme.surfaceContainerLow,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: brightness == Brightness.light
            ? colorScheme.onSurface.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.18),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(
              alpha: brightness == Brightness.light ? 0.35 : 0.6,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        shape: const CircleBorder(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 1,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Colors.transparent,
        thickness: 0,
        space: 0,
      ),
      iconTheme: IconThemeData(
        color: colorScheme.onSurfaceVariant,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: brightness == Brightness.light
            ? const Color(0xFF2E3132)
            : const Color(0xFF1E2529),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: brightness == Brightness.light
              ? Colors.white
              : colorScheme.onSurface,
        ),
        actionTextColor: brightness == Brightness.light
            ? colorScheme.primaryContainer
            : colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  TextTheme _buildTechnicalTextTheme(
    TextTheme base,
    Color textColor,
  ) {
    final bodyTheme = GoogleFonts.interTextTheme(base).apply(
      bodyColor: textColor,
      displayColor: textColor,
    );

    TextStyle bodyStyle(
      TextStyle? style, {
      FontWeight? fontWeight,
      double? letterSpacing,
      double? fontSize,
    }) {
      return GoogleFonts.inter(
        textStyle: style,
        color: textColor,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
        fontSize: fontSize,
      );
    }

    TextStyle headlineStyle(
      TextStyle? style, {
      FontWeight? fontWeight,
      double? letterSpacing,
      double? fontSize,
    }) {
      return GoogleFonts.spaceGrotesk(
        textStyle: style,
        color: textColor,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
        fontSize: fontSize,
      );
    }

    return bodyTheme.copyWith(
      displayLarge: headlineStyle(
        bodyTheme.displayLarge,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.8,
      ),
      displayMedium: headlineStyle(
        bodyTheme.displayMedium,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.4,
      ),
      displaySmall: headlineStyle(
        bodyTheme.displaySmall,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.0,
      ),
      headlineLarge: headlineStyle(
        bodyTheme.headlineLarge,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.9,
      ),
      headlineMedium: headlineStyle(
        bodyTheme.headlineMedium,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
      ),
      titleLarge: headlineStyle(
        bodyTheme.titleLarge,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleMedium: bodyStyle(
        bodyTheme.titleMedium,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: bodyStyle(
        bodyTheme.titleSmall,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: bodyStyle(bodyTheme.bodyLarge),
      bodyMedium: bodyStyle(bodyTheme.bodyMedium),
      bodySmall: bodyStyle(bodyTheme.bodySmall),
      labelLarge: bodyStyle(
        bodyTheme.labelLarge,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
      labelMedium: bodyStyle(
        bodyTheme.labelMedium,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
        fontSize: 12,
      ),
      labelSmall: bodyStyle(
        bodyTheme.labelSmall,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.3,
        fontSize: 10,
      ),
    );
  }
}
