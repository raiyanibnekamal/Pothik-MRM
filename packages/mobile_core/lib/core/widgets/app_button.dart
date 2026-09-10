import 'package:flutter/material.dart';
import 'package:mobile_core/core/theme/app_colors.dart';
import 'package:mobile_core/core/theme/app_radius.dart';
import 'package:mobile_core/core/theme/app_text.dart';
import 'package:mobile_core/core/widgets/pressable.dart';

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
    this.trailing,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool loading;
  final bool expand;
  final double height;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || loading;
    final child = AnimatedSwitcher(
      duration: Pressable.duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
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
          : Row(
              key: ValueKey(label),
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: AppText.button(_fg())),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing!,
                ],
              ],
            ),
    );

    final content = switch (variant) {
      AppButtonVariant.primary => DecoratedBox(
          decoration: BoxDecoration(
            color: disabled
                ? AppColors.interactiveDisabledBg
                : AppColors.interactiveAccent,
            borderRadius: AppRadius.mdAll,
          ),
          child: _box(child),
        ),
      AppButtonVariant.secondary => DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: AppRadius.mdAll,
            border: Border.all(
              color: disabled
                  ? AppColors.borderDefault
                  : AppColors.interactivePrimary,
            ),
          ),
          child: _box(child),
        ),
      AppButtonVariant.danger => DecoratedBox(
          decoration: BoxDecoration(
            color: disabled ? AppColors.interactiveDisabledBg : AppColors.danger,
            borderRadius: AppRadius.mdAll,
          ),
          child: _box(child),
        ),
      AppButtonVariant.text => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: child,
        ),
    };

    final button = Pressable(
      enabled: !disabled,
      onTap: disabled ? null : onPressed,
      borderRadius: AppRadius.mdAll,
      child: content,
    );

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

  Widget _box(Widget child) => AnimatedContainer(
        duration: Pressable.duration,
        curve: Curves.easeOutCubic,
        height: height,
        alignment: Alignment.center,
        child: child,
      );
}
