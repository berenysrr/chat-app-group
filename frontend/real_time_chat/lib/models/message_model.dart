import 'user_model.dart';

class MessageModel {
  final int id;
  final int? conversationId;
  final UserModel sender;
  final String content;
  final String messageType;
  final DateTime createdAt;
  final bool isRead;

  MessageModel({
    required this.id,
    this.conversationId,
    required this.sender,
    required this.content,
    this.messageType = 'text',
    required this.createdAt,
    this.isRead = false,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    final parsedCreatedAt = json['created_at'] != null
        ? DateTime.tryParse(json['created_at'])?.toLocal()
        : null;
    return MessageModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      conversationId: (json['conversation_id'] ?? json['conversation']) != null
          ? ((json['conversation_id'] ?? json['conversation']) is int
                ? (json['conversation_id'] ?? json['conversation'])
                : int.parse(
                    (json['conversation_id'] ?? json['conversation'])
                        .toString(),
                  ))
          : null,
      sender: json['sender'] != null
          ? UserModel.fromJson(json['sender'])
          : UserModel(id: 0, username: 'Unknown', email: ''),
      content: json['content'] ?? '',
      messageType: json['message_type'] ?? 'text',
      createdAt: parsedCreatedAt ?? DateTime.now(),
      isRead: json['is_read_by_me'] ?? json['is_read'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender': sender.toJson(),
      'content': content,
      'message_type': messageType,
      'created_at': createdAt.toIso8601String(),
      'is_read': isRead,
    };
  }
}
