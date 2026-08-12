import '../models/car.dart';
import '../models/owned_part.dart';
import '../models/run_log.dart';
import '../models/saved_setting.dart';
import '../models/visibility_settings.dart';
import '../services/firestore_service.dart';

/// SettingsProvider が利用するクラウド同期の境界。
abstract interface class SettingsCloudRepository {
  String? get userId;

  Future<void> saveSetting(SavedSetting setting);

  Future<List<SavedSetting>> getSavedSettings();

  Future<void> deleteSetting(String settingId);

  Future<void> saveRunLog(RunLog runLog);

  Future<List<RunLog>> getRunLogs();

  Future<void> deleteRunLog(String runLogId);

  Future<void> saveCars(List<Car> cars);

  Future<List<Car>> getCars();

  Future<void> saveOwnedParts(List<OwnedPart> ownedParts);

  Future<List<OwnedPart>> getOwnedParts();

  Future<void> saveVisibilitySettings(
    Map<String, VisibilitySettings> visibilitySettings,
  );

  Future<Map<String, VisibilitySettings>> getVisibilitySettings();

  Future<void> saveLanguageSettings(bool isEnglish);

  Future<bool> getLanguageSettings();

  Future<void> syncAllData({
    required List<SavedSetting> savedSettings,
    required List<RunLog> runLogs,
    required List<Car> cars,
    required List<OwnedPart> ownedParts,
    required Map<String, VisibilitySettings> visibilitySettings,
    required bool isEnglish,
  });
}

typedef SettingsCloudRepositoryFactory = SettingsCloudRepository Function();

/// 既存の FirestoreService を同期境界へ適合させるアダプタ。
class FirestoreSettingsCloudRepository implements SettingsCloudRepository {
  FirestoreSettingsCloudRepository({FirestoreService? service})
      : _service = service ?? FirestoreService();

  final FirestoreService _service;

  @override
  String? get userId => _service.userId;

  @override
  Future<void> saveSetting(SavedSetting setting) =>
      _service.saveSetting(setting);

  @override
  Future<List<SavedSetting>> getSavedSettings() => _service.getSavedSettings();

  @override
  Future<void> deleteSetting(String settingId) =>
      _service.deleteSetting(settingId);

  @override
  Future<void> saveRunLog(RunLog runLog) => _service.saveRunLog(runLog);

  @override
  Future<List<RunLog>> getRunLogs() => _service.getRunLogs();

  @override
  Future<void> deleteRunLog(String runLogId) => _service.deleteRunLog(runLogId);

  @override
  Future<void> saveCars(List<Car> cars) => _service.saveCars(cars);

  @override
  Future<List<Car>> getCars() => _service.getCars();

  @override
  Future<void> saveOwnedParts(List<OwnedPart> ownedParts) =>
      _service.saveOwnedParts(ownedParts);

  @override
  Future<List<OwnedPart>> getOwnedParts() => _service.getOwnedParts();

  @override
  Future<void> saveVisibilitySettings(
    Map<String, VisibilitySettings> visibilitySettings,
  ) =>
      _service.saveVisibilitySettings(visibilitySettings);

  @override
  Future<Map<String, VisibilitySettings>> getVisibilitySettings() =>
      _service.getVisibilitySettings();

  @override
  Future<void> saveLanguageSettings(bool isEnglish) =>
      _service.saveLanguageSettings(isEnglish);

  @override
  Future<bool> getLanguageSettings() => _service.getLanguageSettings();

  @override
  Future<void> syncAllData({
    required List<SavedSetting> savedSettings,
    required List<RunLog> runLogs,
    required List<Car> cars,
    required List<OwnedPart> ownedParts,
    required Map<String, VisibilitySettings> visibilitySettings,
    required bool isEnglish,
  }) =>
      _service.syncAllData(
        savedSettings: savedSettings,
        runLogs: runLogs,
        cars: cars,
        ownedParts: ownedParts,
        visibilitySettings: visibilitySettings,
        isEnglish: isEnglish,
      );
}
