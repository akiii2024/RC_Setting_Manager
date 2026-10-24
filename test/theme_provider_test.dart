import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rc_setting_manager/models/settings_operation_result.dart';
import 'package:rc_setting_manager/providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ThemeProvider initialization', () {
    test('createは保存値の読み込み完了まで完了しない', () async {
      final loaded = Completer<ThemeMode?>();
      var completed = false;
      final future = ThemeProvider.create(
        preferencesRepository: _FakeThemePreferencesRepository(
          onLoad: () => loaded.future,
        ),
      ).then((provider) {
        completed = true;
        return provider;
      });
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);
      loaded.complete(ThemeMode.dark);
      final provider = await future;
      addTearDown(provider.dispose);
      expect(provider.themeMode, ThemeMode.dark);
    });

    test('未設定は端末同期(system)になる', () async {
      final provider = await ThemeProvider.create(
        preferencesRepository: _FakeThemePreferencesRepository(),
      );
      addTearDown(provider.dispose);
      expect(provider.themeMode, ThemeMode.system);
    });

    test('保存済み3値を読み込む', () async {
      for (final mode in ThemeMode.values) {
        final provider = await ThemeProvider.create(
          preferencesRepository: _FakeThemePreferencesRepository(
            onLoad: () async => mode,
          ),
        );
        expect(provider.themeMode, mode);
        provider.dispose();
      }
    });

    test('読み込み失敗は起動失敗として返す', () async {
      final repository = _FakeThemePreferencesRepository(
        onLoad: () => Future<ThemeMode?>.error(StateError('read failed')),
      );
      await expectLater(
        ThemeProvider.create(preferencesRepository: repository),
        throwsA(isA<StateError>()),
      );
    });

    test('新しい値が旧bool設定より優先される', () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesThemePreferencesRepository.themeModeKey:
            ThemeMode.light.name,
        SharedPreferencesThemePreferencesRepository.darkModeKey: true,
      });
      final provider = await ThemeProvider.create();
      addTearDown(provider.dispose);
      expect(provider.themeMode, ThemeMode.light);
    });

    test('旧bool true/falseをそれぞれdark/lightへ移行する', () async {
      for (final entry in <MapEntry<bool, ThemeMode>>[
        const MapEntry(true, ThemeMode.dark),
        const MapEntry(false, ThemeMode.light),
      ]) {
        SharedPreferences.setMockInitialValues({
          SharedPreferencesThemePreferencesRepository.darkModeKey: entry.key,
        });
        final provider = await ThemeProvider.create();
        expect(provider.themeMode, entry.value);
        provider.dispose();
      }
    });

    test('不正な新値は旧bool設定へfallbackする', () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesThemePreferencesRepository.themeModeKey: 'invalid',
        SharedPreferencesThemePreferencesRepository.darkModeKey: false,
      });
      final provider = await ThemeProvider.create();
      addTearDown(provider.dispose);
      expect(provider.themeMode, ThemeMode.light);
    });

    test('SharedPreferencesはenum nameを保存する', () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesThemePreferencesRepository.themeModeKey:
            ThemeMode.system.name,
      });
      final provider = await ThemeProvider.create();
      addTearDown(provider.dispose);
      expect(provider.themeMode, ThemeMode.system);
    });

    test('初期化中にdisposeすると値を通知しない', () async {
      final loadResult = Completer<ThemeMode?>();
      final provider = ThemeProvider(
        preferencesRepository: _FakeThemePreferencesRepository(
          onLoad: () => loadResult.future,
        ),
      );
      var notifications = 0;
      provider.addListener(() => notifications++);
      final initialization = provider.initialize();
      provider.dispose();
      loadResult.complete(ThemeMode.dark);
      await expectLater(initialization, throwsStateError);
      expect(notifications, 0);
    });
  });

  group('ThemeProvider persistence', () {
    test('実repositoryで3値を保存し再生成して読み込む', () async {
      for (final mode in ThemeMode.values) {
        SharedPreferences.setMockInitialValues({
          SharedPreferencesThemePreferencesRepository.darkModeKey: true,
          SharedPreferencesThemePreferencesRepository.themeModeKey:
              (mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark).name,
        });
        final first = await ThemeProvider.create();
        final result = await first.setThemeMode(mode);
        expect(result, isA<SettingsOperationSuccess<ThemeMode>>());
        final preferences = await SharedPreferences.getInstance();
        expect(
          preferences.getString(
            SharedPreferencesThemePreferencesRepository.themeModeKey,
          ),
          mode.name,
        );
        first.dispose();

        final second = await ThemeProvider.create();
        expect(second.themeMode, mode);
        second.dispose();
      }
    });

    test('3値を保存して状態を更新する', () async {
      final saves = <ThemeMode>[];
      final provider = await ThemeProvider.create(
        preferencesRepository: _FakeThemePreferencesRepository(
          onLoad: () async => ThemeMode.dark,
          onSave: (mode) async {
            saves.add(mode);
            return true;
          },
        ),
      );
      addTearDown(provider.dispose);
      for (final mode in <ThemeMode>[
        ThemeMode.system,
        ThemeMode.light,
        ThemeMode.dark,
      ]) {
        final result = await provider.setThemeMode(mode);
        expect(result, isA<SettingsOperationSuccess<ThemeMode>>());
        expect(provider.themeMode, mode);
      }
      expect(saves, [ThemeMode.system, ThemeMode.light, ThemeMode.dark]);
    });

    test('保存失敗時は状態と通知を維持する', () async {
      final provider = await ThemeProvider.create(
        preferencesRepository: _FakeThemePreferencesRepository(
          onSave: (_) async => false,
        ),
      );
      addTearDown(provider.dispose);
      var notifications = 0;
      provider.addListener(() => notifications++);
      final result = await provider.setThemeMode(ThemeMode.dark);
      expect(result, isA<SettingsOperationFailure<ThemeMode>>());
      expect(provider.themeMode, ThemeMode.system);
      expect(notifications, 0);
    });

    test('保存失敗時に汚染されたキャッシュを復元する', () async {
      const key = SharedPreferencesThemePreferencesRepository.themeModeKey;
      SharedPreferences.setMockInitialValues({key: ThemeMode.light.name});
      final original = await SharedPreferences.getInstance();
      final repository = SharedPreferencesThemePreferencesRepository(
        preferencesWriter: (preferences, key, value) async {
          await preferences.setString(key, value);
          SharedPreferences.setMockInitialValues({key: ThemeMode.light.name});
          return false;
        },
      );
      final provider = await ThemeProvider.create(
        preferencesRepository: repository,
      );
      addTearDown(provider.dispose);
      final result = await provider.setThemeMode(ThemeMode.dark);
      expect(result, isA<SettingsOperationFailure<ThemeMode>>());
      expect(provider.themeMode, ThemeMode.light);
      expect(original.getString(key), ThemeMode.light.name);
      expect(await repository.loadThemeMode(), ThemeMode.light);
    });

    test('保存例外時に汚染されたキャッシュを復元する', () async {
      const key = SharedPreferencesThemePreferencesRepository.themeModeKey;
      SharedPreferences.setMockInitialValues({key: ThemeMode.light.name});
      final original = await SharedPreferences.getInstance();
      final repository = SharedPreferencesThemePreferencesRepository(
        preferencesWriter: (preferences, key, value) async {
          await preferences.setString(key, value);
          SharedPreferences.setMockInitialValues({key: ThemeMode.light.name});
          throw StateError('write failed');
        },
      );
      final provider = await ThemeProvider.create(
        preferencesRepository: repository,
      );
      addTearDown(provider.dispose);
      final result = await provider.setThemeMode(ThemeMode.dark);
      expect(result, isA<SettingsOperationFailure<ThemeMode>>());
      expect(original.getString(key), ThemeMode.light.name);
      expect(await repository.loadThemeMode(), ThemeMode.light);
    });

    test('キャッシュ復元失敗は明示的な操作失敗になる', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = SharedPreferencesThemePreferencesRepository(
        preferencesWriter: (preferences, key, value) async => false,
        preferencesReloader: (_) =>
            Future<void>.error(StateError('reload failed')),
      );
      final provider = await ThemeProvider.create(
        preferencesRepository: repository,
      );
      addTearDown(provider.dispose);
      final result = await provider.setThemeMode(ThemeMode.dark);
      final failure = result as SettingsOperationFailure<ThemeMode>;
      expect('${failure.failure.cause}', contains('restore'));
      expect(provider.themeMode, ThemeMode.system);
    });

    test('保存完了まで状態を更新しない', () async {
      final saveResult = Completer<bool>();
      final provider = await ThemeProvider.create(
        preferencesRepository: _FakeThemePreferencesRepository(
          onSave: (_) => saveResult.future,
        ),
      );
      addTearDown(provider.dispose);
      var notifications = 0;
      provider.addListener(() => notifications++);
      final operation = provider.setThemeMode(ThemeMode.dark);
      await Future<void>.delayed(Duration.zero);
      expect(provider.themeMode, ThemeMode.system);
      expect(notifications, 0);
      saveResult.complete(true);
      await operation;
      expect(provider.themeMode, ThemeMode.dark);
      expect(notifications, 1);
    });

    test('変更は要求順に直列化される', () async {
      final first = Completer<bool>();
      final second = Completer<bool>();
      final saves = <ThemeMode>[];
      final provider = await ThemeProvider.create(
        preferencesRepository: _FakeThemePreferencesRepository(
          onSave: (mode) {
            saves.add(mode);
            return saves.length == 1 ? first.future : second.future;
          },
        ),
      );
      addTearDown(provider.dispose);
      final one = provider.setThemeMode(ThemeMode.dark);
      final two = provider.setThemeMode(ThemeMode.light);
      await Future<void>.delayed(Duration.zero);
      expect(saves, [ThemeMode.dark]);
      first.complete(true);
      await one;
      await Future<void>.delayed(Duration.zero);
      expect(saves, [ThemeMode.dark, ThemeMode.light]);
      second.complete(true);
      await two;
      expect(provider.themeMode, ThemeMode.light);
    });
  });
}

class _FakeThemePreferencesRepository implements ThemePreferencesRepository {
  _FakeThemePreferencesRepository({this.onLoad, this.onSave});

  final Future<ThemeMode?> Function()? onLoad;
  final Future<bool> Function(ThemeMode value)? onSave;

  @override
  Future<ThemeMode?> loadThemeMode() => onLoad?.call() ?? Future.value(null);

  @override
  Future<bool> saveThemeMode(ThemeMode value) =>
      onSave?.call(value) ?? Future.value(true);
}
