import 'package:flutter_test/flutter_test.dart';
import 'package:rc_setting_manager/models/ai_advisor.dart';
import 'package:rc_setting_manager/models/car.dart';
import 'package:rc_setting_manager/models/car_setting_definition.dart';
import 'package:rc_setting_manager/models/manufacturer.dart';
import 'package:rc_setting_manager/models/run_log.dart';
import 'package:rc_setting_manager/models/track_location.dart';
import 'package:rc_setting_manager/services/ai_advisor_context_builder.dart';

void main() {
  final manufacturer = Manufacturer(
    id: 'test',
    name: 'Test',
    logoPath: '',
  );
  final car = Car(
    id: 'car-1',
    name: 'Test car',
    imageUrl: '',
    manufacturer: manufacturer,
    category: 'touring',
  );
  final otherCar = Car(
    id: 'car-2',
    name: 'Other car',
    imageUrl: '',
    manufacturer: manufacturer,
    category: 'touring',
  );
  final definition = CarSettingDefinition(
    carId: car.id,
    isHumanVerified: true,
    availableSettings: [
      SettingItem(
        key: 'frontCamber',
        type: 'number',
        constraints: const {'min': -5, 'max': 5, 'step': 0.5},
        unit: '°',
        category: 'front',
        label: 'フロント キャンバー',
        defaultValue: '-1',
      ),
      SettingItem(
        key: 'frontSpring',
        type: 'text',
        category: 'frontDamper',
        label: 'フロント スプリング',
      ),
      SettingItem(
        key: 'memo',
        type: 'text',
        category: 'memo',
        label: 'メモ',
      ),
    ],
  );
  final track = TrackLocation(
    name: 'Alpha Circuit',
    latitude: 0,
    longitude: 0,
    radius: 100,
    prefecture: 'Tokyo',
    address: '',
    type: 'indoor',
    surfaceType: 'carpet',
  );

  test('builds grounded context and keeps only related run logs', () {
    final runs = [
      RunLog(
        id: 'linked',
        createdAt: DateTime(2026, 1, 1),
        runAt: DateTime(2026, 1, 1),
        car: car,
        trackName: 'Other Circuit',
        baseSettingId: 'setting-1',
        bestLapMillis: 12000,
        feelTagIds: const ['push'],
        memo: 'Entry push',
        changes: const [],
      ),
      RunLog(
        id: 'same-track',
        createdAt: DateTime(2026, 1, 2),
        runAt: DateTime(2026, 1, 2),
        car: car,
        trackName: 'Alpha Circuit',
        bestLapMillis: 11800,
        feelTagIds: const ['stable'],
        memo: '',
        changes: const [],
      ),
      RunLog(
        id: 'other-car',
        createdAt: DateTime(2026, 1, 3),
        runAt: DateTime(2026, 1, 3),
        car: otherCar,
        trackName: 'Alpha Circuit',
        bestLapMillis: 11000,
        feelTagIds: const ['stable'],
        memo: '',
        changes: const [],
      ),
    ];

    final context = AIAdvisorContextBuilder.build(
      car: car,
      settingName: 'Base',
      currentSettings: const {
        'frontCamber': -1.0,
        'frontSpring': 'Test spring',
        'memo': 'Current note',
      },
      initialSettings: const {
        'frontCamber': -1.0,
        'frontSpring': '',
      },
      settingDefinition: definition,
      runLogs: runs,
      isSavedSetting: false,
      isEnglish: false,
      activeSettingId: 'setting-1',
      track: track,
    );

    expect(context.relatedRuns, hasLength(2));
    expect(context.relatedRuns.first['trackName'], 'Other Circuit');
    expect(context.relatedRuns.last['trackName'], 'Alpha Circuit');
    expect(context.settingMemo, 'Current note');
    expect(
      context.settings.firstWhere(
        (item) => item['key'] == 'frontCamber',
      )['source'],
      'default',
    );
    expect(
      context.settings.firstWhere(
        (item) => item['key'] == 'frontSpring',
      )['source'],
      'entered',
    );
    expect(
      context.settingCatalog.firstWhere(
        (item) => item['key'] == 'frontCamber',
      )['autoApplicable'],
      isTrue,
    );
    expect(
      context.settingCatalog.firstWhere(
        (item) => item['key'] == 'frontSpring',
      )['autoApplicable'],
      isFalse,
    );
  });

  test('accepts one numeric step and rejects unsafe changes', () {
    dynamic validate(String key, String proposed) {
      return AIAdvisorContextBuilder.validatedProposedValue(
        change: AdvisorSettingChange(
          settingKey: key,
          settingLabel: key,
          currentValue: '-1',
          proposedValue: proposed,
          reason: '',
          expectedEffect: '',
          tradeoff: '',
          priority: 1,
        ),
        settingDefinition: definition,
        currentSettings: const {
          'frontCamber': -1.0,
          'frontSpring': 'Test spring',
        },
      );
    }

    expect(validate('frontCamber', '-1.5'), -1.5);
    expect(validate('frontCamber', '-2.0'), isNull);
    expect(validate('frontCamber', '99'), isNull);
    expect(validate('frontCamber', 'NaN'), isNull);
    expect(validate('frontCamber', 'Infinity'), isNull);
    expect(validate('frontSpring', 'Hard'), isNull);
    expect(validate('unknown', '0'), isNull);

    expect(
      AIAdvisorContextBuilder.validatedProposedValue(
        change: const AdvisorSettingChange(
          settingKey: 'frontCamber',
          settingLabel: 'frontCamber',
          currentValue: 'NaN',
          proposedValue: '-1.5',
          reason: '',
          expectedEffect: '',
          tradeoff: '',
          priority: 1,
        ),
        settingDefinition: definition,
        currentSettings: const {'frontCamber': double.nan},
      ),
      isNull,
    );
  });
}
