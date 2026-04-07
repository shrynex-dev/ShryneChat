import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/local_settings_repository.dart';
import '../../chat/application/chat_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          children: [
            Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Tune reading density, platform color behavior, and local chat storage.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            _SectionCard(
              title: 'Appearance',
              children: [
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('System'),
                    ),
                  ],
                  selected: {settings.themeMode},
                  onSelectionChanged: (selection) {
                    controller.updateThemeMode(selection.first);
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Use dynamic color'),
                  subtitle: const Text(
                    'Follow Android wallpaper accents when available.',
                  ),
                  value: settings.useDynamicColor,
                  onChanged: controller.updateDynamicColor,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Reading',
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Font scale'),
                  subtitle: Slider(
                    value: settings.fontScale,
                    min: 0.9,
                    max: 1.2,
                    divisions: 6,
                    label: settings.fontScale.toStringAsFixed(2),
                    onChanged: controller.updateFontScale,
                  ),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show code line numbers'),
                  value: settings.showLineNumbers,
                  onChanged: controller.updateLineNumbers,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Chat behavior',
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Animations'),
                  subtitle: const Text(
                    'Subtle transitions and composer elevation changes.',
                  ),
                  value: settings.animationsEnabled,
                  onChanged: controller.updateAnimations,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Clear local chat history'),
                  subtitle: const Text(
                    'Deletes all stored conversations and messages on this device.',
                  ),
                  trailing: FilledButton.tonal(
                    onPressed: () =>
                        ref.read(chatControllerProvider.notifier).clearChats(),
                    child: const Text('Clear'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'About',
              children: const [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Transport'),
                  subtitle: Text(
                    'Mock assistant response with full markdown fixture.',
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Storage'),
                  subtitle: Text('SQLite database with scalable repositories.'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}
