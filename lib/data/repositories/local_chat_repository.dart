import '../../features/gemini/application/gemini_webview_session.dart';
import '../local/app_database.dart';
import '../models/chat_models.dart';
import 'chat_repository.dart';

class LocalChatRepository implements ChatRepository {
  LocalChatRepository(this._database, this._geminiSession);
  final AppDatabase _database;
  final GeminiWebViewSessionController _geminiSession;

  @override
  Stream<List<ConversationSummary>> watchConversations() =>
      _database.watchConversations();

  @override
  Future<ConversationSummary?> getConversation(String id) =>
      _database.getConversation(id);

  @override
  Stream<List<ChatMessageModel>> watchMessages(String id) =>
      _database.watchMessages(id);

  @override
  Future<String> startConversation(String text) async {
    // Create the chat entry in SQLite
    final id = await _database.createConversation(
      title: 'New Chat',
      preview: text,
    );
    // Send the message
    await sendUserMessage(conversationId: id, text: text);
    return id;
  }

  @override
  Future<void> sendUserMessage({
    required String conversationId,
    required String text,
  }) async {
    // 1. Save your message to local database
    await _database.insertMessage(
      conversationId: conversationId,
      role: MessageRole.user,
      body: text,
      format: MessageFormat.plainText,
      status: MessageStatus.sent,
    );

    final responseText = await () async {
      try {
        return await _geminiSession.sendPrompt(text);
      } catch (error) {
        return 'Gemini session error: $error. Open the Gemini session screen and sign in before sending messages.';
      }
    }();
    await _database.insertMessage(
      conversationId: conversationId,
      role: MessageRole.assistant,
      body: responseText,
      format: MessageFormat.markdown,
      status: MessageStatus.sent,
    );
  }

  @override
  Future<void> clearAllChats() => _database.clearChats();
}
