import 'package:flutter/material.dart';

class AppColors {
  // Pure Dark Obsidian Palette
  static const Color background = Color(0xFF0F0F12);
  static const Color surface = Color(0xFF16161C);
  static const Color border = Color(0xFF282833);

  // Text colors
  static const Color textPrimary = Color(0xFFEEEEF5);
  static const Color textSecondary = Color(0xFF9A9AAB);
  static const Color textMuted = Color(0xFF646473);

  // Accents and Functional Colors
  static const Color damage = Color(0xFFFF4E4E);       // Red for damage / critical indicators
  static const Color heal = Color(0xFF2ECC71);         // Green for health recovery / success
  static const Color tempHp = Color(0xFF3498DB);       // Blue for temporary Hit Points
  static const Color masterMagic = Color(0xFF8E44AD);  // Purple for GM or magic accents
  static const Color primary = Color(0xFFE67E22);      // Orange accent for main buttons/active actions
}
