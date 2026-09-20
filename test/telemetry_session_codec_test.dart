import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rc_setting_manager/models/telemetry_ai.dart';
import 'package:rc_setting_manager/services/telemetry_analysis_service.dart';
import 'package:rc_setting_manager/services/telemetry_feature_service.dart';
import 'package:rc_setting_manager/services/telemetry_session_codec.dart';

void main() {
  const csv = 'TOTAL LAP,1\nBEST LAP,0:10.00\n'
      'LAP,LAP TIME,REC TIME,ST(%),TH(%)\n'
      '1,0:00.00,00:00:00.000,0,20\n'
      '1,0:00.10,00:00:00.100,10,30\n';
  const codec = TelemetrySessionCodec();

  test('.stgを動画・表示設定・編集コース込みで往復する', () {
    final session = TelemetryAnalysisService.parseCsv(
      text: csv,
      fileName: 'sample.csv',
      sessionId: 'session-1',
    )
      ..selectedMetrics = ['TH(%)']
      ..viewWindowSeconds = 10
      ..videoFileName = 'run.mp4'
      ..videoBytes = Uint8List.fromList([0, 1, 2, 3])
      ..videoSyncMode = 'end'
      ..videoOffsetMillis = -250;

    final decoded = codec.decode(codec.encode(session));

    expect(decoded.id, 'session-1');
    expect(decoded.csvText, csv);
    expect(decoded.selectedMetrics, ['TH(%)']);
    expect(decoded.viewWindowSeconds, 10);
    expect(decoded.videoFileName, 'run.mp4');
    expect(decoded.videoBytes, [0, 1, 2, 3]);
    expect(decoded.videoSyncMode, 'end');
    expect(decoded.videoOffsetMillis, -250);
  });

  test('クラウド向け保存では動画を除外できる', () {
    final session = TelemetryAnalysisService.parseCsv(
      text: csv,
      fileName: 'sample.csv',
    )
      ..videoFileName = 'run.mp4'
      ..videoBytes = Uint8List.fromList([1, 2, 3]);

    final decoded = codec.decode(codec.encode(session, includeVideo: false));
    expect(decoded.videoBytes, isNull);
  });

  test('.stg v2でAI結果を往復し、入力指紋が一致すると復元する', () {
    final session = TelemetryAnalysisService.parseCsv(
      text: csv,
      fileName: 'sample.csv',
    );
    final fingerprint = TelemetryFeatureService.build(session).inputFingerprint;
    session.aiAnalysis = TelemetryAiResult(
      summary: '操作入力を確認しました。',
      confidence: 'low',
      strengthEvidenceIds: const ['lap_1_full_throttle'],
      focusAreas: const [
        TelemetryAiFocusArea(
          title: '立ち上がり',
          evidenceIds: ['lap_1_full_throttle'],
          inference: '入力傾向です。',
          coachingTip: '再現性を試します。',
          verification: '次の走行で比較します。',
        ),
      ],
      limitations: const ['単周分析です。'],
      provider: 'openai',
      model: 'test-model',
      generatedAt: DateTime.utc(2026, 1, 2),
      inputFingerprint: fingerprint,
    );

    final decoded = codec.decode(codec.encode(session));

    expect(decoded.aiAnalysis?.summary, '操作入力を確認しました。');
    expect(decoded.aiAnalysis?.inputFingerprint, fingerprint);
    expect(decoded.aiAnalysis?.focusAreas.single.title, '立ち上がり');
    expect(decoded.aiAnalysis?.limitations, ['単周分析です。']);
  });

  test('入力指紋が一致しないAI結果は表示用に復元しない', () {
    final session = TelemetryAnalysisService.parseCsv(
      text: csv,
      fileName: 'sample.csv',
    )..aiAnalysis = TelemetryAiResult(
        summary: '古い結果',
        confidence: 'high',
        provider: 'gemini',
        model: 'test-model',
        generatedAt: DateTime.utc(2026, 1, 2),
        inputFingerprint: 'ffffffff',
      );

    final decoded = codec.decode(codec.encode(session));

    expect(decoded.aiAnalysis, isNull);
  });

  test('.stg v1を引き続き読み込める', () {
    final session = TelemetryAnalysisService.parseCsv(
      text: csv,
      fileName: 'sample.csv',
      sessionId: 'legacy-session',
    );
    final source = ZipDecoder().decodeBytes(codec.encode(session));
    final legacy = Archive();
    for (final file in source) {
      if (file.name == 'manifest.json') {
        final manifest = jsonDecode(utf8.decode(file.content as List<int>))
            as Map<String, dynamic>;
        manifest['version'] = 1;
        manifest.remove('aiCoach');
        legacy.addFile(
          ArchiveFile.string('manifest.json', jsonEncode(manifest)),
        );
      } else {
        legacy.addFile(
          ArchiveFile(file.name, file.size, file.content as List<int>),
        );
      }
    }

    final decoded =
        codec.decode(Uint8List.fromList(ZipEncoder().encode(legacy)));

    expect(decoded.id, 'legacy-session');
    expect(decoded.aiAnalysis, isNull);
  });
}
