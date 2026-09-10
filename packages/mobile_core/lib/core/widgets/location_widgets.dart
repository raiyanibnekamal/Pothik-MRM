import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_core/core/l10n/app_strings.dart';
import 'package:mobile_core/core/location/location_cubit.dart';
import 'package:mobile_core/core/theme/app_colors.dart';
import 'package:mobile_core/core/theme/app_radius.dart';
import 'package:mobile_core/core/theme/app_shadows.dart';
import 'package:mobile_core/core/theme/app_text.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

/// Explains why the map has no blue dot, and offers the one-tap fix.
///
/// Renders nothing while location is healthy, so it is safe to place above any
/// map without reserving space for it.
class LocationHealthCard extends StatelessWidget {
  const LocationHealthCard({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final live = context.watch<LocationCubit>().state;
    final cubit = context.read<LocationCubit>();

    if (live.status == LocationStatus.ready && live.isPrecise) {
      return const SizedBox.shrink();
    }

    final (icon, title, tone) = switch (live.status) {
      LocationStatus.serviceOff => (
          PhosphorIconsFill.gpsSlash,
          s.locationServiceOff,
          AppColors.danger,
        ),
      LocationStatus.denied || LocationStatus.deniedForever => (
          PhosphorIconsFill.lockKey,
          s.locationDenied,
          AppColors.danger,
        ),
      LocationStatus.failed => (
          PhosphorIconsFill.warning,
          s.locationWeak,
          AppColors.warning,
        ),
      LocationStatus.ready => (
          PhosphorIconsFill.gps,
          s.locationWeak,
          AppColors.warning,
        ),
      _ => (PhosphorIconsFill.gps, s.locationSearching, AppColors.navy900),
    };

    final action = switch (live.status) {
      LocationStatus.serviceOff ||
      LocationStatus.deniedForever =>
        (s.locationOpenSettings, cubit.openSettings),
      LocationStatus.denied => (s.locationTurnOn, () => cubit.ensure()),
      LocationStatus.failed => (s.locationTurnOn, cubit.refresh),
      _ => null,
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: compact ? 8 : 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.borderDefault),
        boxShadow: AppShadows.sm,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: tone),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.label(tone)),
                if (!compact && live.blocked)
                  Text(s.locationBlockedBody, style: AppText.caption()),
              ],
            ),
          ),
          if (action != null)
            TextButton(
              onPressed: action.$2,
              child: Text(action.$1, style: AppText.label(AppColors.navy900)),
            ),
        ],
      ),
    );
  }
}

/// Small "±12 m" readout for screens that need to prove the fix is trustworthy.
class LocationAccuracyChip extends StatelessWidget {
  const LocationAccuracyChip({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final live = context.watch<LocationCubit>().state;
    final accuracy = live.accuracyM;
    if (accuracy == null || live.point == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.9),
        borderRadius: AppRadius.smAll,
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Text(
        s.locationAccuracy(accuracy.round()),
        style: AppText.caption(
          live.isPrecise ? AppColors.textSecondary : AppColors.warning,
        ),
      ),
    );
  }
}
