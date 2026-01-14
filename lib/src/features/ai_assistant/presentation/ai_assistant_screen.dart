
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:student_project_management/src/features/projects/data/ai_service.dart';
import 'package:student_project_management/src/features/projects/data/project_repository.dart';
import 'package:student_project_management/src/utils/document_parser.dart';

class AIAssistantScreen extends ConsumerStatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  ConsumerState<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends ConsumerState<AIAssistantScreen> {
  final _titleController = TextEditingController();
  final _objectivesController = TextEditingController();
  bool _isChecking = false;
  bool _isAnalyzing = false;
  String? _selectedFileName;
  Map<String, dynamic>? _analysisResult;

  Future<void> _pickAndUploadDocument() async {
    setState(() => _isAnalyzing = true);
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
      );

      if (result != null) {
        final path = result.files.single.path!;
        final file = File(path);
        _selectedFileName = result.files.single.name;
        setState(() {});

        // Extract Text locally (if PDF)
        String extractedText = '';
        if (path.endsWith('.pdf')) {
           extractedText = await DocumentParser.extractTextFromPdf(path);
        } else {
           try { extractedText = await file.readAsString(); } catch (_) {}
        }

        if (extractedText.isNotEmpty && extractedText.length > 50) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Analyzing document...')),
          );

          // AI Extraction to auto-fill title/objectives
          final aiService = await ref.read(aiServiceProvider.future);
          final aiData = await aiService.extractProjectDetails(extractedText);
          
          if (mounted) {
             setState(() {
               if (aiData.containsKey('title')) _titleController.text = aiData['title'];
               if (aiData.containsKey('objectives')) _objectivesController.text = aiData['objectives'];
             });
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text('Auto-filled from document!')),
             );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Analysis failed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  Future<void> _checkProposal() async {
    if (_titleController.text.isEmpty || _objectivesController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter Title and Objectives')));
      return;
    }

    setState(() {
      _isChecking = true;
      _analysisResult = null;
    });

    try {
      // 1. Fetch ALL projects from Firestore to compare against
      final projects = await ref.read(projectRepositoryProvider).getProjects();
      
      // 2. Prepare context for AI 
      final projectsSummary = projects.map((p) {
        return "- Title: ${p.title}\n  Objectives: ${p.objectives}\n";
      }).join("\n");

      // 3. Call AI Service
      final aiService = await ref.read(aiServiceProvider.future);
      final result = await aiService.checkProposal(
        _titleController.text,
        _objectivesController.text,
        projectsSummary.substring(0, projectsSummary.length > 20000 ? 20000 : projectsSummary.length), 
      );

      setState(() => _analysisResult = result);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Research Assistant')),
      body: Row(
        children: [
          // Left Panel: Input
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: Theme.of(context).dividerColor)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Verify New Proposal', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    const Text('Enter a topic manually or upload a proposal to check for duplicates.'),
                    const SizedBox(height: 24),
                    
                    // Upload Section
                    Card(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            const Icon(Icons.cloud_upload_outlined, size: 32),
                            const SizedBox(height: 8),
                            const Text('Auto-fill from Proposal Document'),
                             if (_selectedFileName != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text('Selected: $_selectedFileName', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                            const SizedBox(height: 12),
                            FilledButton.tonal(
                              onPressed: _isAnalyzing ? null : _pickAndUploadDocument,
                              child: _isAnalyzing ? const Text('Analyzing...') : const Text('Upload PDF/Doc'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: 'Topic / Title', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _objectivesController,
                      decoration: const InputDecoration(
                        labelText: 'Objectives / Abstract', 
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 8,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _isChecking ? null : _checkProposal,
                      icon: _isChecking 
                        ? const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2))
                        : const Icon(Icons.psychology),
                      label: const Text('Analyze & Check Duplicates'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Right Panel: Results
          Expanded(
            flex: 1,
            child: _analysisResult == null 
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome_mosaic, size: 64, color: Theme.of(context).disabledColor),
                      const SizedBox(height: 16),
                      Text('AI Analysis Results will appear here', style: TextStyle(color: Theme.of(context).disabledColor)),
                    ],
                  ),
                )
              : _buildAnalysisView(),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisView() {
    final data = _analysisResult!;
    final isDuplicate = data['isDuplicate'] == true;
    final analysisText = data['similarityAnalysis'] ?? 'No analysis text.';
    final suggestions = (data['suggestions'] as List<dynamic>?)?.cast<String>() ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDuplicate ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDuplicate ? Colors.red : Colors.green, width: 2),
              ),
              child: Row(
                children: [
                  Icon(isDuplicate ? Icons.warning_amber : Icons.check_circle_outline, 
                       color: isDuplicate ? Colors.red : Colors.green, size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         Text(
                          isDuplicate ? 'Duplicate / High Similarity Detected' : 'Topic Appears Original',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: isDuplicate ? Colors.red : Colors.green,
                            fontWeight: FontWeight.bold
                          ),
                        ),
                        if (isDuplicate)
                           const Text('Significantly overlaps with existing projects.'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text('Analysis Report', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(analysisText, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 32),
            Text('AI Suggestions', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            ...suggestions.map((s) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const Icon(Icons.lightbulb_outline),
                title: Text(s),
              ),
            )),
        ],
      ),
    );
  }
}
