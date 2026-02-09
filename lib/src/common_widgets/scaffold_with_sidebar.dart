
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:student_project_management/src/features/auth/data/auth_repository.dart';

import 'package:flutter_animate/flutter_animate.dart';

class ScaffoldWithSidebar extends ConsumerWidget {
  const ScaffoldWithSidebar({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Current user email
    final userEmail = ref.watch(authRepositoryProvider).currentUser?.email ?? 'User';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 120, // Increased from default ~72dp
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark 
                  ? [Theme.of(context).colorScheme.surface, Theme.of(context).colorScheme.surfaceContainer]
                  : [Colors.white, Colors.indigo.shade50],
              ),
            ),
            child: NavigationRail(
              backgroundColor: Colors.transparent,
              selectedIndex: _calculateSelectedIndex(context),
              onDestinationSelected: (int index) {
                _onItemTapped(index, context);
              },
              labelType: NavigationRailLabelType.all,
              leading: Column(
                children: [
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24, width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white,
                      backgroundImage: const AssetImage('assets/images/nda_logo.png'),
                      onBackgroundImageError: (_, __) => {},
                      child: const SizedBox.shrink(), // Fallback handled by bg color if image fails
                    ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                     .scale(duration: 2.seconds, begin: const Offset(0.95, 0.95), end: const Offset(1.05, 1.05)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'NDA SPMS', 
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1B3A2F), // Military Green
                    ),
                  ).animate().fadeIn().slideY(begin: 0.2),
                  const SizedBox(height: 4),
                   Text(
                    'PG School', 
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.white70 : const Color(0xFFD4AF37), // Gold
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: IconButton(
                      icon: const Icon(Icons.logout),
                      tooltip: 'Logout ($userEmail)',
                      onPressed: () async {
                        await ref.read(authRepositoryProvider).signOut();
                      },
                    ),
                  ),
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: Text('Dashboard'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.library_books_outlined),
                  selectedIcon: Icon(Icons.library_books),
                  label: Text('Projects'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.psychology_outlined),
                  selectedIcon: Icon(Icons.psychology),
                  label: Text('AI Assistant'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: Text('Settings'),
                ),
              ],
            ),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          // Main Content
          Expanded(child: child),
        ],
      ),
    );
  }

  static int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/dashboard')) {
      return 0;
    }
    if (location.startsWith('/projects')) {
      return 1;
    }
    if (location.startsWith('/ai-assistant')) {
      return 2;
    }
    if (location.startsWith('/settings')) {
      return 3;
    }
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/dashboard');
        break;
      case 1:
        context.go('/projects');
        break;
      case 2:
        context.go('/ai-assistant');
        break;
      case 3:
        context.go('/settings');
        break;
    }
  }
}
