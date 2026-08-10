import 'user_model.dart';

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
  final UserModel? sender;
  final DateTime? createdAt;

  LastMessageModel({
    required this.id,
    required this.content,
    this.sender,
    this.createdAt,
  });

  factory LastMessageModel.fromJson(Map<String, dynamic> json) {
    return LastMessageModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      content: json['content'] ?? '',
      sender: json['sender'] != null ? UserModel.fromJson(json['sender']) : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }
}

class ConversationModel {
  final int id;
  final String type;
  final String? name;
  final UserModel? createdBy;
  final List<ConversationMemberModel> members;
  final LastMessageModel? lastMessage;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ConversationModel({
    required this.id,
    required this.type,
    this.name,
    this.createdBy,
    required this.members,
    this.lastMessage,
    this.createdAt,
    this.updatedAt,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      type: json['type'] ?? 'private',
      name: json['name'],
      createdBy: json['created_by'] != null
          ? UserModel.fromJson(json['created_by'])
          : null,
      members: json['members'] != null
          ? (json['members'] as List)
              .map((member) => ConversationMemberModel.fromJson(member))
              .toList()
          : [],
      lastMessage: json['last_message'] != null
          ? LastMessageModel.fromJson(json['last_message'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])
          : null,
    );
  }
}
