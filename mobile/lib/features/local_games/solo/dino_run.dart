import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/ui/components.dart';
import 'package:flutter/services.dart';
import '../shell/local_game_info.dart';
import '../shell/ticking_play.dart';
import 'solo_common.dart';

/// An obstacle: a cactus on the ground, or a bird flying low or high.
class Obstacle {
  double x; // distance ahead, in metres
  final bool bird;
  final bool high; // birds only: high birds can be run under
  final double width;
  Obstacle(this.x, {this.bird = false, this.high = false, this.width = 0.6});
}

/// Dino Run: the dino runs on its own; tap to jump over cacti and low birds (high birds
/// fly over you). It gets faster. Score = metres run.
class DinoLogic extends SoloLogic {
  static const gravity = -38.0, jumpSpeed = 13.5;
  final Random rng;
  double distance = 0, speed = 9; // metres, metres a second
  double y = 0, vy = 0; // the dino's height
  final List<Obstacle> obstacles = [];
  double _nextAt = 18;
  int _last = 0;
  double get dinoX => 2.0; // where the dino stands, metres from the left edge

  DinoLogic({Random? random}) : rng = random ?? Random();

  bool get onGround => y <= 0;

  void jump() {
    if (over || !onGround) return;
    vy = jumpSpeed;
    HapticFeedback.selectionClick().ignore();
    notifyListeners();
  }

  @override
  void step(int now) {
    final dt = ((now - _last) / 1000).clamp(0.0, 0.05);
    _last = now;
    speed = min(22, 9 + distance / 120);
    distance += speed * dt;
    score = distance.floor();
    vy += gravity * dt;
    y = max(0, y + vy * dt);
    if (y == 0) vy = 0;
    for (final o in obstacles) {
      o.x -= speed * dt;
    }
    obstacles.removeWhere((o) => o.x < -2);
    if (distance + 20 > _nextAt) {
      final bird = distance > 150 && rng.nextDouble() < 0.3;
      obstacles.add(Obstacle(_nextAt - distance + dinoX + 14,
          bird: bird,
          high: bird && rng.nextBool(),
          width: bird ? 0.8 : 0.5 + rng.nextDouble() * 0.6));
      _nextAt += max(7.0, 14 - distance / 80) + rng.nextDouble() * 8;
    }
    // Hit test: the dino is about 0.8 m wide and 1 m tall.
    for (final o in obstacles) {
      final ox = o.x;
      final overlapX = ox < dinoX + 0.5 && ox + o.width > dinoX - 0.3;
      if (!overlapX) continue;
      final hit = o.bird ? (o.high ? false : y < 1.0) : y < 0.9;
      if (hit) {
        HapticFeedback.heavyImpact().ignore();
        gameOver(1300);
        break;
      }
    }
    notifyListeners();
  }
}

final dinoInfo = LocalGameInfo(
  id: 'dino_run',
  title: 'Dino Run',
  emoji: '🦖',
  color: const Color(0xFF8BC34A),
  tagline: 'Jump the cacti, dodge the birds!',
  rules: const [
    'The dino runs by itself. Tap anywhere to jump.',
    'Jump over cacti and low birds. High birds fly over your head.',
    'It keeps getting faster. Score = metres run.',
  ],
  scoreUnit: 'metres',
  splitScreen: false,
  minPlayers: 1,
  maxPlayers: 1,
  play: (players, onFinished) => TickingPlay<DinoLogic>(
    create: () => DinoLogic(),
    onFinished: onFinished,
    builder: (context, g) => SoloFrame(
      title: 'Dino Run',
      score: g.score,
      extra: '${g.speed.toStringAsFixed(0)} m/s',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => g.jump(),
        child: SceneFrame(
            child: CustomPaint(size: Size.infinite, painter: _DinoPainter(g))),
      ),
    ),
  ),
);

class _DinoPainter extends CustomPainter {
  final DinoLogic g;
  _DinoPainter(this.g);

  /// The runner: a green dinosaur facing right, [feet] on the ground, [h] tall. Its legs
  /// swap every few frames to run.
  static void _dino(
      Canvas canvas, Offset feet, double h, bool stepA, bool hurt) {
    final u = h / 10;
    final body = Paint()
      ..color = hurt ? const Color(0xFFE57373) : const Color(0xFF43A047);
    final dark = Paint()
      ..color = hurt ? const Color(0xFFC62828) : const Color(0xFF2E7D32);
    final o = feet - Offset(0, h);
    Offset p(double x, double y) => o + Offset(x * u, y * u);
    // Tail and body.
    canvas.drawPath(
        Path()
          ..moveTo(p(-3.5, 4.5).dx, p(-3.5, 4.5).dy)
          ..quadraticBezierTo(
              p(-1, 3.5).dx, p(-1, 3.5).dy, p(0.5, 4).dx, p(0.5, 4).dy)
          ..lineTo(p(0.5, 6.5).dx, p(0.5, 6.5).dy)
          ..close(),
        body);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromPoints(p(0, 3.6), p(4.6, 7.6)), Radius.circular(1.6 * u)),
        body);
    // Neck and head.
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromPoints(p(2.8, 1.2), p(4.4, 4.6)),
            Radius.circular(0.6 * u)),
        body);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromPoints(p(2.6, 0), p(6.6, 2.4)), Radius.circular(0.9 * u)),
        body);
    canvas.drawCircle(p(4.4, 0.9), 0.55 * u, Paint()..color = Colors.white);
    canvas.drawCircle(
        p(4.6, 0.95), 0.28 * u, Paint()..color = const Color(0xFF1B1B1B));
    canvas.drawLine(
        p(5.2, 1.9),
        p(6.3, 1.9),
        Paint()
          ..color = const Color(0xFF1B5E20)
          ..strokeWidth = 0.25 * u);
    // Arm, belly and back spikes.
    canvas.drawLine(p(4.2, 4.8), p(5.2, 5.6), dark..strokeWidth = 0.6 * u);
    canvas.drawOval(Rect.fromPoints(p(1.4, 5.2), p(4.2, 7.4)),
        Paint()..color = const Color(0x33FFFFFF));
    for (var k = 0; k < 3; k++) {
      canvas.drawPath(
          Path()
            ..addPolygon([
              p(0.6 + k * 1.1, 3.8),
              p(1.1 + k * 1.1, 2.9),
              p(1.6 + k * 1.1, 3.8)
            ], true),
          dark);
    }
    // Legs.
    final leg = Paint()
      ..color = dark.color
      ..strokeWidth = 1.0 * u
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(p(1.4, 7.2), p(stepA ? 1.0 : 1.6, stepA ? 9.6 : 9.0), leg);
    canvas.drawLine(p(3.4, 7.2), p(stepA ? 3.8 : 3.2, stepA ? 9.0 : 9.6), leg);
  }

  /// A cartoon burst for the crash.
  static void _boom(Canvas canvas, Offset c, double r) {
    Path star(double rr) {
      final path = Path();
      for (var k = 0; k < 16; k++) {
        final a = k * pi / 8;
        final d = k.isEven ? rr : rr * 0.55;
        final pt = c + Offset(cos(a), sin(a)) * d;
        k == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
      }
      return path..close();
    }

    canvas.drawPath(star(r), Paint()..color = const Color(0xFFFF7043));
    canvas.drawPath(star(r * 0.6), Paint()..color = const Color(0xFFFFEB3B));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final m = size.width / 12; // pixels per metre (12 m on screen)
    final ground = size.height * 0.72;
    // Sky turns to sunset and night as you go further.
    final t = (g.distance % 1500) / 1500;
    final sky = Color.lerp(const Color(0xFF6A7BD8), const Color(0xFF3A2F6B),
        (sin(t * 2 * pi) + 1) / 2 * 0.6)!;
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                sky,
                const Color(0xFFF59E6B),
                const Color(0xFFFFD9A0)
              ]).createShader(Offset.zero & size));
    // Far hills and clouds, slower than the ground (parallax).
    // Distant flat-topped mesas.
    final mesa = Paint()..color = const Color(0xFFC0714A);
    for (var i = -1; i < 6; i++) {
      final x =
          i * size.width * 0.4 - (g.distance * m * 0.15) % (size.width * 0.4);
      final mh = size.width * (0.12 + 0.05 * (i % 2).abs());
      canvas.drawPath(
          Path()
            ..moveTo(x - size.width * 0.16, ground)
            ..lineTo(x - size.width * 0.1, ground - mh)
            ..lineTo(x + size.width * 0.1, ground - mh)
            ..lineTo(x + size.width * 0.16, ground)
            ..close(),
          mesa);
    }
    final cloud = Paint()..color = Colors.white.withValues(alpha: 0.85);
    for (var i = 0; i < 4; i++) {
      final x =
          (i * size.width * 0.37 - g.distance * m * 0.05) % (size.width + 80) -
              40;
      final y = size.height * (0.12 + 0.1 * (i % 2));
      canvas.drawOval(
          Rect.fromCenter(center: Offset(x, y), width: 70, height: 24), cloud);
      canvas.drawOval(
          Rect.fromCenter(center: Offset(x + 18, y - 8), width: 40, height: 22),
          cloud);
    }
    // Ground with moving stones.
    canvas.drawRect(Rect.fromLTRB(0, ground, size.width, size.height),
        Paint()..color = const Color(0xFFE8C48A));
    canvas.drawLine(
        Offset(0, ground),
        Offset(size.width, ground),
        Paint()
          ..color = const Color(0xFF795548)
          ..strokeWidth = 3);
    final stone = Paint()..color = const Color(0xFFA1887F);
    for (var i = 0; i < 14; i++) {
      final x = (i * 53.0 - g.distance * m) % (size.width + 20);
      canvas.drawCircle(
          Offset(x < 0 ? x + size.width + 20 : x, ground + 10 + (i % 3) * 9),
          2.5,
          stone);
    }
    // Obstacles.
    for (final o in g.obstacles) {
      final x = o.x * m;
      if (o.bird) {
        final by = ground - (o.high ? 2.1 : 0.7) * m;
        final bob = (g.now ~/ 140).isEven ? -m * 0.06 : m * 0.06; // wing flap
        final bs = m * 0.9;
        canvas.save();
        canvas.translate(x + bs, by - bs + bob);
        canvas.scale(-1, 1); // flying towards the dino
        paintIcon(canvas, GameIcons.bird, Rect.fromLTWH(0, 0, bs, bs));
        canvas.restore();
      } else {
        final ch = m * (0.8 + o.width * 0.5);
        paintIcon(canvas, GameIcons.cactus,
            Rect.fromLTWH(x, ground - ch * 0.98, ch * 0.85, ch));
      }
    }
    // The dino (facing right), with a shadow that shrinks as it jumps.
    final dx = g.dinoX * m - m * 0.5;
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(dx + m * 0.55, ground + 4),
            width: m * (0.9 - min(0.5, g.y * 0.15)),
            height: 7),
        Paint()..color = Colors.black26);
    _dino(canvas, Offset(dx + m * 0.2, ground - g.y * m), m * 1.15,
        g.y > 0 || (g.now ~/ 110).isEven, g.over);
    if (g.over)
      _boom(canvas, Offset(dx + m * 0.9, ground - g.y * m - m * 0.8), m * 0.55);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
