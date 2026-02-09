
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:student_project_management/src/common_widgets/scaffold_with_sidebar.dart';
import 'package:student_project_management/src/features/auth/data/auth_repository.dart';
import 'package:student_project_management/src/features/auth/presentation/login_screen.dart';
import 'package:student_project_management/src/features/dashboard/presentation/dashboard_screen.dart';
import 'package:student_project_management/src/features/ai_assistant/presentation/ai_assistant_screen.dart';
import 'package:student_project_management/src/features/projects/presentation/project_details_screen.dart';
import 'package:student_project_management/src/features/projects/presentation/project_form_screen.dart';
import 'package:student_project_management/src/features/projects/presentation/project_list_screen.dart';
import 'package:student_project_management/src/features/settings/presentation/settings_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final goRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateChangesProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login',
    initialExtra: null,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isLoggedIn = authState.asData?.value != null;
      final isLoggingIn = state.uri.toString() == '/login';

      if (!isLoggedIn && !isLoggingIn) {
        return '/login';
      }

      if (isLoggedIn && isLoggingIn) {
        return '/dashboard';
      }

      return null;
    },
    refreshListenable: _StreamToLegacyListenable(ref.watch(authRepositoryProvider).authStateChanges()),
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return ScaffoldWithSidebar(child: child); 
        },
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/projects',
            builder: (context, state) => const ProjectListScreen(),
            routes: [
               GoRoute(
                path: 'new',
                parentNavigatorKey: _rootNavigatorKey, 
                builder: (context, state) => const ProjectFormScreen(),
              ),
              GoRoute(
                path: ':id',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) {
                  final projectId = state.pathParameters['id']!;
                  return ProjectDetailsScreen(projectId: projectId);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/ai-assistant',
            builder: (context, state) => const AIAssistantScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});

// Helper to make Stream listenable for GoRouter
class _StreamToLegacyListenable extends ChangeNotifier {
  _StreamToLegacyListenable(Stream stream) {
    stream.listen((_) => notifyListeners());
  }
}
