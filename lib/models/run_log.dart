import 'car.dart';

class RunSettingChange {
  final String settingKey;
  final String settingLabel;
  final dynamic beforeValue;
  final dynamic afterValue;

  const RunSettingChange({
    required this.settingKey,
    required this.settingLabel,
    this.beforeValue,
    this.afterValue,
  });

  factory RunSettingChange.fromJson(Map<String, dynamic> json) {
    return RunSettingChange(
      settingKey: json['settingKey'] as String? ?? '',
      settingLabel: json['settingLabel'] as String? ?? '',
      beforeValue: json['beforeValue'],
      afterValue: json['afterValue'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'settingKey': settingKey,
      'settingLabel': settingLabel,
      'beforeValue': beforeValue,
      'afterValue': afterValue,
    };
  }
}

class RunLog {
  final String id;
  final DateTime createdAt;
  final DateTime runAt;
  final Car car;
  final String? baseSettingId;
  final String? baseSettingName;
  final String? resultSettingId;
  final String? resultSettingName;
  final int bestLapMillis;
  final List<String> feelTagIds;
  final String memo;
  final List<RunSettingChange> changes;

  const RunLog({
    required this.id,
    required this.createdAt,
    required this.runAt,
    required this.car,
    this.baseSettingId,
    this.baseSettingName,
    this.resultSettingId,
    this.resultSettingName,
    required this.bestLapMillis,
    required this.feelTagIds,
    required this.memo,
    required this.changes,
  });

  RunLog copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? runAt,
    Car? car,
    String? baseSettingId,
    String? baseSettingName,
    String? resultSettingId,
    String? resultSettingName,
    int? bestLapMillis,
    List<String>? feelTagIds,
    String? memo,
    List<RunSettingChange>? changes,
  }) {
    return RunLog(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      runAt: runAt ?? this.runAt,
      car: car ?? this.car,
      baseSettingId: baseSettingId ?? this.baseSettingId,
      baseSettingName: baseSettingName ?? this.baseSettingName,
      resultSettingId: resultSettingId ?? this.resultSettingId,
      resultSettingName: resultSettingName ?? this.resultSettingName,
      bestLapMillis: bestLapMillis ?? this.bestLapMillis,
      feelTagIds: feelTagIds ?? this.feelTagIds,
      memo: memo ?? this.memo,
      changes: changes ?? this.changes,
    );
  }

  factory RunLog.fromJson(Map<String, dynamic> json) {
    return RunLog(
      id: json['id'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      runAt: DateTime.parse(json['runAt'] as String),
      car: Car.fromJson(json['car'] as Map<String, dynamic>),
      baseSettingId: json['baseSettingId'] as String?,
      baseSettingName: json['baseSettingName'] as String?,
      resultSettingId: json['resultSettingId'] as String?,
      resultSettingName: json['resultSettingName'] as String?,
      bestLapMillis: json['bestLapMillis'] as int? ?? 0,
      feelTagIds: json['feelTagIds'] != null
          ? List<String>.from(json['feelTagIds'] as List)
          : const [],
      memo: json['memo'] as String? ?? '',
      changes: json['changes'] != null
          ? (json['changes'] as List)
              .map(
                (item) =>
                    RunSettingChange.fromJson(item as Map<String, dynamic>),
              )
              .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'createdAt': createdAt.toIso8601String(),
      'runAt': runAt.toIso8601String(),
      'car': car.toJson(),
      'baseSettingId': baseSettingId,
      'baseSettingName': baseSettingName,
      'resultSettingId': resultSettingId,
      'resultSettingName': resultSettingName,
      'bestLapMillis': bestLapMillis,
      'feelTagIds': feelTagIds,
      'memo': memo,
      'changes': changes.map((change) => change.toJson()).toList(),
    };
  }
}
