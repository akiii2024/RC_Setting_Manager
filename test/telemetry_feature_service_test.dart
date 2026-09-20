import 'package:flutter_test/flutter_test.dart';
import 'package:rc_setting_manager/models/telemetry.dart';
import 'package:rc_setting_manager/models/telemetry_ai.dart';
import 'package:rc_setting_manager/services/telemetry_feature_service.dart';

TelemetrySession _session({int lapCount = 3, Map<String, String>? extra}) {
  final samples = <TelemetrySample>[];
  final laps = <TelemetryLap>[];
  for (var lap = 0; lap < lapCount; lap++) {
    final start = lap * 1000;
    laps.add(TelemetryLap(
        number: lap + 1, startMillis: start, endMillis: start + 1000));
    for (var i = 0; i < 20; i++) {
      final t = start + i * 50;
      samples.add(TelemetrySample(values: {
        'LAP': '${lap + 1}',
        'LAP TIME': '00:00:01.00',
        'REC TIME': '00:00:00.00',
        'ST(%)': i > 5 && i < 14 ? '80' : '0',
        'TH(%)': i < 5 ? '-100' : (i > 14 ? '100' : '0'),
        'RPM': '0',
        'TMP1': '255',
        'VOLT': '5.04',
        ...?extra,
      }, recordMillis: t, lapMillis: 1000));
    }
  }
  return TelemetrySession(
      id: 'test',
      csvFileName: 'test.csv',
      csvText: '',
      summary: const TelemetrySummary(),
      columns: const [
        'LAP',
        'LAP TIME',
        'REC TIME',
        'ST(%)',
        'TH(%)',
        'RPM',
        'TMP1',
        'VOLT'
      ],
      samples: samples,
      prediction: LapPrediction(laps: laps));
}

void main() {
  test('classifies unavailable and static sensors', () {
    final report = TelemetryFeatureService.build(_session());
    expect(
        report.sensorStatus['RPM']!.quality, TelemetrySensorQuality.unusable);
    expect(
        report.sensorStatus['TMP1']!.quality, TelemetrySensorQuality.unusable);
    expect(report.sensorStatus['VOLT']!.quality, TelemetrySensorQuality.static);
  });

  test('selects at most eight laps and keeps best median worst', () {
    final report = TelemetryFeatureService.build(_session(lapCount: 12));
    expect(report.selectedLapNumbers.length, 8);
    expect(report.selectedLapNumbers, containsAll(<int>[1, 6, 12]));
  });

  test('payload remains bounded', () {
    final report = TelemetryFeatureService.build(_session(lapCount: 12));
    expect(TelemetryFeatureService.payloadJson(report).length,
        lessThanOrEqualTo(45000));
  });

  test('extracts corner evidence and weighted ratios', () {
    final report = TelemetryFeatureService.build(_session());
    expect(report.laps.first.corners, isNotEmpty);
    expect(report.evidence, isNotEmpty);
    expect(report.laps.first.brakeRatio, greaterThan(0));
    expect(report.laps.first.fullThrottleRatio, greaterThan(0));
  });

  test('uses elapsed time rather than row count for irregular samples', () {
    final session = TelemetrySession(
      id: 'irregular',
      csvFileName: 'private.csv',
      csvText: 'not sent',
      summary: const TelemetrySummary(),
      columns: const ['ST(%)', 'TH(%)'],
      samples: const [
        TelemetrySample(
          values: {'ST(%)': '0', 'TH(%)': '95'},
          recordMillis: 0,
          lapMillis: 0,
        ),
        TelemetrySample(
          values: {'ST(%)': '30', 'TH(%)': '0'},
          recordMillis: 100,
          lapMillis: 100,
        ),
        TelemetrySample(
          values: {'ST(%)': '0', 'TH(%)': '100'},
          recordMillis: 900,
          lapMillis: 900,
        ),
      ],
      prediction: const LapPrediction(
        laps: [TelemetryLap(number: 1, startMillis: 0, endMillis: 1000)],
      ),
    );

    final lap = TelemetryFeatureService.build(session).laps.single;

    expect(lap.fullThrottleRatio, closeTo(.2, .001));
    expect(lap.neutralRatio, closeTo(.8, .001));
  });

  test('allows a single-session review and omits invalid throttle waveform',
      () {
    final samples = List.generate(
      20,
      (index) => TelemetrySample(
        values: {'ST(%)': index.isEven ? '-40' : '40'},
        recordMillis: index * 50,
        lapMillis: index * 50,
      ),
    );
    final session = TelemetrySession(
      id: 'single',
      csvFileName: 'single.csv',
      csvText: '',
      summary: const TelemetrySummary(),
      columns: const ['ST(%)'],
      samples: samples,
      prediction: const LapPrediction(),
    );

    final report = TelemetryFeatureService.build(session);

    expect(report.laps, hasLength(1));
    expect(
        report.sensorStatus['TH(%)']!.quality, TelemetrySensorQuality.absent);
    expect(
        report.laps.single.waveform.every((point) => point.th == null), isTrue);
  });

  test('payload contains features but not raw source metadata', () {
    final payload = TelemetryFeatureService.payloadJson(
      TelemetryFeatureService.build(_session()),
    );

    expect(payload, isNot(contains('test.csv')));
    expect(payload, isNot(contains('rawCsv')));
    expect(payload, isNot(contains('apiKey')));
    expect(payload, contains('selectedLaps'));
  });

  test('fingerprint changes when a reported sensor value changes', () {
    final first = TelemetryFeatureService.build(
      _session(extra: {'VOLT': '5.04'}),
    );
    final second = TelemetryFeatureService.build(
      _session(extra: {'VOLT': '6.00'}),
    );

    expect(first.inputFingerprint, isNot(second.inputFingerprint));
  });
}
