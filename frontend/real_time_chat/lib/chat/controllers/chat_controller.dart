import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_models.dart';
import '../services/chat_repository.dart';
import '../services/web_socket_service.dart';

class ChatController extends ChangeNotifier {
  ChatController({
    required this.socket,
    required this.currentUser,
    required this.peer,
    required this.conversationId,
    this.initialMessages,
    this.initialUnreadCount = 0,
    this.repository,
    this.initialUpdatedAt,
  });
  final WebSocketService socket;
  final ChatUser currentUser;
  final ChatUser peer;
  final int conversationId;
  final List<ChatMessage>? initialMessages;
  final int initialUnreadCount;
  final ChatRepository? repository;
  final DateTime? initialUpdatedAt;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final List<ChatMessage> _messages = [];
  final Set<int> _readMessageIds = {};
  Timer? _typingDebounce;
  Timer? _peerTypingTimeout;
  Timer? _presencePoller;
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
  bool isLoadingHistory = false;
  bool hasMoreHistory = true;
  bool _syncingAfterReconnect = false;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  DateTime get lastActivityAt =>
      _messages.lastOrNull?.createdAt ??
      initialUpdatedAt ??
      DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    peerIsOnline = peer.isOnline;
    peerLastSeen = peer.lastSeen;
    if (initialMessages != null) _messages.addAll(initialMessages!);
    if (repository != null) {
      await _loadInitialHistory();
    } else if (initialMessages == null) {
      _messages.addAll([
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
      ]);
    }
    unreadCount = initialUnreadCount;
    _subscriptions.addAll([
      socket.connectionState.listen((value) {
        final wasReconnecting =
            connection == SocketConnectionState.reconnecting;
        connection = value;
        if (value == SocketConnectionState.connected && wasReconnecting) {
          _syncAfterReconnect();
        }
        notifyListeners();
      }),
      socket.listenMessage().listen(_onMessage),
      socket.listenAcknowledgement().listen(_onAcknowledgement),
      socket.listenMessageRead().listen(_onRead),
      socket.listenTyping().listen((event) {
        if (event.userId == currentUser.id ||
            (peer.id > 0 && event.userId != peer.id)) {
          return;
        }
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
        _peerTypingTimeout?.cancel();
        peerIsTyping = false;
        peerIsOnline = false;
        peerLastSeen = event.lastSeen;
        notifyListeners();
      }),
      socket.errors.listen((value) {
        errorMessage = value;
        notifyListeners();
      }),
    ]);
    if (repository != null && peer.id > 0) {
      _presencePoller = Timer.periodic(
        const Duration(seconds: 4),
        (_) => _refreshPeerPresence(),
      );
    }
    notifyListeners();
    await socket.connect();
  }

  Future<void> _refreshPeerPresence() async {
    if (repository == null || peer.id <= 0) return;
    try {
      final conversation = await repository!.conversation(conversationId);
      final refreshedPeer = conversation.members
          .where((member) => member.id == peer.id)
          .firstOrNull;
      if (refreshedPeer == null) return;
      if (peerIsOnline != refreshedPeer.isOnline ||
          peerLastSeen != refreshedPeer.lastSeen) {
        peerIsOnline = refreshedPeer.isOnline;
        peerLastSeen = refreshedPeer.lastSeen;
        _notify();
      }
    } catch (_) {}
  }

  Future<void> _loadInitialHistory() async {
    isLoadingHistory = true;
    try {
      final page = await repository!.messages(conversationId);
      _mergeMessages(page.messages);
      hasMoreHistory = page.hasMore;
    } on Object catch (error) {
      errorMessage = error.toString();
    } finally {
      isLoadingHistory = false;
    }
  }

  Future<void> loadOlderMessages() async {
    if (repository == null || isLoadingHistory || !hasMoreHistory) return;
    final oldestId = _messages.where((item) => item.id != null).firstOrNull?.id;
    if (oldestId == null) return;
    isLoadingHistory = true;
    _notify();
    try {
      final page = await repository!.messages(
        conversationId,
        beforeId: oldestId,
      );
      _mergeMessages(page.messages);
      hasMoreHistory = page.hasMore;
    } on Object catch (error) {
      errorMessage = error.toString();
    } finally {
      isLoadingHistory = false;
      _notify();
    }
  }

  Future<void> _syncAfterReconnect() async {
    if (repository == null || _syncingAfterReconnect) return;
    final ids = _messages
        .where((item) => item.id != null)
        .map((item) => item.id!);
    if (ids.isEmpty) return;
    _syncingAfterReconnect = true;
    try {
      final page = await repository!.messages(
        conversationId,
        afterId: ids.reduce((a, b) => a > b ? a : b),
      );
      _mergeMessages(page.messages);
      for (final message in _messages.where(
        (item) => item.status == MessageStatus.pending,
      )) {
        socket.sendMessage(
          clientMessageId: message.clientMessageId,
          content: message.content,
          messageType: message.messageType,
        );
      }
    } on Object catch (error) {
      errorMessage = error.toString();
    } finally {
      _syncingAfterReconnect = false;
      _notify();
    }
  }

  void _mergeMessages(Iterable<ChatMessage> incoming) {
    for (final message in incoming) {
      final index = _messages.indexWhere(
        (item) =>
            (message.id != null && item.id == message.id) ||
            item.clientMessageId == message.clientMessageId,
      );
      if (index < 0) {
        _messages.add(message);
      } else {
        final current = _messages[index];
        _messages[index] = message.copyWith(
          status: latestMessageStatus(current.status, message.status),
        );
      }
    }
    _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  bool send(String rawContent, {String messageType = 'text'}) {
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
        messageType: messageType,
        createdAt: DateTime.now(),
        status: MessageStatus.pending,
      ),
    );
    notifyListeners();
    _stopTyping();
    try {
      socket.sendMessage(
        clientMessageId: clientId,
        content: content,
        messageType: messageType,
      );
      _replaceByClientId(
        clientId,
        (message) => message.copyWith(status: MessageStatus.sent),
      );
      notifyListeners();
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
        messageType: message.messageType,
      );
      _messages[index] = _messages[index].copyWith(status: MessageStatus.sent);
      notifyListeners();
    } catch (_) {
      _messages[index] = message.copyWith(status: MessageStatus.failed);
      errorMessage = 'Mesaj yeniden gönderilemedi.';
      notifyListeners();
    }
  }

  void openConversation() {
    _isConversationVisible = true;
    _syncConversationReadState();
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
      _syncConversationReadState();
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
    final candidates = _messages
        .where(
          (message) =>
              !message.isMine(currentUser.id) &&
              message.id != null &&
              !_readMessageIds.contains(message.id),
        )
        .toList();
    if (candidates.isEmpty) return;
    for (final message in candidates) {
      try {
        socket.sendMessageRead(message.id!);
        _readMessageIds.add(message.id!);
      } catch (_) {}
    }
  }

  void _syncConversationReadState() {
    _markUnreadMessagesRead();
    final repo = repository;
    if (repo == null) return;
    unawaited(repo.markConversationRead(conversationId));
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
        createdAt: acknowledgement.createdAt,
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
      final current = _messages[index];
      final status = latestMessageStatus(current.status, MessageStatus.read);
      if (status == current.status) return;
      _messages[index] = current.copyWith(status: status);
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
    _presencePoller?.cancel();
    if (_isTyping) _safeTyping(false);
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    socket.dispose();
    super.dispose();
  }
}
