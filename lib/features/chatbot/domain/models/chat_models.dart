import 'package:equatable/equatable.dart';

enum ChatRole { user, assistant }

class ChatMessage extends Equatable {
  final String text;
  final ChatRole role;
  final DateTime timestamp;

  const ChatMessage({
    required this.text,
    required this.role,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [text, role, timestamp];

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'role': role.name,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      text: map['text'],
      role: ChatRole.values.byName(map['role']),
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}

class ChatConversation extends Equatable {
  final String id;
  final String userId;
  final String title;
  final List<ChatMessage> messages;
  final DateTime lastUpdated;

  const ChatConversation({
    required this.id,
    required this.userId,
    required this.title,
    required this.messages,
    required this.lastUpdated,
  });

  @override
  List<Object?> get props => [id, userId, title, messages, lastUpdated];

  ChatConversation copyWith({
    String? id,
    String? userId,
    String? title,
    List<ChatMessage>? messages,
    DateTime? lastUpdated,
  }) {
    return ChatConversation(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'messages': messages.map((m) => m.toMap()).toList(),
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory ChatConversation.fromMap(Map<String, dynamic> map) {
    return ChatConversation(
      id: map['id'],
      userId: map['userId'],
      title: map['title'],
      messages: List<ChatMessage>.from(
        map['messages']?.map((m) => ChatMessage.fromMap(m)) ?? [],
      ),
      lastUpdated: DateTime.parse(map['lastUpdated']),
    );
  }
}
