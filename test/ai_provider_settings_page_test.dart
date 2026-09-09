import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rc_setting_manager/models/ai_provider.dart';
import 'package:rc_setting_manager/pages/ai_provider_settings_page.dart';
import 'package:rc_setting_manager/services/ai_configuration_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('saves a provider model and API key outside preferences',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final secrets = MemorySecretStore();
    final service = AiConfigurationService(
      preferences: preferences,
      secretStore: secrets,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AiProviderSettingsPage(
          configurationService: service,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('OpenAI'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), 'sk-test-secret');
    await tester.tap(find.text('保存して使用'));
    await tester.pumpAndSettle();

    final configuration = await service.requireActiveConfiguration();
    expect(configuration.provider, AiProvider.openAI);
    expect(configuration.model, 'gpt-5.6-sol');
    expect(configuration.apiKey, 'sk-test-secret');
    expect(preferences.getKeys().join(','), isNot(contains('sk-test-secret')));
    expect(find.text('sk-test-secret'), findsNothing);
  });

  testWidgets('connection test uses form values without saving them',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final service = AiConfigurationService(
      preferences: preferences,
      secretStore: MemorySecretStore(),
    );
    AiConfiguration? testedConfiguration;

    await tester.pumpWidget(
      MaterialApp(
        home: AiProviderSettingsPage(
          configurationService: service,
          connectionTester: (configuration) async {
            testedConfiguration = configuration;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('Anthropic'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), 'anthropic-test-key');
    await tester.tap(find.text('接続テスト'));
    await tester.pumpAndSettle();

    expect(testedConfiguration?.provider, AiProvider.anthropic);
    expect(testedConfiguration?.model, 'claude-sonnet-5');
    expect(testedConfiguration?.apiKey, 'anthropic-test-key');
    expect(await service.activeConfiguration, isNull);
    expect(find.text('Anthropicへの接続を確認しました。'), findsOneWidget);
  });

  testWidgets('can switch back to standard Gemini without an API key',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = AiConfigurationService(secretStore: MemorySecretStore());
    await service.setSelectedProvider(AiProvider.openAI);
    await tester.pumpWidget(MaterialApp(
      home: AiProviderSettingsPage(configurationService: service),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gemini'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('保存して使用'));
    await tester.pumpAndSettle();
    expect(await service.selectedProvider, AiProvider.gemini);
    expect(await service.isReady, isTrue);
  });
}
