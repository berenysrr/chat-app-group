import 'dart:async';

import '../models/chat_models.dart';
import 'web_socket_service.dart';

class MockWebSocketService implements WebSocketService {
  MockWebSocketService({this.conversationId = 3, this.currentUserId = 1});
  final int conversationId;
  final int currentUserId;
  var _nextId = 100;
  Timer? _typingTimer;
  final _states = StreamController<SocketConnectionState>.broadcast();
  final _messages = StreamController<ChatMessage>.broadcast();
  final _acks = StreamController<MessageAcknowledgement>.broadcast();
  final _reads = StreamController<ReadEvent>.broadcast();
  final _typing = StreamController<TypingEvent>.broadcast();
  final _online = StreamController<PresenceEvent>.broadcast();
  final _offline = StreamController<PresenceEvent>.broadcast();
  final _errors = StreamController<String>.broadcast();

  @override
  Stream<SocketConnectionState> get connectionState => _states.stream;
  @override
  Stream<String> get errors => _errors.stream;
  @override
  Stream<ChatMessage> listenMessage() => _messages.stream;
  @override
  Stream<MessageAcknowledgement> listenAcknowledgement() => _acks.stream;
  @override
  Stream<ReadEvent> listenMessageRead() => _reads.stream;
  @override
  Stream<TypingEvent> listenTyping() => _typing.stream;
  @override
  Stream<PresenceEvent> listenOnline() => _online.stream;
  @override
  Stream<PresenceEvent> listenOffline() => _offline.stream;

  @override
  Future<void> connect() async {
    _states.add(SocketConnectionState.connecting);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    _states.add(SocketConnectionState.connected);
    _online.add(
      const PresenceEvent(userId: 2, username: 'Ece', isOnline: true),
    );
  }

  @override
  Future<void> disconnect() async =>
      _states.add(SocketConnectionState.disconnected);

  @override
  void sendMessage({required String clientMessageId, required String content}) {
    final id = _nextId++;
    final now = DateTime.now();
    Timer(
      const Duration(milliseconds: 300),
      () => _acks.add(
        MessageAcknowledgement(
          clientMessageId: clientMessageId,
          messageId: id,
          conversationId: conversationId,
          createdAt: now,
        ),
      ),
    );
    Timer(
      const Duration(milliseconds: 900),
      () => _reads.add(
        ReadEvent(messageId: id, userId: 2, readAt: DateTime.now()),
      ),
    );
    _typing.add(const TypingEvent(userId: 2, username: 'Ece', isTyping: true));
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _typing.add(const TypingEvent(userId: 2, isTyping: false));
      _messages.add(
        ChatMessage(
          id: _nextId++,
          clientMessageId: 'mock-$id',
          conversationId: conversationId,
          sender: const ChatUser(id: 2, username: 'Ece'),
          content: _replyFor(content),
          createdAt: DateTime.now(),
        ),
      );
    });
  }

  String _replyFor(String content) => content.endsWith('?')
      ? 'Evet, kulağa harika geliyor ✨'
      : 'Mesajını aldım, teşekkürler!';
  @override
  void sendTypingStart() {}
  @override
  void sendTypingStop() {}
  @override
  void sendMessageRead(int messageId) => _reads.add(
    ReadEvent(
      messageId: messageId,
      userId: currentUserId,
      readAt: DateTime.now(),
    ),
  );

  @override
  Future<void> dispose() async {
    _typingTimer?.cancel();
    await Future.wait([
      _states.close(),
      _messages.close(),
      _acks.close(),
      _reads.close(),
      _typing.close(),
      _online.close(),
      _offline.close(),
      _errors.close(),
    ]);
  }
}
