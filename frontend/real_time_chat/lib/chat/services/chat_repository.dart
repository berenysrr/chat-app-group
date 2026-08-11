import '../../network/api_client.dart';
import '../models/chat_models.dart';

class ChatRepository {
  ChatRepository(this.client);
  final AuthenticatedApiClient client;

  Future<ChatUser> currentUser() async =>
      ChatUser.fromJson(_map(await client.get('users/me/')));

  Future<List<ChatUser>> searchUsers(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty) return const [];
    final body = _map(await client.get('users/', query: {'search': query}));
    return _list(
      body['results'],
    ).map((item) => ChatUser.fromJson(_map(item))).toList();
  }

  Future<List<Conversation>> conversations() async {
    final body = _map(await client.get('conversations/'));
    final result = _list(
      body['results'],
    ).map((item) => Conversation.fromJson(_map(item))).toList();
    result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return result;
  }

  Future<Conversation> conversation(int id) async {
    _validateId(id);
    return Conversation.fromJson(_map(await client.get('conversations/$id/')));
  }

  Future<Conversation> createPrivateConversation(int memberId) async {
    _validateId(memberId);
    return Conversation.fromJson(
      _map(
        await client.post(
          'conversations/',
          body: {
            'type': 'private',
            'member_ids': [memberId],
          },
        ),
      ),
    );
  }

  Future<Conversation> createGroupConversation({
    required String name,
    required List<int> memberIds,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) throw ArgumentError('Grup adı boş olamaz.');
    if (memberIds.isEmpty || memberIds.length > 4) {
      throw ArgumentError('Gruba en fazla 4 kişi eklenebilir (siz dahil 5 kişi).');
    }
    for (final id in memberIds) {
      _validateId(id);
    }
    return Conversation.fromJson(
      _map(
        await client.post(
          'conversations/',
          body: {'type': 'group', 'name': cleanName, 'member_ids': memberIds},
        ),
      ),
    );
  }

  Future<MessagePage> messages(
    int conversationId, {
    int? beforeId,
    int? afterId,
    int page = 1,
    int pageSize = 30,
  }) async {
    _validateId(conversationId);
    if (beforeId != null && afterId != null) {
      throw ArgumentError('before_id ve after_id birlikte kullanılamaz.');
    }
    final body = await client.get(
      'conversations/$conversationId/messages/',
      query: {
        if (beforeId == null && afterId == null) 'page': '$page',
        'page_size': '$pageSize',
        if (beforeId != null) 'before_id': '$beforeId',
        if (afterId != null) 'after_id': '$afterId',
      },
    );
    final map = body is Map ? _map(body) : <String, dynamic>{};
    final raw = map['results'] is List ? _list(map['results']) : _list(body);
    final messages =
        raw.map((item) => ChatMessage.fromJson(_map(item))).toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return MessagePage(
      messages: messages,
      hasMore: map['next'] != null || messages.length >= pageSize,
    );
  }

  Future<void> markConversationRead(int conversationId) async {
    _validateId(conversationId);
    await client.post('conversations/$conversationId/read/');
  }

  static void _validateId(int id) {
    if (id <= 0) throw ArgumentError.value(id, 'id', 'Pozitif olmalı');
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();
    throw const FormatException('JSON object bekleniyordu.');
  }

  static List<dynamic> _list(Object? value) {
    if (value is List) return value;
    throw const FormatException('JSON list bekleniyordu.');
  }
}
