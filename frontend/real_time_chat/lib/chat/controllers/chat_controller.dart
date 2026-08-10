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
  final Set<int> _readMessageIds = {};
  Timer? _typingDebounce;
  Timer? _peerTypingTimeout;
  bool _initialized = false;
  bool _disposed = false;
  bool _isTyping = false;
  SocketConnectionState connection = SocketConnectionState.disconnected;
  bool peerIsTyping = false;
  bool peerIsOnline = false;
  bool _isConversationVisible = false;
  bool _isAppForeground = true;
  int unreadCount = 0;
  DateTime? peerLastSeen;
  String? errorMessage;

  List<ChatMessage> get messages => List.unmodifiable(_messages);

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
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
        if (event.userId != peer.id) return;
        _peerTypingTimeout?.cancel();
        peerIsTyping = event.isTyping;
        if (event.isTyping) {
          _peerTypingTimeout = Timer(const Duration(seconds: 5), () {
            peerIsTyping = false;
            _notify();
          });
        }
        notifyListeners();
      }),
      socket.listenOnline().listen((event) {
        if (event.userId != peer.id) return;
        peerIsOnline = true;
        peerLastSeen = null;
        notifyListeners();
      }),
      socket.listenOffline().listen((event) {
        if (event.userId != peer.id) return;
        peerIsOnline = false;
        peerLastSeen = event.lastSeen;
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

  bool send(String rawContent) {
    final content = rawContent.trim();
    if (content.isEmpty) return false;
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
    _stopTyping();
    try {
      socket.sendMessage(clientMessageId: clientId, content: content);
      return true;
    } catch (error) {
      _replaceByClientId(
        clientId,
        (message) => message.copyWith(status: MessageStatus.failed),
      );
      errorMessage = 'Mesaj gönderilemedi. Bağlantıyı kontrol edin.';
      notifyListeners();
      return false;
    }
  }

  void retryMessage(String clientMessageId) {
    final index = _messages.indexWhere(
      (item) =>
          item.clientMessageId == clientMessageId &&
          item.status == MessageStatus.failed,
    );
    if (index < 0) return;
    final message = _messages[index];
    _messages[index] = message.copyWith(status: MessageStatus.pending);
    errorMessage = null;
    notifyListeners();
    try {
      socket.sendMessage(
        clientMessageId: message.clientMessageId,
        content: message.content,
      );
    } catch (_) {
      _messages[index] = message.copyWith(status: MessageStatus.failed);
      errorMessage = 'Mesaj yeniden gönderilemedi.';
      notifyListeners();
    }
  }

  void openConversation() {
    _isConversationVisible = true;
    _markUnreadMessagesRead();
    if (unreadCount != 0) {
      unreadCount = 0;
      notifyListeners();
    }
  }

  void closeConversation() {
    _isConversationVisible = false;
    _stopTyping();
  }

  void setAppForeground(bool foreground) {
    _isAppForeground = foreground;
    if (foreground && _isConversationVisible) {
      _markUnreadMessagesRead();
      if (unreadCount != 0) {
        unreadCount = 0;
        notifyListeners();
      }
    }
  }

  void onInputChanged(String value) {
    _typingDebounce?.cancel();
    if (value.trim().isEmpty) {
      _stopTyping();
      return;
    }
    if (!_isTyping) {
      _isTyping = true;
      _safeTyping(true);
    }
    _typingDebounce = Timer(const Duration(milliseconds: 900), _stopTyping);
  }

  void _safeTyping(bool active) {
    try {
      active ? socket.sendTypingStart() : socket.sendTypingStop();
    } catch (_) {}
  }

  void _stopTyping() {
    _typingDebounce?.cancel();
    if (!_isTyping) return;
    _isTyping = false;
    _safeTyping(false);
  }

  void _markUnreadMessagesRead() {
    if (unreadCount == 0) return;
    final candidates = _messages
        .where(
          (message) =>
              !message.isMine(currentUser.id) &&
              message.id != null &&
              !_readMessageIds.contains(message.id),
        )
        .toList();
    final start = (candidates.length - unreadCount).clamp(0, candidates.length);
    final unreadMessages = candidates.skip(start);
    for (final message in unreadMessages) {
      try {
        socket.sendMessageRead(message.id!);
        _readMessageIds.add(message.id!);
      } catch (_) {}
    }
  }

  void _onMessage(ChatMessage message) {
    if (message.conversationId != conversationId) return;
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
      if (_isConversationVisible && _isAppForeground && message.id != null) {
        socket.sendMessageRead(message.id!);
        _readMessageIds.add(message.id!);
      } else {
        unreadCount++;
      }
    }
    notifyListeners();
  }

  void _onAcknowledgement(MessageAcknowledgement acknowledgement) {
    if (acknowledgement.conversationId != conversationId) return;
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
      if (_messages[index].status == MessageStatus.read) return;
      _messages[index] = _messages[index].copyWith(status: MessageStatus.read);
      notifyListeners();
    }
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

  Future<void> reconnect() async {
    await socket.disconnect();
    await socket.connect();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _typingDebounce?.cancel();
    _peerTypingTimeout?.cancel();
    if (_isTyping) _safeTyping(false);
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    socket.dispose();
    super.dispose();
  }
}
