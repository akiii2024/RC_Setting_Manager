import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rc_setting_manager/models/car.dart';
import 'package:rc_setting_manager/models/manufacturer.dart';
import 'package:rc_setting_manager/pages/car_setting_page.dart';
import 'package:rc_setting_manager/providers/app_mode_provider.dart';
import 'package:rc_setting_manager/providers/settings_provider.dart';
import 'package:rc_setting_manager/services/setting_draft_service.dart';
import 'package:rc_setting_manager/services/track_location_service.dart';
import 'package:rc_setting_manager/widgets/grid_selector.dart';

const _carId = 'tamiya/trf421';
const _recoveredName = 'Recovered setup';
const _recoveredTrack = 'Recovered circuit';
const _nearestTrack = 'ホビーショップタムタム札幌店';

Finder _headerField(String label) => find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == label,
    );

String _headerText(WidgetTester tester, String label) =>
    tester.widget<TextField>(_headerField(label)).controller!.text;

Future<SettingsProvider> _pumpDraft(
  WidgetTester tester, {
  required Map<String, dynamic> settings,
  List<String> favorites = const [],
  Brightness brightness = Brightness.light,
  bool consent = false,
  bool resolveDialog = true,
}) async {
  tester.view.physicalSize = const Size(1200, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final car = Car(
    id: _carId,
    name: 'TRF421',
    imageUrl: '',
    manufacturer: Manufacturer(id: 'tamiya', name: 'Tamiya', logoPath: ''),
    category: 'touring',
    suppressGaragePrompt: true,
  );
  SharedPreferences.setMockInitialValues({
    SettingDraftService(_carId, null).key: jsonEncode({
      'settings': settings,
      'name': _recoveredName,
      'trackName': _recoveredTrack,
    }),
    'language_settings': true,
    'cars_settings': jsonEncode([car.toJson()]),
    'saved_settings': '[]',
    'visibility_settings': jsonEncode({
      _carId: {
        'carId': _carId,
        'settingsVisibility': <String, bool>{},
        'favoriteSettings': {for (final key in favorites) key: true},
      },
    }),
    'weather_location_api_prompt_suppressed_v1': !consent,
    'weather_location_api_consent_v1': consent,
    'weather_cache_current_v1': jsonEncode({
      'lat': 43.0642,
      'lon': 141.3469,
      'fetchedAt': DateTime.now().millisecondsSinceEpoch,
      'data': {
        'temperature': 25.0,
        'humidity': 60,
        'description': 'Clear',
        'feelsLike': 25.0,
        'pressure': 1000,
        'visibility': 10000,
        'windSpeed': 1.0,
        'windDirection': 0,
        'cloudiness': 0,
        'cityName': 'Sapporo',
      },
    }),
  });
  final provider = SettingsProvider(
    appModeProvider: AppModeProvider(
      preferredOnline: false,
      isFirebaseReady: false,
    ),
  );
  await tester.runAsync(() => provider.initialization);
  await tester.pumpWidget(ChangeNotifierProvider.value(
    value: provider,
    child: MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: CarSettingPage(originalCar: car),
    ),
  ));
  await tester.pumpAndSettle();
  expect(find.text('Restore draft?'), findsOneWidget);
  if (resolveDialog) {
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
  }
  addTearDown(provider.dispose);
  return provider;
}

Future<void> _runEditorTest(
  WidgetTester tester,
  Future<void> Function() body,
) async {
  try {
    await body();
  } finally {
    try {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
        'restores visible grid selection in ${brightness.name} theme',
        (tester) => _runEditorTest(tester, () async {
              final provider = await _pumpDraft(tester,
                  settings: {
                    'motorMountScrewPositions': [
                      {'row': 1, 'col': 2},
                    ],
                  },
                  favorites: ['motorMountScrewPositions'],
                  brightness: brightness);
              final grid = find.byType(GridSelector).first;
              expect(
                find.descendant(
                    of: grid, matching: find.byIcon(Icons.check_rounded)),
                findsOneWidget,
              );
              await tester.tap(find.text('Save Setting'));
              await tester.pumpAndSettle();
              expect(
                  provider.savedSettings.single
                      .settings['motorMountScrewPositions'],
                  [
                    {'row': 1, 'col': 2}
                  ]);
            }));

    testWidgets(
        'restores visible composite text in ${brightness.name} theme',
        (tester) => _runEditorTest(tester, () async {
              final provider = await _pumpDraft(tester,
                  settings: {'frontStabilizer': 2.0},
                  favorites: ['frontStabilizer'],
                  brightness: brightness);
              final field = find.byWidgetPredicate((widget) =>
                  widget is TextFormField && widget.initialValue == '2.0');
              final editable = find.descendant(
                  of: field, matching: find.byType(EditableText));
              expect(
                  tester.widget<EditableText>(editable).controller.text, '2.0');
              await tester.tap(find.text('Save Setting'));
              await tester.pumpAndSettle();
              expect(provider.savedSettings.single.settings['frontStabilizer'],
                  2.0);
            }));

    testWidgets(
        'shows the recovered date in ${brightness.name} theme',
        (tester) => _runEditorTest(tester, () async {
              await _pumpDraft(tester,
                  settings: {'date': '2025-01-02'},
                  favorites: ['date'],
                  brightness: brightness);
              final date = find.byWidgetPredicate((widget) =>
                  widget is TextFormField &&
                  widget.initialValue == '2025-01-02');
              expect(date, findsWidgets);
              expect(
                tester
                    .widget<EditableText>(find.descendant(
                        of: date.first, matching: find.byType(EditableText)))
                    .controller
                    .text,
                '2025-01-02',
              );
            }));
  }

  for (final input in ['NaN', 'Infinity', '1e999']) {
    testWidgets(
        'rejects $input without losing the previous valid number',
        (tester) => _runEditorTest(tester, () async {
              final provider = await _pumpDraft(tester,
                  settings: {'airTemp': 15.0}, favorites: ['airTemp']);
              final field = find.byKey(const ValueKey('airTemp_15.0')).first;
              await tester.enterText(field, input);
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              expect(find.text('Enter a valid number'), findsWidgets);
              expect(
                  (await SettingDraftService(_carId, null).read())?['settings']
                      ['airTemp'],
                  15.0);
              await tester.tap(find.text('Save Setting'));
              await tester.pumpAndSettle();
              expect(provider.savedSettings, isEmpty);
              expect(
                  find.text(
                      'Please enter valid numbers in the highlighted fields'),
                  findsOneWidget);
              await tester.enterText(field, '18');
              await tester.pumpAndSettle();
              expect(find.text('Enter a valid number'), findsNothing);
              await tester.tap(find.text('Save Setting'));
              await tester.pumpAndSettle();
              expect(provider.savedSettings.single.settings['airTemp'], 18.0);
              expect(await SettingDraftService(_carId, null).read(), isNull);
            }));
  }

  testWidgets(
      'composite number validation preserves the last valid diameter',
      (tester) => _runEditorTest(tester, () async {
            final provider = await _pumpDraft(tester,
                settings: {'frontStabilizer': 2.0},
                favorites: ['frontStabilizer']);
            final field = find.byWidgetPredicate((widget) =>
                widget is TextFormField && widget.initialValue == '2.0');
            await tester.enterText(field, '1e999');
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(find.text('Enter a valid number'), findsWidgets);
            await tester.tap(find.text('Save Setting'));
            await tester.pumpAndSettle();
            expect(provider.savedSettings, isEmpty);
            await tester.enterText(field, '2.2');
            await tester.pumpAndSettle();
            await tester.tap(find.text('Save Setting'));
            await tester.pumpAndSettle();
            expect(
                provider.savedSettings.single.settings['frontStabilizer'], 2.2);
          }));

  group('environment initialization', () {
    const channel = MethodChannel('flutter.baseflow.com/geolocator');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late List<String> locationCalls;
    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      locationCalls = [];
      messenger.setMockMethodCallHandler(channel, (call) async {
        locationCalls.add(call.method);
        switch (call.method) {
          case 'isLocationServiceEnabled':
            return true;
          case 'checkPermission':
            return LocationPermission.whileInUse.index;
          case 'getCurrentPosition':
            return {'latitude': 43.0642, 'longitude': 141.3469};
          default:
            throw MissingPluginException(call.method);
        }
      });
    });
    tearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets(
        'waits for draft decision and preserves recovered input',
        (tester) => _runEditorTest(tester, () async {
              final provider = await _pumpDraft(tester,
                  settings: {
                    'surface': 'アスファルト',
                    'airTemp': 15.0,
                    'humidity': 20.0
                  },
                  consent: true,
                  resolveDialog: false);
              await tester.runAsync(
                  () => TrackLocationService.instance.loadTrackLocations());
              await tester.pump(const Duration(seconds: 1));
              await tester.pumpAndSettle();
              expect(locationCalls, isEmpty);
              await tester.tap(find.text('Restore'));
              await tester.pumpAndSettle();
              await tester.pump(const Duration(milliseconds: 600));
              await tester.pumpAndSettle();
              expect(locationCalls, contains('getCurrentPosition'));
              expect(_headerText(tester, 'Setting Name'), _recoveredName);
              expect(_headerText(tester, 'Track Name'), _recoveredTrack);
              await tester.tap(find.text('Save Setting'));
              await tester.pumpAndSettle();
              final saved = provider.savedSettings.single;
              expect(saved.name, _recoveredName);
              expect(saved.settings['surface'], 'アスファルト');
              expect(saved.settings['airTemp'], 15.0);
              expect(saved.settings['humidity'], 20.0);
            }));

    testWidgets(
        'discarded draft still gets automatic location and weather',
        (tester) => _runEditorTest(tester, () async {
              await _pumpDraft(tester,
                  settings: {
                    'surface': 'アスファルト',
                    'airTemp': 15.0,
                    'humidity': 20.0
                  },
                  consent: true,
                  resolveDialog: false);
              await tester.runAsync(
                  () => TrackLocationService.instance.loadTrackLocations());
              await tester.tap(find.text('Discard'));
              await tester.pumpAndSettle();
              await tester.pump(const Duration(milliseconds: 600));
              await tester.pumpAndSettle();
              expect(_headerText(tester, 'Track Name'), _nearestTrack);
              expect(
                  _headerText(tester, 'Setting Name'), contains(_nearestTrack));
              await tester.pump(const Duration(milliseconds: 600));
              final draft = await SettingDraftService(_carId, null).read();
              expect(draft?['settings']['surface'], 'カーペット');
              expect(draft?['settings']['airTemp'], 25.0);
              expect(draft?['settings']['humidity'], 60.0);
            }));

    testWidgets(
        'manual location refresh can update a recovered setup',
        (tester) => _runEditorTest(tester, () async {
              await _pumpDraft(tester,
                  settings: {'surface': 'アスファルト'}, consent: true);
              await tester.runAsync(
                  () => TrackLocationService.instance.loadTrackLocations());
              await tester.pump(const Duration(milliseconds: 600));
              await tester.pumpAndSettle();
              expect(_headerText(tester, 'Track Name'), _recoveredTrack);
              await tester.tap(find.byIcon(Icons.my_location));
              await tester.pumpAndSettle();
              expect(_headerText(tester, 'Track Name'), _nearestTrack);
              await tester.pump(const Duration(milliseconds: 600));
              final draft = await SettingDraftService(_carId, null).read();
              expect(draft?['settings']['surface'], 'カーペット');
            }));
  });
}
