import '../../core/constants/mock_markdown_fixture.dart';
import '../local/app_database.dart';
import '../models/chat_models.dart';
import 'chat_repository.dart';

class LocalChatRepository implements ChatRepository {
  LocalChatRepository(this._database);

  final AppDatabase _database;

  @override
  Stream<List<ConversationSummary>> watchConversations() {
    return _database.watchConversations();
  }

  @override
  Future<ConversationSummary?> getConversation(String id) {
    return _database.getConversation(id);
  }

  @override
  Stream<List<ChatMessageModel>> watchMessages(String conversationId) {
    return _database.watchMessages(conversationId);
  }

  @override
  Future<String> startConversation(String openingUserMessage) async {
    final conversationId = await _database.createConversation(
      title: _titleFromPrompt(openingUserMessage),
      preview: openingUserMessage,
    );
    await sendUserMessage(
      conversationId: conversationId,
      text: openingUserMessage,
    );
    return conversationId;
  }

  @override
  Future<void> sendUserMessage({
    required String conversationId,
    required String text,
  }) async {
    await _database.insertMessage(
      conversationId: conversationId,
      role: MessageRole.user,
      format: MessageFormat.plainText,
      status: MessageStatus.sent,
      body: text,
    );
    await _database.insertMessage(
      conversationId: conversationId,
      role: MessageRole.assistant,
      format: MessageFormat.markdown,
      status: MessageStatus.sent,
      body: mockAssistantMarkdown,
    );
  }

  @override
  Future<void> clearAllChats() {
    return _database.clearChats();
  }

  String _titleFromPrompt(String prompt) {
    final normalized = prompt.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) {
      return 'New chat';
    }
    return normalized.length > 36
        ? '${normalized.substring(0, 36)}…'
        : normalized;
  }
}
