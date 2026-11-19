import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/chat_models.dart';
import '../../domain/repositories/chatbot_repository.dart';

class LocalChatbotRepository implements ChatbotRepository {
  final SharedPreferences _prefs;
  FirebaseFirestore? _firestore;

  LocalChatbotRepository(this._prefs) {
    try {
      _firestore = FirebaseFirestore.instance;
    } catch (_) {}
  }

  String _cleanUserId(String userId) => userId.replaceAll('.', '_');
  String _storageKey(String userId) => 'chatbot_conversations_$userId';

  @override
  Future<List<ChatConversation>> getConversations(String userId) async {
    final data = _prefs.getStringList(_storageKey(userId));
    List<ChatConversation> localList = [];
    if (data != null) {
      localList = data.map((e) => ChatConversation.fromMap(json.decode(e))).toList();
    }

    if (_firestore != null && localList.isEmpty) {
      try {
        final querySnapshot = await _firestore!
            .collection('users')
            .doc(_cleanUserId(userId))
            .collection('conversations')
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final cloudConversations = querySnapshot.docs
              .map((doc) => ChatConversation.fromMap(doc.data()))
              .toList();

          cloudConversations.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
          final updatedData = cloudConversations.map((c) => json.encode(c.toMap())).toList();
          await _prefs.setStringList(_storageKey(userId), updatedData);
          return cloudConversations;
        }
      } catch (_) {}
    }

    return localList;
  }

  @override
  Future<void> saveConversation(ChatConversation conversation) async {
    final List<ChatConversation> current = await getConversations(conversation.userId);
    final index = current.indexWhere((c) => c.id == conversation.id);
    if (index != -1) {
      current[index] = conversation;
    } else {
      current.add(conversation);
    }

    final data = current.map((c) => json.encode(c.toMap())).toList();
    await _prefs.setStringList(_storageKey(conversation.userId), data);

    if (_firestore != null) {
      try {
        await _firestore!
            .collection('users')
            .doc(_cleanUserId(conversation.userId))
            .collection('conversations')
            .doc(conversation.id)
            .set(conversation.toMap(), SetOptions(merge: true));
      } catch (_) {}
    }
  }

  @override
  Future<void> deleteConversation(String userId, String conversationId) async {
    final List<ChatConversation> current = await getConversations(userId);
    current.removeWhere((c) => c.id == conversationId);
    final data = current.map((c) => json.encode(c.toMap())).toList();
    await _prefs.setStringList(_storageKey(userId), data);

    if (_firestore != null) {
      try {
        await _firestore!
            .collection('users')
            .doc(_cleanUserId(userId))
            .collection('conversations')
            .doc(conversationId)
            .delete();
      } catch (_) {}
    }
  }
}
