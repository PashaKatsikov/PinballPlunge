import 'package:flutter/material.dart';

/// Primary call-to-action pill used across the gray-flow screens.
///
/// Design targets:
///   - Sits flush inside a horizontal padding rail (no baked-in offset —
///     the caller controls position via [Positioned] / [Center]).
///   - Label is vertically centered via `height: 1.0` line-height to avoid
///     the "tilted button" baseline drift documented in gray_part_pitfalls
///     §13.
///   - Pulsing glow gives the loading-screen / no-wifi hint a heartbeat
///     without any pointer-swallowing animator on top of it.
class NeonPillAction extends StatefulWidget {
  const NeonPillAction({
    super.key,
    required this.label,
    required this.onTap,
    this.compact = false,
    this.width,
    this.height,
  });

  final String label;
  final VoidCallback onTap;
  final bool compact;
  final double? width;
  final double? height;

  @override
  State<NeonPillAction> createState() => _NeonPillActionState();
}

class _NeonPillActionState extends State<NeonPillAction>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  double _scale = 1.0;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double h = widget.height ?? (widget.compact ? 48.0 : 56.0);
    return AnimatedBuilder(
      animation: _pulse,
      builder: (BuildContext context, Widget? child) {
        final double glow = 14 + _pulse.value * 16;
        return GestureDetector(
          onTapDown: (_) => setState(() => _scale = 0.96),
          onTapCancel: () => setState(() => _scale = 1.0),
          onTapUp: (_) {
            setState(() => _scale = 1.0);
            widget.onTap();
          },
          child: AnimatedScale(
            scale: _scale,
            duration: const Duration(milliseconds: 90),
            child: Container(
              width: widget.width,
              height: h,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(h / 2),
                gradient: const LinearGradient(
                  colors: <Color>[Color(0xFFFF2FB3), Color(0xFF7A5CFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.55),
                  width: 1.5,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color:
                        const Color(0xFFFF2FB3).withValues(alpha: 0.55),
                    blurRadius: glow,
                    spreadRadius: 1,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: child,
            ),
          ),
        );
      },
      child: Text(
        widget.label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: widget.compact ? 16 : 19,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          height: 1.0,
          shadows: const <Shadow>[
            Shadow(color: Color(0x66000000), offset: Offset(0, 2), blurRadius: 4),
          ],
        ),
      ),
    );
  }
}

/// Secondary "Skip" action. Rendered as a solid translucent pill (not a
/// bare text link) so it stays visible on any background — see
/// gray_part_pitfalls §12.
class NeonGhostAction extends StatefulWidget {
  const NeonGhostAction({
    super.key,
    required this.label,
    required this.onTap,
    this.compact = false,
    this.width,
    this.height,
  });

  final String label;
  final VoidCallback onTap;
  final bool compact;
  final double? width;
  final double? height;

  @override
  State<NeonGhostAction> createState() => _NeonGhostActionState();
}

class _NeonGhostActionState extends State<NeonGhostAction> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final double h = widget.height ?? (widget.compact ? 40.0 : 48.0);
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.96),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 90),
        child: Container(
          width: widget.width,
          height: h,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(h / 2),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.7),
              width: 1.4,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0x552FA6FF),
                blurRadius: 10,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Text(
            widget.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: widget.compact ? 14 : 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}
