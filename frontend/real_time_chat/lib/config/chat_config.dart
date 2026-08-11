import 'package:flutter/foundation.dart';

enum ChatConnectionMode { mock, real }

abstract final class ChatConfig {
  static ChatConnectionMode get connectionMode {
    const configured = String.fromEnvironment('CHAT_CONNECTION_MODE');
    if (configured == 'mock') return ChatConnectionMode.mock;
    if (configured == 'real') return ChatConnectionMode.real;
    return ChatConnectionMode.real;
  }

  static const restBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://chat-backend-j0z0.onrender.com/api/',
  );

  static const webSocketBaseUrl = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'wss://chat-backend-j0z0.onrender.com',
  );

  static const production = bool.fromEnvironment('PRODUCTION');
}

