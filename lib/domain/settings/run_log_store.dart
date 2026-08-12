import '../../models/car.dart';
import '../../models/run_log.dart';
import '../../models/saved_setting.dart';

/// 走行ログの状態、正規化、並び順を保持する内部ストア。
class RunLogStore {
  List<RunLog> _runLogs = [];

  List<RunLog> get runLogs => _runLogs;

  void replace(List<RunLog> runLogs, {bool sortNewestFirst = false}) {
    _runLogs = runLogs;
    if (sortNewestFirst) {
      _sortNewestFirst();
    }
  }

  List<RunSettingChange> effectiveChanges(
    Iterable<RunSettingChange> changes,
  ) {
    return changes
        .where(
          (change) =>
              change.settingKey.trim().isNotEmpty &&
              change.afterValue != null &&
              change.afterValue.toString().trim().isNotEmpty,
        )
        .toList(growable: false);
  }

  Map<String, dynamic> applyChanges(
    SavedSetting? baseSetting,
    Iterable<RunSettingChange> changes,
  ) {
    final result = baseSetting != null
        ? Map<String, dynamic>.from(baseSetting.settings)
        : <String, dynamic>{};
    for (final change in changes) {
      result[change.settingKey] = change.afterValue;
    }
    return result;
  }

  RunLog add({
    required String id,
    required DateTime createdAt,
    required DateTime runAt,
    required Car car,
    required SavedSetting? baseSetting,
    required SavedSetting? resultSetting,
    required String trackName,
    required int bestLapMillis,
    required double? airTempC,
    required double? humidityPercent,
    required String weatherCondition,
    required double? trackTempC,
    required String trackCondition,
    required List<String> feelTagIds,
    required String memo,
    required List<RunSettingChange> changes,
  }) {
    final runLog = RunLog(
      id: id,
      createdAt: createdAt,
      runAt: runAt,
      car: car,
      trackName: trackName.trim(),
      baseSettingId: baseSetting?.id,
      baseSettingName: baseSetting?.name,
      resultSettingId: resultSetting?.id,
      resultSettingName: resultSetting?.name,
      bestLapMillis: bestLapMillis,
      airTempC: airTempC,
      humidityPercent: humidityPercent,
      weatherCondition: weatherCondition.trim(),
      trackTempC: trackTempC,
      trackCondition: trackCondition.trim(),
      feelTagIds: List<String>.from(feelTagIds),
      memo: memo.trim(),
      changes: changes,
    );
    _runLogs.insert(0, runLog);
    _sortNewestFirst();
    return runLog;
  }

  bool update(RunLog updatedRunLog) {
    final index = _runLogs.indexWhere(
      (runLog) => runLog.id == updatedRunLog.id,
    );
    if (index == -1) {
      return false;
    }
    _runLogs[index] = updatedRunLog;
    _sortNewestFirst();
    return true;
  }

  void delete(String id) {
    _runLogs.removeWhere((runLog) => runLog.id == id);
  }

  void _sortNewestFirst() {
    _runLogs.sort((a, b) => b.runAt.compareTo(a.runAt));
  }
}
