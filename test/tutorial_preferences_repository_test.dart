import 'package:flutter_test/flutter_test.dart';
import 'package:rc_setting_manager/repositories/tutorial_preferences_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SharedPreferencesTutorialPreferencesRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('load returns null when the completion state is not saved', () async {
      final repository = SharedPreferencesTutorialPreferencesRepository();

      expect(await repository.load(), isNull);
    });

    test('load returns the persisted completion state', () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesTutorialPreferencesRepository.tutorialCompletedKey:
            true,
      });
      final repository = SharedPreferencesTutorialPreferencesRepository();

      expect(await repository.load(), isTrue);
    });

    test('save persists the completion state', () async {
      final repository = SharedPreferencesTutorialPreferencesRepository();

      expect(await repository.save(true), isTrue);

      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getBool(
          SharedPreferencesTutorialPreferencesRepository.tutorialCompletedKey,
        ),
        isTrue,
      );
    });

    test('save can persist an incomplete state', () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesTutorialPreferencesRepository.tutorialCompletedKey:
            true,
      });
      final repository = SharedPreferencesTutorialPreferencesRepository();

      expect(await repository.save(false), isTrue);
      expect(await repository.load(), isFalse);
    });
  });
}
