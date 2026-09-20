import 'dart:math' as math;

import '../models/telemetry.dart';

class TelemetryFormatException implements Exception {
  const TelemetryFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _BoundaryResult {
  const _BoundaryResult(this.boundaries, {this.lowConfidence = false});

  final List<int> boundaries;
  final bool lowConfidence;
}

abstract final class TelemetryAnalysisService {
  static const _summaryKeys = ['TOTAL LAP', 'BEST LAP', 'AVERAGE LAP'];
  static const _requiredColumns = ['LAP', 'LAP TIME', 'REC TIME'];

  static TelemetrySession parseCsv({
    required String text,
    required String fileName,
    String? sessionId,
  }) {
    final normalized = text
        .replaceFirst('\ufeff', '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    final lines = normalized
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList(growable: false);
    if (lines.isEmpty) {
      throw const TelemetryFormatException('CSVにデータがありません。');
    }

    var headerIndex = lines.indexWhere((line) {
      final trimmed = line.trimLeft();
      return trimmed.startsWith('LAP,') || trimmed.startsWith('LAP ');
    });
    if (headerIndex < 0) {
      throw const TelemetryFormatException(
        'SANWA形式のヘッダー（LAP, LAP TIME, REC TIME）が見つかりません。',
      );
    }

    final summary = <String, String>{};
    for (final line in lines.take(headerIndex)) {
      final parts = _splitLine(line);
      if (parts.length < 2) continue;
      final key = _clean(parts[0]);
      if (_summaryKeys.contains(key)) summary[key] = _clean(parts[1]);
    }

    final columns = _splitLine(lines[headerIndex])
        .map(_clean)
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    for (final required in _requiredColumns) {
      if (!columns.contains(required)) {
        throw TelemetryFormatException('必須列「$required」が見つかりません。');
      }
    }

    final samples = <TelemetrySample>[];
    for (final (rowIndex, line) in lines.skip(headerIndex + 1).indexed) {
      final parts = _splitLine(line);
      final values = <String, String>{};
      for (var index = 0; index < columns.length; index++) {
        values[columns[index]] =
            index < parts.length ? _clean(parts[index]) : '';
      }
      final recordText = values['REC TIME'] ?? '';
      if (!recordText.contains(':')) continue;
      final recordMillis = parseTelemetryTime(recordText);
      if (recordMillis == 0 && !recordText.contains('00:00:00')) {
        throw TelemetryFormatException(
          '${rowIndex + headerIndex + 2}行目のREC TIMEを読み取れません。',
        );
      }
      for (final column in columns.where(
        (column) => !_requiredColumns.contains(column),
      )) {
        final value = values[column] ?? '';
        if (value.isEmpty) continue;
        final numeric = value.replaceAll(RegExp(r'[^0-9.\-+]'), '');
        if (numeric.isEmpty || double.tryParse(numeric) == null) {
          throw TelemetryFormatException(
            '${rowIndex + headerIndex + 2}行目の「$column」を数値として読み取れません。',
          );
        }
      }
      samples.add(
        TelemetrySample(
          values: Map.unmodifiable(values),
          recordMillis: recordMillis,
          lapMillis: parseTelemetryTime(values['LAP TIME'] ?? ''),
        ),
      );
    }
    if (samples.isEmpty) {
      throw const TelemetryFormatException('有効なテレメトリーレコードがありません。');
    }
    samples.sort((a, b) => a.recordMillis.compareTo(b.recordMillis));

    final prediction = predictLaps(samples);
    final metrics = columns
        .where((column) => !_requiredColumns.contains(column))
        .toList(growable: false);
    final defaults =
        ['ST(%)', 'TH(%)'].where(metrics.contains).toList(growable: false);

    return TelemetrySession(
      id: sessionId ?? _newSessionId(),
      csvFileName: fileName,
      csvText: normalized,
      summary: TelemetrySummary.fromMap(summary),
      columns: List.unmodifiable(columns),
      samples: List.unmodifiable(samples),
      prediction: prediction,
      selectedMetrics: defaults.isNotEmpty
          ? defaults
          : [if (metrics.isNotEmpty) metrics.first],
    );
  }

  static LapPrediction predictLaps(List<TelemetrySample> samples) {
    if (samples.length < 100 ||
        !samples.any((sample) => sample.values.containsKey('ST(%)'))) {
      return const LapPrediction();
    }

    final interval = ((samples.last.recordMillis - samples.first.recordMillis) /
            math.max(1, samples.length - 1))
        .clamp(1, double.infinity)
        .toDouble();
    final values = samples.map((sample) => sample.numeric('ST(%)')).toList();
    final mean = values.reduce((a, b) => a + b) / values.length;
    final normalized = values.map((value) => value - mean).toList();
    final variance =
        normalized.fold<double>(0, (sum, value) => sum + value * value) /
            normalized.length;
    if (variance < 0.001) return const LapPrediction();

    final minLag = math.max(10, (5000 / interval).floor());
    final maxLag = math.min(
      normalized.length ~/ 2,
      (math.min(120000, samples.last.recordMillis / 2) / interval).floor(),
    );
    if (maxLag <= minLag) return const LapPrediction();

    var bestLag = 0;
    var bestCorrelation = double.negativeInfinity;
    final coarseStep = math.max(1, (maxLag - minLag) ~/ 500);
    for (var lag = minLag; lag < maxLag; lag += coarseStep) {
      final correlation = _correlation(normalized, lag);
      if (correlation > bestCorrelation) {
        bestCorrelation = correlation;
        bestLag = lag;
      }
    }
    for (var lag = math.max(minLag, bestLag - coarseStep * 2);
        lag <= math.min(maxLag, bestLag + coarseStep * 2);
        lag++) {
      final correlation = _correlation(normalized, lag);
      if (correlation > bestCorrelation) {
        bestCorrelation = correlation;
        bestLag = lag;
      }
    }
    // Repeated laps also correlate at 2x/3x harmonics. Prefer the earliest lag
    // whose correlation is effectively as strong as the global maximum.
    final nearMaximum = bestCorrelation * 0.98;
    for (var lag = minLag; lag <= bestLag; lag += coarseStep) {
      if (_correlation(normalized, lag) >= nearMaximum) {
        final start = math.max(minLag, lag - coarseStep);
        final end = math.min(bestLag, lag + coarseStep);
        for (var refined = start; refined <= end; refined++) {
          if (_correlation(normalized, refined) >= nearMaximum) {
            bestLag = refined;
            break;
          }
        }
        break;
      }
    }

    final periodMillis = (bestLag * interval).round();
    if (periodMillis < 5000) return const LapPrediction();
    final confidence = bestCorrelation / variance;
    final boundaryResult = _findBoundaries(samples, bestLag);
    final boundaries = boundaryResult.boundaries;
    final laps = <TelemetryLap>[];
    for (var index = 0; index < boundaries.length - 1; index++) {
      final start = boundaries[index];
      final end = boundaries[index + 1];
      if (end > start) {
        laps.add(TelemetryLap(
            number: index + 1, startMillis: start, endMillis: end));
      }
    }
    if (laps.isEmpty) {
      final firstTime = samples.first.recordMillis;
      final lastTime = samples.last.recordMillis;
      for (var start = firstTime, number = 1;
          start + periodMillis <= lastTime;
          start += periodMillis, number++) {
        laps.add(
          TelemetryLap(
            number: number,
            startMillis: start,
            endMillis: start + periodMillis,
          ),
        );
      }
    }
    if (laps.isEmpty) return const LapPrediction();
    final durations = laps.map((lap) => lap.durationMillis).toList();
    return LapPrediction(
      detectedPeriodMillis: periodMillis,
      bestLapMillis: durations.reduce(math.min),
      averageLapMillis:
          (durations.reduce((a, b) => a + b) / durations.length).round(),
      laps: List.unmodifiable(laps),
      lowConfidence: confidence < 0.15 || boundaryResult.lowConfidence,
      method: boundaries.length >= 2 ? 'template' : 'periodicity',
    );
  }

  static List<CoursePoint> buildCourse(
    TelemetrySession session, {
    CourseOptions? options,
  }) {
    final resolved = options ?? session.courseOptions;
    final period = session.prediction.detectedPeriodMillis;
    if (period <= 0 || !session.columns.contains('ST(%)')) return const [];
    final source = session.samples
        .where((sample) => sample.recordMillis <= period)
        .toList(growable: false);
    if (source.length < 2) return const [];

    final steering = _smooth(
      source.map((sample) => sample.numeric('ST(%)')).toList(),
      resolved.smoothWindow,
    );
    final throttle = _smooth(
      source.map((sample) => sample.numeric('TH(%)')).toList(),
      resolved.smoothWindow,
    );
    final stMax =
        math.max(1, _percentile(steering.map((v) => v.abs()).toList(), 0.95));
    final thMax =
        math.max(1, _percentile(throttle.map((v) => v.abs()).toList(), 0.95));
    final direction = detectDirection(session.samples) == 'cw' ? -1.0 : 1.0;
    var x = 0.0;
    var y = 0.0;
    var angle = -math.pi / 2;
    var lastTime = source.first.recordMillis;
    final points = <CoursePoint>[];
    for (var index = 0; index < source.length; index++) {
      final sample = source[index];
      final dt = math.max(1, sample.recordMillis - lastTime);
      lastTime = sample.recordMillis;
      final normalizedSteer = (steering[index] / stMax).clamp(-1.0, 1.0);
      final curved = normalizedSteer.sign *
          math.pow(normalizedSteer.abs(), resolved.steerGamma).toDouble();
      final acceleration = math.max(0, throttle[index] / thMax);
      final braking = math.max(0, -throttle[index] / thMax);
      final speedRatio = math.max(
        0,
        acceleration * (1 - braking * resolved.brakeSpeedLoss),
      );
      final scale = dt / 50;
      final curvature = curved *
          resolved.steerGain *
          direction *
          (1 - resolved.steerSpeedLoss * speedRatio);
      angle += curvature * 0.15 * scale;
      final segment = (0.3 + 0.7 * speedRatio) * resolved.baseSpeed * scale;
      x += math.cos(angle) * segment;
      y += math.sin(angle) * segment;
      points.add(
        CoursePoint(
          x: x,
          y: y,
          timeMillis: sample.recordMillis - source.first.recordMillis,
        ),
      );
    }
    if (points.length < 2) return points;
    final start = points.first;
    final end = points.last;
    final closed = points.indexed.map((entry) {
      final ratio = entry.$1 / (points.length - 1);
      return entry.$2.copyWith(
        x: entry.$2.x - (end.x - start.x) * ratio,
        y: entry.$2.y - (end.y - start.y) * ratio,
      );
    }).toList(growable: false);
    return _smoothCourse(closed, resolved.smoothWindow);
  }

  static String detectDirection(List<TelemetrySample> samples) {
    var sum = 0.0;
    var count = 0;
    for (final sample in samples) {
      final value = sample.numeric('ST(%)');
      if (value.abs() < 5) continue;
      sum += value;
      count++;
    }
    return count > 0 && sum >= 0 ? 'cw' : 'ccw';
  }

  static double valueAtTime(
    List<TelemetrySample> samples,
    String metric,
    int timeMillis,
  ) {
    if (samples.isEmpty) return 0;
    var low = 0;
    var high = samples.length - 1;
    while (low <= high) {
      final middle = (low + high) ~/ 2;
      final time = samples[middle].recordMillis;
      if (time == timeMillis) return samples[middle].numeric(metric);
      if (time < timeMillis) {
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }
    return samples[low.clamp(0, samples.length - 1)].numeric(metric);
  }

  static List<String> _splitLine(String line) {
    final values = <String>[];
    final buffer = StringBuffer();
    var quoted = false;
    for (var index = 0; index < line.length; index++) {
      final char = line[index];
      if (char == '"') {
        if (quoted && index + 1 < line.length && line[index + 1] == '"') {
          buffer.write('"');
          index++;
        } else {
          quoted = !quoted;
        }
      } else if (char == ',' && !quoted) {
        values.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    values.add(buffer.toString().trim());
    return values;
  }

  static String _clean(String value) => value
      .replaceFirst(RegExp("^'+"), '')
      .replaceFirst(RegExp("'+\$"), '')
      .trim();

  static double _correlation(List<double> values, int lag) {
    var total = 0.0;
    var count = 0;
    for (var index = 0; index < values.length - lag; index++) {
      total += values[index] * values[index + lag];
      count++;
    }
    return count == 0 ? 0 : total / count;
  }

  static _BoundaryResult _findBoundaries(
    List<TelemetrySample> samples,
    int periodSamples,
  ) {
    if (samples.length < periodSamples * 2) {
      return const _BoundaryResult([]);
    }
    final steering = _normalizeSignal(
      samples.map((sample) => sample.numeric('ST(%)')).toList(),
    );
    final throttle = _normalizeSignal(
      samples.map((sample) => sample.numeric('TH(%)')).toList(),
    );
    final hasThrottle = samples.any(
          (sample) => sample.values.containsKey('TH(%)'),
        ) &&
        _signalVariance(throttle) > .001;
    final step = math.max(1, periodSamples ~/ 100);
    var bestPhase = 0;
    var bestScore = double.negativeInfinity;
    for (var phase = 0; phase < periodSamples; phase += step) {
      final count = (samples.length - 1 - phase) ~/ periodSamples;
      if (count < 2) continue;
      var score = 0.0;
      for (var segment = 0; segment < count - 1; segment++) {
        final first = phase + segment * periodSamples;
        final second = first + periodSamples;
        final firstSteering = _resampleSegment(
          steering,
          first,
          second,
          128,
        );
        final secondSteering = _resampleSegment(
          steering,
          second,
          second + periodSamples,
          128,
        );
        final steeringScore = _signalCorrelation(
          firstSteering,
          secondSteering,
        );
        if (hasThrottle) {
          final firstThrottle = _resampleSegment(
            throttle,
            first,
            second,
            128,
          );
          final secondThrottle = _resampleSegment(
            throttle,
            second,
            second + periodSamples,
            128,
          );
          score += steeringScore * .75 +
              _signalCorrelation(firstThrottle, secondThrottle) * .25;
        } else {
          score += steeringScore;
        }
      }
      score /= count - 1;
      if (score > bestScore) {
        bestScore = score;
        bestPhase = phase;
      }
    }
    final coarseSteering = <List<double>>[];
    final coarseThrottle = <List<double>>[];
    for (var start = bestPhase;
        start + periodSamples < samples.length;
        start += periodSamples) {
      coarseSteering.add(
        _resampleSegment(steering, start, start + periodSamples, 128),
      );
      if (hasThrottle) {
        coarseThrottle.add(
          _resampleSegment(throttle, start, start + periodSamples, 128),
        );
      }
    }
    if (coarseSteering.length < 2) return const _BoundaryResult([]);
    final steeringTemplate = _medianTemplate(coarseSteering);
    final throttleTemplate =
        hasThrottle ? _medianTemplate(coarseThrottle) : const <double>[];

    final indexes = <int>[bestPhase];
    var lowConfidence = false;
    while (samples.length - 1 - indexes.last >= periodSamples * .75) {
      final previous = indexes.last;
      final minimum = previous + (periodSamples * .75).round();
      final maximum = math.min(
        samples.length - 1,
        previous + (periodSamples * 1.25).round(),
      );
      if (minimum > maximum) break;
      var chosen = minimum;
      var chosenCorrelation = double.negativeInfinity;
      var bestAdjusted = double.negativeInfinity;
      for (var candidate = minimum; candidate <= maximum; candidate++) {
        final candidateSteering = _resampleSegment(
          steering,
          previous,
          candidate,
          128,
        );
        var correlation = _signalCorrelation(
          candidateSteering,
          steeringTemplate,
        );
        if (hasThrottle) {
          final candidateThrottle = _resampleSegment(
            throttle,
            previous,
            candidate,
            128,
          );
          correlation = correlation * .75 +
              _signalCorrelation(candidateThrottle, throttleTemplate) * .25;
        }
        final periodDifference =
            (candidate - previous - periodSamples).abs() / periodSamples;
        final adjusted = correlation - periodDifference * .05;
        if (adjusted > bestAdjusted) {
          bestAdjusted = adjusted;
          chosenCorrelation = correlation;
          chosen = candidate;
        }
      }
      if (chosen <= previous) break;
      if (chosen == minimum || chosen == maximum || chosenCorrelation < .25) {
        lowConfidence = true;
      }
      indexes.add(chosen);
    }
    if (indexes.length < 2) return const _BoundaryResult([]);
    return _BoundaryResult(
      indexes.map((index) => samples[index].recordMillis).toList(),
      lowConfidence: lowConfidence,
    );
  }

  static List<double> _normalizeSignal(List<double> values) {
    if (values.isEmpty) return const [];
    final mean = values.reduce((a, b) => a + b) / values.length;
    return values.map((value) => value - mean).toList(growable: false);
  }

  static double _signalVariance(List<double> values) {
    if (values.isEmpty) return 0;
    return values.fold<double>(0, (sum, value) => sum + value * value) /
        values.length;
  }

  static List<double> _resampleSegment(
    List<double> values,
    int start,
    int end,
    int count,
  ) {
    return List.generate(count, (index) {
      final position = start + (end - start) * index / (count - 1);
      final before = position.floor().clamp(0, values.length - 1);
      final after = math.min(values.length - 1, before + 1);
      final fraction = position - before;
      return values[before] + (values[after] - values[before]) * fraction;
    });
  }

  static List<double> _medianTemplate(List<List<double>> segments) {
    return List.generate(segments.first.length, (index) {
      final values = segments.map((segment) => segment[index]).toList()..sort();
      final middle = values.length ~/ 2;
      return values.length.isOdd
          ? values[middle]
          : (values[middle - 1] + values[middle]) / 2;
    });
  }

  static double _signalCorrelation(List<double> first, List<double> second) {
    var dot = 0.0;
    var aa = 0.0;
    var bb = 0.0;
    for (var i = 0; i < math.min(first.length, second.length); i++) {
      final a = first[i];
      final b = second[i];
      dot += a * b;
      aa += a * a;
      bb += b * b;
    }
    return dot / math.max(1e-9, math.sqrt(aa * bb));
  }

  static List<double> _smooth(List<double> values, int window) {
    if (values.isEmpty) return const [];
    final radius = math.max(0, window ~/ 2);
    return List.generate(values.length, (index) {
      var sum = 0.0;
      var count = 0;
      for (var i = math.max(0, index - radius);
          i <= math.min(values.length - 1, index + radius);
          i++) {
        sum += values[i];
        count++;
      }
      return sum / count;
    });
  }

  static List<CoursePoint> _smoothCourse(List<CoursePoint> points, int window) {
    if (points.isEmpty) return const [];
    final radius = math.max(0, window ~/ 2);
    return List.generate(points.length, (index) {
      var x = 0.0;
      var y = 0.0;
      var count = 0;
      for (var offset = -radius; offset <= radius; offset++) {
        final point = points[(index + offset + points.length) % points.length];
        x += point.x;
        y += point.y;
        count++;
      }
      return points[index].copyWith(x: x / count, y: y / count);
    });
  }

  static double _percentile(List<double> values, double percentile) {
    if (values.isEmpty) return 0;
    values.sort();
    return values[
        (values.length * percentile).floor().clamp(0, values.length - 1)];
  }

  static String _newSessionId() =>
      'telemetry-${DateTime.now().microsecondsSinceEpoch}';
}
