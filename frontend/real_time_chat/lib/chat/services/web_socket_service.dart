import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/chat_models.dart';

enum SocketConnectionState {
  connecting,
  connected,
  disconnected,
  reconnecting,
  failed,
}

class SocketEvent {
  const SocketEvent(this.type, this.data);
  final String type;
  final Map<String, dynamic> data;

  static SocketEvent? decode(Object? frame) {
    try {
      final decoded = frame is String ? jsonDecode(frame) : frame;
      if (decoded is! Map) return null;
      final envelope = decoded.cast<String, dynamic>();
      final type = envelope['type'];
      if (type is! String || type.isEmpty) return null;
      if (type == 'pong') return const SocketEvent('pong', {});
      final rawData = envelope['data'];
      final data = rawData is Map
          ? rawData.cast<String, dynamic>()
          : envelope;
      return SocketEvent(type, data);
    } catch (_) {
      return null;
    }
  }
}


abstract interface class WebSocketService {
  Stream<SocketConnectionState> get connectionState;
  Stream<String> get errors;
  Future<void> connect();
  Future<void> disconnect();
  void sendMessage({
    required String clientMessageId,
    required String content,
    String messageType = 'text',
  });
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

typedef AccessTokenProvider = Future<String?> Function();

class ContractWebSocketService implements WebSocketService {
  ContractWebSocketService({
    required this.conversationId,
    required String baseUrl,
    required this.accessTokenProvider,
    this.production = false,
    this.maxReconnectDelay = const Duration(seconds: 30),
    this.onInvalidToken,
  }) : _baseUri = _validateBaseUri(baseUrl, production);

  final int conversationId;
  final Uri _baseUri;
  final AccessTokenProvider accessTokenProvider;
  final bool production;
  final Duration maxReconnectDelay;
  final Future<bool> Function()? onInvalidToken;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  var _manuallyDisconnected = false;

  var _attempt = 0;
  var _connecting = false;
  var _disposed = false;
  var _invalidTokenRetried = false;

  final _states = StreamController<SocketConnectionState>.broadcast();
  final _messages = StreamController<ChatMessage>.broadcast();
  final _acknowledgements =
      StreamController<MessageAcknowledgement>.broadcast();
  final _reads = StreamController<ReadEvent>.broadcast();
  final _typing = StreamController<TypingEvent>.broadcast();
  final _online = StreamController<PresenceEvent>.broadcast();
  final _offline = StreamController<PresenceEvent>.broadcast();
  final _errors = StreamController<String>.broadcast();

  static Uri _validateBaseUri(String value, bool production) {
    final uri = Uri.parse(value.trim());
    if (uri.scheme != 'ws' && uri.scheme != 'wss') {
      throw ArgumentError.value(value, 'baseUrl', 'ws:// veya wss:// gerekli');
    }
    if (production && uri.scheme != 'wss') {
      throw ArgumentError(
        'Production ortamında yalnızca wss:// kullanılabilir.',
      );
    }
    return uri.replace(path: uri.path.replaceAll(RegExp(r'/+$'), ''));
  }

  static Uri buildUri({
    required String baseUrl,
    required int conversationId,
    required String accessToken,
    bool production = false,
  }) {
    if (conversationId <= 0) {
      throw ArgumentError.value(conversationId, 'conversationId');
    }
    if (accessToken.isEmpty) throw ArgumentError('Access token gerekli.');
    final base = _validateBaseUri(baseUrl, production);
    return base.replace(
      path: '${base.path}/ws/chat/$conversationId/'.replaceAll('//', '/'),
      queryParameters: {'token': accessToken},
    );
  }

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
    _emitState(
      _attempt == 0
          ? SocketConnectionState.connecting
          : SocketConnectionState.reconnecting,
    );
    try {
      final token = await accessTokenProvider();
      if (token == null || token.isEmpty) {
        _errors.add('WebSocket için oturum gerekli.');
        _emitState(SocketConnectionState.failed);
        return;
      }
      final uri = buildUri(
        baseUrl: _baseUri.toString(),
        conversationId: conversationId,
        accessToken: token,
        production: production,
      );
      final channel = WebSocketChannel.connect(uri);
      await channel.ready;
      if (_manuallyDisconnected || _disposed) {
        await channel.sink.close();
        return;
      }
      _channel = channel;
      _attempt = 0;
      _emitState(SocketConnectionState.connected);
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        if (_channel != null) {
          try {
            _channel!.sink.add(jsonEncode({'type': 'ping', 'data': {}}));
          } catch (_) {}
        }
      });
      _subscription = channel.stream.listen(
        _handleFrame,
        onError: _handleError,
        onDone: _handleDone,
        cancelOnError: true,
      );

    } catch (error, stackTrace) {
      _reportError('WebSocket bağlantısı kurulamadı.', stackTrace);
      _scheduleReconnect();
    } finally {
      _connecting = false;
    }
  }

  @visibleForTesting
  void handleFrameForTest(Object? frame) => _handleFrame(frame);

  void _handleFrame(Object? frame) {
    final event = SocketEvent.decode(frame);
    if (event == null) {
      _errors.add('Geçersiz WebSocket payload.');
      return;
    }
    try {
      if (event.type != 'error') _invalidTokenRetried = false;
      switch (event.type) {
        case 'message.new':
          _messages.add(ChatMessage.fromJson(event.data));
        case 'message.ack':
          _acknowledgements.add(MessageAcknowledgement.fromJson(event.data));
        case 'message.read':
          _reads.add(ReadEvent.fromJson(event.data));
        case 'typing.start':
          _typing.add(TypingEvent.fromJson(event.data, isTyping: true));
        case 'typing.stop':
          _typing.add(TypingEvent.fromJson(event.data, isTyping: false));
        case 'user.online':
          _online.add(PresenceEvent.fromJson(event.data, isOnline: true));
        case 'user.offline':
          _offline.add(PresenceEvent.fromJson(event.data, isOnline: false));
        case 'error':
          _handleServerError(event.data);
        default:
          if (kDebugMode) debugPrint('Bilinmeyen WebSocket event türü.');
      }
    } catch (_, stackTrace) {
      _reportError('WebSocket event verisi contract ile uyumsuz.', stackTrace);
    }
  }

  void _handleServerError(Map<String, dynamic> data) {
    final code = data['code'] is String ? data['code'] as String : 'UNKNOWN';
    final message = data['message'] is String
        ? data['message'] as String
        : 'WebSocket hatası';
    _errors.add('$code: $message');
    if (code == 'NOT_MEMBER') {
      _manuallyDisconnected = true;
      disconnect();
    } else if (code == 'INVALID_TOKEN' && !_invalidTokenRetried) {
      _invalidTokenRetried = true;
      _refreshAndReconnect();
    }
  }

  Future<void> _refreshAndReconnect() async {
    final refreshed = await onInvalidToken?.call() ?? false;
    if (!refreshed) {
      await _closeCurrentChannel();
      _emitState(SocketConnectionState.failed);
      return;
    }
    await _closeCurrentChannel();
    await connect();
  }

  void _handleError(Object _, StackTrace stackTrace) {
    _reportError('WebSocket bağlantı hatası.', stackTrace);
    _scheduleReconnect();
  }

  void _handleDone() => _scheduleReconnect();

  void _scheduleReconnect() {
    _subscription?.cancel();
    _subscription = null;
    _channel = null;
    if (_disposed ||
        _manuallyDisconnected ||
        _reconnectTimer?.isActive == true) {
      return;
    }
    _emitState(SocketConnectionState.disconnected);
    final seconds = (1 << _attempt.clamp(0, 5)).clamp(
      1,
      maxReconnectDelay.inSeconds,
    );
    _attempt++;
    _emitState(SocketConnectionState.reconnecting);
    _reconnectTimer = Timer(Duration(seconds: seconds), connect);
  }

  void _send(String type, Map<String, dynamic> data) {
    if (_channel == null) throw StateError('WebSocket bağlı değil');
    _channel!.sink.add(jsonEncode({'type': type, 'data': data}));
  }

  @override
  void sendMessage({
    required String clientMessageId,
    required String content,
    String messageType = 'text',
  }) {
    final clean = content.trim();
    if (clean.isEmpty) throw ArgumentError('Mesaj boş olamaz.');
    _send('message.send', {
      'client_message_id': clientMessageId,
      'content': clean,
      'message_type': messageType,
    });
  }

  @override
  void sendTypingStart() => _send('typing.start', const {});
  @override
  void sendTypingStop() => _send('typing.stop', const {});
  @override
  void sendMessageRead(int messageId) {
    if (messageId <= 0) throw ArgumentError.value(messageId, 'messageId');
    _send('message.read', {'message_id': messageId});
  }

  Future<void> _closeCurrentChannel() async {
    _pingTimer?.cancel();
    _pingTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
  }


  @override
  Future<void> disconnect() async {
    _manuallyDisconnected = true;
    _reconnectTimer?.cancel();
    await _closeCurrentChannel();
    _emitState(SocketConnectionState.disconnected);
  }

  void _emitState(SocketConnectionState value) {
    if (!_states.isClosed) _states.add(value);
  }

  void _reportError(String message, StackTrace stackTrace) {
    if (kDebugMode) debugPrint(message);
    if (!_errors.isClosed) _errors.add(message);
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
