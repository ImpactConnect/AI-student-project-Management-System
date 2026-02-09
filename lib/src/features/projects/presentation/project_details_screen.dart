import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:student_project_management/src/features/projects/data/ai_service.dart';
import 'package:student_project_management/src/features/projects/data/project_repository.dart';
import 'package:student_project_management/src/features/projects/domain/project.dart';
import 'package:student_project_management/src/features/projects/presentation/project_form_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class ProjectDetailsScreen extends ConsumerStatefulWidget {
  final String projectId;
  const ProjectDetailsScreen({super.key, required this.projectId});

  @override
  ConsumerState<ProjectDetailsScreen> createState() =>
      _ProjectDetailsScreenState();
}

class _ProjectDetailsScreenState extends ConsumerState<ProjectDetailsScreen> {
  bool _isGeneratingAnalysis = false;

  Future<void> _generateAIAnalysis(Project project) async {
    setState(() => _isGeneratingAnalysis = true);
    print('Starting AI Analysis generation...');

    try {
      print('Getting AI service...');
      final aiService = await ref.read(aiServiceProvider.future);
      print('Calling analyzeProjectQuality...');

      final analysis = await aiService.analyzeProjectQuality(
        project.title,
        project.objectives,
      );
      print('AI Analysis result: $analysis');

      // Check for errors
      if (analysis.containsKey('error')) {
        throw Exception(analysis['error']);
      }

      // Use copyWith to update only the aiAnalysis field
      final updatedProject = project.copyWith(aiAnalysis: analysis);
      await ref.read(projectRepositoryProvider).updateProject(updatedProject);

      // Force UI refresh by invalidating the provider
      ref.invalidate(projectProvider(project.id));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI Analysis generated and saved!')),
        );
      }
    } catch (e) {
      print('AI Analysis error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      print('Resetting analysis state');
      if (mounted) setState(() => _isGeneratingAnalysis = false);
    }
  }

  Future<void> _deleteProject(Project project) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Project?'),
        content: Text(
          'Are you sure you want to delete "${project.title}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(projectRepositoryProvider).deleteProject(project.id);
      if (mounted) context.go('/projects');
    }
  }

  void _viewDocumentInApp(String? url) {
    if (url == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: const Text('Document Viewer'),
            actions: [
              IconButton(
                icon: const Icon(Icons.open_in_new),
                tooltip: 'Open in Browser',
                onPressed: () => _openInBrowser(url),
              ),
              IconButton(
                icon: const Icon(Icons.download),
                tooltip: 'Download',
                onPressed: () => _openInBrowser(url),
              ),
            ],
          ),
          body: SfPdfViewer.network(url),
        ),
      ),
    );
  }

  Future<void> _openInBrowser(String? url) async {
    if (url == null) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open document')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectAsync = ref.watch(projectProvider(widget.projectId));
    final dateFormat = DateFormat('dd MMM, yyyy');

    return Scaffold(
      appBar: AppBar(title: const Text('Project Details')),
      body: projectAsync.when(
        data: (project) {
          if (project == null)
            return const Center(child: Text('Project not found'));
          return SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center, // CENTRALIZED
                  children: [
                    // ===== TITLE SECTION (CENTERED) =====
                    Text(
                      project.title,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // ===== INFO CHIPS (CENTERED) =====
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 16,
                      runSpacing: 12,
                      children: [
                        _buildInfoChip(
                          Icons.person,
                          'Student',
                          project.studentName,
                        ),
                        _buildInfoChip(
                          Icons.school,
                          'Department',
                          project.department,
                        ),
                        _buildInfoChip(
                          Icons.calendar_today,
                          'Year',
                          project.year,
                        ),
                        _buildInfoChip(
                          Icons.upload_file,
                          'Uploaded',
                          project.dateUploaded != null
                              ? dateFormat.format(project.dateUploaded!)
                              : dateFormat.format(project.createdAt),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // ===== ACTION BUTTONS (CENTERED) =====
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        if (project.documentUrl != null) ...[
                          FilledButton.icon(
                            onPressed: () =>
                                _viewDocumentInApp(project.documentUrl),
                            icon: const Icon(Icons.visibility),
                            label: const Text('View Document'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () =>
                                _openInBrowser(project.documentUrl),
                            icon: const Icon(Icons.download),
                            label: const Text('Download'),
                          ),
                        ],
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ProjectFormScreen(project: project),
                              ),
                            );
                          },
                          icon: const Icon(Icons.edit),
                          label: const Text('Edit'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _deleteProject(project),
                          icon: const Icon(Icons.delete, color: Colors.red),
                          label: const Text(
                            'Delete',
                            style: TextStyle(color: Colors.red),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 24),

                    // ===== OBJECTIVES SECTION =====
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Objectives / Abstract',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              project.objectives,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ===== AI ANALYSIS SECTION =====
                    Card(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.auto_awesome),
                                    const SizedBox(width: 8),
                                    Text(
                                      'AI Analysis',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.headlineSmall,
                                    ),
                                  ],
                                ),
                                FilledButton.icon(
                                  onPressed: _isGeneratingAnalysis
                                      ? null
                                      : () => _generateAIAnalysis(project),
                                  icon: _isGeneratingAnalysis
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.psychology),
                                  label: Text(
                                    _isGeneratingAnalysis
                                        ? 'Analyzing...'
                                        : (project.hasAiAnalysis
                                              ? 'Regenerate'
                                              : 'Generate Analysis'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            if (!project.hasAiAnalysis &&
                                !_isGeneratingAnalysis)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(32.0),
                                  child: Text(
                                    'Click "Generate Analysis" to get AI insights on this project.',
                                  ),
                                ),
                              ),

                            if (_isGeneratingAnalysis)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(32.0),
                                  child: Column(
                                    children: [
                                      CircularProgressIndicator(),
                                      SizedBox(height: 16),
                                      Text('Analyzing project with AI...'),
                                    ],
                                  ),
                                ),
                              ),

                            if (project.hasAiAnalysis &&
                                !_isGeneratingAnalysis) ...[
                              _buildAnalysisSection(
                                'Problem Statement',
                                project.problemStatement,
                              ),
                              _buildAnalysisListSection(
                                'Objectives',
                                project.aiObjectives,
                              ),
                              _buildAnalysisSection(
                                'Methodology',
                                project.methodology,
                              ),
                              _buildAnalysisSection(
                                'Implementation',
                                project.implementation,
                              ),
                              _buildAnalysisSection(
                                'Results / Outcomes',
                                project.results,
                              ),
                              _buildAnalysisListSection(
                                'Areas for Improvement',
                                project.areasForImprovement,
                              ),
                              _buildAnalysisListSection(
                                'Recommendations',
                                project.recommendations,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelSmall),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisSection(String title, String? content) {
    if (content == null || content.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(content, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }

  Widget _buildAnalysisListSection(String title, List<String>? items) {
    if (items == null || items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '• ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final projectProvider = FutureProvider.family<Project?, String>((ref, id) {
  return ref.watch(projectRepositoryProvider).getProject(id);
});
