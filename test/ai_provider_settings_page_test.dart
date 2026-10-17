import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rc_setting_manager/app/app_theme.dart';
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
    await service.unlockDeveloperMode();
    await service.setDeveloperModeEnabled(true);

    await tester.pumpWidget(
      MaterialApp(
        home: AiProviderSettingsPage(
          configurationService: service,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('自分のAPIキー'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OpenAI'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), 'sk-test-secret');
    await tester.tap(find.text('保存して使用'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('同意して保存する'));
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
    await service.unlockDeveloperMode();
    await service.setDeveloperModeEnabled(true);
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
    await tester.tap(find.text('自分のAPIキー'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anthropic'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), 'anthropic-test-key');
    await _scrollTo(tester, find.text('接続テスト'));
    await tester.tap(find.text('接続テスト'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('同意して接続する'));
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
    await service.unlockDeveloperMode();
    await service.setDeveloperModeEnabled(true);
    await service.saveConfiguration(
      provider: AiProvider.openAI,
      model: AiProvider.openAI.defaultModel,
      apiKey: 'existing-key',
    );
    await tester.pumpWidget(MaterialApp(
      home: AiProviderSettingsPage(configurationService: service),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('標準Gemini'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    await _scrollTo(tester, find.text('保存して使用'));
    await tester.tap(find.text('保存して使用'));
    await tester.pumpAndSettle();
    expect(await service.selectedProvider, AiProvider.gemini);
    expect(await service.isReady, isTrue);
  });

  testWidgets('developer mode off hides personal API controls', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = AiConfigurationService(secretStore: MemorySecretStore());
    await tester.pumpWidget(MaterialApp(
      home: AiProviderSettingsPage(configurationService: service),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining('開発者モードがオフ'), findsOneWidget);
    expect(find.text('接続テスト'), findsNothing);
  });

  testWidgets('cancelling save warning leaves selection and key unchanged',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = AiConfigurationService(secretStore: MemorySecretStore());
    await service.unlockDeveloperMode();
    await service.setDeveloperModeEnabled(true);
    await tester.pumpWidget(MaterialApp(
      home: AiProviderSettingsPage(configurationService: service),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('自分のAPIキー'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OpenAI'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), 'cancelled-key');
    await tester.tap(find.text('保存して使用'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(await service.activeConfiguration, isNull);
    expect((await service.activeSettings).usesManagedGemini, isTrue);
  });

  testWidgets('changing an existing key requires confirmation again',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = AiConfigurationService(secretStore: MemorySecretStore());
    await service.unlockDeveloperMode();
    await service.setDeveloperModeEnabled(true);
    await service.saveConfiguration(
      provider: AiProvider.openAI,
      model: AiProvider.openAI.defaultModel,
      apiKey: 'old-key',
    );
    await tester.pumpWidget(MaterialApp(
      home: AiProviderSettingsPage(configurationService: service),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), 'new-key');
    await _scrollTo(tester, find.text('保存して使用'));
    await tester.tap(find.text('保存して使用'));
    await tester.pumpAndSettle();
    expect(find.text('同意して保存する'), findsOneWidget);
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(await service.getApiKey(AiProvider.openAI), 'old-key');
  });

  testWidgets('connection warning cancellation does not call tester',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = AiConfigurationService(secretStore: MemorySecretStore());
    await service.unlockDeveloperMode();
    await service.setDeveloperModeEnabled(true);
    var called = false;
    await tester.pumpWidget(MaterialApp(
      home: AiProviderSettingsPage(
        configurationService: service,
        connectionTester: (_) async => called = true,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('自分のAPIキー'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), 'test-key');
    await _scrollTo(tester, find.text('接続テスト'));
    await tester.tap(find.text('接続テスト'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(called, isFalse);
    expect(await service.activeConfiguration, isNull);
  });

  testWidgets('Gemini personal key can be saved then standard mode restored',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = AiConfigurationService(secretStore: MemorySecretStore());
    await service.unlockDeveloperMode();
    await service.setDeveloperModeEnabled(true);
    await tester.pumpWidget(MaterialApp(
      home: AiProviderSettingsPage(configurationService: service),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('自分のAPIキー'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gemini'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), 'gemini-key');
    await tester.tap(find.text('保存して使用'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('同意して保存する'));
    await tester.pumpAndSettle();
    expect((await service.activeSettings).usesManagedGemini, isFalse);
    await tester.tap(find.text('標準Gemini'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存して使用'));
    await tester.pumpAndSettle();
    expect((await service.activeSettings).usesManagedGemini, isTrue);
    expect(await service.getApiKey(AiProvider.gemini), 'gemini-key');
  });

  testWidgets('save failure reports an error and does not activate the key',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = AiConfigurationService(secretStore: ThrowingSecretStore());
    await service.unlockDeveloperMode();
    await service.setDeveloperModeEnabled(true);
    await tester.pumpWidget(MaterialApp(
      home: AiProviderSettingsPage(configurationService: service),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('自分のAPIキー'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), 'failing-key');
    await tester.tap(find.text('保存して使用'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('同意して保存する'));
    await tester.pumpAndSettle();
    expect(find.text('AI設定を更新できませんでした。開発者モードとAPIキーを確認し、再試行してください。'),
        findsOneWidget);
    expect(await service.activeConfiguration, isNull);
    expect(find.text('保存して使用'), findsOneWidget);
  });

  for (final isEnglish in [false, true]) {
    for (final isDark in [false, true]) {
      testWidgets(
          'personal form and warning at 360px and 2x text: english=$isEnglish dark=$isDark',
          (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        SharedPreferences.setMockInitialValues({});
        final service =
            AiConfigurationService(secretStore: MemorySecretStore());
        await service.unlockDeveloperMode();
        await service.setDeveloperModeEnabled(true);
        await tester.pumpWidget(MaterialApp(
          theme: isDark ? AppTheme.dark() : AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: AiProviderSettingsPage(
              configurationService: service, isEnglish: isEnglish),
        ));
        await tester.pumpAndSettle();
        final personal = find.text(isEnglish ? 'My API key' : '自分のAPIキー');
        await _scrollTo(tester, personal);
        await tester.tap(personal);
        await tester.pumpAndSettle();
        final apiField = find.byWidgetPredicate((widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Gemini API key');
        await _scrollTo(tester, apiField);
        await tester.enterText(apiField, 'test-key');
        final save = find.text(isEnglish ? 'Save and use' : '保存して使用');
        await _scrollTo(tester, save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(find.text(isEnglish ? 'Agree and save' : '同意して保存する'),
            findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text(isEnglish ? 'Cancel' : 'キャンセル'));
        await tester.pumpAndSettle();
        expect(await service.activeConfiguration, isNull);
      });
    }
  }
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find.byType(Scrollable).first,
    );
  } else {
    await tester.ensureVisible(finder);
  }
  await tester.pumpAndSettle();
}

class ThrowingSecretStore extends MemorySecretStore {
  @override
  Future<void> write(String key, String value) {
    throw StateError('保存に失敗しました');
  }
}
