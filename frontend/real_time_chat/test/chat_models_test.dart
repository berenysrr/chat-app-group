import 'package:flutter_test/flutter_test.dart';
import 'package:real_time_chat/chat/models/chat_models.dart';

void main() {
  test('message.new contract payload parses into a typed message', () {
    final message = ChatMessage.fromJson({
      'id': 15,
      'client_message_id': '550e8400-e29b-41d4-a716-446655440000',
      'conversation_id': 3,
      'sender': {'id': 1, 'username': 'user1', 'avatar': null},
      'content': 'Merhaba',
      'message_type': 'text',
      'created_at': '2026-08-10T10:30:00Z',
    });
    expect(message.id, 15);
    expect(message.sender.username, 'user1');
    expect(message.content, 'Merhaba');
  });

  test('presence contract parses last seen timestamp', () {
    final event = PresenceEvent.fromJson({
      'user_id': 1,
      'username': 'user1',
      'last_seen': '2026-08-10T10:40:00Z',
    }, isOnline: false);
    expect(event.isOnline, isFalse);
    expect(event.lastSeen, isNotNull);
  });
}
