import '../models/chat_models.dart';

abstract class ChatbotRepository {
  /// Loads all conversations for a specific user.
  Future<List<ChatConversation>> getConversations(String userId);

  /// Saves or updates a conversation.
  Future<void> saveConversation(ChatConversation conversation);

  /// Deletes a conversation.
  Future<void> deleteConversation(String userId, String conversationId);
}
