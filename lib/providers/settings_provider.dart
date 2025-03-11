import 'package:flutter/material.dart';
import '../models/saved_setting.dart';
import '../models/car.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  List<SavedSetting> _savedSettings = [];
  final String _storageKey = 'saved_settings';

  List<SavedSetting> get savedSettings => _savedSettings;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_storageKey);
      
      if (settingsJson != null) {
        final List<dynamic> decoded = jsonDecode(settingsJson);
        _savedSettings = decoded
            .map((item) => SavedSetting.fromJson(item))
            .toList();
        
        // 作成日時の降順でソート
        _savedSettings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        
        notifyListeners();
      }
    } catch (e) {
      debugPrint('設定の読み込みエラー: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = jsonEncode(_savedSettings.map((setting) => setting.toJson()).toList());
      await prefs.setString(_storageKey, settingsJson);
    } catch (e) {
      debugPrint('設定の保存エラー: $e');
    }
  }

  Future<void> addSetting(String name, Car car, Map<String, dynamic> settings) async {
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
    final index = _savedSettings.indexWhere((setting) => setting.id == updatedSetting.id);
    if (index != -1) {
      _savedSettings[index] = updatedSetting;
      await _saveSettings();
      notifyListeners();
    }
  }
} 