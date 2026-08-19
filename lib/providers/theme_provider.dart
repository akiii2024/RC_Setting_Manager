import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/settings_operation_result.dart';
import '../utils/app_logger.dart';

abstract interface class ThemePreferencesRepository {
  Future<bool?> loadDarkMode();

  Future<bool> saveDarkMode(bool value);
}

typedef ThemeSharedPreferencesLoader = Future<SharedPreferences> Function();
typedef ThemeSharedPreferencesWriter = Future<bool> Function(
  SharedPreferences preferences,
  String key,
  bool value,
);
typedef ThemeSharedPreferencesReloader = Future<void> Function(
  SharedPreferences preferences,
);

class SharedPreferencesThemePreferencesRepository
    implements ThemePreferencesRepository {
  SharedPreferencesThemePreferencesRepository({
    ThemeSharedPreferencesLoader? preferencesLoader,
    ThemeSharedPreferencesWriter? preferencesWriter,
    ThemeSharedPreferencesReloader? preferencesReloader,
  })  : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance,
        _preferencesWriter = preferencesWriter ??
            ((preferences, key, value) => preferences.setBool(key, value)),
        _preferencesReloader =
            preferencesReloader ?? ((preferences) => preferences.reload());

  static const String darkModeKey = 'isDarkMode';

  final ThemeSharedPreferencesLoader _preferencesLoader;
  final ThemeSharedPreferencesWriter _preferencesWriter;
  final ThemeSharedPreferencesReloader _preferencesReloader;

  @override
  Future<bool?> loadDarkMode() async {
    final preferences = await _preferencesLoader();
    return preferences.getBool(darkModeKey);
  }

  @override
  Future<bool> saveDarkMode(bool value) async {
    final preferences = await _preferencesLoader();
    late final bool didSave;
    try {
      didSave = await _preferencesWriter(
        preferences,
        darkModeKey,
        value,
      );
    } catch (error, stackTrace) {
      await _restoreCache(preferences, saveFailure: error);
      Error.throwWithStackTrace(error, stackTrace);
    }
    if (!didSave) {
      await _restoreCache(
        preferences,
        saveFailure: StateError('Theme preference writer returned false.'),
      );
    }
    return didSave;
  }

  Future<void> _restoreCache(
    SharedPreferences preferences, {
    required Object saveFailure,
  }) async {
    try {
      await _preferencesReloader(preferences);
    } catch (reloadError, reloadStackTrace) {
      Error.throwWithStackTrace(
        StateError(
          'Failed to restore the SharedPreferences cache after a theme '
          'save failure ($saveFailure): $reloadError',
        ),
        reloadStackTrace,
      );
    }
  }
}

class ThemeProvider extends ChangeNotifier {
  ThemeProvider({ThemePreferencesRepository? preferencesRepository})
      : _preferencesRepository = preferencesRepository ??
            SharedPreferencesThemePreferencesRepository();

  static Future<ThemeProvider> create({
    ThemePreferencesRepository? preferencesRepository,
  }) async {
    final provider = ThemeProvider(
      preferencesRepository: preferencesRepository,
    );
    try {
      await provider.initialize();
      return provider;
    } catch (error, stackTrace) {
      debugLog('ThemeProvider initialization failed: $error');
      debugLog('Stack trace: $stackTrace');
      provider.dispose();
      rethrow;
    }
  }

  final ThemePreferencesRepository _preferencesRepository;
  bool _isDarkMode = false;
  bool _isInitialized = false;
  bool _isDisposed = false;
  Future<void>? _initialization;
  Future<void> _operationQueue = Future<void>.value();

  bool get isDarkMode => _isDarkMode;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    final storedValue = await _preferencesRepository.loadDarkMode();
    if (_isDisposed) {
      throw StateError('ThemeProvider was disposed during initialization.');
    }

    final didChange = storedValue != null && storedValue != _isDarkMode;
    if (storedValue != null) {
      _isDarkMode = storedValue;
    }
    _isInitialized = true;
    if (didChange) {
      notifyListeners();
    }
  }

  Future<SettingsOperationResult<bool>> toggleTheme() {
    return _enqueueThemeChange(
      operation: 'toggleTheme',
      requestedValue: null,
    );
  }

  Future<SettingsOperationResult<bool>> setDarkMode(bool value) {
    return _enqueueThemeChange(
      operation: 'setDarkMode',
      requestedValue: value,
    );
  }

  Future<SettingsOperationResult<bool>> _enqueueThemeChange({
    required String operation,
    required bool? requestedValue,
  }) {
    final result = _operationQueue.then(
      (_) => _persistThemeChange(
        operation: operation,
        requestedValue: requestedValue,
      ),
      onError: (Object error, StackTrace stackTrace) =>
          SettingsOperationFailure<bool>(
        SettingsPersistenceFailure(
          kind: SettingsPersistenceFailureKind.write,
          operation: operation,
          cause: error,
          stackTrace: stackTrace,
        ),
      ),
    );
    _operationQueue = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return result;
  }

  Future<SettingsOperationResult<bool>> _persistThemeChange({
    required String operation,
    required bool? requestedValue,
  }) async {
    if (_isDisposed) {
      return SettingsOperationFailure(
        SettingsPersistenceFailure(
          kind: SettingsPersistenceFailureKind.write,
          operation: operation,
          cause: StateError('ThemeProvider has already been disposed.'),
          stackTrace: StackTrace.current,
        ),
      );
    }

    final nextValue = requestedValue ?? !_isDarkMode;
    if (nextValue == _isDarkMode) {
      return SettingsOperationSuccess(value: _isDarkMode);
    }

    try {
      final didSave = await _preferencesRepository.saveDarkMode(nextValue);
      if (!didSave) {
        throw StateError('テーマ設定の保存に失敗しました。');
      }
    } catch (error, stackTrace) {
      debugLog('Theme persistence failed for $operation: $error');
      debugLog('Stack trace: $stackTrace');
      return SettingsOperationFailure(
        SettingsPersistenceFailure(
          kind: SettingsPersistenceFailureKind.write,
          operation: operation,
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }

    if (_isDisposed) {
      return SettingsOperationFailure(
        SettingsPersistenceFailure(
          kind: SettingsPersistenceFailureKind.write,
          operation: operation,
          cause: StateError('ThemeProvider was disposed while saving.'),
          stackTrace: StackTrace.current,
        ),
      );
    }

    _isDarkMode = nextValue;
    notifyListeners();
    return SettingsOperationSuccess(value: nextValue);
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
