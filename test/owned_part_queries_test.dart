import 'package:flutter_test/flutter_test.dart';

import 'package:rc_setting_manager/data/built_in_car_catalog.dart';
import 'package:rc_setting_manager/domain/parts/owned_part_queries.dart';
import 'package:rc_setting_manager/models/owned_part.dart';
import 'package:rc_setting_manager/models/saved_setting.dart';

void main() {
  test('owned parts lead suggestions while typed search merges history', () {
    final car = BuiltInCarCatalog.create().first;
    final history = [
      SavedSetting(
        id: 'setting-1',
        name: 'History',
        createdAt: DateTime(2026),
        car: car,
        settings: const {'motor': 'History Motor 17.5T'},
      ),
    ];
    final ownedParts = [
      OwnedPart(
        id: 'part-1',
        category: 'motor',
        name: 'Owned Motor 17.5T',
        createdAt: DateTime(2026),
      ),
    ];

    expect(
      OwnedPartQueries.suggestions(
        key: 'motor',
        baseOptions: const ['Catalog Motor 17.5T'],
        savedSettings: history,
        ownedParts: ownedParts,
      ),
      ['Owned Motor 17.5T'],
    );
    expect(
      OwnedPartQueries.suggestions(
        key: 'motor',
        baseOptions: const ['Catalog Motor 17.5T'],
        savedSettings: history,
        ownedParts: ownedParts,
        query: '17.5',
      ),
      containsAll([
        'Owned Motor 17.5T',
        'Catalog Motor 17.5T',
        'History Motor 17.5T',
      ]),
    );
  });

  test('history candidates exclude duplicates and turn-only motor names', () {
    final car = BuiltInCarCatalog.create().first;
    final settings = [
      SavedSetting(
        id: 'setting-1',
        name: 'History',
        createdAt: DateTime(2026),
        car: car,
        settings: const {
          'motor': '13.5T',
          'frontTire': 'Custom Tire 32',
          'rearTire': 'Custom Tire 32',
        },
      ),
    ];

    final candidates = OwnedPartQueries.importCandidates(
      savedSettings: settings,
      ownedParts: const [],
    );
    expect(candidates.map((candidate) => candidate.name), ['Custom Tire 32']);
  });
}
