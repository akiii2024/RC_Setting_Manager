import 'dart:typed_data';

import 'telemetry_ai.dart';

enum TelemetrySyncState {
  local,
  pendingUpload,
  synced,
  failed,
  unavailable,
}

class TelemetryAttachment {
  const TelemetryAttachment({
    required this.sessionId,
    required this.csvFileName,
    required this.recordCount,
    required this.durationMillis,
    required this.updatedAt,
    this.bestLapCandidateMillis,
    this.videoFileName,
    this.syncState = TelemetrySyncState.local,
    this.ownerUid,
  });

  final String sessionId;
  final String csvFileName;
  final int recordCount;
  final int durationMillis;
  final int? bestLapCandidateMillis;
  final String? videoFileName;
  final DateTime updatedAt;
  final TelemetrySyncState syncState;
  final String? ownerUid;

  TelemetryAttachment copyWith({
    TelemetrySyncState? syncState,
    String? videoFileName,
    String? ownerUid,
  }) {
    return TelemetryAttachment(
      sessionId: sessionId,
      csvFileName: csvFileName,
      recordCount: recordCount,
      durationMillis: durationMillis,
      bestLapCandidateMillis: bestLapCandidateMillis,
      videoFileName: videoFileName ?? this.videoFileName,
      updatedAt: updatedAt,
      syncState: syncState ?? this.syncState,
      ownerUid: ownerUid ?? this.ownerUid,
    );
  }

  factory TelemetryAttachment.fromJson(Map<String, dynamic> json) {
    return TelemetryAttachment(
      sessionId: json['sessionId'] as String? ?? '',
      csvFileName: json['csvFileName'] as String? ?? 'telemetry.csv',
      recordCount: json['recordCount'] as int? ?? 0,
      durationMillis: json['durationMillis'] as int? ?? 0,
      bestLapCandidateMillis: json['bestLapCandidateMillis'] as int?,
      videoFileName: json['videoFileName'] as String?,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      syncState: TelemetrySyncState.values.firstWhere(
        (value) => value.name == json['syncState'],
        orElse: () => TelemetrySyncState.local,
      ),
      ownerUid: json['ownerUid'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'csvFileName': csvFileName,
        'recordCount': recordCount,
        'durationMillis': durationMillis,
        'bestLapCandidateMillis': bestLapCandidateMillis,
        'videoFileName': videoFileName,
        'updatedAt': updatedAt.toIso8601String(),
        'syncState': syncState.name,
        'ownerUid': ownerUid,
      };
}

class TelemetrySample {
  const TelemetrySample({
    required this.values,
    required this.recordMillis,
    required this.lapMillis,
  });

  final Map<String, String> values;
  final int recordMillis;
  final int lapMillis;

  String operator [](String key) => values[key] ?? '';

  double numeric(String key) {
    final cleaned = (values[key] ?? '').replaceAll(RegExp(r'[^0-9.\-]'), '');
    return double.tryParse(cleaned) ?? 0;
  }
}

class TelemetrySummary {
  const TelemetrySummary({
    this.totalLaps,
    this.bestLapMillis,
    this.averageLapMillis,
    this.raw = const {},
  });

  final int? totalLaps;
  final int? bestLapMillis;
  final int? averageLapMillis;
  final Map<String, String> raw;

  factory TelemetrySummary.fromMap(Map<String, String> values) {
    final totalLaps = int.tryParse(values['TOTAL LAP'] ?? '');
    final bestLap = parseTelemetryTime(values['BEST LAP'] ?? '');
    final averageLap = parseTelemetryTime(values['AVERAGE LAP'] ?? '');
    return TelemetrySummary(
      totalLaps: totalLaps,
      bestLapMillis: bestLap > 0 ? bestLap : null,
      averageLapMillis: averageLap > 0 ? averageLap : null,
      raw: Map.unmodifiable(values),
    );
  }

  String? operator [](String key) => raw[key];
}

class TelemetryLap {
  const TelemetryLap({
    required this.number,
    required this.startMillis,
    required this.endMillis,
  });

  final int number;
  final int startMillis;
  final int endMillis;

  int get durationMillis => endMillis - startMillis;
}

class LapPrediction {
  const LapPrediction({
    this.detectedPeriodMillis = 0,
    this.bestLapMillis,
    this.averageLapMillis,
    this.laps = const [],
    this.lowConfidence = false,
    this.method = 'none',
  });

  final int detectedPeriodMillis;
  final int? bestLapMillis;
  final int? averageLapMillis;
  final List<TelemetryLap> laps;
  final bool lowConfidence;
  final String method;

  int get lapCount => laps.length;
}

class CoursePoint {
  const CoursePoint({
    required this.x,
    required this.y,
    required this.timeMillis,
  });

  final double x;
  final double y;
  final int timeMillis;

  CoursePoint copyWith({double? x, double? y, int? timeMillis}) => CoursePoint(
        x: x ?? this.x,
        y: y ?? this.y,
        timeMillis: timeMillis ?? this.timeMillis,
      );

  factory CoursePoint.fromJson(Map<String, dynamic> json) => CoursePoint(
        x: (json['x'] as num?)?.toDouble() ?? 0,
        y: (json['y'] as num?)?.toDouble() ?? 0,
        timeMillis:
            ((json['time'] ?? json['timeMillis']) as num?)?.round() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'time': timeMillis,
      };
}

class CourseOptions {
  const CourseOptions({
    this.baseSpeed = 3,
    this.steerGain = 1,
    this.steerSpeedLoss = 0.3,
    this.brakeSpeedLoss = 0.5,
    this.steerGamma = 1.35,
    this.smoothWindow = 7,
  });

  final double baseSpeed;
  final double steerGain;
  final double steerSpeedLoss;
  final double brakeSpeedLoss;
  final double steerGamma;
  final int smoothWindow;

  CourseOptions copyWith({
    double? baseSpeed,
    double? steerGain,
    double? steerSpeedLoss,
    double? brakeSpeedLoss,
    double? steerGamma,
    int? smoothWindow,
  }) =>
      CourseOptions(
        baseSpeed: baseSpeed ?? this.baseSpeed,
        steerGain: steerGain ?? this.steerGain,
        steerSpeedLoss: steerSpeedLoss ?? this.steerSpeedLoss,
        brakeSpeedLoss: brakeSpeedLoss ?? this.brakeSpeedLoss,
        steerGamma: steerGamma ?? this.steerGamma,
        smoothWindow: smoothWindow ?? this.smoothWindow,
      );

  factory CourseOptions.fromJson(Map<String, dynamic> json) => CourseOptions(
        baseSpeed: (json['baseSpeed'] as num?)?.toDouble() ?? 3,
        steerGain: (json['steerGain'] as num?)?.toDouble() ?? 1,
        steerSpeedLoss: (json['steerSpeedLoss'] as num?)?.toDouble() ?? 0.3,
        brakeSpeedLoss: (json['brakeSpeedLoss'] as num?)?.toDouble() ?? 0.5,
        steerGamma: (json['steerGamma'] as num?)?.toDouble() ?? 1.35,
        smoothWindow: (json['smoothWindow'] as num?)?.round() ?? 7,
      );

  Map<String, dynamic> toJson() => {
        'baseSpeed': baseSpeed,
        'steerGain': steerGain,
        'steerSpeedLoss': steerSpeedLoss,
        'brakeSpeedLoss': brakeSpeedLoss,
        'steerGamma': steerGamma,
        'smoothWindow': smoothWindow,
      };
}

class TelemetrySession {
  TelemetrySession({
    required this.id,
    required this.csvFileName,
    required this.csvText,
    required this.summary,
    required this.columns,
    required this.samples,
    required this.prediction,
    this.selectedMetrics = const ['ST(%)', 'TH(%)'],
    this.viewWindowSeconds = 0,
    this.courseOptions = const CourseOptions(),
    this.editedCoursePoints,
    this.videoFileName,
    this.videoBytes,
    this.videoSyncMode = 'start',
    this.videoOffsetMillis = 0,
    this.aiAnalysis,
  });

  final String id;
  final String csvFileName;
  final String csvText;
  final TelemetrySummary summary;
  final List<String> columns;
  final List<TelemetrySample> samples;
  final LapPrediction prediction;
  List<String> selectedMetrics;
  double viewWindowSeconds;
  CourseOptions courseOptions;
  List<CoursePoint>? editedCoursePoints;
  String? videoFileName;
  Uint8List? videoBytes;
  String videoSyncMode;
  int videoOffsetMillis;
  TelemetryAiResult? aiAnalysis;

  int get durationMillis => samples.isEmpty ? 0 : samples.last.recordMillis;

  List<String> get metrics => columns
      .where(
          (column) => !const ['LAP', 'LAP TIME', 'REC TIME'].contains(column))
      .toList(growable: false);

  int? get bestLapCandidateMillis {
    return summary.bestLapMillis ?? prediction.bestLapMillis;
  }

  TelemetryAttachment attachment({
    TelemetrySyncState syncState = TelemetrySyncState.local,
  }) =>
      TelemetryAttachment(
        sessionId: id,
        csvFileName: csvFileName,
        recordCount: samples.length,
        durationMillis: durationMillis,
        bestLapCandidateMillis: bestLapCandidateMillis,
        videoFileName: videoFileName,
        updatedAt: DateTime.now(),
        syncState: syncState,
      );
}

class TelemetrySyncJob {
  const TelemetrySyncJob({
    required this.sessionId,
    required this.runLogId,
    required this.operation,
    required this.createdAt,
    this.ownerUid,
    this.attempts = 0,
    this.lastError,
  });

  final String sessionId;
  final String runLogId;
  final String operation;
  final DateTime createdAt;
  final String? ownerUid;
  final int attempts;
  final String? lastError;

  factory TelemetrySyncJob.fromJson(Map<String, dynamic> json) =>
      TelemetrySyncJob(
        sessionId: json['sessionId'] as String? ?? '',
        runLogId: json['runLogId'] as String? ?? '',
        operation: json['operation'] as String? ?? 'upload',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        ownerUid: json['ownerUid'] as String?,
        attempts: json['attempts'] as int? ?? 0,
        lastError: json['lastError'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'runLogId': runLogId,
        'operation': operation,
        'createdAt': createdAt.toIso8601String(),
        'ownerUid': ownerUid,
        'attempts': attempts,
        'lastError': lastError,
      };
}

int parseTelemetryTime(String value) {
  final cleaned = value.replaceAll("'", '').trim();
  final parts = cleaned.split(':');
  if (parts.isEmpty || parts.length > 3) return 0;
  final hours = parts.length == 3 ? int.tryParse(parts[0]) : 0;
  final minutes = parts.length >= 2 ? int.tryParse(parts[parts.length - 2]) : 0;
  final secondParts = parts.last.split('.');
  final seconds = int.tryParse(secondParts[0]);
  if (hours == null ||
      minutes == null ||
      seconds == null ||
      minutes < 0 ||
      minutes >= 60 ||
      seconds < 0 ||
      seconds >= 60) {
    return 0;
  }
  final fraction = secondParts.length > 1 ? secondParts[1] : '0';
  final fractionValue = double.tryParse('0.$fraction') ?? 0;
  return ((hours * 3600 + minutes * 60 + seconds) * 1000 + fractionValue * 1000)
      .round();
}

String formatTelemetryTime(int milliseconds) {
  final safe = milliseconds.clamp(0, 1 << 53);
  final totalSeconds = safe ~/ 1000;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  final fraction = (safe % 1000) ~/ 10;
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(hours)}:${two(minutes)}:${two(seconds)}.${two(fraction)}';
}
