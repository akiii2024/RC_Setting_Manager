import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:rc_setting_manager/models/car.dart';
import 'package:rc_setting_manager/models/manufacturer.dart';
import 'package:rc_setting_manager/models/settings_operation_result.dart';
import 'package:rc_setting_manager/models/settings_snapshot_v2.dart';
import 'package:rc_setting_manager/models/visibility_settings.dart';
import 'package:rc_setting_manager/pages/car_list_page.dart';
import 'package:rc_setting_manager/pages/car_setting_page.dart';
import 'package:rc_setting_manager/providers/app_mode_provider.dart';
import 'package:rc_setting_manager/providers/settings_provider.dart';
import 'package:rc_setting_manager/repositories/settings_local_repository.dart';
import 'package:rc_setting_manager/repositories/settings_cloud_repository.dart';
import 'package:rc_setting_manager/utils/settings_operation_feedback.dart';

void main() {
  testWidgets(
    '車両追加の端末保存に失敗すると赤い通知を出してダイアログと状態を維持する',
    (tester) async {
      final repository = _ControllableSettingsLocalRepository();
      final provider = SettingsProvider(
        appModeProvider: AppModeProvider(
          preferredOnline: false,
          isFirebaseReady: false,
        ),
        localRepository: repository,
      );
      addTearDown(provider.dispose);

      const modelName = 'Unsaved Model';
      final manufacturer = Manufacturer(
        id: 'failure-test-manufacturer',
        name: 'Failure Test',
        logoPath: '',
      );

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            home: CarListPage(manufacturer: manufacturer),
          ),
        ),
      );
      await _pumpUntilInitialized(tester, provider);

      final carsBefore = List.of(provider.cars);
      repository.failWrites = true;

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('Add New Model'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, modelName);
      await tester.tap(find.widgetWithText(TextButton, 'Add'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      const failureMessage =
          'Could not save on this device. The change was not applied.';
      expect(find.text(failureMessage), findsOneWidget);
      expect(find.text('Add New Model'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(provider.cars, orderedEquals(carsBefore));
      expect(
        provider.cars.where((car) => car.name == modelName),
        isEmpty,
      );
      expect(find.textContaining('added'), findsNothing);

      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      final scaffoldContext = tester.element(find.byType(Scaffold));
      expect(
        snackBar.backgroundColor,
        Theme.of(scaffoldContext).colorScheme.error,
      );
    },
  );

  testWidgets('車両追加を保存中に連打しても1件だけ確定する', (tester) async {
    final repository = _ControllableSettingsLocalRepository();
    final provider = SettingsProvider(
      appModeProvider: AppModeProvider(
        preferredOnline: false,
        isFirebaseReady: false,
      ),
      localRepository: repository,
    );
    addTearDown(provider.dispose);

    final manufacturer = Manufacturer(
      id: 'double-tap-manufacturer',
      name: 'Double Tap Test',
      logoPath: '',
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(home: CarListPage(manufacturer: manufacturer)),
      ),
    );
    await _pumpUntilInitialized(tester, provider);

    final baselineSaves = repository.saveCount;
    final gate = Completer<void>();
    repository.writeGate = gate;
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Only Once');

    final addButton = find.widgetWithText(TextButton, 'Add');
    await tester.tap(addButton);
    await tester.tap(addButton);
    await tester.pump();

    expect(repository.saveCount, baselineSaves + 1);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
          .onPressed,
      isNull,
    );
    final dialogButtons = tester.widgetList<TextButton>(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextButton),
      ),
    );
    expect(dialogButtons, hasLength(2));
    expect(dialogButtons.every((button) => button.onPressed == null), isTrue);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Add New Model'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(repository.saveCount, baselineSaves + 1);

    gate.complete();
    await tester.pumpAndSettle();
    expect(
      provider.cars.where((car) => car.name == 'Only Once'),
      hasLength(1),
    );
  });

  testWidgets('クラウド失敗時は端末保存を維持して橙色の同期警告を出す', (tester) async {
    final repository = _ControllableSettingsLocalRepository();
    final provider = SettingsProvider(
      appModeProvider: AppModeProvider(
        preferredOnline: true,
        isFirebaseReady: true,
      ),
      localRepository: repository,
      cloudRepositoryFactory: _FailingCarsCloudRepository.new,
    );
    addTearDown(provider.dispose);

    final manufacturer = Manufacturer(
      id: 'warning-manufacturer',
      name: 'Warning Test',
      logoPath: '',
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(home: CarListPage(manufacturer: manufacturer)),
      ),
    );
    await _pumpUntilInitialized(tester, provider);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Local Car');
    await tester.tap(find.widgetWithText(TextButton, 'Add'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text(
        'Saved on this device, but cloud sync failed. Try syncing again later.',
      ),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsNothing);
    expect(provider.cars.where((car) => car.name == 'Local Car'), hasLength(1));
    final snackBars = tester.widgetList<SnackBar>(find.byType(SnackBar));
    expect(snackBars, isNotEmpty);
    expect(
      snackBars.every((snackBar) => snackBar.backgroundColor == Colors.orange),
      isTrue,
    );
  });

  testWidgets('同期警告は直後の成功通知と画面遷移後も最終表示される', (tester) async {
    const warningMessage =
        'Saved on this device, but cloud sync failed. Try syncing again later.';

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (rootContext) => Scaffold(
            body: FilledButton(
              onPressed: () {
                Navigator.of(rootContext).push(
                  MaterialPageRoute<void>(
                    builder: (routeContext) => Scaffold(
                      body: FilledButton(
                        onPressed: () {
                          final result = SettingsOperationResult<bool>.success(
                            value: true,
                            warning: SettingsSyncWarning(
                              operation: 'save',
                              cause: StateError('simulated cloud failure'),
                              stackTrace: StackTrace.empty,
                            ),
                          );
                          if (handleSettingsOperationResult(
                            routeContext,
                            result,
                            isEnglish: true,
                          )) {
                            ScaffoldMessenger.of(routeContext).showSnackBar(
                              const SnackBar(
                                content: Text('Saved successfully'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            Navigator.of(routeContext).pop();
                          }
                        },
                        child: const Text('Save and return'),
                      ),
                    ),
                  ),
                );
              },
              child: const Text('Open editor'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save and return'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Open editor'), findsOneWidget);
    expect(find.text(warningMessage), findsOneWidget);
    expect(find.text('Saved successfully'), findsNothing);
    final snackBars = tester.widgetList<SnackBar>(find.byType(SnackBar));
    expect(snackBars, isNotEmpty);
    expect(
      snackBars.every((snackBar) => snackBar.backgroundColor == Colors.orange),
      isTrue,
    );
  });

  testWidgets('設定とガレージの原子的保存に失敗するとどちらも残らない', (tester) async {
    final manufacturer = Manufacturer(
      id: 'atomic-manufacturer',
      name: 'Atomic Test',
      logoPath: '',
    );
    final car = Car(
      id: 'atomic/car',
      name: 'Atomic Car',
      imageUrl: '',
      manufacturer: manufacturer,
      category: 'touring',
    );
    final repository = _ControllableSettingsLocalRepository(
      snapshot: SettingsSnapshotV2(
        cars: [car],
        savedSettings: const [],
        runLogs: const [],
        ownedParts: const [],
        visibilitySettings: const {},
        isEnglish: true,
        usePaperStyleEditor: false,
      ),
    );
    final provider = SettingsProvider(
      appModeProvider: AppModeProvider(
        preferredOnline: false,
        isFirebaseReady: false,
      ),
      localRepository: repository,
    );
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(home: CarSettingPage(originalCar: car)),
      ),
    );
    await _pumpUntilInitialized(tester, provider);
    await tester.pump(const Duration(milliseconds: 600));
    repository.failWrites = true;

    await tester.ensureVisible(find.text('Save Setting'));
    await tester.tap(find.text('Save Setting'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Add to My Garage?'), findsOneWidget);
    await tester.tap(find.text('Add to My Garage'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(provider.savedSettings, isEmpty);
    expect(provider.getCarById(car.id)?.isInGarage, isFalse);
    expect(find.byType(CarSettingPage), findsOneWidget);
    expect(
      find.text('Could not save on this device. The change was not applied.'),
      findsOneWidget,
    );
  });
}

Future<void> _pumpUntilInitialized(
  WidgetTester tester,
  SettingsProvider provider,
) async {
  for (var i = 0; i < 100 && !provider.isInitialized; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
  expect(provider.isInitialized, isTrue);
}

class _ControllableSettingsLocalRepository implements SettingsLocalRepository {
  _ControllableSettingsLocalRepository({SettingsSnapshotV2? snapshot})
      : _snapshot = snapshot ??
            SettingsSnapshotV2(
              cars: const [],
              savedSettings: const [],
              runLogs: const [],
              ownedParts: const [],
              visibilitySettings: const {},
              isEnglish: true,
              usePaperStyleEditor: false,
            );

  SettingsSnapshotV2 _snapshot;

  bool failWrites = false;
  int saveCount = 0;
  Completer<void>? writeGate;

  @override
  Future<SettingsSnapshotV2?> loadSnapshot() async => _snapshot;

  @override
  Future<SettingsSnapshotV2> loadLegacySnapshot() {
    throw StateError('A v2 snapshot is available; legacy data must not load.');
  }

  @override
  Future<void> saveSnapshot(SettingsSnapshotV2 snapshot) async {
    saveCount += 1;
    final gate = writeGate;
    if (gate != null) {
      await gate.future;
      writeGate = null;
    }
    if (failWrites) {
      throw StateError('simulated snapshot write failure');
    }
    _snapshot = snapshot;
  }
}

class _FailingCarsCloudRepository implements SettingsCloudRepository {
  @override
  String? get userId => 'warning-test-user';

  @override
  Future<void> saveCars(List<Car> cars) {
    throw StateError('simulated cloud write failure');
  }

  @override
  Future<void> saveCarsAndVisibilityAtomically({
    required List<Car> cars,
    required Map<String, VisibilitySettings> visibilitySettings,
  }) {
    throw StateError('simulated cloud write failure');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
