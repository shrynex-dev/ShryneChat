import 'package:drift/drift.dart';
import '../api/gemini_client.dart';
import '../local/app_database.dart';
import '../models/chat_models.dart';
import 'chat_repository.dart';

class LocalChatRepository implements ChatRepository {
  LocalChatRepository(this._database);
  final AppDatabase _database;
  final _api = GeminiClient();

  @override
  Stream<List<ConversationSummary>> watchConversations() => _database.watchConversations();

  @override
  Future<ConversationSummary?> getConversation(String id) => _database.getConversation(id);

  @override
  Stream<List<ChatMessageModel>> watchMessages(String id) => _database.watchMessages(id);

  @override
  Future<String> startConversation(String text) async {
    // Create the chat entry in SQLite
    final id = await _database.createConversation(
      title: 'New Chat', 
      preview: text
    );
    // Send the message
    await sendUserMessage(conversationId: id, text: text);
    return id;
  }

  @override
  Future<void> sendUserMessage({required String conversationId, required String text}) async {
    // 1. Save your message to local database
    await _database.insertMessage(
      conversationId: conversationId,
      role: MessageRole.user,
      body: text,
      format: MessageFormat.plainText,
      status: MessageStatus.sent,
    );

    // 2. Get previous messages so Gemini has "Memory"
    // We use your watchMessages stream but converted to a list
    final messages = await _database.watchMessages(conversationId).first;

    // 3. Request answer from Gemini
    final aiText = await _api.getResponse(text, messages);

    // 4. Save Gemini's answer to local database
    await _database.insertMessage(
      conversationId: conversationId,
      role: MessageRole.assistant,
      body: aiText,
      format: MessageFormat.markdown,
      status: MessageStatus.sent,
    );
  }

  @override
  Future<void> clearAllChats() => _database.clearChats();
}