import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'chat/controllers/chat_controller.dart';
import 'chat/models/chat_models.dart';
import 'chat/screens/chat_list_screen.dart';
import 'chat/services/mock_web_socket_service.dart';
import 'chat/services/web_socket_service.dart';

const useMockSocket = bool.fromEnvironment(
  'USE_MOCK_SOCKET',
  defaultValue: true,
);

void main() => runApp(const ChatApp());

class ChatApp extends StatelessWidget {
  const ChatApp({super.key, this.socketOverride});
  final WebSocketService? socketOverride;

  @override
  Widget build(BuildContext context) {
    final socket =
        socketOverride ??
        (useMockSocket
            ? MockWebSocketService()
            : ContractWebSocketService(
                uri: Uri.parse(
                  const String.fromEnvironment(
                    'WS_URL',
                    defaultValue:
                        'ws://localhost:8000/ws/chat/3/?token=ACCESS_TOKEN',
                  ),
                ),
              ));
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
        home: const ChatListScreen(),
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
