import 'package:flutter_test/flutter_test.dart';
import 'package:rc_setting_manager/models/car.dart';
import 'package:rc_setting_manager/models/manufacturer.dart';
import 'package:rc_setting_manager/models/saved_setting.dart';
import 'package:rc_setting_manager/models/setting_statistics.dart';

void main() {
  group('SettingStatistics', () {
    final tamiya = Manufacturer(
      id: 'tamiya',
      name: 'Tamiya',
      logoPath: '',
    );
    final yokomo = Manufacturer(
      id: 'yokomo',
      name: 'Yokomo',
      logoPath: '',
    );
    final trf421 = Car(
      id: 'tamiya/trf421',
      name: 'TRF421',
      imageUrl: '',
      manufacturer: tamiya,
      category: 'touring',
    );
    final bd12 = Car(
      id: 'yokomo/bd12',
      name: 'BD12',
      imageUrl: '',
      manufacturer: yokomo,
      category: 'touring',
    );

    test('returns empty aggregates when there is no history', () {
      final now = DateTime(2026, 3, 24, 12);
      final statistics = SettingStatistics.fromSavedSettings(
        const [],
        totalRegisteredCars: 3,
        now: now,
      );

      expect(statistics.totalSettings, 0);
      expect(statistics.activeCars, 0);
      expect(statistics.totalRegisteredCars, 3);
      expect(statistics.settingsLast30Days, 0);
      expect(statistics.topCar, isNull);
      expect(statistics.topManufacturer, isNull);
      expect(statistics.monthlyActivity, hasLength(6));
      expect(
        statistics.monthlyActivity.every((item) => item.count == 0),
        isTrue,
      );
    });

    test('aggregates car, manufacturer, and monthly usage', () {
      final now = DateTime(2026, 3, 24, 12);
      final savedSettings = [
        SavedSetting(
          id: '1',
          name: 'March race',
          createdAt: DateTime(2026, 3, 20, 10),
          car: trf421,
          settings: const {'camber': '2.0'},
        ),
        SavedSetting(
          id: '2',
          name: 'March practice',
          createdAt: DateTime(2026, 3, 5, 20),
          car: trf421,
          settings: const {'camber': '1.5'},
        ),
        SavedSetting(
          id: '3',
          name: 'February setup',
          createdAt: DateTime(2026, 2, 10, 9),
          car: trf421,
          settings: const {'camber': '1.0'},
        ),
        SavedSetting(
          id: '4',
          name: 'January setup',
          createdAt: DateTime(2026, 1, 15, 14),
          car: bd12,
          settings: const {'camber': '0.5'},
        ),
      ];

      final statistics = SettingStatistics.fromSavedSettings(
        savedSettings,
        totalRegisteredCars: 5,
        now: now,
      );

      expect(statistics.totalSettings, 4);
      expect(statistics.activeCars, 2);
      expect(statistics.settingsLast30Days, 2);
      expect(statistics.averageSettingsPerCar, 2);
      expect(statistics.topCar?.carName, 'TRF421');
      expect(statistics.topCar?.count, 3);
      expect(statistics.topManufacturer?.manufacturerName, 'Tamiya');
      expect(statistics.topManufacturer?.count, 3);
      expect(statistics.latestActivity, DateTime(2026, 3, 20, 10));
      expect(statistics.recentActivity.first.name, 'March race');
      expect(statistics.monthlyActivity.map((item) => item.count).toList(), [
        0,
        0,
        0,
        1,
        1,
        2,
      ]);
    });
  });
}
