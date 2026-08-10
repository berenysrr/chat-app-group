import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/chat_config.dart';
import 'chat/controllers/chat_controller.dart';
import 'chat/models/chat_models.dart';
import 'chat/screens/chat_list_screen.dart';
import 'chat/services/mock_web_socket_service.dart';
import 'chat/services/web_socket_service.dart';

void main() => runApp(const ChatApp());

class ChatApp extends StatelessWidget {
  const ChatApp({super.key, this.socketOverride});
  final WebSocketService? socketOverride;

  @override
  Widget build(BuildContext context) {
    final mode = ChatConfig.connectionMode;
    final socket =
        socketOverride ??
        (mode == ChatConnectionMode.mock
            ? MockWebSocketService(
                presenceSchedule: const [
                  MockPresenceStep(delay: Duration(seconds: 2), isOnline: true),
                ],
              )
            : ContractWebSocketService(uri: ChatConfig.webSocketUri));
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
        themeMode: ThemeMode.system,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        home: ChatListScreen(
          showDemoConversations: socket is MockWebSocketService,
        ),
      ),
    );
  }
}

ThemeData _theme(Brightness brightness) {
  final colors = ColorScheme.fromSeed(
    seedColor: const Color(0xff4b64d8),
    brightness: brightness,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    brightness: brightness,
    scaffoldBackgroundColor: colors.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    inputDecorationTheme: const InputDecorationTheme(isDense: true),
  );
}
