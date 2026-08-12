import 'package:rc_setting_manager/utils/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/saved_setting.dart';
import '../models/run_log.dart';
import '../models/car.dart';
import '../models/manufacturer.dart';
import '../models/owned_part.dart';
import '../models/visibility_settings.dart';
import '../domain/parts/owned_part_store.dart';
import '../domain/settings/car_store.dart';
import '../domain/settings/display_settings_store.dart';
import '../domain/settings/run_log_store.dart';
import '../domain/settings/saved_setting_store.dart';
import '../repositories/settings_cloud_repository.dart';
import '../repositories/settings_local_repository.dart';

class SettingsProvider extends ChangeNotifier {
  final SavedSettingStore _savedSettingStore = SavedSettingStore();
  final RunLogStore _runLogStore = RunLogStore();
  final OwnedPartStore _ownedPartStore = OwnedPartStore();
  final DisplaySettingsStore _displaySettingsStore = DisplaySettingsStore();
  final CarStore _carStore = CarStore();
  bool _isInitialized = false; // 初期化完了フラグ

  final SettingsLocalRepository _localRepository;
  final SettingsCloudRepositoryFactory _cloudRepositoryFactory;
  SettingsCloudRepository? _firestoreService;

  List<SavedSetting> get _savedSettings => _savedSettingStore.settings;
  List<RunLog> get _runLogs => _runLogStore.runLogs;
  List<OwnedPart> get _ownedParts => _ownedPartStore.parts;
  Map<String, VisibilitySettings> get _visibilitySettings =>
      _displaySettingsStore.visibilitySettings;
  bool get _isEnglish => _displaySettingsStore.isEnglish;
  bool get _usePaperStyleEditor => _displaySettingsStore.usePaperStyleEditor;
  List<Car> get _cars => _carStore.cars;
  bool get _isOnlineMode => _displaySettingsStore.isOnlineMode;

  List<SavedSetting> get savedSettings => _savedSettings;
  List<RunLog> get runLogs => _runLogs;
  List<OwnedPart> get ownedParts => List.unmodifiable(_ownedParts);
  Map<String, VisibilitySettings> get visibilitySettings => _visibilitySettings;
  bool get isEnglish => _isEnglish;
  List<Car> get cars => _cars;
  List<Car> get garageCars => _carStore.garageCars;
  bool get isOnlineMode => _isOnlineMode;
  bool get usePaperStyleEditor => _usePaperStyleEditor;
  bool get isInitialized => _isInitialized;

  SettingsProvider({
    SettingsLocalRepository? localRepository,
    SettingsCloudRepository? cloudRepository,
    SettingsCloudRepositoryFactory? cloudRepositoryFactory,
  })  : _localRepository =
            localRepository ?? SharedPreferencesSettingsLocalRepository(),
        _firestoreService = cloudRepository,
        _cloudRepositoryFactory = cloudRepositoryFactory ??
            (() => FirestoreSettingsCloudRepository()) {
    _initializeAsync();
  }

  // 非同期初期化を安全に実行
  Future<void> _initializeAsync() async {
    try {
      // まずオンライン設定を読み込み、オンライン指定時のみFirebase依存の初期化を試行
      await _loadOnlineMode();
      if (_isOnlineMode && _firestoreService == null) {
        try {
          _firestoreService = _cloudRepositoryFactory();
        } catch (e) {
          debugLog('FirestoreService initialization failed: $e');
          _firestoreService = null;
        }
      }

      // 各設定を順次読み込み（並行処理を避ける）
      await _loadCars();
      await _loadSettings();
      await _loadRunLogs();
      await _loadOwnedParts();
      await _loadVisibilitySettings();
      await _initializeVisibilitySettings();
      await _loadLanguageSettings();
      await _loadEditorLayoutSettings();

      // Firebase認証状態をチェックしてオンラインモードを自動設定
      await _checkAuthStateAndSetOnlineMode();

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugLog('SettingsProvider initialization error: $e');
      // エラーが発生した場合でも最低限のデータで初期化
      _carStore.useInitialCars();
      _isInitialized = true;
      notifyListeners();
    }
  }

  // Firebase認証状態をチェックしてオンラインモードを設定
  Future<void> _checkAuthStateAndSetOnlineMode() async {
    try {
      if (_firestoreService != null) {
        // Firebase認証が利用可能で、ユーザーがログインしている場合はオンラインモードを有効にする
        if (_firestoreService!.userId != null) {
          _displaySettingsStore.setOnlineMode(true);
          await _saveOnlineMode();
          debugLog('Online mode enabled due to Firebase authentication');
        }
      }
    } catch (e) {
      debugLog('Error checking auth state: $e');
    }
  }

  // 車種リストを読み込み
  Future<void> _loadCars() async {
    try {
      final storedCars = await _localRepository.loadCars();

      if (storedCars != null) {
        _carStore.replace(storedCars);
        if (_carStore.mergeBuiltInCars(
          onError: (error) => debugLog('Error merging built-in cars: $error'),
        )) {
          await _saveCars();
        }
      } else {
        // 初回起動時は初期データを設定
        _carStore.useInitialCars();
        await _saveCars(); // 初期データを保存
      }
    } catch (e) {
      debugLog('Error loading cars: $e');
      // エラーが発生した場合も初期データを設定
      _carStore.useInitialCars();
    }
  }

  // 車種リストを保存
  Future<void> _saveCars() async {
    try {
      await _localRepository.saveCars(_cars);
    } catch (e) {
      debugLog('Error saving cars: $e');
    }
  }

  Future<void> _persistCars() async {
    await _saveCars();

    if (_isOnlineMode && _firestoreService != null) {
      try {
        await _firestoreService!.saveCars(_cars);
      } catch (e) {
        debugLog('Firebase菫晏ｭ倥お繝ｩ繝ｼ: $e');
      }
    }

    notifyListeners();
  }

  // 車種を更新
  Future<void> updateCar(Car updatedCar) async {
    try {
      if (_carStore.update(updatedCar)) {
        await _persistCars();

        // オンラインモードの場合はFirebaseにも保存
        if (_isOnlineMode && _firestoreService != null) {
          try {
            await _firestoreService!.saveCars(_cars);
          } catch (e) {
            debugLog('Firebase保存エラー: $e');
          }
        }

        notifyListeners();
      }
    } catch (e) {
      debugLog('Error updating car: $e');
    }
  }

  // 車種を追加
  Future<void> addCar(Car newCar) async {
    _carStore.add(newCar);
    await _persistCars();

    // オンラインモードの場合はFirebaseにも保存
    if (_isOnlineMode && _firestoreService != null) {
      try {
        await _firestoreService!.saveCars(_cars);
      } catch (e) {
        debugLog('Firebase保存エラー: $e');
      }
    }

    notifyListeners();
  }

  // 車種を削除
  Future<void> deleteCar(String carId) async {
    _carStore.delete(carId);
    await _persistCars();

    // オンラインモードの場合はFirebaseにも保存
    if (_isOnlineMode && _firestoreService != null) {
      try {
        await _firestoreService!.saveCars(_cars);
      } catch (e) {
        debugLog('Firebase保存エラー: $e');
      }
    }

    notifyListeners();
  }

  // メーカーリストを取得
  List<Manufacturer> getManufacturers() {
    return _carStore.manufacturers();
  }

  Map<Manufacturer, List<Car>> getGarageCarsByManufacturer() {
    return _carStore.garageCarsByManufacturer();
  }

  // 特定の車種を取得
  Car? getCarById(String carId) {
    return _carStore.byId(carId);
  }

  // 車種固有の設定項目を取得
  List<String> getCarAvailableSettings(String carId) {
    return _carStore.availableSettings(carId);
  }

  List<String> getSuggestionsForSetting(
    String key,
    List<String>? baseOptions, {
    String query = '',
  }) {
    return _ownedPartStore.suggestions(
      key: key,
      baseOptions: baseOptions,
      savedSettings: _savedSettings,
      query: query,
    );
  }

  List<OwnedPart> getOwnedPartsByCategory(String category) {
    return _ownedPartStore.byCategory(category);
  }

  Future<OwnedPart?> addOwnedPart(String category, String name) async {
    final result = _ownedPartStore.add(category, name);
    if (result.changed) {
      await _persistOwnedParts();
    }
    return result.part;
  }

  Future<bool> updateOwnedPart(
    String id, {
    required String category,
    required String name,
  }) async {
    final changed = _ownedPartStore.update(
      id,
      category: category,
      name: name,
    );
    if (!changed) {
      return false;
    }
    await _persistOwnedParts();
    return true;
  }

  Future<void> deleteOwnedPart(String id) async {
    _ownedPartStore.delete(id);
    await _persistOwnedParts();
  }

  List<OwnedPartImportCandidate> getOwnedPartImportCandidatesFromHistory() {
    return _ownedPartStore.importCandidates(_savedSettings);
  }

  Future<void> importOwnedPartsFromHistory(
    List<OwnedPartImportCandidate> selectedCandidates,
  ) async {
    if (_ownedPartStore.importFromHistory(selectedCandidates)) {
      await _persistOwnedParts();
    }
  }

  Future<void> setGarageMembership(String carId, bool value) async {
    final car = getCarById(carId);
    if (car == null || car.isInGarage == value) {
      return;
    }

    await updateCar(car.copyWith(isInGarage: value));
  }

  Future<void> setGaragePromptSuppressed(String carId, bool value) async {
    final car = getCarById(carId);
    if (car == null || car.suppressGaragePrompt == value) {
      return;
    }

    await updateCar(car.copyWith(suppressGaragePrompt: value));
  }

  // 設定読み込み関数を安全に変更
  Future<void> _loadSettings() async {
    try {
      _savedSettingStore.replace(
        await _localRepository.loadSavedSettings(),
        sortNewestFirst: true,
      );
    } catch (e) {
      debugLog('Error loading settings: $e');
      _savedSettingStore.replace([]);
    }
  }

  Future<void> _loadRunLogs() async {
    try {
      _runLogStore.replace(
        await _localRepository.loadRunLogs(),
        sortNewestFirst: true,
      );
    } catch (e) {
      debugLog('Error loading run logs: $e');
      _runLogStore.replace([]);
    }
  }

  Future<void> _loadOwnedParts() async {
    try {
      _ownedPartStore.replace(
        await _localRepository.loadOwnedParts(),
        sortByName: true,
      );
    } catch (e) {
      debugLog('Error loading owned parts: $e');
      _ownedPartStore.replace([]);
    }
  }

  Future<void> _loadVisibilitySettings() async {
    try {
      _displaySettingsStore.replaceVisibilitySettings(
        await _localRepository.loadVisibilitySettings(),
      );
    } catch (e) {
      debugLog('Error loading visibility settings: $e');
      _displaySettingsStore.replaceVisibilitySettings({});
    }
  }

  Future<void> _initializeVisibilitySettings() async {
    if (_displaySettingsStore.initializeVisibilityDefaults(
      _cars,
      _carStore.availableSettings,
    )) {
      await _saveVisibilitySettings();
    }
  }

  Future<void> _loadLanguageSettings() async {
    try {
      _displaySettingsStore.setLanguage(
        await _localRepository.loadLanguageSettings(),
      );
    } catch (e) {
      debugLog('Error loading language settings: $e');
      _displaySettingsStore.setLanguage(false);
    }
  }

  Future<void> _loadOnlineMode() async {
    try {
      _displaySettingsStore.setOnlineMode(
        await _localRepository.loadOnlineMode(),
      );
    } catch (e) {
      debugLog('Error loading online mode: $e');
      _displaySettingsStore.setOnlineMode(false);
    }
  }

  Future<void> _loadEditorLayoutSettings() async {
    try {
      _displaySettingsStore.setPaperStyleEditor(
        await _localRepository.loadPaperStyleEditor(),
      );
    } catch (e) {
      debugLog('Error loading editor layout settings: $e');
      _displaySettingsStore.setPaperStyleEditor(false);
    }
  }

  Future<void> _saveSettings() async {
    try {
      await _localRepository.saveSavedSettings(_savedSettings);
    } catch (e) {
      debugLog('Error saving settings: $e');
    }
  }

  Future<void> _saveRunLogs() async {
    try {
      await _localRepository.saveRunLogs(_runLogs);
    } catch (e) {
      debugLog('Error saving run logs: $e');
    }
  }

  Future<void> _saveOwnedParts() async {
    try {
      await _localRepository.saveOwnedParts(_ownedParts);
    } catch (e) {
      debugLog('Error saving owned parts: $e');
    }
  }

  Future<void> _persistOwnedParts() async {
    await _saveOwnedParts();

    if (_isOnlineMode && _firestoreService != null) {
      try {
        await _firestoreService!.saveOwnedParts(_ownedParts);
      } catch (e) {
        debugLog('Firebase owned parts save error: $e');
      }
    }

    notifyListeners();
  }

  Future<void> _saveVisibilitySettings() async {
    try {
      await _localRepository.saveVisibilitySettings(_visibilitySettings);
    } catch (e) {
      debugLog('Error saving visibility settings: $e');
    }
  }

  Future<void> _saveLanguageSettings() async {
    try {
      await _localRepository.saveLanguageSettings(_isEnglish);
    } catch (e) {
      debugLog('Error saving language settings: $e');
    }
  }

  Future<void> _saveEditorLayoutSettings() async {
    try {
      await _localRepository.savePaperStyleEditor(_usePaperStyleEditor);
    } catch (e) {
      debugLog('Error saving editor layout settings: $e');
    }
  }

  Future<void> updateSetting(SavedSetting updatedSetting) async {
    try {
      final settingToSave = _savedSettingStore.update(updatedSetting);
      if (settingToSave != null) {
        await _saveSettings();

        // オンラインモードの場合はFirebaseにも保存
        if (_isOnlineMode && _firestoreService != null) {
          try {
            await _firestoreService!.saveSetting(settingToSave);
          } catch (e) {
            debugLog('Firebase保存エラー: $e');
          }
        }

        notifyListeners();
      }
    } catch (e) {
      debugLog('Error updating setting: $e');
    }
  }

  // Get visibility settings (create an in-memory default if not exists).
  // Persisted defaults for known cars are prepared during initialization.
  VisibilitySettings getVisibilitySettings(String carId) {
    return _displaySettingsStore.visibilityFor(
      carId,
      _carStore.availableSettings,
    );
  }

  // Toggle visibility for a specific setting
  Future<void> toggleSettingVisibility(
      String carId, String settingKey, bool isVisible) async {
    final updatedSettings = _displaySettingsStore.withVisibility(
      carId,
      settingKey,
      isVisible,
      _carStore.availableSettings,
    );

    await updateVisibilitySettings(updatedSettings);
  }

  // Toggle favorite for a specific setting
  Future<void> toggleFavoriteSetting(
      String carId, String settingKey, bool isFavorite) async {
    final updatedSettings = _displaySettingsStore.withFavorite(
      carId,
      settingKey,
      isFavorite,
      _carStore.availableSettings,
    );

    await updateVisibilitySettings(updatedSettings);
  }

  // Get favorite settings for a car
  List<String> getFavoriteSettings(String carId) {
    return _displaySettingsStore.favoriteSettings(
      carId,
      _carStore.availableSettings,
    );
  }

  // オンラインモード設定を保存
  Future<void> _saveOnlineMode() async {
    try {
      await _localRepository.saveOnlineMode(_isOnlineMode);
    } catch (e) {
      debugLog('Error saving online mode: $e');
    }
  }

  // オフラインモードを強制的に有効化
  Future<void> setOfflineMode() async {
    _displaySettingsStore.setOnlineMode(false);
    await _saveOnlineMode();
    notifyListeners();
  }

  // オンラインモードを明示的に有効化
  Future<void> setOnlineMode() async {
    _displaySettingsStore.setOnlineMode(true);

    // オンライン切り替え時にFirestoreServiceが未生成ならここで試行
    if (_firestoreService == null) {
      try {
        _firestoreService = _cloudRepositoryFactory();
      } catch (e) {
        debugLog('FirestoreService initialization failed on setOnlineMode: $e');
        _firestoreService = null;
      }
    }

    await _saveOnlineMode();
    notifyListeners();
  }

  // オンラインモードを切り替え
  Future<void> toggleOnlineMode() async {
    _displaySettingsStore.toggleOnlineMode();

    if (_isOnlineMode && _firestoreService == null) {
      try {
        _firestoreService = _cloudRepositoryFactory();
      } catch (e) {
        debugLog(
            'FirestoreService initialization failed on toggleOnlineMode: $e');
        _firestoreService = null;
      }
    }

    await _saveOnlineMode();
    notifyListeners();

    if (_isOnlineMode) {
      // オンラインモードに切り替えた時、データを同期
      await syncToFirebase();
    }
  }

  // Firebaseにデータを同期
  Future<void> syncToFirebase() async {
    if (!_isOnlineMode || _firestoreService == null) return;

    try {
      await _firestoreService!.syncAllData(
        savedSettings: _savedSettings,
        runLogs: _runLogs,
        cars: _cars,
        ownedParts: _ownedParts,
        visibilitySettings: _visibilitySettings,
        isEnglish: _isEnglish,
      );
      debugLog('データをFirebaseに同期しました');
    } catch (e) {
      debugLog('Firebase同期エラー: $e');
      rethrow;
    }
  }

  // Firebaseからデータを読み込み
  Future<void> loadFromFirebase() async {
    if (!_isOnlineMode || _firestoreService == null) return;

    try {
      // 保存された設定を読み込み
      _savedSettingStore.replace(
        await _firestoreService!.getSavedSettings(),
        sortNewestFirst: true,
      );

      _runLogStore.replace(
        await _firestoreService!.getRunLogs(),
        sortNewestFirst: true,
      );
      _ownedPartStore.replace(await _firestoreService!.getOwnedParts());

      // 車種リストを読み込み
      _carStore.replace(await _firestoreService!.getCars());
      _carStore.mergeBuiltInCars(
        onError: (error) => debugLog('Error merging built-in cars: $error'),
      );

      // 表示設定を読み込み
      _displaySettingsStore.replaceVisibilitySettings(
        await _firestoreService!.getVisibilitySettings(),
      );

      // 言語設定を読み込み
      _displaySettingsStore.setLanguage(
        await _firestoreService!.getLanguageSettings(),
      );

      await _saveSettings();
      await _saveRunLogs();
      await _saveOwnedParts();
      await _saveCars();
      await _saveVisibilitySettings();
      await _saveLanguageSettings();
      try {
        await _firestoreService!.saveCars(_cars);
      } catch (e) {
        debugLog('Firebase車種マージ保存エラー: $e');
      }

      notifyListeners();
      debugLog('Firebaseからデータを読み込みました');
    } catch (e) {
      debugLog('Firebase読み込みエラー: $e');
      rethrow;
    }
  }

  // 設定追加時にFirebaseにも保存
  Future<SavedSetting> addSetting(
    String name,
    Car car,
    Map<String, dynamic> settings, {
    SavedSettingKind kind = SavedSettingKind.manual,
    String? sourceRunLogId,
    String? parentSettingId,
  }) async {
    final newSetting = _savedSettingStore.add(
      name,
      car,
      settings,
      kind: kind,
      sourceRunLogId: sourceRunLogId,
      parentSettingId: parentSettingId,
    );
    await _saveSettings();

    // オンラインモードの場合はFirebaseにも保存
    if (_isOnlineMode && _firestoreService != null) {
      try {
        await _firestoreService!.saveSetting(newSetting);
      } catch (e) {
        debugLog('Firebase保存エラー: $e');
      }
    }

    notifyListeners();
    return newSetting;
  }

  SavedSetting? getLatestSettingForCar(String carId) {
    return _savedSettingStore.latestForCar(carId);
  }

  List<SavedSetting> getSavedSettingsForCar(String carId) {
    return _savedSettingStore.forCar(carId);
  }

  Future<RunLog> addRunLog({
    required DateTime runAt,
    required Car car,
    SavedSetting? baseSetting,
    String trackName = '',
    required int bestLapMillis,
    double? airTempC,
    double? humidityPercent,
    String weatherCondition = '',
    double? trackTempC,
    String trackCondition = '',
    required List<String> feelTagIds,
    String memo = '',
    List<RunSettingChange> changes = const [],
  }) async {
    final effectiveChanges = _runLogStore.effectiveChanges(changes);

    final now = DateTime.now();
    final runLogId = now.microsecondsSinceEpoch.toString();
    SavedSetting? resultSetting;
    if (effectiveChanges.isNotEmpty) {
      resultSetting = await addSetting(
        _savedSettingStore.runResultName(runAt, car),
        car,
        _runLogStore.applyChanges(baseSetting, effectiveChanges),
        kind: SavedSettingKind.runResult,
        sourceRunLogId: runLogId,
        parentSettingId: baseSetting?.id,
      );
    }

    final runLog = _runLogStore.add(
      id: runLogId,
      createdAt: now,
      runAt: runAt,
      car: car,
      baseSetting: baseSetting,
      resultSetting: resultSetting,
      trackName: trackName,
      bestLapMillis: bestLapMillis,
      airTempC: airTempC,
      humidityPercent: humidityPercent,
      weatherCondition: weatherCondition,
      trackTempC: trackTempC,
      trackCondition: trackCondition,
      feelTagIds: feelTagIds,
      memo: memo,
      changes: effectiveChanges,
    );
    await _saveRunLogs();

    if (_isOnlineMode && _firestoreService != null) {
      try {
        await _firestoreService!.saveRunLog(runLog);
      } catch (e) {
        debugLog('Firebase run log save error: $e');
      }
    }

    notifyListeners();
    return runLog;
  }

  Future<void> updateRunLog(RunLog updatedRunLog) async {
    if (!_runLogStore.update(updatedRunLog)) {
      return;
    }
    await _saveRunLogs();

    if (_isOnlineMode && _firestoreService != null) {
      try {
        await _firestoreService!.saveRunLog(updatedRunLog);
      } catch (e) {
        debugLog('Firebase run log save error: $e');
      }
    }

    notifyListeners();
  }

  Future<void> deleteRunLog(String id) async {
    _runLogStore.delete(id);
    await _saveRunLogs();

    if (_isOnlineMode && _firestoreService != null) {
      try {
        await _firestoreService!.deleteRunLog(id);
      } catch (e) {
        debugLog('Firebase run log delete error: $e');
      }
    }

    notifyListeners();
  }

  // 設定削除時にFirebaseからも削除
  Future<void> deleteSetting(String id) async {
    _savedSettingStore.delete(id);
    await _saveSettings();

    // オンラインモードの場合はFirebaseからも削除
    if (_isOnlineMode && _firestoreService != null) {
      try {
        await _firestoreService!.deleteSetting(id);
      } catch (e) {
        debugLog('Firebase削除エラー: $e');
      }
    }

    notifyListeners();
  }

  // 言語設定変更時にFirebaseにも保存
  Future<void> toggleLanguage() async {
    _displaySettingsStore.toggleLanguage();
    await _saveLanguageSettings();

    // オンラインモードの場合はFirebaseにも保存
    if (_isOnlineMode && _firestoreService != null) {
      try {
        await _firestoreService!.saveLanguageSettings(_isEnglish);
      } catch (e) {
        debugLog('Firebase保存エラー: $e');
      }
    }

    notifyListeners();
  }

  // 表示設定更新時にFirebaseにも保存
  Future<void> setPaperStyleEditor(bool value) async {
    if (!_displaySettingsStore.setPaperStyleEditor(value)) {
      return;
    }

    await _saveEditorLayoutSettings();
    notifyListeners();
  }

  Future<void> updateVisibilitySettings(VisibilitySettings settings) async {
    _displaySettingsStore.updateVisibility(settings);
    await _saveVisibilitySettings();

    // オンラインモードの場合はFirebaseにも保存
    if (_isOnlineMode && _firestoreService != null) {
      try {
        await _firestoreService!.saveVisibilitySettings(_visibilitySettings);
      } catch (e) {
        debugLog('Firebase保存エラー: $e');
      }
    }

    notifyListeners();
  }

  // すべてのデータを置き換え（インポート用）
  Future<void> replaceAllData({
    required List<Car> cars,
    required List<SavedSetting> savedSettings,
    List<RunLog> runLogs = const [],
    List<OwnedPart> ownedParts = const [],
    required Map<String, VisibilitySettings> visibilitySettings,
  }) async {
    try {
      // データを置き換え
      _carStore.replace(cars);
      _savedSettingStore.replace(savedSettings);
      _runLogStore.replace(runLogs, sortNewestFirst: true);
      _ownedPartStore.replace(ownedParts);
      _displaySettingsStore.replaceVisibilitySettings(visibilitySettings);

      // ローカルストレージに保存
      await _saveCars();
      await _saveSettings();
      await _saveRunLogs();
      await _saveOwnedParts();
      await _saveVisibilitySettings();

      // オンラインモードの場合はFirebaseにも同期
      if (_isOnlineMode && _firestoreService != null) {
        try {
          await _firestoreService!.syncAllData(
            savedSettings: _savedSettings,
            runLogs: _runLogs,
            cars: _cars,
            ownedParts: _ownedParts,
            visibilitySettings: _visibilitySettings,
            isEnglish: _isEnglish,
          );
        } catch (e) {
          debugLog('Firebase同期エラー: $e');
        }
      }

      notifyListeners();
    } catch (e) {
      debugLog('データ置き換えエラー: $e');
      rethrow;
    }
  }

  // 部分的なデータ置き換え（部分的インポート用）
  Future<void> replacePartialData({
    List<Car>? cars,
    List<SavedSetting>? savedSettings,
    List<RunLog>? runLogs,
    List<OwnedPart>? ownedParts,
    Map<String, VisibilitySettings>? visibilitySettings,
    bool? isEnglish,
  }) async {
    try {
      // 指定されたデータのみを置き換え
      if (cars != null) {
        _carStore.replace(cars);
        await _saveCars();
      }

      if (savedSettings != null) {
        _savedSettingStore.replace(savedSettings);
        await _saveSettings();
      }

      if (runLogs != null) {
        _runLogStore.replace(runLogs, sortNewestFirst: true);
        await _saveRunLogs();
      }

      if (ownedParts != null) {
        _ownedPartStore.replace(ownedParts);
        await _saveOwnedParts();
      }

      if (visibilitySettings != null) {
        _displaySettingsStore.replaceVisibilitySettings(visibilitySettings);
        await _saveVisibilitySettings();
      }

      if (isEnglish != null) {
        _displaySettingsStore.setLanguage(isEnglish);
        await _saveLanguageSettings();
      }

      // オンラインモードの場合はFirebaseにも同期
      if (_isOnlineMode && _firestoreService != null) {
        try {
          await _firestoreService!.syncAllData(
            savedSettings: _savedSettings,
            runLogs: _runLogs,
            cars: _cars,
            ownedParts: _ownedParts,
            visibilitySettings: _visibilitySettings,
            isEnglish: _isEnglish,
          );
        } catch (e) {
          debugLog('Firebase同期エラー: $e');
        }
      }

      notifyListeners();
    } catch (e) {
      debugLog('部分データ置き換えエラー: $e');
      rethrow;
    }
  }
}
