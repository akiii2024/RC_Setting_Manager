import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rc_setting_manager/data/car_settings/index.dart' as legacy;
import 'package:rc_setting_manager/data/car_settings_definitions.dart';
import 'package:rc_setting_manager/models/car_setting_definition.dart';

Object? _canonicalize(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return {
      for (final key in keys) key: _canonicalize(value[key]),
    };
  }
  if (value is Iterable) {
    return value.map(_canonicalize).toList(growable: false);
  }
  return value;
}

String _fingerprint(Object? value) {
  final bytes = utf8.encode(jsonEncode(_canonicalize(value)));
  var hash = 0x811c9dc5;
  for (final byte in bytes) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

Map<String, Object> _definitionShape(CarSettingDefinition definition) {
  final settings = definition.availableSettings;
  final normalizedSettings = settings.map((setting) {
    final json = setting.toJson();
    if (setting.key == 'date') {
      json['defaultValue'] = '<current-date>';
    }
    return json;
  }).toList(growable: false);
  final options = [
    for (final setting in settings)
      if (setting.options != null)
        {'key': setting.key, 'options': setting.options},
  ];
  final composites = [
    for (final setting in settings)
      if (setting.constraints.containsKey('composite'))
        {'key': setting.key, 'constraints': setting.constraints},
  ];

  return {
    'count': settings.length,
    'keys': _fingerprint(settings.map((setting) => setting.key).toList()),
    'categories':
        _fingerprint(settings.map((setting) => setting.category).toList()),
    'options': _fingerprint(options),
    'composites': _fingerprint(composites),
    'fullShape': _fingerprint(normalizedSettings),
  };
}

void main() {
  test('全車種の登録IDと順序を維持する', () {
    expect(carSettingsDefinitions.keys.toList(), [
      'tamiya/trf421',
      'tamiya/trf420x',
      'tamiya/trf421x',
      'yokomo/bd11',
      'yokomo/bd12',
      'yokomo/ms1_0',
      'yokomo/ms2_0',
    ]);
    for (final entry in carSettingsDefinitions.entries) {
      expect(entry.value.carId, entry.key);
    }
    expect(legacy.carSettingsDefinitions, same(carSettingsDefinitions));
  });

  test('全車種のキー・カテゴリ・選択肢・複合metadataを維持する', () {
    final actual = {
      for (final entry in carSettingsDefinitions.entries)
        entry.key: _definitionShape(entry.value),
    };

    expect(actual, {
      'tamiya/trf421': {
        'count': 94,
        'keys': '8c194754',
        'categories': 'ac31c2e7',
        'options': '3c11f54c',
        'composites': '769dd45f',
        'fullShape': '5e64db6d',
      },
      'tamiya/trf420x': {
        'count': 94,
        'keys': 'd7f1b759',
        'categories': '616648bb',
        'options': 'eb8442e1',
        'composites': '2a570281',
        'fullShape': '6af6b11c',
      },
      'tamiya/trf421x': {
        'count': 100,
        'keys': '164060b1',
        'categories': 'f4593996',
        'options': 'a96eeec0',
        'composites': '769dd45f',
        'fullShape': '998bb7f2',
      },
      'yokomo/bd11': {
        'count': 75,
        'keys': '178cf457',
        'categories': '394e6391',
        'options': 'a366082c',
        'composites': '5c2b6309',
        'fullShape': 'c377fbae',
      },
      'yokomo/bd12': {
        'count': 77,
        'keys': 'e085cd7a',
        'categories': 'd9ce3b24',
        'options': '6b73060e',
        'composites': '4ad23d91',
        'fullShape': 'ad24fd6c',
      },
      'yokomo/ms1_0': {
        'count': 74,
        'keys': '285d0d0d',
        'categories': '9278acf3',
        'options': '6cc854c8',
        'composites': '39675f6d',
        'fullShape': '0497a676',
      },
      'yokomo/ms2_0': {
        'count': 75,
        'keys': 'a4172215',
        'categories': '907e0516',
        'options': '04e11613',
        'composites': '39675f6d',
        'fullShape': 'ed3a8420',
      },
    });
  });
}
