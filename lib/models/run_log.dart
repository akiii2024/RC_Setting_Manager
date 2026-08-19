import 'car.dart';
import 'immutable_json.dart';

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

  RunSettingChange._immutable({
    required this.settingKey,
    required this.settingLabel,
    Object? beforeValue,
    Object? afterValue,
  })  : beforeValue = freezeJsonValue(beforeValue),
        afterValue = freezeJsonValue(afterValue);

  factory RunSettingChange.immutableCopy(RunSettingChange source) {
    return RunSettingChange._immutable(
      settingKey: source.settingKey,
      settingLabel: source.settingLabel,
      beforeValue: source.beforeValue,
      afterValue: source.afterValue,
    );
  }

  factory RunSettingChange.fromJson(Map<String, dynamic> json) {
    return RunSettingChange(
      settingKey: json['settingKey'] as String? ?? '',
      settingLabel: json['settingLabel'] as String? ?? '',
      beforeValue: json['beforeValue'],
      afterValue: json['afterValue'],
    );
  }

  factory RunSettingChange.fromJsonStrict(Map<String, dynamic> json) {
    final settingKey = json['settingKey'];
    final settingLabel = json['settingLabel'];
    if (settingKey is! String || settingKey.trim().isEmpty) {
      throw const FormatException(
        'RunSettingChange settingKey must be a non-empty string.',
      );
    }
    if (settingLabel is! String) {
      throw const FormatException(
        'RunSettingChange settingLabel must be a string.',
      );
    }
    if (!json.containsKey('beforeValue') || !json.containsKey('afterValue')) {
      throw const FormatException(
        'RunSettingChange beforeValue and afterValue are required.',
      );
    }
    return RunSettingChange._immutable(
      settingKey: settingKey,
      settingLabel: settingLabel,
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
  final String trackName;
  final String? baseSettingId;
  final String? baseSettingName;
  final String? resultSettingId;
  final String? resultSettingName;
  final int bestLapMillis;
  final double? airTempC;
  final double? humidityPercent;
  final String weatherCondition;
  final double? trackTempC;
  final String trackCondition;
  final List<String> feelTagIds;
  final String memo;
  final List<RunSettingChange> changes;

  RunLog({
    required this.id,
    required this.createdAt,
    required this.runAt,
    required this.car,
    this.trackName = '',
    this.baseSettingId,
    this.baseSettingName,
    this.resultSettingId,
    this.resultSettingName,
    required this.bestLapMillis,
    this.airTempC,
    this.humidityPercent,
    this.weatherCondition = '',
    this.trackTempC,
    this.trackCondition = '',
    required List<String> feelTagIds,
    required this.memo,
    required List<RunSettingChange> changes,
  })  : feelTagIds = List<String>.unmodifiable(feelTagIds),
        changes = List<RunSettingChange>.unmodifiable(
          changes.map(RunSettingChange.immutableCopy),
        );

  RunLog copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? runAt,
    Car? car,
    String? trackName,
    String? baseSettingId,
    String? baseSettingName,
    String? resultSettingId,
    String? resultSettingName,
    int? bestLapMillis,
    double? airTempC,
    double? humidityPercent,
    String? weatherCondition,
    double? trackTempC,
    String? trackCondition,
    List<String>? feelTagIds,
    String? memo,
    List<RunSettingChange>? changes,
  }) {
    return RunLog(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      runAt: runAt ?? this.runAt,
      car: car ?? this.car,
      trackName: trackName ?? this.trackName,
      baseSettingId: baseSettingId ?? this.baseSettingId,
      baseSettingName: baseSettingName ?? this.baseSettingName,
      resultSettingId: resultSettingId ?? this.resultSettingId,
      resultSettingName: resultSettingName ?? this.resultSettingName,
      bestLapMillis: bestLapMillis ?? this.bestLapMillis,
      airTempC: airTempC ?? this.airTempC,
      humidityPercent: humidityPercent ?? this.humidityPercent,
      weatherCondition: weatherCondition ?? this.weatherCondition,
      trackTempC: trackTempC ?? this.trackTempC,
      trackCondition: trackCondition ?? this.trackCondition,
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
      trackName: json['trackName'] as String? ?? '',
      baseSettingId: json['baseSettingId'] as String?,
      baseSettingName: json['baseSettingName'] as String?,
      resultSettingId: json['resultSettingId'] as String?,
      resultSettingName: json['resultSettingName'] as String?,
      bestLapMillis: json['bestLapMillis'] as int? ?? 0,
      airTempC: _nullableDouble(json['airTempC']),
      humidityPercent: _nullableDouble(json['humidityPercent']),
      weatherCondition: json['weatherCondition'] as String? ?? '',
      trackTempC: _nullableDouble(json['trackTempC']),
      trackCondition: json['trackCondition'] as String? ?? '',
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

  factory RunLog.fromJsonStrict(Map<String, dynamic> json) {
    final id = _requiredString(json, 'id', allowEmpty: false);
    final createdAt = DateTime.parse(
      _requiredString(json, 'createdAt', allowEmpty: false),
    );
    final runAt = DateTime.parse(
      _requiredString(json, 'runAt', allowEmpty: false),
    );
    final carJson = json['car'];
    if (carJson is! Map<String, dynamic>) {
      throw const FormatException('RunLog car must be a JSON object.');
    }
    for (final key in const [
      'trackName',
      'weatherCondition',
      'trackCondition',
      'memo',
    ]) {
      _requiredString(json, key);
    }
    for (final key in const [
      'baseSettingId',
      'baseSettingName',
      'resultSettingId',
      'resultSettingName',
    ]) {
      _nullableString(json, key);
    }
    if (json['bestLapMillis'] is! int) {
      throw const FormatException('RunLog bestLapMillis must be an integer.');
    }
    for (final key in const [
      'airTempC',
      'humidityPercent',
      'trackTempC',
    ]) {
      final value = json[key];
      if (!json.containsKey(key) || (value != null && value is! num)) {
        throw FormatException('RunLog $key must be a number or null.');
      }
    }
    final feelTagIdsJson = json['feelTagIds'];
    if (feelTagIdsJson is! List<dynamic> ||
        feelTagIdsJson.any((value) => value is! String)) {
      throw const FormatException('RunLog feelTagIds must contain strings.');
    }
    final changesJson = json['changes'];
    if (changesJson is! List<dynamic>) {
      throw const FormatException('RunLog changes must be a JSON array.');
    }
    final changes = changesJson.indexed.map((entry) {
      final (index, value) = entry;
      if (value is! Map<String, dynamic>) {
        throw FormatException('RunLog changes[$index] must be a JSON object.');
      }
      return RunSettingChange.fromJsonStrict(value);
    }).toList(growable: false);

    return RunLog(
      id: id,
      createdAt: createdAt,
      runAt: runAt,
      car: Car.fromJsonStrict(carJson),
      trackName: json['trackName'] as String,
      baseSettingId: json['baseSettingId'] as String?,
      baseSettingName: json['baseSettingName'] as String?,
      resultSettingId: json['resultSettingId'] as String?,
      resultSettingName: json['resultSettingName'] as String?,
      bestLapMillis: json['bestLapMillis'] as int,
      airTempC: (json['airTempC'] as num?)?.toDouble(),
      humidityPercent: (json['humidityPercent'] as num?)?.toDouble(),
      weatherCondition: json['weatherCondition'] as String,
      trackTempC: (json['trackTempC'] as num?)?.toDouble(),
      trackCondition: json['trackCondition'] as String,
      feelTagIds: List<String>.from(feelTagIdsJson),
      memo: json['memo'] as String,
      changes: changes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'createdAt': createdAt.toIso8601String(),
      'runAt': runAt.toIso8601String(),
      'car': car.toJson(),
      'trackName': trackName,
      'baseSettingId': baseSettingId,
      'baseSettingName': baseSettingName,
      'resultSettingId': resultSettingId,
      'resultSettingName': resultSettingName,
      'bestLapMillis': bestLapMillis,
      'airTempC': airTempC,
      'humidityPercent': humidityPercent,
      'weatherCondition': weatherCondition,
      'trackTempC': trackTempC,
      'trackCondition': trackCondition,
      'feelTagIds': feelTagIds,
      'memo': memo,
      'changes': changes.map((change) => change.toJson()).toList(),
    };
  }

  static double? _nullableDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        return null;
      }
      return double.tryParse(trimmed.replaceAll(',', '.'));
    }
    return null;
  }

  static String _requiredString(
    Map<String, dynamic> json,
    String key, {
    bool allowEmpty = true,
  }) {
    final value = json[key];
    if (value is! String || (!allowEmpty && value.trim().isEmpty)) {
      throw FormatException('RunLog $key must be a string.');
    }
    return value;
  }

  static void _nullableString(Map<String, dynamic> json, String key) {
    if (!json.containsKey(key) || (json[key] != null && json[key] is! String)) {
      throw FormatException('RunLog $key must be a string or null.');
    }
  }
}
