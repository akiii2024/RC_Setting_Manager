import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rc_setting_manager/services/telemetry_analysis_service.dart';
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
}
