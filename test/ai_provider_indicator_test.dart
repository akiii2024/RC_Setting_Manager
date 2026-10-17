import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rc_setting_manager/models/ai_provider.dart';
import 'package:rc_setting_manager/services/ai_configuration_service.dart';
import 'package:rc_setting_manager/widgets/ai_provider_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
      'indicator refreshes when another service disables personal Gemini',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = AiConfigurationService(secretStore: MemorySecretStore());
    await service.unlockDeveloperMode();
    await service.setDeveloperModeEnabled(true);
    await service.saveConfiguration(
        provider: AiProvider.gemini,
        model: 'personal-model',
        apiKey: 'test-key');
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AiProviderIndicator(configurationService: service))));
    await tester.pumpAndSettle();
    expect(find.textContaining('個人APIキー'), findsOneWidget);
    await AiConfigurationService().setDeveloperModeEnabled(false);
    await tester.pumpAndSettle();
    expect(find.text('標準Gemini'), findsOneWidget);
    expect(find.textContaining('個人APIキー'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
