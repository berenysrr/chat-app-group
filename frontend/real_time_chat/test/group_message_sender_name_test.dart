import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_time_chat/chat/models/chat_models.dart';
import 'package:real_time_chat/chat/screens/chat_detail_screen.dart';
import 'package:real_time_chat/chat/widgets/chat_widgets.dart';

void main() {
  final incoming = ChatMessage(
    id: 1,
    clientMessageId: 'group-message-1',
    conversationId: 3,
    sender: const ChatUser(
      id: 2,
      username: 'Ahmet Yılmaz',
      email: 'ahmet@example.com',
    ),
    content: 'Merhaba arkadaşlar',
    createdAt: DateTime(2026, 8, 11, 12, 13),
  );

  test('sender name is only returned for incoming group messages', () {
    expect(
      senderNameForMessage(
        message: incoming,
        currentUserId: 1,
        showSenderNames: true,
      ),
      'Ahmet Yılmaz',
    );
    expect(
      senderNameForMessage(
        message: incoming,
        currentUserId: 1,
        showSenderNames: false,
      ),
      isNull,
    );
    expect(
      senderNameForMessage(
        message: incoming,
        currentUserId: 2,
        showSenderNames: true,
      ),
      isNull,
    );
  });

  testWidgets('message bubble renders sender above incoming group message', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageBubble(
            message: incoming,
            isMine: false,
            showTail: true,
            senderName: 'Ahmet Yılmaz',
          ),
        ),
      ),
    );

    expect(find.text('Ahmet Yılmaz'), findsOneWidget);
    expect(find.text('Merhaba arkadaşlar'), findsOneWidget);
    final text = tester.widget<Text>(find.text('Ahmet Yılmaz'));
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
  });

  test('sender name falls back to email', () {
    final withoutUsername = ChatMessage(
      id: 2,
      clientMessageId: 'group-message-2',
      conversationId: 3,
      sender: const ChatUser(id: 3, username: ' ', email: 'ayse@example.com'),
      content: 'Toplantı saat kaçta?',
      createdAt: DateTime(2026, 8, 11, 12, 14),
    );

    expect(
      senderNameForMessage(
        message: withoutUsername,
        currentUserId: 1,
        showSenderNames: true,
      ),
      'ayse@example.com',
    );
  });

  test('REST and WebSocket payload sender is preserved by shared parser', () {
    ChatMessage parse(int id, String username) => ChatMessage.fromJson({
      'id': id,
      'client_message_id': 'server-$id',
      'conversation_id': 3,
      'sender': {
        'id': id,
        'username': username,
        'email': '$username@example.com',
        'avatar': null,
      },
      'content': 'Mesaj $id',
      'message_type': 'text',
      'created_at': '2026-08-11T12:15:00Z',
    });

    final beren = parse(2, 'Beren');
    final rumeysa = parse(3, 'Rümeysa');

    expect(beren.senderName, 'Beren');
    expect(rumeysa.senderName, 'Rümeysa');
  });
}
