import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand gradient — deep violet to electric blue
  static const Color primary = Color(0xFF6C5CE7);
  static const Color primaryDark = Color(0xFF4834D4);
  static const Color secondary = Color(0xFF00B4D8);
  static const Color accent = Color(0xFFFF6B6B);

  // Income & Expense
  static const Color income = Color(0xFF00C49A);
  static const Color incomeLight = Color(0xFFE8FBF5);
  static const Color expense = Color(0xFFFF6B6B);
  static const Color expenseLight = Color(0xFFFFEEEE);

  // Status
  static const Color safe = Color(0xFF00C49A);
  static const Color warning = Color(0xFFFFB300);
  static const Color danger = Color(0xFFFF6B6B);
  static const Color exceeded = Color(0xFFD63031);

  // Neutrals
  static const Color background = Color(0xFFF8F9FE);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardShadow = Color(0x1A6C5CE7);

  static const Color textPrimary = Color(0xFF2D3436);
  static const Color textSecondary = Color(0xFF636E72);
  static const Color textHint = Color(0xFFB2BEC3);
  static const Color divider = Color(0xFFEDF2F7);

  // Dark mode
  static const Color darkBackground = Color(0xFF0F0E17);
  static const Color darkSurface = Color(0xFF1A1A2E);
  static const Color darkCard = Color(0xFF16213E);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6C5CE7), Color(0xFF00B4D8)],
  );

  static const LinearGradient incomeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00C49A), Color(0xFF00B4D8)],
  );

  static const LinearGradient expenseGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
  );

  static const LinearGradient purpleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6C5CE7), Color(0xFFa29bfe)],
  );

  // Chart colors
  static const List<Color> chartColors = [
    Color(0xFF6C5CE7),
    Color(0xFF00B4D8),
    Color(0xFF00C49A),
    Color(0xFFFFB300),
    Color(0xFFFF6B6B),
    Color(0xFFFF8E53),
    Color(0xFFa29bfe),
    Color(0xFF74b9ff),
  ];
}
