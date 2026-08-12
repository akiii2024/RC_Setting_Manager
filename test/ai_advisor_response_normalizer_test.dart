import 'package:flutter_test/flutter_test.dart';
import 'package:rc_setting_manager/models/ai_advisor.dart';
import 'package:rc_setting_manager/services/ai_advisor_response_normalizer.dart';

void main() {
  const context = AIAdvisorContext(
    vehicle: {'name': 'Test car'},
    settingName: 'Base',
    definitionVerified: true,
    settings: [
      {'key': 'frontCamber', 'value': -1.0},
      {'key': 'rearCamber', 'value': -2.0},
    ],
    settingCatalog: [
      {
        'key': 'frontCamber',
        'label': 'Front camber',
        'autoApplicable': true,
        'min': -5,
        'max': 5,
        'step': 0.5,
      },
      {
        'key': 'rearCamber',
        'label': 'Rear camber',
        'autoApplicable': true,
        'min': -5,
        'max': 5,
        'step': 0.5,
      },
    ],
  );

  test('チャット応答をトリムし、最大件数までに制限する', () {
    final normalized = AiAdvisorResponseNormalizer.normalizeChatResponse({
      'message': '  追加で路面状態を教えてください。  ',
      'readyForAdvice': true,
      'missingTopics': ['路面', 'タイヤ', '気温', '無視される項目'],
    });

    expect(normalized, {
      'message': '追加で路面状態を教えてください。',
      'readyForAdvice': true,
      'missingTopics': ['路面', 'タイヤ', '気温'],
    });
  });

  test('必須のチャット応答が不正なら従来のStateErrorを返す', () {
    expect(
      () => AiAdvisorResponseNormalizer.normalizeChatResponse({
        'message': '   ',
        'readyForAdvice': false,
        'missingTopics': <String>[],
      }),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'AI応答のmessageが不正です。',
        ),
      ),
    );
  });

  test('最終応答から安全な1ステップ変更だけを優先度順で残す', () {
    final normalized = AiAdvisorResponseNormalizer.normalizeFinalResponse(
      {
        'summary': '  小さな変更を比較します。  ',
        'confidence': 'unknown',
        'evidence': ['e1', 'e2', 'e3', 'e4', 'e5', 'e6'],
        'missingInformation': <String>[],
        'changes': [
          {
            'settingKey': 'rearCamber',
            'settingLabel': 'モデル側ラベル',
            'currentValue': '無視される値',
            'proposedValue': '-2.5',
            'reason': 'Rear reason',
            'expectedEffect': 'Rear effect',
            'tradeoff': '',
            'priority': 2,
          },
          {
            'settingKey': 'frontCamber',
            'settingLabel': 'モデル側ラベル',
            'currentValue': '無視される値',
            'proposedValue': '-1,5',
            'reason': 'Front reason',
            'expectedEffect': 'Front effect',
            'tradeoff': 'Front tradeoff',
            'priority': 1,
          },
          {
            'settingKey': 'frontCamber',
            'settingLabel': 'Front camber',
            'currentValue': '-1.0',
            'proposedValue': '-3.0',
            'reason': 'Unsafe jump',
            'expectedEffect': 'Unknown',
            'tradeoff': '',
            'priority': 3,
          },
        ],
        'manualTips': ['tip'],
        'testPlan': '  5周ずつ比較する。  ',
        'drivingTips': '',
      },
      context,
    );

    expect(normalized['summary'], '小さな変更を比較します。');
    expect(normalized['confidence'], 'low');
    expect(normalized['evidence'], ['e1', 'e2', 'e3', 'e4', 'e5']);
    expect(normalized['testPlan'], '5周ずつ比較する。');
    final changes = normalized['changes'] as List<Map<String, dynamic>>;
    expect(changes, hasLength(2));
    expect(changes.map((change) => change['settingKey']), [
      'frontCamber',
      'rearCamber',
    ]);
    expect(changes.first['settingLabel'], 'Front camber');
    expect(changes.first['currentValue'], '-1.0');
    expect(changes.first['proposedValue'], '-1.5');
  });
}
