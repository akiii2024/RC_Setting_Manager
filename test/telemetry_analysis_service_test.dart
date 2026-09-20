import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:rc_setting_manager/models/telemetry.dart';
import 'package:rc_setting_manager/services/telemetry_analysis_service.dart';

void main() {
  group('SANWA CSV parser', () {
    test('BOM、概要、時刻、欠損メトリクスを解析する', () {
      const csv = '\ufeffTOTAL LAP,2\nBEST LAP,0:10.50\n\n'
          'LAP,LAP TIME,REC TIME,ST(%),TH(%),RPM\n'
          '1,0:10.50,00:00:00.000,0,25,1000\n'
          '1,0:10.50,00:00:00.100,5,30\n';

      final session = TelemetryAnalysisService.parseCsv(
        text: csv,
        fileName: 'sanwa.csv',
      );

      expect(session.samples, hasLength(2));
      expect(session.samples.last.recordMillis, 100);
      expect(session.samples.last['RPM'], isEmpty);
      expect(session.bestLapCandidateMillis, 10500);
      expect(session.selectedMetrics, ['ST(%)', 'TH(%)']);
    });

    test('必須列と不正時刻をユーザー向けエラーにする', () {
      expect(
        () => TelemetryAnalysisService.parseCsv(
          text: 'LAP,LAP TIME,ST(%)\n1,0:10.0,0',
          fileName: 'missing.csv',
        ),
        throwsA(isA<TelemetryFormatException>()),
      );
      expect(
        () => TelemetryAnalysisService.parseCsv(
          text: 'LAP,LAP TIME,REC TIME,ST(%)\n1,0:10.0,invalid:time,0',
          fileName: 'invalid.csv',
        ),
        throwsA(isA<TelemetryFormatException>()),
      );
      expect(
        () => TelemetryAnalysisService.parseCsv(
          text: 'LAP,LAP TIME,REC TIME,ST(%)\n'
              '1,0:10.0,00:00:01.000,not-a-number',
          fileName: 'invalid-number.csv',
        ),
        throwsA(isA<TelemetryFormatException>()),
      );
    });
  });

  test('周期的なステアリングからラップとコースを推定する', () {
    final samples = List.generate(800, (index) {
      final millis = index * 100;
      final steering = math.sin(2 * math.pi * millis / 10000) * 80;
      return TelemetrySample(
        values: {
          'LAP': '${millis ~/ 10000 + 1}',
          'LAP TIME': formatTelemetryTime(millis % 10000),
          'REC TIME': formatTelemetryTime(millis),
          'ST(%)': steering.toStringAsFixed(3),
          'TH(%)': '70',
        },
        recordMillis: millis,
        lapMillis: millis % 10000,
      );
    });

    final prediction = TelemetryAnalysisService.predictLaps(samples);
    expect(prediction.detectedPeriodMillis, closeTo(10000, 500));
    expect(prediction.lapCount, greaterThan(2));
    expect(prediction.lowConfidence, isFalse);

    final session = TelemetrySession(
      id: 'periodic',
      csvFileName: 'periodic.csv',
      csvText: '',
      summary: const TelemetrySummary(),
      columns: const ['LAP', 'LAP TIME', 'REC TIME', 'ST(%)', 'TH(%)'],
      samples: samples,
      prediction: prediction,
    );
    final course = TelemetryAnalysisService.buildCourse(session);
    expect(course.length, greaterThan(20));
    expect(
        course.every((point) => point.x.isFinite && point.y.isFinite), isTrue);
  });

  test('一定値データは低品質な周期を捏造しない', () {
    final samples = List.generate(
      200,
      (index) => TelemetrySample(
        values: const {'ST(%)': '0'},
        recordMillis: index * 100,
        lapMillis: index * 100,
      ),
    );
    expect(TelemetryAnalysisService.predictLaps(samples).lapCount, 0);
  });

  test('可変速度の合成周回を固定間隔ではなく周回ごとに補正する', () {
    const lapDurations = [9000, 10200, 11000, 9500, 10600, 9800];
    final samples = <TelemetrySample>[];
    var lapStart = 0;
    for (var lap = 0; lap < lapDurations.length; lap++) {
      final duration = lapDurations[lap];
      for (var offset = 0; offset < duration; offset += 50) {
        final phase = offset / duration;
        final steering = math.sin(phase * math.pi * 2) * 65 +
            math.sin(phase * math.pi * 6) * 25;
        final throttle = math.cos(phase * math.pi * 4) * 70;
        final time = lapStart + offset;
        samples.add(
          TelemetrySample(
            values: {
              'ST(%)': steering.toStringAsFixed(3),
              'TH(%)': throttle.toStringAsFixed(3),
            },
            recordMillis: time,
            lapMillis: offset,
          ),
        );
      }
      lapStart += duration;
    }

    final prediction = TelemetryAnalysisService.predictLaps(samples);
    final predicted = prediction.laps.map((lap) => lap.durationMillis).toList();

    expect(predicted.length, greaterThanOrEqualTo(4));
    expect(predicted.toSet().length, greaterThan(1));
    for (final duration in predicted.take(lapDurations.length - 1)) {
      expect(
        lapDurations.any((expected) => (expected - duration).abs() <= 800),
        isTrue,
      );
    }
  });
}
