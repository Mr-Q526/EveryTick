import 'package:flutter/material.dart';

/// Design tokens 1:1 from constants/theme.ts
class AppColors {
  // Primary brand
  static const primary = Color(0xFF2563EB);
  static const primaryDark = Color(0xFF1E40AF);

  // Dark surfaces
  static const dark = Color(0xFF0F172A);
  static const darkSoft = Color(0xFF1E293B);

  // Light surfaces
  static const bg = Color(0xFFF1F5F9);
  static const card = Color(0xFFFFFFFF);
  static const cardBorder = Color(0xFFE2E8F0);

  // Text hierarchy
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF475569);
  static const textMuted = Color(0xFF94A3B8);
  static const textLight = Color(0xFFCBD5E1);

  // Accents
  static const success = Color(0xFF10B981);
  static const danger = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);

  // 8 curated event colors
  static const eventColors = [
    Color(0xFF3B82F6), // Blue
    Color(0xFF10B981), // Emerald
    Color(0xFF8B5CF6), // Violet
    Color(0xFFF59E0B), // Amber
    Color(0xFFEF4444), // Red
    Color(0xFFEC4899), // Pink
    Color(0xFF06B6D4), // Cyan
    Color(0xFFF97316), // Orange
  ];

  static const eventColorHexes = [
    '#3B82F6', '#10B981', '#8B5CF6', '#F59E0B',
    '#EF4444', '#EC4899', '#06B6D4', '#F97316',
  ];
}

class AppRadius {
  static const double sm = 12;
  static const double md = 20;
  static const double lg = 28;
  static const double xl = 36;
  static const double full = 9999;
}

class AppShadows {
  static List<BoxShadow> get sm => [
        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
      ];
  static List<BoxShadow> get md => [
        BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4)),
      ];
  static List<BoxShadow> get lg => [
        BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 8)),
      ];
  static List<BoxShadow> colored(Color color) => [
        BoxShadow(color: color.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 6)),
      ];
}

/// Parse hex color string like '#3B82F6' to Color
Color hexToColor(String hex) {
  hex = hex.replaceFirst('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  return Color(int.parse(hex, radix: 16));
}
