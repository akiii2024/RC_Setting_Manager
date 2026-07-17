import 'package:flutter_test/flutter_test.dart';
import 'package:rc_setting_manager/models/ai_provider.dart';
import 'package:rc_setting_manager/services/ai_configuration_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('provider metadata has stable values and requested default models', () {
    expect(AiProvider.openAI.value, 'openai');
    expect(AiProvider.openAI.displayName, 'OpenAI');
    expect(AiProvider.openAI.defaultModel, 'gpt-5.6-sol');
    expect(AiProvider.anthropic.defaultModel, 'claude-sonnet-5');
    expect(AiProvider.gemini.defaultModel, 'gemini-3.5-flash');
    expect(AiProvider.tryParse(' OpenAI '), AiProvider.openAI);
    expect(AiProvider.tryParse('unknown'), isNull);
  });

  test('defaults to Gemini without exposing an active configuration', () async {
    final service = AiConfigurationService(
      secretStore: MemorySecretStore(),
    );

    expect(await service.selectedProvider, AiProvider.gemini);
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
    await service.saveApiKey(AiProvider.openAI, 'openai-key');
    await service.saveApiKey(AiProvider.anthropic, 'anthropic-key');
    await service.setSelectedProvider(AiProvider.anthropic);

    expect((await service.activeConfiguration)?.apiKey, 'anthropic-key');

    await service.deleteApiKey(AiProvider.anthropic);

    expect(await service.activeConfiguration, isNull);
    expect(await service.getApiKey(AiProvider.openAI), 'openai-key');
    expect(await service.getApiKey(AiProvider.anthropic), isNull);
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
