import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/chat_models.dart';

enum SocketConnectionState { connecting, connected, disconnected, reconnecting }

abstract interface class WebSocketService {
  Stream<SocketConnectionState> get connectionState;
  Stream<String> get errors;
  Future<void> connect();
  Future<void> disconnect();
  void sendMessage({required String clientMessageId, required String content});
  void sendTypingStart();
  void sendTypingStop();
  void sendMessageRead(int messageId);
  Stream<ChatMessage> listenMessage();
  Stream<MessageAcknowledgement> listenAcknowledgement();
  Stream<ReadEvent> listenMessageRead();
  Stream<TypingEvent> listenTyping();
  Stream<PresenceEvent> listenOnline();
  Stream<PresenceEvent> listenOffline();
  Future<void> dispose();
}

class ContractWebSocketService implements WebSocketService {
  ContractWebSocketService({
    required this.uri,
    this.maxReconnectDelay = const Duration(seconds: 30),
  });

  final Uri uri;
  final Duration maxReconnectDelay;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  var _manuallyDisconnected = false;
  var _attempt = 0;
  var _connecting = false;
  var _disposed = false;

  final _states = StreamController<SocketConnectionState>.broadcast();
  final _messages = StreamController<ChatMessage>.broadcast();
  final _acknowledgements =
      StreamController<MessageAcknowledgement>.broadcast();
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
  Stream<MessageAcknowledgement> listenAcknowledgement() =>
      _acknowledgements.stream;
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
    if (_disposed || _connecting || _channel != null) return;
    _connecting = true;
    _manuallyDisconnected = false;
    _reconnectTimer?.cancel();
    _states.add(
      _attempt == 0
          ? SocketConnectionState.connecting
          : SocketConnectionState.reconnecting,
    );
    try {
      final channel = WebSocketChannel.connect(uri);
      await channel.ready;
      if (_manuallyDisconnected || _disposed) {
        await channel.sink.close();
        return;
      }
      _channel = channel;
      _attempt = 0;
      _states.add(SocketConnectionState.connected);
      _subscription = channel.stream.listen(
        _handleFrame,
        onError: _handleError,
        onDone: _handleDone,
        cancelOnError: true,
      );
    } catch (error, stackTrace) {
      _reportError('Connection failed: $error', stackTrace);
      _scheduleReconnect();
    } finally {
      _connecting = false;
    }
  }

  void _handleFrame(dynamic frame) {
    try {
      final envelope = jsonDecode(frame as String) as Map<String, dynamic>;
      final type = envelope['type'] as String;
      final data = envelope['data'] as Map<String, dynamic>;
      switch (type) {
        case 'message.new':
          _messages.add(ChatMessage.fromJson(data));
        case 'message.ack':
          _acknowledgements.add(MessageAcknowledgement.fromJson(data));
        case 'message.read':
          _reads.add(ReadEvent.fromJson(data));
        case 'typing.start':
          _typing.add(TypingEvent.fromJson(data, isTyping: true));
        case 'typing.stop':
          _typing.add(TypingEvent.fromJson(data, isTyping: false));
        case 'user.online':
          _online.add(PresenceEvent.fromJson(data, isOnline: true));
        case 'user.offline':
          _offline.add(PresenceEvent.fromJson(data, isOnline: false));
        case 'error':
          _errors.add((data['message'] as String?) ?? 'WebSocket error');
        default:
          _errors.add('Unknown WebSocket event: $type');
      }
    } catch (error, stackTrace) {
      _reportError('Invalid WebSocket payload: $error', stackTrace);
    }
  }

  void _handleError(Object error, StackTrace stackTrace) {
    _reportError('WebSocket error: $error', stackTrace);
    _scheduleReconnect();
  }

  void _handleDone() => _scheduleReconnect();

  void _scheduleReconnect() {
    _subscription?.cancel();
    _channel = null;
    if (_disposed ||
        _manuallyDisconnected ||
        _reconnectTimer?.isActive == true) {
      return;
    }
    _states.add(SocketConnectionState.disconnected);
    final seconds = (1 << _attempt.clamp(0, 5)).clamp(
      1,
      maxReconnectDelay.inSeconds,
    );
    _attempt++;
    _states.add(SocketConnectionState.reconnecting);
    _reconnectTimer = Timer(Duration(seconds: seconds), connect);
  }

  void _send(String type, Map<String, dynamic> data) {
    if (_channel == null) throw StateError('WebSocket is not connected');
    _channel!.sink.add(jsonEncode({'type': type, 'data': data}));
  }

  @override
  void sendMessage({
    required String clientMessageId,
    required String content,
  }) => _send('message.send', {
    'client_message_id': clientMessageId,
    'content': content,
  });
  @override
  void sendTypingStart() => _send('typing.start', const {});
  @override
  void sendTypingStop() => _send('typing.stop', const {});
  @override
  void sendMessageRead(int messageId) =>
      _send('message.read', {'message_id': messageId});

  @override
  Future<void> disconnect() async {
    _manuallyDisconnected = true;
    _reconnectTimer?.cancel();
    await _subscription?.cancel();
    await _channel?.sink.close();
    _channel = null;
    _states.add(SocketConnectionState.disconnected);
  }

  void _reportError(String message, StackTrace stackTrace) {
    final safeMessage = message.replaceAll(
      uri.toString(),
      '${uri.scheme}://${uri.host}${uri.path}?token=***',
    );
    debugPrint(safeMessage);
    _errors.add(safeMessage);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await disconnect();
    await Future.wait([
      _states.close(),
      _messages.close(),
      _acknowledgements.close(),
      _reads.close(),
      _typing.close(),
      _online.close(),
      _offline.close(),
      _errors.close(),
    ]);
  }
}
