enum TelemetrySensorQuality { absent, unusable, static, dynamic }

class TelemetrySensorStatus {
  const TelemetrySensorStatus(
      {required this.quality, this.min, this.max, this.average});
  final TelemetrySensorQuality quality;
  final double? min;
  final double? max;
  final double? average;
  Map<String, dynamic> toJson() => {
        'quality': quality.name,
        if (min != null) 'min': min,
        if (max != null) 'max': max,
        if (average != null) 'average': average,
      };
}

class TelemetryWavePoint {
  const TelemetryWavePoint({required this.t, required this.st, this.th});
  final double t;
  final double st;
  final double? th;
  Map<String, dynamic> toJson() => {'t': t, 'st': st, if (th != null) 'th': th};
}

class TelemetryCornerFeatures {
  const TelemetryCornerFeatures(
      {required this.number,
      required this.startMillis,
      required this.endMillis,
      required this.peakSteering,
      this.brakeStartMillis,
      this.turnInMillis,
      this.throttleReapplyMillis,
      this.fullThrottleMillis,
      this.steeringCorrections = 0});
  final int number;
  final int startMillis;
  final int endMillis;
  final double peakSteering;
  final int? brakeStartMillis;
  final int? turnInMillis;
  final int? throttleReapplyMillis;
  final int? fullThrottleMillis;
  final int steeringCorrections;
  Map<String, dynamic> toJson() => {
        'corner': number,
        'start': startMillis,
        'end': endMillis,
        'peakSteering': peakSteering,
        if (brakeStartMillis != null) 'brakeStart': brakeStartMillis,
        if (turnInMillis != null) 'turnIn': turnInMillis,
        if (throttleReapplyMillis != null)
          'throttleReapply': throttleReapplyMillis,
        if (fullThrottleMillis != null) 'fullThrottle': fullThrottleMillis,
        'steeringCorrections': steeringCorrections,
      };
}

class TelemetryLapFeatures {
  const TelemetryLapFeatures(
      {required this.number,
      required this.startMillis,
      required this.endMillis,
      required this.fullThrottleRatio,
      required this.neutralRatio,
      required this.brakeRatio,
      required this.fullBrakeRatio,
      required this.fullSteeringRatio,
      required this.steeringCenterRatio,
      this.corners = const [],
      this.waveform = const [],
      this.alignmentCost = 0});
  final int number;
  final int startMillis;
  final int endMillis;
  final double fullThrottleRatio;
  final double neutralRatio;
  final double brakeRatio;
  final double fullBrakeRatio;
  final double fullSteeringRatio;
  final double steeringCenterRatio;
  final List<TelemetryCornerFeatures> corners;
  final List<TelemetryWavePoint> waveform;
  final double alignmentCost;
  int get durationMillis => endMillis - startMillis;
  Map<String, dynamic> toJson() => {
        'lap': number,
        'durationMillis': durationMillis,
        'fullThrottleRatio': fullThrottleRatio,
        'neutralRatio': neutralRatio,
        'brakeRatio': brakeRatio,
        'fullBrakeRatio': fullBrakeRatio,
        'fullSteeringRatio': fullSteeringRatio,
        'steeringCenterRatio': steeringCenterRatio,
        'corners': corners.map((e) => e.toJson()).toList(),
        'waveform': waveform.map((e) => e.toJson()).toList(),
        if (alignmentCost != 0) 'alignmentCost': alignmentCost
      };
}

class TelemetryEvidence {
  const TelemetryEvidence(
      {required this.id,
      required this.metric,
      required this.value,
      this.lap,
      this.corner,
      this.referenceValue,
      this.difference,
      this.unit = ''});
  final String id;
  final String metric;
  final double value;
  final int? lap;
  final int? corner;
  final double? referenceValue;
  final double? difference;
  final String unit;
  Map<String, dynamic> toJson() => {
        'id': id,
        'metric': metric,
        'value': value,
        if (lap != null) 'lap': lap,
        if (corner != null) 'corner': corner,
        if (referenceValue != null) 'referenceValue': referenceValue,
        if (difference != null) 'difference': difference,
        'unit': unit
      };
}

class TelemetryFeatureReport {
  const TelemetryFeatureReport(
      {required this.sensorStatus,
      required this.laps,
      required this.selectedLapNumbers,
      required this.evidence,
      required this.excludedLaps,
      required this.inputFingerprint,
      this.referenceLapNumber,
      this.waveformPoints = 96});
  final Map<String, TelemetrySensorStatus> sensorStatus;
  final List<TelemetryLapFeatures> laps;
  final List<int> selectedLapNumbers;
  final List<TelemetryEvidence> evidence;
  final List<String> excludedLaps;
  final String inputFingerprint;
  final int? referenceLapNumber;
  final int waveformPoints;
  Map<String, dynamic> toJson() => {
        'schemaVersion': 1,
        'sensorStatus': sensorStatus.map((k, v) => MapEntry(k, v.toJson())),
        'laps': laps
            .where((l) => selectedLapNumbers.contains(l.number))
            .map((l) => l.toJson())
            .toList(),
        'selectedLaps': selectedLapNumbers,
        'evidence': evidence.map((e) => e.toJson()).toList(),
        'excludedLaps': excludedLaps,
        'referenceLap': referenceLapNumber,
        'inputFingerprint': inputFingerprint,
        'waveformPoints': waveformPoints
      };
}

class TelemetryAiFocusArea {
  const TelemetryAiFocusArea(
      {required this.title,
      this.evidenceIds = const [],
      this.inference = '',
      this.coachingTip = '',
      this.verification = ''});
  final String title;
  final List<String> evidenceIds;
  final String inference;
  final String coachingTip;
  final String verification;
  factory TelemetryAiFocusArea.fromJson(Map<String, dynamic> json) =>
      TelemetryAiFocusArea(
          title: json['title'] as String? ?? '',
          evidenceIds: (json['evidenceIds'] as List? ?? const [])
              .whereType<String>()
              .toList(),
          inference: json['inference'] as String? ?? '',
          coachingTip: json['coachingTip'] as String? ?? '',
          verification: json['verification'] as String? ?? '');
  Map<String, dynamic> toJson() => {
        'title': title,
        'evidenceIds': evidenceIds,
        'inference': inference,
        'coachingTip': coachingTip,
        'verification': verification
      };
}

class TelemetryAiResult {
  const TelemetryAiResult(
      {required this.summary,
      required this.confidence,
      this.strengthEvidenceIds = const [],
      this.focusAreas = const [],
      this.limitations = const [],
      required this.provider,
      required this.model,
      required this.generatedAt,
      required this.inputFingerprint,
      this.schemaVersion = 1});
  final String summary;
  final String confidence;
  final List<String> strengthEvidenceIds;
  final List<TelemetryAiFocusArea> focusAreas;
  final List<String> limitations;
  final String provider;
  final String model;
  final DateTime generatedAt;
  final String inputFingerprint;
  final int schemaVersion;
  factory TelemetryAiResult.fromJson(Map<String, dynamic> json) =>
      TelemetryAiResult(
          summary: json['summary'] as String? ?? '',
          confidence: json['confidence'] as String? ?? 'low',
          strengthEvidenceIds:
              (json['strengthEvidenceIds'] as List? ?? const [])
                  .whereType<String>()
                  .toList(),
          focusAreas: (json['focusAreas'] as List? ?? const [])
              .whereType<Map>()
              .map((e) =>
                  TelemetryAiFocusArea.fromJson(Map<String, dynamic>.from(e)))
              .toList(),
          limitations: (json['limitations'] as List? ?? const [])
              .whereType<String>()
              .toList(),
          provider: json['provider'] as String? ?? '',
          model: json['model'] as String? ?? '',
          generatedAt:
              DateTime.tryParse(json['generatedAt'] as String? ?? '') ??
                  DateTime.fromMillisecondsSinceEpoch(0),
          inputFingerprint: json['inputFingerprint'] as String? ?? '',
          schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1);
  Map<String, dynamic> toJson() => {
        'summary': summary,
        'confidence': confidence,
        'strengthEvidenceIds': strengthEvidenceIds,
        'focusAreas': focusAreas.map((e) => e.toJson()).toList(),
        'limitations': limitations,
        'provider': provider,
        'model': model,
        'generatedAt': generatedAt.toIso8601String(),
        'inputFingerprint': inputFingerprint,
        'schemaVersion': schemaVersion
      };
}
