
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:student_project_management/src/features/projects/data/project_repository.dart';
import 'package:student_project_management/src/features/prompts/domain/prompt.dart';

abstract class PromptRepository {
  Future<String> getPromptTemplate(String promptName);
  Future<void> seedDefaultPrompts();
}

class FirestorePromptRepository implements PromptRepository {
  final FirebaseFirestore _firestore;

  FirestorePromptRepository(this._firestore);

  @override
  Future<String> getPromptTemplate(String promptName) async {
    final snapshot = await _firestore
        .collection('prompts')
        .where('name', isEqualTo: promptName)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.first.data()['template'] as String;
    }
    
    // Fallback if prompt not found in DB
    return _getDefaultPrompt(promptName);
  }

  @override
  Future<void> seedDefaultPrompts() async {
    final prompts = [
      {
        'name': 'extraction',
        'description': 'Extracts structured data from project document text',
        'template': '''
You are an AI assistant helping to extract structured information from student project documents.

Extract the following information from the text below and return it as JSON:
- title: The project title
- studentName: Student's name
- department: Department (e.g., Computer Science)
- objectives: Project objectives or abstract
- year: The academic year (e.g. 2024, 2025)

Document Text:
{{documentText}}

Return ONLY valid JSON in this exact format:
{
  "title": "extracted title",
  "studentName": "extracted name",
  "department": "extracted department",
  "objectives": "extracted objectives",
  "year": "2024"
}
'''
      },
      {
        'name': 'quality_analysis',
        'description': 'Analyzes the quality of a project proposal',
        'template': '''
You are an expert academic advisor reviewing a student project proposal.

Project Title: {{title}}

Objectives:
{{objectives}}

Provide constructive feedback on:
1. Clarity of objectives
2. Feasibility
3. Originality
4. Scope appropriateness

Also generate:
- A list of 3 potential "Achievements" or milestones.
- A list of 3 "Recommendations" for improvement.

Return response as JSON:
{
  "feedback": "constructive feedback text...",
  "achievements": ["achievement 1", "achievement 2", "achievement 3"],
  "recommendations": ["rec 1", "rec 2", "rec 3"]
}
'''
      },
      {
        'name': 'proposal_check',
        'description': 'Checks for duplicate topics and suggests alternatives',
        'template': '''
You are a Research Topic Validator.

Analyzer the new proposed topic:
Title: {{title}}
Objectives: {{objectives}}

Compare with these existing similar projects:
{{existingProjects}}

1. Determine if the new topic is too similar (Duplicate).
2. If Duplicate, suggest 3 alternative directions or refinements.
3. If Novel, suggest 3 ways to expand it.

Return as JSON:
{
  "isDuplicate": true/false,
  "similarityAnalysis": "analysis text...",
  "suggestions": ["suggestion 1", "suggestion 2", "suggestion 3"]
}
'''
      }
    ];

    final batch = _firestore.batch();
    final collection = _firestore.collection('prompts');

    for (var prompt in prompts) {
      final snapshot = await collection.where('name', isEqualTo: prompt['name']).get();
      if (snapshot.docs.isEmpty) {
        final docRef = collection.doc();
        batch.set(docRef, prompt);
      }
    }
    await batch.commit();
  }

  String _getDefaultPrompt(String name) {
    if (name == 'extraction') {
      return '''
Extract title, studentName, department, objectives, year from the text.
Document: {{documentText}}
Return JSON.
''';
    }
    return '';
  }
}

final promptRepositoryProvider = Provider<PromptRepository>((ref) {
  return FirestorePromptRepository(ref.watch(firestoreProvider));
});
