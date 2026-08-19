import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rc_setting_manager/models/ai_advisor.dart';
import 'package:rc_setting_manager/models/car.dart';
import 'package:rc_setting_manager/models/car_setting_definition.dart';
import 'package:rc_setting_manager/models/manufacturer.dart';
import 'package:rc_setting_manager/models/saved_setting.dart';
import 'package:rc_setting_manager/pages/ai_setting_advisor_page.dart';
import 'package:rc_setting_manager/providers/app_mode_provider.dart';
import 'package:rc_setting_manager/providers/settings_provider.dart';
import 'package:rc_setting_manager/services/ai_advisor_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAdvisorService extends AIAdvisorService {
  @override
  Future<AdvisorChatTurn> continueStructuredConversation({
    required AIAdvisorContext context,
    required AIAdvisorIntake intake,
    required List<AdvisorMessage> messages,
    required bool isEnglish,
    required bool includeHistory,
  }) async {
    return const AdvisorChatTurn(
      message: '進入時の症状を確認しました。提案を生成できます。',
      readyForAdvice: true,
    );
  }

  @override
  Future<AISettingAdvice> generateStructuredAdvice({
    required AIAdvisorContext context,
    required AIAdvisorIntake intake,
    required List<AdvisorMessage> messages,
    required bool isEnglish,
    required bool includeHistory,
  }) async {
    return const AISettingAdvice(
      summary: '進入時の旋回不足を一項目ずつ確認します。',
      confidence: 'medium',
      evidence: ['コーナー進入で曲がらない'],
      changes: [
        AdvisorSettingChange(
          settingKey: 'frontCamber',
          settingLabel: 'フロント キャンバー',
          currentValue: '-1.0',
          proposedValue: '-1.5',
          reason: 'フロントの接地変化を比較します。',
          expectedEffect: '進入時の旋回特性を確認できます。',
          tradeoff: '直進時の摩耗を確認してください。',
          priority: 1,
        ),
      ],
      manualTips: [],
      testPlan: '同じタイヤで5周ずつ比較します。',
      drivingTips: '操作量を揃えて比較します。',
    );
  }
}

Future<void> _pumpUntilInitialized(
  WidgetTester tester,
  SettingsProvider provider,
) async {
  for (var index = 0; index < 50 && !provider.isInitialized; index += 1) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'language_settings': false,
    });
  });

  testWidgets('creates a linked AI-derived setting from validated advice',
      (tester) async {
    final provider = SettingsProvider(
      appModeProvider: AppModeProvider(
        preferredOnline: false,
        isFirebaseReady: false,
      ),
    );
    final car = Car(
      id: 'car-1',
      name: 'Test car',
      imageUrl: '',
      manufacturer: Manufacturer(
        id: 'test',
        name: 'Test',
        logoPath: '',
      ),
      category: 'touring',
    );
    final definition = CarSettingDefinition(
      carId: car.id,
      availableSettings: [
        SettingItem(
          key: 'frontCamber',
          type: 'number',
          constraints: const {'min': -5, 'max': 5, 'step': 0.5},
          unit: '°',
          category: 'front',
          label: 'フロント キャンバー',
          defaultValue: '-1',
        ),
      ],
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          home: AISettingAdvisorPage(
            car: car,
            currentSettings: const {'frontCamber': -1.0},
            initialSettings: const {'frontCamber': -1.0},
            settingDefinition: definition,
            settingName: 'Base setup',
            isEnglish: false,
            advisorService: _FakeAdvisorService(),
          ),
        ),
      ),
    );
    await _pumpUntilInitialized(tester, provider);
    await tester.pumpAndSettle();

    await tester.tap(find.text('曲がらない'));
    await tester.tap(find.text('コーナー進入'));
    final startButton = find.text('相談を開始');
    await tester.scrollUntilVisible(
      startButton,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.drag(
      find.byType(Scrollable).last,
      const Offset(0, -100),
    );
    await tester.pumpAndSettle();
    await tester.tap(startButton);
    await tester.pumpAndSettle();

    expect(find.text('進入時の症状を確認しました。提案を生成できます。'), findsOneWidget);
    await tester.tap(find.text('セッティング提案を生成'));
    await tester.pumpAndSettle();

    expect(find.text('診断'), findsOneWidget);
    expect(find.textContaining('フロント キャンバー:'), findsOneWidget);

    final createButton = find.text('派生セットを作成');
    await tester.scrollUntilVisible(
      createButton,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(createButton);
    await tester.pumpAndSettle();

    expect(provider.savedSettings, hasLength(2));
    final derived = provider.savedSettings.first;
    final base = provider.savedSettings.last;
    expect(derived.kind, SavedSettingKind.aiSuggestion);
    expect(derived.parentSettingId, base.id);
    expect(derived.settings['frontCamber'], -1.5);
    expect(base.settings['frontCamber'], -1.0);
  });
}
