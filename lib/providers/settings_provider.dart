import 'package:flutter/material.dart';
import '../models/saved_setting.dart';
import '../models/car.dart';
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

  final String _savedSettingsKey = 'saved_settings';
  final String _visibilitySettingsKey = 'visibility_settings';
  final String _languageKey = 'language_settings';
  final String _carsKey = 'cars_settings';
  final String _onlineModeKey = 'online_mode';
  
  final FirestoreService _firestoreService = FirestoreService();

  List<SavedSetting> get savedSettings => _savedSettings;
  Map<String, VisibilitySettings> get visibilitySettings => _visibilitySettings;
  bool get isEnglish => _isEnglish;
  List<Car> get cars => _cars;
  bool get isOnlineMode => _isOnlineMode;

  SettingsProvider() {
    _loadSettings();
    _loadVisibilitySettings();
    _loadLanguageSettings();
    _loadCars();
    _loadOnlineMode();
  }

  // 車種リストを読み込み
  Future<void> _loadCars() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final carsJson = prefs.getString(_carsKey);

      if (carsJson != null) {
        final List<dynamic> decoded = jsonDecode(carsJson);
        _cars = decoded.map((item) => Car.fromJson(item)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading cars: $e');
    }
  }

  // 車種リストを保存
  Future<void> _saveCars() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final carsJson = jsonEncode(_cars.map((car) => car.toJson()).toList());
      await prefs.setString(_carsKey, carsJson);
    } catch (e) {
      debugPrint('Error saving cars: $e');
    }
  }

  // 車種を更新
  Future<void> updateCar(Car updatedCar) async {
    final index = _cars.indexWhere((car) => car.id == updatedCar.id);
    if (index != -1) {
      _cars[index] = updatedCar;
      await _saveCars();
      
      // オンラインモードの場合はFirebaseにも保存
      if (_isOnlineMode) {
        try {
          await _firestoreService.saveCars(_cars);
        } catch (e) {
          debugPrint('Firebase保存エラー: $e');
        }
      }
      
      notifyListeners();
    }
  }

  // 車種を削除
  Future<void> deleteCar(String carId) async {
    _cars.removeWhere((car) => car.id == carId);
    await _saveCars();
    
    // オンラインモードの場合はFirebaseにも保存
    if (_isOnlineMode) {
      try {
        await _firestoreService.saveCars(_cars);
      } catch (e) {
        debugPrint('Firebase保存エラー: $e');
      }
    }
    
    notifyListeners();
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

        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
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

        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading visibility settings: $e');
    }
  }

  Future<void> _loadLanguageSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnglish = prefs.getBool(_languageKey) ?? false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading language settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = jsonEncode(
          _savedSettings.map((setting) => setting.toJson()).toList());
      await prefs.setString(_savedSettingsKey, settingsJson);
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }

  Future<void> _saveVisibilitySettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final visibilityJson = jsonEncode(_visibilitySettings);
      await prefs.setString(_visibilitySettingsKey, visibilityJson);
    } catch (e) {
      debugPrint('Error saving visibility settings: $e');
    }
  }

  Future<void> _saveLanguageSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_languageKey, _isEnglish);
    } catch (e) {
      debugPrint('Error saving language settings: $e');
    }
  }


  Future<void> updateSetting(SavedSetting updatedSetting) async {
    final index =
        _savedSettings.indexWhere((setting) => setting.id == updatedSetting.id);
    if (index != -1) {
      _savedSettings[index] = updatedSetting;
      await _saveSettings();
      
      // オンラインモードの場合はFirebaseにも保存
      if (_isOnlineMode) {
        try {
          await _firestoreService.saveSetting(updatedSetting);
        } catch (e) {
          debugPrint('Firebase保存エラー: $e');
        }
      }
      
      notifyListeners();
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
    );

    await updateVisibilitySettings(updatedSettings);
  }

  // オンラインモード設定を読み込み
  Future<void> _loadOnlineMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isOnlineMode = prefs.getBool(_onlineModeKey) ?? false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading online mode: $e');
    }
  }

  // オンラインモード設定を保存
  Future<void> _saveOnlineMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onlineModeKey, _isOnlineMode);
    } catch (e) {
      debugPrint('Error saving online mode: $e');
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
    if (!_isOnlineMode) return;
    
    try {
      await _firestoreService.syncAllData(
        savedSettings: _savedSettings,
        cars: _cars,
        visibilitySettings: _visibilitySettings,
        isEnglish: _isEnglish,
      );
      debugPrint('データをFirebaseに同期しました');
    } catch (e) {
      debugPrint('Firebase同期エラー: $e');
      rethrow;
    }
  }

  // Firebaseからデータを読み込み
  Future<void> loadFromFirebase() async {
    if (!_isOnlineMode) return;
    
    try {
      // 保存された設定を読み込み
      _savedSettings = await _firestoreService.getSavedSettings();
      _savedSettings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      // 車種リストを読み込み
      _cars = await _firestoreService.getCars();
      
      // 表示設定を読み込み
      _visibilitySettings = await _firestoreService.getVisibilitySettings();
      
      // 言語設定を読み込み
      _isEnglish = await _firestoreService.getLanguageSettings();
      
      notifyListeners();
      debugPrint('Firebaseからデータを読み込みました');
    } catch (e) {
      debugPrint('Firebase読み込みエラー: $e');
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
    if (_isOnlineMode) {
      try {
        await _firestoreService.saveSetting(newSetting);
      } catch (e) {
        debugPrint('Firebase保存エラー: $e');
      }
    }
    
    notifyListeners();
  }

  // 設定削除時にFirebaseからも削除
  Future<void> deleteSetting(String id) async {
    _savedSettings.removeWhere((setting) => setting.id == id);
    await _saveSettings();
    
    // オンラインモードの場合はFirebaseからも削除
    if (_isOnlineMode) {
      try {
        await _firestoreService.deleteSetting(id);
      } catch (e) {
        debugPrint('Firebase削除エラー: $e');
      }
    }
    
    notifyListeners();
  }

  // 車種追加時にFirebaseにも保存
  Future<void> addCar(Car car) async {
    _cars.add(car);
    await _saveCars();
    
    // オンラインモードの場合はFirebaseにも保存
    if (_isOnlineMode) {
      try {
        await _firestoreService.saveCars(_cars);
      } catch (e) {
        debugPrint('Firebase保存エラー: $e');
      }
    }
    
    notifyListeners();
  }

  // 言語設定変更時にFirebaseにも保存
  Future<void> toggleLanguage() async {
    _isEnglish = !_isEnglish;
    await _saveLanguageSettings();
    
    // オンラインモードの場合はFirebaseにも保存
    if (_isOnlineMode) {
      try {
        await _firestoreService.saveLanguageSettings(_isEnglish);
      } catch (e) {
        debugPrint('Firebase保存エラー: $e');
      }
    }
    
    notifyListeners();
  }

  // 表示設定更新時にFirebaseにも保存
  Future<void> updateVisibilitySettings(VisibilitySettings settings) async {
    _visibilitySettings[settings.carId] = settings;
    await _saveVisibilitySettings();
    
    // オンラインモードの場合はFirebaseにも保存
    if (_isOnlineMode) {
      try {
        await _firestoreService.saveVisibilitySettings(_visibilitySettings);
      } catch (e) {
        debugPrint('Firebase保存エラー: $e');
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
      if (_isOnlineMode) {
        try {
          await _firestoreService.syncAllData(
            savedSettings: _savedSettings,
            cars: _cars,
            visibilitySettings: _visibilitySettings,
            isEnglish: _isEnglish,
          );
        } catch (e) {
          debugPrint('Firebase同期エラー: $e');
        }
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('データ置き換えエラー: $e');
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
      if (_isOnlineMode) {
        try {
          await _firestoreService.syncAllData(
            savedSettings: _savedSettings,
            cars: _cars,
            visibilitySettings: _visibilitySettings,
            isEnglish: _isEnglish,
          );
        } catch (e) {
          debugPrint('Firebase同期エラー: $e');
        }
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('部分データ置き換えエラー: $e');
      rethrow;
    }
  }
}
