import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared 0.5s press motion for every tappable control (buttons, tiles, nav).
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius,
    this.enabled = true,
    this.scaleTo = 0.96,
    this.haptic = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final bool enabled;
  final double scaleTo;
  final bool haptic;

  static const duration = Duration(milliseconds: 500);

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Pressable.duration,
  );
  late final Animation<double> _scale = Tween(begin: 1.0, end: widget.scaleTo)
      .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _down() async {
    if (!widget.enabled || widget.onTap == null) return;
    await _c.forward();
  }

  Future<void> _up({required bool fire}) async {
    if (!widget.enabled) return;
    await _c.reverse();
    if (fire && widget.onTap != null) {
      if (widget.haptic) HapticFeedback.selectionClick();
      widget.onTap!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (context, child) => Transform.scale(
        scale: _scale.value,
        child: child,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: null,
          onTapDown: (_) => _down(),
          onTapUp: (_) => _up(fire: true),
          onTapCancel: () => _up(fire: false),
          borderRadius: widget.borderRadius,
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Soft looping “vector” pulse used on featured service tiles.
class VectorPulse extends StatefulWidget {
  const VectorPulse({
    super.key,
    required this.child,
    this.enabled = true,
  });

  final Widget child;
  final bool enabled;

  @override
  State<VectorPulse> createState() => _VectorPulseState();
}

class _VectorPulseState extends State<VectorPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  late final Animation<double> _t = Tween(begin: 0.97, end: 1.03).animate(
    CurvedAnimation(parent: _c, curve: Curves.easeInOut),
  );

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant VectorPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!widget.enabled && _c.isAnimating) {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return AnimatedBuilder(
      animation: _t,
      builder: (context, child) => Transform.scale(scale: _t.value, child: child),
      child: widget.child,
    );
  }
}
