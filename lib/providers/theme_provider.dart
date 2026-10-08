import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/settings_operation_result.dart';
import '../utils/app_logger.dart';

abstract interface class ThemePreferencesRepository {
  Future<ThemeMode?> loadThemeMode();

  Future<bool> saveThemeMode(ThemeMode value);
}

typedef ThemeSharedPreferencesLoader = Future<SharedPreferences> Function();
typedef ThemeSharedPreferencesWriter = Future<bool> Function(
  SharedPreferences preferences,
  String key,
  String value,
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
            ((preferences, key, value) => preferences.setString(key, value)),
        _preferencesReloader =
            preferencesReloader ?? ((preferences) => preferences.reload());

  static const String darkModeKey = 'isDarkMode';
  static const String themeModeKey = 'themeMode';

  final ThemeSharedPreferencesLoader _preferencesLoader;
  final ThemeSharedPreferencesWriter _preferencesWriter;
  final ThemeSharedPreferencesReloader _preferencesReloader;

  @override
  Future<ThemeMode?> loadThemeMode() async {
    final preferences = await _preferencesLoader();
    final storedMode = preferences.getString(themeModeKey);
    for (final mode in ThemeMode.values) {
      if (mode.name == storedMode) return mode;
    }
    // 既存のオン／オフ設定を維持し、未設定の場合だけ端末に同期する。
    return switch (preferences.getBool(darkModeKey)) {
      true => ThemeMode.dark,
      false => ThemeMode.light,
      null => null,
    };
  }

  @override
  Future<bool> saveThemeMode(ThemeMode value) async {
    final preferences = await _preferencesLoader();
    late final bool didSave;
    try {
      didSave = await _preferencesWriter(
        preferences,
        themeModeKey,
        value.name,
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
  ThemeMode _themeMode = ThemeMode.system;
  bool _isInitialized = false;
  bool _isDisposed = false;
  Future<void>? _initialization;
  Future<void> _operationQueue = Future<void>.value();

  ThemeMode get themeMode => _themeMode;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    final storedValue = await _preferencesRepository.loadThemeMode();
    if (_isDisposed) {
      throw StateError('ThemeProvider was disposed during initialization.');
    }

    final didChange = storedValue != null && storedValue != _themeMode;
    if (storedValue != null) {
      _themeMode = storedValue;
    }
    _isInitialized = true;
    if (didChange) {
      notifyListeners();
    }
  }

  Future<SettingsOperationResult<ThemeMode>> setThemeMode(ThemeMode value) {
    return _enqueueThemeChange(
      operation: 'setThemeMode',
      requestedValue: value,
    );
  }

  Future<SettingsOperationResult<ThemeMode>> _enqueueThemeChange({
    required String operation,
    required ThemeMode requestedValue,
  }) {
    final result = _operationQueue.then(
      (_) => _persistThemeChange(
        operation: operation,
        requestedValue: requestedValue,
      ),
      onError: (Object error, StackTrace stackTrace) =>
          SettingsOperationFailure<ThemeMode>(
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

  Future<SettingsOperationResult<ThemeMode>> _persistThemeChange({
    required String operation,
    required ThemeMode requestedValue,
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

    final nextValue = requestedValue;
    if (nextValue == _themeMode) {
      return SettingsOperationSuccess(value: _themeMode);
    }

    try {
      final didSave = await _preferencesRepository.saveThemeMode(nextValue);
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

    _themeMode = nextValue;
    notifyListeners();
    return SettingsOperationSuccess(value: nextValue);
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
