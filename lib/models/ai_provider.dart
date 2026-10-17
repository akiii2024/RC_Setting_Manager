enum AiProvider {
  openAI(
    value: 'openai',
    displayName: 'OpenAI',
    defaultModel: 'gpt-5.6-sol',
  ),
  anthropic(
    value: 'anthropic',
    displayName: 'Anthropic',
    defaultModel: 'claude-sonnet-5',
  ),
  gemini(
    value: 'gemini',
    displayName: 'Gemini',
    defaultModel: 'gemini-3.8-flash',
  );

  const AiProvider({
    required this.value,
    required this.displayName,
    required this.defaultModel,
  });

  /// 永続化やAPIリクエストで使用する安定した識別子。
  final String value;

  final String displayName;

  final String defaultModel;

  static AiProvider? tryParse(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    for (final provider in values) {
      if (provider.value == normalized) {
        return provider;
      }
    }
    return null;
  }
}

enum AiAccessMode { managedGemini, personalApi }

/// APIキーを含まない、永続化可能なAI設定。
class AiProviderSettings {
  const AiProviderSettings({
    required this.provider,
    required this.model,
    this.accessMode = AiAccessMode.managedGemini,
  });

  final AiProvider provider;
  final String model;
  final AiAccessMode accessMode;

  bool get usesManagedGemini => accessMode == AiAccessMode.managedGemini;

  AiProviderSettings copyWith({
    AiProvider? provider,
    String? model,
    AiAccessMode? accessMode,
  }) {
    return AiProviderSettings(
      provider: provider ?? this.provider,
      model: model ?? this.model,
      accessMode: accessMode ?? this.accessMode,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AiProviderSettings &&
        other.provider == provider &&
        other.model == model &&
        other.accessMode == accessMode;
  }

  @override
  int get hashCode => Object.hash(provider, model, accessMode);

  @override
  String toString() {
    return 'AiProviderSettings(provider: ${provider.value}, model: $model, '
        'accessMode: ${accessMode.name})';
  }
}

/// 実際のAPI呼び出しに使用する一時的な設定。
///
/// [apiKey] は安全な資格情報ストアから都度読み出し、このオブジェクト自体を
/// SharedPreferences、Firestore、ログへ保存しないこと。
class AiConfiguration extends AiProviderSettings {
  const AiConfiguration({
    required super.provider,
    required super.model,
    required this.apiKey,
  }) : super(accessMode: AiAccessMode.personalApi);

  final String apiKey;

  @override
  String toString() {
    return 'AiConfiguration(provider: ${provider.value}, model: $model, '
        'apiKey: ***)';
  }
}
