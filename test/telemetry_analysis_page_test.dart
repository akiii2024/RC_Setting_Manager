import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rc_setting_manager/pages/telemetry_analysis_page.dart';
import 'package:rc_setting_manager/providers/app_mode_provider.dart';
import 'package:rc_setting_manager/providers/settings_provider.dart';
import 'package:rc_setting_manager/services/ai_configuration_service.dart';
import 'package:rc_setting_manager/services/telemetry_analysis_service.dart';
import 'package:rc_setting_manager/services/telemetry_ai_analysis_service.dart';

const _csv = 'TOTAL LAP,1\nBEST LAP,0:10.00\n'
    'LAP,LAP TIME,REC TIME,ST(%),TH(%)\n'
    '1,0:00.00,00:00:00.000,0,100\n'
    '1,0:00.05,00:00:00.050,0,80\n'
    '1,0:00.10,00:00:00.100,30,-20\n'
    '1,0:00.15,00:00:00.150,50,-100\n'
    '1,0:00.20,00:00:00.200,50,0\n'
    '1,0:00.25,00:00:00.250,40,10\n'
    '1,0:00.30,00:00:00.300,10,50\n'
    '1,0:00.35,00:00:00.350,0,100\n'
    '1,0:00.40,00:00:00.400,-40,0\n'
    '1,0:00.45,00:00:00.450,-40,-20\n'
    '1,0:00.50,00:00:00.500,0,100\n';

Future<SettingsProvider> _pumpPage(
  WidgetTester tester, {
  required bool english,
  required Size size,
  required Brightness brightness,
  TelemetryAiAnalysisService? aiAnalysisService,
}) async {
  SharedPreferences.setMockInitialValues({
    'language_settings': english,
    'ai_provider_api_consent_v4': true,
  });
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
          aiAnalysisService: aiAnalysisService,
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
    await tester.scrollUntilVisible(find.text('AI走行コーチ'), 300);
    expect(find.text('AI走行コーチ'), findsOneWidget);
    expect(find.text('AIで走行を分析'), findsOneWidget);
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

  testWidgets('AI走行コーチの実行中・成功・単周低信頼・再分析を表示する', (tester) async {
    final response = Completer<Map<String, dynamic>>();
    final service = TelemetryAiAnalysisService(
      configurationService: AiConfigurationService(
        secretStore: MemorySecretStore(),
      ),
      functionCaller: (_, __) => response.future,
    );
    await _pumpPage(
      tester,
      english: false,
      size: const Size(360, 800),
      brightness: Brightness.dark,
      aiAnalysisService: service,
    );

    await tester.scrollUntilVisible(find.text('AIで走行を分析'), 300);
    await tester.tap(find.text('AIで走行を分析'));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    response.complete({
      'analysis': {
        'summary': '入力の再現性を確認できます。',
        'confidence': 'high',
        'strengthEvidenceIds': ['lap_1_full_throttle'],
        'focusAreas': [
          {
            'title': '立ち上がり',
            'evidenceIds': ['lap_1_full_throttle'],
            'inference': '操作入力の傾向です。',
            'coachingTip': '同じ操作を試します。',
            'verification': '次の走行で比較します。',
          },
        ],
        'limitations': <String>[],
      },
      'modelVersion': 'managed-test',
    });
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('入力の再現性を確認できます。'), findsOneWidget);
    expect(find.text('確信度: 低'), findsOneWidget);
    expect(find.text('再分析する'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AI走行コーチの失敗時に再試行できるエラーを表示する', (tester) async {
    final service = TelemetryAiAnalysisService(
      configurationService: AiConfigurationService(
        secretStore: MemorySecretStore(),
      ),
      functionCaller: (_, __) async => throw StateError('一時的に分析できません。'),
    );
    await _pumpPage(
      tester,
      english: false,
      size: const Size(360, 800),
      brightness: Brightness.dark,
      aiAnalysisService: service,
    );

    await tester.scrollUntilVisible(find.text('AIで走行を分析'), 300);
    await tester.tap(find.text('AIで走行を分析'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('一時的に分析できません。'), findsOneWidget);
    expect(find.text('AIで走行を分析'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
