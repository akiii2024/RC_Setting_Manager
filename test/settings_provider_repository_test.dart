import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rc_setting_manager/models/car.dart';
import 'package:rc_setting_manager/models/manufacturer.dart';
import 'package:rc_setting_manager/models/owned_part.dart';
import 'package:rc_setting_manager/models/run_log.dart';
import 'package:rc_setting_manager/models/saved_setting.dart';
import 'package:rc_setting_manager/models/visibility_settings.dart';
import 'package:rc_setting_manager/providers/settings_provider.dart';
import 'package:rc_setting_manager/repositories/settings_cloud_repository.dart';
import 'package:rc_setting_manager/repositories/settings_local_repository.dart';

Future<void> _waitForProvider(SettingsProvider provider) async {
  for (var i = 0; i < 100; i++) {
    if (provider.isInitialized) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }

  fail('SettingsProvider did not initialize in time.');
}

Car _buildCar() {
  return Car(
    id: 'custom/test-car',
    name: 'Test Car',
    imageUrl: '',
    manufacturer: Manufacturer(
      id: 'test-manufacturer',
      name: 'Test Manufacturer',
      logoPath: '',
    ),
    category: 'touring',
  );
}

SavedSetting _buildSetting(String id, DateTime createdAt) {
  return SavedSetting(
    id: id,
    name: id,
    createdAt: createdAt,
    car: _buildCar(),
    settings: const {},
  );
}

void main() {
  test('shared preferences repository preserves storage keys and JSON shapes',
      () async {
    SharedPreferences.setMockInitialValues({});
    final repository = SharedPreferencesSettingsLocalRepository();
    final car = _buildCar();
    final setting = _buildSetting('setting-1', DateTime(2026, 1, 2));
    final runLog = RunLog(
      id: 'run-1',
      createdAt: DateTime(2026, 1, 3),
      runAt: DateTime(2026, 1, 3, 10),
      car: car,
      bestLapMillis: 12345,
      feelTagIds: const ['stable'],
      memo: 'memo',
      changes: const [],
    );
    final ownedPart = OwnedPart(
      id: 'part-1',
      category: 'motor',
      name: 'Test Motor',
      createdAt: DateTime(2026, 1, 4),
    );
    final visibility = VisibilitySettings(
      carId: car.id,
      settingsVisibility: const {'motor': true},
      favoriteSettings: const {'motor': true},
    );

    await repository.saveCars([car]);
    await repository.saveSavedSettings([setting]);
    await repository.saveRunLogs([runLog]);
    await repository.saveOwnedParts([ownedPart]);
    await repository.saveVisibilitySettings({car.id: visibility});
    await repository.saveLanguageSettings(true);
    await repository.saveOnlineMode(true);
    await repository.savePaperStyleEditor(true);

    final prefs = await SharedPreferences.getInstance();
    expect(jsonDecode(prefs.getString('cars_settings')!), [car.toJson()]);
    expect(
      jsonDecode(prefs.getString('saved_settings')!),
      [setting.toJson()],
    );
    expect(jsonDecode(prefs.getString('run_logs')!), [runLog.toJson()]);
    expect(
      jsonDecode(prefs.getString('owned_parts')!),
      [ownedPart.toJson()],
    );
    expect(
      jsonDecode(prefs.getString('visibility_settings')!),
      {car.id: visibility.toJson()},
    );
    expect(prefs.getBool('language_settings'), isTrue);
    expect(prefs.getBool('online_mode'), isTrue);
    expect(prefs.getBool('editor_layout_paper'), isTrue);

    expect((await repository.loadCars())?.single.id, car.id);
    expect((await repository.loadSavedSettings()).single.id, setting.id);
    expect((await repository.loadRunLogs()).single.id, runLog.id);
    expect((await repository.loadOwnedParts()).single.id, ownedPart.id);
    expect(
      (await repository.loadVisibilitySettings())[car.id]?.favoriteSettings,
      const {'motor': true},
    );
  });

  test('loads legacy visibility JSON without favorite settings', () async {
    final car = _buildCar();
    SharedPreferences.setMockInitialValues({
      'visibility_settings': jsonEncode({
        car.id: {
          'carId': car.id,
          'settingsVisibility': {'motor': false},
        },
      }),
    });
    final repository = SharedPreferencesSettingsLocalRepository();

    final loaded = await repository.loadVisibilitySettings();

    expect(loaded[car.id]?.settingsVisibility, const {'motor': false});
    expect(loaded[car.id]?.favoriteSettings, isEmpty);
  });

  test('loads legacy saved-setting JSON without run lineage fields', () async {
    final legacySetting = _buildSetting('legacy', DateTime(2026, 1, 1)).toJson()
      ..remove('kind')
      ..remove('sourceRunLogId')
      ..remove('parentSettingId');
    SharedPreferences.setMockInitialValues({
      'saved_settings': jsonEncode([legacySetting]),
    });
    final repository = SharedPreferencesSettingsLocalRepository();

    final loaded = (await repository.loadSavedSettings()).single;

    expect(loaded.kind, SavedSettingKind.manual);
    expect(loaded.sourceRunLogId, isNull);
    expect(loaded.parentSettingId, isNull);
  });

  test('loads through the injected repository and preserves newest-first order',
      () async {
    final localRepository = _MemorySettingsLocalRepository(
      cars: [_buildCar()],
      savedSettings: [
        _buildSetting('oldest', DateTime(2026, 1, 1)),
        _buildSetting('newest', DateTime(2026, 1, 3)),
        _buildSetting('middle', DateTime(2026, 1, 2)),
      ],
    );

    final provider = SettingsProvider(localRepository: localRepository);
    await _waitForProvider(provider);

    expect(
      provider.savedSettings.map((setting) => setting.id),
      ['newest', 'middle', 'oldest'],
    );
    expect(provider.cars.map((car) => car.id), contains(_buildCar().id));
  });

  test('initialization emits exactly one notification', () async {
    final provider = SettingsProvider(
      localRepository: _MemorySettingsLocalRepository(cars: [_buildCar()]),
    );
    var notifications = 0;
    provider.addListener(() => notifications++);

    await _waitForProvider(provider);

    expect(notifications, 1);
  });

  test('initializes visibility defaults explicitly and getter does not persist',
      () async {
    final localRepository = _MemorySettingsLocalRepository(
      cars: [_buildCar()],
    );

    final provider = SettingsProvider(localRepository: localRepository);
    await _waitForProvider(provider);

    expect(
      provider.cars.every(
        (car) => provider.visibilitySettings.containsKey(car.id),
      ),
      isTrue,
    );
    expect(localRepository.visibilitySaveCount, 1);

    final defaults = provider.getVisibilitySettings('custom/lazy-car');
    await Future<void>.delayed(Duration.zero);

    expect(defaults.carId, 'custom/lazy-car');
    expect(defaults.settingsVisibility, isNotEmpty);
    expect(provider.visibilitySettings, contains('custom/lazy-car'));
    expect(localRepository.visibilitySaveCount, 1);
  });

  test('keeps in-memory update and notification when local persistence fails',
      () async {
    final localRepository = _MemorySettingsLocalRepository(
      cars: [_buildCar()],
      failSavedSettingsWrites: true,
    );
    final provider = SettingsProvider(localRepository: localRepository);
    await _waitForProvider(provider);
    var notifications = 0;
    provider.addListener(() => notifications++);

    final setting = await provider.addSetting(
      'Unsaved setup',
      _buildCar(),
      const {'frontCamber': 1.5},
    );

    expect(provider.savedSettings.single.id, setting.id);
    expect(localRepository.savedSettingsSaveCount, 1);
    expect(notifications, 1);
  });

  test('uses injected cloud boundary only while online', () async {
    final localRepository = _MemorySettingsLocalRepository(
      cars: [_buildCar()],
      isOnlineMode: true,
    );
    final cloudRepository = _RecordingSettingsCloudRepository(userId: 'user');
    final provider = SettingsProvider(
      localRepository: localRepository,
      cloudRepository: cloudRepository,
    );
    await _waitForProvider(provider);

    expect(provider.isOnlineMode, isTrue);
    await provider.addSetting('Online setup', _buildCar(), const {});
    expect(cloudRepository.savedSettingCount, 1);

    await provider.syncToFirebase();
    expect(cloudRepository.syncCount, 1);

    await provider.setOfflineMode();
    await provider.addSetting('Offline setup', _buildCar(), const {});
    expect(cloudRepository.savedSettingCount, 1);
    expect(cloudRepository.syncCount, 1);
  });

  test('creates cloud boundary lazily when switching online', () async {
    final localRepository = _MemorySettingsLocalRepository(
      cars: [_buildCar()],
    );
    final cloudRepository = _RecordingSettingsCloudRepository();
    var factoryCalls = 0;
    final provider = SettingsProvider(
      localRepository: localRepository,
      cloudRepositoryFactory: () {
        factoryCalls++;
        return cloudRepository;
      },
    );
    await _waitForProvider(provider);

    expect(provider.isOnlineMode, isFalse);
    expect(factoryCalls, 0);

    await provider.setOnlineMode();

    expect(provider.isOnlineMode, isTrue);
    expect(factoryCalls, 1);
    expect(localRepository.isOnlineMode, isTrue);
  });

  test('keeps notification counts for no-op and nested CRUD operations',
      () async {
    final car = _buildCar();
    final localRepository = _MemorySettingsLocalRepository(cars: [car]);
    final provider = SettingsProvider(localRepository: localRepository);
    await _waitForProvider(provider);
    var notifications = 0;
    provider.addListener(() => notifications++);

    await provider.updateCar(
      Car(
        id: 'missing',
        name: 'Missing',
        imageUrl: '',
        manufacturer: car.manufacturer,
        category: car.category,
      ),
    );
    await provider.updateRunLog(
      RunLog(
        id: 'missing',
        createdAt: DateTime(2026),
        runAt: DateTime(2026),
        car: car,
        bestLapMillis: 0,
        feelTagIds: const [],
        memo: '',
        changes: const [],
      ),
    );
    await provider.setPaperStyleEditor(false);
    expect(notifications, 0);

    await provider.addRunLog(
      runAt: DateTime(2026, 1, 2),
      car: car,
      baseSetting: null,
      bestLapMillis: 12345,
      feelTagIds: const [],
      changes: const [
        RunSettingChange(
          settingKey: 'frontCamber',
          settingLabel: 'Front Camber',
          afterValue: 1.5,
        ),
      ],
    );
    expect(notifications, 2);

    await provider.addOwnedPart('motor', 'Test Motor');
    expect(notifications, 3);
    await provider.addOwnedPart('motor', ' test motor ');
    expect(notifications, 3);
  });

  test('preserves the existing two notifications for car CRUD', () async {
    final localRepository = _MemorySettingsLocalRepository(
      cars: [_buildCar()],
    );
    final provider = SettingsProvider(localRepository: localRepository);
    await _waitForProvider(provider);
    var notifications = 0;
    provider.addListener(() => notifications++);
    final car = Car(
      id: 'custom/second-car',
      name: 'Second Car',
      imageUrl: '',
      manufacturer: _buildCar().manufacturer,
      category: 'touring',
    );

    await provider.addCar(car);
    expect(notifications, 2);
    await provider.updateCar(car.copyWith(isInGarage: true));
    expect(notifications, 4);
    await provider.deleteCar(car.id);
    expect(notifications, 6);
  });

  test('loads cloud state into stores, persists it, and notifies once',
      () async {
    final localRepository = _MemorySettingsLocalRepository(
      cars: [_buildCar()],
      isOnlineMode: true,
    );
    final cloudCar = _buildCar();
    final cloudRepository = _RecordingSettingsCloudRepository(
      cloudSavedSettings: [
        _buildSetting('old', DateTime(2026, 1, 1)),
        _buildSetting('new', DateTime(2026, 1, 3)),
      ],
      cloudRunLogs: [
        RunLog(
          id: 'older-run',
          createdAt: DateTime(2026, 1, 1),
          runAt: DateTime(2026, 1, 1),
          car: cloudCar,
          bestLapMillis: 1,
          feelTagIds: const [],
          memo: '',
          changes: const [],
        ),
        RunLog(
          id: 'newer-run',
          createdAt: DateTime(2026, 1, 2),
          runAt: DateTime(2026, 1, 2),
          car: cloudCar,
          bestLapMillis: 1,
          feelTagIds: const [],
          memo: '',
          changes: const [],
        ),
      ],
      cloudCars: [cloudCar],
      cloudOwnedParts: [
        OwnedPart(
          id: 'cloud-part',
          category: 'motor',
          name: 'Cloud Motor',
          createdAt: DateTime(2026, 1, 4),
        ),
      ],
      cloudVisibilitySettings: {
        cloudCar.id: VisibilitySettings(
          carId: cloudCar.id,
          settingsVisibility: const {'motor': false},
        ),
      },
      cloudIsEnglish: true,
    );
    final provider = SettingsProvider(
      localRepository: localRepository,
      cloudRepository: cloudRepository,
    );
    await _waitForProvider(provider);
    var notifications = 0;
    provider.addListener(() => notifications++);

    await provider.loadFromFirebase();

    expect(provider.savedSettings.map((setting) => setting.id), ['new', 'old']);
    expect(provider.runLogs.map((runLog) => runLog.id), [
      'newer-run',
      'older-run',
    ]);
    expect(provider.isEnglish, isTrue);
    expect(provider.ownedParts.single.id, 'cloud-part');
    expect(
      provider.getVisibilitySettings(cloudCar.id).settingsVisibility['motor'],
      isFalse,
    );
    expect(localRepository.savedSettings.map((setting) => setting.id), [
      'new',
      'old',
    ]);
    expect(cloudRepository.savedCarsCount, 1);
    expect(notifications, 1);
  });
}

class _MemorySettingsLocalRepository implements SettingsLocalRepository {
  _MemorySettingsLocalRepository({
    this.cars,
    List<SavedSetting> savedSettings = const [],
    this.isOnlineMode = false,
    this.failSavedSettingsWrites = false,
  }) : savedSettings = List.of(savedSettings);

  List<Car>? cars;
  List<SavedSetting> savedSettings;
  List<RunLog> runLogs = [];
  List<OwnedPart> ownedParts = [];
  Map<String, VisibilitySettings> visibilitySettings = {};
  bool isEnglish = false;
  bool isOnlineMode;
  bool usePaperStyleEditor = false;
  final bool failSavedSettingsWrites;
  int savedSettingsSaveCount = 0;
  int visibilitySaveCount = 0;

  @override
  Future<List<Car>?> loadCars() async =>
      cars == null ? null : List<Car>.of(cars!);

  @override
  Future<void> saveCars(List<Car> cars) async {
    this.cars = List<Car>.of(cars);
  }

  @override
  Future<List<SavedSetting>> loadSavedSettings() async =>
      List<SavedSetting>.of(savedSettings);

  @override
  Future<void> saveSavedSettings(List<SavedSetting> savedSettings) async {
    savedSettingsSaveCount++;
    if (failSavedSettingsWrites) {
      throw StateError('simulated write failure');
    }
    this.savedSettings = List<SavedSetting>.of(savedSettings);
  }

  @override
  Future<List<RunLog>> loadRunLogs() async => List<RunLog>.of(runLogs);

  @override
  Future<void> saveRunLogs(List<RunLog> runLogs) async {
    this.runLogs = List<RunLog>.of(runLogs);
  }

  @override
  Future<List<OwnedPart>> loadOwnedParts() async =>
      List<OwnedPart>.of(ownedParts);

  @override
  Future<void> saveOwnedParts(List<OwnedPart> ownedParts) async {
    this.ownedParts = List<OwnedPart>.of(ownedParts);
  }

  @override
  Future<Map<String, VisibilitySettings>> loadVisibilitySettings() async =>
      Map<String, VisibilitySettings>.of(visibilitySettings);

  @override
  Future<void> saveVisibilitySettings(
    Map<String, VisibilitySettings> visibilitySettings,
  ) async {
    visibilitySaveCount++;
    this.visibilitySettings =
        Map<String, VisibilitySettings>.of(visibilitySettings);
  }

  @override
  Future<bool> loadLanguageSettings() async => isEnglish;

  @override
  Future<void> saveLanguageSettings(bool isEnglish) async {
    this.isEnglish = isEnglish;
  }

  @override
  Future<bool> loadOnlineMode() async => isOnlineMode;

  @override
  Future<void> saveOnlineMode(bool isOnlineMode) async {
    this.isOnlineMode = isOnlineMode;
  }

  @override
  Future<bool> loadPaperStyleEditor() async => usePaperStyleEditor;

  @override
  Future<void> savePaperStyleEditor(bool usePaperStyleEditor) async {
    this.usePaperStyleEditor = usePaperStyleEditor;
  }
}

class _RecordingSettingsCloudRepository implements SettingsCloudRepository {
  _RecordingSettingsCloudRepository({
    this.userId,
    this.cloudSavedSettings = const [],
    this.cloudRunLogs = const [],
    this.cloudCars = const [],
    this.cloudOwnedParts = const [],
    this.cloudVisibilitySettings = const {},
    this.cloudIsEnglish = false,
  });

  @override
  final String? userId;
  final List<SavedSetting> cloudSavedSettings;
  final List<RunLog> cloudRunLogs;
  final List<Car> cloudCars;
  final List<OwnedPart> cloudOwnedParts;
  final Map<String, VisibilitySettings> cloudVisibilitySettings;
  final bool cloudIsEnglish;

  int savedSettingCount = 0;
  int savedCarsCount = 0;
  int syncCount = 0;

  @override
  Future<void> saveSetting(SavedSetting setting) async {
    savedSettingCount++;
  }

  @override
  Future<List<SavedSetting>> getSavedSettings() async =>
      List<SavedSetting>.of(cloudSavedSettings);

  @override
  Future<void> deleteSetting(String settingId) async {}

  @override
  Future<void> saveRunLog(RunLog runLog) async {}

  @override
  Future<List<RunLog>> getRunLogs() async => List<RunLog>.of(cloudRunLogs);

  @override
  Future<void> deleteRunLog(String runLogId) async {}

  @override
  Future<void> saveCars(List<Car> cars) async {
    savedCarsCount++;
  }

  @override
  Future<List<Car>> getCars() async => List<Car>.of(cloudCars);

  @override
  Future<void> saveOwnedParts(List<OwnedPart> ownedParts) async {}

  @override
  Future<List<OwnedPart>> getOwnedParts() async =>
      List<OwnedPart>.of(cloudOwnedParts);

  @override
  Future<void> saveVisibilitySettings(
    Map<String, VisibilitySettings> visibilitySettings,
  ) async {}

  @override
  Future<Map<String, VisibilitySettings>> getVisibilitySettings() async =>
      Map<String, VisibilitySettings>.of(cloudVisibilitySettings);

  @override
  Future<void> saveLanguageSettings(bool isEnglish) async {}

  @override
  Future<bool> getLanguageSettings() async => cloudIsEnglish;

  @override
  Future<void> syncAllData({
    required List<SavedSetting> savedSettings,
    required List<RunLog> runLogs,
    required List<Car> cars,
    required List<OwnedPart> ownedParts,
    required Map<String, VisibilitySettings> visibilitySettings,
    required bool isEnglish,
  }) async {
    syncCount++;
  }
}
