
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
  final config = await ref.watch(aiConfigStreamProvider.future);
  final promptRepo = ref.read(promptRepositoryProvider);
  
  if (config.provider == AIProvider.openai) {
    if (config.openAIKey.isEmpty) {
      throw Exception('OpenAI API Key not configured');
    }
    return OpenAIService(config.openAIKey, config.openAIModel, promptRepo);
  } else {
    // Default to Gemini
    // Allow empty key for now if they haven't set it, but it will fail on call
    return GeminiAIService(config.geminiKey, config.geminiModel, promptRepo);
  }
});
