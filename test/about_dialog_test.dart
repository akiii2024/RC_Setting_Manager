import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rc_setting_manager/app/app_theme.dart';
import 'package:rc_setting_manager/pages/settings_page.dart';
import 'package:rc_setting_manager/providers/app_mode_provider.dart';
import 'package:rc_setting_manager/providers/settings_provider.dart';
import 'package:rc_setting_manager/providers/theme_provider.dart';
import 'package:rc_setting_manager/services/auth_service.dart';
import 'package:rc_setting_manager/utils/app_metadata.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

Future<void> _openAbout(
  WidgetTester tester, {
  bool isEnglish = false,
  bool isDark = false,
}) async {
  SharedPreferences.setMockInitialValues({'language_settings': isEnglish});
  final mode = AppModeProvider(
    preferredOnline: false,
    isFirebaseReady: false,
    onlineCapabilityEnabled: false,
  );
  final settings = SettingsProvider(appModeProvider: mode);
  final theme = ThemeProvider();
  addTearDown(() {
    settings.dispose();
    theme.dispose();
    mode.dispose();
  });
  await tester.binding.setSurfaceSize(const Size(360, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: theme),
        Provider<AuthService?>.value(value: null),
      ],
      child: MaterialApp(
        theme: isDark ? AppTheme.dark() : AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const SettingsPage(),
      ),
    ),
  );
  for (var i = 0; i < 50 && !settings.isInitialized; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
  expect(settings.isInitialized, isTrue);
  await tester.pumpAndSettle();
  final tile = find.text(isEnglish ? 'About This App' : 'アプリについて');
  await tester.scrollUntilVisible(tile, 200);
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => rootBundle.evict('pubspec.yaml'));
  tearDown(() {
    binding.defaultBinaryMessenger
        .setMockMethodCallHandler(_shareChannel, null);
    binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  for (final isEnglish in [false, true]) {
    for (final isDark in [false, true]) {
      testWidgets(
          'About links work at narrow width and large text: English=$isEnglish dark=$isDark',
          (tester) async {
        final sharedUrls = <String>[];
        binding.defaultBinaryMessenger.setMockMethodCallHandler(_shareChannel,
            (call) async {
          expect(call.method, 'share');
          sharedUrls.add((call.arguments as Map)['text'] as String);
          return 'test-share-target';
        });
        await _openAbout(tester, isEnglish: isEnglish, isDark: isDark);
        final version =
            AppMetadata.parseVersion(File('pubspec.yaml').readAsStringSync());
        expect(find.text('RC Setting Manager'), findsOneWidget);
        expect(find.text(isEnglish ? 'Version: $version' : 'バージョン: $version'),
            findsOneWidget);
        final links = {
          'Privacy Policy':
              'https://akiii2024.github.io/RC_Setting_Manager/privacy.html',
          isEnglish ? 'GitHub Repository' : 'GitHubリポジトリ':
              'https://github.com/akiii2024/RC_Setting_Manager',
          isEnglish ? 'Report an issue' : '不具合を報告する':
              'https://github.com/akiii2024/RC_Setting_Manager/issues',
        };
        for (final link in links.entries) {
          final label = find.text(link.key);
          expect(label, findsOneWidget);
          await tester.ensureVisible(label);
          await tester.tap(label);
          await tester.pumpAndSettle();
          expect(sharedUrls.last, link.value);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('failed link sharing copies its URL for browser access',
      (tester) async {
    String? copiedUrl;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(_shareChannel,
        (_) async {
      throw PlatformException(code: 'unavailable');
    });
    binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copiedUrl = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    await _openAbout(tester);
    await tester.ensureVisible(find.text('Privacy Policy'));
    await tester.tap(find.text('Privacy Policy'));
    await tester.pumpAndSettle();
    expect(copiedUrl,
        'https://akiii2024.github.io/RC_Setting_Manager/privacy.html');
    expect(find.text('URLをコピーしました。ブラウザに貼り付けて開いてください。'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
