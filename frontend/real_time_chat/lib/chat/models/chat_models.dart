enum MessageStatus { pending, sent, delivered, read, failed }

class ChatUser {
  const ChatUser({
    required this.id,
    required this.username,
    this.avatar,
    this.email,
    this.isOnline = false,
    this.lastSeen,
  });

  final int id;
  final String username;
  final String? avatar;
  final String? email;
  final bool isOnline;
  final DateTime? lastSeen;

  factory ChatUser.fromJson(Map<String, dynamic> json) => ChatUser(
    id: json['id'] as int,
    username: json['username'] as String,
    avatar: json['avatar'] as String?,
    email: json['email'] as String?,
    isOnline: json['is_online'] == true,
    lastSeen: json['last_seen'] is String
        ? DateTime.tryParse(json['last_seen'] as String)?.toLocal()
        : null,
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

  ChatMessage copyWith({int? id, DateTime? createdAt, MessageStatus? status}) =>
      ChatMessage(
        id: id ?? this.id,
        clientMessageId: clientMessageId,
        conversationId: conversationId,
        sender: sender,
        content: content,
        messageType: messageType,
        createdAt: createdAt ?? this.createdAt,
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

enum ConversationType { private, group }

class Conversation {
  const Conversation({
    required this.id,
    required this.type,
    required this.createdBy,
    required this.members,
    required this.updatedAt,
    this.name,
    this.lastMessage,
  });

  final int id;
  final ConversationType type;
  final String? name;
  final int createdBy;
  final List<ChatUser> members;
  final ChatMessage? lastMessage;
  final DateTime updatedAt;

  ChatUser? peerFor(int currentUserId) {
    for (final member in members) {
      if (member.id != currentUserId) return member;
    }
    return null;
  }

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final rawMembers = json['members'];
    final members = rawMembers is List
        ? rawMembers
              .whereType<Map>()
              .map((value) => ChatUser.fromJson(value.cast<String, dynamic>()))
              .toList()
        : <ChatUser>[];
    final rawLastMessage = json['last_message'];
    return Conversation(
      id: json['id'] as int,
      type: json['type'] == 'group'
          ? ConversationType.group
          : ConversationType.private,
      name: json['name'] as String?,
      createdBy: json['created_by'] as int,
      members: members,
      lastMessage: rawLastMessage is Map
          ? ChatMessage.fromJson(rawLastMessage.cast<String, dynamic>())
          : null,
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    );
  }
}

class MessagePage {
  const MessagePage({required this.messages, required this.hasMore});
  final List<ChatMessage> messages;
  final bool hasMore;
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
    this.lastMessageIsMine = false,
    this.lastMessageStatus = MessageStatus.delivered,
  });
  final int conversationId;
  final ChatUser user;
  final String lastMessage;
  final DateTime updatedAt;
  final int unreadCount;
  final bool lastMessageIsMine;
  final MessageStatus lastMessageStatus;
}
