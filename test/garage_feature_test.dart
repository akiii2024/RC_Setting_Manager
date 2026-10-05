import 'dart:convert';

import 'package:rc_setting_manager/domain/parts/owned_part_store.dart';
import 'package:rc_setting_manager/domain/parts/owned_part_queries.dart';
import 'package:rc_setting_manager/models/owned_part.dart';
import 'package:rc_setting_manager/repositories/settings_local_repository.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rc_setting_manager/models/car.dart';
import 'package:rc_setting_manager/models/manufacturer.dart';
import 'package:rc_setting_manager/models/saved_setting.dart';
import 'package:rc_setting_manager/pages/car_selection_page.dart';
import 'package:rc_setting_manager/pages/car_setting_page.dart';
import 'package:rc_setting_manager/pages/history_page.dart';
import 'package:rc_setting_manager/pages/my_garage_page.dart';
import 'package:rc_setting_manager/providers/app_mode_provider.dart';
import 'package:rc_setting_manager/providers/settings_provider.dart';

Future<void> _pumpUntilInitialized(
  WidgetTester tester,
  SettingsProvider provider,
) async {
  for (var i = 0; i < 50; i++) {
    if (provider.isInitialized) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 10));
  }

  fail('SettingsProvider did not initialize in time.');
}

Car _buildCar({
  String id = 'tamiya/trf421',
  String name = 'TRF421',
  bool isInGarage = false,
  bool suppressGaragePrompt = false,
}) {
  final manufacturer = Manufacturer(
    id: 'tamiya',
    name: 'Tamiya',
    logoPath: '',
  );

  return Car(
    id: id,
    name: name,
    imageUrl: '',
    manufacturer: manufacturer,
    category: 'touring',
    isInGarage: isInGarage,
    suppressGaragePrompt: suppressGaragePrompt,
  );
}

SettingsProvider _createProvider(
  List<Car> cars, {
  List<SavedSetting> savedSettings = const [],
  List<OwnedPart> ownedParts = const [],
}) {
  SharedPreferences.setMockInitialValues({
    'owned_parts': jsonEncode(ownedParts.map((part) => part.toJson()).toList()),
    'language_settings': true,
    'cars_settings': jsonEncode(cars.map((car) => car.toJson()).toList()),
    'saved_settings':
        jsonEncode(savedSettings.map((setting) => setting.toJson()).toList()),
  });

  return SettingsProvider(
    appModeProvider: AppModeProvider(
      preferredOnline: false,
      isFirebaseReady: false,
    ),
  );
}

OwnedPart _part(String id, String category, String name, int day) => OwnedPart(
    id: id, category: category, name: name, createdAt: DateTime(2026, 1, day));

void main() {
  test('all categories round trip strictly; unknown and malformed data fail',
      () {
    for (final category in ownedPartCategories) {
      final part = _part(category, category, 'Part', 1);
      expect(OwnedPart.fromJsonStrict(part.toJson()).category, category);
    }
    final json = _part('id', 'motor', 'Part', 1).toJson();
    for (final invalid in [
      {...json, 'category': 'unknown'},
      {...json, 'name': ' '},
      {...json, 'id': ''},
      {...json, 'createdAt': 'invalid'},
    ]) {
      expect(() => OwnedPart.fromJsonStrict(invalid), throwsFormatException);
    }
  });

  test('store rename normalizes, rejects duplicates and preserves identity',
      () {
    var counter = 0;
    final store = OwnedPartStore(idGenerator: () => '${counter++}');
    final first = store.add('spring', ' Alpha ').part!;
    final second = store.add('spring', 'Beta').part!;
    store.add('wheel', 'Beta');
    expect(store.rename(first.id, ' beta '), isFalse);
    expect(store.rename(first.id, '  '), isFalse);
    expect(store.rename('missing', 'Name'), isFalse);
    expect(store.rename(first.id, ' Gamma '), isTrue);
    final renamed = store.parts.first;
    expect(renamed.name, 'Gamma');
    expect(renamed.category, first.category);
    expect(renamed.id, first.id);
    expect(renamed.createdAt, first.createdAt);
    expect(store.rename(first.id, 'gamma'), isTrue);
    expect(store.remove(second.id), isTrue);
    expect(store.remove(second.id), isFalse);
    expect(store.add('unknown', 'Name').changed, isFalse);
  });

  test('search and sorting cover all categories without changing source', () {
    final parts = [
      _part('1', 'wheel', 'alpha', 1),
      _part('2', 'motor', 'Beta', 3),
      _part('3', 'spring', 'Alpine', 2),
    ];
    expect(OwnedPartQueries.search(parts, query: ' AL ').map((p) => p.id),
        ['1', '3']);
    expect(
        OwnedPartQueries.search(parts, sort: OwnedPartSort.category)
            .map((p) => p.id),
        ['2', '3', '1']);
    expect(
        OwnedPartQueries.search(parts, sort: OwnedPartSort.createdAt)
            .map((p) => p.id),
        ['2', '3', '1']);
    expect(OwnedPartQueries.search(parts, query: 'missing'), isEmpty);
    expect(parts.map((p) => p.id), ['1', '2', '3']);
  });

  test('references match normalized category names and front/rear keys once',
      () {
    final saved = SavedSetting(
        id: 's',
        name: 'Setup',
        createdAt: DateTime(2026),
        car: _buildCar(),
        settings: const {
          'frontTire': ' ALPHA ',
          'rearTire': 'alpha',
          'frontDamperSpring': 'Spring',
          'esc': 'ESC',
          'wheel': 'Wheel',
        });
    for (final part in [
      _part('t', 'tire', 'Alpha', 1),
      _part('s', 'spring', 'Spring', 1),
      _part('e', 'electronics', 'ESC', 1),
      _part('w', 'wheel', 'Wheel', 1),
    ]) {
      expect(OwnedPartQueries.references(part, [saved]), [saved]);
    }
    expect(
        OwnedPartQueries.references(_part('m', 'motor', 'Alpha', 1), [saved]),
        isEmpty);
  });

  testWidgets(
      'garage searches, sorts, warns on edit/delete and persists changes',
      (tester) async {
    final car = _buildCar();
    final provider = _createProvider([
      car
    ], ownedParts: [
      _part('a', 'motor', 'Alpha', 1),
      _part('b', 'wheel', 'Beta', 2),
    ], savedSettings: [
      SavedSetting(
          id: 's',
          name: 'Setup',
          createdAt: DateTime(2026),
          car: car,
          settings: const {'motor': 'Alpha'})
    ]);
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: provider, child: const MaterialApp(home: MyGaragePage())));
    await _pumpUntilInitialized(tester, provider);
    await tester.pumpAndSettle();
    final search = find.byKey(const Key('owned-parts-search'));
    await tester.ensureVisible(search);
    await tester.enterText(search, 'alp');
    await tester.pumpAndSettle();
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsNothing);
    await tester.enterText(search, '');
    await tester.tap(find.byKey(const Key('owned-parts-sort')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Newest first').last);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Beta')).dy,
        lessThan(tester.getTopLeft(find.text('Alpha')).dy));
    final alphaRow =
        find.ancestor(of: find.text('Alpha'), matching: find.byType(ListTile));
    final edit =
        find.descendant(of: alphaRow, matching: find.byTooltip('Edit'));
    await tester.ensureVisible(edit);
    await tester.tap(edit);
    await tester.pumpAndSettle();
    expect(find.textContaining('Used in 1 saved settings.'), findsOneWidget);
    await tester.enterText(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.byType(TextFormField)),
        ' Renamed ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(provider.ownedParts.first.name, 'Renamed');
    expect(provider.savedSettings.single.settings['motor'], 'Alpha');
    // The original name remains referenced in the saved setting.
    await provider.updateOwnedPart('a', category: 'motor', name: 'Alpha');
    await tester.pumpAndSettle();
    final delete =
        find.descendant(of: alphaRow, matching: find.byTooltip('Delete'));
    await tester.ensureVisible(delete);
    await tester.tap(delete);
    await tester.pumpAndSettle();
    expect(find.textContaining('Used in 1 saved settings.'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(provider.ownedParts.length, 2);
    await tester.tap(delete);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(provider.ownedParts.map((p) => p.id), ['b']);
    expect(provider.savedSettings.single.settings['motor'], 'Alpha');
    final preferences = await SharedPreferences.getInstance();
    expect(
        (jsonDecode(preferences.getString(
                SharedPreferencesSettingsLocalRepository.settingsStateV2Key)!)
            as Map<String, dynamic>)['ownedParts'] as List,
        hasLength(1));
  });

  testWidgets('garage can register each expanded part category',
      (tester) async {
    final provider = _createProvider([]);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: provider,
      child: const MaterialApp(home: MyGaragePage()),
    ));
    await _pumpUntilInitialized(tester, provider);
    await tester.pumpAndSettle();
    for (final entry in const {
      'damper': 'Damper',
      'spring': 'Spring',
      'wheel': 'Wheel',
      'electronics': 'Electronics',
    }.entries) {
      await tester.ensureVisible(find.text('Add Part'));
      await tester.tap(find.text('Add Part'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(entry.value).last);
      await tester.tap(find.text(entry.value).last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.byType(TextFormField)),
        '${entry.value} Part',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(provider.getOwnedPartsByCategory(entry.key).single.name,
          '${entry.value} Part');
    }
    expect(provider.ownedParts, hasLength(4));
  });

  for (final brightness in Brightness.values) {
    testWidgets('parts controls fit narrow $brightness theme with large text',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final provider = _createProvider([], ownedParts: [
        _part('long', 'spring', '長いパーツ名のスプリングを登録して表示を確認する', 1),
      ]);
      await tester.pumpWidget(ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
              theme: ThemeData(brightness: brightness),
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(1.5)),
                  child: child!),
              home: const MyGaragePage())));
      await _pumpUntilInitialized(tester, provider);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
          find.widgetWithIcon(IconButton, Icons.edit_rounded), 100,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithIcon(IconButton, Icons.edit_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Edit Owned Part'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('manufacturer selection opens My Garage from shortcut card',
      (WidgetTester tester) async {
    final provider = _createProvider([
      _buildCar(isInGarage: true),
    ]);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: CarSelectionPage()),
      ),
    );

    await _pumpUntilInitialized(tester, provider);
    await tester.pump();

    expect(find.text('MY GARAGE'), findsOneWidget);
    expect(find.text('1 model registered'), findsOneWidget);

    await tester.tap(find.text('MY GARAGE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(MyGaragePage), findsOneWidget);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('TRF421'),
      100,
      scrollable: find
          .descendant(
            of: find.byType(MyGaragePage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.text('TRF421'), findsOneWidget);
  });

  testWidgets('garage car selection opens history filtered to that car',
      (WidgetTester tester) async {
    final garageCar = _buildCar(isInGarage: true);
    final otherCar = _buildCar(
      id: 'tamiya/trf420x',
      name: 'TRF420X',
    );
    final provider = _createProvider(
      [
        garageCar,
        otherCar,
      ],
      savedSettings: [
        SavedSetting(
          id: 'setting-1',
          name: 'TRF421 Race Setup',
          createdAt: DateTime(2026, 1, 2, 12, 0),
          car: garageCar,
          settings: const {},
        ),
        SavedSetting(
          id: 'setting-2',
          name: 'TRF420X Practice Setup',
          createdAt: DateTime(2026, 1, 1, 12, 0),
          car: otherCar,
          settings: const {},
        ),
      ],
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: MyGaragePage()),
      ),
    );

    await _pumpUntilInitialized(tester, provider);
    await tester.pump();

    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('TRF421'),
      100,
      scrollable: find
          .descendant(
            of: find.byType(MyGaragePage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('TRF421').first);
    await tester.pumpAndSettle();

    expect(find.byType(HistoryPage), findsOneWidget);
    expect(find.text('TRF421 Race Setup'), findsOneWidget);
    expect(find.text('TRF420X Practice Setup'), findsNothing);
  });

  testWidgets('new save shows garage prompt and can suppress future prompts',
      (WidgetTester tester) async {
    final initialCar = _buildCar();
    final provider = _createProvider([
      initialCar,
    ]);

    Future<void> pumpPage() async {
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            home: CarSettingPage(
              originalCar: initialCar,
            ),
          ),
        ),
      );
      await _pumpUntilInitialized(tester, provider);
      await tester.pump();
    }

    await pumpPage();

    final saveButton = find.text('Save Setting');

    expect(saveButton, findsOneWidget);

    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Add to My Garage?'), findsOneWidget);
    expect(find.text("Don't show again"), findsOneWidget);

    await tester.tap(find.text("Don't show again"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      provider.getCarById('tamiya/trf421')?.suppressGaragePrompt,
      isTrue,
    );
    expect(provider.getCarById('tamiya/trf421')?.isInGarage, isFalse);

    await pumpPage();

    final secondSaveButton = find.text('Save Setting');
    await tester.ensureVisible(secondSaveButton);
    await tester.tap(secondSaveButton, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Add to My Garage?'), findsNothing);
  });

  testWidgets('app editor scroll moves the input header with setting fields',
      (WidgetTester tester) async {
    final car = _buildCar();
    final provider = _createProvider([car]);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          home: CarSettingPage(originalCar: car),
        ),
      ),
    );
    await _pumpUntilInitialized(tester, provider);
    await tester.pump(const Duration(milliseconds: 600));

    final editorScrollView = find.byKey(
      const Key('setting-editor-scroll-view'),
    );
    expect(editorScrollView, findsOneWidget);

    final settingName = find.text('Setting Name');
    final initialTop = tester.getTopLeft(settingName).dy;

    await tester.drag(editorScrollView, const Offset(0, -250));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(settingName).dy, lessThan(initialTop - 100));
    expect(find.text('Favorites'), findsOneWidget);
  });
}
