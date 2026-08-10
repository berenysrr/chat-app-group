import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'token_storage.dart';

class WebSocketEvent {
  final String type;
  final Map<String, dynamic> data;

  WebSocketEvent({required this.type, required this.data});

  factory WebSocketEvent.fromJson(Map<String, dynamic> json) {
    return WebSocketEvent(
      type: json['type'] ?? '',
      data: json['data'] is Map<String, dynamic>
          ? json['data']
          : <String, dynamic>{},
    );
  }

  Map<String, dynamic> toJson() {
    return {'type': type, 'data': data};
  }
}

class WebSocketService {
  WebSocketChannel? _channel;
  final StreamController<WebSocketEvent> _eventController =
      StreamController<WebSocketEvent>.broadcast();

  bool _isConnected = false;
  int? _currentConversationId;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _manualDisconnect = false;

  bool get isConnected => _isConnected;
  Stream<WebSocketEvent> get events => _eventController.stream;

  Future<void> connect(int conversationId) async {
    if (_isConnected && _currentConversationId == conversationId) return;

    await disconnect();
    _manualDisconnect = false;
    _currentConversationId = conversationId;
    await _openConnection();
  }

  Future<void> _openConnection() async {
    final conversationId = _currentConversationId;
    if (conversationId == null || _manualDisconnect) return;
    try {
      final token = await TokenStorage().getAccessToken();
      if (token == null || token.isEmpty) {
        if (kDebugMode) print('WebSocket Error: No access token available');
        return;
      }

      // Determine websocket base URL based on host
      final String host = kIsWeb
          ? Uri.base.host.isNotEmpty
                ? Uri.base.host
                : '127.0.0.1'
          : '127.0.0.1';
      final scheme = kIsWeb && Uri.base.scheme == 'https' ? 'wss' : 'ws';
      final wsUrl = Uri.parse(
        '$scheme://$host:8000/ws/chat/$conversationId/?token=$token',
      );

      if (kDebugMode) print('Connecting WebSocket: $wsUrl');

      _channel = WebSocketChannel.connect(wsUrl);
      _isConnected = true;
      _reconnectAttempts = 0;

      _channel!.stream.listen(
        (dynamic message) {
          try {
            final Map<String, dynamic> decoded = jsonDecode(message.toString());
            final event = WebSocketEvent.fromJson(decoded);
            _eventController.add(event);
          } catch (e) {
            if (kDebugMode) print('WebSocket Json Decode Error: $e');
          }
        },
        onError: (error) {
          if (kDebugMode) print('WebSocket Stream Error: $error');
          _isConnected = false;
          _scheduleReconnect();
        },
        onDone: () {
          if (kDebugMode) print('WebSocket Stream Done/Closed');
          _isConnected = false;
          _scheduleReconnect();
        },
      );
    } catch (e) {
      if (kDebugMode) print('WebSocket Connection Failed: $e');
      _isConnected = false;
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_manualDisconnect ||
        _currentConversationId == null ||
        _reconnectTimer != null) {
      return;
    }
    final delaySeconds = (1 << _reconnectAttempts.clamp(0, 5).toInt())
        .clamp(1, 30)
        .toInt();
    _reconnectAttempts++;
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () async {
      _reconnectTimer = null;
      await _openConnection();
    });
  }

  String? sendMessage(String content) {
    if (!_isConnected || _channel == null) return null;
    final clientMessageId = _newUuid();
    final payload = {
      'type': 'message.send',
      'data': {'client_message_id': clientMessageId, 'content': content},
    };
    _channel!.sink.add(jsonEncode(payload));
    return clientMessageId;
  }

  void startTyping() {
    if (!_isConnected || _channel == null) return;
    final payload = {'type': 'typing.start', 'data': {}};
    _channel!.sink.add(jsonEncode(payload));
  }

  void stopTyping() {
    if (!_isConnected || _channel == null) return;
    final payload = {'type': 'typing.stop', 'data': {}};
    _channel!.sink.add(jsonEncode(payload));
  }

  void markAsRead(int messageId) {
    if (!_isConnected || _channel == null) return;
    final payload = {
      'type': 'message.read',
      'data': {'message_id': messageId},
    };
    _channel!.sink.add(jsonEncode(payload));
  }

  Future<void> disconnect() async {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _isConnected = false;
    _currentConversationId = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  void dispose() {
    disconnect();
    _eventController.close();
  }

  String _newUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
