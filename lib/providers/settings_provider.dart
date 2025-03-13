import 'package:flutter/material.dart';
import '../models/saved_setting.dart';
import '../models/car.dart';
import '../models/visibility_settings.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  List<SavedSetting> _savedSettings = [];
  Map<String, VisibilitySettings> _visibilitySettings = {};
  bool _isEnglish = false;
  List<Car> _cars = []; // 車種リストを保持

  final String _savedSettingsKey = 'saved_settings';
  final String _visibilitySettingsKey = 'visibility_settings';
  final String _languageKey = 'language_settings';
  final String _carsKey = 'cars_settings';

  List<SavedSetting> get savedSettings => _savedSettings;
  Map<String, VisibilitySettings> get visibilitySettings => _visibilitySettings;
  bool get isEnglish => _isEnglish;
  List<Car> get cars => _cars;

  SettingsProvider() {
    _loadSettings();
    _loadVisibilitySettings();
    _loadLanguageSettings();
    _loadCars();
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

  // 車種を追加
  Future<void> addCar(Car car) async {
    _cars.add(car);
    await _saveCars();
    notifyListeners();
  }

  // 車種を更新
  Future<void> updateCar(Car updatedCar) async {
    final index = _cars.indexWhere((car) => car.id == updatedCar.id);
    if (index != -1) {
      _cars[index] = updatedCar;
      await _saveCars();
      notifyListeners();
    }
  }

  // 車種を削除
  Future<void> deleteCar(String carId) async {
    _cars.removeWhere((car) => car.id == carId);
    await _saveCars();
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

  Future<void> toggleLanguage() async {
    _isEnglish = !_isEnglish;
    await _saveLanguageSettings();
    notifyListeners();
  }

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
    notifyListeners();
  }

  Future<void> deleteSetting(String id) async {
    _savedSettings.removeWhere((setting) => setting.id == id);
    await _saveSettings();
    notifyListeners();
  }

  Future<void> updateSetting(SavedSetting updatedSetting) async {
    final index =
        _savedSettings.indexWhere((setting) => setting.id == updatedSetting.id);
    if (index != -1) {
      _savedSettings[index] = updatedSetting;
      await _saveSettings();
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

  // Update visibility settings
  Future<void> updateVisibilitySettings(VisibilitySettings settings) async {
    _visibilitySettings[settings.carId] = settings;
    await _saveVisibilitySettings();
    notifyListeners();
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
}
