import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/chat_models.dart';
import '../../../data/repositories/local_settings_repository.dart';
import '../../../markdown/ast.dart';
import '../../../markdown/parser.dart';
import '../../../markdown/renderer.dart';
import '../application/chat_providers.dart';

class ChatThreadScreen extends ConsumerWidget {
  const ChatThreadScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationAsync = ref.watch(conversationProvider(conversationId));
    final messagesAsync = ref.watch(messagesProvider(conversationId));

    return Scaffold(
      appBar: AppBar(
        title: conversationAsync.when(
          data: (conversation) => Text(conversation?.title ?? 'Chat'),
          loading: () => const Text('Chat'),
          error: (error, stackTrace) => const Text('Chat'),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: messagesAsync.when(
                data: (messages) => _MessageList(messages: messages),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) =>
                    Center(child: Text('Failed to load thread: $error')),
              ),
            ),
            ChatComposer(conversationId: conversationId),
          ],
        ),
      ),
    );
  }
}

class _MessageList extends ConsumerWidget {
  const _MessageList({required this.messages});

  final List<ChatMessageModel> messages;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);

    if (messages.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[messages.length - 1 - index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: message.isAssistant
              ? _AssistantMessage(
                  key: ValueKey(message.id),
                  message: message,
                  showLineNumbers: settings.showLineNumbers,
                )
              : _UserBubble(key: ValueKey(message.id), message: message),
        );
      },
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({super.key, required this.message});

  final ChatMessageModel message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.72,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(8),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Text(
              message.body,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AssistantMessage extends StatefulWidget {
  const _AssistantMessage({
    super.key,
    required this.message,
    required this.showLineNumbers,
  });

  final ChatMessageModel message;
  final bool showLineNumbers;

  @override
  State<_AssistantMessage> createState() => _AssistantMessageState();
}

class _AssistantMessageState extends State<_AssistantMessage> {
  late final MarkdownDocument _document = MarkdownParser().parse(
    widget.message.body,
  );

  @override
  Widget build(BuildContext context) {
    return MarkdownRenderer(
      document: _document,
      showLineNumbers: widget.showLineNumbers,
    );
  }
}

class ChatComposer extends ConsumerStatefulWidget {
  const ChatComposer({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends ConsumerState<ChatComposer> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sending = ref.watch(chatControllerProvider).isLoading;
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 12,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.96),
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: _focusNode.hasFocus ? 0.10 : 0.03,
            ),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(hintText: 'Ask anything'),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: sending ? null : _send,
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            ),
            child: sending
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.arrow_upward_rounded),
          ),
        ],
      ),
    );
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }
    _controller.clear();
    await ref
        .read(chatControllerProvider.notifier)
        .sendMessage(conversationId: widget.conversationId, text: text);
  }
}
