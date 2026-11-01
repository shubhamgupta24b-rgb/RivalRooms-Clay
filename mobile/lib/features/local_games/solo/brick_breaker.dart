import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/ui/tokens.dart';
import '../air_hockey/air_hockey_game.dart' show V;
import '../shell/local_game_info.dart';
import '../shell/ticking_play.dart';
import 'solo_common.dart';

/// Brick Breaker: drag the paddle, bounce the ball, smash every brick. 3 lives; each
/// cleared wall brings a faster one. 10 points a brick.
class BrickBreakerLogic extends SoloLogic {
  static const height = 1.5, paddleY = 1.38, paddleW = 0.24, ballR = 0.018;
  static const cols = 8, rows = 6, brickTop = 0.16, brickH = 0.05;
  double paddleX = 0.5;
  V ball = const V(0.5, paddleY - ballR - 0.01);
  V vel = V.zero;
  bool launched = false;
  int lives = 3;
  int level = 1;
  late List<bool> bricks = List.filled(cols * rows, true);
  int _last = 0;

  double get speed => 0.85 + level * 0.12;

  Rect brickRect(int i) => Rect.fromLTWH(
      (i % cols) / cols + 0.006,
      brickTop + (i ~/ cols) * brickH + 0.004,
      1 / cols - 0.012,
      brickH - 0.008);

  void movePaddle(double x) {
    if (over) return;
    paddleX = x.clamp(paddleW / 2, 1 - paddleW / 2);
    if (!launched) ball = V(paddleX, paddleY - ballR - 0.01);
    notifyListeners();
  }

  void launch() {
    if (over || launched) return;
    launched = true;
    vel = V(0.35, -1) * (speed / V(0.35, -1).length);
  }

  @override
  void step(int now) {
    final dt = ((now - _last) / 1000).clamp(0.0, 0.03);
    _last = now;
    if (!launched) return;
    for (var i = 0; i < 3 && !over; i++) {
      _move(dt / 3);
    }
    notifyListeners();
  }

  void _move(double dt) {
    ball = ball + vel * dt;
    if (ball.x < ballR && vel.x < 0 || ball.x > 1 - ballR && vel.x > 0)
      vel = V(-vel.x, vel.y);
    if (ball.y < ballR && vel.y < 0) vel = V(vel.x, -vel.y);
    // Paddle: the further from the centre you hit, the sharper the angle.
    if (vel.y > 0 &&
        ball.y + ballR >= paddleY &&
        ball.y < paddleY + 0.02 &&
        (ball.x - paddleX).abs() <= paddleW / 2 + ballR) {
      final off = ((ball.x - paddleX) / (paddleW / 2)).clamp(-1.0, 1.0);
      final a = off * 1.05;
      vel = V(sin(a), -cos(a)) * speed;
      HapticFeedback.selectionClick().ignore();
    }
    // Bricks.
    for (var i = 0; i < bricks.length; i++) {
      if (!bricks[i]) continue;
      final r = brickRect(i).inflate(ballR);
      if (!r.contains(Offset(ball.x, ball.y))) continue;
      bricks[i] = false;
      score += 10;
      final fromSide = min(ball.x - r.left, r.right - ball.x) <
          min(ball.y - r.top, r.bottom - ball.y);
      vel = fromSide ? V(-vel.x, vel.y) : V(vel.x, -vel.y);
      break;
    }
    if (!bricks.contains(true)) {
      level++;
      bricks = List.filled(cols * rows, true);
      _reset();
    }
    if (ball.y > height) {
      lives--;
      HapticFeedback.heavyImpact().ignore();
      if (lives <= 0) {
        lives = 0;
        vel = V.zero;
        gameOver();
      } else {
        _reset();
      }
    }
  }

  void _reset() {
    launched = false;
    vel = V.zero;
    ball = V(paddleX, paddleY - ballR - 0.01);
  }
}

final brickBreakerInfo = LocalGameInfo(
  id: 'brick_breaker',
  title: 'Brick Breaker',
  emoji: '🧱',
  color: const Color(0xFFFF7043),
  tagline: 'Smash every brick!',
  rules: const [
    'Drag left and right to move the paddle. Tap to launch the ball.',
    'Bounce the ball into the bricks: 10 points each.',
    'Don\'t let it fall! 3 lives. Clear the wall for a faster one.',
  ],
  scoreUnit: 'points',
  splitScreen: false,
  minPlayers: 1,
  maxPlayers: 1,
  play: (players, onFinished) => TickingPlay<BrickBreakerLogic>(
    create: () => BrickBreakerLogic(),
    onFinished: onFinished,
    builder: (context, g) => SoloFrame(
      title: 'Level ${g.level}',
      score: g.score,
      lives: max(0, g.lives),
      child: Center(
        child: AspectRatio(
          aspectRatio: 1 / BrickBreakerLogic.height,
          child: LayoutBuilder(
            builder: (context, c) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: g.launch,
              onPanDown: (d) => g.movePaddle(d.localPosition.dx / c.maxWidth),
              onPanUpdate: (d) => g.movePaddle(d.localPosition.dx / c.maxWidth),
              onPanEnd: (_) => g.launch(),
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child:
                      CustomPaint(size: c.biggest, painter: _BrickPainter(g))),
            ),
          ),
        ),
      ),
    ),
  ),
);

class _BrickPainter extends CustomPainter {
  final BrickBreakerLogic g;
  _BrickPainter(this.g);
  static const _rowColors = [
    Color(0xFFE53935),
    Color(0xFFFF7043),
    Color(0xFFFFCA28),
    Color(0xFF66BB6A),
    Color(0xFF29B6F6),
    Color(0xFFAB47BC)
  ];
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFF0F1438));
    for (var i = 0; i < g.bricks.length; i++) {
      if (!g.bricks[i]) continue;
      final r = g.brickRect(i);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTRB(r.left * s, r.top * s, r.right * s, r.bottom * s),
              const Radius.circular(4)),
          Paint()
            ..color =
                _rowColors[(i ~/ BrickBreakerLogic.cols) % _rowColors.length]);
    }
    final p = Rect.fromCenter(
        center: Offset(g.paddleX * s, (BrickBreakerLogic.paddleY + 0.012) * s),
        width: BrickBreakerLogic.paddleW * s,
        height: 0.024 * s);
    canvas.drawRRect(RRect.fromRectAndRadius(p, const Radius.circular(8)),
        Paint()..color = Colors.white);
    canvas.drawCircle(Offset(g.ball.x * s, g.ball.y * s),
        BrickBreakerLogic.ballR * s, Paint()..color = const Color(0xFFFFD43B));
    if (!g.launched && !g.over) {
      final tp = TextPainter(
          text: const TextSpan(
              text: 'TAP TO LAUNCH',
              style: TextStyle(
                  fontFamily: Fonts.display,
                  color: Colors.white70,
                  fontSize: 22,
                  letterSpacing: 1)),
          textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height * 0.62));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
