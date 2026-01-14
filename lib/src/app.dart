
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:student_project_management/src/routing/app_router.dart';
import 'package:student_project_management/src/theme/app_theme.dart';
import 'package:student_project_management/src/features/settings/data/theme_controller.dart';

import 'package:student_project_management/src/features/prompts/data/prompt_repository.dart';

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    // Seed default prompts if they don't exist
    // We delay slightly to not block the immediate UI rendering
    Future.microtask(() {
       ref.read(promptRepositoryProvider).seedDefaultPrompts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final goRouter = ref.watch(goRouterProvider);
    return MaterialApp.router(
      routerConfig: goRouter,
      debugShowCheckedModeBanner: false,
      restorationScopeId: 'app',
      title: 'Student Project Management',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeControllerProvider),
    );
  }
}
