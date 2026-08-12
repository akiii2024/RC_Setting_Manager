import '../../models/car.dart';
import '../../models/visibility_settings.dart';

typedef AvailableSettingsLookup = List<String> Function(String carId);

/// 表示、言語、編集形式、接続モードの状態を保持する内部ストア。
class DisplaySettingsStore {
  Map<String, VisibilitySettings> _visibilitySettings = {};
  bool _isEnglish = false;
  bool _usePaperStyleEditor = false;
  bool _isOnlineMode = false;

  Map<String, VisibilitySettings> get visibilitySettings => _visibilitySettings;
  bool get isEnglish => _isEnglish;
  bool get usePaperStyleEditor => _usePaperStyleEditor;
  bool get isOnlineMode => _isOnlineMode;

  void replaceVisibilitySettings(
    Map<String, VisibilitySettings> visibilitySettings,
  ) {
    _visibilitySettings = visibilitySettings;
  }

  void setLanguage(bool isEnglish) {
    _isEnglish = isEnglish;
  }

  bool toggleLanguage() {
    _isEnglish = !_isEnglish;
    return _isEnglish;
  }

  bool setPaperStyleEditor(bool value) {
    if (_usePaperStyleEditor == value) {
      return false;
    }
    _usePaperStyleEditor = value;
    return true;
  }

  void setOnlineMode(bool value) {
    _isOnlineMode = value;
  }

  bool toggleOnlineMode() {
    _isOnlineMode = !_isOnlineMode;
    return _isOnlineMode;
  }

  bool initializeVisibilityDefaults(
    Iterable<Car> cars,
    AvailableSettingsLookup availableSettingsForCar,
  ) {
    var didAddDefaults = false;
    for (final car in cars) {
      if (_visibilitySettings.containsKey(car.id)) {
        continue;
      }
      _visibilitySettings[car.id] = _createDefault(
        car.id,
        availableSettingsForCar,
      );
      didAddDefaults = true;
    }
    return didAddDefaults;
  }

  VisibilitySettings visibilityFor(
    String carId,
    AvailableSettingsLookup availableSettingsForCar,
  ) {
    return _visibilitySettings.putIfAbsent(
      carId,
      () => _createDefault(carId, availableSettingsForCar),
    );
  }

  VisibilitySettings withVisibility(
    String carId,
    String settingKey,
    bool isVisible,
    AvailableSettingsLookup availableSettingsForCar,
  ) {
    final current = visibilityFor(carId, availableSettingsForCar);
    return VisibilitySettings(
      carId: carId,
      settingsVisibility: Map<String, bool>.from(current.settingsVisibility)
        ..[settingKey] = isVisible,
      favoriteSettings: current.favoriteSettings,
    );
  }

  VisibilitySettings withFavorite(
    String carId,
    String settingKey,
    bool isFavorite,
    AvailableSettingsLookup availableSettingsForCar,
  ) {
    final current = visibilityFor(carId, availableSettingsForCar);
    final favorites = Map<String, bool>.from(current.favoriteSettings);
    if (isFavorite) {
      favorites[settingKey] = true;
    } else {
      favorites.remove(settingKey);
    }
    return VisibilitySettings(
      carId: carId,
      settingsVisibility: current.settingsVisibility,
      favoriteSettings: favorites,
    );
  }

  List<String> favoriteSettings(
    String carId,
    AvailableSettingsLookup availableSettingsForCar,
  ) {
    return visibilityFor(carId, availableSettingsForCar)
        .favoriteSettings
        .entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
  }

  void updateVisibility(VisibilitySettings settings) {
    _visibilitySettings[settings.carId] = settings;
  }

  VisibilitySettings _createDefault(
    String carId,
    AvailableSettingsLookup availableSettingsForCar,
  ) {
    final availableSettings = availableSettingsForCar(carId);
    return VisibilitySettings.createDefault(
      carId,
      availableSettings:
          availableSettings.isNotEmpty ? availableSettings : null,
    );
  }
}
