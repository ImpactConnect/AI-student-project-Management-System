
abstract class AIService {
  Future<Map<String, dynamic>> extractProjectDetails(String documentText);
  
  Future<Map<String, dynamic>> analyzeProjectQuality(String title, String objectives);
  
  Future<Map<String, dynamic>> checkProposal(
    String title, 
    String objectives, 
    String existingProjectsText
  );
}
