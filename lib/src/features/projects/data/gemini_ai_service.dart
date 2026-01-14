
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart' as ai;
import 'package:student_project_management/src/features/projects/domain/ai_service_interface.dart';
import 'package:student_project_management/src/features/prompts/data/prompt_repository.dart';

class GeminiAIService implements AIService {
  final ai.GenerativeModel _model;
  final PromptRepository _promptRepo;

  GeminiAIService(String apiKey, String modelName, this._promptRepo)
      : _model = ai.GenerativeModel(
          model: modelName.isEmpty ? 'gemini-1.5-flash' : modelName,
          apiKey: apiKey,
        );

  @override
  Future<Map<String, dynamic>> extractProjectDetails(String documentText) async {
    String template = await _promptRepo.getPromptTemplate('extraction');
    final prompt = template.replaceAll('{{documentText}}', documentText);
    final content = [ai.Content.text(prompt)];
    final response = await _model.generateContent(content);
    return _parseJsonFromResponse(response.text);
  }

  @override
  Future<Map<String, dynamic>> analyzeProjectQuality(String title, String objectives) async {
    String template = await _promptRepo.getPromptTemplate('quality_analysis');
    final prompt = template
        .replaceAll('{{title}}', title)
        .replaceAll('{{objectives}}', objectives);
    final content = [ai.Content.text(prompt)];
    final response = await _model.generateContent(content);
    return _parseJsonFromResponse(response.text);
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
    final content = [ai.Content.text(prompt)];
    final response = await _model.generateContent(content);
    return _parseJsonFromResponse(response.text);
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
