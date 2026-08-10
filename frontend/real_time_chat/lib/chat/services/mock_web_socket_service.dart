import 'dart:async';

import '../models/chat_models.dart';
import 'web_socket_service.dart';

class MockPresenceStep {
  const MockPresenceStep({required this.delay, required this.isOnline});
  final Duration delay;
  final bool isOnline;
}

class MockWebSocketService implements WebSocketService {
  MockWebSocketService({
    this.conversationId = 3,
    this.currentUserId = 1,
    this.peerId = 2,
    this.peerUsername = 'Ece',
    this.presenceSchedule = const [],
  });
  final int conversationId;
  final int currentUserId;
  final int peerId;
  final String peerUsername;
  final List<MockPresenceStep> presenceSchedule;
  var _nextId = 100;
  bool failNextSend = false;
  int connectCalls = 0;
  int typingStartCalls = 0;
  int typingStopCalls = 0;
  int readCalls = 0;
  bool _connected = false;
  bool _disposed = false;
  Timer? _typingTimer;
  final List<Timer> _timers = [];
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
    if (_disposed || _connected) return;
    connectCalls++;
    _states.add(SocketConnectionState.connecting);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    _states.add(SocketConnectionState.connected);
    _connected = true;
    for (final step in presenceSchedule) {
      _timers.add(Timer(step.delay, () => setPeerOnline(step.isOnline)));
    }
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    _states.add(SocketConnectionState.disconnected);
  }

  @override
  void sendMessage({required String clientMessageId, required String content}) {
    if (failNextSend || !_connected) {
      failNextSend = false;
      throw StateError('Mock WebSocket is not connected');
    }
    final id = _nextId++;
    final now = DateTime.now();
    _timers.add(
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
      ),
    );
    _timers.add(
      Timer(
        const Duration(milliseconds: 900),
        () => _reads.add(
          ReadEvent(messageId: id, userId: peerId, readAt: DateTime.now()),
        ),
      ),
    );
    _typing.add(
      TypingEvent(userId: peerId, username: peerUsername, isTyping: true),
    );
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _typing.add(TypingEvent(userId: peerId, isTyping: false));
      _messages.add(
        ChatMessage(
          id: _nextId++,
          clientMessageId: 'mock-$id',
          conversationId: conversationId,
          sender: ChatUser(id: peerId, username: peerUsername),
          content: _replyFor(content),
          createdAt: DateTime.now(),
        ),
      );
    });
  }

  String _replyFor(String content) => content.endsWith('?')
      ? 'Evet, kulağa harika geliyor ✨'
      : 'Mesajını aldım, teşekkürler!';

  void setPeerOnline(bool online) {
    emitPresence(userId: peerId, username: peerUsername, online: online);
  }

  void emitPresence({
    required int userId,
    required String username,
    required bool online,
  }) {
    final event = PresenceEvent(
      userId: userId,
      username: username,
      isOnline: online,
      lastSeen: online ? null : DateTime.now(),
    );
    (online ? _online : _offline).add(event);
  }

  void emitMessage(ChatMessage message) => _messages.add(message);

  void emitTyping(bool typing, {int? userId}) => _typing.add(
    TypingEvent(
      userId: userId ?? peerId,
      username: peerUsername,
      isTyping: typing,
    ),
  );

  @override
  void sendTypingStart() => typingStartCalls++;
  @override
  void sendTypingStop() => typingStopCalls++;
  @override
  void sendMessageRead(int messageId) {
    readCalls++;
    _reads.add(
      ReadEvent(
        messageId: messageId,
        userId: currentUserId,
        readAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _typingTimer?.cancel();
    for (final timer in _timers) {
      timer.cancel();
    }
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
