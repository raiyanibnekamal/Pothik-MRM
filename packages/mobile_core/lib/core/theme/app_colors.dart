import 'package:flutter/material.dart';

/// The only place hex values exist in Flutter. Widgets import tokens from here.
abstract final class AppColors {
  // Navy ramp
  static const navy50 = Color(0xFFEEF1F6);
  static const navy100 = Color(0xFFD6DCE8);
  static const navy200 = Color(0xFFAEBBD1);
  static const navy300 = Color(0xFF8698B9);
  static const navy400 = Color(0xFF5E75A1);
  static const navy500 = Color(0xFF3B5389);
  static const navy600 = Color(0xFF24406F);
  static const navy700 = Color(0xFF1B325A);
  static const navy800 = Color(0xFF172946);
  static const navy900 = Color(0xFF14213D);
  static const navy950 = Color(0xFF0D1729);

  // Amber ramp
  static const amber50 = Color(0xFFFEF6E9);
  static const amber100 = Color(0xFFFCE7C2);
  static const amber200 = Color(0xFFF9D28E);
  static const amber300 = Color(0xFFF6BD5A);
  static const amber400 = Color(0xFFF4B646);
  static const amber500 = Color(0xFFF2A93C);
  static const amber600 = Color(0xFFD6902B);

  // Gray ramp
  static const gray50 = Color(0xFFF7F7F5);
  static const gray100 = Color(0xFFEFEFEC);
  static const gray200 = Color(0xFFE3E5E8);
  static const gray300 = Color(0xFFC7CBD1);
  static const gray400 = Color(0xFF9CA3AF);
  static const gray500 = Color(0xFF6B7280);
  static const gray700 = Color(0xFF363B47);
  static const gray800 = Color(0xFF23262E);
  static const gray900 = Color(0xFF16181D);
  static const gray950 = Color(0xFF0E0F13);

  // Semantic
  static const bg = gray50;
  static const surface = Color(0xFFFFFFFF);
  static const borderDefault = gray200;
  static const borderStrong = gray300;
  static const textPrimary = gray900;
  static const textSecondary = gray500;
  static const textDisabled = gray400;
  static const textOnPrimary = Color(0xFFFFFFFF);
  static const textOnAccent = navy900;
  static const interactivePrimary = navy900;
  static const interactivePrimaryHover = navy700;
  static const interactivePrimaryPressed = navy950;
  static const interactiveAccent = amber500;
  static const interactiveAccentHover = amber400;
  static const interactiveAccentPressed = amber600;
  static const interactiveDisabledBg = gray100;
  static const interactiveDisabledText = gray400;
  static const success = Color(0xFF1E8A5F);
  static const successBg = Color(0xFFE7F5EE);
  static const danger = Color(0xFFD64545);
  static const dangerBg = Color(0xFFFBEAEA);
  static const warning = Color(0xFFC97A1E);
  static const warningBg = Color(0xFFFBF0E2);
  static const splash = navy950;
  static const mapHeader = navy800;
  static const pickupPin = navy900;
  static const dropPin = amber500;
  static const sosMarker = danger;
}
