import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rc_setting_manager/models/settings_operation_result.dart';
import 'package:rc_setting_manager/providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ThemeProvider initialization', () {
    test('create waits for the stored preference before publishing provider',
        () async {
      final loadResult = Completer<ThemeMode?>();
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
      loadResult.complete(ThemeMode.dark);
      final provider = await providerFuture;
      addTearDown(provider.dispose);
      expect(provider.isInitialized, isTrue);
      expect(provider.themeMode, ThemeMode.dark);
    });

    test('a read failure remains a startup failure', () async {
      final repository = _FakeThemePreferencesRepository(
        onLoad: () => Future<ThemeMode?>.error(StateError('read failed')),
      );
      await expectLater(
        ThemeProvider.create(preferencesRepository: repository),
        throwsA(isA<StateError>()),
      );
    });

    test('completion after dispose does not publish the loaded value',
        () async {
      final loadResult = Completer<ThemeMode?>();
      final repository = _FakeThemePreferencesRepository(
        onLoad: () => loadResult.future,
      );
      final provider = ThemeProvider(preferencesRepository: repository);
      var notificationCount = 0;
      provider.addListener(() => notificationCount++);
      final initialization = provider.initialize();
      provider.dispose();
      loadResult.complete(ThemeMode.dark);
      await expectLater(initialization, throwsStateError);
      expect(notificationCount, 0);
    });

    test('missing preference defaults to system mode', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = await ThemeProvider.create();
      addTearDown(provider.dispose);
      expect(provider.themeMode, ThemeMode.system);
    });

    test('SharedPreferences-backed create loads each persisted theme mode',
        () async {
      for (final mode in ThemeMode.values) {
        SharedPreferences.setMockInitialValues({
          SharedPreferencesThemePreferencesRepository.themeModeKey: mode.name,
        });
        final provider = await ThemeProvider.create();
        expect(provider.themeMode, mode);
        provider.dispose();
      }
    });

    test('legacy dark mode preference is migrated when new key is absent',
        () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesThemePreferencesRepository.darkModeKey: true,
      });
      final provider = await ThemeProvider.create();
      addTearDown(provider.dispose);
      expect(provider.themeMode, ThemeMode.dark);
    });

    test('legacy light mode preference remains light', () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesThemePreferencesRepository.darkModeKey: false,
      });
      final provider = await ThemeProvider.create();
      addTearDown(provider.dispose);
      expect(provider.themeMode, ThemeMode.light);
    });
    test('new theme mode preference takes precedence over legacy bool',
        () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesThemePreferencesRepository.themeModeKey:
            ThemeMode.system.name,
        SharedPreferencesThemePreferencesRepository.darkModeKey: true,
      });
      final provider = await ThemeProvider.create();
      addTearDown(provider.dispose);
      expect(provider.themeMode, ThemeMode.system);
    });
  });

  group('ThemeProvider persistence', () {
    test('each selected mode is restored after creating a new provider',
        () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesThemePreferencesRepository.darkModeKey: true,
      });
      var provider = await ThemeProvider.create();
      for (final mode in [ThemeMode.light, ThemeMode.dark, ThemeMode.system]) {
        final result = await provider.setThemeMode(mode);
        expect(result.isSuccess, isTrue);
        provider.dispose();
        provider = await ThemeProvider.create();
        expect(provider.themeMode, mode);
      }
      provider.dispose();
    });
    test('successful change persists the selected mode', () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesThemePreferencesRepository.themeModeKey:
            ThemeMode.system.name,
      });
      final provider = await ThemeProvider.create();
      addTearDown(provider.dispose);
      final result = await provider.setThemeMode(ThemeMode.dark);
      final preferences = await SharedPreferences.getInstance();
      expect(result, isA<SettingsOperationSuccess<ThemeMode>>());
      expect(provider.themeMode, ThemeMode.dark);
      expect(
        preferences.getString(
          SharedPreferencesThemePreferencesRepository.themeModeKey,
        ),
        ThemeMode.dark.name,
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
      final result = await provider.setThemeMode(ThemeMode.dark);
      expect(result, isA<SettingsOperationFailure<ThemeMode>>());
      expect(provider.themeMode, ThemeMode.system);
      expect(notificationCount, 0);
    });

    test('false result restores a cache polluted before platform failure',
        () async {
      const key = SharedPreferencesThemePreferencesRepository.themeModeKey;
      SharedPreferences.setMockInitialValues({key: ThemeMode.system.name});
      final originalPreferences = await SharedPreferences.getInstance();
      final repository = SharedPreferencesThemePreferencesRepository(
        preferencesWriter: (preferences, key, value) async {
          await preferences.setString(key, value);
          SharedPreferences.setMockInitialValues({key: ThemeMode.system.name});
          return false;
        },
      );
      final provider = await ThemeProvider.create(
        preferencesRepository: repository,
      );
      addTearDown(provider.dispose);
      var notificationCount = 0;
      provider.addListener(() => notificationCount++);
      final result = await provider.setThemeMode(ThemeMode.dark);
      expect(result, isA<SettingsOperationFailure<ThemeMode>>());
      expect(provider.themeMode, ThemeMode.system);
      expect(notificationCount, 0);
      expect(originalPreferences.getString(key), ThemeMode.system.name);
      expect(await repository.loadThemeMode(), ThemeMode.system);
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
      final result = await provider.setThemeMode(ThemeMode.dark);
      expect(result, isA<SettingsOperationFailure<ThemeMode>>());
      expect(provider.themeMode, ThemeMode.system);
      expect(notificationCount, 0);
    });

    test('save exception restores a polluted cache before reporting failure',
        () async {
      const key = SharedPreferencesThemePreferencesRepository.themeModeKey;
      SharedPreferences.setMockInitialValues({key: ThemeMode.system.name});
      final originalPreferences = await SharedPreferences.getInstance();
      final repository = SharedPreferencesThemePreferencesRepository(
        preferencesWriter: (preferences, key, value) async {
          await preferences.setString(key, value);
          SharedPreferences.setMockInitialValues({key: ThemeMode.system.name});
          throw StateError('simulated platform exception');
        },
      );
      final provider = await ThemeProvider.create(
        preferencesRepository: repository,
      );
      addTearDown(provider.dispose);
      var notificationCount = 0;
      provider.addListener(() => notificationCount++);
      final result = await provider.setThemeMode(ThemeMode.dark);
      expect(result, isA<SettingsOperationFailure<ThemeMode>>());
      expect(provider.themeMode, ThemeMode.system);
      expect(notificationCount, 0);
      expect(originalPreferences.getString(key), ThemeMode.system.name);
      expect(await repository.loadThemeMode(), ThemeMode.system);
    });

    test('cache reload failure is preserved as an explicit operation failure',
        () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesThemePreferencesRepository.themeModeKey:
            ThemeMode.system.name,
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
      final result = await provider.setThemeMode(ThemeMode.dark);
      final failure = result as SettingsOperationFailure<ThemeMode>;
      expect(failure.failure.cause, isA<StateError>());
      expect('${failure.failure.cause}', contains('restore'));
      expect(provider.themeMode, ThemeMode.system);
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
      final operation = provider.setThemeMode(ThemeMode.dark);
      await Future<void>.delayed(Duration.zero);
      expect(provider.themeMode, ThemeMode.system);
      expect(notificationCount, 0);
      saveResult.complete(true);
      final result = await operation;
      expect(result, isA<SettingsOperationSuccess<ThemeMode>>());
      expect(provider.themeMode, ThemeMode.dark);
      expect(notificationCount, 1);
    });

    test('theme changes are serialized in request order', () async {
      final firstSave = Completer<bool>();
      final secondSave = Completer<bool>();
      final saves = <ThemeMode>[];
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
      final firstOperation = provider.setThemeMode(ThemeMode.dark);
      final secondOperation = provider.setThemeMode(ThemeMode.light);
      await Future<void>.delayed(Duration.zero);
      expect(saves, [ThemeMode.dark]);
      firstSave.complete(true);
      await firstOperation;
      await Future<void>.delayed(Duration.zero);
      expect(saves, [ThemeMode.dark, ThemeMode.light]);
      secondSave.complete(true);
      await secondOperation;
      expect(provider.themeMode, ThemeMode.light);
    });
  });
}

class _FakeThemePreferencesRepository implements ThemePreferencesRepository {
  _FakeThemePreferencesRepository({
    this.onLoad,
    this.onSave,
  });

  final Future<ThemeMode?> Function()? onLoad;
  final Future<bool> Function(ThemeMode value)? onSave;

  @override
  Future<ThemeMode?> loadThemeMode() =>
      onLoad?.call() ?? Future.value(ThemeMode.system);

  @override
  Future<bool> saveThemeMode(ThemeMode value) =>
      onSave?.call(value) ?? Future.value(true);
}
