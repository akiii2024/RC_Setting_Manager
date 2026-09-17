import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rc_setting_manager/pages/telemetry_analysis_page.dart';
import 'package:rc_setting_manager/providers/app_mode_provider.dart';
import 'package:rc_setting_manager/providers/settings_provider.dart';
import 'package:rc_setting_manager/services/telemetry_analysis_service.dart';

const _csv = 'TOTAL LAP,1\nBEST LAP,0:10.00\n'
    'LAP,LAP TIME,REC TIME,ST(%),TH(%)\n'
    '1,0:00.00,00:00:00.000,0,20\n'
    '1,0:00.10,00:00:00.100,10,30\n';

Future<SettingsProvider> _pumpPage(
  WidgetTester tester, {
  required bool english,
  required Size size,
  required Brightness brightness,
}) async {
  SharedPreferences.setMockInitialValues({'language_settings': english});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final provider = SettingsProvider(
    appModeProvider: AppModeProvider(
      preferredOnline: false,
      isFirebaseReady: false,
    ),
  );
  final session = TelemetryAnalysisService.parseCsv(
    text: _csv,
    fileName: 'sample.csv',
  );
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: TelemetryAnalysisPage(
          initialSession: session,
          selectionMode: true,
        ),
      ),
    ),
  );
  for (var i = 0; i < 50 && !provider.isInitialized; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
  await tester.pump();
  return provider;
}

void main() {
  testWidgets('360dpの日本語・ダーク表示で概要と添付操作を表示する', (tester) async {
    await _pumpPage(
      tester,
      english: false,
      size: const Size(360, 800),
      brightness: Brightness.dark,
    );

    expect(find.text('テレメトリー分析'), findsOneWidget);
    expect(find.text('セッション概要'), findsOneWidget);
    expect(find.text('このテレメトリーを使用'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('720dp超の英語表示とキーボード再生操作を提供する', (tester) async {
    await _pumpPage(
      tester,
      english: true,
      size: const Size(1000, 900),
      brightness: Brightness.light,
    );

    expect(find.text('Telemetry Analysis'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Replay'), 320);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Pause'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
