import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rc_setting_manager/models/car.dart';
import 'package:rc_setting_manager/models/manufacturer.dart';
import 'package:rc_setting_manager/providers/settings_provider.dart';

Future<void> _waitForProvider(SettingsProvider provider) async {
  for (var i = 0; i < 50; i++) {
    if (provider.isInitialized) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }

  fail('SettingsProvider did not initialize in time.');
}

Car _buildCar({
  bool isInGarage = false,
  bool suppressGaragePrompt = false,
}) {
  final manufacturer = Manufacturer(
    id: 'tamiya',
    name: 'Tamiya',
    logoPath: '',
  );

  return Car(
    id: 'tamiya/trf421',
    name: 'TRF421',
    imageUrl: '',
    manufacturer: manufacturer,
    category: 'touring',
    isInGarage: isInGarage,
    suppressGaragePrompt: suppressGaragePrompt,
  );
}

void main() {
  test('persists garage membership and suppression flags', () async {
    final initialCar = _buildCar();

    SharedPreferences.setMockInitialValues({
      'cars_settings': jsonEncode([initialCar.toJson()]),
      'language_settings': true,
    });

    final provider = SettingsProvider();
    await _waitForProvider(provider);

    await provider.setGarageMembership(initialCar.id, true);
    await provider.setGaragePromptSuppressed(initialCar.id, true);

    expect(provider.garageCars.map((car) => car.id), contains(initialCar.id));
    expect(provider.getCarById(initialCar.id)?.suppressGaragePrompt, isTrue);

    final reloadedProvider = SettingsProvider();
    await _waitForProvider(reloadedProvider);

    final reloadedCar = reloadedProvider.getCarById(initialCar.id);
    expect(reloadedCar, isNotNull);
    expect(reloadedCar?.isInGarage, isTrue);
    expect(reloadedCar?.suppressGaragePrompt, isTrue);
  });
}
