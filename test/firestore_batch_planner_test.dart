import 'package:flutter_test/flutter_test.dart';

import 'package:rc_setting_manager/domain/settings/settings_id_generator.dart';
import 'package:rc_setting_manager/services/firestore_batch_planner.dart';

void main() {
  group('planFirestoreSyncBatches', () {
    test('keeps 450 operations in one batch', () {
      final batches =
          planFirestoreSyncBatches(List<int>.generate(450, (i) => i));

      expect(batches, hasLength(1));
      expect(batches.single, hasLength(450));
    });

    test('splits 451 operations without reordering', () {
      final source = List<int>.generate(451, (i) => i);
      final batches = planFirestoreSyncBatches(source);

      expect(batches.map((batch) => batch.length), [450, 1]);
      expect(batches.expand((batch) => batch), source);
    });

    test('splits 900 operations into two full batches', () {
      final batches =
          planFirestoreSyncBatches(List<int>.generate(900, (i) => i));

      expect(batches.map((batch) => batch.length), [450, 450]);
    });
  });

  test('secure IDs do not depend on clock precision', () {
    final generator = SecureSettingsIdGenerator();
    final ids = List<String>.generate(1000, (_) => generator.nextId());

    expect(ids.toSet(), hasLength(ids.length));
    expect(
      ids.every(
        (id) => RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(id),
      ),
      isTrue,
    );
  });
}
