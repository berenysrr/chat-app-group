import 'package:flutter/foundation.dart';

enum ChatConnectionMode { mock, real }

abstract final class ChatConfig {
  static ChatConnectionMode get connectionMode {
    const configured = String.fromEnvironment('CHAT_CONNECTION_MODE');
    if (configured == 'mock') return ChatConnectionMode.mock;
    if (configured == 'real') return ChatConnectionMode.real;
    return kReleaseMode ? ChatConnectionMode.real : ChatConnectionMode.mock;
  }

  static const restBaseUrl = String.fromEnvironment(
    'REST_BASE_URL',
    defaultValue: 'http://localhost:8000/api/',
  );

  static Uri get webSocketUri => Uri.parse(
    const String.fromEnvironment(
      'WS_URL',
      defaultValue: 'ws://localhost:8000/ws/chat/3/?token=ACCESS_TOKEN',
    ),
  );
}
