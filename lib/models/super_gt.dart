// RC Super GT (4WD) の規則と車検計算を扱うドメインモデル。

enum SuperGtPowerSource { hobbywing, yokomo }

enum SuperGtBodyGroup { a, b }

enum SuperGtCheckState { pass, fail, unconfirmed }

class SuperGtRuleProfile {
  const SuperGtRuleProfile({
    required this.id,
    required this.title,
    required this.sourceUrl,
    required this.powerSource,
    required this.bodyGroup,
    required this.minimumFinalDriveRatio,
    required this.maxTireRpm,
    required this.minBodyWeightGrams,
    required this.minCarWeightGrams,
    required this.minVoltage,
    required this.maxVoltage,
  });

  static const sourceUrlValue =
      'https://www.rc-sgt.com/post/2026%E5%B9%B4%E5%BA%A6-%E5%85%A8%E5%9B%BD%E7%B5%B1%E4%B8%80%E3%83%AC%E3%82%AE%E3%83%A5%E3%83%AC%E3%83%BC%E3%82%B7%E3%83%A7%E3%83%B3-2026-2-27%E6%9B%B4%E6%96%B0';

  static const hobbywingA = SuperGtRuleProfile(
      id: '2026-08-10-4wd-hobbywing-a',
      title: '2026 Super GT 4WD / Hobbywing / A',
      sourceUrl: sourceUrlValue,
      powerSource: SuperGtPowerSource.hobbywing,
      bodyGroup: SuperGtBodyGroup.a,
      minimumFinalDriveRatio: 5.3,
      maxTireRpm: 4000,
      minBodyWeightGrams: 80,
      minCarWeightGrams: 1220,
      minVoltage: 8.3,
      maxVoltage: 8.4);
  static const hobbywingB = SuperGtRuleProfile(
      id: '2026-08-10-4wd-hobbywing-b',
      title: '2026 Super GT 4WD / Hobbywing / B',
      sourceUrl: sourceUrlValue,
      powerSource: SuperGtPowerSource.hobbywing,
      bodyGroup: SuperGtBodyGroup.b,
      minimumFinalDriveRatio: 5.3,
      maxTireRpm: 4000,
      minBodyWeightGrams: 80,
      minCarWeightGrams: 1300,
      minVoltage: 8.3,
      maxVoltage: 8.4);
  static const yokomoA = SuperGtRuleProfile(
      id: '2026-08-10-4wd-yokomo-a',
      title: '2026 Super GT 4WD / Yokomo / A',
      sourceUrl: sourceUrlValue,
      powerSource: SuperGtPowerSource.yokomo,
      bodyGroup: SuperGtBodyGroup.a,
      minimumFinalDriveRatio: 5.3,
      maxTireRpm: 3800,
      minBodyWeightGrams: 80,
      minCarWeightGrams: 1220,
      minVoltage: 8.3,
      maxVoltage: 8.4);
  static const yokomoB = SuperGtRuleProfile(
      id: '2026-08-10-4wd-yokomo-b',
      title: '2026 Super GT 4WD / Yokomo / B',
      sourceUrl: sourceUrlValue,
      powerSource: SuperGtPowerSource.yokomo,
      bodyGroup: SuperGtBodyGroup.b,
      minimumFinalDriveRatio: 5.3,
      maxTireRpm: 3800,
      minBodyWeightGrams: 80,
      minCarWeightGrams: 1300,
      minVoltage: 8.3,
      maxVoltage: 8.4);

  final String id, title, sourceUrl;
  final SuperGtPowerSource powerSource;
  final SuperGtBodyGroup bodyGroup;
  final double minimumFinalDriveRatio, maxTireRpm, minBodyWeightGrams;
  final double minCarWeightGrams, minVoltage, maxVoltage;

  factory SuperGtRuleProfile.for4wd(
      SuperGtPowerSource powerSource, SuperGtBodyGroup bodyGroup) {
    return switch ((powerSource, bodyGroup)) {
      (SuperGtPowerSource.hobbywing, SuperGtBodyGroup.a) => hobbywingA,
      (SuperGtPowerSource.hobbywing, SuperGtBodyGroup.b) => hobbywingB,
      (SuperGtPowerSource.yokomo, SuperGtBodyGroup.a) => yokomoA,
      (SuperGtPowerSource.yokomo, SuperGtBodyGroup.b) => yokomoB,
    };
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'sourceUrl': sourceUrl,
        'powerSource': powerSource.name,
        'bodyGroup': bodyGroup.name,
        'minimumFinalDriveRatio': minimumFinalDriveRatio,
        'maxTireRpm': maxTireRpm,
        'minBodyWeightGrams': minBodyWeightGrams,
        'minCarWeightGrams': minCarWeightGrams,
        'minVoltage': minVoltage,
        'maxVoltage': maxVoltage,
      };

  factory SuperGtRuleProfile.fromJson(Map<String, dynamic> json) {
    try {
      final power =
          SuperGtPowerSource.values.byName(_string(json, 'powerSource'));
      final body = SuperGtBodyGroup.values.byName(_string(json, 'bodyGroup'));
      final profile = SuperGtRuleProfile(
        id: _string(json, 'id'),
        title: _string(json, 'title'),
        sourceUrl: _string(json, 'sourceUrl'),
        powerSource: power,
        bodyGroup: body,
        minimumFinalDriveRatio: _finite(json, 'minimumFinalDriveRatio'),
        maxTireRpm: _finite(json, 'maxTireRpm'),
        minBodyWeightGrams: _finite(json, 'minBodyWeightGrams'),
        minCarWeightGrams: _finite(json, 'minCarWeightGrams'),
        minVoltage: _finite(json, 'minVoltage'),
        maxVoltage: _finite(json, 'maxVoltage'),
      );
      if (profile.minimumFinalDriveRatio <= 0 ||
          profile.maxTireRpm <= 0 ||
          profile.minBodyWeightGrams <= 0 ||
          profile.minCarWeightGrams <= 0 ||
          profile.minVoltage <= 0 ||
          profile.maxVoltage <= 0 ||
          profile.minVoltage > profile.maxVoltage) {
        throw StateError('Invalid rule limits');
      }
      return profile;
    } catch (e) {
      throw FormatException('Invalid SuperGtRuleProfile JSON', json.toString());
    }
  }
}

class SuperGtDriveMath {
  static double finalDriveRatio(
      {required double spurTeeth,
      required double pinionTeeth,
      required double internalRatio}) {
    _positiveInteger(spurTeeth, 'spurTeeth');
    _positiveInteger(pinionTeeth, 'pinionTeeth');
    _positive(internalRatio, 'internalRatio');
    return _positive(
        spurTeeth / pinionTeeth * internalRatio, 'finalDriveRatio');
  }

  static double inferredMotorRpm(
      {required double tireRpm, required double finalDriveRatio}) {
    _positive(tireRpm, 'tireRpm');
    _positive(finalDriveRatio, 'finalDriveRatio');
    return _positive(tireRpm * finalDriveRatio, 'motorRpm');
  }

  static double predictedTireRpm(
      {required double motorRpm, required double finalDriveRatio}) {
    _positive(motorRpm, 'motorRpm');
    _positive(finalDriveRatio, 'finalDriveRatio');
    return _positive(motorRpm / finalDriveRatio, 'tireRpm');
  }
}

class SuperGtCheck {
  const SuperGtCheck(
      {required this.key,
      required this.label,
      required this.state,
      required this.message});
  final String key, label, message;
  final SuperGtCheckState state;
}

class SuperGtMeasurement {
  static const settingKey = 'superGtMeasurement';
  SuperGtMeasurement({
    required this.measuredAt,
    required this.rules,
    required double finalDriveRatio,
    required double tireRpm,
    this.carWeightGrams,
    this.bodyWeightGrams,
    this.batteryVoltage,
    this.motorName = '',
    this.memo = '',
    Map<String, bool> confirmations = const {},
  })  : finalDriveRatio = _positive(finalDriveRatio, 'finalDriveRatio'),
        tireRpm = _positive(tireRpm, 'tireRpm'),
        confirmations = Map.unmodifiable(confirmations) {
    _optionalPositive(carWeightGrams, 'carWeightGrams');
    _optionalPositive(bodyWeightGrams, 'bodyWeightGrams');
    _optionalPositive(batteryVoltage, 'batteryVoltage');
    SuperGtDriveMath.inferredMotorRpm(
        tireRpm: this.tireRpm, finalDriveRatio: this.finalDriveRatio);
  }

  final DateTime measuredAt;
  final SuperGtRuleProfile rules;
  final double finalDriveRatio, tireRpm;
  final double? carWeightGrams, bodyWeightGrams, batteryVoltage;
  final String motorName, memo;
  final Map<String, bool> confirmations;
  double get inferredMotorRpm => SuperGtDriveMath.inferredMotorRpm(
      tireRpm: tireRpm, finalDriveRatio: finalDriveRatio);

  List<SuperGtCheck> get checks => localizedChecks();

  List<SuperGtCheck> localizedChecks({bool isEnglish = false}) {
    String t(String en, String ja) => isEnglish ? en : ja;

    String margin(double value) => value >= 0
        ? t('headroom ${_format(value)}', '余裕 ${_format(value)}')
        : t('short by ${_format(-value)}', '不足 ${_format(-value)}');

    String weightMargin(double? value, double minimum) =>
        value == null ? '' : '${margin(value - minimum)} g';

    SuperGtCheck numeric(String key, String label, bool pass, String detail) =>
        SuperGtCheck(
          key: key,
          label: label,
          state: pass ? SuperGtCheckState.pass : SuperGtCheckState.fail,
          message: pass
              ? t('Within spec: $detail', '条件内: $detail')
              : t('Out of spec: $detail', '条件外: $detail'),
        );

    SuperGtCheck optional(String key, String label, double? value,
            bool Function(double) test, String detail) =>
        value == null
            ? SuperGtCheck(
                key: key,
                label: label,
                state: SuperGtCheckState.unconfirmed,
                message: t('Not entered ($detail)', '未入力（$detail）'),
              )
            : numeric(
                key,
                label,
                test(value),
                t('$detail / measured ${_format(value)}',
                    '$detail / 実測 ${_format(value)}'));

    SuperGtCheck confirmation(String key, String label) {
      final value = confirmations[key];
      return SuperGtCheck(
        key: key,
        label: label,
        state: value == null
            ? SuperGtCheckState.unconfirmed
            : (value ? SuperGtCheckState.pass : SuperGtCheckState.fail),
        message: value == null
            ? t('Unchecked', '未確認')
            : (value
                ? t('Within spec (confirmed)', '条件内（確認済み）')
                : t('Out of spec', '条件外')),
      );
    }

    final ratioLimit = rules.minimumFinalDriveRatio;
    final rpmLimit = rules.maxTireRpm;
    final rpmDifference = _format((rpmLimit - tireRpm).abs());
    final tireMargin = tireRpm <= rpmLimit
        ? t('headroom $rpmDifference rpm', '余裕 $rpmDifference rpm')
        : t('over by $rpmDifference rpm', '超過 $rpmDifference rpm');
    final carMinimum = rules.minCarWeightGrams;
    final bodyMinimum = rules.minBodyWeightGrams;
    final voltageRange = '${rules.minVoltage}–${rules.maxVoltage}';
    return [
      numeric(
        'finalDriveRatio',
        t('Final drive ratio', '最終減速比'),
        finalDriveRatio >= ratioLimit,
        t('Min. $ratioLimit (${margin(finalDriveRatio - ratioLimit)})',
            '基準 $ratioLimit（${margin(finalDriveRatio - ratioLimit)}）'),
      ),
      numeric(
        'tireRpm',
        t('Tire speed', 'タイヤ回転数'),
        tireRpm <= rpmLimit,
        t('Max. $rpmLimit rpm ($tireMargin)', '上限 ${rpmLimit}rpm（$tireMargin）'),
      ),
      optional(
        'carWeightGrams',
        t('Car weight', '車重'),
        carWeightGrams,
        (v) => v >= carMinimum,
        t('Min. $carMinimum g ${weightMargin(carWeightGrams, carMinimum)}',
            '下限 ${carMinimum}g ${weightMargin(carWeightGrams, carMinimum)}'),
      ),
      optional(
        'bodyWeightGrams',
        t('Body weight', 'ボディ重量'),
        bodyWeightGrams,
        (v) => v >= bodyMinimum,
        t('Min. $bodyMinimum g ${weightMargin(bodyWeightGrams, bodyMinimum)}',
            '下限 ${bodyMinimum}g ${weightMargin(bodyWeightGrams, bodyMinimum)}'),
      ),
      optional(
        'batteryVoltage',
        t('Battery voltage', 'バッテリー電圧'),
        batteryVoltage,
        (v) => v >= rules.minVoltage && v <= rules.maxVoltage,
        t('Range $voltageRange V', '範囲 ${voltageRange}V'),
      ),
      confirmation('powerSource', t('Motor / ESC', 'モーター／ESC')),
      confirmation('body', t('Body', 'ボディ')),
      confirmation('tires', t('Tires', 'タイヤ')),
      confirmation('prohibitedTreatments', t('Prohibited treatments', '禁止処理')),
    ];
  }

  bool get hasFailures => checks.any((c) => c.state == SuperGtCheckState.fail);
  bool get hasUnconfirmed =>
      checks.any((c) => c.state == SuperGtCheckState.unconfirmed);

  Map<String, dynamic> toJson() => {
        'measuredAt': measuredAt.toIso8601String(),
        'rules': rules.toJson(),
        'finalDriveRatio': finalDriveRatio,
        'tireRpm': tireRpm,
        'carWeightGrams': carWeightGrams,
        'bodyWeightGrams': bodyWeightGrams,
        'batteryVoltage': batteryVoltage,
        'motorName': motorName,
        'memo': memo,
        'confirmations': confirmations
      };
  factory SuperGtMeasurement.fromJson(Map<String, dynamic> json) {
    try {
      final date = DateTime.parse(_string(json, 'measuredAt'));
      final c = json['confirmations'];
      if (c is! Map) {
        throw StateError('confirmations');
      }
      final confirmations = <String, bool>{};
      for (final e in c.entries) {
        if (e.key is! String || e.value is! bool) {
          throw StateError('confirmations');
        }
        confirmations[e.key as String] = e.value as bool;
      }
      return SuperGtMeasurement(
          measuredAt: date,
          rules: SuperGtRuleProfile.fromJson(_map(json, 'rules')),
          finalDriveRatio: _finite(json, 'finalDriveRatio'),
          tireRpm: _finite(json, 'tireRpm'),
          carWeightGrams: _nullableFinite(json, 'carWeightGrams'),
          bodyWeightGrams: _nullableFinite(json, 'bodyWeightGrams'),
          batteryVoltage: _nullableFinite(json, 'batteryVoltage'),
          motorName: _string(json, 'motorName'),
          memo: _string(json, 'memo'),
          confirmations: confirmations);
    } catch (e) {
      if (e is FormatException) rethrow;
      throw FormatException('Invalid SuperGtMeasurement JSON', json.toString());
    }
  }
  static SuperGtMeasurement? fromSettings(Map<String, dynamic> settings) {
    try {
      final value = settings[settingKey];
      if (value == null) {
        return null;
      }
      if (value is! Map) {
        throw const FormatException('Invalid superGtMeasurement setting');
      }
      return SuperGtMeasurement.fromJson(Map<String, dynamic>.from(value));
    } catch (e) {
      if (e is FormatException) {
        rethrow;
      }
      throw FormatException('Invalid superGtMeasurement setting', e.toString());
    }
  }
}

String _string(Map json, String key) {
  final v = json[key];
  if (v is! String) {
    throw StateError(key);
  }
  return v;
}

Map<String, dynamic> _map(Map json, String key) {
  final v = json[key];
  if (v is! Map) {
    throw StateError(key);
  }
  return Map<String, dynamic>.from(v);
}

double _finite(Map json, String key) {
  final v = json[key];
  if (v is! num || !v.isFinite) {
    throw StateError(key);
  }
  return v.toDouble();
}

double? _nullableFinite(Map json, String key) {
  final v = json[key];
  if (v == null) {
    return null;
  }
  if (v is! num || !v.isFinite) {
    throw StateError(key);
  }
  return v.toDouble();
}

double _positive(double value, String name) {
  if (!value.isFinite || value <= 0) {
    throw ArgumentError.value(value, name);
  }
  return value;
}

void _optionalPositive(double? value, String name) {
  if (value != null) _positive(value, name);
}

void _positiveInteger(double value, String name) {
  _positive(value, name);
  if (value != value.roundToDouble()) {
    throw ArgumentError.value(value, name, 'Must be an integer.');
  }
}

String _format(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  if (value.abs() < 0.01) {
    return value.toStringAsFixed(6);
  }
  return value.toStringAsFixed(2);
}
