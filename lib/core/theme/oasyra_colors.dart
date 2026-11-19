import 'package:flutter/material.dart';

class OasyraColors {
  // Primary Healthcare Palette
  static const Color primary = Color(0xFF6C63FF);
  static const Color primaryLight = Color(0xFFEAE9FF);
  static const Color primarySoft = Color(0xFFF3F1FF);
  static const Color accentLavender = Color(0xFFF0EEFF);
  
  // AI Accent Palette
  static const Color aiAccent = Color(0xFF00D2FF);
  static const Color aiPurple = Color(0xFFA155FF);
  
  // Surface & Background Colors
  static const Color background = Color(0xFFF7F8FC);
  static const Color surface = Colors.white;
  static const Color surfaceSoft = Color(0xFFF2F4FA);
  static const Color border = Color(0xFFE6E8F0);
  
  // Text Colors (High Contrast)
  static const Color textPrimary = Color(0xFF1A1C23);
  static const Color textSecondary = Color(0xFF5A6070);
  static const Color textTertiary = Color(0xFF8A909D);
  
  // Status Colors (Semantic Light Tints)
  static const Color success = Color(0xFF22C55E);
  static const Color successLight = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color infoLight = Color(0xFFE0F2FE);
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, Color(0xFF8B85FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient meshGradient = LinearGradient(
    colors: [background, Color(0xFFE0E3FF), background],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  static const LinearGradient welcomeGradient = LinearGradient(
    colors: [Color(0xFFE6E8FF), Color(0xFFF0F1FF), Color(0xFFFFFFFF)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
