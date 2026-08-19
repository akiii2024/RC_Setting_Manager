import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rc_setting_manager/models/settings_operation_result.dart';
import 'package:rc_setting_manager/providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ThemeProvider initialization', () {
    test('create waits for the stored preference before publishing provider',
        () async {
      final loadResult = Completer<bool?>();
      final repository = _FakeThemePreferencesRepository(
        onLoad: () => loadResult.future,
      );
      var completed = false;

      final providerFuture = ThemeProvider.create(
        preferencesRepository: repository,
      ).then((provider) {
        completed = true;
        return provider;
      });
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);

      loadResult.complete(true);
      final provider = await providerFuture;
      addTearDown(provider.dispose);

      expect(provider.isInitialized, isTrue);
      expect(provider.isDarkMode, isTrue);
    });

    test('a read failure remains a startup failure', () async {
      final repository = _FakeThemePreferencesRepository(
        onLoad: () => Future<bool?>.error(StateError('read failed')),
      );

      await expectLater(
        ThemeProvider.create(preferencesRepository: repository),
        throwsA(isA<StateError>()),
      );
    });

    test('completion after dispose does not publish the loaded value',
        () async {
      final loadResult = Completer<bool?>();
      final repository = _FakeThemePreferencesRepository(
        onLoad: () => loadResult.future,
      );
      final provider = ThemeProvider(preferencesRepository: repository);
      var notificationCount = 0;
      provider.addListener(() => notificationCount++);

      final initialization = provider.initialize();
      provider.dispose();
      loadResult.complete(true);

      await expectLater(initialization, throwsStateError);
      expect(notificationCount, 0);
    });

    test('SharedPreferences-backed create loads the persisted theme', () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesThemePreferencesRepository.darkModeKey: true,
      });

      final provider = await ThemeProvider.create();
      addTearDown(provider.dispose);

      expect(provider.isDarkMode, isTrue);
    });
  });

  group('ThemeProvider persistence', () {
    test('successful change persists the SharedPreferences value', () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesThemePreferencesRepository.darkModeKey: false,
      });
      final provider = await ThemeProvider.create();
      addTearDown(provider.dispose);

      final result = await provider.setDarkMode(true);
      final preferences = await SharedPreferences.getInstance();

      expect(result, isA<SettingsOperationSuccess<bool>>());
      expect(provider.isDarkMode, isTrue);
      expect(
        preferences.getBool(
          SharedPreferencesThemePreferencesRepository.darkModeKey,
        ),
        isTrue,
      );
    });

    test('false save result keeps live state and notifications unchanged',
        () async {
      final repository = _FakeThemePreferencesRepository(
        onSave: (_) async => false,
      );
      final provider = await ThemeProvider.create(
        preferencesRepository: repository,
      );
      addTearDown(provider.dispose);
      var notificationCount = 0;
      provider.addListener(() => notificationCount++);

      final result = await provider.setDarkMode(true);

      expect(result, isA<SettingsOperationFailure<bool>>());
      expect(provider.isDarkMode, isFalse);
      expect(notificationCount, 0);
    });

    test('false result restores a cache polluted before the platform failure',
        () async {
      const key = SharedPreferencesThemePreferencesRepository.darkModeKey;
      SharedPreferences.setMockInitialValues({key: false});
      final originalPreferences = await SharedPreferences.getInstance();
      final repository = SharedPreferencesThemePreferencesRepository(
        preferencesWriter: (preferences, key, value) async {
          // Legacy SharedPreferences mutates its cache before the platform
          // result is known. Resetting the mock platform to the old value
          // simulates a platform write that returned false.
          await preferences.setBool(key, value);
          SharedPreferences.setMockInitialValues({key: false});
          return false;
        },
      );
      final provider = await ThemeProvider.create(
        preferencesRepository: repository,
      );
      addTearDown(provider.dispose);
      var notificationCount = 0;
      provider.addListener(() => notificationCount++);

      final result = await provider.setDarkMode(true);

      expect(result, isA<SettingsOperationFailure<bool>>());
      expect(provider.isDarkMode, isFalse);
      expect(notificationCount, 0);
      expect(originalPreferences.getBool(key), isFalse);
      expect(await repository.loadDarkMode(), isFalse);
    });

    test('save exception keeps live state and notifications unchanged',
        () async {
      final repository = _FakeThemePreferencesRepository(
        onSave: (_) => Future<bool>.error(StateError('write failed')),
      );
      final provider = await ThemeProvider.create(
        preferencesRepository: repository,
      );
      addTearDown(provider.dispose);
      var notificationCount = 0;
      provider.addListener(() => notificationCount++);

      final result = await provider.toggleTheme();

      expect(result, isA<SettingsOperationFailure<bool>>());
      expect(provider.isDarkMode, isFalse);
      expect(notificationCount, 0);
    });

    test('save exception restores a polluted cache before reporting failure',
        () async {
      const key = SharedPreferencesThemePreferencesRepository.darkModeKey;
      SharedPreferences.setMockInitialValues({key: false});
      final originalPreferences = await SharedPreferences.getInstance();
      final repository = SharedPreferencesThemePreferencesRepository(
        preferencesWriter: (preferences, key, value) async {
          await preferences.setBool(key, value);
          SharedPreferences.setMockInitialValues({key: false});
          throw StateError('simulated platform exception');
        },
      );
      final provider = await ThemeProvider.create(
        preferencesRepository: repository,
      );
      addTearDown(provider.dispose);
      var notificationCount = 0;
      provider.addListener(() => notificationCount++);

      final result = await provider.setDarkMode(true);

      expect(result, isA<SettingsOperationFailure<bool>>());
      expect(provider.isDarkMode, isFalse);
      expect(notificationCount, 0);
      expect(originalPreferences.getBool(key), isFalse);
      expect(await repository.loadDarkMode(), isFalse);
    });

    test('cache reload failure is preserved as an explicit operation failure',
        () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesThemePreferencesRepository.darkModeKey: false,
      });
      final repository = SharedPreferencesThemePreferencesRepository(
        preferencesWriter: (preferences, key, value) async => false,
        preferencesReloader: (preferences) =>
            Future<void>.error(StateError('reload failed')),
      );
      final provider = await ThemeProvider.create(
        preferencesRepository: repository,
      );
      addTearDown(provider.dispose);
      var notificationCount = 0;
      provider.addListener(() => notificationCount++);

      final result = await provider.setDarkMode(true);

      final failure = result as SettingsOperationFailure<bool>;
      expect(failure.failure.cause, isA<StateError>());
      expect('${failure.failure.cause}', contains('restore'));
      expect(provider.isDarkMode, isFalse);
      expect(notificationCount, 0);
    });

    test('pending save is not visible until persistence succeeds', () async {
      final saveResult = Completer<bool>();
      final repository = _FakeThemePreferencesRepository(
        onSave: (_) => saveResult.future,
      );
      final provider = await ThemeProvider.create(
        preferencesRepository: repository,
      );
      addTearDown(provider.dispose);
      var notificationCount = 0;
      provider.addListener(() => notificationCount++);

      final operation = provider.setDarkMode(true);
      await Future<void>.delayed(Duration.zero);
      expect(provider.isDarkMode, isFalse);
      expect(notificationCount, 0);

      saveResult.complete(true);
      final result = await operation;

      expect(result, isA<SettingsOperationSuccess<bool>>());
      expect(provider.isDarkMode, isTrue);
      expect(notificationCount, 1);
    });

    test('theme changes are serialized in request order', () async {
      final firstSave = Completer<bool>();
      final secondSave = Completer<bool>();
      final saves = <bool>[];
      final repository = _FakeThemePreferencesRepository(
        onSave: (value) {
          saves.add(value);
          return saves.length == 1 ? firstSave.future : secondSave.future;
        },
      );
      final provider = await ThemeProvider.create(
        preferencesRepository: repository,
      );
      addTearDown(provider.dispose);

      final firstOperation = provider.setDarkMode(true);
      final secondOperation = provider.setDarkMode(false);
      await Future<void>.delayed(Duration.zero);
      expect(saves, [true]);

      firstSave.complete(true);
      await firstOperation;
      await Future<void>.delayed(Duration.zero);
      expect(saves, [true, false]);

      secondSave.complete(true);
      await secondOperation;
      expect(provider.isDarkMode, isFalse);
    });
  });
}

class _FakeThemePreferencesRepository implements ThemePreferencesRepository {
  _FakeThemePreferencesRepository({
    this.onLoad,
    this.onSave,
  });

  final Future<bool?> Function()? onLoad;
  final Future<bool> Function(bool value)? onSave;

  @override
  Future<bool?> loadDarkMode() => onLoad?.call() ?? Future.value(false);

  @override
  Future<bool> saveDarkMode(bool value) =>
      onSave?.call(value) ?? Future.value(true);
}
