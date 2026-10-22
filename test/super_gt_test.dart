import 'package:flutter_test/flutter_test.dart';
import 'package:rc_setting_manager/models/super_gt.dart';

void main() {
  const confirmed = {
    'powerSource': true,
    'body': true,
    'tires': true,
    'prohibitedTreatments': true,
  };

  for (final power in SuperGtPowerSource.values) {
    for (final group in SuperGtBodyGroup.values) {
      test('${power.name}/${group.name}の下限・上限は条件内', () {
        final rules = SuperGtRuleProfile.for4wd(power, group);
        expect(rules.maxTireRpm,
            power == SuperGtPowerSource.hobbywing ? 4000 : 3800);
        expect(
            rules.minCarWeightGrams, group == SuperGtBodyGroup.a ? 1220 : 1300);
        for (final voltage in [8.3, 8.4]) {
          final measurement = SuperGtMeasurement(
            measuredAt: DateTime.utc(2026),
            rules: rules,
            finalDriveRatio: 5.3,
            tireRpm: rules.maxTireRpm,
            carWeightGrams: rules.minCarWeightGrams,
            bodyWeightGrams: 80,
            batteryVoltage: voltage,
            confirmations: confirmed,
          );
          expect(
              measurement.checks
                  .every((item) => item.state == SuperGtCheckState.pass),
              isTrue);
        }
      });
    }
  }

  test('境界を僅かでも外れた値と未確認・条件外を区別する', () {
    for (final voltage in [8.299999, 8.400001]) {
      final measurement = SuperGtMeasurement(
        measuredAt: DateTime.utc(2026),
        rules: SuperGtRuleProfile.hobbywingA,
        finalDriveRatio: 5.299999,
        tireRpm: 4000.000001,
        carWeightGrams: 1219.999999,
        bodyWeightGrams: 79.999999,
        batteryVoltage: voltage,
        confirmations: const {'powerSource': false},
      );
      expect(
          measurement.checks
              .take(6)
              .every((item) => item.state == SuperGtCheckState.fail),
          isTrue);
      expect(measurement.checks.last.state, SuperGtCheckState.unconfirmed);
      expect(measurement.checks[1].message, contains('超過'));
      expect(measurement.checks[2].message, contains('不足'));
    }
  });

  test('数値計算で無効値と計算結果のoverflow/underflowを拒否する', () {
    for (final value in [0.0, -1.0, double.nan, double.infinity]) {
      expect(
          () => SuperGtDriveMath.inferredMotorRpm(
              tireRpm: value, finalDriveRatio: 5.3),
          throwsArgumentError);
      expect(
          () => SuperGtDriveMath.predictedTireRpm(
              motorRpm: 21200, finalDriveRatio: value),
          throwsArgumentError);
      expect(
          () => SuperGtDriveMath.finalDriveRatio(
              spurTeeth: 100, pinionTeeth: value, internalRatio: 2),
          throwsArgumentError);
    }
    expect(
        () => SuperGtDriveMath.inferredMotorRpm(
            tireRpm: 1e308, finalDriveRatio: 5.3),
        throwsArgumentError);
    expect(
        () => SuperGtDriveMath.inferredMotorRpm(
            tireRpm: 1e-300, finalDriveRatio: 1e-300),
        throwsArgumentError);
    expect(
        () => SuperGtDriveMath.predictedTireRpm(
            motorRpm: 21200, finalDriveRatio: 1e-310),
        throwsArgumentError);
    expect(
        () => SuperGtMeasurement.fromJson(
            {...SuperGtMeasurementTestData.valid, 'tireRpm': 1e308}),
        throwsFormatException);
  });

  test('保存された規則の条件は現在のプリセットで置き換えない', () {
    final json = SuperGtMeasurementTestData.valid;
    final oldRules = {
      ...SuperGtRuleProfile.hobbywingA.toJson(),
      'maxTireRpm': 3900.0
    };
    final restored = SuperGtMeasurement.fromJson({...json, 'rules': oldRules});
    expect(restored.rules.maxTireRpm, 3900);
    expect(restored.hasFailures, isTrue);
    expect(SuperGtRuleProfile.hobbywingA.maxTireRpm, 4000);
  });

  test('壊れた規則・確認項目・測定日時を復元しない', () {
    final valid = SuperGtMeasurementTestData.valid;
    for (final patch in <Map<String, dynamic>>[
      {'measuredAt': 'invalid'},
      {
        'rules': {...SuperGtRuleProfile.hobbywingA.toJson(), 'minVoltage': 9}
      },
      {
        'rules': {...SuperGtRuleProfile.hobbywingA.toJson(), 'maxTireRpm': -1}
      },
      {
        'confirmations': {'powerSource': 'true'}
      },
    ]) {
      expect(() => SuperGtMeasurement.fromJson({...valid, ...patch}),
          throwsFormatException);
    }
    expect(
        () => SuperGtMeasurement.fromSettings({
              SuperGtMeasurement.settingKey: {1: 'bad'}
            }),
        throwsFormatException);
  });

  test('4WDプリセットと回転数計算', () {
    final rules = SuperGtRuleProfile.for4wd(
        SuperGtPowerSource.hobbywing, SuperGtBodyGroup.a);
    expect(rules.maxTireRpm, 4000);
    expect(
        SuperGtDriveMath.finalDriveRatio(
            spurTeeth: 55, pinionTeeth: 25, internalRatio: 2.4),
        5.28);
    expect(
        SuperGtDriveMath.inferredMotorRpm(tireRpm: 4000, finalDriveRatio: 5.3),
        21200);
    expect(
        SuperGtDriveMath.predictedTireRpm(
            motorRpm: 21200, finalDriveRatio: 5.5),
        closeTo(3854.54545, 0.00001));
  });

  test('測定値のチェックと未入力', () {
    final measurement = SuperGtMeasurement(
      measuredAt: DateTime.utc(2026, 8, 10),
      rules: SuperGtRuleProfile.hobbywingA,
      finalDriveRatio: 5.2,
      tireRpm: 4001,
    );
    expect(measurement.hasFailures, isTrue);
    expect(measurement.hasUnconfirmed, isTrue);
    expect(measurement.checks.first.message, contains('不足'));
    expect(measurement.checks[2].state, SuperGtCheckState.unconfirmed);
  });

  test('JSON roundtrip preserves rule snapshot', () {
    final original = SuperGtMeasurement(
        measuredAt: DateTime.utc(2026, 8, 10, 1, 2),
        rules: SuperGtRuleProfile.yokomoB,
        finalDriveRatio: 5.5,
        tireRpm: 3500,
        carWeightGrams: 1300,
        bodyWeightGrams: 80,
        batteryVoltage: 8.4,
        motorName: 'Test',
        memo: 'memo',
        confirmations: const {
          'powerSource': true,
          'body': true,
          'tires': true,
          'prohibitedTreatments': true
        });
    final restored = SuperGtMeasurement.fromJson(original.toJson());
    expect(restored.rules.maxTireRpm, 3800);
    expect(restored.toJson(), original.toJson());
    expect(SuperGtMeasurement.fromSettings(const {}).toString(), 'null');
  });

  test('不正値を拒否する', () {
    expect(
        () => SuperGtDriveMath.finalDriveRatio(
            spurTeeth: 55.5, pinionTeeth: 25, internalRatio: 2.4),
        throwsArgumentError);
    expect(
        () => SuperGtDriveMath.predictedTireRpm(
            motorRpm: 0, finalDriveRatio: 5.3),
        throwsArgumentError);
    expect(
        () => SuperGtMeasurement.fromJson(
            {...SuperGtMeasurementTestData.valid, 'tireRpm': double.infinity}),
        throwsFormatException);
    expect(
        () => SuperGtMeasurement.fromSettings({'superGtMeasurement': 'broken'}),
        throwsFormatException);
  });
}

class SuperGtMeasurementTestData {
  static final valid = SuperGtMeasurement(
          measuredAt: DateTime.utc(2026),
          rules: SuperGtRuleProfile.hobbywingA,
          finalDriveRatio: 5.3,
          tireRpm: 4000)
      .toJson();
}
