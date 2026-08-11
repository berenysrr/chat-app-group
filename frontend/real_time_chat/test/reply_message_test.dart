import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_time_chat/chat/controllers/chat_controller.dart';
import 'package:real_time_chat/chat/models/chat_models.dart';
import 'package:real_time_chat/chat/services/mock_web_socket_service.dart';
import 'package:real_time_chat/chat/widgets/chat_widgets.dart';

void main() {
  const me = ChatUser(id: 1, username: 'Siz');
  const beren = ChatUser(id: 2, username: 'Beren');
  final original = ChatMessage(
    id: 12,
    clientMessageId: 'original-12',
    conversationId: 3,
    sender: beren,
    content: 'Yarın saat kaçta buluşuyoruz?',
    createdAt: DateTime(2026, 8, 11, 14),
  );

  test('REST ve WebSocket ortak parser reply_to bilgisini korur', () {
    final message = ChatMessage.fromJson({
      'id': 13,
      'client_message_id': 'reply-13',
      'conversation_id': 3,
      'sender': {'id': 1, 'username': 'Siz'},
      'content': '14:00 uygun',
      'message_type': 'text',
      'created_at': '2026-08-11T14:01:00Z',
      'reply_to': {
        'id': 12,
        'sender': {'id': 2, 'username': 'Beren'},
        'content': 'Yarın saat kaçta buluşuyoruz?',
        'message_type': 'text',
      },
    });

    expect(message.replyTo?.id, 12);
    expect(message.replyTo?.senderName, 'Beren');
    expect(message.replyTo?.content, 'Yarın saat kaçta buluşuyoruz?');
  });

  test(
    'optimistic reply özeti ve backend message id payloadı korunur',
    () async {
      final socket = MockWebSocketService(autoReplyEnabled: false);
      final controller = ChatController(
        socket: socket,
        currentUser: me,
        peer: beren,
        conversationId: 3,
        initialMessages: [original],
      );
      await controller.initialize();

      expect(controller.send('14:00 uygun', replyTo: original), isTrue);
      final optimistic = controller.messages.last;
      expect(optimistic.replyTo?.id, 12);
      expect(optimistic.replyTo?.senderName, 'Beren');
      expect(socket.lastReplyToMessageId, 12);
      controller.dispose();
    },
  );

  testWidgets('reply bubble özeti render eder ve uzun basma action çalışır', (
    tester,
  ) async {
    var replied = false;
    final reply = ChatMessage(
      id: 13,
      clientMessageId: 'reply-13',
      conversationId: 3,
      sender: me,
      content: '14:00 uygun',
      createdAt: DateTime(2026, 8, 11, 14, 1),
      replyTo: ReplyMessageInfo.fromMessage(original),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageBubble(
            message: reply,
            isMine: true,
            showTail: true,
            onReply: () => replied = true,
          ),
        ),
      ),
    );

    expect(find.text('Beren'), findsOneWidget);
    expect(find.text('Yarın saat kaçta buluşuyoruz?'), findsOneWidget);
    expect(find.text('14:00 uygun'), findsOneWidget);
    await tester.longPress(find.byType(MessageBubble));
    expect(replied, isTrue);
  });

  testWidgets('input reply preview gösterilir ve iptal edilebilir', (
    tester,
  ) async {
    var cancelled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageInput(
            replyingTo: ReplyMessageInfo.fromMessage(original),
            onCancelReply: () => cancelled = true,
            onSend: (_, {messageType = 'text'}) => true,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('reply-input-preview')), findsOneWidget);
    expect(find.text('Beren'), findsOneWidget);
    await tester.tap(find.byKey(const Key('cancel-reply')));
    expect(cancelled, isTrue);
  });

  test('media reply kısa preview kullanır', () {
    const reply = ReplyMessageInfo(
      id: 20,
      sender: beren,
      content: 'data:audio/webm;base64,AAA',
      messageType: 'audio',
    );
    expect(replyPreviewText(reply), contains('Ses'));
  });
}
