import '../models/chat_models.dart';

abstract class ChatRepository {
  Stream<List<ConversationSummary>> watchConversations();
  Future<ConversationSummary?> getConversation(String id);
  Stream<List<ChatMessageModel>> watchMessages(String conversationId);
  Future<String> startConversation(String openingUserMessage);
  Future<void> sendUserMessage({
    required String conversationId,
    required String text,
  });
  Future<void> clearAllChats();
}
