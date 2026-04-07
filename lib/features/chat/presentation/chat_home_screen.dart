import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../data/models/chat_models.dart';
import '../../../data/repositories/local_settings_repository.dart';
import '../../../markdown/ast.dart';
import '../../../markdown/parser.dart';
import '../../../markdown/renderer.dart';
import '../application/chat_providers.dart';

class ChatHomeScreen extends ConsumerWidget {
  const ChatHomeScreen({super.key, this.conversationId});

  final String? conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationAsync = conversationId == null
        ? const AsyncValue<ConversationSummary?>.data(null)
        : ref.watch(conversationProvider(conversationId!));
    final messagesAsync = conversationId == null
        ? const AsyncValue<List<ChatMessageModel>>.data([])
        : ref.watch(messagesProvider(conversationId!));

    return Scaffold(
      drawer: const _ChatDrawer(),
      appBar: AppBar(
        titleSpacing: 6,
        title: conversationAsync.when(
          data: (conversation) => Text(conversation?.title ?? 'Shryne'),
          loading: () => const Text('Shryne'),
          error: (error, stackTrace) => const Text('Shryne'),
        ),
        actions: [
          IconButton(
            tooltip: 'New chat',
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.edit_note_rounded),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: messagesAsync.when(
                data: (messages) => _ChatBody(
                  conversationId: conversationId,
                  messages: messages,
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) =>
                    Center(child: Text('Failed to load chat: $error')),
              ),
            ),
            ChatComposer(conversationId: conversationId),
          ],
        ),
      ),
    );
  }
}

class _ChatBody extends StatelessWidget {
  const _ChatBody({required this.conversationId, required this.messages});

  final String? conversationId;
  final List<ChatMessageModel> messages;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const _GreetingState();
    }
    return _MessageList(messages: messages);
  }
}

class _GreetingState extends StatelessWidget {
  const _GreetingState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 34,
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 22),
            Text('How can I help today?', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(
              'Ask a question, draft an idea, or attach files. Once you send the first message, this greeting gets out of the way and the conversation begins.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
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
          maxWidth: MediaQuery.sizeOf(context).width * 0.74,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(10),
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

  final String? conversationId;

  @override
  ConsumerState<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends ConsumerState<ChatComposer> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<PlatformFile> _selectedFiles = const [];

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final sending = ref.watch(chatControllerProvider).isLoading;
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.fromLTRB(
        14,
        10,
        14,
        MediaQuery.viewInsetsOf(context).bottom + 12,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.98),
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: _focusNode.hasFocus ? 0.1 : 0.03,
            ),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedFiles.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final file in _selectedFiles)
                    InputChip(
                      label: Text(file.name),
                      onDeleted: () {
                        setState(() {
                          _selectedFiles = _selectedFiles
                              .where((candidate) => candidate.path != file.path)
                              .toList(growable: false);
                        });
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton.filledTonal(
                tooltip: 'Upload file',
                onPressed: sending ? null : _pickFiles,
                icon: const Icon(Icons.add_rounded),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    hintText: 'Write a message',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: sending ? null : _send,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 18,
                  ),
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
        ],
      ),
    );
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: false,
    );
    if (!mounted || result == null) {
      return;
    }
    setState(() {
      _selectedFiles = result.files;
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _selectedFiles.isEmpty) {
      return;
    }

    final attachmentPrefix = _selectedFiles.isEmpty
        ? ''
        : 'Attached files: ${_selectedFiles.map((file) => file.name).join(', ')}\n\n';
    final composedMessage =
        '$attachmentPrefix${text.isEmpty ? 'Please review the attached files.' : text}';

    _controller.clear();
    setState(() {
      _selectedFiles = const [];
    });

    final router = GoRouter.of(context);
    if (widget.conversationId == null) {
      final conversationId = await ref
          .read(chatControllerProvider.notifier)
          .startConversation(composedMessage);
      if (!mounted) {
        return;
      }
      router.go('/chat/$conversationId');
      return;
    }

    await ref
        .read(chatControllerProvider.notifier)
        .sendMessage(
          conversationId: widget.conversationId!,
          text: composedMessage,
        );
  }
}

class _ChatDrawer extends ConsumerStatefulWidget {
  const _ChatDrawer();

  @override
  ConsumerState<_ChatDrawer> createState() => _ChatDrawerState();
}

class _ChatDrawerState extends ConsumerState<_ChatDrawer> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conversationsAsync = ref.watch(conversationsProvider);
    final theme = Theme.of(context);

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Search chats',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        context.go('/');
                      },
                      icon: const Icon(Icons.edit_note_rounded),
                      label: const Text('New chat'),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: conversationsAsync.when(
                data: (conversations) {
                  final filtered = _filterConversations(
                    conversations,
                    _searchController.text,
                  );
                  if (filtered.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          'No chats found.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final conversation = filtered[index];
                      return _DrawerConversationTile(
                        conversation: conversation,
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) =>
                    Center(child: Text('Failed to load chats: $error')),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                leading: const Icon(Icons.tune_rounded),
                title: const Text('Settings'),
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/settings');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<ConversationSummary> _filterConversations(
    List<ConversationSummary> all,
    String query,
  ) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return all;
    }
    return all
        .where(
          (conversation) =>
              conversation.title.toLowerCase().contains(normalized) ||
              conversation.lastMessagePreview.toLowerCase().contains(
                normalized,
              ),
        )
        .toList(growable: false);
  }
}

class _DrawerConversationTile extends StatelessWidget {
  const _DrawerConversationTile({required this.conversation});

  final ConversationSummary conversation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatter = DateFormat('MMM d');

    return Material(
      color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.of(context).pop();
          context.go('/chat/${conversation.id}');
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      conversation.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatter.format(conversation.updatedAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                conversation.lastMessagePreview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
