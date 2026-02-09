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
''',
      },
      {
        'name': 'quality_analysis',
        'description': 'Analyzes a completed project and extracts key insights',
        'template': '''
You are an expert academic reviewer analyzing a completed student thesis/project.

Project Title: {{title}}

Objectives/Abstract:
{{objectives}}

Based on the information provided, extract and summarize the following sections. 
CRITICAL: If a section is NOT found in the text, explicitly state "Not available in the provided document". Do NOT invent information.

1. **Problem Statement**: What specific problem or gap is being solved?
2. **Objectives**: The main goals.
3. **Methodology**: specific algorithms, tools (e.g., Flutter, Python), or research methods used.
4. **Implementation**: How was the system built? (Architecture, key modules).
5. **Results/Outcomes**: What was achieved? (Accuracy metrics, user feedback, successful deployment).
6. **Areas for Improvement**: Weaknesses or limitations mentioned.
7. **Recommendations**: Future work.

Return response as JSON in this exact format:
{
  "problemStatement": "Summary of problem...",
  "objectives": ["Obj 1", "Obj 2"],
  "methodology": "Methodology summary...",
  "implementation": "Implementation details...",
  "results": "Results summary...",
  "areasForImprovement": ["Weakness 1", "Weakness 2"],
  "recommendations": ["Rec 1", "Rec 2"]
}
''',
      },
      {
        'name': 'proposal_check',
        'description':
            'Checks for duplicate topics with detailed matching analysis',
        'template': '''
You are a Research Topic Validator.

Analyze the new proposed topic:
Title: {{title}}
Objectives: {{objectives}}

Compare with these existing projects:
{{existingProjects}}

Provide a detailed analysis:
1. Calculate overall matching percentage (0-100%). IMPORTANT: If any existing project has a similarity > 50%, the Overall Matching Percentage MUST be at least that high. Do not output 0% if there are matches.
2. List ALL projects that have >20% similarity.
3. Describe the similarities.
4. Provide recommendations.
5. Suggest 3 alternative distinct project titles based on the user's idea but with a different angle.

Return as JSON in this EXACT format:
{
  "isDuplicate": true/false,
  "matchingPercentage": 75,
  "matchedProjects": [
    {
      "id": "project_id",
      "title": "Project Title",
      "studentName": "Student Name",
      "year": "2024",
      "department": "Computer Science",
      "similarity": 85
    }
  ],
  "similarityAnalysis": "Detailed analysis...",
  "recommendations": "Specific recommendations...",
  "suggestions": ["General suggestion 1", "General suggestion 2"],
  "alternativeTitles": ["Alternative Title 1", "Alternative Title 2", "Alternative Title 3"]
}
''',
      },
    ];

    final batch = _firestore.batch();
    final collection = _firestore.collection('prompts');

    for (var prompt in prompts) {
      final snapshot = await collection
          .where('name', isEqualTo: prompt['name'])
          .get();
      if (snapshot.docs.isEmpty) {
        final docRef = collection.doc();
        batch.set(docRef, prompt);
      } else {
        // Force update for development/refinement
        final docRef = snapshot.docs.first.reference;
        batch.update(docRef, {
          'template': prompt['template'],
          'description': prompt['description'],
        });
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
