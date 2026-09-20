import 'dart:convert';
import 'dart:math' as math;

import '../models/telemetry.dart';
import '../models/telemetry_ai.dart';
import 'telemetry_analysis_service.dart';

/// Converts raw telemetry into a compact, provider-safe feature report.
abstract final class TelemetryFeatureService {
  static const maxPayloadCharacters = 45000;
  static const _waveformPoints = 96;
  static const _dtwRadius = 12;

  static TelemetryFeatureReport build(TelemetrySession session) {
    final laps = _completeLaps(session);
    final durations = laps.map((lap) => lap.durationMillis).toList()..sort();
    final median =
        durations.isEmpty ? 0 : durations[(durations.length - 1) ~/ 2];
    final excluded = <String>[
      if (session.prediction.lowConfidence)
        'lap boundary refinement: low confidence',
    ];
    final valid = <TelemetryLap>[];
    for (final lap in laps) {
      if (median > 0 &&
          (lap.durationMillis < median * .7 ||
              lap.durationMillis > median * 1.3)) {
        excluded.add(
          'lap ${lap.number}: duration outside 70-130% of median',
        );
      } else {
        valid.add(lap);
      }
    }

    final selected = _selectLaps(valid, 8);
    final reference = selected.isEmpty
        ? null
        : selected.reduce(
            (a, b) => a.durationMillis <= b.durationMillis ? a : b,
          );
    final sensorStatus = _sensorStatuses(session);
    final hasThrottle =
        sensorStatus['TH(%)']?.quality == TelemetrySensorQuality.dynamic;

    final referenceWave = reference == null
        ? const <TelemetryWavePoint>[]
        : _waveform(session, reference, hasThrottle, _waveformPoints);
    final referenceCorners = reference == null
        ? const <TelemetryCornerFeatures>[]
        : _corners(session, reference, hasThrottle: hasThrottle);

    final features = <TelemetryLapFeatures>[];
    for (final lap in selected) {
      final waveform = _waveform(
        session,
        lap,
        hasThrottle,
        _waveformPoints,
      );
      var corners = _corners(session, lap, hasThrottle: hasThrottle);
      var alignmentCost = 0.0;
      if (reference != null && lap.number != reference.number) {
        final alignment = _dtw(waveform, referenceWave, hasThrottle);
        alignmentCost = alignment.cost;
        corners = _alignCornerNumbers(
          corners,
          lap,
          referenceCorners,
          reference,
          alignment,
        );
      }
      features.add(
        _lapFeatures(
          session,
          lap,
          corners,
          waveform,
          alignmentCost: alignmentCost,
        ),
      );
    }

    final referenceFeatures = reference == null
        ? null
        : features.firstWhere((lap) => lap.number == reference.number);
    final evidence = _evidence(features, referenceFeatures);
    return TelemetryFeatureReport(
      sensorStatus: sensorStatus,
      laps: features,
      selectedLapNumbers:
          selected.map((lap) => lap.number).toList(growable: false),
      evidence: evidence,
      excludedLaps: excluded,
      inputFingerprint: _fingerprint(session, selected),
      referenceLapNumber: reference?.number,
    );
  }

  /// Produces a complete JSON document no longer than 45,000 characters.
  /// Reduction order is waveform 96 -> 64 -> 32, then laps 8 -> 6 -> fewer.
  static String payloadJson(TelemetryFeatureReport report) {
    var points = report.waveformPoints;
    var lapCount = report.selectedLapNumbers.length;
    var cornerLimit = 1000;
    while (true) {
      final included = _selectFeatureLaps(report.laps, lapCount);
      final json = jsonEncode(
        _payloadMap(report, included, points, cornerLimit),
      );
      if (json.length <= maxPayloadCharacters) return json;
      if (points > 32) {
        points = points == 96 ? 64 : 32;
      } else if (lapCount > 6) {
        lapCount = 6;
      } else if (lapCount > 1) {
        lapCount--;
      } else if (cornerLimit > 1) {
        cornerLimit = math.max(1, cornerLimit ~/ 2);
      } else {
        return jsonEncode({
          'schemaVersion': 1,
          'sensorStatus': report.sensorStatus.map(
            (key, value) => MapEntry(key, value.toJson()),
          ),
          'selectedLaps': const [],
          'evidence': const [],
          'excludedLaps': report.excludedLaps.take(16).toList(),
          'inputFingerprint': report.inputFingerprint,
        });
      }
    }
  }

  static Map<String, dynamic> _payloadMap(
    TelemetryFeatureReport report,
    List<TelemetryLapFeatures> included,
    int points,
    int cornerLimit,
  ) {
    final includedNumbers = included.map((lap) => lap.number).toSet();
    final selected = included.map((lap) {
      final wave = lap.waveform.length <= points
          ? lap.waveform
          : _resampleWave(lap.waveform, points);
      return {
        ...lap.toJson(),
        'corners': lap.corners
            .take(cornerLimit)
            .map((corner) => corner.toJson())
            .toList(growable: false),
        'waveform': wave.map((point) => point.toJson()).toList(growable: false),
      };
    }).toList(growable: false);
    return {
      'schemaVersion': 1,
      'sensorStatus': report.sensorStatus.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
      'selectedLaps': selected,
      'referenceLap': includedNumbers.contains(report.referenceLapNumber)
          ? report.referenceLapNumber
          : included.isEmpty
              ? null
              : included
                  .reduce(
                    (a, b) => a.durationMillis <= b.durationMillis ? a : b,
                  )
                  .number,
      'evidence': report.evidence
          .where(
            (item) => item.lap == null || includedNumbers.contains(item.lap),
          )
          .where(
            (item) => item.corner == null || item.corner! <= cornerLimit,
          )
          .map((item) => item.toJson())
          .toList(growable: false),
      'excludedLaps': report.excludedLaps,
      'inputFingerprint': report.inputFingerprint,
    };
  }

  static List<TelemetryLap> _completeLaps(TelemetrySession session) {
    final predicted = session.prediction.laps
        .where((lap) => lap.endMillis > lap.startMillis)
        .toList(growable: false);
    if (predicted.isNotEmpty) return predicted;
    if (session.samples.length < 2) return const [];
    final start = session.samples.first.recordMillis;
    final end = session.samples.last.recordMillis;
    if (end - start < 250) return const [];
    return [TelemetryLap(number: 1, startMillis: start, endMillis: end)];
  }

  static List<TelemetryLap> _selectLaps(
    List<TelemetryLap> valid,
    int count,
  ) {
    if (valid.length <= count) {
      return [...valid]..sort((a, b) => a.number.compareTo(b.number));
    }
    final sorted = [...valid]..sort((a, b) {
        final duration = a.durationMillis.compareTo(b.durationMillis);
        return duration != 0 ? duration : a.number.compareTo(b.number);
      });
    final indexes = <int>{
      0,
      (sorted.length - 1) ~/ 2,
      sorted.length - 1,
    };
    for (var index = 0; index < count; index++) {
      indexes.add((index * (sorted.length - 1) / (count - 1)).round());
    }
    final result = indexes
        .take(count)
        .map((index) => sorted[index])
        .toList(growable: false);
    return [...result]..sort((a, b) => a.number.compareTo(b.number));
  }

  static List<TelemetryLapFeatures> _selectFeatureLaps(
    List<TelemetryLapFeatures> laps,
    int count,
  ) {
    if (laps.length <= count) return laps;
    final sorted = [...laps]..sort((a, b) {
        final duration = a.durationMillis.compareTo(b.durationMillis);
        return duration != 0 ? duration : a.number.compareTo(b.number);
      });
    final indexes = <int>{
      0,
      (sorted.length - 1) ~/ 2,
      sorted.length - 1,
    };
    for (var index = 0; indexes.length < count; index++) {
      indexes.add((index * (sorted.length - 1) / (count - 1)).round());
    }
    final result = indexes
        .take(count)
        .map((index) => sorted[index])
        .toList(growable: false);
    return [...result]..sort((a, b) => a.number.compareTo(b.number));
  }

  static Map<String, TelemetrySensorStatus> _sensorStatuses(
    TelemetrySession session,
  ) {
    final columns = <String>{
      'ST(%)',
      'TH(%)',
      'RPM',
      'VOLT',
      'TMP1',
      'TMP2',
      ...session.columns.where(
        (column) => !const {'LAP', 'LAP TIME', 'REC TIME'}.contains(column),
      ),
    };
    return {
      for (final column in columns) column: _sensorStatus(session, column),
    };
  }

  static TelemetrySensorStatus _sensorStatus(
    TelemetrySession session,
    String key,
  ) {
    if (!session.columns.contains(key)) {
      return const TelemetrySensorStatus(
        quality: TelemetrySensorQuality.absent,
      );
    }
    final populated =
        session.samples.where((sample) => sample[key].trim().isNotEmpty);
    final missingRatio =
        1 - populated.length / math.max(1, session.samples.length);
    if (populated.length < 2 || missingRatio > .2) {
      return const TelemetrySensorStatus(
        quality: TelemetrySensorQuality.unusable,
      );
    }
    final values = populated.map((sample) => sample.numeric(key)).toList();
    final min = values.reduce(math.min);
    final max = values.reduce(math.max);
    final average = values.reduce((a, b) => a + b) / values.length;
    final upper = key.toUpperCase();
    if ((upper.contains('RPM') && min == 0 && max == 0) ||
        (upper.startsWith('TMP') && min == 255 && max == 255)) {
      return const TelemetrySensorStatus(
        quality: TelemetrySensorQuality.unusable,
      );
    }
    final isStatic = (max - min).abs() < math.max(.01, average.abs() * .001);
    return TelemetrySensorStatus(
      quality: isStatic
          ? TelemetrySensorQuality.static
          : TelemetrySensorQuality.dynamic,
      min: min,
      max: max,
      average: average,
    );
  }

  static TelemetryLapFeatures _lapFeatures(
    TelemetrySession session,
    TelemetryLap lap,
    List<TelemetryCornerFeatures> corners,
    List<TelemetryWavePoint> waveform, {
    double alignmentCost = 0,
  }) {
    double weighted(bool Function(double st, double th) matches) {
      var total = 0.0;
      var hit = 0.0;
      final rows = session.samples;
      for (var index = 0; index < rows.length; index++) {
        final segmentStart =
            math.max(lap.startMillis, rows[index].recordMillis);
        final nextTime = index + 1 < rows.length
            ? rows[index + 1].recordMillis
            : lap.endMillis;
        final segmentEnd = math.min(lap.endMillis, nextTime);
        final duration = math.max(0, segmentEnd - segmentStart).toDouble();
        if (duration == 0) continue;
        total += duration;
        if (matches(
          rows[index].numeric('ST(%)'),
          rows[index].numeric('TH(%)'),
        )) {
          hit += duration;
        }
      }
      return total == 0 ? 0 : hit / total;
    }

    return TelemetryLapFeatures(
      number: lap.number,
      startMillis: lap.startMillis,
      endMillis: lap.endMillis,
      fullThrottleRatio: weighted((_, th) => th >= 95),
      neutralRatio: weighted((_, th) => th.abs() <= 5),
      brakeRatio: weighted((_, th) => th < -5),
      fullBrakeRatio: weighted((_, th) => th <= -95),
      fullSteeringRatio: weighted((st, _) => st.abs() >= 90),
      steeringCenterRatio: weighted((st, _) => st.abs() <= 10),
      corners: corners,
      waveform: waveform,
      alignmentCost: alignmentCost,
    );
  }

  static List<TelemetryCornerFeatures> _corners(
    TelemetrySession session,
    TelemetryLap lap, {
    required bool hasThrottle,
  }) {
    final rows = session.samples
        .where(
          (sample) =>
              sample.recordMillis >= lap.startMillis &&
              sample.recordMillis <= lap.endMillis,
        )
        .toList(growable: false);
    if (rows.isEmpty) return const [];
    final smooth = _smoothSteering(rows);
    final ranges = <_CornerRange>[];
    var start = -1;
    int? quietSince;
    for (var index = 0; index < rows.length; index++) {
      final magnitude = smooth[index].abs();
      if (start < 0 && magnitude >= 20) {
        start = index;
        quietSince = null;
      } else if (start >= 0) {
        if (magnitude < 15) {
          quietSince ??= rows[index].recordMillis;
          if (rows[index].recordMillis - quietSince >= 200) {
            final end = index;
            if (rows[end].recordMillis - rows[start].recordMillis >= 250) {
              ranges.add(_range(rows, smooth, start, end));
            }
            start = -1;
            quietSince = null;
          }
        } else {
          quietSince = null;
        }
      }
    }
    if (start >= 0 &&
        rows.last.recordMillis - rows[start].recordMillis >= 250) {
      ranges.add(_range(rows, smooth, start, rows.length - 1));
    }

    final merged = <_CornerRange>[];
    for (final range in ranges) {
      if (merged.isNotEmpty &&
          range.direction == merged.last.direction &&
          rows[range.from].recordMillis - rows[merged.last.to].recordMillis <=
              300) {
        merged[merged.length - 1] = _range(
          rows,
          smooth,
          merged.last.from,
          range.to,
        );
      } else {
        merged.add(range);
      }
    }
    return [
      for (var index = 0; index < merged.length; index++)
        _corner(
          rows,
          smooth,
          merged[index],
          index + 1,
          hasThrottle: hasThrottle,
        ),
    ];
  }

  static List<double> _smoothSteering(List<TelemetrySample> rows) {
    return List.generate(rows.length, (index) {
      final center = rows[index].recordMillis;
      var sum = 0.0;
      var count = 0;
      for (var cursor = index;
          cursor >= 0 && center - rows[cursor].recordMillis <= 75;
          cursor--) {
        sum += rows[cursor].numeric('ST(%)');
        count++;
      }
      for (var cursor = index + 1;
          cursor < rows.length && rows[cursor].recordMillis - center <= 75;
          cursor++) {
        sum += rows[cursor].numeric('ST(%)');
        count++;
      }
      return count == 0 ? 0 : sum / count;
    });
  }

  static _CornerRange _range(
    List<TelemetrySample> rows,
    List<double> smooth,
    int from,
    int to,
  ) {
    var peak = from;
    for (var index = from + 1; index <= to; index++) {
      if (smooth[index].abs() > smooth[peak].abs()) peak = index;
    }
    return _CornerRange(
      from: from,
      to: to,
      peak: peak,
      direction: smooth[peak].sign.toInt(),
    );
  }

  static TelemetryCornerFeatures _corner(
    List<TelemetrySample> rows,
    List<double> smooth,
    _CornerRange range,
    int number, {
    required bool hasThrottle,
  }) {
    int? brake;
    int? reapply;
    int? full;
    if (hasThrottle) {
      var entry = range.from;
      while (entry > 0 &&
          rows[range.from].recordMillis - rows[entry - 1].recordMillis <=
              1000) {
        entry--;
      }
      for (var index = entry; index <= range.peak; index++) {
        if (rows[index].numeric('TH(%)') < -5) {
          brake ??= rows[index].recordMillis;
        }
      }
      var exit = range.to;
      while (exit + 1 < rows.length &&
          rows[exit + 1].recordMillis - rows[range.to].recordMillis <= 1000) {
        exit++;
      }
      for (var index = range.peak; index <= exit; index++) {
        final throttle = rows[index].numeric('TH(%)');
        if (throttle >= 10) reapply ??= rows[index].recordMillis;
        if (throttle >= 95) {
          full = rows[index].recordMillis;
          break;
        }
      }
    }
    return TelemetryCornerFeatures(
      number: number,
      startMillis: rows[range.from].recordMillis,
      endMillis: rows[range.to].recordMillis,
      peakSteering: smooth[range.peak].abs(),
      brakeStartMillis: brake,
      turnInMillis: rows[range.from].recordMillis,
      throttleReapplyMillis: reapply,
      fullThrottleMillis: full,
      steeringCorrections: _steeringCorrections(
        smooth,
        range.from,
        range.to,
      ),
    );
  }

  static int _steeringCorrections(List<double> values, int from, int to) {
    if (to - from < 2) return 0;
    var anchor = values[from];
    var direction = 0;
    var corrections = 0;
    for (var index = from + 1; index <= to; index++) {
      final delta = values[index] - anchor;
      if (delta.abs() < 8) continue;
      final nextDirection = delta.sign.toInt();
      if (direction != 0 && nextDirection != direction) corrections++;
      direction = nextDirection;
      anchor = values[index];
    }
    return corrections;
  }

  static List<TelemetryWavePoint> _waveform(
    TelemetrySession session,
    TelemetryLap lap,
    bool hasThrottle,
    int count,
  ) {
    return List.generate(count, (index) {
      final ratio = index / (count - 1);
      final time = lap.startMillis + (lap.durationMillis * ratio).round();
      return TelemetryWavePoint(
        t: ratio,
        st: TelemetryAnalysisService.valueAtTime(
          session.samples,
          'ST(%)',
          time,
        ),
        th: hasThrottle
            ? TelemetryAnalysisService.valueAtTime(
                session.samples,
                'TH(%)',
                time,
              )
            : null,
      );
    });
  }

  static List<TelemetryWavePoint> _resampleWave(
    List<TelemetryWavePoint> source,
    int count,
  ) {
    return List.generate(count, (index) {
      final position = index * (source.length - 1) / (count - 1);
      final before = position.floor();
      final after = math.min(source.length - 1, before + 1);
      final fraction = position - before;
      final first = source[before];
      final second = source[after];
      return TelemetryWavePoint(
        t: index / (count - 1),
        st: first.st + (second.st - first.st) * fraction,
        th: first.th == null || second.th == null
            ? null
            : first.th! + (second.th! - first.th!) * fraction,
      );
    });
  }

  static _DtwAlignment _dtw(
    List<TelemetryWavePoint> target,
    List<TelemetryWavePoint> reference,
    bool hasThrottle,
  ) {
    final rows = target.length;
    final columns = reference.length;
    final costs = List.generate(
      rows + 1,
      (_) => List.filled(columns + 1, double.infinity),
    );
    costs[0][0] = 0;
    for (var row = 1; row <= rows; row++) {
      final from = math.max(1, row - _dtwRadius);
      final to = math.min(columns, row + _dtwRadius);
      for (var column = from; column <= to; column++) {
        final st = (target[row - 1].st - reference[column - 1].st).abs();
        final th = hasThrottle
            ? ((target[row - 1].th ?? 0) - (reference[column - 1].th ?? 0))
                .abs()
            : 0.0;
        final distance = hasThrottle ? st * .75 + th * .25 : st;
        costs[row][column] = distance +
            math.min(
              costs[row - 1][column],
              math.min(
                costs[row][column - 1],
                costs[row - 1][column - 1],
              ),
            );
      }
    }
    var row = rows;
    var column = columns;
    final pairs = <(int, int)>[];
    while (row > 0 && column > 0) {
      pairs.add((row - 1, column - 1));
      final diagonal = costs[row - 1][column - 1];
      final up = costs[row - 1][column];
      final left = costs[row][column - 1];
      if (diagonal <= up && diagonal <= left) {
        row--;
        column--;
      } else if (up <= left) {
        row--;
      } else {
        column--;
      }
    }
    final orderedPairs = pairs.reversed.toList(growable: false);
    final mapped = List<double>.generate(
      rows,
      (index) => index * (columns - 1) / math.max(1, rows - 1),
    );
    for (var targetIndex = 0; targetIndex < rows; targetIndex++) {
      final matches = orderedPairs
          .where((pair) => pair.$1 == targetIndex)
          .map((pair) => pair.$2)
          .toList(growable: false);
      if (matches.isNotEmpty) {
        mapped[targetIndex] = matches.reduce((a, b) => a + b) / matches.length;
      }
    }
    return _DtwAlignment(
      cost: costs[rows][columns] / math.max(1, orderedPairs.length),
      targetToReference: mapped,
    );
  }

  static List<TelemetryCornerFeatures> _alignCornerNumbers(
    List<TelemetryCornerFeatures> target,
    TelemetryLap targetLap,
    List<TelemetryCornerFeatures> reference,
    TelemetryLap referenceLap,
    _DtwAlignment alignment,
  ) {
    if (target.isEmpty || reference.isEmpty) return target;
    final referenceCenters = {
      for (final corner in reference)
        corner.number: ((corner.startMillis + corner.endMillis) / 2 -
                referenceLap.startMillis) /
            referenceLap.durationMillis *
            (_waveformPoints - 1),
    };
    final used = <int>{};
    final aligned = <TelemetryCornerFeatures>[];
    for (final corner in target) {
      final targetPosition = (((corner.startMillis + corner.endMillis) / 2 -
                  targetLap.startMillis) /
              targetLap.durationMillis *
              (_waveformPoints - 1))
          .round()
          .clamp(0, _waveformPoints - 1);
      final mapped = alignment.targetToReference[targetPosition];
      final available = referenceCenters.entries.where(
        (entry) => !used.contains(entry.key),
      );
      final closest = available.isEmpty
          ? null
          : available.reduce(
              (a, b) =>
                  (a.value - mapped).abs() <= (b.value - mapped).abs() ? a : b,
            );
      final number = closest?.key ?? corner.number;
      used.add(number);
      aligned.add(_copyCorner(corner, number));
    }
    aligned.sort((a, b) => a.startMillis.compareTo(b.startMillis));
    return aligned;
  }

  static TelemetryCornerFeatures _copyCorner(
    TelemetryCornerFeatures source,
    int number,
  ) {
    return TelemetryCornerFeatures(
      number: number,
      startMillis: source.startMillis,
      endMillis: source.endMillis,
      peakSteering: source.peakSteering,
      brakeStartMillis: source.brakeStartMillis,
      turnInMillis: source.turnInMillis,
      throttleReapplyMillis: source.throttleReapplyMillis,
      fullThrottleMillis: source.fullThrottleMillis,
      steeringCorrections: source.steeringCorrections,
    );
  }

  static List<TelemetryEvidence> _evidence(
    List<TelemetryLapFeatures> laps,
    TelemetryLapFeatures? reference,
  ) {
    final evidence = <TelemetryEvidence>[];
    final referenceCorrections = reference?.corners.fold<int>(
      0,
      (sum, corner) => sum + corner.steeringCorrections,
    );
    for (final lap in laps) {
      final corrections = lap.corners.fold<int>(
        0,
        (sum, corner) => sum + corner.steeringCorrections,
      );
      evidence.add(
        TelemetryEvidence(
          id: 'lap_${lap.number}_full_throttle',
          metric: 'fullThrottleRatio',
          value: lap.fullThrottleRatio,
          lap: lap.number,
          referenceValue: reference?.fullThrottleRatio,
          difference: reference == null
              ? null
              : lap.fullThrottleRatio - reference.fullThrottleRatio,
          unit: 'ratio',
        ),
      );
      evidence.add(
        TelemetryEvidence(
          id: 'lap_${lap.number}_steering_corrections',
          metric: 'steeringCorrections',
          value: corrections.toDouble(),
          lap: lap.number,
          referenceValue: referenceCorrections?.toDouble(),
          difference: referenceCorrections == null
              ? null
              : (corrections - referenceCorrections).toDouble(),
          unit: 'count',
        ),
      );
      for (final corner in lap.corners) {
        final matching = reference?.corners.where(
          (item) => item.number == corner.number,
        );
        final referenceCorner =
            matching == null || matching.isEmpty ? null : matching.first;
        evidence.add(
          TelemetryEvidence(
            id: 'lap_${lap.number}_corner_${corner.number}_peak_steering',
            metric: 'peakSteering',
            value: corner.peakSteering,
            lap: lap.number,
            corner: corner.number,
            referenceValue: referenceCorner?.peakSteering,
            difference: referenceCorner == null
                ? null
                : corner.peakSteering - referenceCorner.peakSteering,
            unit: '%',
          ),
        );
        _addTimingEvidence(
          evidence,
          lap,
          corner,
          referenceCorner,
          'brake_start',
          'brakeStart',
          corner.brakeStartMillis,
          referenceCorner?.brakeStartMillis,
        );
        _addTimingEvidence(
          evidence,
          lap,
          corner,
          referenceCorner,
          'throttle_reapply',
          'throttleReapply',
          corner.throttleReapplyMillis,
          referenceCorner?.throttleReapplyMillis,
        );
        _addTimingEvidence(
          evidence,
          lap,
          corner,
          referenceCorner,
          'full_throttle',
          'fullThrottle',
          corner.fullThrottleMillis,
          referenceCorner?.fullThrottleMillis,
        );
      }
    }
    return evidence;
  }

  static void _addTimingEvidence(
    List<TelemetryEvidence> evidence,
    TelemetryLapFeatures lap,
    TelemetryCornerFeatures corner,
    TelemetryCornerFeatures? referenceCorner,
    String idSuffix,
    String metric,
    int? valueTime,
    int? referenceTime,
  ) {
    final turnIn = corner.turnInMillis;
    final referenceTurnIn = referenceCorner?.turnInMillis;
    if (valueTime == null ||
        turnIn == null ||
        referenceTime == null ||
        referenceTurnIn == null) {
      return;
    }
    final value = (valueTime - turnIn).toDouble();
    final referenceValue = (referenceTime - referenceTurnIn).toDouble();
    evidence.add(
      TelemetryEvidence(
        id: 'lap_${lap.number}_corner_${corner.number}_$idSuffix',
        metric: metric,
        value: value,
        lap: lap.number,
        corner: corner.number,
        referenceValue: referenceValue,
        difference: value - referenceValue,
        unit: 'ms',
      ),
    );
  }

  static String _fingerprint(
    TelemetrySession session,
    List<TelemetryLap> laps,
  ) {
    var hash = 2166136261;
    void addByte(int value) {
      hash ^= value & 0xff;
      hash = (hash * 16777619) & 0xffffffff;
    }

    void addInt(int value) {
      for (var shift = 0; shift < 32; shift += 8) {
        addByte(value >> shift);
      }
    }

    void addString(String value) {
      for (final byte in utf8.encode(value)) {
        addByte(byte);
      }
      addByte(0);
    }

    addInt(1);
    for (final lap in laps) {
      addInt(lap.number);
      addInt(lap.startMillis);
      addInt(lap.endMillis);
    }
    final metricColumns = session.columns
        .where(
          (column) => !const {'LAP', 'LAP TIME', 'REC TIME'}.contains(column),
        )
        .toList(growable: false)
      ..sort();
    addInt(session.samples.length);
    for (final column in metricColumns) {
      addString(column);
    }
    for (final sample in session.samples) {
      addInt(sample.recordMillis);
      for (final column in metricColumns) {
        addInt(
          sample[column].trim().isEmpty
              ? -2147483648
              : (sample.numeric(column) * 1000).round(),
        );
      }
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}

class _CornerRange {
  const _CornerRange({
    required this.from,
    required this.to,
    required this.peak,
    required this.direction,
  });

  final int from;
  final int to;
  final int peak;
  final int direction;
}

class _DtwAlignment {
  const _DtwAlignment({
    required this.cost,
    required this.targetToReference,
  });

  final double cost;
  final List<double> targetToReference;
}
