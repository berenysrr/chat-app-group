import 'package:dio/dio.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';
import 'api_client.dart';

class ChatService {
  final ApiClient _client = ApiClient();

  Future<List<ConversationModel>> getConversations() async {
    try {
      final response = await _client.dio.get('/api/conversations/');
      final results = response.data is Map
          ? response.data['results']
          : response.data;
      if (response.statusCode == 200 && results is List) {
        return results.map((json) => ConversationModel.fromJson(json)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<ConversationModel?> createConversation({
    required String type,
    required List<int> memberIds,
    String? name,
  }) async {
    try {
      final data = <String, dynamic>{'type': type, 'member_ids': memberIds};
      if (name != null && name.isNotEmpty) data['name'] = name;

      final response = await _client.dio.post(
        '/api/conversations/',
        data: data,
      );
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          response.data != null) {
        return ConversationModel.fromJson(response.data);
      }
    } on DioException catch (error) {
      final message =
          error.response?.data?['detail'] ?? 'Could not create conversation.';
      throw Exception(message);
    }
    return null;
  }

  Future<List<MessageModel>> getMessages(
    int conversationId, {
    int? afterId,
    int? beforeId,
    int? pageSize,
  }) async {
    try {
      final response = await _client.dio.get(
        '/api/conversations/$conversationId/messages/',
        queryParameters: {
          'after_id': ?afterId,
          'before_id': ?beforeId,
          'page_size': ?pageSize,
        },
      );
      final results = response.data is Map
          ? response.data['results']
          : response.data;
      if (response.statusCode == 200 && results is List) {
        return results.map((json) => MessageModel.fromJson(json)).toList();
      }
    } catch (_) {}
    return [];
  }
}
