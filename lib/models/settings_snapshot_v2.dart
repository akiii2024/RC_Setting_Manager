import 'car.dart';
import 'owned_part.dart';
import 'run_log.dart';
import 'saved_setting.dart';
import 'visibility_settings.dart';

/// SettingsProvider のローカル状態を一括保存する v2 スナップショット。
///
/// オンラインモードとテーマは、それぞれ別の Provider が所有するため含めない。
class SettingsSnapshotV2 {
  SettingsSnapshotV2({
    required List<Car> cars,
    required List<SavedSetting> savedSettings,
    required List<RunLog> runLogs,
    required List<OwnedPart> ownedParts,
    required Map<String, VisibilitySettings> visibilitySettings,
    required this.isEnglish,
    required this.usePaperStyleEditor,
  })  : cars = List<Car>.unmodifiable(cars),
        savedSettings = List<SavedSetting>.unmodifiable(savedSettings),
        runLogs = List<RunLog>.unmodifiable(runLogs),
        ownedParts = List<OwnedPart>.unmodifiable(ownedParts),
        visibilitySettings =
            Map<String, VisibilitySettings>.unmodifiable(visibilitySettings);

  static const int schemaVersion = 2;

  final List<Car> cars;
  final List<SavedSetting> savedSettings;
  final List<RunLog> runLogs;
  final List<OwnedPart> ownedParts;
  final Map<String, VisibilitySettings> visibilitySettings;
  final bool isEnglish;
  final bool usePaperStyleEditor;

  factory SettingsSnapshotV2.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException(
        'Settings snapshot must be a JSON object.',
      );
    }

    final version = json['schemaVersion'];
    if (version is! int) {
      throw const FormatException(
        'Settings snapshot schemaVersion must be an integer.',
      );
    }
    if (version != schemaVersion) {
      throw FormatException(
        'Unsupported settings snapshot schemaVersion: $version.',
      );
    }

    final cars = _decodeModelList(json, 'cars', Car.fromJsonStrict);
    final savedSettings = _decodeModelList(
      json,
      'savedSettings',
      SavedSetting.fromJsonStrict,
    );
    final runLogs = _decodeModelList(
      json,
      'runLogs',
      RunLog.fromJsonStrict,
    );
    final ownedParts = _decodeModelList(
      json,
      'ownedParts',
      OwnedPart.fromJsonStrict,
    );
    final visibilitySettings = _decodeVisibilitySettings(
      json['visibilitySettings'],
    );

    _validateUniqueIds('cars', cars.map((value) => value.id));
    _validateUniqueIds(
      'savedSettings',
      savedSettings.map((value) => value.id),
    );
    _validateUniqueIds('runLogs', runLogs.map((value) => value.id));
    _validateUniqueIds('ownedParts', ownedParts.map((value) => value.id));
    for (final entry in visibilitySettings.entries) {
      if (entry.key != entry.value.carId) {
        throw FormatException(
          'VisibilitySettings key ${entry.key} does not match carId '
          '${entry.value.carId}.',
        );
      }
    }

    return SettingsSnapshotV2(
      cars: cars,
      savedSettings: savedSettings,
      runLogs: runLogs,
      ownedParts: ownedParts,
      visibilitySettings: visibilitySettings,
      isEnglish: _decodeBool(json, 'isEnglish'),
      usePaperStyleEditor: _decodeBool(json, 'usePaperStyleEditor'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'cars': cars.map((car) => car.toJson()).toList(growable: false),
      'savedSettings': savedSettings
          .map((setting) => setting.toJson())
          .toList(growable: false),
      'runLogs':
          runLogs.map((runLog) => runLog.toJson()).toList(growable: false),
      'ownedParts':
          ownedParts.map((part) => part.toJson()).toList(growable: false),
      'visibilitySettings': visibilitySettings.map(
        (carId, settings) => MapEntry(carId, settings.toJson()),
      ),
      'isEnglish': isEnglish,
      'usePaperStyleEditor': usePaperStyleEditor,
    };
  }

  SettingsSnapshotV2 copyWith({
    List<Car>? cars,
    List<SavedSetting>? savedSettings,
    List<RunLog>? runLogs,
    List<OwnedPart>? ownedParts,
    Map<String, VisibilitySettings>? visibilitySettings,
    bool? isEnglish,
    bool? usePaperStyleEditor,
  }) {
    return SettingsSnapshotV2(
      cars: cars ?? this.cars,
      savedSettings: savedSettings ?? this.savedSettings,
      runLogs: runLogs ?? this.runLogs,
      ownedParts: ownedParts ?? this.ownedParts,
      visibilitySettings: visibilitySettings ?? this.visibilitySettings,
      isEnglish: isEnglish ?? this.isEnglish,
      usePaperStyleEditor: usePaperStyleEditor ?? this.usePaperStyleEditor,
    );
  }

  static List<T> _decodeModelList<T>(
    Map<String, dynamic> json,
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final value = json[key];
    if (value is! List<dynamic>) {
      throw FormatException('Settings snapshot $key must be a JSON array.');
    }

    return value.indexed.map((entry) {
      final (index, item) = entry;
      if (item is! Map<String, dynamic>) {
        throw FormatException(
          'Settings snapshot $key[$index] must be a JSON object.',
        );
      }
      return fromJson(item);
    }).toList(growable: false);
  }

  static Map<String, VisibilitySettings> _decodeVisibilitySettings(
    Object? value,
  ) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException(
        'Settings snapshot visibilitySettings must be a JSON object.',
      );
    }

    return value.map((carId, settingsJson) {
      if (settingsJson is! Map<String, dynamic>) {
        throw FormatException(
          'Settings snapshot visibilitySettings[$carId] must be a JSON object.',
        );
      }
      return MapEntry(carId, VisibilitySettings.fromJsonStrict(settingsJson));
    });
  }

  static void _validateUniqueIds(String field, Iterable<String> ids) {
    final seen = <String>{};
    for (final id in ids) {
      if (!seen.add(id)) {
        throw FormatException(
            'Settings snapshot $field contains duplicate id $id.');
      }
    }
  }

  static bool _decodeBool(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! bool) {
      throw FormatException('Settings snapshot $key must be a boolean.');
    }
    return value;
  }
}
