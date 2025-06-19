import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
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
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    print('Firebase initialized successfully');
  } catch (e) {
    print('Firebase initialization error: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, SettingsProvider>(
      builder: (context, themeProvider, settingsProvider, child) {
        return MaterialApp(
          title: settingsProvider.isEnglish
              ? 'RC Car Setting App'
              : 'RCカーセッティングアプリ',
          theme: ThemeData(
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
            textTheme: GoogleFonts.notoSansJpTextTheme(
              Theme.of(context).textTheme,
            ),
            appBarTheme: AppBarTheme(
              centerTitle: true,
              elevation: 0,
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              titleTextStyle: GoogleFonts.notoSansJp(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                borderSide:
                    const BorderSide(color: Color(0xFF4CAF50), width: 2),
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
          ),
          darkTheme: ThemeData(
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
            textTheme: GoogleFonts.notoSansJpTextTheme(
              ThemeData(brightness: Brightness.dark).textTheme,
            ),
            appBarTheme: AppBarTheme(
              centerTitle: true,
              elevation: 0,
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              titleTextStyle: GoogleFonts.notoSansJp(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                borderSide:
                    const BorderSide(color: Color(0xFF81C784), width: 2),
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
          ),
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
            '/car_selection': (context) => const CarSelectionPage(),
            '/settings': (context) => const SettingsPage(),
            '/history': (context) => const HistoryPage(),
            '/tools': (context) => const ToolsPage(),
            '/login': (context) => const LoginPage(),
          },
        );
      },
    );
  }
}
