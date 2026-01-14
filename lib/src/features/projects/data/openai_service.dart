
import 'dart:convert';
import 'package:dart_openai/dart_openai.dart';
import 'package:student_project_management/src/features/projects/domain/ai_service_interface.dart';
import 'package:student_project_management/src/features/prompts/data/prompt_repository.dart';

class OpenAIService implements AIService {
  final String _modelName;
  final PromptRepository _promptRepo;

  OpenAIService(String apiKey, String modelName, this._promptRepo)
      : _modelName = modelName.isEmpty ? 'gpt-3.5-turbo' : modelName {
    OpenAI.apiKey = apiKey;
  }

  @override
  Future<Map<String, dynamic>> extractProjectDetails(String documentText) async {
    String template = await _promptRepo.getPromptTemplate('extraction');
    final prompt = template.replaceAll('{{documentText}}', documentText);
    return _generate(prompt);
  }

  @override
  Future<Map<String, dynamic>> analyzeProjectQuality(String title, String objectives) async {
    String template = await _promptRepo.getPromptTemplate('quality_analysis');
    final prompt = template
        .replaceAll('{{title}}', title)
        .replaceAll('{{objectives}}', objectives);
    return _generate(prompt);
  }

  @override
  Future<Map<String, dynamic>> checkProposal(
    String title, 
    String objectives, 
    String existingProjectsText
  ) async {
    String template = await _promptRepo.getPromptTemplate('proposal_check');
    final prompt = template
        .replaceAll('{{title}}', title)
        .replaceAll('{{objectives}}', objectives)
        .replaceAll('{{existingProjects}}', existingProjectsText);
    return _generate(prompt);
  }

  Future<Map<String, dynamic>> _generate(String prompt) async {
    try {
      final completion = await OpenAI.instance.chat.create(
        model: _modelName,
        messages: [
          OpenAIChatCompletionChoiceMessageModel(
            content: [OpenAIChatCompletionChoiceMessageContentItemModel.text(prompt)],
            role: OpenAIChatMessageRole.user,
          ),
        ],
      );

      final content = completion.choices.first.message.content?.first.text;
      return _parseJsonFromResponse(content);
    } catch (e) {
      return {'error': 'OpenAI Error: $e'};
    }
  }
  
  Map<String, dynamic> _parseJsonFromResponse(String? text) {
    if (text == null) return {};
    try {
      final cleanText = text.replaceAll('```json', '').replaceAll('```', '').trim();
      return jsonDecode(cleanText) as Map<String, dynamic>;
    } catch (e) {
      return {'error': 'Failed to parse AI response', 'rawText': text};
    }
  }
}
