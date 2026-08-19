import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:rc_setting_manager/models/car.dart';
import 'package:rc_setting_manager/models/manufacturer.dart';
import 'package:rc_setting_manager/models/owned_part.dart';
import 'package:rc_setting_manager/models/run_log.dart';
import 'package:rc_setting_manager/models/saved_setting.dart';
import 'package:rc_setting_manager/models/settings_operation_result.dart';
import 'package:rc_setting_manager/models/settings_snapshot_v2.dart';
import 'package:rc_setting_manager/models/visibility_settings.dart';
import 'package:rc_setting_manager/domain/settings/settings_id_generator.dart';
import 'package:rc_setting_manager/providers/app_mode_provider.dart';
import 'package:rc_setting_manager/providers/settings_provider.dart';
import 'package:rc_setting_manager/repositories/settings_cloud_repository.dart';
import 'package:rc_setting_manager/repositories/settings_local_repository.dart';

Car _buildCar({String id = 'custom/test-car', String name = 'Test Car'}) {
  return Car(
    id: id,
    name: name,
    imageUrl: '',
    manufacturer: Manufacturer(
      id: 'test-manufacturer',
      name: 'Test Manufacturer',
      logoPath: '',
    ),
    category: 'touring',
  );
}

SavedSetting _buildSetting({
  String id = 'setting-1',
  String name = 'Existing setting',
  DateTime? createdAt,
}) {
  return SavedSetting(
    id: id,
    name: name,
    createdAt: createdAt ?? DateTime.utc(2026, 1, 2),
    car: _buildCar(),
    settings: const {'motor': 'Existing Motor', 'frontCamber': 1.0},
  );
}

RunLog _buildRunLog({String id = 'run-1', String memo = 'existing'}) {
  return RunLog(
    id: id,
    createdAt: DateTime.utc(2026, 1, 3),
    runAt: DateTime.utc(2026, 1, 3, 10),
    car: _buildCar(),
    bestLapMillis: 12345,
    feelTagIds: const ['stable'],
    memo: memo,
    changes: const [],
  );
}

OwnedPart _buildOwnedPart({String id = 'part-1', String name = 'Motor A'}) {
  return OwnedPart(
    id: id,
    category: 'motor',
    name: name,
    createdAt: DateTime.utc(2026, 1, 4),
  );
}

SettingsSnapshotV2 _buildSnapshot({
  List<Car>? cars,
  List<SavedSetting>? savedSettings,
  List<RunLog>? runLogs,
  List<OwnedPart>? ownedParts,
  Map<String, VisibilitySettings>? visibilitySettings,
  bool isEnglish = false,
  bool usePaperStyleEditor = false,
}) {
  final effectiveCars = cars ?? [_buildCar()];
  return SettingsSnapshotV2(
    cars: effectiveCars,
    savedSettings: savedSettings ?? [_buildSetting()],
    runLogs: runLogs ?? [_buildRunLog()],
    ownedParts: ownedParts ?? [_buildOwnedPart()],
    visibilitySettings: visibilitySettings ??
        {
          for (final car in effectiveCars)
            car.id: VisibilitySettings(
              carId: car.id,
              settingsVisibility: const {'motor': true},
              favoriteSettings: const {'motor': true},
            ),
        },
    isEnglish: isEnglish,
    usePaperStyleEditor: usePaperStyleEditor,
  );
}

AppModeProvider _offlineMode() => AppModeProvider(
      preferredOnline: false,
      isFirebaseReady: false,
    );

AppModeProvider _onlineMode() => AppModeProvider(
      preferredOnline: true,
      isFirebaseReady: true,
    );

Future<SettingsProvider> _createProvider({
  required _MemorySettingsLocalRepository localRepository,
  bool online = false,
  SettingsCloudRepository? cloudRepository,
  SettingsCloudRepositoryFactory? cloudRepositoryFactory,
  SettingsIdGenerator? idGenerator,
  Duration cloudTimeout = const Duration(seconds: 15),
}) async {
  final provider = SettingsProvider(
    appModeProvider: online ? _onlineMode() : _offlineMode(),
    localRepository: localRepository,
    cloudRepository: cloudRepository,
    cloudRepositoryFactory: cloudRepositoryFactory,
    idGenerator: idGenerator,
    cloudTimeout: cloudTimeout,
  );
  await provider.initialization;
  localRepository.resetRecords();
  return provider;
}

String _providerState(SettingsProvider provider) {
  return jsonEncode(
    SettingsSnapshotV2(
      cars: provider.cars,
      savedSettings: provider.savedSettings,
      runLogs: provider.runLogs,
      ownedParts: provider.ownedParts,
      visibilitySettings: provider.visibilitySettings,
      isEnglish: provider.isEnglish,
      usePaperStyleEditor: provider.usePaperStyleEditor,
    ).toJson(),
  );
}

Future<void> _waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 1),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Condition was not met before the test timeout.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

void main() {
  group('SettingsProvider initialization', () {
    test('loads the injected v2 snapshot, sorts history, and notifies once',
        () async {
      final localRepository = _MemorySettingsLocalRepository(
        snapshot: _buildSnapshot(
          savedSettings: [
            _buildSetting(
              id: 'oldest',
              createdAt: DateTime.utc(2026, 1, 1),
            ),
            _buildSetting(
              id: 'newest',
              createdAt: DateTime.utc(2026, 1, 3),
            ),
            _buildSetting(
              id: 'middle',
              createdAt: DateTime.utc(2026, 1, 2),
            ),
          ],
        ),
      );
      final provider = SettingsProvider(
        appModeProvider: _offlineMode(),
        localRepository: localRepository,
      );
      var notifications = 0;
      provider.addListener(() => notifications++);

      await provider.initialization;

      expect(provider.isInitialized, isTrue);
      expect(
        provider.savedSettings.map((setting) => setting.id),
        ['newest', 'middle', 'oldest'],
      );
      expect(provider.cars.map((car) => car.id), contains(_buildCar().id));
      expect(notifications, 1);
    });

    test('prefers v2 and never reads legacy when both are available', () async {
      final localRepository = _MemorySettingsLocalRepository(
        snapshot: _buildSnapshot(
          savedSettings: [_buildSetting(id: 'v2-setting')],
        ),
        legacySnapshot: _buildSnapshot(
          savedSettings: [_buildSetting(id: 'legacy-setting')],
        ),
      );

      final provider = await _createProvider(localRepository: localRepository);

      expect(
        provider.savedSettings.map((setting) => setting.id),
        contains('v2-setting'),
      );
      expect(
        provider.savedSettings.map((setting) => setting.id),
        isNot(contains('legacy-setting')),
      );
      expect(localRepository.loadSnapshotCount, 1);
      expect(localRepository.loadLegacyCount, 0);
    });

    test('queues a mutation until initialization has completed', () async {
      final loadGate = Completer<void>();
      final localRepository = _MemorySettingsLocalRepository(
        snapshot: _buildSnapshot(savedSettings: const []),
      )..loadGate = loadGate;
      final provider = SettingsProvider(
        appModeProvider: _offlineMode(),
        localRepository: localRepository,
      );
      var notifications = 0;
      provider.addListener(() => notifications++);

      final operation = provider.addSetting(
        'Queued during initialization',
        _buildCar(),
        const {'frontCamber': 1.5},
      );
      await Future<void>.delayed(Duration.zero);

      expect(provider.isInitialized, isFalse);
      expect(provider.savedSettings, isEmpty);
      expect(localRepository.saveCount, 0);
      expect(notifications, 0);

      loadGate.complete();
      await provider.initialization;
      final result = await operation;

      expect(result, isA<SettingsOperationSuccess<SavedSetting>>());
      expect(
        provider.savedSettings.single.name,
        'Queued during initialization',
      );
      expect(localRepository.saveCount, 2);
      expect(notifications, 2);
    });

    test('returns a read failure for a mutation after initialization fails',
        () async {
      final loadGate = Completer<void>();
      final loadError = StateError('deferred snapshot read failed');
      final localRepository = _MemorySettingsLocalRepository(
        snapshot: _buildSnapshot(savedSettings: const []),
        loadError: loadError,
      )..loadGate = loadGate;
      final provider = SettingsProvider(
        appModeProvider: _offlineMode(),
        localRepository: localRepository,
      );
      var notifications = 0;
      provider.addListener(() => notifications++);

      final operation = provider.addSetting(
        'Must not be applied',
        _buildCar(),
        const {},
      );
      await Future<void>.delayed(Duration.zero);
      loadGate.complete();

      await expectLater(provider.initialization, throwsA(same(loadError)));
      final result = await operation;

      expect(result, isA<SettingsOperationFailure<SavedSetting>>());
      final failure =
          (result as SettingsOperationFailure<SavedSetting>).failure;
      expect(failure.kind, SettingsPersistenceFailureKind.read);
      expect(failure.operation, 'addSetting');
      expect(failure.cause, same(loadError));
      expect(provider.savedSettings, isEmpty);
      expect(localRepository.saveCount, 0);
      expect(notifications, 0);
    });

    test('initialization failure is propagated without publishing readiness',
        () async {
      final error = StateError('snapshot read failed');
      final localRepository = _MemorySettingsLocalRepository(
        snapshot: _buildSnapshot(),
        loadError: error,
      );
      final provider = SettingsProvider(
        appModeProvider: _offlineMode(),
        localRepository: localRepository,
      );
      var notifications = 0;
      provider.addListener(() => notifications++);

      await expectLater(provider.initialization, throwsA(same(error)));

      expect(provider.isInitialized, isFalse);
      expect(provider.initializationError, same(error));
      expect(notifications, 0);
      expect(localRepository.saveCount, 0);
    });

    test('legacy migration save failure becomes an initialization failure',
        () async {
      final localRepository = _MemorySettingsLocalRepository(
        snapshot: null,
        legacySnapshot: _buildSnapshot(),
        failWrites: true,
      );
      final provider = SettingsProvider(
        appModeProvider: _offlineMode(),
        localRepository: localRepository,
      );

      await expectLater(provider.initialization, throwsStateError);

      expect(provider.isInitialized, isFalse);
      expect(localRepository.loadLegacyCount, 1);
      expect(localRepository.saveCount, 1);
      expect(localRepository.storedSnapshot, isNull);
    });

    test('visibility defaults persist during initialization, not in getter',
        () async {
      final localRepository = _MemorySettingsLocalRepository(
        snapshot: _buildSnapshot(visibilitySettings: const {}),
      );
      final provider = await _createProvider(localRepository: localRepository);

      expect(
        provider.cars.every(
          (car) => provider.visibilitySettings.containsKey(car.id),
        ),
        isTrue,
      );

      final defaults = provider.getVisibilitySettings('custom/lazy-car');
      await Future<void>.delayed(Duration.zero);

      expect(defaults.carId, 'custom/lazy-car');
      expect(defaults.settingsVisibility, isNotEmpty);
      expect(provider.visibilitySettings, isNot(contains('custom/lazy-car')));
      expect(localRepository.saveCount, 0);
    });
  });

  group('atomic local persistence', () {
    test('does not publish a draft until snapshot persistence completes',
        () async {
      final localRepository = _MemorySettingsLocalRepository(
        snapshot: _buildSnapshot(savedSettings: const []),
      );
      final provider = await _createProvider(localRepository: localRepository);
      final writeGate = Completer<void>();
      localRepository.writeGate = writeGate;
      var notifications = 0;
      provider.addListener(() => notifications++);

      final operation = provider.addSetting(
        'Pending setting',
        _buildCar(),
        const {'frontCamber': 1.5},
      );
      await Future<void>.delayed(Duration.zero);

      expect(localRepository.saveCount, 1);
      expect(provider.savedSettings, isEmpty);
      expect(notifications, 0);

      writeGate.complete();
      final result = await operation;

      expect(result, isA<SettingsOperationSuccess<SavedSetting>>());
      expect(provider.savedSettings.single.name, 'Pending setting');
      expect(notifications, 1);
    });

    test('serializes consecutive mutations and preserves snapshot order',
        () async {
      final localRepository = _MemorySettingsLocalRepository(
        snapshot: _buildSnapshot(savedSettings: const []),
      );
      final provider = await _createProvider(localRepository: localRepository);
      final firstGate = Completer<void>();
      final secondGate = Completer<void>();
      localRepository.writeGate = firstGate;
      var notifications = 0;
      provider.addListener(() => notifications++);

      final first = provider.addSetting('First', _buildCar(), const {});
      await Future<void>.delayed(Duration.zero);
      final second = provider.addSetting('Second', _buildCar(), const {});
      await Future<void>.delayed(Duration.zero);

      expect(localRepository.saveCount, 1);
      expect(provider.savedSettings, isEmpty);
      expect(notifications, 0);

      localRepository.writeGate = secondGate;
      firstGate.complete();
      await first;
      await Future<void>.delayed(Duration.zero);

      expect(localRepository.saveCount, 2);
      expect(provider.savedSettings.map((setting) => setting.name), ['First']);
      expect(notifications, 1);

      secondGate.complete();
      await second;

      expect(
        provider.savedSettings.map((setting) => setting.name),
        unorderedEquals(['First', 'Second']),
      );
      expect(localRepository.savedSnapshots, hasLength(2));
      expect(
        localRepository.savedSnapshots[0].savedSettings
            .map((setting) => setting.name),
        ['First'],
      );
      expect(
        localRepository.savedSnapshots[1].savedSettings
            .map((setting) => setting.name),
        unorderedEquals(['First', 'Second']),
      );
      expect(notifications, 2);
    });

    test('derives visibility changes inside the queue without lost updates',
        () async {
      final car = _buildCar();
      final localRepository = _MemorySettingsLocalRepository(
        snapshot: _buildSnapshot(
          cars: [car],
          visibilitySettings: {
            car.id: VisibilitySettings(
              carId: car.id,
              settingsVisibility: const {
                'motor': true,
                'frontCamber': true,
              },
            ),
          },
        ),
      );
      final provider = await _createProvider(localRepository: localRepository);
      final firstWrite = Completer<void>();
      localRepository.writeGate = firstWrite;

      final first = provider.toggleSettingVisibility(car.id, 'motor', false);
      await Future<void>.delayed(Duration.zero);
      final second = provider.toggleSettingVisibility(
        car.id,
        'frontCamber',
        false,
      );
      firstWrite.complete();

      expect(await first, isA<SettingsOperationSuccess<bool>>());
      expect(await second, isA<SettingsOperationSuccess<bool>>());
      final visibility = provider.getVisibilitySettings(car.id);
      expect(visibility.settingsVisibility['motor'], isFalse);
      expect(visibility.settingsVisibility['frontCamber'], isFalse);
      expect(localRepository.saveCount, 2);
    });

    test('the last queued paper-style request wins', () async {
      final localRepository = _MemorySettingsLocalRepository(
        snapshot: _buildSnapshot(usePaperStyleEditor: false),
      );
      final provider = await _createProvider(localRepository: localRepository);

      final first = provider.setPaperStyleEditor(true);
      final second = provider.setPaperStyleEditor(false);

      expect(await first, isA<SettingsOperationSuccess<bool>>());
      expect(await second, isA<SettingsOperationSuccess<bool>>());
      expect(provider.usePaperStyleEditor, isFalse);
      expect(localRepository.saveCount, 2);
    });

    test('detaches nested input values and exposes immutable state', () async {
      final localRepository = _MemorySettingsLocalRepository(
        snapshot: _buildSnapshot(savedSettings: const []),
      );
      final provider = await _createProvider(localRepository: localRepository);
      final input = <String, dynamic>{
        'values': <dynamic>[1],
        'nested': <String, dynamic>{'value': 1},
      };

      final result = await provider.addSetting('Immutable', _buildCar(), input);
      expect(result, isA<SettingsOperationSuccess<SavedSetting>>());
      (input['values'] as List<dynamic>).add(2);
      (input['nested'] as Map<String, dynamic>)['value'] = 2;

      final stored = provider.savedSettings.single.settings;
      expect(stored['values'], [1]);
      expect(stored['nested'], {'value': 1});
      expect(
        () => (stored['values'] as List<dynamic>).add(3),
        throwsUnsupportedError,
      );
      expect(
        () => provider
            .getVisibilitySettings(_buildCar().id)
            .settingsVisibility['motor'] = false,
        throwsUnsupportedError,
      );
    });

    final cases = <({
      String name,
      String operation,
      Future<SettingsOperationResult<dynamic>> Function(
          SettingsProvider) mutate,
    })>[
      (
        name: 'car add',
        operation: 'addCar',
        mutate: (provider) => provider.addCar(
              _buildCar(id: 'custom/added', name: 'Added'),
            ),
      ),
      (
        name: 'car update',
        operation: 'updateCar',
        mutate: (provider) => provider.updateCar(
              _buildCar().copyWith(name: 'Updated'),
            ),
      ),
      (
        name: 'car delete',
        operation: 'deleteCar',
        mutate: (provider) => provider.deleteCar(_buildCar().id),
      ),
      (
        name: 'setting add',
        operation: 'addSetting',
        mutate: (provider) => provider.addSetting(
              'Added setting',
              _buildCar(),
              const {'frontCamber': 1.5},
            ),
      ),
      (
        name: 'setting update',
        operation: 'updateSetting',
        mutate: (provider) => provider.updateSetting(
              _buildSetting(name: 'Updated setting'),
            ),
      ),
      (
        name: 'setting delete',
        operation: 'deleteSetting',
        mutate: (provider) => provider.deleteSetting('setting-1'),
      ),
      (
        name: 'run log add',
        operation: 'addRunLog',
        mutate: (provider) => provider.addRunLog(
              runAt: DateTime.utc(2026, 2, 1),
              car: _buildCar(),
              baseSetting: _buildSetting(),
              bestLapMillis: 12000,
              feelTagIds: const ['stable'],
              changes: const [
                RunSettingChange(
                  settingKey: 'frontCamber',
                  settingLabel: 'Front Camber',
                  afterValue: 1.5,
                ),
              ],
            ),
      ),
      (
        name: 'run log update',
        operation: 'updateRunLog',
        mutate: (provider) => provider.updateRunLog(
              _buildRunLog().copyWith(memo: 'updated'),
            ),
      ),
      (
        name: 'run log delete',
        operation: 'deleteRunLog',
        mutate: (provider) => provider.deleteRunLog('run-1'),
      ),
      (
        name: 'owned part add',
        operation: 'addOwnedPart',
        mutate: (provider) => provider.addOwnedPart('motor', 'Motor B'),
      ),
      (
        name: 'owned part update',
        operation: 'updateOwnedPart',
        mutate: (provider) => provider.updateOwnedPart(
              'part-1',
              category: 'motor',
              name: 'Motor Updated',
            ),
      ),
      (
        name: 'owned part delete',
        operation: 'deleteOwnedPart',
        mutate: (provider) => provider.deleteOwnedPart('part-1'),
      ),
      (
        name: 'visibility update',
        operation: 'updateVisibilitySettings',
        mutate: (provider) => provider.updateVisibilitySettings(
              VisibilitySettings(
                carId: _buildCar().id,
                settingsVisibility: const {'motor': false},
              ),
            ),
      ),
      (
        name: 'language update',
        operation: 'toggleLanguage',
        mutate: (provider) => provider.toggleLanguage(),
      ),
      (
        name: 'editor layout update',
        operation: 'setPaperStyleEditor',
        mutate: (provider) => provider.setPaperStyleEditor(true),
      ),
      (
        name: 'full import',
        operation: 'replaceAllData',
        mutate: (provider) => provider.replaceAllData(
              cars: [_buildCar(id: 'custom/imported')],
              savedSettings: const [],
              runLogs: const [],
              ownedParts: const [],
              visibilitySettings: const {},
            ),
      ),
      (
        name: 'partial import',
        operation: 'replacePartialData',
        mutate: (provider) => provider.replacePartialData(
              savedSettings: const [],
              ownedParts: const [],
              isEnglish: true,
            ),
      ),
    ];

    for (final mutationCase in cases) {
      test(
          '${mutationCase.name}: write failure rolls back memory and emits no notification',
          () async {
        final localRepository = _MemorySettingsLocalRepository(
          snapshot: _buildSnapshot(),
        );
        final provider =
            await _createProvider(localRepository: localRepository);
        final before = _providerState(provider);
        var notifications = 0;
        provider.addListener(() => notifications++);
        localRepository.failWrites = true;

        final result = await mutationCase.mutate(provider);

        expect(result, isA<SettingsOperationFailure<dynamic>>());
        final failure = (result as SettingsOperationFailure<dynamic>).failure;
        expect(failure.kind, SettingsPersistenceFailureKind.write);
        expect(failure.operation, mutationCase.operation);
        expect(_providerState(provider), before);
        expect(localRepository.saveCount, 1);
        expect(notifications, 0);
      });
    }

    test('run log and derived setting never become orphaned on write failure',
        () async {
      final localRepository = _MemorySettingsLocalRepository(
        snapshot: _buildSnapshot(savedSettings: const [], runLogs: const []),
      );
      final provider = await _createProvider(localRepository: localRepository);
      localRepository.failWrites = true;
      var notifications = 0;
      provider.addListener(() => notifications++);

      final result = await provider.addRunLog(
        runAt: DateTime.utc(2026, 2, 1),
        car: _buildCar(),
        bestLapMillis: 12000,
        feelTagIds: const [],
        changes: const [
          RunSettingChange(
            settingKey: 'frontCamber',
            settingLabel: 'Front Camber',
            afterValue: 1.5,
          ),
        ],
      );

      expect(result, isA<SettingsOperationFailure<RunLog>>());
      expect(provider.runLogs, isEmpty);
      expect(provider.savedSettings, isEmpty);
      expect(localRepository.saveCount, 1);
      expect(notifications, 0);
    });

    test('no-op mutations do not persist or notify', () async {
      final localRepository = _MemorySettingsLocalRepository(
        snapshot: _buildSnapshot(),
      );
      final provider = await _createProvider(localRepository: localRepository);
      var notifications = 0;
      provider.addListener(() => notifications++);

      final missingCar = await provider.updateCar(
        _buildCar(id: 'custom/missing'),
      );
      final missingRun = await provider.deleteRunLog('missing');
      final duplicatePart = await provider.addOwnedPart('motor', ' motor a ');
      final sameLayout = await provider.setPaperStyleEditor(false);

      expect((missingCar as SettingsOperationSuccess<bool>).value, isFalse);
      expect((missingRun as SettingsOperationSuccess<bool>).value, isFalse);
      expect(
        (duplicatePart as SettingsOperationSuccess<OwnedPart?>).value?.id,
        'part-1',
      );
      expect((sameLayout as SettingsOperationSuccess<bool>).value, isFalse);
      expect(localRepository.saveCount, 0);
      expect(notifications, 0);
    });

    test('rejects operations submitted after disposal', () async {
      final localRepository = _MemorySettingsLocalRepository(
        snapshot: _buildSnapshot(savedSettings: const []),
      );
      final provider = await _createProvider(localRepository: localRepository);
      provider.dispose();

      final result =
          await provider.addSetting('Disposed', _buildCar(), const {});

      expect(result, isA<SettingsOperationFailure<SavedSetting>>());
      expect(localRepository.saveCount, 0);
      expect(provider.savedSettings, isEmpty);
    });

    test('serializes mutations from different Zones for the same repository',
        () async {
      final localRepository = _MemorySettingsLocalRepository(
        snapshot: _buildSnapshot(savedSettings: const []),
      );
      final provider = await _createProvider(localRepository: localRepository);
      final firstWriteGate = Completer<void>();
      localRepository.writeGate = firstWriteGate;

      final first = runZoned(
        () => provider.addSetting('Zone A', _buildCar(), const {}),
      );
      await _waitUntil(() => localRepository.saveCount == 1);
      final second = runZoned(
        () => provider.addSetting('Zone B', _buildCar(), const {}),
      );
      await Future<void>.delayed(Duration.zero);

      expect(localRepository.saveCount, 1);
      firstWriteGate.complete();
      expect(await first, isA<SettingsOperationSuccess<SavedSetting>>());
      expect(await second, isA<SettingsOperationSuccess<SavedSetting>>());
      expect(
        provider.savedSettings.map((setting) => setting.name),
        unorderedEquals(['Zone A', 'Zone B']),
      );
      expect(localRepository.savedSnapshots.last.savedSettings, hasLength(2));
    });
  });

  group('cloud synchronization after local commit', () {
    test('each car CRUD performs one local save, one cloud save, one notify',
        () async {
      final localRepository = _MemorySettingsLocalRepository(
        snapshot: _buildSnapshot(),
      );
      final cloudRepository = _RecordingSettingsCloudRepository();
      final provider = await _createProvider(
        localRepository: localRepository,
        online: true,
        cloudRepository: cloudRepository,
      );
      var notifications = 0;
      provider.addListener(() => notifications++);
      final addedCar = _buildCar(id: 'custom/second-car', name: 'Second Car');

      final added = await provider.addCar(addedCar);
      expect(added, isA<SettingsOperationSuccess<Car>>());
      expect(localRepository.saveCount, 1);
      expect(cloudRepository.saveCarsAndVisibilityBatchCount, 1);
      expect(
        cloudRepository.savedVisibilityMaps.last,
        contains(addedCar.id),
      );
      expect(notifications, 1);

      final updated = await provider.updateCar(
        addedCar.copyWith(isInGarage: true),
      );
      expect(updated, isA<SettingsOperationSuccess<bool>>());
      expect(localRepository.saveCount, 2);
      expect(cloudRepository.saveCarsAndVisibilityBatchCount, 2);
      expect(notifications, 2);

      final deleted = await provider.deleteCar(addedCar.id);
      expect(deleted, isA<SettingsOperationSuccess<bool>>());
      expect(localRepository.saveCount, 3);
      expect(cloudRepository.saveCarsAndVisibilityBatchCount, 3);
      expect(notifications, 3);
      expect(cloudRepository.savedAtomicCarLists, hasLength(3));
      expect(
        cloudRepository.savedVisibilityMaps.last,
        isNot(contains(addedCar.id)),
      );
    });

    test('run log and derived setting use one snapshot and one cloud batch',
        () async {
      final localRepository = _MemorySettingsLocalRepository(
        snapshot: _buildSnapshot(savedSettings: const [], runLogs: const []),
      );
      final cloudRepository = _RecordingSettingsCloudRepository();
      final provider = await _createProvider(
        localRepository: localRepository,
        online: true,
        cloudRepository: cloudRepository,
      );
      var notifications = 0;
      provider.addListener(() => notifications++);

      final result = await provider.addRunLog(
        runAt: DateTime.utc(2026, 2, 1),
        car: _buildCar(),
        bestLapMillis: 12000,
        feelTagIds: const ['stable'],
        changes: const [
          RunSettingChange(
            settingKey: 'frontCamber',
            settingLabel: 'Front Camber',
            afterValue: 1.5,
          ),
        ],
      );

      expect(result, isA<SettingsOperationSuccess<RunLog>>());
      expect(localRepository.saveCount, 1);
      expect(cloudRepository.runLogBatchCount, 1);
      expect(cloudRepository.saveRunLogCount, 0);
      expect(cloudRepository.saveSettingCount, 0);
      expect(provider.runLogs, hasLength(1));
      expect(provider.savedSettings, hasLength(1));
      expect(
        cloudRepository.batchedRunLog?.resultSettingId,
        cloudRepository.batchedResultSetting?.id,
      );
      expect(
        cloudRepository.batchedResultSetting?.sourceRunLogId,
        cloudRepository.batchedRunLog?.id,
      );
      expect(notifications, 1);
    });

    test('AI base and derived settings commit in one local and cloud batch',
        () async {
      final localRepository = _MemorySettingsLocalRepository(
        snapshot: _buildSnapshot(savedSettings: const []),
      );
      final cloudRepository = _RecordingSettingsCloudRepository();
      final provider = await _createProvider(
        localRepository: localRepository,
        online: true,
        cloudRepository: cloudRepository,
      );
      var notifications = 0;
      provider.addListener(() => notifications++);

      final result = await provider.addDerivedSettingWithBase(
        base: NewSavedSettingInput(
          name: 'Base',
          car: _buildCar(),
          settings: const {'frontCamber': 1.0},
        ),
        derived: NewSavedSettingInput(
          name: 'AI',
          car: _buildCar(),
          settings: const {'frontCamber': 1.5},
          kind: SavedSettingKind.aiSuggestion,
        ),
      );

      final value = (result as SettingsOperationSuccess<
              ({
                SavedSetting baseSetting,
                SavedSetting derivedSetting,
              })>)
          .value!;
      expect(value.derivedSetting.parentSettingId, value.baseSetting.id);
      expect(provider.savedSettings, hasLength(2));
      expect(localRepository.saveCount, 1);
      expect(cloudRepository.saveSettingsAndCarsBatchCount, 1);
      expect(notifications, 1);
    });

    test('batch settings and car update each use one atomic commit', () async {
      final localRepository = _MemorySettingsLocalRepository(
        snapshot: _buildSnapshot(savedSettings: const []),
      );
      final cloudRepository = _RecordingSettingsCloudRepository();
      final provider = await _createProvider(
        localRepository: localRepository,
        online: true,
        cloudRepository: cloudRepository,
      );

      final batchResult = await provider.addSettingsBatch([
        NewSavedSettingInput(
          name: 'One',
          car: _buildCar(),
          settings: const {'frontCamber': 1.0},
        ),
        NewSavedSettingInput(
          name: 'Two',
          car: _buildCar(),
          settings: const {'frontCamber': 1.5},
        ),
      ]);
      expect(
        (batchResult as SettingsOperationSuccess<List<SavedSetting>>).value,
        hasLength(2),
      );
      expect(localRepository.saveCount, 1);
      expect(cloudRepository.saveSettingsAndCarsBatchCount, 1);

      final carResult = await provider.addSettingWithCarUpdate(
        'Garage',
        _buildCar(),
        const {},
        isInGarage: true,
        suppressGaragePrompt: true,
      );
      expect(carResult, isA<SettingsOperationSuccess<SavedSetting>>());
      expect(provider.getCarById(_buildCar().id)?.isInGarage, isTrue);
      expect(
        provider.getCarById(_buildCar().id)?.suppressGaragePrompt,
        isTrue,
      );
      expect(localRepository.saveCount, 2);
      expect(cloudRepository.saveSettingsAndCarsBatchCount, 2);
    });

    test('cloud failure keeps local state and returns a sync warning',
        () async {
      final localRepository = _MemorySettingsLocalRepository(
        snapshot: _buildSnapshot(savedSettings: const []),
      );
      final cloudRepository = _RecordingSettingsCloudRepository(
        failingOperations: const {'saveSetting'},
      );
      final provider = await _createProvider(
        localRepository: localRepository,
        online: true,
        cloudRepository: cloudRepository,
      );
      var notifications = 0;
      provider.addListener(() => notifications++);

      final result = await provider.addSetting(
        'Locally saved',
        _buildCar(),
        const {'frontCamber': 1.5},
      );

      expect(result, isA<SettingsOperationSuccess<SavedSetting>>());
      final success = result as SettingsOperationSuccess<SavedSetting>;
      expect(success.warning?.operation, 'addSetting');
      expect(provider.savedSettings, hasLength(1));
      expect(localRepository.storedSnapshot?.savedSettings, hasLength(1));
      expect(localRepository.saveCount, 1);
      expect(cloudRepository.saveSettingCount, 1);
      expect(notifications, 1);
    });

    test('slow cloud sync does not block notifications or later local commits',
        () async {
      final gate = Completer<void>();
      final localRepository = _MemorySettingsLocalRepository(
        snapshot: _buildSnapshot(savedSettings: const []),
      );
      final cloudRepository = _RecordingSettingsCloudRepository(
        saveSettingGates: [gate, null],
      );
      final provider = await _createProvider(
        localRepository: localRepository,
        online: true,
        cloudRepository: cloudRepository,
        cloudTimeout: const Duration(seconds: 1),
      );
      var notifications = 0;
      provider.addListener(() => notifications++);

      final first = provider.addSetting('First', _buildCar(), const {});
      await Future<void>.delayed(Duration.zero);
      final second = provider.addSetting('Second', _buildCar(), const {});
      await Future<void>.delayed(Duration.zero);

      expect(localRepository.saveCount, 2);
      expect(provider.savedSettings, hasLength(2));
      expect(notifications, 2);
      expect(cloudRepository.saveSettingCount, 1);

      gate.complete();
      expect(await first, isA<SettingsOperationSuccess<SavedSetting>>());
      expect(await second, isA<SettingsOperationSuccess<SavedSetting>>());
      expect(cloudRepository.saveSettingCount, 2);
    });

    test('caller timeout does not let a newer write overtake the base Future',
        () async {
      final firstWriteGate = Completer<void>();
      final localRepository = _MemorySettingsLocalRepository(
        snapshot: _buildSnapshot(savedSettings: [_buildSetting()]),
      );
      final cloudRepository = _RecordingSettingsCloudRepository(
        saveSettingGates: [firstWriteGate, null],
      );
      final provider = await _createProvider(
        localRepository: localRepository,
        online: true,
        cloudRepository: cloudRepository,
        cloudTimeout: const Duration(milliseconds: 20),
      );
      final first = await provider.updateSetting(
        _buildSetting(name: 'Older timed-out write'),
      );
      expect(
        (first as SettingsOperationSuccess<SavedSetting?>).warning,
        isNotNull,
      );

      final second = await provider.updateSetting(
        _buildSetting(name: 'Latest write'),
      );
      expect(
        (second as SettingsOperationSuccess<SavedSetting?>).warning,
        isNotNull,
      );
      expect(cloudRepository.saveSettingCount, 1);

      firstWriteGate.complete();
      await _waitUntil(
        () => cloudRepository.completedSettingWrites.length == 2,
      );
      expect(
        cloudRepository.completedSettingWrites.map((write) => write.name),
        ['Older timed-out write', 'Latest write'],
      );
      expect(
        cloudRepository.remoteSettings[_buildSetting().id]?.name,
        'Latest write',
      );
    });

    test('an A commit queued before an account switch never writes as B',
        () async {
      final firstWriteGate = Completer<void>();
      final localRepository = _MemorySettingsLocalRepository(
        snapshot: _buildSnapshot(savedSettings: const []),
      );
      final cloudRepository = _RecordingSettingsCloudRepository(
        currentUserId: 'A',
        saveSettingGates: [firstWriteGate, null],
      );
      final provider = await _createProvider(
        localRepository: localRepository,
        online: true,
        cloudRepository: cloudRepository,
        cloudTimeout: const Duration(seconds: 1),
      );

      final blocker = provider.addSetting('A blocker', _buildCar(), const {});
      await _waitUntil(() => cloudRepository.saveSettingCount == 1);
      final queued = provider.addSetting('A queued', _buildCar(), const {});
      await _waitUntil(() => localRepository.saveCount == 2);

      cloudRepository.currentUserId = 'B';
      firstWriteGate.complete();
      final blockerResult =
          await blocker as SettingsOperationSuccess<SavedSetting>;
      final queuedResult =
          await queued as SettingsOperationSuccess<SavedSetting>;

      expect(blockerResult.warning, isNotNull);
      expect(queuedResult.warning, isNotNull);
      expect(
        cloudRepository.startedSettingWrites
            .map((write) => '${write.userId}:${write.setting.name}'),
        ['A:A blocker'],
      );
    });

    test('captures A before local persistence waits and never writes as B',
        () async {
      final localWriteGate = Completer<void>();
      final localRepository = _MemorySettingsLocalRepository(
        snapshot: _buildSnapshot(savedSettings: const []),
      );
      final cloudRepository = _RecordingSettingsCloudRepository(
        currentUserId: 'A',
      );
      final provider = await _createProvider(
        localRepository: localRepository,
        online: true,
        cloudRepository: cloudRepository,
      );
      localRepository.writeGate = localWriteGate;

      final operation = provider.addSetting(
        'Captured as A',
        _buildCar(),
        const {},
      );
      await _waitUntil(() => localRepository.saveCount == 1);
      cloudRepository.currentUserId = 'B';
      localWriteGate.complete();

      final result = await operation as SettingsOperationSuccess<SavedSetting>;
      expect(result.warning, isNotNull);
      expect(provider.savedSettings.single.name, 'Captured as A');
      expect(cloudRepository.startedSettingWrites, isEmpty);
    });

    test(
        'cloud factory errors preserve local mutations and return typed results',
        () async {
      final localRepository = _MemorySettingsLocalRepository(
        snapshot: _buildSnapshot(savedSettings: const []),
      );
      final factoryFailure = StateError('cloud factory failed');
      final provider = await _createProvider(
        localRepository: localRepository,
        online: true,
        cloudRepositoryFactory: () => throw factoryFailure,
      );

      final mutation = await provider.addSetting(
        'Local only after factory failure',
        _buildCar(),
        const {},
      );
      final mutationSuccess =
          mutation as SettingsOperationSuccess<SavedSetting>;
      expect(mutationSuccess.warning?.cause, same(factoryFailure));
      expect(provider.savedSettings, hasLength(1));
      expect(localRepository.saveCount, 1);

      final sync = await provider.syncToFirebase();
      final load = await provider.loadFromFirebase();
      expect(
        (sync as SettingsOperationFailure<void>).failure.cause,
        same(factoryFailure),
      );
      expect(
        (load as SettingsOperationFailure<void>).failure.cause,
        same(factoryFailure),
      );
    });

    test('sync requests capture A and do not start a queued write as B',
        () async {
      final firstSyncGate = Completer<void>();
      final localRepository = _MemorySettingsLocalRepository(
        snapshot: _buildSnapshot(),
      );
      final cloudRepository = _RecordingSettingsCloudRepository(
        currentUserId: 'A',
        syncAllDataGates: [firstSyncGate, null],
      );
      final provider = await _createProvider(
        localRepository: localRepository,
        online: true,
        cloudRepository: cloudRepository,
        cloudTimeout: const Duration(seconds: 1),
      );

      final blocker = provider.syncToFirebase();
      await _waitUntil(() => cloudRepository.syncCount == 1);
      final queued = provider.syncToFirebase();
      await Future<void>.delayed(Duration.zero);
      cloudRepository.currentUserId = 'B';
      firstSyncGate.complete();

      expect(await blocker, isA<SettingsOperationFailure<void>>());
      expect(await queued, isA<SettingsOperationFailure<void>>());
      expect(cloudRepository.syncStartedUsers, ['A']);
    });

    test('cloud load stops before the next collection after a user switch',
        () async {
      final firstReadGate = Completer<void>();
      final localRepository = _MemorySettingsLocalRepository(
        snapshot: _buildSnapshot(),
      );
      final cloudRepository = _RecordingSettingsCloudRepository(
        currentUserId: 'A',
        getSavedSettingsGates: [firstReadGate],
      );
      final provider = await _createProvider(
        localRepository: localRepository,
        online: true,
        cloudRepository: cloudRepository,
        cloudTimeout: const Duration(seconds: 1),
      );

      final load = provider.loadFromFirebase();
      await _waitUntil(() => cloudRepository.cloudReads.isNotEmpty);
      cloudRepository.currentUserId = 'B';
      firstReadGate.complete();

      expect(await load, isA<SettingsOperationFailure<void>>());
      expect(cloudRepository.cloudReads, ['A:getSavedSettings']);
      expect(localRepository.saveCount, 0);
    });

    test('cloud load caller can time out while its base read remains ordered',
        () async {
      final firstReadGate = Completer<void>();
      final localRepository = _MemorySettingsLocalRepository(
        snapshot: _buildSnapshot(),
      );
      final cloudRepository = _RecordingSettingsCloudRepository(
        getSavedSettingsGates: [firstReadGate],
      );
      final provider = await _createProvider(
        localRepository: localRepository,
        online: true,
        cloudRepository: cloudRepository,
        cloudTimeout: const Duration(milliseconds: 20),
      );
      final stateBeforeTimedOutLoad = _providerState(provider);
      var notifications = 0;
      provider.addListener(() => notifications++);

      final result = await provider.loadFromFirebase();
      expect(result, isA<SettingsOperationFailure<void>>());
      expect(cloudRepository.cloudReads, ['user:getSavedSettings']);

      firstReadGate.complete();
      await provider.localOperationsSettled;
      await _waitUntil(
          () => cloudRepository.getSavedSettingsCompletionCount == 1);
      expect(localRepository.saveCount, 0);
      expect(cloudRepository.saveCarsAndVisibilityBatchCount, 0);
      expect(notifications, 0);
      expect(_providerState(provider), stateBeforeTimedOutLoad);

      final retry = await provider.loadFromFirebase();
      expect(retry, isA<SettingsOperationSuccess<void>>());
      expect(localRepository.saveCount, 1);
      expect(cloudRepository.saveCarsAndVisibilityBatchCount, 1);
      expect(notifications, 1);
    });

    test('offline operations never instantiate the cloud repository', () async {
      final localRepository = _MemorySettingsLocalRepository(
        snapshot: _buildSnapshot(savedSettings: const []),
      );
      var factoryCalls = 0;
      final provider = await _createProvider(
        localRepository: localRepository,
        cloudRepositoryFactory: () {
          factoryCalls++;
          return _RecordingSettingsCloudRepository();
        },
      );

      final result = await provider.addSetting(
        'Offline setting',
        _buildCar(),
        const {},
      );

      expect(result, isA<SettingsOperationSuccess<SavedSetting>>());
      expect(factoryCalls, 0);
      expect(localRepository.saveCount, 1);
    });

    test('cloud load commits all local stores once and notifies once',
        () async {
      final localRepository = _MemorySettingsLocalRepository(
        snapshot: _buildSnapshot(),
      );
      final cloudCar = _buildCar();
      final cloudRepository = _RecordingSettingsCloudRepository(
        cloudSavedSettings: [
          _buildSetting(
            id: 'old',
            createdAt: DateTime.utc(2026, 1, 1),
          ),
          _buildSetting(
            id: 'new',
            createdAt: DateTime.utc(2026, 1, 3),
          ),
        ],
        cloudRunLogs: [
          _buildRunLog(id: 'older-run'),
          _buildRunLog(id: 'newer-run').copyWith(
            createdAt: DateTime.utc(2026, 1, 5),
            runAt: DateTime.utc(2026, 1, 5),
          ),
        ],
        cloudCars: [cloudCar],
        cloudOwnedParts: [_buildOwnedPart(id: 'cloud-part')],
        cloudVisibilitySettings: {
          cloudCar.id: VisibilitySettings(
            carId: cloudCar.id,
            settingsVisibility: const {'motor': false},
          ),
        },
        cloudIsEnglish: true,
      );
      final provider = await _createProvider(
        localRepository: localRepository,
        online: true,
        cloudRepository: cloudRepository,
      );
      var notifications = 0;
      provider.addListener(() => notifications++);

      final result = await provider.loadFromFirebase();

      expect(result, isA<SettingsOperationSuccess<void>>());
      expect(
        provider.savedSettings.map((setting) => setting.id),
        ['new', 'old'],
      );
      expect(
        provider.runLogs.map((runLog) => runLog.id),
        ['newer-run', 'older-run'],
      );
      expect(provider.isEnglish, isTrue);
      expect(provider.ownedParts.single.id, 'cloud-part');
      expect(localRepository.saveCount, 1);
      expect(cloudRepository.saveCarsAndVisibilityBatchCount, 1);
      expect(notifications, 1);
    });
  });
}

SettingsSnapshotV2 _cloneSnapshot(SettingsSnapshotV2 snapshot) {
  return SettingsSnapshotV2.fromJson(
    jsonDecode(jsonEncode(snapshot.toJson())) as Map<String, dynamic>,
  );
}

class _MemorySettingsLocalRepository implements SettingsLocalRepository {
  _MemorySettingsLocalRepository({
    required SettingsSnapshotV2? snapshot,
    SettingsSnapshotV2? legacySnapshot,
    this.loadError,
    this.failWrites = false,
  })  : storedSnapshot = snapshot == null ? null : _cloneSnapshot(snapshot),
        legacySnapshot = _cloneSnapshot(legacySnapshot ?? _buildSnapshot());

  SettingsSnapshotV2? storedSnapshot;
  final SettingsSnapshotV2 legacySnapshot;
  final Object? loadError;
  bool failWrites;
  Completer<void>? loadGate;
  Completer<void>? writeGate;
  int loadSnapshotCount = 0;
  int loadLegacyCount = 0;
  int saveCount = 0;
  final List<SettingsSnapshotV2> savedSnapshots = [];

  void resetRecords() {
    saveCount = 0;
    savedSnapshots.clear();
  }

  @override
  Future<SettingsSnapshotV2?> loadSnapshot() async {
    loadSnapshotCount++;
    final gate = loadGate;
    if (gate != null) {
      await gate.future;
    }
    if (loadError case final error?) {
      throw error;
    }
    final snapshot = storedSnapshot;
    return snapshot == null ? null : _cloneSnapshot(snapshot);
  }

  @override
  Future<SettingsSnapshotV2> loadLegacySnapshot() async {
    loadLegacyCount++;
    return _cloneSnapshot(legacySnapshot);
  }

  @override
  Future<void> saveSnapshot(SettingsSnapshotV2 snapshot) async {
    saveCount++;
    final gate = writeGate;
    if (gate != null) {
      await gate.future;
    }
    if (failWrites) {
      throw StateError('simulated snapshot write failure');
    }
    final saved = _cloneSnapshot(snapshot);
    storedSnapshot = saved;
    savedSnapshots.add(saved);
  }
}

class _RecordingSettingsCloudRepository implements SettingsCloudRepository {
  _RecordingSettingsCloudRepository({
    this.currentUserId = 'user',
    this.failingOperations = const {},
    this.cloudSavedSettings = const [],
    this.cloudRunLogs = const [],
    this.cloudCars = const [],
    this.cloudOwnedParts = const [],
    this.cloudVisibilitySettings = const {},
    this.cloudIsEnglish = false,
    this.saveSettingGates = const [],
    this.syncAllDataGates = const [],
    this.getSavedSettingsGates = const [],
  });

  String? currentUserId;
  final Set<String> failingOperations;
  final List<SavedSetting> cloudSavedSettings;
  final List<RunLog> cloudRunLogs;
  final List<Car> cloudCars;
  final List<OwnedPart> cloudOwnedParts;
  final Map<String, VisibilitySettings> cloudVisibilitySettings;
  final bool cloudIsEnglish;
  final List<Completer<void>?> saveSettingGates;
  final List<Completer<void>?> syncAllDataGates;
  final List<Completer<void>?> getSavedSettingsGates;

  int saveSettingCount = 0;
  int saveSettingsAndCarsBatchCount = 0;
  int saveRunLogCount = 0;
  int runLogBatchCount = 0;
  int saveCarsCount = 0;
  int saveCarsAndVisibilityBatchCount = 0;
  int saveOwnedPartsCount = 0;
  int saveVisibilityCount = 0;
  int saveLanguageCount = 0;
  int syncCount = 0;
  int getSavedSettingsCount = 0;
  int getSavedSettingsCompletionCount = 0;
  RunLog? batchedRunLog;
  SavedSetting? batchedResultSetting;
  final List<List<Car>> savedCarLists = [];
  final List<List<Car>> savedAtomicCarLists = [];
  final List<Map<String, VisibilitySettings>> savedVisibilityMaps = [];
  final List<({String? userId, SavedSetting setting})> startedSettingWrites =
      [];
  final List<SavedSetting> completedSettingWrites = [];
  final Map<String, SavedSetting> remoteSettings = {};
  final List<String?> syncStartedUsers = [];
  final List<String> cloudReads = [];

  @override
  String? get userId => currentUserId;

  void _failIfRequested(String operation) {
    if (failingOperations.contains(operation)) {
      throw StateError('simulated cloud $operation failure');
    }
  }

  @override
  Future<void> saveSetting(SavedSetting setting) async {
    final callIndex = saveSettingCount;
    saveSettingCount++;
    startedSettingWrites.add((userId: currentUserId, setting: setting));
    _failIfRequested('saveSetting');
    if (callIndex < saveSettingGates.length) {
      await saveSettingGates[callIndex]?.future;
    }
    completedSettingWrites.add(setting);
    remoteSettings[setting.id] = setting;
  }

  @override
  Future<void> saveSettingsAndCarsAtomically({
    required List<SavedSetting> settings,
    List<Car>? cars,
  }) async {
    saveSettingsAndCarsBatchCount++;
    _failIfRequested('saveSettingsAndCarsAtomically');
  }

  @override
  Future<List<SavedSetting>> getSavedSettings() async {
    final callIndex = getSavedSettingsCount;
    getSavedSettingsCount++;
    cloudReads.add('$currentUserId:getSavedSettings');
    _failIfRequested('getSavedSettings');
    if (callIndex < getSavedSettingsGates.length) {
      await getSavedSettingsGates[callIndex]?.future;
    }
    getSavedSettingsCompletionCount++;
    return List<SavedSetting>.of(cloudSavedSettings);
  }

  @override
  Future<void> deleteSetting(String settingId) async {
    _failIfRequested('deleteSetting');
  }

  @override
  Future<void> saveRunLog(RunLog runLog) async {
    saveRunLogCount++;
    _failIfRequested('saveRunLog');
  }

  @override
  Future<void> saveRunLogWithResultSetting({
    required RunLog runLog,
    SavedSetting? resultSetting,
  }) async {
    runLogBatchCount++;
    batchedRunLog = runLog;
    batchedResultSetting = resultSetting;
    _failIfRequested('saveRunLogWithResultSetting');
  }

  @override
  Future<List<RunLog>> getRunLogs() async {
    cloudReads.add('$currentUserId:getRunLogs');
    _failIfRequested('getRunLogs');
    return List<RunLog>.of(cloudRunLogs);
  }

  @override
  Future<void> deleteRunLog(String runLogId) async {
    _failIfRequested('deleteRunLog');
  }

  @override
  Future<void> saveCars(List<Car> cars) async {
    saveCarsCount++;
    savedCarLists.add(List<Car>.of(cars));
    _failIfRequested('saveCars');
  }

  @override
  Future<void> saveCarsAndVisibilityAtomically({
    required List<Car> cars,
    required Map<String, VisibilitySettings> visibilitySettings,
  }) async {
    saveCarsAndVisibilityBatchCount++;
    savedAtomicCarLists.add(List<Car>.of(cars));
    savedVisibilityMaps.add(
      Map<String, VisibilitySettings>.of(visibilitySettings),
    );
    _failIfRequested('saveCarsAndVisibilityAtomically');
  }

  @override
  Future<List<Car>> getCars() async {
    cloudReads.add('$currentUserId:getCars');
    _failIfRequested('getCars');
    return List<Car>.of(cloudCars);
  }

  @override
  Future<void> saveOwnedParts(List<OwnedPart> ownedParts) async {
    saveOwnedPartsCount++;
    _failIfRequested('saveOwnedParts');
  }

  @override
  Future<List<OwnedPart>> getOwnedParts() async {
    cloudReads.add('$currentUserId:getOwnedParts');
    _failIfRequested('getOwnedParts');
    return List<OwnedPart>.of(cloudOwnedParts);
  }

  @override
  Future<void> saveVisibilitySettings(
    Map<String, VisibilitySettings> visibilitySettings,
  ) async {
    saveVisibilityCount++;
    _failIfRequested('saveVisibilitySettings');
  }

  @override
  Future<Map<String, VisibilitySettings>> getVisibilitySettings() async {
    cloudReads.add('$currentUserId:getVisibilitySettings');
    _failIfRequested('getVisibilitySettings');
    return Map<String, VisibilitySettings>.of(cloudVisibilitySettings);
  }

  @override
  Future<void> saveLanguageSettings(bool isEnglish) async {
    saveLanguageCount++;
    _failIfRequested('saveLanguageSettings');
  }

  @override
  Future<bool> getLanguageSettings() async {
    cloudReads.add('$currentUserId:getLanguageSettings');
    _failIfRequested('getLanguageSettings');
    return cloudIsEnglish;
  }

  @override
  Future<void> syncAllData({
    required List<SavedSetting> savedSettings,
    required List<RunLog> runLogs,
    required List<Car> cars,
    required List<OwnedPart> ownedParts,
    required Map<String, VisibilitySettings> visibilitySettings,
    required bool isEnglish,
  }) async {
    final callIndex = syncCount;
    syncCount++;
    syncStartedUsers.add(currentUserId);
    _failIfRequested('syncAllData');
    if (callIndex < syncAllDataGates.length) {
      await syncAllDataGates[callIndex]?.future;
    }
  }
}
