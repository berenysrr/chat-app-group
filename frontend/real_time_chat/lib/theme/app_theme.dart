import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Sleek Gen-Z Tech Startup Design System (Discord x Telegram x Raycast Aesthetic)
class AppTheme {
  // Electric Tech Accent Tokens
  static const Color primary = Color(0xFF6366F1); // Electric Indigo
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color secondary = Color(0xFF8B5CF6); // Vibrant Violet
  static const Color accent = Color(0xFF06B6D4); // Neon Cyan
  static const Color onlineGreen = Color(0xFF10B981); // Emerald Pulse
  static const Color offlineRed = Color(0xFFEF4444);
  static const Color offlineGrey = Color(0xFF64748B);
  static const Color amber = Color(0xFFF59E0B);

  // Legacy getters for backward compatibility
  static Color get darkSurface => const Color(0xFF1E293B);
  static Color get lightTextPrimary => const Color(0xFF0F172A);
  static Color get darkTextSecondary => const Color(0xFF94A3B8);
  static Color get lightTextSecondary => const Color(0xFF64748B);

  // Global Theme Mode Switcher
  static final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(
    ThemeMode.dark,
  );

  // Dynamic Color Tokens (Sleek Tech Dark / Clean Slate Light)
  static Color bg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF0F172A) // Deep Slate Charcoal
      : const Color(0xFFF8FAFC); // Clean Slate Snow

  static Color leftPanelBg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF1E293B) // Discord / Slate Dark
      : const Color(0xFFFFFFFF);

  static Color headerBg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF0F172A)
      : const Color(0xFFF1F5F9);

  static Color surface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF1E293B)
      : const Color(0xFFFFFFFF);

  static Color card(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF1E293B)
      : const Color(0xFFFFFFFF);

  static Color cardBorder(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF334155) // Sharp Technical Border
      : const Color(0xFFE2E8F0);

  static Color textPrimary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFFF8FAFC)
      : const Color(0xFF0F172A);

  static Color textSecondary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF94A3B8)
      : const Color(0xFF64748B);

  // Sleek Tech Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient techGradient = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkBackgroundGradient = LinearGradient(
    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient lightBackgroundGradient = LinearGradient(
    colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = darkBackgroundGradient;

  static LinearGradient dynamicBackgroundGradient(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? darkBackgroundGradient
      : lightBackgroundGradient;

  // ThemeData definitions
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF0F172A),
    colorScheme: const ColorScheme.dark(
      primary: primary,
      secondary: secondary,
      tertiary: accent,
      surface: Color(0xFF1E293B),
      onSurface: Color(0xFFF8FAFC),
    ),
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0F172A),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: TextStyle(
        color: Color(0xFFF8FAFC),
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      iconTheme: IconThemeData(color: Color(0xFF94A3B8)),
    ),
  );

  // Chat modülünün önceki tema API'si için uyumluluk alias'ı.
  static ThemeData get dark => darkTheme;

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF8FAFC),
    colorScheme: const ColorScheme.light(
      primary: primary,
      secondary: secondary,
      tertiary: accent,
      surface: Color(0xFFFFFFFF),
      onSurface: Color(0xFF0F172A),
    ),
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF1F5F9),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      titleTextStyle: TextStyle(
        color: Color(0xFF0F172A),
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      iconTheme: IconThemeData(color: Color(0xFF64748B)),
    ),
  );
}
