import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:real_time_chat/chat/services/web_socket_service.dart';

void main() {
  test(
    'conversation socket URI encodes token and avoids duplicate slashes',
    () {
      final uri = ContractWebSocketService.buildUri(
        baseUrl: 'ws://localhost:8000/',
        conversationId: 42,
        accessToken: 'token +/?&',
      );

      expect(uri.toString(), contains('/ws/chat/42/?token='));
      expect(uri.queryParameters['token'], 'token +/?&');
      expect(uri.path, '/ws/chat/42/');
    },
  );

  test('production rejects insecure websocket URL', () {
    expect(
      () => ContractWebSocketService.buildUri(
        baseUrl: 'ws://example.com',
        conversationId: 1,
        accessToken: 'token',
        production: true,
      ),
      throwsArgumentError,
    );
  });

  test('event decoder rejects malformed envelopes', () {
    expect(SocketEvent.decode('not-json'), isNull);
    expect(SocketEvent.decode('{"data":{}}'), isNull);
    expect(SocketEvent.decode('{"type":"message.new","data":[]}'), isNull);
    expect(SocketEvent.decode('{"type":"unknown","data":{}}')?.type, 'unknown');
  });

  test('message ack and message new are routed to typed streams', () async {
    final service = ContractWebSocketService(
      conversationId: 3,
      baseUrl: 'ws://localhost:8000',
      accessTokenProvider: () async => 'token',
    );
    addTearDown(service.dispose);
    final ackFuture = service.listenAcknowledgement().first;
    final messageFuture = service.listenMessage().first;

    service.handleFrameForTest(
      jsonEncode({
        'type': 'message.ack',
        'data': {
          'client_message_id': 'client-1',
          'message_id': 15,
          'conversation_id': 3,
          'created_at': '2026-08-10T10:30:00Z',
        },
      }),
    );
    service.handleFrameForTest(
      jsonEncode({
        'type': 'message.new',
        'data': {
          'id': 15,
          'client_message_id': 'client-1',
          'conversation_id': 3,
          'sender': {'id': 1, 'username': 'user1', 'avatar': null},
          'reply_to': {
            'id': 12,
            'sender': {'id': 2, 'username': 'user2', 'avatar': null},
            'content': 'Yarın geliyor musun?',
            'message_type': 'text',
          },
          'content': 'Merhaba',
          'message_type': 'text',
          'created_at': '2026-08-10T10:30:00Z',
        },
      }),
    );

    expect((await ackFuture.timeout(const Duration(seconds: 1))).messageId, 15);
    final message = await messageFuture.timeout(const Duration(seconds: 1));
    expect(message.content, 'Merhaba');
    expect(message.replyTo?.id, 12);
    expect(message.replyTo?.senderName, 'user2');
  });

  test('message read carries aggregate group read state', () async {
    final service = ContractWebSocketService(
      conversationId: 3,
      baseUrl: 'ws://localhost:8000',
      accessTokenProvider: () async => 'token',
    );
    addTearDown(service.dispose);
    final readFuture = service.listenMessageRead().first;

    service.handleFrameForTest(
      jsonEncode({
        'type': 'message.read',
        'data': {
          'message_id': 15,
          'user_id': 2,
          'read_at': '2026-08-10T10:35:00Z',
          'read_count': 1,
          'recipient_count': 2,
          'is_read_by_all': false,
        },
      }),
    );

    final read = await readFuture.timeout(const Duration(seconds: 1));
    expect(read.messageId, 15);
    expect(read.readCount, 1);
    expect(read.recipientCount, 2);
    expect(read.isReadByAll, isFalse);
  });
}
