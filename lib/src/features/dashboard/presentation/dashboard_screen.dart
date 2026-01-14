
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:student_project_management/src/features/projects/data/project_repository.dart';
import 'package:student_project_management/src/features/projects/domain/project.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: projectsAsync.when(
        data: (projects) => _buildDashboard(context, projects),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildDashboard(BuildContext context, List<Project> projects) {
    final total = projects.length;
    final approved = projects.where((p) => p.status == ProjectStatus.approved).length;
    final pending = projects.where((p) => p.status == ProjectStatus.pending).length;
    final rejected = projects.where((p) => p.status == ProjectStatus.rejected).length;
    final revision = projects.where((p) => p.status == ProjectStatus.needsRevision).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'NDA Postgraduate School',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.grey[600],
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Department of Computer Science',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn().slideY(begin: 0.3, duration: 600.ms, curve: Curves.easeOutBack),
                 const SizedBox(height: 8),
                Container(
                  width: 60,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ).animate().scaleX(delay: 400.ms, duration: 400.ms, curve: Curves.easeOut),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // KPI Cards
          Row(
            children: [
              Expanded(
                child: _StatCard(
                    title: 'Total Projects', value: '$total', icon: Icons.folder, color: Colors.blue)
                    .animate().fadeIn(delay: 100.ms).scale(),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatCard(
                    title: 'Approved', value: '$approved', icon: Icons.check_circle, color: Colors.green)
                    .animate().fadeIn(delay: 200.ms).scale(),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatCard(
                    title: 'Pending Review', value: '$pending', icon: Icons.pending, color: Colors.orange)
                    .animate().fadeIn(delay: 300.ms).scale(),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatCard(
                    title: 'Need Revision', value: '$revision', icon: Icons.edit_note, color: Colors.purple)
                    .animate().fadeIn(delay: 400.ms).scale(),
              ),
            ],
          ),
          const SizedBox(height: 32),
          // Chart Section
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Project Status Distribution', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 300,
                          child: total == 0 
                            ? const Center(child: Text('No Data')) 
                            : PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 40,
                              sections: [
                                if (approved > 0)
                                  PieChartSectionData(
                                      color: Colors.green, value: approved.toDouble(), title: 'Approved', radius: 50, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                if (pending > 0)
                                  PieChartSectionData(
                                      color: Colors.orange, value: pending.toDouble(), title: 'Pending', radius: 50, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                if (rejected > 0)
                                  PieChartSectionData(
                                      color: Colors.red, value: rejected.toDouble(), title: 'Rejected', radius: 50, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                if (revision > 0)
                                  PieChartSectionData(
                                      color: Colors.purple, value: revision.toDouble(), title: 'Revision', radius: 50, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ).animate().fadeIn(delay: 500.ms),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 1,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Quick Actions', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 16),
                         ListTile(
                          leading: const Icon(Icons.add, color: Colors.indigo),
                          title: const Text('New Project'),
                          subtitle: const Text('Add project manually'),
                          onTap: () => context.go('/projects/new'),
                        ),
                         const Divider(),
                         ListTile(
                          leading: const Icon(Icons.psychology, color: Colors.indigo),
                          title: const Text('AI Assistant'),
                          subtitle: const Text('Verify new proposal'),
                          onTap: () => context.go('/ai-assistant'),
                        ),
                         const Divider(),
                         ListTile(
                          leading: const Icon(Icons.settings, color: Colors.indigo),
                          title: const Text('Settings'),
                          subtitle: const Text('Theme & About'),
                          onTap: () => context.go('/settings'),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: 600.ms).slideX(begin: 0.1),
              )
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                Text(title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
