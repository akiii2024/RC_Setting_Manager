import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rc_setting_manager/models/car.dart';
import 'package:rc_setting_manager/models/manufacturer.dart';
import 'package:rc_setting_manager/models/owned_part.dart';
import 'package:rc_setting_manager/models/run_log.dart';
import 'package:rc_setting_manager/models/saved_setting.dart';
import 'package:rc_setting_manager/models/settings_operation_result.dart';
import 'package:rc_setting_manager/models/settings_snapshot_v2.dart';
import 'package:rc_setting_manager/models/visibility_settings.dart';
import 'package:rc_setting_manager/providers/app_mode_provider.dart';
import 'package:rc_setting_manager/providers/settings_provider.dart';
import 'package:rc_setting_manager/repositories/settings_local_repository.dart';

Car _car() {
  return Car(
    id: 'custom/test-car',
    name: 'Test Car',
    imageUrl: '',
    manufacturer: Manufacturer(
      id: 'test',
      name: 'Test',
      logoPath: '',
    ),
    category: 'touring',
  );
}

SettingsSnapshotV2 _snapshot() {
  final car = _car();
  final setting = SavedSetting(
    id: 'setting-1',
    name: 'Setting',
    createdAt: DateTime.utc(2026, 8, 19),
    car: car,
    settings: const {'frontCamber': 1.5},
  );
  final runLog = RunLog(
    id: 'run-1',
    createdAt: DateTime.utc(2026, 8, 19, 1),
    runAt: DateTime.utc(2026, 8, 19, 2),
    car: car,
    baseSettingId: setting.id,
    bestLapMillis: 12345,
    feelTagIds: const ['stable'],
    memo: 'memo',
    changes: const [],
  );
  final part = OwnedPart(
    id: 'part-1',
    category: 'motor',
    name: 'Motor',
    createdAt: DateTime.utc(2026, 8, 19, 3),
  );
  final visibility = VisibilitySettings(
    carId: car.id,
    settingsVisibility: const {'motor': true},
    favoriteSettings: const {'motor': true},
  );

  return SettingsSnapshotV2(
    cars: [car],
    savedSettings: [setting],
    runLogs: [runLog],
    ownedParts: [part],
    visibilitySettings: {car.id: visibility},
    isEnglish: true,
    usePaperStyleEditor: true,
  );
}

void main() {
  group('SettingsSnapshotV2', () {
    test('all state is round-tripped with the v2 top-level shape', () {
      final source = _snapshot();

      final encoded = jsonEncode(source.toJson());
      final decoded = SettingsSnapshotV2.fromJson(jsonDecode(encoded));

      expect(
        (jsonDecode(encoded) as Map<String, dynamic>).keys,
        unorderedEquals(const {
          'schemaVersion',
          'cars',
          'savedSettings',
          'runLogs',
          'ownedParts',
          'visibilitySettings',
          'isEnglish',
          'usePaperStyleEditor',
        }),
      );
      expect(decoded.cars.single.id, source.cars.single.id);
      expect(decoded.savedSettings.single.id, source.savedSettings.single.id);
      expect(decoded.runLogs.single.id, source.runLogs.single.id);
      expect(decoded.ownedParts.single.id, source.ownedParts.single.id);
      expect(
        decoded.visibilitySettings[_car().id]?.favoriteSettings,
        const {'motor': true},
      );
      expect(decoded.isEnglish, isTrue);
      expect(decoded.usePaperStyleEditor, isTrue);
    });

    test('rejects non-object, missing version, and unsupported version', () {
      expect(
        () => SettingsSnapshotV2.fromJson(const <Object>[]),
        throwsFormatException,
      );
      expect(
        () => SettingsSnapshotV2.fromJson(const <String, dynamic>{}),
        throwsFormatException,
      );

      final unsupported = _snapshot().toJson()..['schemaVersion'] = 3;
      expect(
        () => SettingsSnapshotV2.fromJson(unsupported),
        throwsFormatException,
      );
    });

    test('rejects a missing or incorrectly typed required state field', () {
      final missingCars = _snapshot().toJson()..remove('cars');
      final invalidLanguage = _snapshot().toJson()..['isEnglish'] = 'true';

      expect(
        () => SettingsSnapshotV2.fromJson(missingCars),
        throwsFormatException,
      );
      expect(
        () => SettingsSnapshotV2.fromJson(invalidLanguage),
        throwsFormatException,
      );
    });

    test('rejects nested corruption and duplicate identifiers', () {
      final missingRunLogId = _snapshot().toJson();
      final runLog = (missingRunLogId['runLogs'] as List<dynamic>).single
          as Map<String, dynamic>;
      runLog.remove('id');

      final unknownKind = _snapshot().toJson();
      final setting = (unknownKind['savedSettings'] as List<dynamic>).single
          as Map<String, dynamic>;
      setting['kind'] = 'future-kind';

      final duplicateSetting = _snapshot().toJson();
      final settings = List<dynamic>.of(
        duplicateSetting['savedSettings'] as List<dynamic>,
      );
      settings.add(Map<String, dynamic>.from(settings.single as Map));
      duplicateSetting['savedSettings'] = settings;

      expect(
        () => SettingsSnapshotV2.fromJson(missingRunLogId),
        throwsFormatException,
      );
      expect(
        () => SettingsSnapshotV2.fromJson(unknownKind),
        throwsFormatException,
      );
      expect(
        () => SettingsSnapshotV2.fromJson(duplicateSetting),
        throwsFormatException,
      );
    });

    test('legacy model decoding remains tolerant of newly added fields', () {
      final legacy = _snapshot().savedSettings.single.toJson()..remove('kind');

      expect(
        SavedSetting.fromJson(legacy).kind,
        SavedSettingKind.manual,
      );
    });
  });

  group('SharedPreferencesSettingsLocalRepository', () {
    test('returns null only when the v2 key is absent', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = SharedPreferencesSettingsLocalRepository();

      expect(await repository.loadSnapshot(), isNull);
    });

    test('saves and loads one v2 value without changing legacy keys', () async {
      const legacyCars = 'legacy-cars';
      SharedPreferences.setMockInitialValues({
        SharedPreferencesSettingsLocalRepository.carsKey: legacyCars,
        SharedPreferencesSettingsLocalRepository.onlineModeKey: true,
      });
      final repository = SharedPreferencesSettingsLocalRepository();

      await repository.saveSnapshot(_snapshot());
      final loaded = await repository.loadSnapshot();
      final preferences = await SharedPreferences.getInstance();

      expect(loaded?.cars.single.id, _car().id);
      expect(
        preferences.getString(
          SharedPreferencesSettingsLocalRepository.carsKey,
        ),
        legacyCars,
      );
      expect(
        preferences.getBool(
          SharedPreferencesSettingsLocalRepository.onlineModeKey,
        ),
        isTrue,
      );
    });

    test('treats a false setString result as a snapshot write failure',
        () async {
      final oldJson = _snapshot().toJson()..['isEnglish'] = false;
      final oldEncoded = jsonEncode(oldJson);
      SharedPreferences.setMockInitialValues({
        SharedPreferencesSettingsLocalRepository.settingsStateV2Key: oldEncoded,
      });
      final preferences = await SharedPreferences.getInstance();
      var writerCalls = 0;
      var reloadCalls = 0;
      final repository = SharedPreferencesSettingsLocalRepository(
        preferencesLoader: () async => preferences,
        stringWriter: (preferences, key, value) async {
          writerCalls++;
          expect(
            key,
            SharedPreferencesSettingsLocalRepository.settingsStateV2Key,
          );
          expect(value, isNotEmpty);
          await preferences.setString(key, value);
          SharedPreferences.setMockInitialValues({key: oldEncoded});
          return false;
        },
        preferencesReloader: (preferences) async {
          reloadCalls++;
          await preferences.reload();
        },
      );

      await expectLater(repository.saveSnapshot(_snapshot()), throwsStateError);

      expect(writerCalls, 1);
      expect(reloadCalls, 1);
      expect((await repository.loadSnapshot())?.isEnglish, isFalse);
    });

    test('reloads cache and rethrows the original writer exception', () async {
      final oldJson = _snapshot().toJson()..['isEnglish'] = false;
      final oldEncoded = jsonEncode(oldJson);
      SharedPreferences.setMockInitialValues({
        SharedPreferencesSettingsLocalRepository.settingsStateV2Key: oldEncoded,
      });
      final preferences = await SharedPreferences.getInstance();
      final writeFailure = StateError('platform write failed');
      var reloadCalls = 0;
      final repository = SharedPreferencesSettingsLocalRepository(
        preferencesLoader: () async => preferences,
        stringWriter: (preferences, key, value) async {
          await preferences.setString(key, value);
          SharedPreferences.setMockInitialValues({key: oldEncoded});
          throw writeFailure;
        },
        preferencesReloader: (preferences) async {
          reloadCalls++;
          await preferences.reload();
        },
      );

      await expectLater(
        repository.saveSnapshot(_snapshot()),
        throwsA(same(writeFailure)),
      );
      expect(reloadCalls, 1);
      expect((await repository.loadSnapshot())?.isEnglish, isFalse);
    });

    test('reports an explicit cache recovery failure when reload also fails',
        () async {
      SharedPreferences.setMockInitialValues({});
      final writeFailure = StateError('platform write failed');
      final reloadFailure = StateError('cache reload failed');
      final repository = SharedPreferencesSettingsLocalRepository(
        stringWriter: (preferences, key, value) async => throw writeFailure,
        preferencesReloader: (preferences) async => throw reloadFailure,
      );

      await expectLater(
        repository.saveSnapshot(_snapshot()),
        throwsA(
          isA<SettingsSnapshotCacheRecoveryFailure>()
              .having(
                (failure) => failure.writeFailure,
                'writeFailure',
                same(writeFailure),
              )
              .having(
                (failure) => failure.reloadFailure,
                'reloadFailure',
                same(reloadFailure),
              ),
        ),
      );
    });

    test('failed legacy migration is a startup error and preserves old keys',
        () async {
      final source = _snapshot();
      final legacyCars =
          jsonEncode(source.cars.map((car) => car.toJson()).toList());
      final legacySettings = jsonEncode(
        source.savedSettings.map((setting) => setting.toJson()).toList(),
      );
      final legacyRunLogs =
          jsonEncode(source.runLogs.map((log) => log.toJson()).toList());
      final legacyOwnedParts =
          jsonEncode(source.ownedParts.map((part) => part.toJson()).toList());
      final legacyVisibility = jsonEncode(
        source.visibilitySettings.map(
          (carId, settings) => MapEntry(carId, settings.toJson()),
        ),
      );
      SharedPreferences.setMockInitialValues({
        SharedPreferencesSettingsLocalRepository.carsKey: legacyCars,
        SharedPreferencesSettingsLocalRepository.savedSettingsKey:
            legacySettings,
        SharedPreferencesSettingsLocalRepository.runLogsKey: legacyRunLogs,
        SharedPreferencesSettingsLocalRepository.ownedPartsKey:
            legacyOwnedParts,
        SharedPreferencesSettingsLocalRepository.visibilitySettingsKey:
            legacyVisibility,
        SharedPreferencesSettingsLocalRepository.languageKey: true,
        SharedPreferencesSettingsLocalRepository.editorLayoutKey: true,
        SharedPreferencesSettingsLocalRepository.onlineModeKey: true,
      });
      final repository = SharedPreferencesSettingsLocalRepository(
        stringWriter: (preferences, key, value) async => false,
      );

      await expectLater(
        SettingsProvider.create(
          appModeProvider: AppModeProvider(
            preferredOnline: false,
            isFirebaseReady: false,
          ),
          localRepository: repository,
        ),
        throwsStateError,
      );

      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getString(
          SharedPreferencesSettingsLocalRepository.settingsStateV2Key,
        ),
        isNull,
      );
      expect(
        preferences.getString(SharedPreferencesSettingsLocalRepository.carsKey),
        legacyCars,
      );
      expect(
        preferences.getString(
          SharedPreferencesSettingsLocalRepository.savedSettingsKey,
        ),
        legacySettings,
      );
      expect(
        preferences.getString(
          SharedPreferencesSettingsLocalRepository.runLogsKey,
        ),
        legacyRunLogs,
      );
      expect(
        preferences.getString(
          SharedPreferencesSettingsLocalRepository.ownedPartsKey,
        ),
        legacyOwnedParts,
      );
      expect(
        preferences.getString(
          SharedPreferencesSettingsLocalRepository.visibilitySettingsKey,
        ),
        legacyVisibility,
      );
      expect(
        preferences.getBool(
          SharedPreferencesSettingsLocalRepository.onlineModeKey,
        ),
        isTrue,
      );
    });

    test('propagates malformed JSON and unsupported v2 versions', () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesSettingsLocalRepository.settingsStateV2Key: '{',
      });
      var repository = SharedPreferencesSettingsLocalRepository();
      await expectLater(repository.loadSnapshot(), throwsFormatException);

      final unsupported = _snapshot().toJson()..['schemaVersion'] = 99;
      SharedPreferences.setMockInitialValues({
        SharedPreferencesSettingsLocalRepository.settingsStateV2Key:
            jsonEncode(unsupported),
      });
      repository = SharedPreferencesSettingsLocalRepository();
      await expectLater(repository.loadSnapshot(), throwsFormatException);
    });

    test('loads every legacy field but ignores and preserves online_mode',
        () async {
      final source = _snapshot();
      final visibilityJson = source.visibilitySettings.map(
        (carId, settings) => MapEntry(carId, settings.toJson()),
      );
      SharedPreferences.setMockInitialValues({
        SharedPreferencesSettingsLocalRepository.carsKey:
            jsonEncode(source.cars.map((car) => car.toJson()).toList()),
        SharedPreferencesSettingsLocalRepository.savedSettingsKey: jsonEncode(
          source.savedSettings.map((setting) => setting.toJson()).toList(),
        ),
        SharedPreferencesSettingsLocalRepository.runLogsKey:
            jsonEncode(source.runLogs.map((log) => log.toJson()).toList()),
        SharedPreferencesSettingsLocalRepository.ownedPartsKey: jsonEncode(
          source.ownedParts.map((part) => part.toJson()).toList(),
        ),
        SharedPreferencesSettingsLocalRepository.visibilitySettingsKey:
            jsonEncode(visibilityJson),
        SharedPreferencesSettingsLocalRepository.languageKey: true,
        SharedPreferencesSettingsLocalRepository.editorLayoutKey: true,
        SharedPreferencesSettingsLocalRepository.onlineModeKey: true,
      });
      final repository = SharedPreferencesSettingsLocalRepository();

      final loaded = await repository.loadLegacySnapshot();
      final preferences = await SharedPreferences.getInstance();

      expect(loaded.cars.single.id, source.cars.single.id);
      expect(loaded.savedSettings.single.id, source.savedSettings.single.id);
      expect(loaded.runLogs.single.id, source.runLogs.single.id);
      expect(loaded.ownedParts.single.id, source.ownedParts.single.id);
      expect(loaded.visibilitySettings, contains(source.cars.single.id));
      expect(loaded.isEnglish, isTrue);
      expect(loaded.usePaperStyleEditor, isTrue);
      expect(
        preferences.getBool(
          SharedPreferencesSettingsLocalRepository.onlineModeKey,
        ),
        isTrue,
      );
      expect(
        preferences.getString(
          SharedPreferencesSettingsLocalRepository.settingsStateV2Key,
        ),
        isNull,
      );
    });

    test('builds complete defaults when no legacy key exists', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = SharedPreferencesSettingsLocalRepository();

      final loaded = await repository.loadLegacySnapshot();

      expect(loaded.cars, hasLength(7));
      expect(loaded.savedSettings, isEmpty);
      expect(loaded.runLogs, isEmpty);
      expect(loaded.ownedParts, isEmpty);
      expect(loaded.visibilitySettings, isEmpty);
      expect(loaded.isEnglish, isFalse);
      expect(loaded.usePaperStyleEditor, isFalse);
    });
  });

  test('SettingsOperationResult exposes typed success and failure variants',
      () {
    final warning = SettingsSyncWarning(
      operation: 'saveSetting',
      cause: StateError('cloud failed'),
      stackTrace: StackTrace.current,
    );
    final success = SettingsOperationResult<int>.success(
      value: 1,
      warning: warning,
    );
    final persistenceFailure = SettingsPersistenceFailure(
      kind: SettingsPersistenceFailureKind.write,
      operation: 'saveSetting',
      cause: StateError('local failed'),
      stackTrace: StackTrace.current,
    );
    final failure = SettingsOperationResult<int>.failure(persistenceFailure);

    expect(success, isA<SettingsOperationSuccess<int>>());
    expect((success as SettingsOperationSuccess<int>).value, 1);
    expect(success.warning, same(warning));
    expect(failure, isA<SettingsOperationFailure<int>>());
    expect(
      (failure as SettingsOperationFailure<int>).failure,
      same(persistenceFailure),
    );
  });
}
