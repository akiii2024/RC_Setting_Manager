import 'package:flutter_test/flutter_test.dart';
import 'package:rc_setting_manager/models/ai_provider.dart';
import 'package:rc_setting_manager/services/ai_configuration_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _enable(AiConfigurationService service) async {
  await service.unlockDeveloperMode();
  await service.setDeveloperModeEnabled(true);
}

class _FailingSecretStore extends MemorySecretStore {
  @override
  Future<void> write(String key, String value) async =>
      throw StateError('write failed');
}

class _UnreadableSecretStore extends MemorySecretStore {
  _UnreadableSecretStore()
      : super({'rc_setting_manager_ai_api_key_v1_gemini': 'retained-key'});

  @override
  Future<String?> read(String key) async =>
      throw StateError('standard mode must not read secrets');
}

class _FailingActivationPreferences implements SharedPreferences {
  _FailingActivationPreferences(this.delegate);
  final SharedPreferences delegate;
  @override
  bool? getBool(String key) => delegate.getBool(key);
  @override
  String? getString(String key) => delegate.getString(key);
  @override
  Future<bool> setString(String key, String value) =>
      delegate.setString(key, value);
  @override
  Future<bool> remove(String key) => delegate.remove(key);
  @override
  Future<bool> setBool(String key, bool value) async {
    final result = await delegate.setBool(key, value);
    return key == 'ai_configuration_personal_api_v1' && value ? false : result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('provider metadata has stable values and requested default models', () {
    expect(AiProvider.openAI.value, 'openai');
    expect(AiProvider.openAI.displayName, 'OpenAI');
    expect(AiProvider.openAI.defaultModel, 'gpt-5.6-sol');
    expect(AiProvider.anthropic.defaultModel, 'claude-sonnet-5');
    expect(AiProvider.gemini.defaultModel, 'gemini-3.8-flash');
    expect(AiProvider.tryParse(' OpenAI '), AiProvider.openAI);
    expect(AiProvider.tryParse('unknown'), isNull);
  });

  test('defaults to Gemini without exposing an active configuration', () async {
    final service = AiConfigurationService(
      secretStore: MemorySecretStore(),
    );

    expect(await service.selectedProvider, AiProvider.gemini);
    expect(await service.isReady, isTrue);
    expect(
      await service.getModel(AiProvider.gemini),
      AiProvider.gemini.defaultModel,
    );
    expect(await service.activeConfiguration, isNull);
    expect(
      service.requireActiveConfiguration(),
      throwsA(isA<StateError>()),
    );
  });

  test('stores provider models separately and keys only in SecretStore',
      () async {
    final secrets = MemorySecretStore();
    final service = AiConfigurationService(secretStore: secrets);
    await _enable(service);

    await service.saveConfiguration(
      provider: AiProvider.openAI,
      model: '  gpt-custom  ',
      apiKey: '  sk-openai-secret  ',
    );
    await service.setModel(AiProvider.anthropic, 'claude-custom');
    await service.saveApiKey(AiProvider.anthropic, 'sk-ant-secret');
    await service.saveApiKey(AiProvider.gemini, 'gemini-secret');

    expect(await service.selectedProvider, AiProvider.openAI);
    expect(await service.getModel(AiProvider.openAI), 'gpt-custom');
    expect(await service.getModel(AiProvider.anthropic), 'claude-custom');
    expect(
      await service.getModel(AiProvider.gemini),
      AiProvider.gemini.defaultModel,
    );
    expect(await service.getApiKey(AiProvider.openAI), 'sk-openai-secret');
    expect(await service.getApiKey(AiProvider.anthropic), 'sk-ant-secret');
    expect(await service.getApiKey(AiProvider.gemini), 'gemini-secret');
    expect(secrets.values, hasLength(3));

    final preferences = await SharedPreferences.getInstance();
    final persistedValues = preferences.getKeys().map(preferences.get).toList();
    expect(persistedValues, isNot(contains('sk-openai-secret')));
    expect(persistedValues, isNot(contains('sk-ant-secret')));
    expect(persistedValues, isNot(contains('gemini-secret')));

    final active = await service.activeConfiguration;
    expect(active, isNotNull);
    expect(active!.provider, AiProvider.openAI);
    expect(active.model, 'gpt-custom');
    expect(active.apiKey, 'sk-openai-secret');
    expect(active.toString(), isNot(contains('sk-openai-secret')));
  });

  test('switches provider and deletes only the requested provider key',
      () async {
    final service = AiConfigurationService(
      secretStore: MemorySecretStore(),
    );
    await _enable(service);
    await service.saveApiKey(AiProvider.openAI, 'openai-key');
    await service.saveApiKey(AiProvider.anthropic, 'anthropic-key');
    await service.setSelectedProvider(AiProvider.anthropic);

    expect((await service.activeConfiguration)?.apiKey, 'anthropic-key');

    await service.deleteApiKey(AiProvider.anthropic);

    expect(await service.activeConfiguration, isNull);
    expect(await service.getApiKey(AiProvider.openAI), 'openai-key');
    expect(await service.getApiKey(AiProvider.anthropic), isNull);
  });

  test(
      'off blocks personal settings and ignores legacy selection without reading keys',
      () async {
    SharedPreferences.setMockInitialValues({
      'ai_configuration_selected_provider_v1': 'openai',
      'ai_configuration_personal_api_v1': true,
    });
    final secrets = MemorySecretStore(
        {'rc_setting_manager_ai_api_key_v1_openai': 'old-key'});
    final service = AiConfigurationService(secretStore: secrets);
    expect(await service.isDeveloperModeUnlocked, isFalse);
    expect(await service.isDeveloperModeEnabled, isFalse);
    expect(await service.usesManagedGemini, isTrue);
    expect(await service.activeConfiguration, isNull);
    await expectLater(service.setDeveloperModeEnabled(true), throwsStateError);
    await expectLater(
        service.saveApiKey(AiProvider.openAI, 'new-key'), throwsStateError);
    await expectLater(service.getApiKey(AiProvider.openAI), throwsStateError);
    await expectLater(
        service.saveConfiguration(
            provider: AiProvider.gemini, model: 'model', apiKey: 'key'),
        throwsStateError);
    expect(secrets.values.values.single, 'old-key');
  });

  test('disabling retains keys and models without automatic resumption',
      () async {
    final secrets = MemorySecretStore();
    final service = AiConfigurationService(secretStore: secrets);
    await _enable(service);
    await service.saveConfiguration(
        provider: AiProvider.gemini,
        model: 'personal-model',
        apiKey: 'personal-key');
    expect(await service.usesManagedGemini, isFalse);
    expect(await service.isReady, isTrue);
    await service.setDeveloperModeEnabled(false);
    expect(await service.usesManagedGemini, isTrue);
    expect(await service.activeConfiguration, isNull);
    expect(secrets.values.values.single, 'personal-key');
    final restored = AiConfigurationService(secretStore: secrets);
    expect(await restored.isDeveloperModeUnlocked, isTrue);
    expect(await restored.isDeveloperModeEnabled, isFalse);
    await restored.setDeveloperModeEnabled(true);
    expect(await restored.usesManagedGemini, isTrue);
    expect(await restored.getModel(AiProvider.gemini), 'personal-model');
    await restored.selectPersonalProvider(
        provider: AiProvider.gemini, model: 'personal-model');
    expect(
        (await restored.requireActiveConfiguration()).apiKey, 'personal-key');
    await restored.selectManagedGemini();
    expect(await restored.activeConfiguration, isNull);
  });

  test('personal Gemini without a key is not ready and does not fall back',
      () async {
    final service = AiConfigurationService(secretStore: MemorySecretStore());
    await _enable(service);
    await service.saveConfiguration(
        provider: AiProvider.gemini, model: 'model', apiKey: 'key');
    await service.deleteApiKey(AiProvider.gemini);
    expect(await service.usesManagedGemini, isFalse);
    expect(await service.isReady, isFalse);
    await expectLater(service.requireActiveConfiguration(), throwsStateError);
  });

  test(
      'standard Gemini ignores retained personal Gemini key even in developer mode',
      () async {
    final service =
        AiConfigurationService(secretStore: _UnreadableSecretStore());
    await _enable(service);
    expect(await service.usesManagedGemini, isTrue);
    expect(await service.isReady, isTrue);
    expect(await service.activeConfiguration, isNull);
  });

  test('failed key save never activates personal API', () async {
    final service = AiConfigurationService(secretStore: _FailingSecretStore());
    await _enable(service);
    await expectLater(
        service.saveConfiguration(
            provider: AiProvider.openAI, model: 'model', apiKey: 'key'),
        throwsStateError);
    expect(await service.usesManagedGemini, isTrue);
    expect(await service.activeConfiguration, isNull);
  });

  test('failed final preference write rolls back cached personal activation',
      () async {
    final preferences = await SharedPreferences.getInstance();
    final service = AiConfigurationService(
        preferences: _FailingActivationPreferences(preferences),
        secretStore: MemorySecretStore());
    await _enable(service);
    await expectLater(
        service.saveConfiguration(
            provider: AiProvider.gemini, model: 'model', apiKey: 'key'),
        throwsStateError);
    expect(preferences.getBool('ai_configuration_personal_api_v1'), isFalse);
    expect(await service.usesManagedGemini, isTrue);
    expect(await service.activeConfiguration, isNull);
  });

  test('rejects whitespace-only models and API keys', () async {
    final service = AiConfigurationService(
      secretStore: MemorySecretStore(),
    );

    expect(
      service.setModel(AiProvider.openAI, '   '),
      throwsArgumentError,
    );
    expect(
      service.saveApiKey(AiProvider.openAI, '\n\t'),
      throwsArgumentError,
    );
    expect(
      service.saveConfiguration(
        provider: AiProvider.openAI,
        model: 'gpt-test',
        apiKey: ' ',
      ),
      throwsArgumentError,
    );
  });
}
