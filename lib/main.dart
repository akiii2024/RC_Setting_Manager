import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'pages/car_selection_page.dart';
import 'pages/home_page.dart';
import 'pages/settings_page.dart';
import 'pages/history_page.dart';
import 'pages/tools_page.dart';
import 'pages/login_page.dart';
import 'providers/theme_provider.dart';
import 'providers/settings_provider.dart';
import 'services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

void main() async {
  // エラーハンドリングを最初に設定
  FlutterError.onError = (FlutterErrorDetails details) {
    print('Flutter Error: ${details.exception}');
    print('Stack trace: ${details.stack}');
  };

  try {
    WidgetsFlutterBinding.ensureInitialized();
  } catch (e) {
    print('WidgetsFlutterBinding initialization error: $e');
  }

  // 環境変数の読み込み
  try {
    await dotenv.load(fileName: ".env");
    print('Environment variables loaded successfully');
  } catch (e) {
    print('Environment variables loading error: $e');
    // 環境変数が読み込めなくてもアプリは続行
  }

  // Firebase初期化をより安全に行う
  bool firebaseInitialized = false;
  try {
    if (kIsWeb) {
      // Web環境でのFirebase初期化
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.web,
      );
    } else {
      // モバイル環境でのFirebase初期化
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    firebaseInitialized = true;
    print('Firebase initialized successfully');
  } catch (e) {
    print('Firebase initialization error: $e');
    // Firebaseが初期化できなくてもアプリは続行
    firebaseInitialized = false;
  }
  runApp(
    MyAppWrapper(firebaseInitialized: firebaseInitialized),
  );
}

class MyAppWrapper extends StatelessWidget {
  final bool firebaseInitialized;

  const MyAppWrapper({super.key, required this.firebaseInitialized});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
          lazy: false,
        ),
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(),
          lazy: false,
        ),
        // Firebaseが初期化できた場合のみAuthServiceを提供
        if (firebaseInitialized)
          ChangeNotifierProvider(
            create: (_) => AuthService(),
            lazy: false,
          ),
      ],
      child: const MyApp(),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // エラーが発生した場合のフォールバック
    try {
      return Consumer<SettingsProvider>(
        builder: (context, settingsProvider, child) {
          return Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return MaterialApp(
                title: 'RC Car Setting App',
                theme: _buildLightTheme(context),
                darkTheme: _buildDarkTheme(context),
                themeMode:
                    themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: const [
                  Locale("ja", "JP"),
                  Locale("en", "US"),
                ],
                locale: settingsProvider.isEnglish
                    ? const Locale("en", "US")
                    : const Locale("ja", "JP"),
                debugShowCheckedModeBanner: false,
                initialRoute: '/',
                routes: {
                  '/': (context) => const HomePage(),
                  '/car-selection': (context) => const CarSelectionPage(),
                  '/settings': (context) => const SettingsPage(),
                  '/login': (context) => const LoginPage(),
                },
                onGenerateRoute: (settings) {
                  // PWAからのルーティング処理
                  if (settings.name != null && settings.name!.startsWith('/')) {
                    // ルートパスにリダイレクト
                    return MaterialPageRoute(
                      builder: (context) => const HomePage(),
                    );
                  }
                  return null;
                },
                // エラー時のフォールバック画面
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
                const Text('アプリの初期化エラー'),
                const SizedBox(height: 8),
                Text('$e'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // アプリを再起動
                    main();
                  },
                  child: const Text('再試行'),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  // エラーウィジェットの構築
  Widget _buildErrorWidget(FlutterErrorDetails errorDetails) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text('エラーが発生しました'),
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
    );
  }

  // ライトテーマの構築（Google Fontsのエラー対策）
  ThemeData _buildLightTheme(BuildContext context) {
    TextTheme textTheme;
    try {
      textTheme = kIsWeb
          ? Theme.of(context).textTheme // Web環境ではデフォルトフォントを使用
          : GoogleFonts.notoSansJpTextTheme(Theme.of(context).textTheme);
    } catch (e) {
      print('Google Fonts error: $e');
      textTheme = Theme.of(context).textTheme; // エラー時はデフォルトフォント
    }

    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF4CAF50),
        brightness: Brightness.light,
        primary: const Color(0xFF4CAF50),
        secondary: const Color(0xFF66BB6A),
        tertiary: const Color(0xFF81C784),
        surface: const Color(0xFFFAFAFA),
        background: const Color(0xFFF5F5F5),
        error: Colors.red[700]!,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Colors.black87,
        onBackground: Colors.black87,
        onError: Colors.white,
      ),
      useMaterial3: true,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        titleTextStyle: _buildTitleTextStyle(),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: Color(0xFF4CAF50),
        unselectedItemColor: Color(0xFF757575),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        backgroundColor: Colors.white,
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 2,
          backgroundColor: const Color(0xFF4CAF50),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        elevation: 4,
        shape: CircleBorder(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
        ),
        contentPadding: const EdgeInsets.all(16),
        hintStyle: const TextStyle(color: Color(0xFF9E9E9E)),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE0E0E0),
        thickness: 1,
      ),
      iconTheme: const IconThemeData(
        color: Color(0xFF757575),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xFF323232),
        contentTextStyle: TextStyle(color: Colors.white),
        actionTextColor: Color(0xFF81C784),
      ),
    );
  }

  // ダークテーマの構築（Google Fontsのエラー対策）
  ThemeData _buildDarkTheme(BuildContext context) {
    TextTheme textTheme;
    try {
      textTheme = kIsWeb
          ? ThemeData(brightness: Brightness.dark).textTheme // Web環境ではデフォルトフォント
          : GoogleFonts.notoSansJpTextTheme(
              ThemeData(brightness: Brightness.dark).textTheme);
    } catch (e) {
      print('Google Fonts error: $e');
      textTheme = ThemeData(brightness: Brightness.dark).textTheme;
    }

    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF4CAF50),
        brightness: Brightness.dark,
        primary: const Color(0xFF81C784),
        secondary: const Color(0xFF66BB6A),
        tertiary: const Color(0xFFA5D6A7),
        surface: const Color(0xFF1E1E1E),
        background: const Color(0xFF121212),
        error: const Color(0xFFFF5252),
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: Colors.white,
        onBackground: Colors.white,
        onError: Colors.black,
      ),
      useMaterial3: true,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        titleTextStyle: _buildTitleTextStyle(),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: Color(0xFF81C784),
        unselectedItemColor: Color(0xFF9E9E9E),
        backgroundColor: Color(0xFF1E1E1E),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      cardTheme: CardTheme(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: const Color(0xFF2C2C2C),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 4,
          backgroundColor: const Color(0xFF4CAF50),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        elevation: 6,
        shape: CircleBorder(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2C2C2C),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF424242)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF81C784), width: 2),
        ),
        contentPadding: const EdgeInsets.all(16),
        hintStyle: const TextStyle(color: Color(0xFF757575)),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF424242),
        thickness: 1,
      ),
      iconTheme: const IconThemeData(
        color: Color(0xFF9E9E9E),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xFF424242),
        contentTextStyle: TextStyle(color: Colors.white),
        actionTextColor: Color(0xFF81C784),
      ),
    );
  }

  // タイトルテキストスタイル（安全な方法で取得）
  TextStyle _buildTitleTextStyle() {
    try {
      if (kIsWeb) {
        return const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        );
      } else {
        return GoogleFonts.notoSansJp(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        );
      }
    } catch (e) {
      return const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        color: Colors.white,
      );
    }
  }
}
