import 'package:flutter/material.dart';
import 'package:mobile_core/core/theme/app_colors.dart';
import 'package:mobile_core/core/theme/app_radius.dart';
import 'package:mobile_core/core/theme/app_shadows.dart';
import 'package:mobile_core/core/theme/app_spacing.dart';
import 'package:mobile_core/core/theme/app_text.dart';
import 'package:mobile_core/core/widgets/app_button.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

class AppBarBack extends StatelessWidget implements PreferredSizeWidget {
  const AppBarBack({
    super.key,
    required this.title,
    this.onBack,
    this.actions,
    this.navy = false,
  });

  final String title;
  final VoidCallback? onBack;
  final List<Widget>? actions;
  final bool navy;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final fg = navy ? AppColors.textOnPrimary : AppColors.textPrimary;
    return AppBar(
      backgroundColor: navy ? AppColors.interactivePrimary : AppColors.bg,
      foregroundColor: fg,
      leading: onBack == null && !Navigator.of(context).canPop()
          ? const SizedBox.shrink()
          : IconButton(
              tooltip: 'Back',
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              icon: Icon(PhosphorIconsBold.arrowLeft, color: fg, size: 24),
              iconSize: 24,
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            ),
      title: Text(title, style: AppText.appBar(fg)),
      actions: actions,
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(AppSpacing.card),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: child,
    );
  }
}

class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.tone = BadgeTone.navy,
    this.icon,
  });

  final String label;
  final BadgeTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      BadgeTone.success => (AppColors.successBg, AppColors.success),
      BadgeTone.danger => (AppColors.dangerBg, AppColors.danger),
      BadgeTone.warning => (AppColors.warningBg, AppColors.warning),
      BadgeTone.navy => (AppColors.navy50, AppColors.navy900),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.smAll),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(label, style: AppText.caption(fg)),
        ],
      ),
    );
  }
}

enum BadgeTone { success, danger, warning, navy }

class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.online, required this.label});

  final bool online;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: online ? AppColors.success : AppColors.textDisabled,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppText.caption(
            online ? AppColors.success : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class ChoiceChipApp extends StatelessWidget {
  const ChoiceChipApp({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.interactivePrimary : AppColors.surface,
      borderRadius: AppRadius.smAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.smAll,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: AppRadius.smAll,
            border: Border.all(
              color: selected
                  ? AppColors.interactivePrimary
                  : AppColors.borderDefault,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: AppText.label(
                selected ? AppColors.textOnPrimary : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<T?> showAppSheet<T>({
  required BuildContext context,
  required Widget child,
  bool isDismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    backgroundColor: AppColors.surface,
    shape: RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderStrong,
                borderRadius: AppRadius.smAll,
              ),
            ),
            Flexible(child: child),
          ],
        ),
      ),
    ),
  );
}

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.warningBg,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(PhosphorIconsBold.wifiSlash,
                  size: 16, color: AppColors.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(message, style: AppText.helper(AppColors.warning)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.body,
    required this.cta,
    required this.onCta,
    this.icon = PhosphorIconsRegular.mapTrifold,
  });

  final String title;
  final String body;
  final String cta;
  final VoidCallback onCta;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text(title, style: AppText.title(), textAlign: TextAlign.left),
          const SizedBox(height: 8),
          Text(body, style: AppText.body(AppColors.textSecondary)),
          const SizedBox(height: 24),
          AppButton(label: cta, onPressed: onCta),
        ],
      ),
    );
  }
}

/// Pulsing placeholder block. Used in cold-load states for cards, lists,
/// and avatars. Drives its own animation so it works inside `Column` /
/// `ListView` without an external controller.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.height = 16,
    this.width,
    this.radius = 8,
    this.duration = const Duration(milliseconds: 1200),
  });

  final double height;
  final double? width;
  final double radius;
  final Duration duration;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat(reverse: true);
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, _) {
        // Map [0,1] -> [0.35, 1.0] for a soft pulse, never fully invisible.
        final t = _opacity.value;
        return Opacity(
          opacity: 0.35 + (0.65 * t),
          child: Container(
            height: widget.height,
            width: widget.width,
            decoration: BoxDecoration(
              color: AppColors.gray100,
              borderRadius: BorderRadius.circular(widget.radius),
            ),
          ),
        );
      },
    );
  }
}

class ConnectingChip extends StatelessWidget {
  const ConnectingChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.smAll,
        boxShadow: AppShadows.sm,
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Text(label, style: AppText.caption()),
    );
  }
}

void showAppSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: error ? AppColors.dangerBg : AppColors.surface,
      content: Text(
        message,
        style: AppText.helper(error ? AppColors.danger : AppColors.textPrimary),
      ),
    ),
  );
}
