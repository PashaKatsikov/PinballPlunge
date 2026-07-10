import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../media_library.dart';
import '../services/storage.dart';

enum _BallPhase { idle, flying }

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final math.Random _rng = math.Random();

  // Wheel state.
  double _wheelAngle = 0; // radians
  double _rotationSpeed = 1.4; // rad/s
  int _direction = 1;

  // Ball state.
  _BallPhase _phase = _BallPhase.idle;
  double _ballT = 0; // 0 at launcher, 1 at wheel
  int _ballColor = 0;
  int _nextBallColor = 0;

  // Scoring.
  int _score = 0;
  int _streak = 0;
  int _hits = 0;
  bool _gameOver = false;
  int _endBest = 0;

  // Feedback.
  double _hitFlash = 0;

  static const double _flightDuration = 0.26;

  Duration _lastElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ballColor = _rng.nextInt(WheelPalette.count);
    _nextBallColor = _rng.nextInt(WheelPalette.count);
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    double dt = (elapsed - _lastElapsed).inMicroseconds / 1e6;
    _lastElapsed = elapsed;
    if (dt <= 0) return;
    if (dt > 0.05) dt = 0.016; // guard against big frame gaps

    setState(() {
      _wheelAngle += _direction * _rotationSpeed * dt;
      if (_wheelAngle > math.pi * 2) _wheelAngle -= math.pi * 2;
      if (_wheelAngle < 0) _wheelAngle += math.pi * 2;

      if (_hitFlash > 0) {
        _hitFlash = math.max(0, _hitFlash - dt * 2.6);
      }

      if (_phase == _BallPhase.flying) {
        _ballT += dt / _flightDuration;
        if (_ballT >= 1.0) {
          _ballT = 1.0;
          _resolveHit();
        }
      }
    });
  }

  /// Index of the sector currently facing the incoming ball (screen bottom).
  int _targetSector() {
    final double deg = _wheelAngle * 180 / math.pi;
    double effective = (180 - deg) % 360;
    if (effective < 0) effective += 360;
    return (effective ~/ 60) % WheelPalette.count;
  }

  void _launch() {
    if (_gameOver || _phase != _BallPhase.idle) return;
    setState(() {
      _phase = _BallPhase.flying;
      _ballT = 0;
    });
  }

  void _resolveHit() {
    final int target = _targetSector();
    if (target == _ballColor) {
      _hits += 1;
      _streak += 1;
      _score += 10 + (_streak - 1) * 2;
      _hitFlash = 1.0;
      _rotationSpeed = math.min(5.5, _rotationSpeed + 0.12);
      // Add unpredictability once the player is warmed up.
      if (_streak > 2 && _rng.nextDouble() < 0.22) {
        _direction = -_direction;
      }
      _ballColor = _nextBallColor;
      _nextBallColor = _rng.nextInt(WheelPalette.count);
      _phase = _BallPhase.idle;
      _ballT = 0;
    } else {
      _phase = _BallPhase.idle;
      _endGame();
    }
  }

  Future<void> _endGame() async {
    _gameOver = true;
    await Storage.saveResult(score: _score, streak: _streak, hits: _hits);
    if (mounted) {
      setState(() => _endBest = Storage.bestScore);
    }
  }

  void _restart() {
    setState(() {
      _wheelAngle = 0;
      _rotationSpeed = 1.4;
      _direction = 1;
      _phase = _BallPhase.idle;
      _ballT = 0;
      _score = 0;
      _streak = 0;
      _hits = 0;
      _gameOver = false;
      _hitFlash = 0;
      _ballColor = _rng.nextInt(WheelPalette.count);
      _nextBallColor = _rng.nextInt(WheelPalette.count);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(MediaLibrary.bg1, fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(color: Color(0x330B0B2E)),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _launch,
                child: _buildPlayfield(constraints.biggest),
              );
            },
          ),
          SafeArea(child: _buildTopBar()),
          if (_gameOver) _buildGameOver(),
        ],
      ),
    );
  }

  Widget _buildPlayfield(Size size) {
    final double wheelDiameter =
        math.min(size.width * 0.86, size.height * 0.44);
    final double wheelRadius = wheelDiameter / 2;
    final double wheelCenterY = size.height * 0.40;
    final double wheelBottomY = wheelCenterY + wheelRadius;
    final double launchY = size.height * 0.85;
    final double ballRadius = wheelRadius * 0.3;
    final double centerX = size.width / 2;

    // Ball travels straight up from the launcher to the wheel's bottom edge.
    final double ballY = _lerp(launchY, wheelBottomY, _ballT);

    final Color targetColor = WheelPalette.sectors[_targetSector()];

    return Stack(
      children: <Widget>[
        // Guide beam from launcher up to the wheel.
        Positioned(
          left: centerX - 2,
          top: wheelBottomY,
          height: launchY - wheelBottomY,
          child: Container(
            width: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: <Color>[
                  WheelPalette.sectors[_ballColor].withValues(alpha: 0.0),
                  WheelPalette.sectors[_ballColor].withValues(alpha: 0.35),
                ],
              ),
            ),
          ),
        ),

        // Target pointer just below the wheel showing the entry sector color.
        Positioned(
          left: centerX - 14,
          top: wheelBottomY + 6,
          child: CustomPaint(
            size: const Size(28, 20),
            painter: _PointerPainter(color: targetColor),
          ),
        ),

        // Success flash at the impact point.
        if (_hitFlash > 0)
          Positioned(
            left: centerX - wheelRadius * 0.5,
            top: wheelBottomY - wheelRadius * 0.5,
            child: Opacity(
              opacity: _hitFlash.clamp(0.0, 1.0),
              child: Container(
                width: wheelRadius,
                height: wheelRadius,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      Colors.white.withValues(alpha: 0.9),
                      WheelPalette.sectors[_ballColor].withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // The rotating wheel.
        Positioned(
          left: centerX - wheelRadius,
          top: wheelCenterY - wheelRadius,
          width: wheelDiameter,
          height: wheelDiameter,
          child: Transform.rotate(
            angle: _wheelAngle,
            child: Image.asset(MediaLibrary.wheel, fit: BoxFit.contain),
          ),
        ),

        // The current ball.
        Positioned(
          left: centerX - ballRadius,
          top: ballY - ballRadius,
          width: ballRadius * 2,
          height: ballRadius * 2,
          child: Image.asset(MediaLibrary.balls[_ballColor], fit: BoxFit.contain),
        ),

        // Next-ball preview near the launcher.
        Positioned(
          left: centerX + ballRadius + 18,
          top: launchY - ballRadius * 0.55,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              const Text(
                'NEXT',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              SizedBox(
                width: ballRadius * 1.1,
                height: ballRadius * 1.1,
                child: Image.asset(
                  MediaLibrary.balls[_nextBallColor],
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ),

        // Tap hint (only before the first launch).
        if (_score == 0 && _phase == _BallPhase.idle && !_gameOver)
          Positioned(
            left: 0,
            right: 0,
            top: size.height * 0.68,
            child: const Center(
              child: Text(
                'TAP TO LAUNCH',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  shadows: <Shadow>[
                    Shadow(color: Color(0xFF7A5CFF), blurRadius: 12),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Column(
        children: <Widget>[
          // Row 1: back button + three compact stats
          Row(
            children: <Widget>[
              _CircleIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    _StatChip(
                      icon: Icons.emoji_events_rounded,
                      color: const Color(0xFFFFD400),
                      label: 'BEST',
                      value: '${Storage.bestScore}',
                    ),
                    _StatChip(
                      icon: Icons.local_fire_department_rounded,
                      color: const Color(0xFFFF7A18),
                      label: 'STREAK',
                      value: '$_streak',
                    ),
                    _StatChip(
                      icon: Icons.ads_click_rounded,
                      color: const Color(0xFF23D6E0),
                      label: 'HITS',
                      value: '$_hits',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Row 2: score (below the stats, above the wheel)
          Column(
            children: <Widget>[
              const Text(
                'SCORE',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
              Text(
                '$_score',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  shadows: <Shadow>[
                    Shadow(color: Color(0xFFFF2FB3), blurRadius: 14),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGameOver() {
    return Container(
      color: const Color(0xCC000000),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.panel,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0x55FF2FB3)),
            boxShadow: const <BoxShadow>[
              BoxShadow(color: Color(0x66FF2FB3), blurRadius: 30),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                'GAME OVER',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 20),
              _resultRow('Score', '$_score'),
              _resultRow('Best', '$_endBest'),
              _resultRow('Best streak', '$_streak'),
              _resultRow('Hits', '$_hits'),
              const SizedBox(height: 24),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _OverlayButton(
                      label: 'HOME',
                      filled: false,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _OverlayButton(
                      label: 'PLAY AGAIN',
                      filled: true,
                      onTap: _restart,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 16,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

class _PointerPainter extends CustomPainter {
  _PointerPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final Paint glow = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final Path path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, glow);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PointerPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x66000000),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0x66000000),
          border: Border.all(color: const Color(0x33FFFFFF)),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _OverlayButton extends StatelessWidget {
  const _OverlayButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: filled
              ? const LinearGradient(
                  colors: <Color>[Color(0xFFFF2FB3), Color(0xFF7A5CFF)],
                )
              : null,
          color: filled ? null : const Color(0x33FFFFFF),
          border: filled
              ? null
              : Border.all(color: const Color(0x55FFFFFF)),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }
}
