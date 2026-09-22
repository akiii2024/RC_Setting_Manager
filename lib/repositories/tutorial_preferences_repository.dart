import 'package:shared_preferences/shared_preferences.dart';

/// チュートリアルの完了状態を保存・読み込みする境界。
abstract interface class TutorialPreferencesRepository {
  /// 保存済みの完了状態を返す。未保存の場合は `null` を返す。
  Future<bool?> load();

  /// 完了状態を保存し、書き込み結果を返す。
  Future<bool> save(bool completed);
}

typedef TutorialSharedPreferencesLoader = Future<SharedPreferences> Function();
typedef TutorialSharedPreferencesWriter = Future<bool> Function(
  SharedPreferences preferences,
  String key,
  bool value,
);

/// [SharedPreferences] を利用したチュートリアル完了状態の実装。
class SharedPreferencesTutorialPreferencesRepository
    implements TutorialPreferencesRepository {
  SharedPreferencesTutorialPreferencesRepository({
    TutorialSharedPreferencesLoader? preferencesLoader,
    TutorialSharedPreferencesWriter? preferencesWriter,
  })  : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance,
        _preferencesWriter = preferencesWriter ??
            ((preferences, key, value) => preferences.setBool(key, value));

  static const String tutorialCompletedKey = 'tutorial_completed_v1';

  final TutorialSharedPreferencesLoader _preferencesLoader;
  final TutorialSharedPreferencesWriter _preferencesWriter;

  @override
  Future<bool?> load() async {
    final preferences = await _preferencesLoader();
    return preferences.getBool(tutorialCompletedKey);
  }

  @override
  Future<bool> save(bool completed) async {
    final preferences = await _preferencesLoader();
    return _preferencesWriter(preferences, tutorialCompletedKey, completed);
  }
}
