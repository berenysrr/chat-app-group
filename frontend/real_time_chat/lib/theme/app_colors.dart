import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xff0b1220);
  static const surface = Color(0xff111a2c);
  static const sidebar = Color(0xff172236);
  static const card = Color(0xff1c2940);
  static const input = Color(0xff0d1728);
  static const border = Color(0xff293650);
  static const primary = Color(0xff675cff);
  static const secondary = Color(0xff8b4dff);
  static const accentBlue = Color(0xff4f7cff);
  static const textPrimary = Color(0xfff4f6ff);
  static const textSecondary = Color(0xff9aa7bd);
  static const textMuted = Color(0xff68758d);
  static const online = Color(0xff35d07f);
  static const warning = Color(0xffffad5c);
  static const error = Color(0xffff5c72);

  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, accentBlue],
  );
}
