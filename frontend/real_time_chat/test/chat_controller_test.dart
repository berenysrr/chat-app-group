import 'package:flutter_test/flutter_test.dart';
import 'package:real_time_chat/chat/controllers/chat_controller.dart';
import 'package:real_time_chat/chat/models/chat_models.dart';
import 'package:real_time_chat/chat/services/mock_web_socket_service.dart';

void main() {
  const me = ChatUser(id: 1, username: 'Sen');
  const peer = ChatUser(id: 2, username: 'Ece');

  ChatController buildController(
    MockWebSocketService socket, {
    int unread = 0,
  }) {
    return ChatController(
      socket: socket,
      currentUser: me,
      peer: peer,
      conversationId: 3,
      initialMessages: const [],
      initialUnreadCount: unread,
    );
  }

  test('initialize and socket connect are idempotent', () async {
    final socket = MockWebSocketService();
    final controller = buildController(socket);
    await Future.wait([controller.initialize(), controller.initialize()]);
    expect(socket.connectCalls, 1);
    controller.dispose();
  });

  test('empty message is rejected and content is trimmed', () async {
    final socket = MockWebSocketService();
    final controller = buildController(socket);
    await controller.initialize();
    expect(controller.send('   '), isFalse);
    expect(controller.messages, isEmpty);
    expect(controller.send('  Merhaba  '), isTrue);
    expect(controller.messages.single.content, 'Merhaba');
    controller.dispose();
  });

  test('failed optimistic message remains available for retry', () async {
    final socket = MockWebSocketService();
    final controller = buildController(socket);
    await controller.initialize();
    socket.failNextSend = true;
    expect(controller.send('Kaybolmasın'), isFalse);
    expect(controller.messages.single.status, MessageStatus.failed);
    controller.retryMessage(controller.messages.single.clientMessageId);
    expect(controller.messages.single.status, MessageStatus.pending);
    controller.dispose();
  });

  test('duplicate and wrong-conversation messages are ignored', () async {
    final socket = MockWebSocketService();
    final controller = buildController(socket);
    await controller.initialize();
    final message = ChatMessage(
      id: 10,
      clientMessageId: 'same',
      conversationId: 3,
      sender: peer,
      content: 'Tek mesaj',
      createdAt: DateTime.now(),
    );
    socket.emitMessage(message);
    socket.emitMessage(message);
    socket.emitMessage(
      ChatMessage(
        id: 11,
        clientMessageId: 'other',
        conversationId: 99,
        sender: peer,
        content: 'Yanlış oda',
        createdAt: DateTime.now(),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(controller.messages, hasLength(1));
    expect(controller.unreadCount, 1);
    controller.dispose();
  });

  testWidgets('typing start is sent once and stop is debounced', (
    tester,
  ) async {
    final socket = MockWebSocketService();
    final controller = buildController(socket);
    final initialization = controller.initialize();
    await tester.pump(const Duration(milliseconds: 250));
    await initialization;
    controller.onInputChanged('m');
    controller.onInputChanged('me');
    controller.onInputChanged('mer');
    expect(socket.typingStartCalls, 1);
    await tester.pump(const Duration(milliseconds: 901));
    expect(socket.typingStopCalls, 1);
    controller.dispose();
  });

  testWidgets('foreign typing is ignored and peer typing times out', (
    tester,
  ) async {
    final socket = MockWebSocketService();
    final controller = buildController(socket);
    final initialization = controller.initialize();
    await tester.pump(const Duration(milliseconds: 250));
    await initialization;
    socket.emitTyping(true, userId: 999);
    await tester.pump();
    expect(controller.peerIsTyping, isFalse);
    socket.emitTyping(true);
    await tester.pump();
    expect(controller.peerIsTyping, isTrue);
    await tester.pump(const Duration(seconds: 5));
    expect(controller.peerIsTyping, isFalse);
    controller.dispose();
  });

  test(
    'mock replies use contract models and a deterministic sequence',
    () async {
      final socket = MockWebSocketService(
        conversationId: 3,
        peerId: 2,
        peerUsername: 'Ece',
      );
      final replies = <ChatMessage>[];
      final subscription = socket.listenMessage().listen(replies.add);
      await socket.connect();

      socket.sendMessage(clientMessageId: 'first', content: 'İlk mesaj');
      socket.sendMessage(clientMessageId: 'second', content: 'İkinci mesaj');
      await Future<void>.delayed(const Duration(milliseconds: 1100));

      expect(replies.map((message) => message.content), [
        'Tamamdır, teşekkürler.',
        'Dosyayı birazdan kontrol edeceğim.',
      ]);
      expect(replies.every((message) => message.conversationId == 3), isTrue);
      expect(replies.every((message) => message.sender.id == 2), isTrue);
      expect(replies.map((message) => message.id).toSet(), hasLength(2));
      expect(
        replies.map((message) => message.clientMessageId).toSet(),
        hasLength(2),
      );

      await subscription.cancel();
      await socket.dispose();
    },
  );

  test('read is sent once only while conversation is visible', () async {
    final socket = MockWebSocketService();
    final controller = buildController(socket);
    await controller.initialize();
    controller.openConversation();
    socket.emitMessage(
      ChatMessage(
        id: 20,
        clientMessageId: 'visible',
        conversationId: 3,
        sender: peer,
        content: 'Göründü',
        createdAt: DateTime.now(),
      ),
    );
    socket.emitMessage(
      ChatMessage(
        id: 20,
        clientMessageId: 'visible',
        conversationId: 3,
        sender: peer,
        content: 'Göründü',
        createdAt: DateTime.now(),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(socket.readCalls, 1);
    expect(controller.unreadCount, 0);
    controller.closeConversation();
    socket.emitMessage(
      ChatMessage(
        id: 21,
        clientMessageId: 'hidden',
        conversationId: 3,
        sender: peer,
        content: 'Okunmadı',
        createdAt: DateTime.now(),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(socket.readCalls, 1);
    expect(controller.unreadCount, 1);
    controller.dispose();
  });
}
