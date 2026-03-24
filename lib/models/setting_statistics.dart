import 'saved_setting.dart';

class SettingStatistics {
  final int totalSettings;
  final int activeCars;
  final int totalRegisteredCars;
  final int settingsLast30Days;
  final double averageSettingsPerCar;
  final DateTime? latestActivity;
  final CarUsageStatistics? topCar;
  final ManufacturerUsageStatistics? topManufacturer;
  final List<CarUsageStatistics> carUsage;
  final List<ManufacturerUsageStatistics> manufacturerUsage;
  final List<MonthlyActivityStatistics> monthlyActivity;
  final List<SavedSetting> recentActivity;

  const SettingStatistics({
    required this.totalSettings,
    required this.activeCars,
    required this.totalRegisteredCars,
    required this.settingsLast30Days,
    required this.averageSettingsPerCar,
    required this.latestActivity,
    required this.topCar,
    required this.topManufacturer,
    required this.carUsage,
    required this.manufacturerUsage,
    required this.monthlyActivity,
    required this.recentActivity,
  });

  factory SettingStatistics.fromSavedSettings(
    List<SavedSetting> savedSettings, {
    required int totalRegisteredCars,
    DateTime? now,
    int recentDays = 30,
    int monthWindow = 6,
    int recentActivityLimit = 5,
  }) {
    final referenceTime = now ?? DateTime.now();
    final totalSettings = savedSettings.length;
    final recentCutoff = referenceTime.subtract(Duration(days: recentDays));

    final monthStarts = List<DateTime>.generate(monthWindow, (index) {
      final offset = monthWindow - index - 1;
      final month = DateTime(referenceTime.year, referenceTime.month - offset);
      return DateTime(month.year, month.month);
    });
    final monthBuckets = {
      for (final month in monthStarts) _monthKey(month): 0,
    };

    final carBuckets = <String, _MutableCarBucket>{};
    final manufacturerBuckets = <String, _MutableManufacturerBucket>{};

    int recentCount = 0;
    DateTime? latestActivity;

    for (final setting in savedSettings) {
      if (latestActivity == null || setting.createdAt.isAfter(latestActivity)) {
        latestActivity = setting.createdAt;
      }

      if (!setting.createdAt.isBefore(recentCutoff)) {
        recentCount += 1;
      }

      final monthKey =
          _monthKey(DateTime(setting.createdAt.year, setting.createdAt.month));
      if (monthBuckets.containsKey(monthKey)) {
        monthBuckets[monthKey] = monthBuckets[monthKey]! + 1;
      }

      final carBucket = carBuckets.putIfAbsent(
        setting.car.id,
        () => _MutableCarBucket(
          carId: setting.car.id,
          carName: setting.car.name,
          manufacturerName: setting.car.manufacturer.name,
          lastUsedAt: setting.createdAt,
        ),
      );
      carBucket.count += 1;
      if (setting.createdAt.isAfter(carBucket.lastUsedAt)) {
        carBucket.lastUsedAt = setting.createdAt;
      }

      final manufacturerKey = setting.car.manufacturer.id.isNotEmpty
          ? setting.car.manufacturer.id
          : setting.car.manufacturer.name;
      final manufacturerBucket = manufacturerBuckets.putIfAbsent(
        manufacturerKey,
        () => _MutableManufacturerBucket(
          manufacturerId: manufacturerKey,
          manufacturerName: setting.car.manufacturer.name,
          lastUsedAt: setting.createdAt,
        ),
      );
      manufacturerBucket.count += 1;
      if (setting.createdAt.isAfter(manufacturerBucket.lastUsedAt)) {
        manufacturerBucket.lastUsedAt = setting.createdAt;
      }
    }

    final carUsage = carBuckets.values
        .map(
          (bucket) => CarUsageStatistics(
            carId: bucket.carId,
            carName: bucket.carName,
            manufacturerName: bucket.manufacturerName,
            count: bucket.count,
            share: totalSettings == 0 ? 0 : bucket.count / totalSettings,
            lastUsedAt: bucket.lastUsedAt,
          ),
        )
        .toList()
      ..sort(_compareUsageCounts);

    final manufacturerUsage = manufacturerBuckets.values
        .map(
          (bucket) => ManufacturerUsageStatistics(
            manufacturerId: bucket.manufacturerId,
            manufacturerName: bucket.manufacturerName,
            count: bucket.count,
            share: totalSettings == 0 ? 0 : bucket.count / totalSettings,
            lastUsedAt: bucket.lastUsedAt,
          ),
        )
        .toList()
      ..sort(_compareUsageCounts);

    final monthlyActivity = monthStarts
        .map(
          (month) => MonthlyActivityStatistics(
            month: month,
            count: monthBuckets[_monthKey(month)] ?? 0,
          ),
        )
        .toList();

    final recentActivity = List<SavedSetting>.from(savedSettings)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final activeCars = carUsage.length;

    return SettingStatistics(
      totalSettings: totalSettings,
      activeCars: activeCars,
      totalRegisteredCars: totalRegisteredCars,
      settingsLast30Days: recentCount,
      averageSettingsPerCar: activeCars == 0 ? 0 : totalSettings / activeCars,
      latestActivity: latestActivity,
      topCar: carUsage.isEmpty ? null : carUsage.first,
      topManufacturer:
          manufacturerUsage.isEmpty ? null : manufacturerUsage.first,
      carUsage: carUsage,
      manufacturerUsage: manufacturerUsage,
      monthlyActivity: monthlyActivity,
      recentActivity: recentActivity.take(recentActivityLimit).toList(),
    );
  }

  static int _compareUsageCounts(
      _UsageStatisticsBase a, _UsageStatisticsBase b) {
    final countComparison = b.count.compareTo(a.count);
    if (countComparison != 0) {
      return countComparison;
    }
    return b.lastUsedAt.compareTo(a.lastUsedAt);
  }

  static String _monthKey(DateTime month) =>
      '${month.year}-${month.month.toString().padLeft(2, '0')}';
}

abstract class _UsageStatisticsBase {
  int get count;
  DateTime get lastUsedAt;
}

class CarUsageStatistics implements _UsageStatisticsBase {
  final String carId;
  final String carName;
  final String manufacturerName;
  @override
  final int count;
  final double share;
  @override
  final DateTime lastUsedAt;

  const CarUsageStatistics({
    required this.carId,
    required this.carName,
    required this.manufacturerName,
    required this.count,
    required this.share,
    required this.lastUsedAt,
  });
}

class ManufacturerUsageStatistics implements _UsageStatisticsBase {
  final String manufacturerId;
  final String manufacturerName;
  @override
  final int count;
  final double share;
  @override
  final DateTime lastUsedAt;

  const ManufacturerUsageStatistics({
    required this.manufacturerId,
    required this.manufacturerName,
    required this.count,
    required this.share,
    required this.lastUsedAt,
  });
}

class MonthlyActivityStatistics {
  final DateTime month;
  final int count;

  const MonthlyActivityStatistics({
    required this.month,
    required this.count,
  });
}

class _MutableCarBucket {
  final String carId;
  final String carName;
  final String manufacturerName;
  int count;
  DateTime lastUsedAt;

  _MutableCarBucket({
    required this.carId,
    required this.carName,
    required this.manufacturerName,
    required this.lastUsedAt,
  }) : count = 0;
}

class _MutableManufacturerBucket {
  final String manufacturerId;
  final String manufacturerName;
  int count;
  DateTime lastUsedAt;

  _MutableManufacturerBucket({
    required this.manufacturerId,
    required this.manufacturerName,
    required this.lastUsedAt,
  }) : count = 0;
}
