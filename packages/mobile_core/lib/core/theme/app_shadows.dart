import 'package:flutter/material.dart';
import 'package:mobile_core/core/theme/app_colors.dart';

abstract final class AppShadows {
  static const sm = [
    BoxShadow(
      color: Color(0x1A14213D),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  static const md = [
    BoxShadow(
      color: Color(0x2914213D),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  static const fab = [
    BoxShadow(
      color: Color(0x59D64545),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  static Color get navyTint => AppColors.navy900.withValues(alpha: 0.10);
}
