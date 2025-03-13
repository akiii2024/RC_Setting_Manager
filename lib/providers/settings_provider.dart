import 'package:flutter/material.dart';
import '../models/saved_setting.dart';
import '../models/car.dart';
import '../models/visibility_settings.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  List<SavedSetting> _savedSettings = [];
  Map<String, VisibilitySettings> _visibilitySettings = {};

  final String _savedSettingsKey = 'saved_settings';
  final String _visibilitySettingsKey = 'visibility_settings';

  List<SavedSetting> get savedSettings => _savedSettings;
  Map<String, VisibilitySettings> get visibilitySettings => _visibilitySettings;

  SettingsProvider() {
    _loadSettings();
    _loadVisibilitySettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_savedSettingsKey);

      if (settingsJson != null) {
        final List<dynamic> decoded = jsonDecode(settingsJson);
        _savedSettings =
            decoded.map((item) => SavedSetting.fromJson(item)).toList();

        // 作成日時の降順でソート
        _savedSettings.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        notifyListeners();
      }
    } catch (e) {
      debugPrint('設定の読み込みエラー: $e');
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
      debugPrint('表示設定の読み込みエラー: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = jsonEncode(
          _savedSettings.map((setting) => setting.toJson()).toList());
      await prefs.setString(_savedSettingsKey, settingsJson);
    } catch (e) {
      debugPrint('設定の保存エラー: $e');
    }
  }

  Future<void> _saveVisibilitySettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final visibilityJson = jsonEncode(_visibilitySettings);
      await prefs.setString(_visibilitySettingsKey, visibilityJson);
    } catch (e) {
      debugPrint('表示設定の保存エラー: $e');
    }
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

  // 表示設定の取得（存在しない場合はデフォルト設定を作成）
  VisibilitySettings getVisibilitySettings(String carId) {
    if (!_visibilitySettings.containsKey(carId)) {
      _visibilitySettings[carId] = VisibilitySettings.createDefault(carId);
      _saveVisibilitySettings();
    }
    return _visibilitySettings[carId]!;
  }

  // 表示設定の更新
  Future<void> updateVisibilitySettings(VisibilitySettings settings) async {
    _visibilitySettings[settings.carId] = settings;
    await _saveVisibilitySettings();
    notifyListeners();
  }

  // 特定の設定項目の表示/非表示を切り替え
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
