import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
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
    // Listen for unauthorized 401 token refresh failures to navigate to login
    ApiClient().onUnauthorized = () {
      _navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
    };
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeModeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          title: 'RealTime Chat',
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
