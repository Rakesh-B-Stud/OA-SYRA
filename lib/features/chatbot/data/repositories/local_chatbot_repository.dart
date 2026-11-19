import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/models/chat_models.dart';
import '../../domain/repositories/chatbot_repository.dart';

class LocalChatbotRepository implements ChatbotRepository {
  final SharedPreferences _prefs;
  final AppDatabase _appDatabase = AppDatabase();
  FirebaseFirestore? _firestore;

  LocalChatbotRepository(this._prefs) {
    try {
      _firestore = FirebaseFirestore.instance;
    } catch (_) {}
  }

  String _cleanUserId(String userId) => userId.trim().replaceAll('.', '_');
  String _storageKey(String userId) => 'chatbot_conversations_${_cleanUserId(userId)}';

  @override
  Future<List<ChatConversation>> getConversations(String userId) async {
    final cleanId = _cleanUserId(userId);
    final key = _storageKey(userId);

    // 1. Try reading from SharedPreferences
    final data = _prefs.getStringList(key) ?? _prefs.getStringList('chatbot_conversations_$userId');
    List<ChatConversation> localList = [];
    if (data != null) {
      localList = data.map((e) => ChatConversation.fromMap(json.decode(e))).toList();
    }

    // 2. Try reading from SQLite if localList is empty
    if (localList.isEmpty) {
      try {
        final db = await _appDatabase.database;
        final convRows = await db.query(
          'chat_conversations',
          where: 'user_id = ? OR user_id = ?',
          whereArgs: [cleanId, userId],
          orderBy: 'last_updated DESC',
        );

        for (var row in convRows) {
          final convId = row['id'] as String;
          final msgRows = await db.query(
            'chat_messages',
            where: 'conversation_id = ?',
            whereArgs: [convId],
            orderBy: 'timestamp ASC',
          );

          final messages = msgRows.map((m) => ChatMessage(
            text: m['text'] as String,
            role: ChatRole.values.byName(m['role'] as String),
            timestamp: DateTime.parse(m['timestamp'] as String),
          )).toList();

          localList.add(ChatConversation(
            id: convId,
            userId: row['user_id'] as String,
            title: row['title'] as String,
            messages: messages,
            lastUpdated: DateTime.parse(row['last_updated'] as String),
          ));
        }
      } catch (_) {}
    }

    localList.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
    return localList;
  }

  @override
  Future<void> saveConversation(ChatConversation conversation) async {
    final cleanId = _cleanUserId(conversation.userId);
    final key = _storageKey(conversation.userId);

    // Read current local list without cloud blocking
    final data = _prefs.getStringList(key) ?? _prefs.getStringList('chatbot_conversations_${conversation.userId}');
    List<ChatConversation> current = [];
    if (data != null) {
      current = data.map((e) => ChatConversation.fromMap(json.decode(e))).toList();
    }

    final index = current.indexWhere((c) => c.id == conversation.id);
    if (index != -1) {
      current[index] = conversation;
    } else {
      current.add(conversation);
    }

    current.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));

    // Save to SharedPreferences immediately
    final updatedData = current.map((c) => json.encode(c.toMap())).toList();
    await _prefs.setStringList(key, updatedData);
    await _prefs.setStringList('chatbot_conversations_${conversation.userId}', updatedData);

    // Save to SQLite asynchronously
    try {
      final db = await _appDatabase.database;
      await db.transaction((txn) async {
        await txn.rawInsert('''
          INSERT INTO chat_conversations (id, user_id, title, created_at, last_updated)
          VALUES (?, ?, ?, ?, ?)
          ON CONFLICT(id) DO UPDATE SET
            title = excluded.title,
            last_updated = excluded.last_updated
        ''', [
          conversation.id,
          cleanId,
          conversation.title,
          conversation.lastUpdated.toIso8601String(),
          conversation.lastUpdated.toIso8601String(),
        ]);

        for (var msgIndex = 0; msgIndex < conversation.messages.length; msgIndex++) {
          final msg = conversation.messages[msgIndex];
          final msgId = '${conversation.id}_msg_$msgIndex';
          await txn.rawInsert('''
            INSERT INTO chat_messages (id, conversation_id, user_id, role, text, timestamp)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
              text = excluded.text,
              timestamp = excluded.timestamp
          ''', [
            msgId,
            conversation.id,
            cleanId,
            msg.role.name,
            msg.text,
            msg.timestamp.toIso8601String(),
          ]);
        }
      });
    } catch (_) {}

    // Cloud Firestore non-blocking background sync
    if (_firestore != null) {
      _firestore!
          .collection('users')
          .doc(cleanId)
          .collection('conversations')
          .doc(conversation.id)
          .set(conversation.toMap(), SetOptions(merge: true))
          .catchError((_) {});
    }
  }

  @override
  Future<void> deleteConversation(String userId, String conversationId) async {
    final cleanId = _cleanUserId(userId);
    final key = _storageKey(userId);

    final data = _prefs.getStringList(key) ?? _prefs.getStringList('chatbot_conversations_$userId');
    List<ChatConversation> current = [];
    if (data != null) {
      current = data.map((e) => ChatConversation.fromMap(json.decode(e))).toList();
    }

    current.removeWhere((c) => c.id == conversationId);
    final updatedData = current.map((c) => json.encode(c.toMap())).toList();
    await _prefs.setStringList(key, updatedData);
    await _prefs.setStringList('chatbot_conversations_$userId', updatedData);

    try {
      final db = await _appDatabase.database;
      await db.delete('chat_conversations', where: 'id = ?', whereArgs: [conversationId]);
    } catch (_) {}

    if (_firestore != null) {
      _firestore!
          .collection('users')
          .doc(cleanId)
          .collection('conversations')
          .doc(conversationId)
          .delete()
          .catchError((_) {});
    }
  }
}
