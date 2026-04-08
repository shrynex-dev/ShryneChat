import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/chat_models.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../../data/repositories/local_chat_repository.dart';
import '../../../data/repositories/local_settings_repository.dart';
import '../../gemini/application/gemini_webview_session.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  ref.watch(databaseReadyProvider);
  return LocalChatRepository(
    ref.watch(databaseProvider),
    ref.read(geminiWebViewSessionProvider.notifier),
  );
});

final conversationsProvider = StreamProvider<List<ConversationSummary>>((ref) {
  return ref.watch(chatRepositoryProvider).watchConversations();
});

final conversationProvider =
    FutureProvider.family<ConversationSummary?, String>((ref, id) {
      return ref.watch(chatRepositoryProvider).getConversation(id);
    });

final messagesProvider = StreamProvider.family<List<ChatMessageModel>, String>((
  ref,
  conversationId,
) {
  return ref.watch(chatRepositoryProvider).watchMessages(conversationId);
});

class ChatController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<String> startConversation(String prompt) async {
    state = const AsyncLoading();
    try {
      final conversationId = await ref
          .read(chatRepositoryProvider)
          .startConversation(prompt);
      state = const AsyncData(null);
      return conversationId;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> sendMessage({
    required String conversationId,
    required String text,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(chatRepositoryProvider)
          .sendUserMessage(conversationId: conversationId, text: text),
    );
  }

  Future<void> clearChats() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(chatRepositoryProvider).clearAllChats(),
    );
  }
}

final chatControllerProvider = AsyncNotifierProvider<ChatController, void>(
  ChatController.new,
);
