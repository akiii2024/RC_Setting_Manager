import 'package:flutter_test/flutter_test.dart';
import 'package:rc_setting_manager/models/car.dart';
import 'package:rc_setting_manager/models/manufacturer.dart';
import 'package:rc_setting_manager/models/run_log.dart';
import 'package:rc_setting_manager/models/run_log_statistics.dart';

void main() {
  group('RunLogStatistics', () {
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

    test('returns empty aggregates when there are no run logs', () {
      final statistics = RunLogStatistics.fromRunLogs(
        const [],
        now: DateTime(2026, 6, 20),
      );

      expect(statistics.totalRuns, 0);
      expect(statistics.timedRuns, 0);
      expect(statistics.bestRun, isNull);
      expect(statistics.averageBestLapMillis, 0);
      expect(statistics.carPerformance, isEmpty);
      expect(statistics.settingPerformance, isEmpty);
      expect(statistics.changePerformance, isEmpty);
    });

    test('aggregates fastest runs and performance buckets', () {
      final logs = [
        RunLog(
          id: 'run-1',
          createdAt: DateTime(2026, 6, 10, 9),
          runAt: DateTime(2026, 6, 10, 10),
          car: trf421,
          baseSettingId: 'base-1',
          baseSettingName: 'Base',
          resultSettingId: 'result-1',
          resultSettingName: 'Fast setup',
          bestLapMillis: 13520,
          feelTagIds: const ['stable'],
          memo: '',
          changes: const [
            RunSettingChange(
              settingKey: 'frontCamber',
              settingLabel: 'Front Camber',
              beforeValue: 1.0,
              afterValue: 1.5,
            ),
          ],
        ),
        RunLog(
          id: 'run-2',
          createdAt: DateTime(2026, 6, 12, 9),
          runAt: DateTime(2026, 6, 12, 10),
          car: trf421,
          baseSettingId: 'base-1',
          baseSettingName: 'Base',
          resultSettingId: 'result-2',
          resultSettingName: 'Faster setup',
          bestLapMillis: 13200,
          feelTagIds: const ['stable', 'turns_well'],
          memo: '',
          changes: const [
            RunSettingChange(
              settingKey: 'frontCamber',
              settingLabel: 'Front Camber',
              beforeValue: 1.0,
              afterValue: 2.0,
            ),
          ],
        ),
        RunLog(
          id: 'run-3',
          createdAt: DateTime(2026, 5, 1, 9),
          runAt: DateTime(2026, 5, 1, 10),
          car: bd12,
          baseSettingId: 'base-2',
          baseSettingName: 'BD base',
          bestLapMillis: 14100,
          feelTagIds: const ['push'],
          memo: '',
          changes: const [],
        ),
        RunLog(
          id: 'run-4',
          createdAt: DateTime(2026, 6, 13, 9),
          runAt: DateTime(2026, 6, 13, 10),
          car: trf421,
          bestLapMillis: 0,
          feelTagIds: const ['spin'],
          memo: '',
          changes: const [],
        ),
      ];

      final statistics = RunLogStatistics.fromRunLogs(
        logs,
        now: DateTime(2026, 6, 20),
      );

      expect(statistics.totalRuns, 4);
      expect(statistics.timedRuns, 3);
      expect(statistics.runsLast30Days, 3);
      expect(statistics.bestRun?.id, 'run-2');
      expect(statistics.averageBestLapMillis, 13607);
      expect(statistics.fastestRuns.map((runLog) => runLog.id), [
        'run-2',
        'run-1',
        'run-3',
      ]);
      expect(statistics.carPerformance.first.carName, 'TRF421');
      expect(statistics.carPerformance.first.bestLapMillis, 13200);
      expect(statistics.settingPerformance.first.settingName, 'Faster setup');
      expect(statistics.feelTagPerformance.first.tagId, 'turns_well');
      expect(statistics.changePerformance.first.settingKey, 'frontCamber');
      expect(statistics.changePerformance.first.fastestAfterValue, 2.0);
    });
  });
}
