import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ai_provider.dart';
import '../models/open_code_go_model.dart';

/// APIキーの保存先を抽象化する最小インターフェース。
abstract interface class SecretStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

/// OSの保護された資格情報ストアを使用する既定実装。
///
/// Webでは永続ストレージへ秘密を残さず、ページを再読み込みするまでの
/// メモリ内セッションだけで共有する。
class FlutterSecureSecretStore implements SecretStore {
  FlutterSecureSecretStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.unlocked_this_device,
              ),
              mOptions: MacOsOptions(
                accessibility: KeychainAccessibility.unlocked_this_device,
              ),
            );

  final FlutterSecureStorage _storage;
  static final Map<String, String> _webSessionValues = {};

  @override
  Future<String?> read(String key) async {
    if (kIsWeb) return _webSessionValues[key];
    return _storage.read(key: key);
  }

  @override
  Future<void> write(String key, String value) async {
    if (kIsWeb) {
      _webSessionValues[key] = value;
      return;
    }
    await _storage.write(key: key, value: value);
  }

  @override
  Future<void> delete(String key) async {
    if (kIsWeb) {
      _webSessionValues.remove(key);
      return;
    }
    await _storage.delete(key: key);
  }
}

/// テストや一時セッション向けのメモリ内資格情報ストア。
class MemorySecretStore implements SecretStore {
  MemorySecretStore([Map<String, String>? initialValues])
      : _values = Map<String, String>.from(initialValues ?? const {});

  final Map<String, String> _values;

  Map<String, String> get values => Map.unmodifiable(_values);

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}

/// AIプロバイダ設定とAPIキーを、秘密度に応じて別々に管理する。
///
/// 開発者モード・利用方式・プロバイダ・モデル名を [SharedPreferences] に保存し、APIキーは
/// [SecretStore] にのみ保存する。APIキーをアプリの通常バックアップや
/// Firestore同期へ含めないため、このサービスとSettingsProviderは分離する。
class AiConfigurationService {
  AiConfigurationService({
    SecretStore? secretStore,
    SharedPreferences? preferences,
    bool? isWeb,
  })  : _secretStore = secretStore ?? FlutterSecureSecretStore(),
        _preferences = preferences,
        isWeb = isWeb ?? kIsWeb;

  final bool isWeb;

  static const String _developerUnlockedKey = 'developer_mode_unlocked_v1';

  /// 別の画面・サービスインスタンスから設定が変わった場合も表示を更新する。
  static final ValueNotifier<int> changes = ValueNotifier(0);
  static const String _developerEnabledKey = 'developer_mode_enabled_v1';
  static const String _personalApiKey = 'ai_configuration_personal_api_v1';
  static const String _selectedProviderKey =
      'ai_configuration_selected_provider_v1';
  static const String _modelKeyPrefix = 'ai_configuration_model_v1_';
  static const String _apiKeyPrefix = 'rc_setting_manager_ai_api_key_v1_';

  final SecretStore _secretStore;
  final SharedPreferences? _preferences;

  Future<SharedPreferences> _getPreferences() async {
    return _preferences ?? await SharedPreferences.getInstance();
  }

  String _modelKey(AiProvider provider) => '$_modelKeyPrefix${provider.value}';

  String _apiKey(AiProvider provider) => '$_apiKeyPrefix${provider.value}';

  void _requireProviderSupported(AiProvider provider) {
    if (isWeb && provider == AiProvider.openCodeGo) {
      throw StateError(OpenCodeGoModel.webUnavailableMessage);
    }
  }

  String _validatedModel(AiProvider provider, String model) {
    _requireProviderSupported(provider);
    final normalized = _requiredValue(model, 'モデル名');
    if (provider == AiProvider.openCodeGo &&
        OpenCodeGoModel.tryParse(normalized) == null) {
      throw ArgumentError('未対応のOpenCode Goモデルです。対応モデルから選択してください。');
    }
    return normalized;
  }

  String _requiredValue(String value, String label) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError('$labelを空白だけにすることはできません。');
    }
    return normalized;
  }

  Future<void> _ensureWritten(Future<bool> operation) async {
    if (!await operation) throw StateError('設定を保存できませんでした。もう一度お試しください。');
    changes.value++;
  }

  Future<void> _writeBool(
      SharedPreferences preferences, String key, bool value) async {
    final previous = preferences.getBool(key);
    try {
      await _ensureWritten(preferences.setBool(key, value));
    } catch (_) {
      // SharedPreferencesは書き込み失敗時も先にメモリキャッシュを更新する。
      // 個人APIの有効化が失敗した値を、その後のリクエストが参照しないよう戻す。
      try {
        if (previous == null) {
          await preferences.remove(key);
        } else {
          await preferences.setBool(key, previous);
        }
      } catch (_) {
        // 元の保存エラーを呼び出し元へ返す。
      }
      rethrow;
    }
  }

  Future<bool> get isDeveloperModeUnlocked async =>
      (await _getPreferences()).getBool(_developerUnlockedKey) ?? false;

  Future<bool> get isDeveloperModeEnabled async {
    final preferences = await _getPreferences();
    return (preferences.getBool(_developerUnlockedKey) ?? false) &&
        (preferences.getBool(_developerEnabledKey) ?? false);
  }

  Future<void> unlockDeveloperMode() async {
    final preferences = await _getPreferences();
    await _writeBool(preferences, _developerUnlockedKey, true);
  }

  Future<void> setDeveloperModeEnabled(bool enabled) async {
    final preferences = await _getPreferences();
    if (enabled && !await isDeveloperModeUnlocked) {
      throw StateError('バージョンを7回タップして開発者モードを解放してください。');
    }
    // 再有効化しても、個人APIの利用は自動再開しない。
    await selectManagedGemini();
    await _writeBool(preferences, _developerEnabledKey, enabled);
  }

  Future<void> requireDeveloperMode() async {
    if (!await isDeveloperModeEnabled) {
      throw StateError('個人APIキーを利用するには開発者モードをオンにしてください。');
    }
  }

  Future<void> selectManagedGemini() async {
    final preferences = await _getPreferences();
    await _writeBool(preferences, _personalApiKey, false);
  }

  Future<bool> get usesManagedGemini async =>
      (await activeSettings).usesManagedGemini;

  Future<AiProvider> get selectedProvider async =>
      (await activeSettings).provider;

  Future<void> selectPersonalProvider(
      {required AiProvider provider, required String model}) async {
    final normalized = _validatedModel(provider, model);
    await requireDeveloperMode();
    if (!await hasApiKey(provider)) throw StateError('APIキーを入力して保存してください。');
    await _activatePersonalProvider(provider, normalized);
  }

  Future<void> _activatePersonalProvider(
      AiProvider provider, String model) async {
    _validatedModel(provider, model);
    await requireDeveloperMode();
    await selectManagedGemini();
    final preferences = await _getPreferences();
    await _ensureWritten(preferences.setString(_modelKey(provider), model));
    await _ensureWritten(
        preferences.setString(_selectedProviderKey, provider.value));
    await requireDeveloperMode();
    await _writeBool(preferences, _personalApiKey, true);
  }

  Future<void> setSelectedProvider(AiProvider provider) async {
    if (provider == AiProvider.gemini) {
      await selectManagedGemini();
    } else {
      await selectPersonalProvider(
          provider: provider, model: await getModel(provider));
    }
  }

  Future<String> getModel(AiProvider provider) async {
    final preferences = await _getPreferences();
    final storedModel = preferences.getString(_modelKey(provider))?.trim();
    if (storedModel == null || storedModel.isEmpty) {
      return provider.defaultModel;
    }
    return storedModel;
  }

  Future<void> setModel(AiProvider provider, String model) async {
    final normalized = _validatedModel(provider, model);
    await requireDeveloperMode();
    final preferences = await _getPreferences();
    await _ensureWritten(
        preferences.setString(_modelKey(provider), normalized));
  }

  Future<void> resetModel(AiProvider provider) async {
    _requireProviderSupported(provider);
    await requireDeveloperMode();
    final preferences = await _getPreferences();
    await preferences.remove(_modelKey(provider));
  }

  Future<String?> getApiKey(AiProvider provider) async {
    await requireDeveloperMode();
    final storedKey = (await _secretStore.read(_apiKey(provider)))?.trim();
    if (storedKey == null || storedKey.isEmpty) {
      return null;
    }
    return storedKey;
  }

  Future<bool> hasApiKey(AiProvider provider) async {
    return await getApiKey(provider) != null;
  }

  Future<void> saveApiKey(AiProvider provider, String apiKey) async {
    _requireProviderSupported(provider);
    final normalized = _requiredValue(apiKey, 'APIキー');
    await requireDeveloperMode();
    await _secretStore.write(_apiKey(provider), normalized);
  }

  Future<void> deleteApiKey(AiProvider provider) async {
    await _secretStore.delete(_apiKey(provider));
  }

  Future<AiProviderSettings> get activeSettings async {
    final preferences = await _getPreferences();
    final provider =
        AiProvider.tryParse(preferences.getString(_selectedProviderKey));
    if (!await isDeveloperModeEnabled ||
        !(preferences.getBool(_personalApiKey) ?? false) ||
        provider == null) {
      return AiProviderSettings(
          provider: AiProvider.gemini, model: AiProvider.gemini.defaultModel);
    }
    return AiProviderSettings(
      provider: provider,
      model: await getModel(provider),
      accessMode: AiAccessMode.personalApi,
    );
  }

  /// 標準Geminiはサーバー側のAPIキーを使うため、端末での設定は不要。
  Future<bool> get isReady async {
    final settings = await activeSettings;
    if (settings.usesManagedGemini) return true;
    if (await availabilityIssue() != null) return false;
    return await activeConfiguration != null;
  }

  /// キーを読み出さず、機能を開始する前に表示できる設定上の案内。
  Future<String?> availabilityIssue({
    bool requireImages = false,
    bool isEnglish = false,
  }) async {
    final settings = await activeSettings;
    if (settings.usesManagedGemini ||
        settings.provider != AiProvider.openCodeGo) {
      return null;
    }
    if (isWeb) {
      return isEnglish
          ? 'OpenCode Go is unavailable on web due to CORS restrictions. Use the app or select another AI provider.'
          : OpenCodeGoModel.webUnavailableMessage;
    }
    final model = OpenCodeGoModel.tryParse(settings.model);
    if (model == null) {
      return isEnglish
          ? 'This OpenCode Go model is unsupported. Select a supported model in AI settings.'
          : '未対応のOpenCode Goモデルです。AI設定で対応モデルを選択してください。';
    }
    if (requireImages && !model.supportsImages) {
      return isEnglish
          ? 'This OpenCode Go model does not support images. Select an image-capable model in AI settings before using OCR.'
          : '選択中のOpenCode Goモデルは画像に対応していません。OCRを使うにはAI設定で画像対応モデルを選択してください。';
    }
    return null;
  }

  /// 標準Geminiでは保存された個人キーを読み出さない。
  Future<AiConfiguration?> get activeConfiguration async {
    final settings = await activeSettings;
    if (settings.usesManagedGemini) return null;
    _validatedModel(settings.provider, settings.model);
    final apiKey = await getApiKey(settings.provider);
    if (apiKey == null) {
      return null;
    }
    await requireDeveloperMode();
    return AiConfiguration(
      provider: settings.provider,
      model: settings.model,
      apiKey: apiKey,
    );
  }

  Future<AiConfiguration> requireActiveConfiguration() async {
    final configuration = await activeConfiguration;
    if (configuration == null) {
      throw StateError('開発者モードとAPI設定を確認し、APIキーを保存してください。');
    }
    return configuration;
  }

  /// 値をすべて検証してから保存し、最後に選択プロバイダを切り替える。
  Future<void> saveConfiguration({
    required AiProvider provider,
    required String model,
    required String apiKey,
  }) async {
    final normalizedModel = _validatedModel(provider, model);
    final normalizedApiKey = _requiredValue(apiKey, 'APIキー');

    await requireDeveloperMode();
    // 途中で保存に失敗した場合、個人APIの利用は開始しない。
    await selectManagedGemini();
    await _secretStore.write(_apiKey(provider), normalizedApiKey);
    await _activatePersonalProvider(provider, normalizedModel);
  }
}
