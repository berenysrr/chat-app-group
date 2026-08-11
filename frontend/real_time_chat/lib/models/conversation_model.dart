import 'user_model.dart';

DateTime? _parseLocalDateTime(Object? value) {
  if (value == null) return null;
  final parsed = DateTime.tryParse(value.toString());
  if (parsed == null) return null;
  return parsed.isUtc ? parsed.toLocal() : parsed;
}

class ConversationMemberModel {
  final int id;
  final UserModel user;
  final String role;

  ConversationMemberModel({
    required this.id,
    required this.user,
    required this.role,
  });

  factory ConversationMemberModel.fromJson(Map<String, dynamic> json) {
    return ConversationMemberModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      user: UserModel.fromJson(json['user']),
      role: json['role'] ?? 'member',
    );
  }
}

class LastMessageModel {
  final int id;
  final String content;
  final String messageType;
  final UserModel? sender;
  final DateTime? createdAt;
  final int readCount;
  final bool isReadByMe;

  LastMessageModel({
    required this.id,
    required this.content,
    this.messageType = 'text',
    this.sender,
    this.createdAt,
    this.readCount = 0,
    this.isReadByMe = false,
  });

  LastMessageModel copyWith({int? readCount}) => LastMessageModel(
    id: id,
    content: content,
    messageType: messageType,
    sender: sender,
    createdAt: createdAt,
    readCount: readCount ?? this.readCount,
    isReadByMe: isReadByMe,
  );

  factory LastMessageModel.fromJson(Map<String, dynamic> json) {
    return LastMessageModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      content: json['content'] ?? '',
      messageType: json['message_type'] ?? 'text',
      sender: json['sender'] != null
          ? UserModel.fromJson(json['sender'])
          : null,
      createdAt: _parseLocalDateTime(json['created_at']),
      readCount: json['read_count'] is int
          ? json['read_count'] as int
          : int.tryParse('${json['read_count'] ?? 0}') ?? 0,
      isReadByMe: json['is_read_by_me'] == true,
    );
  }
}

class ConversationModel {
  final int id;
  final String type;
  final String? name;
  final int? createdBy;
  final List<ConversationMemberModel> members;
  final LastMessageModel? lastMessage;
  final int unreadCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ConversationModel({
    required this.id,
    required this.type,
    this.name,
    this.createdBy,
    required this.members,
    this.lastMessage,
    this.unreadCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  ConversationModel copyWith({LastMessageModel? lastMessage}) =>
      ConversationModel(
        id: id,
        type: type,
        name: name,
        createdBy: createdBy,
        members: members,
        lastMessage: lastMessage ?? this.lastMessage,
        unreadCount: unreadCount,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      type: json['type'] ?? 'private',
      name: json['name'],
      // Conversation API'si created_by alanını kullanıcı nesnesi değil,
      // kullanıcı kimliği olarak döndürür.
      createdBy: json['created_by'] == null
          ? null
          : (json['created_by'] is int
                ? json['created_by'] as int
                : int.tryParse(json['created_by'].toString())),
      members: json['members'] != null
          ? (json['members'] as List)
                .map((member) => ConversationMemberModel.fromJson(member))
                .toList()
          : [],
      lastMessage: json['last_message'] != null
          ? LastMessageModel.fromJson(json['last_message'])
          : null,
      unreadCount: json['unread_count'] is int
          ? json['unread_count'] as int
          : int.tryParse('${json['unread_count'] ?? 0}') ?? 0,
      createdAt: _parseLocalDateTime(json['created_at']),
      updatedAt: _parseLocalDateTime(json['updated_at']),
    );
  }
}

ConversationModel applyReadReceiptToConversation(
  ConversationModel conversation, {
  required int messageId,
  required int currentUserId,
}) {
  final lastMessage = conversation.lastMessage;
  if (lastMessage == null ||
      lastMessage.id != messageId ||
      lastMessage.sender?.id != currentUserId ||
      lastMessage.readCount > 0) {
    return conversation;
  }
  return conversation.copyWith(lastMessage: lastMessage.copyWith(readCount: 1));
}
