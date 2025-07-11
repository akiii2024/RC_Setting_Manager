import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/saved_setting.dart';
import '../models/car.dart';
import '../models/manufacturer.dart';
import '../models/visibility_settings.dart';
import '../services/firestore_service.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  List<SavedSetting> _savedSettings = [];
  Map<String, VisibilitySettings> _visibilitySettings = {};
  bool _isEnglish = false;
  List<Car> _cars = []; // 車種リストを保持
  bool _isOnlineMode = false; // オンラインモードかどうか
  bool _isInitialized = false; // 初期化完了フラグ

  final String _savedSettingsKey = 'saved_settings';
  final String _visibilitySettingsKey = 'visibility_settings';
  final String _languageKey = 'language_settings';
  final String _carsKey = 'cars_settings';
  final String _onlineModeKey = 'online_mode';

  FirestoreService? _firestoreService;

  List<SavedSetting> get savedSettings => _savedSettings;
  Map<String, VisibilitySettings> get visibilitySettings => _visibilitySettings;
  bool get isEnglish => _isEnglish;
  List<Car> get cars => _cars;
  bool get isOnlineMode => _isOnlineMode;
  bool get isInitialized => _isInitialized;

  SettingsProvider() {
    _initializeAsync();
  }

  // 非同期初期化を安全に実行
  Future<void> _initializeAsync() async {
    try {
      // FirestoreServiceを安全に初期化
      try {
        _firestoreService = FirestoreService();
      } catch (e) {
        print('FirestoreService initialization failed: $e');
        _firestoreService = null;
      }

      // 各設定を順次読み込み（並行処理を避ける）
      await _loadCars();
      await _loadSettings();
      await _loadVisibilitySettings();
      await _loadLanguageSettings();
      await _loadOnlineMode();

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

  // 車種リストを読み込み
  Future<void> _loadCars() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final carsJson = prefs.getString(_carsKey);

      if (carsJson != null) {
        final List<dynamic> decoded = jsonDecode(carsJson);
        _cars = decoded.map((item) => Car.fromJson(item)).toList();
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

        // ヨコモの車種
        Car(
          id: 'yokomo/bd12',
          name: 'BD12',
          imageUrl: 'assets/images/bd12.jpg',
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

  // 車種を更新
  Future<void> updateCar(Car updatedCar) async {
    try {
      final index = _cars.indexWhere((car) => car.id == updatedCar.id);
      if (index != -1) {
        _cars[index] = updatedCar;
        await _saveCars();

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
    await _saveCars();

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
    await _saveCars();

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
    return manufacturers.values.toList();
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
    return car?.availableSettings ?? [];
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

  Future<void> updateSetting(SavedSetting updatedSetting) async {
    try {
      final index = _savedSettings
          .indexWhere((setting) => setting.id == updatedSetting.id);
      if (index != -1) {
        _savedSettings[index] = updatedSetting;
        await _saveSettings();

        // オンラインモードの場合はFirebaseにも保存
        if (_isOnlineMode && _firestoreService != null) {
          try {
            await _firestoreService!.saveSetting(updatedSetting);
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

  // オンラインモードを切り替え
  Future<void> toggleOnlineMode() async {
    _isOnlineMode = !_isOnlineMode;
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
        cars: _cars,
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

      // 車種リストを読み込み
      _cars = await _firestoreService!.getCars();

      // 表示設定を読み込み
      _visibilitySettings = await _firestoreService!.getVisibilitySettings();

      // 言語設定を読み込み
      _isEnglish = await _firestoreService!.getLanguageSettings();

      notifyListeners();
      print('Firebaseからデータを読み込みました');
    } catch (e) {
      print('Firebase読み込みエラー: $e');
      rethrow;
    }
  }

  // 設定追加時にFirebaseにも保存
  Future<void> addSetting(
      String name, Car car, Map<String, dynamic> settings) async {
    final newSetting = SavedSetting(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      createdAt: DateTime.now(),
      car: car,
      settings: settings,
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
    required Map<String, VisibilitySettings> visibilitySettings,
  }) async {
    try {
      // データを置き換え
      _cars = cars;
      _savedSettings = savedSettings;
      _visibilitySettings = visibilitySettings;

      // ローカルストレージに保存
      await _saveCars();
      await _saveSettings();
      await _saveVisibilitySettings();

      // オンラインモードの場合はFirebaseにも同期
      if (_isOnlineMode && _firestoreService != null) {
        try {
          await _firestoreService!.syncAllData(
            savedSettings: _savedSettings,
            cars: _cars,
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
            cars: _cars,
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
