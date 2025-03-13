import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'pages/car_selection_page.dart';
import 'pages/home_page.dart';
import 'pages/settings_page.dart';
import 'pages/history_page.dart';
import 'pages/tools_page.dart';
import 'providers/theme_provider.dart';
import 'providers/settings_provider.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'RCカーセッティングアプリ',
          theme: ThemeData(
            primarySwatch: Colors.blue,
            visualDensity: VisualDensity.adaptivePlatformDensity,
            brightness: Brightness.light,
          ),
          darkTheme: ThemeData(
            primarySwatch: Colors.blue,
            visualDensity: VisualDensity.adaptivePlatformDensity,
            brightness: Brightness.dark,
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
          ],
          debugShowCheckedModeBanner: false,
          initialRoute: '/',
          routes: {
            '/': (context) => const HomePage(),
            '/car_selection': (context) => const CarSelectionPage(),
            '/settings': (context) => const SettingsPage(),
            '/history': (context) => const HistoryPage(),
            '/tools': (context) => const ToolsPage(),
          },
        );
      },
    );
  }
}
