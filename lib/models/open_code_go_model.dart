enum OpenCodeGoApiFormat { chatCompletions, responses, messages }

enum OpenCodeGoStructuredOutput { jsonSchema, prompt }

/// Goはモデルごとに通信形式が異なるため、確認済みの組み合わせだけを扱う。
/// 正本: https://opencode.ai/v2/docs/console/go/
enum OpenCodeGoModel {
  glm53Flash(
    id: 'glm-5.3-flash',
    displayName: 'GLM-5.3-Flash',
    apiFormat: OpenCodeGoApiFormat.chatCompletions,
  ),
  glm53(
    id: 'glm-5.3',
    displayName: 'GLM-5.3',
    apiFormat: OpenCodeGoApiFormat.chatCompletions,
    supportsImages: false,
  ),
  kimiK3(
    id: 'kimi-k3',
    displayName: 'Kimi K3',
    apiFormat: OpenCodeGoApiFormat.chatCompletions,
  ),
  gpt6Luna(
    id: 'gpt-6-luna',
    displayName: 'GPT-6 Luna',
    apiFormat: OpenCodeGoApiFormat.responses,
  ),
  claudeHaiku55(
    id: 'claude-haiku-5-5',
    displayName: 'Claude Haiku 5.5',
    apiFormat: OpenCodeGoApiFormat.messages,
  ),
  minimaxM3(
    id: 'minimax-m3',
    displayName: 'MiniMax M3',
    apiFormat: OpenCodeGoApiFormat.messages,
    structuredOutput: OpenCodeGoStructuredOutput.prompt,
  );

  const OpenCodeGoModel({
    required this.id,
    required this.displayName,
    required this.apiFormat,
    this.supportsImages = true,
    this.structuredOutput = OpenCodeGoStructuredOutput.jsonSchema,
  });

  final String id;
  final String displayName;
  final OpenCodeGoApiFormat apiFormat;
  final bool supportsImages;
  final OpenCodeGoStructuredOutput structuredOutput;

  static OpenCodeGoModel? tryParse(String id) {
    final normalized = id.trim();
    for (final model in values) {
      if (model.id == normalized) return model;
    }
    return null;
  }

  static const webUnavailableMessage = 'Web版のOpenCode Go対応はCORS制約のため保留中です。'
      'アプリ版を利用するか、AI設定で別のプロバイダーを選択してください。';
}
