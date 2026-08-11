import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth/token_store.dart';
import 'chat/controllers/chat_controller.dart';
import 'chat/models/chat_models.dart';
import 'chat/screens/chat_list_screen.dart';
import 'chat/screens/real_chat_home.dart';
import 'chat/services/mock_web_socket_service.dart';
import 'chat/services/web_socket_service.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/splash_screen.dart';
import 'services/api_client.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RealTimeChatApp());
}

class RealTimeChatApp extends StatefulWidget {
  const RealTimeChatApp({super.key});

  @override
  State<RealTimeChatApp> createState() => _RealTimeChatAppState();
}

class _RealTimeChatAppState extends State<RealTimeChatApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    ApiClient().onUnauthorized = () {
      _navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
    };
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeModeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          title: 'Chat',
          navigatorKey: _navigatorKey,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode,
          initialRoute: '/',
          routes: {
            '/': (context) => const SplashScreen(),
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const RegisterScreen(),
            '/home': (context) => const HomeScreen(),
          },
        );
      },
    );
  }
}

/// Chat modülünün izole testleri ve mock geliştirme modu için uygulama kabuğu.
/// Gerçek uygulamanın giriş noktası [RealTimeChatApp] olarak kalır.
class ChatApp extends StatelessWidget {
  const ChatApp({super.key, this.socketOverride, this.tokenStore});

  final WebSocketService? socketOverride;
  final TokenStore? tokenStore;

  @override
  Widget build(BuildContext context) {
    if (tokenStore != null && socketOverride == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Chat',
        themeMode: ThemeMode.dark,
        theme: AppTheme.dark,
        darkTheme: AppTheme.dark,
        home: RealChatHome(tokens: tokenStore!),
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
        title: 'Chat',
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
