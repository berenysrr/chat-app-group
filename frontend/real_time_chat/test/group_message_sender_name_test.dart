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

  testWidgets('message bubble renders sender outside incoming group bubble', (
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
    expect(text.textAlign, TextAlign.left);
    expect(
      find.ancestor(
        of: find.byKey(const Key('group-message-sender-name')),
        matching: find.byType(AnimatedContainer),
      ),
      findsNothing,
    );
  });

  test('only directly consecutive messages share a sender group', () {
    ChatMessage message(int id, int senderId, DateTime createdAt) =>
        ChatMessage(
          id: id,
          clientMessageId: 'message-$id',
          conversationId: 3,
          sender: ChatUser(id: senderId, username: 'User $senderId'),
          content: 'Mesaj $id',
          createdAt: createdAt,
        );

    final berenA = message(1, 2, DateTime(2026, 8, 11, 14));
    final berenB = message(2, 2, DateTime(2026, 8, 11, 14, 1));
    final mine = message(3, 1, DateTime(2026, 8, 11, 14, 2));
    final rumeysa = message(4, 3, DateTime(2026, 8, 11, 14, 3));
    final berenC = message(5, 2, DateTime(2026, 8, 11, 14, 4));

    bool show(ChatMessage current, ChatMessage? previous) =>
        shouldShowSenderNameForMessage(
          message: current,
          previousMessage: previous,
          currentUserId: 1,
          showSenderNames: true,
        );

    expect(show(berenA, null), isTrue);
    expect(show(berenB, berenA), isFalse);
    expect(show(berenC, rumeysa), isTrue);
    expect(show(berenC, mine), isTrue);
    expect(show(mine, berenA), isFalse);

    final chronological = [berenA, berenB, rumeysa, berenC];
    final currentIndexForFirstReverseRow = chronological.length - 1;
    expect(
      previousVisibleMessageForIndex(
        chronological,
        currentIndexForFirstReverseRow,
      ),
      same(rumeysa),
    );
  });

  test('date separator starts a new sender group', () {
    final yesterday = ChatMessage(
      id: 10,
      clientMessageId: 'yesterday',
      conversationId: 3,
      sender: const ChatUser(id: 2, username: 'Beren'),
      content: 'Dün',
      createdAt: DateTime(2026, 8, 10, 23, 59),
    );
    final today = ChatMessage(
      id: 11,
      clientMessageId: 'today',
      conversationId: 3,
      sender: const ChatUser(id: 2, username: 'Beren'),
      content: 'Bugün',
      createdAt: DateTime(2026, 8, 11, 0, 1),
    );

    expect(
      shouldShowSenderNameForMessage(
        message: today,
        previousMessage: yesterday,
        currentUserId: 1,
        showSenderNames: true,
      ),
      isTrue,
    );
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
