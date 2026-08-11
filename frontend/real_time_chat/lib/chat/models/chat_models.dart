import '../../services/api_client.dart';
import '../../utils/avatar_url.dart';

enum MessageStatus { pending, sent, delivered, read, failed }

int _requiredInt(Object? value, String field) {
  if (value is int) return value;
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed != null) return parsed;
  throw FormatException('$field geçerli bir sayı değil.');
}

String _requiredString(Object? value, String field) {
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('$field geçerli bir metin değil.');
}

Map<String, dynamic> _requiredMap(Object? value, String field) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  throw FormatException('$field JSON nesnesi değil.');
}

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
    id: _requiredInt(json['id'], 'user.id'),
    username: _requiredString(json['username'], 'user.username'),
    avatar: resolveAvatarUrl(
      json['avatar']?.toString(),
      baseUrl: ApiClient.baseUrl,
    ),
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

  String get senderName {
    final username = sender.username.trim();
    if (username.isNotEmpty) return username;
    final email = sender.email?.trim() ?? '';
    return email.isNotEmpty ? email : 'Kullanıcı';
  }

  ChatMessage copyWith({
    int? id,
    DateTime? createdAt,
    MessageStatus? status,
    String? content,
    String? messageType,
  }) => ChatMessage(
    id: id ?? this.id,
    clientMessageId: clientMessageId,
    conversationId: conversationId,
    sender: sender,
    content: content ?? this.content,
    messageType: messageType ?? this.messageType,
    createdAt: createdAt ?? this.createdAt,
    status: status ?? this.status,
  );

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: _requiredInt(json['id'], 'message.id'),
    clientMessageId: _requiredString(
      json['client_message_id'],
      'message.client_message_id',
    ),
    conversationId: _requiredInt(
      json['conversation_id'] ?? json['conversation'],
      'message.conversation',
    ),
    sender: ChatUser.fromJson(_requiredMap(json['sender'], 'message.sender')),
    content: _requiredString(json['content'], 'message.content'),
    messageType: (json['message_type'] as String?) ?? 'text',
    createdAt: DateTime.parse(
      _requiredString(json['created_at'], 'message.created_at'),
    ).toLocal(),
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
        ? rawMembers.whereType<Map>().map((value) {
            final member = value.cast<String, dynamic>();
            // Conversation API'si üyeyi { user: {...}, role: ... } olarak
            // döndürür; WebSocket ise kullanıcıyı doğrudan döndürür.
            return ChatUser.fromJson(
              _requiredMap(member['user'] ?? member, 'conversation.member'),
            );
          }).toList()
        : <ChatUser>[];
    final rawLastMessage = json['last_message'];
    return Conversation(
      id: _requiredInt(json['id'], 'conversation.id'),
      type: json['type'] == 'group'
          ? ConversationType.group
          : ConversationType.private,
      name: json['name'] as String?,
      createdBy: _requiredInt(json['created_by'], 'conversation.created_by'),
      members: members,
      lastMessage: rawLastMessage is Map
          ? ChatMessage.fromJson(rawLastMessage.cast<String, dynamic>())
          : null,
      updatedAt: DateTime.parse(
        _requiredString(json['updated_at'], 'conversation.updated_at'),
      ).toLocal(),
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
        clientMessageId: _requiredString(
          json['client_message_id'],
          'ack.client_message_id',
        ),
        messageId: _requiredInt(json['message_id'], 'ack.message_id'),
        conversationId: _requiredInt(
          json['conversation_id'],
          'ack.conversation_id',
        ),
        createdAt: DateTime.parse(
          _requiredString(json['created_at'], 'ack.created_at'),
        ).toLocal(),
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
    userId: _requiredInt(json['user_id'], 'typing.user_id'),
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
    userId: _requiredInt(json['user_id'], 'presence.user_id'),
    username: _requiredString(json['username'], 'presence.username'),
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
    messageId: _requiredInt(json['message_id'], 'read.message_id'),
    userId: _requiredInt(json['user_id'], 'read.user_id'),
    readAt: DateTime.parse(
      _requiredString(json['read_at'], 'read.read_at'),
    ).toLocal(),
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
