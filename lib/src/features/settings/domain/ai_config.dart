
enum AIProvider {
  gemini,
  openai,
}

class AIConfig {
  final AIProvider provider;
  final String geminiKey;
  final String openAIKey;
  final String geminiModel;
  final String openAIModel;

  const AIConfig({
    required this.provider,
    required this.geminiKey,
    required this.openAIKey,
    this.geminiModel = 'gemini-1.5-flash',
    this.openAIModel = 'gpt-3.5-turbo',
  });

  factory AIConfig.empty() {
    return const AIConfig(
      provider: AIProvider.gemini,
      geminiKey: '',
      openAIKey: '',
    );
  }

  factory AIConfig.fromMap(Map<String, dynamic> map) {
    return AIConfig(
      provider: AIProvider.values.firstWhere(
        (e) => e.name == (map['provider'] as String?),
        orElse: () => AIProvider.gemini,
      ),
      geminiKey: map['geminiKey'] as String? ?? '',
      openAIKey: map['openAIKey'] as String? ?? '',
      geminiModel: map['geminiModel'] as String? ?? 'gemini-1.5-flash',
      openAIModel: map['openAIModel'] as String? ?? 'gpt-3.5-turbo',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'provider': provider.name,
      'geminiKey': geminiKey,
      'openAIKey': openAIKey,
      'geminiModel': geminiModel,
      'openAIModel': openAIModel,
    };
  }

  AIConfig copyWith({
    AIProvider? provider,
    String? geminiKey,
    String? openAIKey,
    String? geminiModel,
    String? openAIModel,
  }) {
    return AIConfig(
      provider: provider ?? this.provider,
      geminiKey: geminiKey ?? this.geminiKey,
      openAIKey: openAIKey ?? this.openAIKey,
      geminiModel: geminiModel ?? this.geminiModel,
      openAIModel: openAIModel ?? this.openAIModel,
    );
  }
}
