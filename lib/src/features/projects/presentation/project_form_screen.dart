
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:student_project_management/src/features/auth/data/auth_repository.dart';
import 'package:student_project_management/src/features/projects/data/ai_service.dart';
import 'package:student_project_management/src/features/projects/data/project_repository.dart';
import 'package:student_project_management/src/features/projects/domain/project.dart';
import 'package:student_project_management/src/utils/document_parser.dart';

class ProjectFormScreen extends ConsumerStatefulWidget {
  final Project? project;

  const ProjectFormScreen({super.key, this.project});

  @override
  ConsumerState<ProjectFormScreen> createState() => _ProjectFormScreenState();
}

class _ProjectFormScreenState extends ConsumerState<ProjectFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _studentNameController;
  late TextEditingController _departmentController;
  late TextEditingController _objectivesController;
  late TextEditingController _yearController;
  
  bool _isLoading = false;
  bool _isAnalyzing = false;
  
  String? _uploadedFileUrl;
  String? _selectedFileName;
  Map<String, dynamic>? _extractedData; // Store AI extracted JSON

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.project?.title ?? '');
    _studentNameController = TextEditingController(text: widget.project?.studentName ?? '');
    _departmentController = TextEditingController(text: widget.project?.department ?? '');
    _objectivesController = TextEditingController(text: widget.project?.objectives ?? '');
    _yearController = TextEditingController(text: widget.project?.year ?? DateTime.now().year.toString());
    _uploadedFileUrl = widget.project?.documentUrl;
    _extractedData = widget.project?.extractedData;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _studentNameController.dispose();
    _departmentController.dispose();
    _objectivesController.dispose();
    _yearController.dispose();
    super.dispose();
  }

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

        // 1. Upload to Firebase Storage
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('projects/${DateTime.now().millisecondsSinceEpoch}_${result.files.single.name}');
        
        await storageRef.putFile(file);
        _uploadedFileUrl = await storageRef.getDownloadURL();

        // 2. Extract Text locally (if PDF)
        String extractedText = '';
        if (path.endsWith('.pdf')) {
           extractedText = await DocumentParser.extractTextFromPdf(path);
        } else {
           try { extractedText = await file.readAsString(); } catch (_) {}
        }

        if (extractedText.isNotEmpty && extractedText.length > 50) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Analyzing document with AI...')),
          );

          // 3. AI Extraction
          final aiService = await ref.read(aiServiceProvider.future);
          final aiData = await aiService.extractProjectDetails(extractedText);
          
          if (mounted) {
            setState(() {
              _extractedData = aiData; // Save structured data
              if (aiData.containsKey('title')) _titleController.text = aiData['title'];
              if (aiData.containsKey('studentName')) _studentNameController.text = aiData['studentName'];
              if (aiData.containsKey('department')) _departmentController.text = aiData['department'];
              if (aiData.containsKey('objectives')) _objectivesController.text = aiData['objectives'];
              if (aiData.containsKey('year')) _yearController.text = aiData['year'];
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Auto-filled from document!')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload/Analysis failed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final currentUser = ref.read(authRepositoryProvider).currentUser;
        
        // Ensure manual edits also update the extracted data JSON to keep it in sync
        // or we just keep the initial extraction. 
        // Better to update it so the DB has the latest truth for AI checking.
        final currentData = {
          'title': _titleController.text.trim(),
          'studentName': _studentNameController.text.trim(),
          'department': _departmentController.text.trim(),
          'objectives': _objectivesController.text.trim(),
          'year': _yearController.text.trim(),
          ...(_extractedData ?? {}), // Preserve other fields if any
        };

        final newProject = Project(
          id: widget.project?.id ?? '',
          title: _titleController.text.trim(),
          studentName: _studentNameController.text.trim(),
          department: _departmentController.text.trim(),
          objectives: _objectivesController.text.trim(),
          year: _yearController.text.trim(),
          supervisorId: currentUser?.uid ?? 'unknown',
          status: widget.project?.status ?? ProjectStatus.pending,
          createdAt: widget.project?.createdAt ?? DateTime.now(),
          documentUrl: _uploadedFileUrl,
          extractedData: currentData, // [NEW] Save structured data
        );

        if (widget.project == null) {
          await ref.read(projectRepositoryProvider).addProject(newProject);
        } else {
          await ref.read(projectRepositoryProvider).updateProject(newProject);
        }

        if (mounted) context.pop();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.project == null ? 'New Project' : 'Edit Project')),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   _buildUploadSection(),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                           TextFormField(
                            controller: _titleController,
                            decoration: const InputDecoration(labelText: 'Project Title', border: OutlineInputBorder()),
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _studentNameController,
                                  decoration: const InputDecoration(labelText: 'Student Name', border: OutlineInputBorder()),
                                  validator: (v) => v!.isEmpty ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _yearController,
                                  decoration: const InputDecoration(labelText: 'Year', border: OutlineInputBorder()),
                                  validator: (v) => v!.isEmpty ? 'Required' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _departmentController,
                            decoration: const InputDecoration(labelText: 'Department', border: OutlineInputBorder()),
                            validator: (v) => v!.isEmpty ? 'Required' : null,
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
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: FilledButton.icon(
                              onPressed: _isLoading ? null : _save,
                              icon: const Icon(Icons.save),
                              label: _isLoading ? const Text('Saving...') : const Text('Save Project'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadSection() {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(Icons.cloud_upload_outlined, size: 48),
            const SizedBox(height: 16),
            const Text('Auto-fill from Document', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Upload a PDF/Word file to automatically extract project details.', textAlign: TextAlign.center),
             if (_selectedFileName != null) ...[
                const SizedBox(height: 16),
                Chip(
                  avatar: const Icon(Icons.check_circle, size: 16),
                  label: Text('Selected: $_selectedFileName'),
                ),
             ],
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: _isAnalyzing ? null : _pickAndUploadDocument,
              child: _isAnalyzing 
                ? const Row(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(width:16,height:16, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 8),
                    Text('Analyzing...'),
                  ])
                : const Text('Upload PDF/Doc'),
            ),
          ],
        ),
      ),
    );
  }
}
