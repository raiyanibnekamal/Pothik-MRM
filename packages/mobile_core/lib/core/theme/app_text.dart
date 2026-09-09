import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_core/core/theme/app_colors.dart';

abstract final class AppText {
  static TextStyle get _ui => GoogleFonts.hindSiliguri();
  static TextStyle get _num => GoogleFonts.inter(fontFeatures: const [
        FontFeature.tabularFigures(),
      ]);

  static TextStyle caption([Color? color]) => _ui.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: color ?? AppColors.textSecondary,
      );

  static TextStyle helper([Color? color]) => _ui.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: color ?? AppColors.textSecondary,
      );

  static TextStyle body([Color? color]) => _ui.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: color ?? AppColors.textPrimary,
      );

  static TextStyle label([Color? color]) => _ui.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: color ?? AppColors.textPrimary,
      );

  static TextStyle subhead([Color? color]) => _ui.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: color ?? AppColors.textPrimary,
      );

  static TextStyle title([Color? color]) => _ui.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: color ?? AppColors.textPrimary,
      );

  static TextStyle appBar([Color? color]) => _ui.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: color ?? AppColors.textPrimary,
      );

  static TextStyle button([Color? color]) => _ui.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1,
        color: color ?? AppColors.textOnAccent,
      );

  static TextStyle heroNumber([Color? color]) => _num.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        height: 1.1,
        color: color ?? AppColors.textPrimary,
      );

  static TextStyle otp([Color? color]) => _num.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.1,
        color: color ?? AppColors.textPrimary,
      );

  static TextStyle fare([Color? color]) => _num.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: color ?? AppColors.textPrimary,
      );
}
