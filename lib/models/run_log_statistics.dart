import 'run_log.dart';

class RunLogStatistics {
  final int totalRuns;
  final int timedRuns;
  final int runsLast30Days;
  final DateTime? latestRunAt;
  final RunLog? bestRun;
  final int averageBestLapMillis;
  final List<RunLog> fastestRuns;
  final List<CarRunPerformance> carPerformance;
  final List<SettingRunPerformance> settingPerformance;
  final List<FeelTagRunPerformance> feelTagPerformance;
  final List<ChangeRunPerformance> changePerformance;

  const RunLogStatistics({
    required this.totalRuns,
    required this.timedRuns,
    required this.runsLast30Days,
    required this.latestRunAt,
    required this.bestRun,
    required this.averageBestLapMillis,
    required this.fastestRuns,
    required this.carPerformance,
    required this.settingPerformance,
    required this.feelTagPerformance,
    required this.changePerformance,
  });

  factory RunLogStatistics.fromRunLogs(
    List<RunLog> runLogs, {
    DateTime? now,
    int recentDays = 30,
    int fastestLimit = 5,
    int rankingLimit = 8,
  }) {
    final referenceTime = now ?? DateTime.now();
    final recentCutoff = referenceTime.subtract(Duration(days: recentDays));
    final timedLogs =
        runLogs.where((runLog) => runLog.bestLapMillis > 0).toList();

    DateTime? latestRunAt;
    var recentCount = 0;
    for (final runLog in runLogs) {
      if (latestRunAt == null || runLog.runAt.isAfter(latestRunAt)) {
        latestRunAt = runLog.runAt;
      }
      if (!runLog.runAt.isBefore(recentCutoff)) {
        recentCount += 1;
      }
    }

    timedLogs.sort((a, b) {
      final lapComparison = a.bestLapMillis.compareTo(b.bestLapMillis);
      if (lapComparison != 0) {
        return lapComparison;
      }
      return b.runAt.compareTo(a.runAt);
    });

    final averageBestLapMillis = timedLogs.isEmpty
        ? 0
        : (timedLogs.fold<int>(
                  0,
                  (sum, runLog) => sum + runLog.bestLapMillis,
                ) /
                timedLogs.length)
            .round();

    final carBuckets = <String, _MutableCarRunBucket>{};
    final settingBuckets = <String, _MutableSettingRunBucket>{};
    final feelTagBuckets = <String, _MutableFeelTagRunBucket>{};
    final changeBuckets = <String, _MutableChangeRunBucket>{};

    for (final runLog in timedLogs) {
      final carBucket = carBuckets.putIfAbsent(
        runLog.car.id,
        () => _MutableCarRunBucket(
          carId: runLog.car.id,
          carName: runLog.car.name,
          manufacturerName: runLog.car.manufacturer.name,
        ),
      );
      carBucket.add(runLog);

      final settingKey = _settingBucketKey(runLog);
      final settingName = _settingBucketName(runLog);
      if (settingKey != null && settingName != null) {
        final settingBucket = settingBuckets.putIfAbsent(
          settingKey,
          () => _MutableSettingRunBucket(
            settingId: _settingBucketId(runLog),
            settingName: settingName,
            carName: runLog.car.name,
            isResultSetting: runLog.resultSettingId != null,
          ),
        );
        settingBucket.add(runLog);
      }

      for (final tagId in runLog.feelTagIds.toSet()) {
        final tagBucket = feelTagBuckets.putIfAbsent(
          tagId,
          () => _MutableFeelTagRunBucket(tagId: tagId),
        );
        tagBucket.add(runLog);
      }

      for (final change in runLog.changes) {
        if (change.settingKey.trim().isEmpty) {
          continue;
        }
        final changeKey = change.settingKey;
        final changeBucket = changeBuckets.putIfAbsent(
          changeKey,
          () => _MutableChangeRunBucket(
            settingKey: change.settingKey,
            settingLabel: change.settingLabel.isEmpty
                ? change.settingKey
                : change.settingLabel,
          ),
        );
        changeBucket.add(runLog, change);
      }
    }

    return RunLogStatistics(
      totalRuns: runLogs.length,
      timedRuns: timedLogs.length,
      runsLast30Days: recentCount,
      latestRunAt: latestRunAt,
      bestRun: timedLogs.isEmpty ? null : timedLogs.first,
      averageBestLapMillis: averageBestLapMillis,
      fastestRuns: timedLogs.take(fastestLimit).toList(),
      carPerformance: _rankPerformance(
        carBuckets.values.map((bucket) => bucket.toPerformance()).toList(),
      ).take(rankingLimit).toList(),
      settingPerformance: _rankPerformance(
        settingBuckets.values.map((bucket) => bucket.toPerformance()).toList(),
      ).take(rankingLimit).toList(),
      feelTagPerformance: _rankPerformance(
        feelTagBuckets.values.map((bucket) => bucket.toPerformance()).toList(),
      ).take(rankingLimit).toList(),
      changePerformance: _rankPerformance(
        changeBuckets.values.map((bucket) => bucket.toPerformance()).toList(),
      ).take(rankingLimit).toList(),
    );
  }

  static String? _settingBucketId(RunLog runLog) {
    return runLog.resultSettingId ?? runLog.baseSettingId;
  }

  static String? _settingBucketName(RunLog runLog) {
    return runLog.resultSettingName ?? runLog.baseSettingName;
  }

  static String? _settingBucketKey(RunLog runLog) {
    final settingId = _settingBucketId(runLog);
    if (settingId != null && settingId.isNotEmpty) {
      return settingId;
    }

    final settingName = _settingBucketName(runLog);
    if (settingName != null && settingName.isNotEmpty) {
      return '${runLog.car.id}:$settingName';
    }

    return null;
  }

  static List<T> _rankPerformance<T extends RunPerformanceBase>(List<T> items) {
    items.sort((a, b) {
      final bestComparison = a.bestLapMillis.compareTo(b.bestLapMillis);
      if (bestComparison != 0) {
        return bestComparison;
      }

      final averageComparison =
          a.averageLapMillis.compareTo(b.averageLapMillis);
      if (averageComparison != 0) {
        return averageComparison;
      }

      final countComparison = b.runCount.compareTo(a.runCount);
      if (countComparison != 0) {
        return countComparison;
      }

      return b.lastRunAt.compareTo(a.lastRunAt);
    });
    return items;
  }
}

abstract class RunPerformanceBase {
  int get runCount;
  int get bestLapMillis;
  int get averageLapMillis;
  DateTime get lastRunAt;
}

class CarRunPerformance implements RunPerformanceBase {
  final String carId;
  final String carName;
  final String manufacturerName;
  @override
  final int runCount;
  @override
  final int bestLapMillis;
  @override
  final int averageLapMillis;
  @override
  final DateTime lastRunAt;

  const CarRunPerformance({
    required this.carId,
    required this.carName,
    required this.manufacturerName,
    required this.runCount,
    required this.bestLapMillis,
    required this.averageLapMillis,
    required this.lastRunAt,
  });
}

class SettingRunPerformance implements RunPerformanceBase {
  final String? settingId;
  final String settingName;
  final String carName;
  final bool isResultSetting;
  @override
  final int runCount;
  @override
  final int bestLapMillis;
  @override
  final int averageLapMillis;
  @override
  final DateTime lastRunAt;

  const SettingRunPerformance({
    required this.settingId,
    required this.settingName,
    required this.carName,
    required this.isResultSetting,
    required this.runCount,
    required this.bestLapMillis,
    required this.averageLapMillis,
    required this.lastRunAt,
  });
}

class FeelTagRunPerformance implements RunPerformanceBase {
  final String tagId;
  @override
  final int runCount;
  @override
  final int bestLapMillis;
  @override
  final int averageLapMillis;
  @override
  final DateTime lastRunAt;

  const FeelTagRunPerformance({
    required this.tagId,
    required this.runCount,
    required this.bestLapMillis,
    required this.averageLapMillis,
    required this.lastRunAt,
  });
}

class ChangeRunPerformance implements RunPerformanceBase {
  final String settingKey;
  final String settingLabel;
  final dynamic fastestAfterValue;
  @override
  final int runCount;
  @override
  final int bestLapMillis;
  @override
  final int averageLapMillis;
  @override
  final DateTime lastRunAt;

  const ChangeRunPerformance({
    required this.settingKey,
    required this.settingLabel,
    required this.fastestAfterValue,
    required this.runCount,
    required this.bestLapMillis,
    required this.averageLapMillis,
    required this.lastRunAt,
  });
}

class _MutableRunBucket {
  int runCount = 0;
  int totalLapMillis = 0;
  int? bestLapMillis;
  DateTime? lastRunAt;

  void addRun(RunLog runLog) {
    runCount += 1;
    totalLapMillis += runLog.bestLapMillis;
    if (bestLapMillis == null || runLog.bestLapMillis < bestLapMillis!) {
      bestLapMillis = runLog.bestLapMillis;
    }
    if (lastRunAt == null || runLog.runAt.isAfter(lastRunAt!)) {
      lastRunAt = runLog.runAt;
    }
  }

  int get averageLapMillis =>
      runCount == 0 ? 0 : (totalLapMillis / runCount).round();
}

class _MutableCarRunBucket extends _MutableRunBucket {
  final String carId;
  final String carName;
  final String manufacturerName;

  _MutableCarRunBucket({
    required this.carId,
    required this.carName,
    required this.manufacturerName,
  });

  void add(RunLog runLog) => addRun(runLog);

  CarRunPerformance toPerformance() {
    return CarRunPerformance(
      carId: carId,
      carName: carName,
      manufacturerName: manufacturerName,
      runCount: runCount,
      bestLapMillis: bestLapMillis ?? 0,
      averageLapMillis: averageLapMillis,
      lastRunAt: lastRunAt ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class _MutableSettingRunBucket extends _MutableRunBucket {
  final String? settingId;
  final String settingName;
  final String carName;
  final bool isResultSetting;

  _MutableSettingRunBucket({
    required this.settingId,
    required this.settingName,
    required this.carName,
    required this.isResultSetting,
  });

  void add(RunLog runLog) => addRun(runLog);

  SettingRunPerformance toPerformance() {
    return SettingRunPerformance(
      settingId: settingId,
      settingName: settingName,
      carName: carName,
      isResultSetting: isResultSetting,
      runCount: runCount,
      bestLapMillis: bestLapMillis ?? 0,
      averageLapMillis: averageLapMillis,
      lastRunAt: lastRunAt ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class _MutableFeelTagRunBucket extends _MutableRunBucket {
  final String tagId;

  _MutableFeelTagRunBucket({required this.tagId});

  void add(RunLog runLog) => addRun(runLog);

  FeelTagRunPerformance toPerformance() {
    return FeelTagRunPerformance(
      tagId: tagId,
      runCount: runCount,
      bestLapMillis: bestLapMillis ?? 0,
      averageLapMillis: averageLapMillis,
      lastRunAt: lastRunAt ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class _MutableChangeRunBucket extends _MutableRunBucket {
  final String settingKey;
  final String settingLabel;
  dynamic fastestAfterValue;

  _MutableChangeRunBucket({
    required this.settingKey,
    required this.settingLabel,
  });

  void add(RunLog runLog, RunSettingChange change) {
    if (bestLapMillis == null || runLog.bestLapMillis < bestLapMillis!) {
      fastestAfterValue = change.afterValue;
    }
    addRun(runLog);
  }

  ChangeRunPerformance toPerformance() {
    return ChangeRunPerformance(
      settingKey: settingKey,
      settingLabel: settingLabel,
      fastestAfterValue: fastestAfterValue,
      runCount: runCount,
      bestLapMillis: bestLapMillis ?? 0,
      averageLapMillis: averageLapMillis,
      lastRunAt: lastRunAt ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
