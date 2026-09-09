import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:mobile_core/core/theme/app_colors.dart';

class CountdownRing extends StatelessWidget {
  const CountdownRing({
    super.key,
    required this.progress,
    required this.child,
    this.size = 56,
  });

  /// 1 = full, 0 = empty
  final double progress;
  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(progress.clamp(0, 1)),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 4;
    final track = Paint()
      ..color = AppColors.navy900
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    final accent = Paint()
      ..color = AppColors.interactiveAccent
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4;
    canvas.drawCircle(c, r, track);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      accent,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class SosHoldFab extends StatefulWidget {
  const SosHoldFab({
    super.key,
    required this.label,
    required this.onConfirmed,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onConfirmed;
  final bool enabled;

  @override
  State<SosHoldFab> createState() => _SosHoldFabState();
}

class _SosHoldFabState extends State<SosHoldFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hold;

  @override
  void initState() {
    super.initState();
    _hold = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          widget.onConfirmed();
          _hold.reset();
        }
      });
  }

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onLongPressStart: widget.enabled ? (_) => _hold.forward() : null,
        onLongPressEnd: (_) => _hold.reverse(),
        onLongPressCancel: _hold.reverse,
        child: AnimatedBuilder(
          animation: _hold,
          builder: (context, _) {
            return Stack(
              alignment: Alignment.center,
              children: [
                CountdownRing(
                  progress: _hold.value,
                  size: 64,
                  child: const SizedBox.shrink(),
                ),
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: AppColors.danger,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x59D64545),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.shield,
                    color: AppColors.textOnPrimary,
                    size: 24,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
