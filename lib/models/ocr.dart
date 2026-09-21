enum OcrConfidence {
  high,
  medium,
  low;

  static OcrConfidence fromValue(Object? value) {
    return switch (value?.toString().toLowerCase()) {
      'high' => OcrConfidence.high,
      'medium' => OcrConfidence.medium,
      _ => OcrConfidence.low,
    };
  }

  int get rank => switch (this) {
        OcrConfidence.high => 3,
        OcrConfidence.medium => 2,
        OcrConfidence.low => 1,
      };
}

class OcrGridPoint {
  const OcrGridPoint({required this.row, required this.col});

  final int row;
  final int col;

  Map<String, int> toJson() => {'row': row, 'col': col};

  static OcrGridPoint? tryParse(Object? value) {
    if (value is! Map) return null;
    final row = value['row'];
    final col = value['col'];
    if (row is! num || col is! num) return null;
    if (row.toInt() != row || col.toInt() != col) return null;
    return OcrGridPoint(row: row.toInt(), col: col.toInt());
  }

  @override
  bool operator ==(Object other) =>
      other is OcrGridPoint && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(row, col);
}

class OcrCandidate {
  const OcrCandidate({
    required this.key,
    required this.label,
    required this.rawValue,
    required this.points,
    required this.confidence,
    required this.evidence,
    this.value,
    this.rejectionReason,
  });

  final String key;
  final String label;
  final String rawValue;
  final List<OcrGridPoint> points;
  final OcrConfidence confidence;
  final String evidence;
  final dynamic value;
  final String? rejectionReason;

  bool get isValid => rejectionReason == null && value != null;
  bool get isInitiallySelected => isValid && confidence != OcrConfidence.low;

  factory OcrCandidate.fromAiJson(Map<String, dynamic> json) {
    final rawPoints = json['points'];
    final points = rawPoints is List
        ? rawPoints
            .map(OcrGridPoint.tryParse)
            .whereType<OcrGridPoint>()
            .toList(growable: false)
        : const <OcrGridPoint>[];
    return OcrCandidate(
      key: json['key']?.toString().trim() ?? '',
      label: '',
      rawValue: json['rawValue']?.toString().trim() ?? '',
      points: points,
      confidence: OcrConfidence.fromValue(json['confidence']),
      evidence: json['evidence']?.toString().trim() ?? '',
    );
  }
}

class OcrExtractionResult {
  const OcrExtractionResult({
    required this.detectedModel,
    required this.candidates,
    required this.warnings,
    required this.modelMismatch,
  });

  final String detectedModel;
  final List<OcrCandidate> candidates;
  final List<String> warnings;
  final bool modelMismatch;

  Map<String, dynamic> selectedSettings(Set<String> selectedKeys) {
    return {
      for (final candidate in candidates)
        if (candidate.isValid && selectedKeys.contains(candidate.key))
          candidate.key: candidate.value,
    };
  }
}
