import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/saved_setting.dart';
import '../models/run_log.dart';
import '../models/car.dart';
import '../models/manufacturer.dart';
import '../models/owned_part.dart';
import '../models/visibility_settings.dart';
import '../data/car_settings_definitions.dart';
import '../data/setting_name_options.dart';
import '../services/firestore_service.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  List<SavedSetting> _savedSettings = [];
  List<RunLog> _runLogs = [];
  List<OwnedPart> _ownedParts = [];
  Map<String, VisibilitySettings> _visibilitySettings = {};
  bool _isEnglish = false;
  bool _usePaperStyleEditor = false;
  List<Car> _cars = []; // 車種リストを保持
  bool _isOnlineMode = false; // オンラインモードかどうか
  bool _isInitialized = false; // 初期化完了フラグ

  final String _savedSettingsKey = 'saved_settings';
  final String _runLogsKey = 'run_logs';
  final String _ownedPartsKey = 'owned_parts';
  final String _visibilitySettingsKey = 'visibility_settings';
  final String _languageKey = 'language_settings';
  final String _carsKey = 'cars_settings';
  final String _onlineModeKey = 'online_mode';
  final String _editorLayoutKey = 'editor_layout_paper';

  FirestoreService? _firestoreService;

  List<SavedSetting> get savedSettings => _savedSettings;
  List<RunLog> get runLogs => _runLogs;
  List<OwnedPart> get ownedParts => List.unmodifiable(_ownedParts);
  Map<String, VisibilitySettings> get visibilitySettings => _visibilitySettings;
  bool get isEnglish => _isEnglish;
  List<Car> get cars => _cars;
  List<Car> get garageCars =>
      _cars.where((car) => car.isInGarage).toList(growable: false);
  bool get isOnlineMode => _isOnlineMode;
  bool get usePaperStyleEditor => _usePaperStyleEditor;
  bool get isInitialized => _isInitialized;

  SettingsProvider() {
    _initializeAsync();
  }

  // 非同期初期化を安全に実行
  Future<void> _initializeAsync() async {
    try {
      // まずオンライン設定を読み込み、オンライン指定時のみFirebase依存の初期化を試行
      await _loadOnlineMode();
      if (_isOnlineMode) {
        try {
          _firestoreService = FirestoreService();
        } catch (e) {
          print('FirestoreService initialization failed: $e');
          _firestoreService = null;
        }
      }

      // 各設定を順次読み込み（並行処理を避ける）
      await _loadCars();
      await _loadSettings();
      await _loadRunLogs();
      await _loadOwnedParts();
      await _loadVisibilitySettings();
      await _loadLanguageSettings();
      await _loadEditorLayoutSettings();

      // Firebase認証状態をチェックしてオンラインモードを自動設定
      await _checkAuthStateAndSetOnlineMode();

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      print('SettingsProvider initialization error: $e');
      // エラーが発生した場合でも最低限のデータで初期化
      _cars = _getInitialCars();
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
          _isOnlineMode = true;
          await _saveOnlineMode();
          print('Online mode enabled due to Firebase authentication');
        }
      }
    } catch (e) {
      print('Error checking auth state: $e');
    }
  }

  // 車種リストを読み込み
  Future<void> _loadCars() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final carsJson = prefs.getString(_carsKey);

      if (carsJson != null) {
        final List<dynamic> decoded = jsonDecode(carsJson);
        _cars = decoded.map((item) => Car.fromJson(item)).toList();
        final mergedCars = _mergeBuiltInCars(_cars);
        if (mergedCars.length != _cars.length) {
          _cars = mergedCars;
          await _saveCars();
        }
      } else {
        // 初回起動時は初期データを設定
        _cars = _getInitialCars();
        await _saveCars(); // 初期データを保存
      }
    } catch (e) {
      print('Error loading cars: $e');
      // エラーが発生した場合も初期データを設定
      _cars = _getInitialCars();
    }
  }

  // 初期車種データを取得
  List<Car> _getInitialCars() {
    return _getBuiltInCars();
  }

  List<Car> _mergeBuiltInCars(List<Car> cars) {
    final mergedCars = List<Car>.from(cars);
    final existingIds = mergedCars.map((car) => car.id).toSet();

    for (final builtInCar in _getBuiltInCars()) {
      if (!existingIds.contains(builtInCar.id)) {
        mergedCars.add(builtInCar);
      }
    }

    return mergedCars;
  }

  List<Car> _getBuiltInCars() {
    try {
      final tamiyaManufacturer = Manufacturer(
        id: 'tamiya',
        name: 'タミヤ',
        logoPath: 'assets/images/tamiya.png',
      );

      final yokomoManufacturer = Manufacturer(
        id: 'yokomo',
        name: 'ヨコモ',
        logoPath: 'assets/images/yokomo.png',
      );

      return [
        // タミヤの車種
        Car(
          id: 'tamiya/trf421',
          name: 'TRF421',
          imageUrl: 'assets/images/trf421.jpg',
          manufacturer: tamiyaManufacturer,
          category: 'ツーリングカー',
        ),
        Car(
          id: 'tamiya/trf420x',
          name: 'TRF420X',
          imageUrl: 'assets/images/trf420x.jpg',
          manufacturer: tamiyaManufacturer,
          category: 'ツーリングカー',
        ),
        Car(
          id: 'tamiya/trf421x',
          name: 'TRF421X',
          imageUrl: 'assets/images/trf421x.jpg',
          manufacturer: tamiyaManufacturer,
          category: 'ツーリングカー',
        ),

        // ヨコモの車種
        Car(
          id: 'yokomo/bd11',
          name: 'BD11',
          imageUrl: 'assets/images/bd11.jpg',
          manufacturer: yokomoManufacturer,
          category: 'ツーリングカー',
        ),
        Car(
          id: 'yokomo/bd12',
          name: 'BD12',
          imageUrl: 'assets/images/bd12.jpg',
          manufacturer: yokomoManufacturer,
          category: 'ツーリングカー',
        ),
        Car(
          id: 'yokomo/ms1_0',
          name: 'MS1.0',
          imageUrl: 'assets/images/ms1_0.jpg',
          manufacturer: yokomoManufacturer,
          category: 'ツーリングカー',
        ),
        Car(
          id: 'yokomo/ms2_0',
          name: 'MS2.0',
          imageUrl: 'assets/images/ms2_0.jpg',
          manufacturer: yokomoManufacturer,
          category: 'ツーリングカー',
        ),
      ];
    } catch (e) {
      print('Error creating initial cars: $e');
      return []; // エラー時は空のリストを返す
    }
  }

  // 車種リストを保存
  Future<void> _saveCars() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final carsJson = jsonEncode(_cars.map((car) => car.toJson()).toList());
      await prefs.setString(_carsKey, carsJson);
    } catch (e) {
      print('Error saving cars: $e');
    }
  }

  Future<void> _persistCars() async {
    await _saveCars();

    if (_isOnlineMode && _firestoreService != null) {
      try {
        await _firestoreService!.saveCars(_cars);
      } catch (e) {
        print('Firebase菫晏ｭ倥お繝ｩ繝ｼ: $e');
      }
    }

    notifyListeners();
  }

  // 車種を更新
  Future<void> updateCar(Car updatedCar) async {
    try {
      final index = _cars.indexWhere((car) => car.id == updatedCar.id);
      if (index != -1) {
        _cars[index] = updatedCar;
        await _persistCars();

        // オンラインモードの場合はFirebaseにも保存
        if (_isOnlineMode && _firestoreService != null) {
          try {
            await _firestoreService!.saveCars(_cars);
          } catch (e) {
            print('Firebase保存エラー: $e');
          }
        }

        notifyListeners();
      }
    } catch (e) {
      print('Error updating car: $e');
    }
  }

  // 車種を追加
  Future<void> addCar(Car newCar) async {
    _cars.add(newCar);
    await _persistCars();

    // オンラインモードの場合はFirebaseにも保存
    if (_isOnlineMode && _firestoreService != null) {
      try {
        await _firestoreService!.saveCars(_cars);
      } catch (e) {
        print('Firebase保存エラー: $e');
      }
    }

    notifyListeners();
  }

  // 車種を削除
  Future<void> deleteCar(String carId) async {
    _cars.removeWhere((car) => car.id == carId);
    await _persistCars();

    // オンラインモードの場合はFirebaseにも保存
    if (_isOnlineMode && _firestoreService != null) {
      try {
        await _firestoreService!.saveCars(_cars);
      } catch (e) {
        print('Firebase保存エラー: $e');
      }
    }

    notifyListeners();
  }

  // メーカーリストを取得
  List<Manufacturer> getManufacturers() {
    final manufacturers = <String, Manufacturer>{};
    for (final car in _cars) {
      manufacturers[car.manufacturer.id] = car.manufacturer;
    }
    final values = manufacturers.values.toList();
    values.sort((a, b) => a.name.compareTo(b.name));
    return values;
  }

  Map<Manufacturer, List<Car>> getGarageCarsByManufacturer() {
    final groupedCars = <String, List<Car>>{};
    final manufacturers = <String, Manufacturer>{};

    for (final car in garageCars) {
      manufacturers[car.manufacturer.id] = car.manufacturer;
      groupedCars.putIfAbsent(car.manufacturer.id, () => <Car>[]).add(car);
    }

    final manufacturerIds = groupedCars.keys.toList()
      ..sort(
          (a, b) => manufacturers[a]!.name.compareTo(manufacturers[b]!.name));

    return {
      for (final manufacturerId in manufacturerIds)
        manufacturers[manufacturerId]!: groupedCars[manufacturerId]!
          ..sort(
            (a, b) => a.name.compareTo(b.name),
          ),
    };
  }

  // 特定の車種を取得
  Car? getCarById(String carId) {
    try {
      return _cars.firstWhere((car) => car.id == carId);
    } catch (e) {
      return null; // 見つからない場合はnullを返す
    }
  }

  // 車種固有の設定項目を取得
  List<String> getCarAvailableSettings(String carId) {
    final car = getCarById(carId);
    if (car != null && car.availableSettings.isNotEmpty) {
      return car.availableSettings;
    }

    final definition = getCarSettingDefinition(carId);
    return definition?.availableSettings
            .map((setting) => setting.key)
            .toList(growable: false) ??
        [];
  }

  List<String> getSuggestionsForSetting(
    String key,
    List<String>? baseOptions, {
    String query = '',
  }) {
    final suggestionCategory = _suggestionCategoryForKey(key);
    final base = [
      ...?baseOptions,
      ...defaultNameOptionsForSetting(key),
    ];

    if (!settingNameSuggestionKeys.contains(key)) {
      return List<String>.from(base);
    }

    final ownedNames = suggestionCategory == null
        ? const <String>[]
        : getOwnedPartsByCategory(suggestionCategory)
            .map((part) => part.name)
            .toList(growable: false);
    final normalizedOwnedNames = normalizeSettingNameOptions(key, ownedNames);
    final normalizedQuery = query.trim().toLowerCase();

    if (normalizedQuery.isEmpty && normalizedOwnedNames.isNotEmpty) {
      return normalizedOwnedNames;
    }

    final historyKeys = historyKeysForSettingSuggestions(key);
    final savedNames = _savedSettings.expand(
      (setting) => historyKeys
          .map((historyKey) => setting.settings[historyKey])
          .whereType<String>(),
    );

    final suggestions = normalizeSettingNameOptions(key, [
      ...normalizedOwnedNames,
      ...base,
      ...savedNames,
    ]);

    if (normalizedQuery.isEmpty) {
      return suggestions;
    }

    return suggestions
        .where((option) => option.toLowerCase().contains(normalizedQuery))
        .toList(growable: false);
  }

  String? _suggestionCategoryForKey(String key) {
    if (key == 'frontTire' || key == 'rearTire') {
      return 'tire';
    }
    return ownedPartCategories.contains(key) ? key : null;
  }

  List<OwnedPart> getOwnedPartsByCategory(String category) {
    final parts = _ownedParts
        .where((part) => part.category == category)
        .toList(growable: false);
    parts.sort((a, b) => a.name.compareTo(b.name));
    return parts;
  }

  Future<OwnedPart?> addOwnedPart(String category, String name) async {
    final normalizedName = name.trim();
    if (!ownedPartCategories.contains(category) || normalizedName.isEmpty) {
      return null;
    }

    final existing = _findOwnedPartByName(category, normalizedName);
    if (existing != null) {
      return existing;
    }

    final now = DateTime.now();
    final part = OwnedPart(
      id: now.microsecondsSinceEpoch.toString(),
      category: category,
      name: normalizedName,
      createdAt: now,
    );
    _ownedParts.add(part);
    await _persistOwnedParts();
    return part;
  }

  Future<bool> updateOwnedPart(
    String id, {
    required String category,
    required String name,
  }) async {
    final normalizedName = name.trim();
    if (!ownedPartCategories.contains(category) || normalizedName.isEmpty) {
      return false;
    }

    final index = _ownedParts.indexWhere((part) => part.id == id);
    if (index == -1) {
      return false;
    }

    final duplicate = _findOwnedPartByName(
      category,
      normalizedName,
      excludeId: id,
    );
    if (duplicate != null) {
      return false;
    }

    _ownedParts[index] = _ownedParts[index].copyWith(
      category: category,
      name: normalizedName,
    );
    await _persistOwnedParts();
    return true;
  }

  Future<void> deleteOwnedPart(String id) async {
    _ownedParts.removeWhere((part) => part.id == id);
    await _persistOwnedParts();
  }

  List<OwnedPartImportCandidate> getOwnedPartImportCandidatesFromHistory() {
    final candidates = <OwnedPartImportCandidate>[];
    final seen = <String>{};

    void addCandidate(String category, dynamic value) {
      if (value is! String) {
        return;
      }
      final name = value.trim();
      if (name.isEmpty) {
        return;
      }
      final normalized = normalizeSettingNameOptions(category, [name]);
      if (normalized.isEmpty) {
        return;
      }
      final normalizedName = normalized.first;
      if (_findOwnedPartByName(category, normalizedName) != null) {
        return;
      }
      final identity =
          '${category.toLowerCase()}::${normalizedName.toLowerCase()}';
      if (seen.add(identity)) {
        candidates.add(
          OwnedPartImportCandidate(
            category: category,
            name: normalizedName,
          ),
        );
      }
    }

    for (final setting in _savedSettings) {
      addCandidate('motor', setting.settings['motor']);
      addCandidate('battery', setting.settings['battery']);
      addCandidate('body', setting.settings['body']);
      addCandidate('tire', setting.settings['tire']);
      addCandidate('tire', setting.settings['frontTire']);
      addCandidate('tire', setting.settings['rearTire']);
    }

    candidates.sort((a, b) {
      final categoryCompare = a.category.compareTo(b.category);
      if (categoryCompare != 0) {
        return categoryCompare;
      }
      return a.name.compareTo(b.name);
    });
    return candidates;
  }

  Future<void> importOwnedPartsFromHistory(
    List<OwnedPartImportCandidate> selectedCandidates,
  ) async {
    var changed = false;

    for (final candidate in selectedCandidates) {
      final category = candidate.category;
      final name = candidate.name.trim();
      if (!ownedPartCategories.contains(category) || name.isEmpty) {
        continue;
      }
      if (_findOwnedPartByName(category, name) != null) {
        continue;
      }
      final now = DateTime.now();
      _ownedParts.add(
        OwnedPart(
          id: '${now.microsecondsSinceEpoch}-${_ownedParts.length}',
          category: category,
          name: name,
          createdAt: now,
        ),
      );
      changed = true;
    }

    if (changed) {
      await _persistOwnedParts();
    }
  }

  OwnedPart? _findOwnedPartByName(
    String category,
    String name, {
    String? excludeId,
  }) {
    final normalizedName = name.trim().toLowerCase();
    for (final part in _ownedParts) {
      if (part.category == category &&
          part.id != excludeId &&
          part.name.trim().toLowerCase() == normalizedName) {
        return part;
      }
    }
    return null;
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
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_savedSettingsKey);

      if (settingsJson != null) {
        final List<dynamic> decoded = jsonDecode(settingsJson);
        _savedSettings =
            decoded.map((item) => SavedSetting.fromJson(item)).toList();

        // Sort by creation date in descending order
        _savedSettings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
    } catch (e) {
      print('Error loading settings: $e');
      _savedSettings = [];
    }
  }

  Future<void> _loadRunLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final runLogsJson = prefs.getString(_runLogsKey);

      if (runLogsJson != null) {
        final List<dynamic> decoded = jsonDecode(runLogsJson);
        _runLogs = decoded.map((item) => RunLog.fromJson(item)).toList();
        _runLogs.sort((a, b) => b.runAt.compareTo(a.runAt));
      }
    } catch (e) {
      print('Error loading run logs: $e');
      _runLogs = [];
    }
  }

  Future<void> _loadOwnedParts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ownedPartsJson = prefs.getString(_ownedPartsKey);

      if (ownedPartsJson != null) {
        final List<dynamic> decoded = jsonDecode(ownedPartsJson);
        _ownedParts = decoded
            .map((item) => OwnedPart.fromJson(Map<String, dynamic>.from(
                  item as Map,
                )))
            .toList();
        _ownedParts.sort((a, b) => a.name.compareTo(b.name));
      }
    } catch (e) {
      print('Error loading owned parts: $e');
      _ownedParts = [];
    }
  }

  Future<void> _loadVisibilitySettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final visibilityJson = prefs.getString(_visibilitySettingsKey);

      if (visibilityJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(visibilityJson);
        _visibilitySettings = decoded.map((key, value) => MapEntry(
            key, VisibilitySettings.fromJson(value as Map<String, dynamic>)));
      }
    } catch (e) {
      print('Error loading visibility settings: $e');
      _visibilitySettings = {};
    }
  }

  Future<void> _loadLanguageSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnglish = prefs.getBool(_languageKey) ?? false;
    } catch (e) {
      print('Error loading language settings: $e');
      _isEnglish = false;
    }
  }

  Future<void> _loadOnlineMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isOnlineMode = prefs.getBool(_onlineModeKey) ?? false;
    } catch (e) {
      print('Error loading online mode: $e');
      _isOnlineMode = false;
    }
  }

  Future<void> _loadEditorLayoutSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _usePaperStyleEditor = prefs.getBool(_editorLayoutKey) ?? false;
    } catch (e) {
      print('Error loading editor layout settings: $e');
      _usePaperStyleEditor = false;
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = jsonEncode(
          _savedSettings.map((setting) => setting.toJson()).toList());
      await prefs.setString(_savedSettingsKey, settingsJson);
    } catch (e) {
      print('Error saving settings: $e');
    }
  }

  Future<void> _saveRunLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final runLogsJson =
          jsonEncode(_runLogs.map((runLog) => runLog.toJson()).toList());
      await prefs.setString(_runLogsKey, runLogsJson);
    } catch (e) {
      print('Error saving run logs: $e');
    }
  }

  Future<void> _saveOwnedParts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ownedPartsJson =
          jsonEncode(_ownedParts.map((part) => part.toJson()).toList());
      await prefs.setString(_ownedPartsKey, ownedPartsJson);
    } catch (e) {
      print('Error saving owned parts: $e');
    }
  }

  Future<void> _persistOwnedParts() async {
    await _saveOwnedParts();

    if (_isOnlineMode && _firestoreService != null) {
      try {
        await _firestoreService!.saveOwnedParts(_ownedParts);
      } catch (e) {
        print('Firebase owned parts save error: $e');
      }
    }

    notifyListeners();
  }

  Future<void> _saveVisibilitySettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final visibilityJson = jsonEncode(_visibilitySettings);
      await prefs.setString(_visibilitySettingsKey, visibilityJson);
    } catch (e) {
      print('Error saving visibility settings: $e');
    }
  }

  Future<void> _saveLanguageSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_languageKey, _isEnglish);
    } catch (e) {
      print('Error saving language settings: $e');
    }
  }

  Future<void> _saveEditorLayoutSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_editorLayoutKey, _usePaperStyleEditor);
    } catch (e) {
      print('Error saving editor layout settings: $e');
    }
  }

  Future<void> updateSetting(SavedSetting updatedSetting) async {
    try {
      final index = _savedSettings
          .indexWhere((setting) => setting.id == updatedSetting.id);
      if (index != -1) {
        final uniqueName = _createUniqueSettingName(
          updatedSetting.name,
          excludeId: updatedSetting.id,
        );
        final settingToSave = SavedSetting(
          id: updatedSetting.id,
          name: uniqueName,
          createdAt: updatedSetting.createdAt,
          car: updatedSetting.car,
          settings: updatedSetting.settings,
          kind: updatedSetting.kind,
          sourceRunLogId: updatedSetting.sourceRunLogId,
          parentSettingId: updatedSetting.parentSettingId,
        );

        _savedSettings[index] = settingToSave;
        await _saveSettings();

        // オンラインモードの場合はFirebaseにも保存
        if (_isOnlineMode && _firestoreService != null) {
          try {
            await _firestoreService!.saveSetting(settingToSave);
          } catch (e) {
            print('Firebase保存エラー: $e');
          }
        }

        notifyListeners();
      }
    } catch (e) {
      print('Error updating setting: $e');
    }
  }

  // Get visibility settings (create default if not exists)
  VisibilitySettings getVisibilitySettings(String carId) {
    if (!_visibilitySettings.containsKey(carId)) {
      // 車種固有の設定項目リストを取得
      final availableSettings = getCarAvailableSettings(carId);

      // 車種固有の設定項目を使用して表示設定を作成
      _visibilitySettings[carId] = VisibilitySettings.createDefault(carId,
          availableSettings:
              availableSettings.isNotEmpty ? availableSettings : null);
      _saveVisibilitySettings();
    }
    return _visibilitySettings[carId]!;
  }

  // Toggle visibility for a specific setting
  Future<void> toggleSettingVisibility(
      String carId, String settingKey, bool isVisible) async {
    final settings = getVisibilitySettings(carId);
    final updatedVisibility =
        Map<String, bool>.from(settings.settingsVisibility);
    updatedVisibility[settingKey] = isVisible;

    final updatedSettings = VisibilitySettings(
      carId: carId,
      settingsVisibility: updatedVisibility,
      favoriteSettings: settings.favoriteSettings, // favoritesを保持
    );

    await updateVisibilitySettings(updatedSettings);
  }

  // Toggle favorite for a specific setting
  Future<void> toggleFavoriteSetting(
      String carId, String settingKey, bool isFavorite) async {
    final settings = getVisibilitySettings(carId);
    final updatedFavorites = Map<String, bool>.from(settings.favoriteSettings);

    if (isFavorite) {
      updatedFavorites[settingKey] = true;
    } else {
      updatedFavorites.remove(settingKey);
    }

    final updatedSettings = VisibilitySettings(
      carId: carId,
      settingsVisibility: settings.settingsVisibility,
      favoriteSettings: updatedFavorites,
    );

    await updateVisibilitySettings(updatedSettings);
  }

  // Get favorite settings for a car
  List<String> getFavoriteSettings(String carId) {
    final settings = getVisibilitySettings(carId);
    return settings.favoriteSettings.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
  }

  // オンラインモード設定を保存
  Future<void> _saveOnlineMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onlineModeKey, _isOnlineMode);
    } catch (e) {
      print('Error saving online mode: $e');
    }
  }

  // オフラインモードを強制的に有効化
  Future<void> setOfflineMode() async {
    _isOnlineMode = false;
    await _saveOnlineMode();
    notifyListeners();
  }

  // オンラインモードを明示的に有効化
  Future<void> setOnlineMode() async {
    _isOnlineMode = true;

    // オンライン切り替え時にFirestoreServiceが未生成ならここで試行
    if (_firestoreService == null) {
      try {
        _firestoreService = FirestoreService();
      } catch (e) {
        print('FirestoreService initialization failed on setOnlineMode: $e');
        _firestoreService = null;
      }
    }

    await _saveOnlineMode();
    notifyListeners();
  }

  // オンラインモードを切り替え
  Future<void> toggleOnlineMode() async {
    _isOnlineMode = !_isOnlineMode;

    if (_isOnlineMode && _firestoreService == null) {
      try {
        _firestoreService = FirestoreService();
      } catch (e) {
        print('FirestoreService initialization failed on toggleOnlineMode: $e');
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
      print('データをFirebaseに同期しました');
    } catch (e) {
      print('Firebase同期エラー: $e');
      rethrow;
    }
  }

  // Firebaseからデータを読み込み
  Future<void> loadFromFirebase() async {
    if (!_isOnlineMode || _firestoreService == null) return;

    try {
      // 保存された設定を読み込み
      _savedSettings = await _firestoreService!.getSavedSettings();
      _savedSettings.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      _runLogs = await _firestoreService!.getRunLogs();
      _runLogs.sort((a, b) => b.runAt.compareTo(a.runAt));
      _ownedParts = await _firestoreService!.getOwnedParts();

      // 車種リストを読み込み
      _cars = await _firestoreService!.getCars();
      _cars = _mergeBuiltInCars(_cars);

      // 表示設定を読み込み
      _visibilitySettings = await _firestoreService!.getVisibilitySettings();

      // 言語設定を読み込み
      _isEnglish = await _firestoreService!.getLanguageSettings();

      await _saveSettings();
      await _saveRunLogs();
      await _saveOwnedParts();
      await _saveCars();
      await _saveVisibilitySettings();
      await _saveLanguageSettings();
      try {
        await _firestoreService!.saveCars(_cars);
      } catch (e) {
        print('Firebase車種マージ保存エラー: $e');
      }

      notifyListeners();
      print('Firebaseからデータを読み込みました');
    } catch (e) {
      print('Firebase読み込みエラー: $e');
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
    final uniqueName = _createUniqueSettingName(name);
    final newSetting = SavedSetting(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: uniqueName,
      createdAt: DateTime.now(),
      car: car,
      settings: settings,
      kind: kind,
      sourceRunLogId: sourceRunLogId,
      parentSettingId: parentSettingId,
    );

    _savedSettings.insert(0, newSetting);
    await _saveSettings();

    // オンラインモードの場合はFirebaseにも保存
    if (_isOnlineMode && _firestoreService != null) {
      try {
        await _firestoreService!.saveSetting(newSetting);
      } catch (e) {
        print('Firebase保存エラー: $e');
      }
    }

    notifyListeners();
    return newSetting;
  }

  SavedSetting? getLatestSettingForCar(String carId) {
    for (final setting in _savedSettings) {
      if (setting.car.id == carId) {
        return setting;
      }
    }
    return null;
  }

  List<SavedSetting> getSavedSettingsForCar(String carId) {
    return _savedSettings
        .where((setting) => setting.car.id == carId)
        .toList(growable: false);
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
    final effectiveChanges = changes
        .where((change) =>
            change.settingKey.trim().isNotEmpty &&
            change.afterValue != null &&
            change.afterValue.toString().trim().isNotEmpty)
        .toList(growable: false);

    final now = DateTime.now();
    final runLogId = now.microsecondsSinceEpoch.toString();
    SavedSetting? resultSetting;
    if (effectiveChanges.isNotEmpty) {
      final resultSettings = baseSetting != null
          ? Map<String, dynamic>.from(baseSetting.settings)
          : <String, dynamic>{};

      for (final change in effectiveChanges) {
        resultSettings[change.settingKey] = change.afterValue;
      }

      resultSetting = await addSetting(
        _buildRunSettingName(runAt, car),
        car,
        resultSettings,
        kind: SavedSettingKind.runResult,
        sourceRunLogId: runLogId,
        parentSettingId: baseSetting?.id,
      );
    }

    final runLog = RunLog(
      id: runLogId,
      createdAt: now,
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
      changes: effectiveChanges,
    );

    _runLogs.insert(0, runLog);
    _runLogs.sort((a, b) => b.runAt.compareTo(a.runAt));
    await _saveRunLogs();

    if (_isOnlineMode && _firestoreService != null) {
      try {
        await _firestoreService!.saveRunLog(runLog);
      } catch (e) {
        print('Firebase run log save error: $e');
      }
    }

    notifyListeners();
    return runLog;
  }

  Future<void> updateRunLog(RunLog updatedRunLog) async {
    final index =
        _runLogs.indexWhere((runLog) => runLog.id == updatedRunLog.id);
    if (index == -1) {
      return;
    }

    _runLogs[index] = updatedRunLog;
    _runLogs.sort((a, b) => b.runAt.compareTo(a.runAt));
    await _saveRunLogs();

    if (_isOnlineMode && _firestoreService != null) {
      try {
        await _firestoreService!.saveRunLog(updatedRunLog);
      } catch (e) {
        print('Firebase run log save error: $e');
      }
    }

    notifyListeners();
  }

  Future<void> deleteRunLog(String id) async {
    _runLogs.removeWhere((runLog) => runLog.id == id);
    await _saveRunLogs();

    if (_isOnlineMode && _firestoreService != null) {
      try {
        await _firestoreService!.deleteRunLog(id);
      } catch (e) {
        print('Firebase run log delete error: $e');
      }
    }

    notifyListeners();
  }

  String _buildRunSettingName(DateTime runAt, Car car) {
    final formattedDate =
        '${runAt.year}-${runAt.month.toString().padLeft(2, '0')}-${runAt.day.toString().padLeft(2, '0')}';
    return '$formattedDate-${car.name}-run';
  }

  String _createUniqueSettingName(String name, {String? excludeId}) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return name;
    }

    final existingNames = _savedSettings
        .where((setting) => setting.id != excludeId)
        .map((setting) => setting.name.trim())
        .toSet();

    if (!existingNames.contains(trimmedName)) {
      return trimmedName;
    }

    final baseName = _stripCopySuffix(trimmedName);
    var suffix = 1;
    while (existingNames.contains('$baseName ($suffix)')) {
      suffix++;
    }

    return '$baseName ($suffix)';
  }

  String _stripCopySuffix(String name) {
    final match = RegExp(r'^(.*) \((\d+)\)$').firstMatch(name);
    if (match == null) {
      return name;
    }

    final baseName = match.group(1)?.trim();
    return baseName == null || baseName.isEmpty ? name : baseName;
  }

  // 設定削除時にFirebaseからも削除
  Future<void> deleteSetting(String id) async {
    _savedSettings.removeWhere((setting) => setting.id == id);
    await _saveSettings();

    // オンラインモードの場合はFirebaseからも削除
    if (_isOnlineMode && _firestoreService != null) {
      try {
        await _firestoreService!.deleteSetting(id);
      } catch (e) {
        print('Firebase削除エラー: $e');
      }
    }

    notifyListeners();
  }

  // 言語設定変更時にFirebaseにも保存
  Future<void> toggleLanguage() async {
    _isEnglish = !_isEnglish;
    await _saveLanguageSettings();

    // オンラインモードの場合はFirebaseにも保存
    if (_isOnlineMode && _firestoreService != null) {
      try {
        await _firestoreService!.saveLanguageSettings(_isEnglish);
      } catch (e) {
        print('Firebase保存エラー: $e');
      }
    }

    notifyListeners();
  }

  // 表示設定更新時にFirebaseにも保存
  Future<void> setPaperStyleEditor(bool value) async {
    if (_usePaperStyleEditor == value) {
      return;
    }

    _usePaperStyleEditor = value;
    await _saveEditorLayoutSettings();
    notifyListeners();
  }

  Future<void> updateVisibilitySettings(VisibilitySettings settings) async {
    _visibilitySettings[settings.carId] = settings;
    await _saveVisibilitySettings();

    // オンラインモードの場合はFirebaseにも保存
    if (_isOnlineMode && _firestoreService != null) {
      try {
        await _firestoreService!.saveVisibilitySettings(_visibilitySettings);
      } catch (e) {
        print('Firebase保存エラー: $e');
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
      _cars = cars;
      _savedSettings = savedSettings;
      _runLogs = runLogs;
      _ownedParts = ownedParts;
      _runLogs.sort((a, b) => b.runAt.compareTo(a.runAt));
      _visibilitySettings = visibilitySettings;

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
          print('Firebase同期エラー: $e');
        }
      }

      notifyListeners();
    } catch (e) {
      print('データ置き換えエラー: $e');
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
        _cars = cars;
        await _saveCars();
      }

      if (savedSettings != null) {
        _savedSettings = savedSettings;
        await _saveSettings();
      }

      if (runLogs != null) {
        _runLogs = runLogs;
        _runLogs.sort((a, b) => b.runAt.compareTo(a.runAt));
        await _saveRunLogs();
      }

      if (ownedParts != null) {
        _ownedParts = ownedParts;
        await _saveOwnedParts();
      }

      if (visibilitySettings != null) {
        _visibilitySettings = visibilitySettings;
        await _saveVisibilitySettings();
      }

      if (isEnglish != null) {
        _isEnglish = isEnglish;
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
          print('Firebase同期エラー: $e');
        }
      }

      notifyListeners();
    } catch (e) {
      print('部分データ置き換えエラー: $e');
      rethrow;
    }
  }
}
