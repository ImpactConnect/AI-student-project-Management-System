
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:student_project_management/src/features/projects/data/ai_service.dart';
import 'package:student_project_management/src/features/projects/data/project_repository.dart';
import 'package:student_project_management/src/features/projects/domain/project.dart';
import 'package:student_project_management/src/features/projects/presentation/project_form_screen.dart';

class ProjectDetailsScreen extends ConsumerStatefulWidget {
  final String projectId;
  const ProjectDetailsScreen({super.key, required this.projectId});

  @override
  ConsumerState<ProjectDetailsScreen> createState() => _ProjectDetailsScreenState();
}

class _ProjectDetailsScreenState extends ConsumerState<ProjectDetailsScreen> {
  bool _isGeneratingInsights = false;

  Future<void> _generateInsights(Project project) async {
    setState(() => _isGeneratingInsights = true);
    try {
      final aiService = await ref.read(aiServiceProvider.future);
      final analysis = await aiService.analyzeProjectQuality(
        project.title, 
        project.objectives
      );

      // Expecting keys: achievements, recommendations
      final achievements = (analysis['achievements'] as List<dynamic>?)?.cast<String>();
      final recommendations = (analysis['recommendations'] as List<dynamic>?)?.cast<String>();

      final updatedProject = Project(
         id: project.id,
         title: project.title,
         objectives: project.objectives,
         studentName: project.studentName,
         department: project.department,
         year: project.year,
         supervisorId: project.supervisorId,
         status: project.status,
         createdAt: project.createdAt,
         documentUrl: project.documentUrl,
         similarityScore: project.similarityScore,
         achievements: achievements ?? project.achievements,
         recommendations: recommendations ?? project.recommendations,
         aiFeedback: analysis,
      );

      await ref.read(projectRepositoryProvider).updateProject(updatedProject);
      
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isGeneratingInsights = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectAsync = ref.watch(projectProvider(widget.projectId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Project Details'),
        actions: [
          projectAsync.when(
            data: (project) => IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                if (project != null) {
                   Navigator.push(
                     context,
                     MaterialPageRoute(builder: (_) => ProjectFormScreen(project: project)),
                   );
                }
              },
            ),
            loading: () => const SizedBox(),
            error: (_,__) => const SizedBox(),
          )
        ],
      ),
      body: projectAsync.when(
        data: (project) {
          if (project == null) return const Center(child: Text('Project not found'));
          return SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, project),
                const SizedBox(height: 32),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: _buildMainContent(context, project)),
                    const SizedBox(width: 32),
                    Expanded(flex: 1, child: _buildInsightsPanel(context, project)),
                  ],
                )
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Project project) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Chip(label: Text(project.status.name.toUpperCase())),
            const SizedBox(width: 16),
            Text('Year: ${project.year}', style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 16),
        Text(project.title, style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 8),
        Text('by ${project.studentName} • ${project.department}', 
             style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.grey)),
      ],
    );
  }

  Widget _buildMainContent(BuildContext context, Project project) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Objectives / Abstract', style: Theme.of(context).textTheme.headlineSmall),
            const Divider(),
            const SizedBox(height: 16),
            Text(project.objectives, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 32),
            if (project.documentUrl != null)
              OutlinedButton.icon(
                onPressed: () {
                   // Open URL (implement url_launcher if needed)
                },
                icon: const Icon(Icons.description),
                label: const Text('View Document'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightsPanel(BuildContext context, Project project) {
    final hasInsights = project.achievements != null && project.achievements!.isNotEmpty;

    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(Icons.auto_awesome),
                if (!hasInsights)
                  IconButton(
                    onPressed: _isGeneratingInsights ? null : () => _generateInsights(project),
                    icon: _isGeneratingInsights 
                      ? const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2))
                      : const Icon(Icons.refresh),
                    tooltip: 'Generate Insights',
                  )
              ],
            ),
            const SizedBox(height: 16),
            Text('AI Insights', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),
            
            if (!hasInsights)
              const Text('No insights generated yet. Click refresh to analyze.'),

            if (project.achievements != null) ...[
               Text('Key Achievements', style: Theme.of(context).textTheme.titleMedium),
               ...project.achievements!.map((a) => Text('• $a')),
               const SizedBox(height: 16),
            ],

            if (project.recommendations != null) ...[
               Text('Recommendations', style: Theme.of(context).textTheme.titleMedium),
               ...project.recommendations!.map((r) => Text('• $r')),
            ],
          ],
        ),
      ),
    );
  }
}

final projectProvider = FutureProvider.family<Project?, String>((ref, id) {
  return ref.watch(projectRepositoryProvider).getProject(id);
});
