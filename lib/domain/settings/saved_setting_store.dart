import '../../models/car.dart';
import '../../models/saved_setting.dart';
import 'setting_name_policy.dart';

/// 保存済みセッティングの状態と命名規則を保持する内部ストア。
class SavedSettingStore {
  SavedSettingStore({required String Function() idGenerator})
      : _idGenerator = idGenerator;

  final String Function() _idGenerator;
  List<SavedSetting> _settings = [];

  List<SavedSetting> get settings => _settings;

  void replace(
    List<SavedSetting> settings, {
    bool sortNewestFirst = false,
  }) {
    _settings = settings;
    if (sortNewestFirst) {
      _settings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
  }

  SavedSetting? update(SavedSetting updatedSetting) {
    final index = _settings.indexWhere(
      (setting) => setting.id == updatedSetting.id,
    );
    if (index == -1) {
      return null;
    }

    final settingToSave = SavedSetting(
      id: updatedSetting.id,
      name: SettingNamePolicy.uniqueName(
        updatedSetting.name,
        _settings,
        excludeId: updatedSetting.id,
      ),
      createdAt: updatedSetting.createdAt,
      car: updatedSetting.car,
      settings: updatedSetting.settings,
      kind: updatedSetting.kind,
      sourceRunLogId: updatedSetting.sourceRunLogId,
      parentSettingId: updatedSetting.parentSettingId,
    );
    _settings[index] = settingToSave;
    return settingToSave;
  }

  SavedSetting add(
    String name,
    Car car,
    Map<String, dynamic> settings, {
    SavedSettingKind kind = SavedSettingKind.manual,
    String? sourceRunLogId,
    String? parentSettingId,
  }) {
    final newSetting = SavedSetting(
      id: _idGenerator(),
      name: SettingNamePolicy.uniqueName(name, _settings),
      createdAt: DateTime.now(),
      car: car,
      settings: settings,
      kind: kind,
      sourceRunLogId: sourceRunLogId,
      parentSettingId: parentSettingId,
    );
    _settings.insert(0, newSetting);
    return newSetting;
  }

  void delete(String id) {
    _settings.removeWhere((setting) => setting.id == id);
  }

  SavedSetting? latestForCar(String carId) {
    for (final setting in _settings) {
      if (setting.car.id == carId) {
        return setting;
      }
    }
    return null;
  }

  List<SavedSetting> forCar(String carId) {
    return _settings
        .where((setting) => setting.car.id == carId)
        .toList(growable: false);
  }

  String runResultName(DateTime runAt, Car car) {
    return SettingNamePolicy.runResultName(runAt, car);
  }
}
