
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:student_project_management/src/features/projects/data/gemini_ai_service.dart';
import 'package:student_project_management/src/features/projects/data/openai_service.dart';
import 'package:student_project_management/src/features/projects/domain/ai_service_interface.dart';
import 'package:student_project_management/src/features/prompts/data/prompt_repository.dart';
import 'package:student_project_management/src/features/settings/data/ai_settings_repository.dart';
import 'package:student_project_management/src/features/settings/domain/ai_config.dart';

// Export the interface so consumers don't need to change imports
export 'package:student_project_management/src/features/projects/domain/ai_service_interface.dart';

final aiServiceProvider = FutureProvider<AIService>((ref) async {
  print('[DEBUG] aiServiceProvider: Initializing...');
  try {
    print('[DEBUG] aiServiceProvider: Waiting for config (direct fetch)...');
    // Using simple fetch instead of stream to prevent hanging on initial load
    final config = await ref.read(aiSettingsRepositoryProvider).getAIConfig().timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        print('[DEBUG] aiServiceProvider: Config fetch timed out, defaulting to empty');
        return AIConfig.empty();
      },
    );
    print('[DEBUG] aiServiceProvider: Got config: Provider=${config.provider}, HasKeys=${config.openAIKey.isNotEmpty}/${config.geminiKey.isNotEmpty}');
    
    final promptRepo = ref.read(promptRepositoryProvider);
    
    if (config.provider == AIProvider.openai) {
      if (config.openAIKey.isEmpty) {
        print('[DEBUG] aiServiceProvider: OpenAI Key missing');
        throw Exception('OpenAI API Key not configured');
      }
      print('[DEBUG] aiServiceProvider: Returning OpenAIService');
      return OpenAIService(config.openAIKey, config.openAIModel, promptRepo);
    } else {
      print('[DEBUG] aiServiceProvider: Returning GeminiAIService (Key present: ${config.geminiKey.isNotEmpty})');
      return GeminiAIService(config.geminiKey, config.geminiModel, promptRepo);
    }
  } catch (e, st) {
    print('[DEBUG] aiServiceProvider error: $e');
    print(st);
    rethrow;
  }
});
