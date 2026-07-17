import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ai_provider.dart';

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
/// プロバイダとモデル名だけを [SharedPreferences] に保存し、APIキーは
/// [SecretStore] にのみ保存する。APIキーをアプリの通常バックアップや
/// Firestore同期へ含めないため、このサービスとSettingsProviderは分離する。
class AiConfigurationService {
  AiConfigurationService({
    SecretStore? secretStore,
    SharedPreferences? preferences,
  })  : _secretStore = secretStore ?? FlutterSecureSecretStore(),
        _preferences = preferences;

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

  String _requiredValue(String value, String label) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError('$labelを空白だけにすることはできません。');
    }
    return normalized;
  }

  /// 未設定または不明な値の場合は、既存機能との互換性のためGeminiを返す。
  Future<AiProvider> get selectedProvider async {
    final preferences = await _getPreferences();
    return AiProvider.tryParse(preferences.getString(_selectedProviderKey)) ??
        AiProvider.gemini;
  }

  Future<void> setSelectedProvider(AiProvider provider) async {
    final preferences = await _getPreferences();
    await preferences.setString(_selectedProviderKey, provider.value);
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
    final normalized = _requiredValue(model, 'モデル名');
    final preferences = await _getPreferences();
    await preferences.setString(_modelKey(provider), normalized);
  }

  Future<void> resetModel(AiProvider provider) async {
    final preferences = await _getPreferences();
    await preferences.remove(_modelKey(provider));
  }

  Future<String?> getApiKey(AiProvider provider) async {
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
    final normalized = _requiredValue(apiKey, 'APIキー');
    await _secretStore.write(_apiKey(provider), normalized);
  }

  Future<void> deleteApiKey(AiProvider provider) async {
    await _secretStore.delete(_apiKey(provider));
  }

  Future<AiProviderSettings> get activeSettings async {
    final provider = await selectedProvider;
    return AiProviderSettings(
      provider: provider,
      model: await getModel(provider),
    );
  }

  /// 選択中プロバイダにAPIキーがなければ `null` を返す。
  Future<AiConfiguration?> get activeConfiguration async {
    final settings = await activeSettings;
    final apiKey = await getApiKey(settings.provider);
    if (apiKey == null) {
      return null;
    }
    return AiConfiguration(
      provider: settings.provider,
      model: settings.model,
      apiKey: apiKey,
    );
  }

  Future<AiConfiguration> requireActiveConfiguration() async {
    final configuration = await activeConfiguration;
    if (configuration == null) {
      throw StateError('選択中のAIプロバイダにAPIキーが設定されていません。');
    }
    return configuration;
  }

  /// 値をすべて検証してから保存し、最後に選択プロバイダを切り替える。
  Future<void> saveConfiguration({
    required AiProvider provider,
    required String model,
    required String apiKey,
  }) async {
    final normalizedModel = _requiredValue(model, 'モデル名');
    final normalizedApiKey = _requiredValue(apiKey, 'APIキー');

    await _secretStore.write(_apiKey(provider), normalizedApiKey);
    final preferences = await _getPreferences();
    await preferences.setString(_modelKey(provider), normalizedModel);
    await preferences.setString(_selectedProviderKey, provider.value);
  }
}
