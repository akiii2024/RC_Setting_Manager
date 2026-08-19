import 'dart:async';

import 'package:rc_setting_manager/utils/app_logger.dart';
import 'package:flutter/foundation.dart';
import '../models/saved_setting.dart';
import '../models/run_log.dart';
import '../models/car.dart';
import '../models/manufacturer.dart';
import '../models/owned_part.dart';
import '../models/visibility_settings.dart';
import '../models/settings_operation_result.dart';
import '../models/settings_snapshot_v2.dart';
import '../domain/parts/owned_part_store.dart';
import '../domain/settings/car_store.dart';
import '../domain/settings/display_settings_store.dart';
import '../domain/settings/run_log_store.dart';
import '../domain/settings/saved_setting_store.dart';
import '../domain/settings/settings_id_generator.dart';
import '../repositories/settings_cloud_repository.dart';
import '../repositories/settings_local_repository.dart';
import 'app_mode_provider.dart';

class SettingsProvider extends ChangeNotifier {
  static const String _firebaseCarSaveError = '車両のFirebase保存に失敗しました';
  static final _SettingsOperationCoordinator _productionCoordinator =
      _SettingsOperationCoordinator();
  static final Expando<_SettingsOperationCoordinator>
      _injectedRepositoryCoordinators =
      Expando<_SettingsOperationCoordinator>('settings-operation-coordinator');

  late final SavedSettingStore _savedSettingStore;
  final RunLogStore _runLogStore = RunLogStore();
  late final OwnedPartStore _ownedPartStore;
  final DisplaySettingsStore _displaySettingsStore = DisplaySettingsStore();
  final CarStore _carStore = CarStore();
  bool _isInitialized = false; // 初期化完了フラグ

  final SettingsLocalRepository _localRepository;
  final SettingsCloudRepositoryFactory _cloudRepositoryFactory;
  final AppModeProvider _appModeProvider;
  final SettingsIdGenerator _idGenerator;
  final Duration _cloudTimeout;
  late final _SettingsOperationCoordinator _operationCoordinator;
  SettingsCloudRepository? _firestoreService;
  late final Future<void> initialization;
  Object? _initializationError;
  StackTrace? _initializationStackTrace;
  bool _isDisposed = false;
  late Future<void> _mutationQueue;

  List<SavedSetting> get _savedSettings => _savedSettingStore.settings;
  List<RunLog> get _runLogs => _runLogStore.runLogs;
  List<OwnedPart> get _ownedParts => _ownedPartStore.parts;
  Map<String, VisibilitySettings> get _visibilitySettings =>
      _displaySettingsStore.visibilitySettings;
  bool get _isEnglish => _displaySettingsStore.isEnglish;
  bool get _usePaperStyleEditor => _displaySettingsStore.usePaperStyleEditor;
  List<Car> get _cars => _carStore.cars;
  bool get _isOnlineActive => _appModeProvider.isOnlineActive;

  List<SavedSetting> get savedSettings => List.unmodifiable(_savedSettings);
  List<RunLog> get runLogs => List.unmodifiable(_runLogs);
  List<OwnedPart> get ownedParts => List.unmodifiable(_ownedParts);
  Map<String, VisibilitySettings> get visibilitySettings =>
      Map.unmodifiable(_visibilitySettings);
  bool get isEnglish => _isEnglish;
  List<Car> get cars => List.unmodifiable(_cars);
  List<Car> get garageCars => List.unmodifiable(_carStore.garageCars);
  bool get usePaperStyleEditor => _usePaperStyleEditor;
  bool get isInitialized => _isInitialized;
  Object? get initializationError => _initializationError;
  StackTrace? get initializationStackTrace => _initializationStackTrace;
  Future<void> get localOperationsSettled => _mutationQueue;

  SettingsProvider({
    required AppModeProvider appModeProvider,
    SettingsLocalRepository? localRepository,
    SettingsCloudRepository? cloudRepository,
    SettingsCloudRepositoryFactory? cloudRepositoryFactory,
    SettingsIdGenerator? idGenerator,
    Duration cloudTimeout = const Duration(seconds: 15),
  })  : _localRepository =
            localRepository ?? SharedPreferencesSettingsLocalRepository(),
        _appModeProvider = appModeProvider,
        _idGenerator = idGenerator ?? SecureSettingsIdGenerator(),
        _cloudTimeout = cloudTimeout,
        _firestoreService = cloudRepository,
        _cloudRepositoryFactory = cloudRepositoryFactory ??
            (() => FirestoreSettingsCloudRepository()) {
    _operationCoordinator = _coordinatorFor(_localRepository);
    _savedSettingStore = SavedSettingStore(idGenerator: _idGenerator.nextId);
    _ownedPartStore = OwnedPartStore(idGenerator: _idGenerator.nextId);
    initialization = _scheduleLocalOperation(_initializeAsync);
    _mutationQueue = initialization;
  }

  static _SettingsOperationCoordinator _coordinatorFor(
    SettingsLocalRepository repository,
  ) {
    if (repository is SharedPreferencesSettingsLocalRepository) {
      return _productionCoordinator;
    }
    return _injectedRepositoryCoordinators[repository] ??=
        _SettingsOperationCoordinator();
  }

  static Future<SettingsProvider> create({
    required AppModeProvider appModeProvider,
    SettingsLocalRepository? localRepository,
    SettingsCloudRepository? cloudRepository,
    SettingsCloudRepositoryFactory? cloudRepositoryFactory,
    SettingsIdGenerator? idGenerator,
    Duration cloudTimeout = const Duration(seconds: 15),
  }) async {
    final provider = SettingsProvider(
      appModeProvider: appModeProvider,
      localRepository: localRepository,
      cloudRepository: cloudRepository,
      cloudRepositoryFactory: cloudRepositoryFactory,
      idGenerator: idGenerator,
      cloudTimeout: cloudTimeout,
    );
    try {
      await provider.initialization;
      return provider;
    } catch (_) {
      provider.dispose();
      rethrow;
    }
  }

  // 非同期初期化を安全に実行
  Future<void> _initializeAsync() async {
    final before = _currentSnapshot();
    try {
      final storedSnapshot = await _localRepository.loadSnapshot();
      final snapshot =
          storedSnapshot ?? await _localRepository.loadLegacySnapshot();
      _applySnapshot(snapshot, normalizeOrder: true);

      var snapshotChanged = storedSnapshot == null;
      if (_carStore.cars.isEmpty) {
        _carStore.useInitialCars();
        snapshotChanged = true;
      } else if (_carStore.mergeBuiltInCars(
        onError: (error) => debugLog('Error merging built-in cars: $error'),
      )) {
        snapshotChanged = true;
      }

      if (_displaySettingsStore.initializeVisibilityDefaults(
        _cars,
        _carStore.availableSettings,
      )) {
        snapshotChanged = true;
      }

      final initializedSnapshot = _currentSnapshot();
      _applySnapshot(before);

      if (snapshotChanged) {
        await _localRepository.saveSnapshot(initializedSnapshot);
      }
      if (_isDisposed) {
        throw StateError(
            'SettingsProvider was disposed during initialization.');
      }

      _applySnapshot(initializedSnapshot);
      _isInitialized = true;
      _notifyListenersIfActive();
    } catch (error, stackTrace) {
      _applySnapshot(before);
      _initializationError = error;
      _initializationStackTrace = stackTrace;
      debugLog('SettingsProvider initialization error: $error');
      rethrow;
    }
  }

  // 車種を更新
  Future<SettingsOperationResult<bool>> updateCar(Car updatedCar) async {
    return _commitMutation<bool>(
      operation: 'updateCar',
      mutate: () {
        final currentCar = _carStore.byId(updatedCar.id);
        if (currentCar == null) {
          return false;
        }
        final availableSettingsChanged = !listEquals(
            currentCar.availableSettings, updatedCar.availableSettings);
        final didUpdate = _carStore.update(updatedCar);
        if (didUpdate && availableSettingsChanged) {
          final currentVisibility =
              _displaySettingsStore.visibilitySettings[updatedCar.id];
          final availableSettings = _carStore.availableSettings(updatedCar.id);
          final updatedVisibility = <String, bool>{
            for (final key in availableSettings)
              key: currentVisibility?.settingsVisibility[key] ?? true,
          };
          final updatedFavorites = <String, bool>{
            for (final key in availableSettings)
              if (currentVisibility?.favoriteSettings[key] == true) key: true,
          };
          _displaySettingsStore.updateVisibility(
            VisibilitySettings(
              carId: updatedCar.id,
              settingsVisibility: updatedVisibility,
              favoriteSettings: updatedFavorites,
            ),
          );
        }
        return didUpdate;
      },
      didChange: (value) => value,
      sync: (cloud, snapshot) => cloud.saveCarsAndVisibilityAtomically(
        cars: snapshot.cars,
        visibilitySettings: snapshot.visibilitySettings,
      ),
      cloudErrorLog: _firebaseCarSaveError,
    );
  }

  // 車種を追加
  Future<SettingsOperationResult<Car>> addCar(Car newCar) {
    return _commitMutation<Car>(
      operation: 'addCar',
      mutate: () {
        if (_carStore.byId(newCar.id) != null) {
          throw StateError('A car with id ${newCar.id} already exists.');
        }
        _carStore.add(newCar);
        _displaySettingsStore.initializeVisibilityDefaults(
          [newCar],
          _carStore.availableSettings,
        );
        return newCar;
      },
      sync: (cloud, snapshot) => cloud.saveCarsAndVisibilityAtomically(
        cars: snapshot.cars,
        visibilitySettings: snapshot.visibilitySettings,
      ),
      cloudErrorLog: _firebaseCarSaveError,
    );
  }

  // 車種を削除
  Future<SettingsOperationResult<bool>> deleteCar(String carId) async {
    return _commitMutation<bool>(
      operation: 'deleteCar',
      mutate: () {
        if (_carStore.byId(carId) == null) {
          return false;
        }
        _carStore.delete(carId);
        _displaySettingsStore.removeVisibility(carId);
        return true;
      },
      didChange: (value) => value,
      sync: (cloud, snapshot) => cloud.saveCarsAndVisibilityAtomically(
        cars: snapshot.cars,
        visibilitySettings: snapshot.visibilitySettings,
      ),
      cloudErrorLog: _firebaseCarSaveError,
    );
  }

  // メーカーリストを取得
  List<Manufacturer> getManufacturers() {
    return _carStore.manufacturers();
  }

  Map<Manufacturer, List<Car>> getGarageCarsByManufacturer() {
    return _carStore.garageCarsByManufacturer();
  }

  // 特定の車種を取得
  Car? getCarById(String carId) {
    return _carStore.byId(carId);
  }

  // 車種固有の設定項目を取得
  List<String> getCarAvailableSettings(String carId) {
    return _carStore.availableSettings(carId);
  }

  List<String> getSuggestionsForSetting(
    String key,
    List<String>? baseOptions, {
    String query = '',
  }) {
    return _ownedPartStore.suggestions(
      key: key,
      baseOptions: baseOptions,
      savedSettings: _savedSettings,
      query: query,
    );
  }

  List<OwnedPart> getOwnedPartsByCategory(String category) {
    return _ownedPartStore.byCategory(category);
  }

  Future<SettingsOperationResult<OwnedPart?>> addOwnedPart(
    String category,
    String name,
  ) async {
    final normalizedName = name.trim();
    var changed = false;
    return _commitMutation<OwnedPart?>(
      operation: 'addOwnedPart',
      mutate: () {
        final result = _ownedPartStore.add(category, normalizedName);
        changed = result.changed;
        return result.part;
      },
      didChange: (_) => changed,
      sync: (cloud, snapshot) => cloud.saveOwnedParts(snapshot.ownedParts),
    );
  }

  Future<SettingsOperationResult<bool>> updateOwnedPart(
    String id, {
    required String category,
    required String name,
  }) async {
    final normalizedName = name.trim();
    return _commitMutation<bool>(
      operation: 'updateOwnedPart',
      mutate: () => _ownedPartStore.update(
        id,
        category: category,
        name: normalizedName,
      ),
      didChange: (value) => value,
      sync: (cloud, snapshot) => cloud.saveOwnedParts(snapshot.ownedParts),
    );
  }

  Future<SettingsOperationResult<bool>> deleteOwnedPart(String id) async {
    return _commitMutation<bool>(
      operation: 'deleteOwnedPart',
      mutate: () {
        if (_ownedParts.every((part) => part.id != id)) {
          return false;
        }
        _ownedPartStore.delete(id);
        return true;
      },
      didChange: (value) => value,
      sync: (cloud, snapshot) => cloud.saveOwnedParts(snapshot.ownedParts),
    );
  }

  List<OwnedPartImportCandidate> getOwnedPartImportCandidatesFromHistory() {
    return _ownedPartStore.importCandidates(_savedSettings);
  }

  Future<SettingsOperationResult<bool>> importOwnedPartsFromHistory(
    List<OwnedPartImportCandidate> selectedCandidates,
  ) async {
    return _commitMutation<bool>(
      operation: 'importOwnedPartsFromHistory',
      mutate: () => _ownedPartStore.importFromHistory(selectedCandidates),
      didChange: (value) => value,
      sync: (cloud, snapshot) => cloud.saveOwnedParts(snapshot.ownedParts),
    );
  }

  Future<SettingsOperationResult<bool>> setGarageMembership(
    String carId,
    bool value,
  ) async {
    return _commitMutation<bool>(
      operation: 'setGarageMembership',
      mutate: () {
        final car = _carStore.byId(carId);
        if (car == null || car.isInGarage == value) {
          return false;
        }
        return _carStore.update(car.copyWith(isInGarage: value));
      },
      didChange: (changed) => changed,
      sync: (cloud, snapshot) => cloud.saveCars(snapshot.cars),
      cloudErrorLog: _firebaseCarSaveError,
    );
  }

  Future<SettingsOperationResult<bool>> setGaragePromptSuppressed(
    String carId,
    bool value,
  ) async {
    return _commitMutation<bool>(
      operation: 'setGaragePromptSuppressed',
      mutate: () {
        final car = _carStore.byId(carId);
        if (car == null || car.suppressGaragePrompt == value) {
          return false;
        }
        return _carStore.update(car.copyWith(suppressGaragePrompt: value));
      },
      didChange: (changed) => changed,
      sync: (cloud, snapshot) => cloud.saveCars(snapshot.cars),
      cloudErrorLog: _firebaseCarSaveError,
    );
  }

  Future<SettingsOperationResult<SavedSetting?>> updateSetting(
    SavedSetting updatedSetting,
  ) async {
    return _commitMutation<SavedSetting?>(
      operation: 'updateSetting',
      mutate: () => _savedSettingStore.update(updatedSetting),
      didChange: (value) => value != null,
      sync: (cloud, snapshot) async {
        final saved = snapshot.savedSettings.firstWhere(
          (setting) => setting.id == updatedSetting.id,
        );
        await cloud.saveSetting(saved);
      },
    );
  }

  // Get visibility settings (create an in-memory default if not exists).
  // Persisted defaults for known cars are prepared during initialization.
  VisibilitySettings getVisibilitySettings(String carId) {
    return _displaySettingsStore.visibilityFor(
      carId,
      _carStore.availableSettings,
    );
  }

  // Toggle visibility for a specific setting
  Future<SettingsOperationResult<bool>> toggleSettingVisibility(
      String carId, String settingKey, bool isVisible) async {
    return _commitMutation<bool>(
      operation: 'toggleSettingVisibility',
      mutate: () {
        final current = _displaySettingsStore.visibilityFor(
          carId,
          _carStore.availableSettings,
        );
        if (current.settingsVisibility[settingKey] == isVisible) {
          return false;
        }
        _displaySettingsStore.updateVisibility(
          _displaySettingsStore.withVisibility(
            carId,
            settingKey,
            isVisible,
            _carStore.availableSettings,
          ),
        );
        return true;
      },
      didChange: (changed) => changed,
      sync: (cloud, snapshot) =>
          cloud.saveVisibilitySettings(snapshot.visibilitySettings),
    );
  }

  // Toggle favorite for a specific setting
  Future<SettingsOperationResult<bool>> toggleFavoriteSetting(
      String carId, String settingKey, bool isFavorite) async {
    return _commitMutation<bool>(
      operation: 'toggleFavoriteSetting',
      mutate: () {
        final current = _displaySettingsStore.visibilityFor(
          carId,
          _carStore.availableSettings,
        );
        if ((current.favoriteSettings[settingKey] == true) == isFavorite) {
          return false;
        }
        _displaySettingsStore.updateVisibility(
          _displaySettingsStore.withFavorite(
            carId,
            settingKey,
            isFavorite,
            _carStore.availableSettings,
          ),
        );
        return true;
      },
      didChange: (changed) => changed,
      sync: (cloud, snapshot) =>
          cloud.saveVisibilitySettings(snapshot.visibilitySettings),
    );
  }

  // Get favorite settings for a car
  List<String> getFavoriteSettings(String carId) {
    return _displaySettingsStore.favoriteSettings(
      carId,
      _carStore.availableSettings,
    );
  }

  // Firebaseにデータを同期
  Future<SettingsOperationResult<void>> syncToFirebase() {
    final targetCapture = _captureCloudTargetForRequest();
    Future<void>? cloudOperation;
    final preparation = _scheduleLocalOperation<SettingsOperationResult<void>>(
      () async {
        final guardFailure = _guardFailure<void>('syncToFirebase');
        if (guardFailure != null) {
          return guardFailure;
        }
        if (!_isOnlineActive) {
          return SettingsOperationFailure(
            SettingsPersistenceFailure(
              kind: SettingsPersistenceFailureKind.read,
              operation: 'syncToFirebase',
              cause: StateError('Online mode is not active.'),
              stackTrace: StackTrace.current,
            ),
          );
        }
        final target = targetCapture.target;
        if (target == null) {
          return _cloudTargetFailure<void>(
            targetCapture,
            kind: SettingsPersistenceFailureKind.write,
            operation: 'syncToFirebase',
          );
        }

        final committedSnapshot = SettingsSnapshotV2.fromJson(
          _currentSnapshot().toJson(),
        );
        cloudOperation = _scheduleCloudOperation(() async {
          _ensureCloudTarget(target, operation: 'cloud sync');
          await _syncAllData(target.repository, committedSnapshot);
          _ensureCloudTarget(target, operation: 'cloud sync');
        });
        return const SettingsOperationSuccess();
      },
    );
    _mutationQueue = preparation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );

    return preparation.then((prepared) async {
      if (prepared is SettingsOperationFailure<void> ||
          cloudOperation == null) {
        return prepared;
      }
      try {
        await cloudOperation!.timeout(_cloudTimeout);
        debugLog('データをFirebaseに同期しました');
        return const SettingsOperationSuccess();
      } catch (error, stackTrace) {
        debugLog('Firebase同期エラー: $error');
        return SettingsOperationFailure(
          SettingsPersistenceFailure(
            kind: SettingsPersistenceFailureKind.write,
            operation: 'syncToFirebase',
            cause: error,
            stackTrace: stackTrace,
          ),
        );
      }
    });
  }

  // Firebaseからデータを読み込み
  Future<SettingsOperationResult<void>> loadFromFirebase() {
    final targetCapture = _captureCloudTargetForRequest();
    final localCommit = _scheduleLocalOperation<_CommittedMutation<void>>(
      () async {
        final guardFailure = _guardFailure<void>('loadFromFirebase');
        if (guardFailure != null) {
          return _CommittedMutation(result: guardFailure);
        }
        if (!_isOnlineActive) {
          return _CommittedMutation(
            result: SettingsOperationFailure(
              SettingsPersistenceFailure(
                kind: SettingsPersistenceFailureKind.read,
                operation: 'loadFromFirebase',
                cause: StateError('Online mode is not active.'),
                stackTrace: StackTrace.current,
              ),
            ),
          );
        }

        final target = targetCapture.target;
        if (target == null) {
          return _CommittedMutation(
            result: _cloudTargetFailure<void>(
              targetCapture,
              kind: SettingsPersistenceFailureKind.read,
              operation: 'loadFromFirebase',
            ),
          );
        }

        try {
          late List<SavedSetting> cloudSettings;
          late List<RunLog> cloudRunLogs;
          late List<OwnedPart> cloudOwnedParts;
          late List<Car> cloudCars;
          late Map<String, VisibilitySettings> cloudVisibility;
          late bool cloudIsEnglish;
          var acceptsCloudReadResult = true;

          Future<T> readCloudValue<T>(
            String step,
            Future<T> Function() read,
          ) async {
            if (!acceptsCloudReadResult) {
              throw StateError('Cloud load request has already timed out.');
            }
            _ensureCloudTarget(target, operation: 'cloud load before $step');
            final value = await read();
            if (!acceptsCloudReadResult) {
              throw StateError('Cloud load request has already timed out.');
            }
            _ensureCloudTarget(target, operation: 'cloud load after $step');
            return value;
          }

          Future<void> readAll() async {
            cloudSettings = await readCloudValue(
              'saved settings',
              target.repository.getSavedSettings,
            );
            cloudRunLogs = await readCloudValue(
              'run logs',
              target.repository.getRunLogs,
            );
            cloudOwnedParts = await readCloudValue(
              'owned parts',
              target.repository.getOwnedParts,
            );
            cloudCars = await readCloudValue(
              'cars',
              target.repository.getCars,
            );
            cloudVisibility = await readCloudValue(
              'visibility settings',
              target.repository.getVisibilitySettings,
            );
            cloudIsEnglish = await readCloudValue(
              'language settings',
              target.repository.getLanguageSettings,
            );
          }

          final readOperation = _scheduleCloudOperation(readAll);
          try {
            await readOperation.timeout(_cloudTimeout);
          } on TimeoutException {
            acceptsCloudReadResult = false;
            rethrow;
          }
          _ensureCloudTarget(target, operation: 'cloud load commit');

          return _commitMutationNow<void>(
            operation: 'loadFromFirebase',
            cloudTargetCapture: targetCapture,
            mutate: () {
              _savedSettingStore.replace(
                cloudSettings,
                sortNewestFirst: true,
              );
              _runLogStore.replace(cloudRunLogs, sortNewestFirst: true);
              _ownedPartStore.replace(cloudOwnedParts, sortByName: true);
              _carStore.replace(cloudCars);
              _carStore.mergeBuiltInCars(
                onError: (error) =>
                    debugLog('Error merging built-in cars: $error'),
              );
              _displaySettingsStore.replaceVisibilitySettings(cloudVisibility);
              _displaySettingsStore.initializeVisibilityDefaults(
                _cars,
                _carStore.availableSettings,
              );
              _displaySettingsStore.setLanguage(cloudIsEnglish);
            },
            sync: (repository, snapshot) =>
                repository.saveCarsAndVisibilityAtomically(
              cars: snapshot.cars,
              visibilitySettings: snapshot.visibilitySettings,
            ),
          );
        } catch (error, stackTrace) {
          debugLog('Firebase読み込みエラー: $error');
          return _CommittedMutation(
            result: SettingsOperationFailure(
              SettingsPersistenceFailure(
                kind: SettingsPersistenceFailureKind.read,
                operation: 'loadFromFirebase',
                cause: error,
                stackTrace: stackTrace,
              ),
            ),
          );
        }
      },
    );
    _mutationQueue = localCommit.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return localCommit.then(_resolveCommittedMutation);
  }

  // 設定追加時にFirebaseにも保存
  Future<SettingsOperationResult<SavedSetting>> addSetting(
    String name,
    Car car,
    Map<String, dynamic> settings, {
    SavedSettingKind kind = SavedSettingKind.manual,
    String? sourceRunLogId,
    String? parentSettingId,
  }) {
    late SavedSetting newSetting;
    return _commitMutation<SavedSetting>(
      operation: 'addSetting',
      mutate: () {
        newSetting = _savedSettingStore.add(
          name,
          car,
          settings,
          kind: kind,
          sourceRunLogId: sourceRunLogId,
          parentSettingId: parentSettingId,
        );
        return newSetting;
      },
      sync: (cloud, snapshot) => cloud.saveSetting(newSetting),
    );
  }

  Future<SettingsOperationResult<List<SavedSetting>>> addSettingsBatch(
    List<NewSavedSettingInput> inputs,
  ) {
    final detachedInputs = List<NewSavedSettingInput>.unmodifiable(inputs);
    var created = <SavedSetting>[];
    return _commitMutation<List<SavedSetting>>(
      operation: 'addSettingsBatch',
      mutate: () {
        created =
            detachedInputs.map(_addSettingFromInput).toList(growable: false);
        return List<SavedSetting>.unmodifiable(created);
      },
      didChange: (settings) => settings.isNotEmpty,
      sync: (cloud, snapshot) => cloud.saveSettingsAndCarsAtomically(
        settings: created,
      ),
    );
  }

  Future<
      SettingsOperationResult<
          ({
            SavedSetting baseSetting,
            SavedSetting derivedSetting,
          })>> addDerivedSettingWithBase({
    String? existingBaseSettingId,
    required NewSavedSettingInput base,
    required NewSavedSettingInput derived,
  }) {
    var created = <SavedSetting>[];
    return _commitMutation<
        ({
          SavedSetting baseSetting,
          SavedSetting derivedSetting,
        })>(
      operation: 'addDerivedSettingWithBase',
      mutate: () {
        SavedSetting? baseSetting;
        if (existingBaseSettingId != null) {
          for (final setting in _savedSettings) {
            if (setting.id == existingBaseSettingId) {
              baseSetting = setting;
              break;
            }
          }
        }
        if (baseSetting == null) {
          baseSetting = _addSettingFromInput(base);
          created.add(baseSetting);
        }
        if (baseSetting.car.id != derived.car.id) {
          throw StateError('Base and derived settings must use the same car.');
        }
        final derivedSetting = _savedSettingStore.add(
          derived.name,
          derived.car,
          derived.settings,
          kind: derived.kind,
          sourceRunLogId: derived.sourceRunLogId,
          parentSettingId: baseSetting.id,
        );
        created.add(derivedSetting);
        return (
          baseSetting: baseSetting,
          derivedSetting: derivedSetting,
        );
      },
      sync: (cloud, snapshot) => cloud.saveSettingsAndCarsAtomically(
        settings: created,
      ),
    );
  }

  Future<SettingsOperationResult<SavedSetting>> addSettingWithCarUpdate(
    String name,
    Car car,
    Map<String, dynamic> settings, {
    bool? isInGarage,
    bool? suppressGaragePrompt,
    SavedSettingKind kind = SavedSettingKind.manual,
    String? sourceRunLogId,
    String? parentSettingId,
  }) {
    late SavedSetting created;
    final shouldUpdateCar = isInGarage != null || suppressGaragePrompt != null;
    return _commitMutation<SavedSetting>(
      operation: 'addSettingWithCarUpdate',
      mutate: () {
        var effectiveCar = car;
        if (shouldUpdateCar) {
          final currentCar = _carStore.byId(car.id);
          if (currentCar == null) {
            throw StateError('Cannot update an unknown car: ${car.id}.');
          }
          effectiveCar = currentCar.copyWith(
            isInGarage: isInGarage,
            suppressGaragePrompt: suppressGaragePrompt,
          );
          _carStore.update(effectiveCar);
        }
        created = _savedSettingStore.add(
          name,
          effectiveCar,
          settings,
          kind: kind,
          sourceRunLogId: sourceRunLogId,
          parentSettingId: parentSettingId,
        );
        return created;
      },
      sync: (cloud, snapshot) => cloud.saveSettingsAndCarsAtomically(
        settings: [created],
        cars: shouldUpdateCar ? snapshot.cars : null,
      ),
    );
  }

  SavedSetting _addSettingFromInput(NewSavedSettingInput input) {
    return _savedSettingStore.add(
      input.name,
      input.car,
      input.settings,
      kind: input.kind,
      sourceRunLogId: input.sourceRunLogId,
      parentSettingId: input.parentSettingId,
    );
  }

  SavedSetting? getLatestSettingForCar(String carId) {
    return _savedSettingStore.latestForCar(carId);
  }

  List<SavedSetting> getSavedSettingsForCar(String carId) {
    return _savedSettingStore.forCar(carId);
  }

  Future<SettingsOperationResult<RunLog>> addRunLog({
    required DateTime runAt,
    required Car car,
    SavedSetting? baseSetting,
    String trackName = '',
    required int bestLapMillis,
    double? airTempC,
    double? humidityPercent,
    String weatherCondition = '',
    double? trackTempC,
    String trackCondition = '',
    required List<String> feelTagIds,
    String memo = '',
    List<RunSettingChange> changes = const [],
  }) async {
    final effectiveChanges = _runLogStore.effectiveChanges(changes);

    SavedSetting? resultSetting;
    late RunLog runLog;
    return _commitMutation<RunLog>(
      operation: 'addRunLog',
      mutate: () {
        final now = DateTime.now();
        final runLogId = _idGenerator.nextId();
        if (effectiveChanges.isNotEmpty) {
          resultSetting = _savedSettingStore.add(
            _savedSettingStore.runResultName(runAt, car),
            car,
            _runLogStore.applyChanges(baseSetting, effectiveChanges),
            kind: SavedSettingKind.runResult,
            sourceRunLogId: runLogId,
            parentSettingId: baseSetting?.id,
          );
        }
        runLog = _runLogStore.add(
          id: runLogId,
          createdAt: now,
          runAt: runAt,
          car: car,
          baseSetting: baseSetting,
          resultSetting: resultSetting,
          trackName: trackName,
          bestLapMillis: bestLapMillis,
          airTempC: airTempC,
          humidityPercent: humidityPercent,
          weatherCondition: weatherCondition,
          trackTempC: trackTempC,
          trackCondition: trackCondition,
          feelTagIds: feelTagIds,
          memo: memo,
          changes: effectiveChanges,
        );
        return runLog;
      },
      sync: (cloud, snapshot) => cloud.saveRunLogWithResultSetting(
        runLog: runLog,
        resultSetting: resultSetting,
      ),
    );
  }

  Future<SettingsOperationResult<bool>> updateRunLog(
    RunLog updatedRunLog,
  ) async {
    return _commitMutation<bool>(
      operation: 'updateRunLog',
      mutate: () => _runLogStore.update(updatedRunLog),
      didChange: (changed) => changed,
      sync: (cloud, snapshot) => cloud.saveRunLog(updatedRunLog),
    );
  }

  Future<SettingsOperationResult<bool>> deleteRunLog(String id) async {
    return _commitMutation<bool>(
      operation: 'deleteRunLog',
      mutate: () {
        if (_runLogs.every((runLog) => runLog.id != id)) {
          return false;
        }
        _runLogStore.delete(id);
        return true;
      },
      didChange: (changed) => changed,
      sync: (cloud, snapshot) => cloud.deleteRunLog(id),
    );
  }

  // 設定削除時にFirebaseからも削除
  Future<SettingsOperationResult<bool>> deleteSetting(String id) async {
    return _commitMutation<bool>(
      operation: 'deleteSetting',
      mutate: () {
        if (_savedSettings.every((setting) => setting.id != id)) {
          return false;
        }
        _savedSettingStore.delete(id);
        return true;
      },
      didChange: (changed) => changed,
      sync: (cloud, snapshot) => cloud.deleteSetting(id),
    );
  }

  // 言語設定変更時にFirebaseにも保存
  Future<SettingsOperationResult<bool>> toggleLanguage() {
    return _commitMutation<bool>(
      operation: 'toggleLanguage',
      mutate: _displaySettingsStore.toggleLanguage,
      sync: (cloud, snapshot) => cloud.saveLanguageSettings(snapshot.isEnglish),
    );
  }

  // 表示設定更新時にFirebaseにも保存
  Future<SettingsOperationResult<bool>> setPaperStyleEditor(bool value) async {
    return _commitMutation<bool>(
      operation: 'setPaperStyleEditor',
      mutate: () => _displaySettingsStore.setPaperStyleEditor(value),
      didChange: (changed) => changed,
    );
  }

  Future<SettingsOperationResult<bool>> updateVisibilitySettings(
    VisibilitySettings settings,
  ) {
    return _commitMutation<bool>(
      operation: 'updateVisibilitySettings',
      mutate: () {
        final current = _visibilitySettings[settings.carId];
        if (current != null &&
            mapEquals(
                current.settingsVisibility, settings.settingsVisibility) &&
            mapEquals(current.favoriteSettings, settings.favoriteSettings)) {
          return false;
        }
        _displaySettingsStore.updateVisibility(settings);
        return true;
      },
      didChange: (changed) => changed,
      sync: (cloud, snapshot) =>
          cloud.saveVisibilitySettings(snapshot.visibilitySettings),
    );
  }

  // すべてのデータを置き換え（インポート用）
  Future<SettingsOperationResult<void>> replaceAllData({
    required List<Car> cars,
    required List<SavedSetting> savedSettings,
    List<RunLog> runLogs = const [],
    List<OwnedPart> ownedParts = const [],
    required Map<String, VisibilitySettings> visibilitySettings,
  }) {
    return _commitMutation<void>(
      operation: 'replaceAllData',
      mutate: () {
        _carStore.replace(List<Car>.of(cars));
        _savedSettingStore.replace(
          List<SavedSetting>.of(savedSettings),
          sortNewestFirst: true,
        );
        _runLogStore.replace(List<RunLog>.of(runLogs), sortNewestFirst: true);
        _ownedPartStore.replace(List<OwnedPart>.of(ownedParts));
        _displaySettingsStore.replaceVisibilitySettings(
          Map<String, VisibilitySettings>.of(visibilitySettings),
        );
        _carStore.mergeBuiltInCars(
          onError: (error) => debugLog('Error merging built-in cars: $error'),
        );
        _displaySettingsStore.initializeVisibilityDefaults(
          _cars,
          _carStore.availableSettings,
        );
      },
      sync: (cloud, snapshot) => _syncAllData(cloud, snapshot),
    );
  }

  // 部分的なデータ置き換え（部分的インポート用）
  Future<SettingsOperationResult<void>> replacePartialData({
    List<Car>? cars,
    List<SavedSetting>? savedSettings,
    List<RunLog>? runLogs,
    List<OwnedPart>? ownedParts,
    Map<String, VisibilitySettings>? visibilitySettings,
    bool? isEnglish,
  }) {
    return _commitMutation<void>(
      operation: 'replacePartialData',
      mutate: () {
        if (cars != null) {
          _carStore.replace(List<Car>.of(cars));
        }
        if (savedSettings != null) {
          _savedSettingStore.replace(
            List<SavedSetting>.of(savedSettings),
            sortNewestFirst: true,
          );
        }
        if (runLogs != null) {
          _runLogStore.replace(
            List<RunLog>.of(runLogs),
            sortNewestFirst: true,
          );
        }
        if (ownedParts != null) {
          _ownedPartStore.replace(List<OwnedPart>.of(ownedParts));
        }
        if (visibilitySettings != null) {
          _displaySettingsStore.replaceVisibilitySettings(
            Map<String, VisibilitySettings>.of(visibilitySettings),
          );
        }
        if (isEnglish != null) {
          _displaySettingsStore.setLanguage(isEnglish);
        }
        if (cars != null || visibilitySettings != null) {
          _carStore.mergeBuiltInCars(
            onError: (error) => debugLog('Error merging built-in cars: $error'),
          );
          _displaySettingsStore.initializeVisibilityDefaults(
            _cars,
            _carStore.availableSettings,
          );
        }
      },
      sync: (cloud, snapshot) => _syncAllData(cloud, snapshot),
    );
  }

  SettingsSnapshotV2 _currentSnapshot() {
    return SettingsSnapshotV2(
      cars: List<Car>.of(_cars),
      savedSettings: List<SavedSetting>.of(_savedSettings),
      runLogs: List<RunLog>.of(_runLogs),
      ownedParts: List<OwnedPart>.of(_ownedParts),
      visibilitySettings:
          Map<String, VisibilitySettings>.of(_visibilitySettings),
      isEnglish: _isEnglish,
      usePaperStyleEditor: _usePaperStyleEditor,
    );
  }

  void _applySnapshot(
    SettingsSnapshotV2 snapshot, {
    bool normalizeOrder = false,
  }) {
    _carStore.replace(List<Car>.of(snapshot.cars));
    _savedSettingStore.replace(
      List<SavedSetting>.of(snapshot.savedSettings),
      sortNewestFirst: normalizeOrder,
    );
    _runLogStore.replace(
      List<RunLog>.of(snapshot.runLogs),
      sortNewestFirst: normalizeOrder,
    );
    _ownedPartStore.replace(
      List<OwnedPart>.of(snapshot.ownedParts),
      sortByName: normalizeOrder,
    );
    _displaySettingsStore.replaceVisibilitySettings(
      Map<String, VisibilitySettings>.of(snapshot.visibilitySettings),
    );
    _displaySettingsStore.setLanguage(snapshot.isEnglish);
    _displaySettingsStore.setPaperStyleEditor(snapshot.usePaperStyleEditor);
  }

  Future<SettingsOperationResult<T>> _commitMutation<T>({
    required String operation,
    required T Function() mutate,
    bool Function(T value)? didChange,
    Future<void> Function(
      SettingsCloudRepository cloud,
      SettingsSnapshotV2 snapshot,
    )? sync,
    String? cloudErrorLog,
  }) {
    final cloudTargetCapture = sync == null
        ? const _CloudTargetCapture.skipped()
        : _captureCloudTargetForRequest();
    final localCommit = _scheduleLocalOperation<_CommittedMutation<T>>(
      () async {
        final guardFailure = _guardFailure<T>(operation);
        if (guardFailure != null) {
          return _CommittedMutation(result: guardFailure);
        }
        return _commitMutationNow<T>(
          operation: operation,
          cloudTargetCapture: cloudTargetCapture,
          mutate: mutate,
          didChange: didChange,
          sync: sync,
          cloudErrorLog: cloudErrorLog,
        );
      },
    );
    _mutationQueue = localCommit.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return localCommit.then(_resolveCommittedMutation);
  }

  Future<_CommittedMutation<T>> _commitMutationNow<T>({
    required String operation,
    required _CloudTargetCapture cloudTargetCapture,
    required T Function() mutate,
    bool Function(T value)? didChange,
    Future<void> Function(
      SettingsCloudRepository cloud,
      SettingsSnapshotV2 snapshot,
    )? sync,
    String? cloudErrorLog,
  }) async {
    final before = _currentSnapshot();
    late final T value;
    late final SettingsSnapshotV2 draft;
    try {
      value = mutate();
      final changed = didChange?.call(value) ?? true;
      if (!changed) {
        _applySnapshot(before);
        return _CommittedMutation(
          result: SettingsOperationSuccess(value: value),
        );
      }
      draft = SettingsSnapshotV2.fromJson(_currentSnapshot().toJson());
      // A mutation is built synchronously as a draft. Do not expose it until
      // the complete snapshot has been persisted successfully.
      _applySnapshot(before);
    } catch (error, stackTrace) {
      _applySnapshot(before);
      debugLog('Settings mutation failed for $operation: $error');
      return _CommittedMutation(
        result: SettingsOperationFailure(
          SettingsPersistenceFailure(
            kind: SettingsPersistenceFailureKind.invalidData,
            operation: operation,
            cause: error,
            stackTrace: stackTrace,
          ),
        ),
      );
    }

    try {
      await _localRepository.saveSnapshot(draft);
    } catch (error, stackTrace) {
      debugLog('Local persistence failed for $operation: $error');
      return _CommittedMutation(
        result: SettingsOperationFailure(
          SettingsPersistenceFailure(
            kind: SettingsPersistenceFailureKind.write,
            operation: operation,
            cause: error,
            stackTrace: stackTrace,
          ),
        ),
      );
    }

    _applySnapshot(draft);

    Future<SettingsSyncWarning?>? warningFuture;
    final captureFailure = cloudTargetCapture.failure;
    if (sync != null && captureFailure != null) {
      debugLog(
        '${cloudErrorLog ?? 'Firebase save failed'}: $captureFailure',
      );
      warningFuture = Future<SettingsSyncWarning?>.value(
        SettingsSyncWarning(
          operation: operation,
          cause: captureFailure,
          stackTrace:
              cloudTargetCapture.failureStackTrace ?? StackTrace.current,
        ),
      );
    } else if (!_isDisposed && _isOnlineActive && sync != null) {
      final target = cloudTargetCapture.target;
      if (target == null) {
        _notifyListenersIfActive();
        return _CommittedMutation(
          result: SettingsOperationSuccess(value: value),
        );
      }
      final cloudOperation = _scheduleCloudOperation(() async {
        _ensureCloudTarget(target, operation: operation);
        await sync(target.repository, draft);
        _ensureCloudTarget(target, operation: operation);
      });
      warningFuture = _cloudWarning(
        cloudOperation,
        operation: operation,
        cloudErrorLog: cloudErrorLog,
      );
    }

    _notifyListenersIfActive();
    return _CommittedMutation(
      result: SettingsOperationSuccess(value: value),
      warningFuture: warningFuture,
    );
  }

  Future<SettingsOperationResult<T>> _resolveCommittedMutation<T>(
    _CommittedMutation<T> committed,
  ) async {
    final result = committed.result;
    if (result is SettingsOperationFailure<T>) {
      return result;
    }
    final success = result as SettingsOperationSuccess<T>;
    final warningFuture = committed.warningFuture;
    final warning = warningFuture == null ? null : await warningFuture;
    return SettingsOperationSuccess(value: success.value, warning: warning);
  }

  Future<SettingsSyncWarning?> _cloudWarning(
    Future<void> operationFuture, {
    required String operation,
    String? cloudErrorLog,
  }) async {
    try {
      await operationFuture.timeout(_cloudTimeout);
      return null;
    } catch (error, stackTrace) {
      debugLog('${cloudErrorLog ?? 'Firebase save failed'}: $error');
      return SettingsSyncWarning(
        operation: operation,
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  SettingsOperationFailure<T>? _guardFailure<T>(String operation) {
    if (_isDisposed) {
      return SettingsOperationFailure(
        SettingsPersistenceFailure(
          kind: SettingsPersistenceFailureKind.write,
          operation: operation,
          cause: StateError('SettingsProvider has been disposed.'),
          stackTrace: StackTrace.current,
        ),
      );
    }
    final initializationError = _initializationError;
    if (initializationError != null) {
      return SettingsOperationFailure(
        SettingsPersistenceFailure(
          kind: SettingsPersistenceFailureKind.read,
          operation: operation,
          cause: initializationError,
          stackTrace: _initializationStackTrace ?? StackTrace.empty,
        ),
      );
    }
    return null;
  }

  Future<T> _scheduleLocalOperation<T>(Future<T> Function() operation) {
    return _operationCoordinator.scheduleLocal(operation);
  }

  Future<void> _scheduleCloudOperation(
    Future<void> Function() operation,
  ) {
    return _operationCoordinator.scheduleCloud(operation);
  }

  _CloudTargetCapture _captureCloudTargetForRequest() {
    if (_isDisposed || !_isOnlineActive) {
      return const _CloudTargetCapture.skipped();
    }
    try {
      final repository = _cloudRepositoryForCommittedSync();
      return _CloudTargetCapture.captured(
        _CloudOperationTarget(
          repository: repository,
          userId: repository.userId,
        ),
      );
    } catch (error, stackTrace) {
      return _CloudTargetCapture.failed(error, stackTrace);
    }
  }

  SettingsOperationFailure<T> _cloudTargetFailure<T>(
    _CloudTargetCapture capture, {
    required SettingsPersistenceFailureKind kind,
    required String operation,
  }) {
    return SettingsOperationFailure(
      SettingsPersistenceFailure(
        kind: kind,
        operation: operation,
        cause: capture.failure ??
            StateError(
              'No authenticated cloud target was captured for this request.',
            ),
        stackTrace: capture.failureStackTrace ?? StackTrace.current,
      ),
    );
  }

  void _ensureCloudTarget(
    _CloudOperationTarget target, {
    required String operation,
  }) {
    if (_isDisposed) {
      throw StateError(
        'SettingsProvider was disposed before $operation completed.',
      );
    }
    if (!_isOnlineActive) {
      throw StateError('Online mode is no longer active during $operation.');
    }
    if (target.repository.userId != target.userId) {
      throw StateError('Authenticated user changed during $operation.');
    }
  }

  SettingsCloudRepository _cloudRepositoryForCommittedSync() {
    return _firestoreService ??= _cloudRepositoryFactory();
  }

  Future<void> _syncAllData(
    SettingsCloudRepository cloud,
    SettingsSnapshotV2 snapshot,
  ) {
    return cloud.syncAllData(
      savedSettings: snapshot.savedSettings,
      runLogs: snapshot.runLogs,
      cars: snapshot.cars,
      ownedParts: snapshot.ownedParts,
      visibilitySettings: snapshot.visibilitySettings,
      isEnglish: snapshot.isEnglish,
    );
  }

  void _notifyListenersIfActive() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}

class _CommittedMutation<T> {
  const _CommittedMutation({
    required this.result,
    this.warningFuture,
  });

  final SettingsOperationResult<T> result;
  final Future<SettingsSyncWarning?>? warningFuture;
}

final class _CloudOperationTarget {
  const _CloudOperationTarget({
    required this.repository,
    required this.userId,
  });

  final SettingsCloudRepository repository;
  final String? userId;
}

final class _CloudTargetCapture {
  const _CloudTargetCapture.skipped()
      : target = null,
        failure = null,
        failureStackTrace = null;

  const _CloudTargetCapture.captured(this.target)
      : failure = null,
        failureStackTrace = null;

  const _CloudTargetCapture.failed(this.failure, this.failureStackTrace)
      : target = null;

  final _CloudOperationTarget? target;
  final Object? failure;
  final StackTrace? failureStackTrace;
}

final class _SettingsOperationCoordinator {
  Future<void>? _localTail;
  Future<void>? _cloudTail;

  Future<T> scheduleLocal<T>(Future<T> Function() operation) {
    final previous = _localTail;
    final result = previous == null
        ? Future<T>.sync(operation)
        : previous.then((_) => operation());
    final tail = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    _localTail = tail;
    unawaited(tail.then((_) {
      if (identical(_localTail, tail)) {
        _localTail = null;
      }
    }));
    return result;
  }

  Future<void> scheduleCloud(Future<void> Function() operation) {
    final previous = _cloudTail;
    final result = previous == null
        ? Future<void>.sync(operation)
        : previous.then((_) => operation());
    final tail = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    _cloudTail = tail;
    unawaited(tail.then((_) {
      if (identical(_cloudTail, tail)) {
        _cloudTail = null;
      }
    }));
    return result;
  }
}
