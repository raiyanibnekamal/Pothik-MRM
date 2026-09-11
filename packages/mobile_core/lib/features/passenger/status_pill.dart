import 'package:flutter/material.dart';
import 'package:mobile_core/core/l10n/app_strings.dart';
import 'package:mobile_core/core/network/error_codes.dart';
import 'package:mobile_core/core/theme/app_colors.dart';
import 'package:mobile_core/core/theme/app_shadows.dart';
import 'package:mobile_core/core/theme/app_text.dart';

/// Floating status chip pinned above the bottom sheet. Shows where the ride
/// is right now and gently pulses to draw the eye when something changes.
///
/// Kept public so screens other than [TrackingScreen] can drop it in (e.g.
/// driver-side mirror) and so widget tests can drive transitions in isolation.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status, this.etaMin});

  final RideStatus status;
  final int? etaMin;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final label = switch (status) {
      RideStatus.requested => s.findingDriver,
      RideStatus.accepted => s.driverArriving,
      RideStatus.driverArriving =>
        etaMin != null ? s.etaPill(etaMin!) : s.driverArriving,
      RideStatus.driverArrived => s.driverArrived,
      RideStatus.inProgress => s.tripStarted,
      RideStatus.completed => s.tripComplete,
      RideStatus.cancelled => s.cancelRide,
      _ => s.findingDriver,
    };
    final tone = switch (status) {
      RideStatus.driverArrived || RideStatus.inProgress => AppColors.success,
      RideStatus.cancelled || RideStatus.noShow => AppColors.danger,
      RideStatus.noDriverAvailable => AppColors.warning,
      _ => AppColors.interactivePrimary,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: Alignment.center,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: tone),
            boxShadow: AppShadows.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PulsingDot(color: tone, active: status != RideStatus.completed),
              const SizedBox(width: 8),
              Text(label, style: AppText.caption(tone)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated dot used inside [StatusPill]. Pulses softly while [active] is
/// true and snaps to a static circle otherwise. Reusable for any "live"
/// indicator (recording, streaming, in-progress).
class PulsingDot extends StatefulWidget {
  const PulsingDot({super.key, required this.color, required this.active});

  final Color color;
  final bool active;

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    if (widget.active) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant PulsingDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.active && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) {
      return Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      );
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return Container(
          width: 10 + (4 * t),
          height: 10 + (4 * t),
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.55 + (0.45 * (1 - t))),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}
