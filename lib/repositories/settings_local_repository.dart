import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/built_in_car_catalog.dart';
import '../models/car.dart';
import '../models/owned_part.dart';
import '../models/run_log.dart';
import '../models/saved_setting.dart';
import '../models/settings_snapshot_v2.dart';
import '../models/visibility_settings.dart';

/// SettingsProvider が扱うローカル永続化の境界。
///
/// 状態全体を単一の v2 スナップショットとして保存する。旧形式は移行元として
/// 読み込むだけで、このリポジトリから削除・更新しない。
abstract interface class SettingsLocalRepository {
  Future<SettingsSnapshotV2?> loadSnapshot();

  Future<SettingsSnapshotV2> loadLegacySnapshot();

  Future<void> saveSnapshot(SettingsSnapshotV2 snapshot);
}

typedef SharedPreferencesLoader = Future<SharedPreferences> Function();
typedef SharedPreferencesStringWriter = Future<bool> Function(
  SharedPreferences preferences,
  String key,
  String value,
);
typedef SharedPreferencesReloader = Future<void> Function(
  SharedPreferences preferences,
);

final class SettingsSnapshotCacheRecoveryFailure implements Exception {
  const SettingsSnapshotCacheRecoveryFailure({
    required this.writeFailure,
    required this.reloadFailure,
  });

  final Object writeFailure;
  final Object reloadFailure;

  @override
  String toString() {
    return 'Settings snapshot save failed and the SharedPreferences cache '
        'could not be reloaded. The cache may be inconsistent. '
        'Write failure: $writeFailure; reload failure: $reloadFailure';
  }
}

/// SharedPreferences を利用する設定スナップショットの実装。
class SharedPreferencesSettingsLocalRepository
    implements SettingsLocalRepository {
  SharedPreferencesSettingsLocalRepository({
    SharedPreferencesLoader? preferencesLoader,
    SharedPreferencesStringWriter? stringWriter,
    SharedPreferencesReloader? preferencesReloader,
  })  : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance,
        _stringWriter = stringWriter ??
            ((preferences, key, value) => preferences.setString(key, value)),
        _preferencesReloader =
            preferencesReloader ?? ((preferences) => preferences.reload());

  static const settingsStateV2Key = 'settings_state_v2';

  /// 呼び出し元や移行テストで使える短い別名。
  static const snapshotKey = settingsStateV2Key;

  // 旧キーは移行と移行テストのため維持する。
  static const savedSettingsKey = 'saved_settings';
  static const runLogsKey = 'run_logs';
  static const ownedPartsKey = 'owned_parts';
  static const visibilitySettingsKey = 'visibility_settings';
  static const languageKey = 'language_settings';
  static const carsKey = 'cars_settings';
  static const onlineModeKey = 'online_mode';
  static const editorLayoutKey = 'editor_layout_paper';

  final SharedPreferencesLoader _preferencesLoader;
  final SharedPreferencesStringWriter _stringWriter;
  final SharedPreferencesReloader _preferencesReloader;

  @override
  Future<SettingsSnapshotV2?> loadSnapshot() async {
    final preferences = await _preferencesLoader();
    final encodedSnapshot = preferences.getString(settingsStateV2Key);
    if (encodedSnapshot == null) {
      return null;
    }

    return SettingsSnapshotV2.fromJson(jsonDecode(encodedSnapshot));
  }

  @override
  Future<SettingsSnapshotV2> loadLegacySnapshot() async {
    final preferences = await _preferencesLoader();

    final cars = _decodeLegacyList(
          preferences.getString(carsKey),
          key: carsKey,
          fromJson: Car.fromJson,
        ) ??
        BuiltInCarCatalog.create();
    final savedSettings = _decodeLegacyList(
          preferences.getString(savedSettingsKey),
          key: savedSettingsKey,
          fromJson: SavedSetting.fromJson,
        ) ??
        <SavedSetting>[];
    final runLogs = _decodeLegacyList(
          preferences.getString(runLogsKey),
          key: runLogsKey,
          fromJson: RunLog.fromJson,
        ) ??
        <RunLog>[];
    final ownedParts = _decodeLegacyList(
          preferences.getString(ownedPartsKey),
          key: ownedPartsKey,
          fromJson: OwnedPart.fromJson,
        ) ??
        <OwnedPart>[];

    return SettingsSnapshotV2(
      cars: cars,
      savedSettings: savedSettings,
      runLogs: runLogs,
      ownedParts: ownedParts,
      visibilitySettings: _decodeLegacyVisibilitySettings(
        preferences.getString(visibilitySettingsKey),
      ),
      isEnglish: preferences.getBool(languageKey) ?? false,
      usePaperStyleEditor: preferences.getBool(editorLayoutKey) ?? false,
    );
  }

  @override
  Future<void> saveSnapshot(SettingsSnapshotV2 snapshot) async {
    final preferences = await _preferencesLoader();
    try {
      final didSave = await _stringWriter(
        preferences,
        settingsStateV2Key,
        jsonEncode(snapshot.toJson()),
      );
      if (!didSave) {
        throw StateError('Failed to save settings snapshot.');
      }
    } catch (writeFailure, writeStackTrace) {
      try {
        await _preferencesReloader(preferences);
      } catch (reloadFailure, reloadStackTrace) {
        Error.throwWithStackTrace(
          SettingsSnapshotCacheRecoveryFailure(
            writeFailure: writeFailure,
            reloadFailure: reloadFailure,
          ),
          reloadStackTrace,
        );
      }
      Error.throwWithStackTrace(writeFailure, writeStackTrace);
    }
  }

  static List<T>? _decodeLegacyList<T>(
    String? encoded, {
    required String key,
    required T Function(Map<String, dynamic>) fromJson,
  }) {
    if (encoded == null) {
      return null;
    }

    final decoded = jsonDecode(encoded);
    if (decoded is! List<dynamic>) {
      throw FormatException('Legacy setting $key must be a JSON array.');
    }

    return decoded.indexed.map((entry) {
      final (index, item) = entry;
      if (item is! Map<String, dynamic>) {
        throw FormatException(
          'Legacy setting $key[$index] must be a JSON object.',
        );
      }
      return fromJson(item);
    }).toList(growable: false);
  }

  static Map<String, VisibilitySettings> _decodeLegacyVisibilitySettings(
    String? encoded,
  ) {
    if (encoded == null) {
      return <String, VisibilitySettings>{};
    }

    final decoded = jsonDecode(encoded);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Legacy visibility settings must be a JSON object.',
      );
    }

    return decoded.map((carId, settingsJson) {
      if (settingsJson is! Map<String, dynamic>) {
        throw FormatException(
          'Legacy visibility setting for $carId must be a JSON object.',
        );
      }
      return MapEntry(carId, VisibilitySettings.fromJson(settingsJson));
    });
  }
}
