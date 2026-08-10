import 'dart:async';
import 'dart:convert';
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
    return {
      'type': type,
      'data': data,
    };
  }
}

class WebSocketService {
  WebSocketChannel? _channel;
  final StreamController<WebSocketEvent> _eventController =
      StreamController<WebSocketEvent>.broadcast();

  bool _isConnected = false;
  int? _currentConversationId;

  bool get isConnected => _isConnected;
  Stream<WebSocketEvent> get events => _eventController.stream;

  Future<void> connect(int conversationId) async {
    if (_isConnected && _currentConversationId == conversationId) return;

    await disconnect();
    _currentConversationId = conversationId;

    try {
      final token = await TokenStorage().getAccessToken();
      if (token == null || token.isEmpty) {
        if (kDebugMode) print('WebSocket Error: No access token available');
        return;
      }

      // Determine websocket base URL based on host
      final String host = kIsWeb
          ? Uri.base.host.isNotEmpty ? Uri.base.host : '127.0.0.1'
          : '127.0.0.1';
      final wsUrl = Uri.parse(
        'ws://$host:8000/ws/chat/$conversationId/?token=$token',
      );

      if (kDebugMode) print('Connecting WebSocket: $wsUrl');

      _channel = WebSocketChannel.connect(wsUrl);
      _isConnected = true;

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
        },
        onDone: () {
          if (kDebugMode) print('WebSocket Stream Done/Closed');
          _isConnected = false;
        },
      );
    } catch (e) {
      if (kDebugMode) print('WebSocket Connection Failed: $e');
      _isConnected = false;
    }
  }

  void sendMessage(String content) {
    if (!_isConnected || _channel == null) return;
    final payload = {
      'type': 'message.send',
      'data': {'content': content},
    };
    _channel!.sink.add(jsonEncode(payload));
  }

  void startTyping() {
    if (!_isConnected || _channel == null) return;
    final payload = {
      'type': 'typing.start',
      'data': {},
    };
    _channel!.sink.add(jsonEncode(payload));
  }

  void stopTyping() {
    if (!_isConnected || _channel == null) return;
    final payload = {
      'type': 'typing.stop',
      'data': {},
    };
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
}
