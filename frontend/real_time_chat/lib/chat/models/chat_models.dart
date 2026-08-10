enum MessageStatus { pending, sent, delivered, read, failed }

class ChatUser {
  const ChatUser({required this.id, required this.username, this.avatar});

  final int id;
  final String username;
  final String? avatar;

  factory ChatUser.fromJson(Map<String, dynamic> json) => ChatUser(
    id: json['id'] as int,
    username: json['username'] as String,
    avatar: json['avatar'] as String?,
  );
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.clientMessageId,
    required this.conversationId,
    required this.sender,
    required this.content,
    required this.createdAt,
    this.messageType = 'text',
    this.status = MessageStatus.delivered,
  });

  final int? id;
  final String clientMessageId;
  final int conversationId;
  final ChatUser sender;
  final String content;
  final String messageType;
  final DateTime createdAt;
  final MessageStatus status;

  bool isMine(int currentUserId) => sender.id == currentUserId;

  ChatMessage copyWith({int? id, MessageStatus? status}) => ChatMessage(
    id: id ?? this.id,
    clientMessageId: clientMessageId,
    conversationId: conversationId,
    sender: sender,
    content: content,
    messageType: messageType,
    createdAt: createdAt,
    status: status ?? this.status,
  );

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as int,
    clientMessageId: json['client_message_id'] as String,
    conversationId: json['conversation_id'] as int,
    sender: ChatUser.fromJson(json['sender'] as Map<String, dynamic>),
    content: json['content'] as String,
    messageType: json['message_type'] as String,
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
  );
}

class MessageAcknowledgement {
  const MessageAcknowledgement({
    required this.clientMessageId,
    required this.messageId,
    required this.conversationId,
    required this.createdAt,
  });
  final String clientMessageId;
  final int messageId;
  final int conversationId;
  final DateTime createdAt;
  factory MessageAcknowledgement.fromJson(Map<String, dynamic> json) =>
      MessageAcknowledgement(
        clientMessageId: json['client_message_id'] as String,
        messageId: json['message_id'] as int,
        conversationId: json['conversation_id'] as int,
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      );
}

class TypingEvent {
  const TypingEvent({
    required this.userId,
    required this.isTyping,
    this.username,
  });
  final int userId;
  final String? username;
  final bool isTyping;
  factory TypingEvent.fromJson(
    Map<String, dynamic> json, {
    required bool isTyping,
  }) => TypingEvent(
    userId: json['user_id'] as int,
    username: json['username'] as String?,
    isTyping: isTyping,
  );
}

class PresenceEvent {
  const PresenceEvent({
    required this.userId,
    required this.username,
    required this.isOnline,
    this.lastSeen,
  });
  final int userId;
  final String username;
  final bool isOnline;
  final DateTime? lastSeen;
  factory PresenceEvent.fromJson(
    Map<String, dynamic> json, {
    required bool isOnline,
  }) => PresenceEvent(
    userId: json['user_id'] as int,
    username: json['username'] as String,
    isOnline: isOnline,
    lastSeen: json['last_seen'] == null
        ? null
        : DateTime.parse(json['last_seen'] as String).toLocal(),
  );
}

class ReadEvent {
  const ReadEvent({
    required this.messageId,
    required this.userId,
    required this.readAt,
  });
  final int messageId;
  final int userId;
  final DateTime readAt;
  factory ReadEvent.fromJson(Map<String, dynamic> json) => ReadEvent(
    messageId: json['message_id'] as int,
    userId: json['user_id'] as int,
    readAt: DateTime.parse(json['read_at'] as String).toLocal(),
  );
}

class ChatPreview {
  const ChatPreview({
    required this.conversationId,
    required this.user,
    required this.lastMessage,
    required this.updatedAt,
    this.unreadCount = 0,
  });
  final int conversationId;
  final ChatUser user;
  final String lastMessage;
  final DateTime updatedAt;
  final int unreadCount;
}
