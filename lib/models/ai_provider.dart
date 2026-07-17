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
    defaultModel: 'gemini-3.5-flash',
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

/// APIキーを含まない、永続化可能なAI設定。
class AiProviderSettings {
  const AiProviderSettings({
    required this.provider,
    required this.model,
  });

  final AiProvider provider;
  final String model;

  AiProviderSettings copyWith({
    AiProvider? provider,
    String? model,
  }) {
    return AiProviderSettings(
      provider: provider ?? this.provider,
      model: model ?? this.model,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AiProviderSettings &&
        other.provider == provider &&
        other.model == model;
  }

  @override
  int get hashCode => Object.hash(provider, model);

  @override
  String toString() {
    return 'AiProviderSettings(provider: ${provider.value}, model: $model)';
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
  });

  final String apiKey;

  @override
  String toString() {
    return 'AiConfiguration(provider: ${provider.value}, model: $model, '
        'apiKey: ***)';
  }
}
