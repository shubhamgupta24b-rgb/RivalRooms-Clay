import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/ui/tokens.dart';
import '../shell/local_game_info.dart';
import '../shell/ticking_play.dart';
import 'solo_common.dart';

class Pipe {
  double x;
  final double gapY; // centre of the gap
  bool passed = false;
  Pipe(this.x, this.gapY);
}

/// Flappy Jump: tap to flap. Fly through the gaps; each pipe passed is a point.
/// World is 1 wide and [height] tall; the bird stays at x = [birdX].
class FlappyLogic extends SoloLogic {
  static const height = 1.5,
      birdX = 0.3,
      birdR = 0.035,
      pipeW = 0.17,
      gap = 0.37;
  static const gravity = 2.7,
      flapVy = -0.85,
      speed = 0.4,
      spacing = 0.62,
      ground = height - 0.08;
  final Random _rng;
  double birdY = height / 2;
  double vy = 0;
  bool started = false;
  final List<Pipe> pipes = [];
  int _last = 0;

  FlappyLogic({Random? random}) : _rng = random ?? Random();

  void flap() {
    if (over) return;
    started = true;
    vy = flapVy;
    HapticFeedback.selectionClick().ignore();
    notifyListeners();
  }

  @override
  void step(int now) {
    final dt = ((now - _last) / 1000).clamp(0.0, 0.05);
    _last = now;
    if (!started) return notifyListeners();
    vy += gravity * dt;
    birdY += vy * dt;
    if (pipes.isEmpty || pipes.last.x < 1 - spacing)
      pipes.add(Pipe(1.1, 0.35 + _rng.nextDouble() * (ground - 0.7)));
    for (final p in pipes) {
      p.x -= speed * dt;
      if (!p.passed && p.x + pipeW < birdX) {
        p.passed = true;
        score++;
      }
    }
    pipes.removeWhere((p) => p.x < -pipeW - 0.1);
    if (birdY - birdR < 0) birdY = birdR;
    if (_hits()) {
      HapticFeedback.heavyImpact().ignore();
      gameOver();
    }
    notifyListeners();
  }

  bool _hits() {
    if (birdY + birdR >= ground) return true;
    for (final p in pipes) {
      if (birdX + birdR > p.x &&
          birdX - birdR < p.x + pipeW &&
          ((birdY - birdR) < p.gapY - gap / 2 ||
              (birdY + birdR) > p.gapY + gap / 2)) return true;
    }
    return false;
  }
}

final flappyInfo = LocalGameInfo(
  id: 'flappy_jump',
  title: 'Flappy Jump',
  emoji: '🐦',
  color: const Color(0xFF4FC3F7),
  tagline: 'Tap, flap, don\'t crash!',
  rules: const [
    'Tap anywhere to flap your wings and fly up.',
    'Fly through the gaps between the pipes. Each one is a point.',
    'Touch a pipe or the ground and it\'s over!',
  ],
  scoreUnit: 'pipes',
  splitScreen: false,
  minPlayers: 1,
  maxPlayers: 1,
  play: (players, onFinished) => TickingPlay<FlappyLogic>(
    create: () => FlappyLogic(),
    onFinished: onFinished,
    builder: (context, g) => SoloFrame(
      title: 'Flappy Jump',
      score: g.score,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => g.flap(),
        child: Center(
          child: AspectRatio(
            aspectRatio: 1 / FlappyLogic.height,
            child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CustomPaint(
                    painter: _FlappyPainter(g), size: Size.infinite)),
          ),
        ),
      ),
    ),
  ),
);

class _FlappyPainter extends CustomPainter {
  final FlappyLogic g;
  _FlappyPainter(this.g);
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width; // 1 world unit
    final rect = Offset.zero & size;
    canvas.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF4FC3F7), Color(0xFFB3E5FC)])
              .createShader(rect));
    // Clouds.
    for (final (x, y) in const [(0.2, 0.2), (0.75, 0.35), (0.45, 0.6)]) {
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(x * s, y * s), width: s * 0.28, height: s * 0.09),
          Paint()..color = Colors.white70);
    }
    final pipe = Paint()..color = const Color(0xFF43A047);
    final edge = Paint()..color = const Color(0xFF2E7D32);
    for (final p in g.pipes) {
      final top = Rect.fromLTRB(p.x * s, 0, (p.x + FlappyLogic.pipeW) * s,
          (p.gapY - FlappyLogic.gap / 2) * s);
      final bottom = Rect.fromLTRB(p.x * s, (p.gapY + FlappyLogic.gap / 2) * s,
          (p.x + FlappyLogic.pipeW) * s, FlappyLogic.ground * s);
      for (final r in [top, bottom]) {
        canvas.drawRect(r, pipe);
        canvas.drawRect(
            Rect.fromLTWH(
                r.left - 4, r == top ? r.bottom - 14 : r.top, r.width + 8, 14),
            edge);
      }
    }
    canvas.drawRect(Rect.fromLTRB(0, FlappyLogic.ground * s, s, size.height),
        Paint()..color = const Color(0xFFDEB887));
    canvas.drawRect(
        Rect.fromLTRB(0, FlappyLogic.ground * s, s, FlappyLogic.ground * s + 8),
        Paint()..color = const Color(0xFF8BC34A));
    // Bird, tilted with its speed.
    canvas.save();
    canvas.translate(FlappyLogic.birdX * s, g.birdY * s);
    canvas.rotate((g.vy * 0.5).clamp(-0.5, 1.2));
    final r = FlappyLogic.birdR * s;
    canvas.drawCircle(Offset.zero, r,
        Paint()..color = g.over ? Colors.redAccent : const Color(0xFFFFD43B));
    canvas.drawCircle(
        Offset(r * 0.35, -r * 0.3), r * 0.28, Paint()..color = Colors.white);
    canvas.drawCircle(
        Offset(r * 0.45, -r * 0.3), r * 0.13, Paint()..color = Colors.black);
    canvas.drawPath(
        Path()
          ..moveTo(r * 0.8, 0)
          ..lineTo(r * 1.45, r * 0.15)
          ..lineTo(r * 0.8, r * 0.35)
          ..close(),
        Paint()..color = const Color(0xFFFF8A3D));
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(-r * 0.3, r * 0.2), width: r * 0.9, height: r * 0.5),
        Paint()..color = const Color(0xFFF5B700));
    canvas.restore();
    if (!g.started) {
      final tp = TextPainter(
        text: const TextSpan(
            text: 'TAP TO FLY',
            style: TextStyle(
                fontFamily: Fonts.display,
                color: Colors.white,
                fontSize: 30,
                shadows: [
                  Shadow(color: Colors.black45, offset: Offset(0, 2))
                ])),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height * 0.3));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
