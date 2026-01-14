import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:student_project_management/src/features/settings/data/ai_settings_repository.dart';
import 'package:student_project_management/src/features/settings/data/theme_controller.dart';
import 'package:student_project_management/src/features/settings/domain/ai_config.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeControllerProvider);


    final aiConfigAsync = ref.watch(aiConfigStreamProvider);
    
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildSettingsSection(
            context,
            title: 'Appearance',
            children: [
              SwitchListTile(
                secondary: Icon(themeMode == ThemeMode.light ? Icons.wb_sunny : Icons.nightlight_round),
                title: const Text('Light Mode'),
                subtitle: const Text('Toggle to switch between Light (White) and Dark (Black) modes.'),
                value: themeMode == ThemeMode.light,
                onChanged: (isLight) {
                   ref.read(themeControllerProvider.notifier).setTheme(
                     isLight ? ThemeMode.light : ThemeMode.dark
                   );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSettingsSection(
            context,
            title: 'AI Configuration',
            children: [
              aiConfigAsync.when(
                data: (config) => _AIConfigForm(initialConfig: config),
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
                error: (err, stack) => Padding(padding: const EdgeInsets.all(16), child: Text('Error: $err')),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSettingsSection(
            context,
            title: 'About',
            children: [
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Student Project Management System'),
                subtitle: Text('Version 1.0.0+1'),
              ),
              const ListTile(
                leading: Icon(Icons.school),
                title: Text('Academic Year'),
                subtitle: Text('2025-2026'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context, {required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        )),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.5)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _AIConfigForm extends ConsumerStatefulWidget {
  final AIConfig initialConfig;
  const _AIConfigForm({required this.initialConfig});

  @override
  ConsumerState<_AIConfigForm> createState() => _AIConfigFormState();
}

class _AIConfigFormState extends ConsumerState<_AIConfigForm> {
  late AIProvider _provider;
  late TextEditingController _geminiKeyController;
  late TextEditingController _openAIKeyController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _provider = widget.initialConfig.provider;
    _geminiKeyController = TextEditingController(text: widget.initialConfig.geminiKey);
    _openAIKeyController = TextEditingController(text: widget.initialConfig.openAIKey);
  }

  @override
  void dispose() {
    _geminiKeyController.dispose();
    _openAIKeyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final newConfig = widget.initialConfig.copyWith(
        provider: _provider,
        geminiKey: _geminiKeyController.text.trim(),
        openAIKey: _openAIKeyController.text.trim(),
      );
      await ref.read(aiSettingsRepositoryProvider).updateAIConfig(newConfig);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI Configuration Saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving config: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<AIProvider>(
            value: _provider,
            decoration: const InputDecoration(labelText: 'Active Provider'),
            items: AIProvider.values.map((p) => DropdownMenuItem(
              value: p,
              child: Text(p.name.toUpperCase()),
            )).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _provider = val);
            },
          ),
          const SizedBox(height: 16),
          if (_provider == AIProvider.gemini)
            TextFormField(
              controller: _geminiKeyController,
              decoration: const InputDecoration(
                labelText: 'Gemini API Key',
                helperText: 'Required for Gemini provider',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
          if (_provider == AIProvider.openai)
            TextFormField(
              controller: _openAIKeyController,
              decoration: const InputDecoration(
                labelText: 'OpenAI API Key',
                helperText: 'Required for OpenAI provider',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving ? const CircularProgressIndicator() : const Text('Save Configuration'),
            ),
          ),
        ],
      ),
    );
  }
}
