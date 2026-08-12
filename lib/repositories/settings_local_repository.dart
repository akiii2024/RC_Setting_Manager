import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/car.dart';
import '../models/owned_part.dart';
import '../models/run_log.dart';
import '../models/saved_setting.dart';
import '../models/visibility_settings.dart';

/// SettingsProvider が扱うローカル永続化の境界。
///
/// 保存キーと JSON 形式は [SharedPreferencesSettingsLocalRepository] に閉じ込め、
/// Provider は状態遷移と通知だけを担当する。
abstract interface class SettingsLocalRepository {
  Future<List<Car>?> loadCars();

  Future<void> saveCars(List<Car> cars);

  Future<List<SavedSetting>> loadSavedSettings();

  Future<void> saveSavedSettings(List<SavedSetting> savedSettings);

  Future<List<RunLog>> loadRunLogs();

  Future<void> saveRunLogs(List<RunLog> runLogs);

  Future<List<OwnedPart>> loadOwnedParts();

  Future<void> saveOwnedParts(List<OwnedPart> ownedParts);

  Future<Map<String, VisibilitySettings>> loadVisibilitySettings();

  Future<void> saveVisibilitySettings(
    Map<String, VisibilitySettings> visibilitySettings,
  );

  Future<bool> loadLanguageSettings();

  Future<void> saveLanguageSettings(bool isEnglish);

  Future<bool> loadOnlineMode();

  Future<void> saveOnlineMode(bool isOnlineMode);

  Future<bool> loadPaperStyleEditor();

  Future<void> savePaperStyleEditor(bool usePaperStyleEditor);
}

typedef SharedPreferencesLoader = Future<SharedPreferences> Function();

/// 既存の SharedPreferences キーと JSON 形状を維持する実装。
class SharedPreferencesSettingsLocalRepository
    implements SettingsLocalRepository {
  SharedPreferencesSettingsLocalRepository({
    SharedPreferencesLoader? preferencesLoader,
  }) : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

  static const savedSettingsKey = 'saved_settings';
  static const runLogsKey = 'run_logs';
  static const ownedPartsKey = 'owned_parts';
  static const visibilitySettingsKey = 'visibility_settings';
  static const languageKey = 'language_settings';
  static const carsKey = 'cars_settings';
  static const onlineModeKey = 'online_mode';
  static const editorLayoutKey = 'editor_layout_paper';

  final SharedPreferencesLoader _preferencesLoader;

  @override
  Future<List<Car>?> loadCars() async {
    final prefs = await _preferencesLoader();
    final carsJson = prefs.getString(carsKey);
    if (carsJson == null) {
      return null;
    }

    final List<dynamic> decoded = jsonDecode(carsJson);
    return decoded.map((item) => Car.fromJson(item)).toList();
  }

  @override
  Future<void> saveCars(List<Car> cars) async {
    final prefs = await _preferencesLoader();
    final carsJson = jsonEncode(cars.map((car) => car.toJson()).toList());
    await prefs.setString(carsKey, carsJson);
  }

  @override
  Future<List<SavedSetting>> loadSavedSettings() async {
    final prefs = await _preferencesLoader();
    final settingsJson = prefs.getString(savedSettingsKey);
    if (settingsJson == null) {
      return [];
    }

    final List<dynamic> decoded = jsonDecode(settingsJson);
    return decoded.map((item) => SavedSetting.fromJson(item)).toList();
  }

  @override
  Future<void> saveSavedSettings(List<SavedSetting> savedSettings) async {
    final prefs = await _preferencesLoader();
    final settingsJson = jsonEncode(
      savedSettings.map((setting) => setting.toJson()).toList(),
    );
    await prefs.setString(savedSettingsKey, settingsJson);
  }

  @override
  Future<List<RunLog>> loadRunLogs() async {
    final prefs = await _preferencesLoader();
    final runLogsJson = prefs.getString(runLogsKey);
    if (runLogsJson == null) {
      return [];
    }

    final List<dynamic> decoded = jsonDecode(runLogsJson);
    return decoded.map((item) => RunLog.fromJson(item)).toList();
  }

  @override
  Future<void> saveRunLogs(List<RunLog> runLogs) async {
    final prefs = await _preferencesLoader();
    final runLogsJson = jsonEncode(
      runLogs.map((runLog) => runLog.toJson()).toList(),
    );
    await prefs.setString(runLogsKey, runLogsJson);
  }

  @override
  Future<List<OwnedPart>> loadOwnedParts() async {
    final prefs = await _preferencesLoader();
    final ownedPartsJson = prefs.getString(ownedPartsKey);
    if (ownedPartsJson == null) {
      return [];
    }

    final List<dynamic> decoded = jsonDecode(ownedPartsJson);
    return decoded
        .map(
          (item) => OwnedPart.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  @override
  Future<void> saveOwnedParts(List<OwnedPart> ownedParts) async {
    final prefs = await _preferencesLoader();
    final ownedPartsJson = jsonEncode(
      ownedParts.map((part) => part.toJson()).toList(),
    );
    await prefs.setString(ownedPartsKey, ownedPartsJson);
  }

  @override
  Future<Map<String, VisibilitySettings>> loadVisibilitySettings() async {
    final prefs = await _preferencesLoader();
    final visibilityJson = prefs.getString(visibilitySettingsKey);
    if (visibilityJson == null) {
      return {};
    }

    final Map<String, dynamic> decoded = jsonDecode(visibilityJson);
    return decoded.map(
      (key, value) => MapEntry(
        key,
        VisibilitySettings.fromJson(value as Map<String, dynamic>),
      ),
    );
  }

  @override
  Future<void> saveVisibilitySettings(
    Map<String, VisibilitySettings> visibilitySettings,
  ) async {
    final prefs = await _preferencesLoader();
    final visibilityJson = jsonEncode(visibilitySettings);
    await prefs.setString(visibilitySettingsKey, visibilityJson);
  }

  @override
  Future<bool> loadLanguageSettings() async {
    final prefs = await _preferencesLoader();
    return prefs.getBool(languageKey) ?? false;
  }

  @override
  Future<void> saveLanguageSettings(bool isEnglish) async {
    final prefs = await _preferencesLoader();
    await prefs.setBool(languageKey, isEnglish);
  }

  @override
  Future<bool> loadOnlineMode() async {
    final prefs = await _preferencesLoader();
    return prefs.getBool(onlineModeKey) ?? false;
  }

  @override
  Future<void> saveOnlineMode(bool isOnlineMode) async {
    final prefs = await _preferencesLoader();
    await prefs.setBool(onlineModeKey, isOnlineMode);
  }

  @override
  Future<bool> loadPaperStyleEditor() async {
    final prefs = await _preferencesLoader();
    return prefs.getBool(editorLayoutKey) ?? false;
  }

  @override
  Future<void> savePaperStyleEditor(bool usePaperStyleEditor) async {
    final prefs = await _preferencesLoader();
    await prefs.setBool(editorLayoutKey, usePaperStyleEditor);
  }
}
