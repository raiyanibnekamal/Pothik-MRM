import 'package:flutter/material.dart';
import 'package:mobile_core/core/theme/app_colors.dart';
import 'package:mobile_core/core/theme/app_radius.dart';
import 'package:mobile_core/core/theme/app_text.dart';

enum AppButtonVariant { primary, secondary, danger, text }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.loading = false,
    this.expand = true,
    this.height = 48,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool loading;
  final bool expand;
  final double height;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || loading;
    final child = AnimatedSwitcher(
      duration: const Duration(milliseconds: 150),
      child: loading
          ? SizedBox(
              key: const ValueKey('spin'),
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: variant == AppButtonVariant.primary
                    ? AppColors.textOnAccent
                    : variant == AppButtonVariant.danger
                        ? AppColors.textOnPrimary
                        : AppColors.interactivePrimary,
              ),
            )
          : Text(
              label,
              key: ValueKey(label),
              style: AppText.button(_fg()),
            ),
    );

    final button = switch (variant) {
      AppButtonVariant.primary => Material(
          color: disabled
              ? AppColors.interactiveDisabledBg
              : AppColors.interactiveAccent,
          borderRadius: AppRadius.mdAll,
          child: InkWell(
            onTap: disabled ? null : onPressed,
            borderRadius: AppRadius.mdAll,
            child: _box(child),
          ),
        ),
      AppButtonVariant.secondary => Material(
          color: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.mdAll,
            side: BorderSide(
              color: disabled
                  ? AppColors.borderDefault
                  : AppColors.interactivePrimary,
            ),
          ),
          child: InkWell(
            onTap: disabled ? null : onPressed,
            borderRadius: AppRadius.mdAll,
            child: _box(child),
          ),
        ),
      AppButtonVariant.danger => Material(
          color: disabled ? AppColors.interactiveDisabledBg : AppColors.danger,
          borderRadius: AppRadius.mdAll,
          child: InkWell(
            onTap: disabled ? null : onPressed,
            borderRadius: AppRadius.mdAll,
            child: _box(child),
          ),
        ),
      AppButtonVariant.text => TextButton(
          onPressed: disabled ? null : onPressed,
          child: child,
        ),
    };

    if (!expand || variant == AppButtonVariant.text) return button;
    return SizedBox(width: double.infinity, child: button);
  }

  Color _fg() {
    if (onPressed == null && !loading) {
      return AppColors.interactiveDisabledText;
    }
    return switch (variant) {
      AppButtonVariant.primary => AppColors.textOnAccent,
      AppButtonVariant.secondary => AppColors.interactivePrimary,
      AppButtonVariant.danger => AppColors.textOnPrimary,
      AppButtonVariant.text => AppColors.textSecondary,
    };
  }

  Widget _box(Widget child) => SizedBox(
        height: height,
        child: Center(child: child),
      );
}
