import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_models.dart';
import '../services/web_socket_service.dart';

class ChatController extends ChangeNotifier {
  ChatController({
    required this.socket,
    required this.currentUser,
    required this.peer,
    required this.conversationId,
    this.initialMessages,
    this.initialUnreadCount = 0,
  });
  final WebSocketService socket;
  final ChatUser currentUser;
  final ChatUser peer;
  final int conversationId;
  final List<ChatMessage>? initialMessages;
  final int initialUnreadCount;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final List<ChatMessage> _messages = [];
  Timer? _typingDebounce;
  SocketConnectionState connection = SocketConnectionState.disconnected;
  bool peerIsTyping = false;
  bool peerIsOnline = false;
  bool _isConversationVisible = false;
  int unreadCount = 0;
  DateTime? peerLastSeen;
  String? errorMessage;

  List<ChatMessage> get messages => List.unmodifiable(_messages);

  Future<void> initialize() async {
    _messages.addAll(
      initialMessages ??
          [
            ChatMessage(
              id: 1,
              clientMessageId: 'seed-1',
              conversationId: conversationId,
              sender: peer,
              content: 'Selam! Bugünkü sunum hazır mı?',
              createdAt: DateTime.now().subtract(const Duration(minutes: 18)),
            ),
            ChatMessage(
              id: 2,
              clientMessageId: 'seed-2',
              conversationId: conversationId,
              sender: currentUser,
              content: 'Neredeyse bitti, son dokunuşları yapıyorum.',
              createdAt: DateTime.now().subtract(const Duration(minutes: 16)),
              status: MessageStatus.read,
            ),
          ],
    );
    unreadCount = initialUnreadCount;
    _subscriptions.addAll([
      socket.connectionState.listen((value) {
        connection = value;
        notifyListeners();
      }),
      socket.listenMessage().listen(_onMessage),
      socket.listenAcknowledgement().listen(_onAcknowledgement),
      socket.listenMessageRead().listen(_onRead),
      socket.listenTyping().listen((event) {
        if (event.userId == peer.id) peerIsTyping = event.isTyping;
        notifyListeners();
      }),
      socket.listenOnline().listen((event) {
        if (event.userId == peer.id) peerIsOnline = true;
        notifyListeners();
      }),
      socket.listenOffline().listen((event) {
        if (event.userId == peer.id) {
          peerIsOnline = false;
          peerLastSeen = event.lastSeen;
        }
        notifyListeners();
      }),
      socket.errors.listen((value) {
        errorMessage = value;
        notifyListeners();
      }),
    ]);
    notifyListeners();
    await socket.connect();
  }

  void send(String rawContent) {
    final content = rawContent.trim();
    if (content.isEmpty) return;
    final clientId = const Uuid().v4();
    _messages.add(
      ChatMessage(
        id: null,
        clientMessageId: clientId,
        conversationId: conversationId,
        sender: currentUser,
        content: content,
        createdAt: DateTime.now(),
        status: MessageStatus.pending,
      ),
    );
    notifyListeners();
    try {
      socket.sendTypingStop();
      socket.sendMessage(clientMessageId: clientId, content: content);
    } catch (error) {
      _replaceByClientId(
        clientId,
        (message) => message.copyWith(status: MessageStatus.failed),
      );
      errorMessage = 'Mesaj gönderilemedi. Bağlantıyı kontrol edin.';
      notifyListeners();
    }
  }

  void openConversation() {
    _isConversationVisible = true;
    final unreadMessages = _messages.where(
      (message) => !message.isMine(currentUser.id) && message.id != null,
    );
    for (final message in unreadMessages) {
      try {
        socket.sendMessageRead(message.id!);
      } catch (_) {}
    }
    if (unreadCount != 0) {
      unreadCount = 0;
      notifyListeners();
    }
  }

  void closeConversation() {
    _isConversationVisible = false;
  }

  void onInputChanged(String value) {
    _typingDebounce?.cancel();
    if (value.trim().isEmpty) {
      _safeTyping(false);
      return;
    }
    _safeTyping(true);
    _typingDebounce = Timer(
      const Duration(milliseconds: 900),
      () => _safeTyping(false),
    );
  }

  void _safeTyping(bool active) {
    try {
      active ? socket.sendTypingStart() : socket.sendTypingStop();
    } catch (_) {}
  }

  void _onMessage(ChatMessage message) {
    if (_messages.any(
      (item) =>
          item.id == message.id ||
          item.clientMessageId == message.clientMessageId,
    )) {
      return;
    }
    _messages.add(message);
    _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (!message.isMine(currentUser.id)) {
      if (_isConversationVisible && message.id != null) {
        socket.sendMessageRead(message.id!);
      } else {
        unreadCount++;
      }
    }
    notifyListeners();
  }

  void _onAcknowledgement(MessageAcknowledgement acknowledgement) {
    _replaceByClientId(
      acknowledgement.clientMessageId,
      (message) => message.copyWith(
        id: acknowledgement.messageId,
        status: MessageStatus.delivered,
      ),
    );
    notifyListeners();
  }

  void _onRead(ReadEvent event) {
    final index = _messages.indexWhere(
      (message) =>
          message.id == event.messageId && message.isMine(currentUser.id),
    );
    if (index >= 0) {
      _messages[index] = _messages[index].copyWith(status: MessageStatus.read);
    }
    notifyListeners();
  }

  void _replaceByClientId(
    String id,
    ChatMessage Function(ChatMessage) replace,
  ) {
    final index = _messages.indexWhere(
      (message) => message.clientMessageId == id,
    );
    if (index >= 0) _messages[index] = replace(_messages[index]);
  }

  @override
  void dispose() {
    _typingDebounce?.cancel();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    socket.dispose();
    super.dispose();
  }
}
