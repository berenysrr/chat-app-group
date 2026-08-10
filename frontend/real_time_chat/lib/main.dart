import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/chat_config.dart';
import 'auth/token_store.dart';
import 'theme/app_theme.dart';
import 'chat/controllers/chat_controller.dart';
import 'chat/models/chat_models.dart';
import 'chat/screens/chat_list_screen.dart';
import 'chat/screens/real_chat_home.dart';
import 'chat/services/mock_web_socket_service.dart';
import 'chat/services/web_socket_service.dart';

void main() => runApp(const ChatApp());

class ChatApp extends StatelessWidget {
  const ChatApp({super.key, this.socketOverride, this.tokenStore});
  final WebSocketService? socketOverride;
  final TokenStore? tokenStore;

  @override
  Widget build(BuildContext context) {
    final mode = ChatConfig.connectionMode;
    if (mode == ChatConnectionMode.real && socketOverride == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Pulse Chat',
        themeMode: ThemeMode.dark,
        theme: AppTheme.dark,
        darkTheme: AppTheme.dark,
        home: tokenStore == null
            ? const _MissingAuthBridge()
            : RealChatHome(tokens: tokenStore!),
      );
    }
    final socket =
        socketOverride ??
        MockWebSocketService(
          presenceSchedule: const [
            MockPresenceStep(delay: Duration(seconds: 2), isOnline: true),
          ],
        );
    return ChangeNotifierProvider(
      create: (_) => ChatController(
        socket: socket,
        currentUser: const ChatUser(id: 1, username: 'Sen'),
        peer: const ChatUser(id: 2, username: 'Ece'),
        conversationId: 3,
      )..initialize(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Pulse Chat',
        themeMode: ThemeMode.dark,
        theme: AppTheme.dark,
        darkTheme: AppTheme.dark,
        home: ChatListScreen(
          showDemoConversations: socket is MockWebSocketService,
        ),
      ),
    );
  }
}

class _MissingAuthBridge extends StatelessWidget {
  const _MissingAuthBridge();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: const Text(
            'Gerçek chat modu için auth modülünün TokenStore uygulamasını '
            'ChatApp(tokenStore: ...) üzerinden sağlaması gerekiyor. Token '
            'kaynak koda veya dart-define içine gömülmedi.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );
}
