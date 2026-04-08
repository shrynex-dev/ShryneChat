import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gemini/application/gemini_webview_session.dart';
import '../gemini/presentation/gemini_session_webview.dart';

class GeminiLoginScreen extends ConsumerStatefulWidget {
  const GeminiLoginScreen({super.key});

  @override
  ConsumerState<GeminiLoginScreen> createState() => _GeminiLoginScreenState();
}

class _GeminiLoginScreenState extends ConsumerState<GeminiLoginScreen> {
  double _progress = 0;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(geminiWebViewSessionProvider);
    final sessionController = ref.read(geminiWebViewSessionProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gemini Session'),
        actions: [
          IconButton(
            tooltip: 'Open AI Studio',
            onPressed: sessionController.openAiStudioHome,
            icon: const Icon(Icons.open_in_browser_rounded),
          ),
          IconButton(
            tooltip: 'Reload',
            onPressed: sessionController.reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This screen is now the persistent Gemini session host. Sign in to AI Studio here. The next transport step will drive the real page through an injected JavaScript bridge instead of replaying private RPCs.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: _progress == 1 ? null : _progress,
                ),
                const SizedBox(height: 12),
                Text(
                  session.status,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatusChip(
                      label: session.hasController ? 'Attached' : 'Detached',
                    ),
                    _StatusChip(
                      label: session.bridgeInstalled
                          ? 'Bridge installed'
                          : 'Bridge pending',
                    ),
                    _StatusChip(
                      label: session.appLoaded ? 'App loaded' : 'Not in app',
                    ),
                    _StatusChip(
                      label: session.hasPromptInput
                          ? 'Prompt input found'
                          : 'Prompt input missing',
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: GeminiSessionWebView(
              onProgress: (value) {
                if (!mounted) {
                  return;
                }
                setState(() {
                  _progress = value;
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(label));
  }
}
