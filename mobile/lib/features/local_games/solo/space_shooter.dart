import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/ui/components.dart';
import 'package:flutter/services.dart';
import '../shell/local_game_info.dart';
import '../shell/ticking_play.dart';
import 'solo_common.dart';

class Alien {
  double x, y;
  final double baseX, phase;
  final int kind; // 0 scout, 1 shooter, 2 tank (takes 3 hits)
  int hp;
  int nextShotAt;
  Alien(this.x, this.y, this.kind, this.phase, this.nextShotAt)
      : baseX = x,
        hp = kind == 2 ? 3 : 1;
}

/// Space Shooter: your ship follows your finger and fires by itself. Shoot the alien waves,
/// dodge their shots, grab ⚡ for double shots. 3 lives. The screen is 1 wide, [viewH] tall.
class SpaceLogic extends SoloLogic {
  static const viewH = 1.6;
  final Random rng;
  double shipX = 0.5, shipY = 1.4, targetX = 0.5, targetY = 1.4;
  int lives = 3, wave = 0;
  int doubleUntil = 0, hitUntil = 0, _nextShot = 0, _nextWaveAt = 600;
  final List<Alien> aliens = [];
  final List<Offset> bullets = [], enemyShots = [];
  final List<Offset> powerUps = [];
  final List<(double, double, int)> booms = [];
  int _last = 0;

  SpaceLogic({Random? random}) : rng = random ?? Random();

  void steer(double x, double y) {
    targetX = x.clamp(0.05, 0.95);
    targetY = y.clamp(viewH * 0.55, viewH - 0.08);
  }

  void _spawnWave() {
    wave++;
    final n = min(5 + wave, 12);
    for (var i = 0; i < n; i++) {
      final kind = wave >= 3 && i % 5 == 0 ? 2 : (wave >= 2 && i.isOdd ? 1 : 0);
      aliens.add(Alien(0.1 + (i % 6) * 0.16, -0.1 - (i ~/ 6) * 0.14, kind,
          rng.nextDouble() * 6, now + 1200 + rng.nextInt(1500)));
    }
  }

  @override
  void step(int now) {
    final dt = ((now - _last) / 1000).clamp(0.0, 0.04);
    _last = now;
    shipX += (targetX - shipX) * min(1, dt * 12);
    shipY += (targetY - shipY) * min(1, dt * 12);
    if (aliens.isEmpty && now >= _nextWaveAt) _spawnWave();
    // Fire.
    if (now >= _nextShot) {
      _nextShot = now + 230;
      if (now < doubleUntil) {
        bullets.addAll([
          Offset(shipX - 0.03, shipY - 0.05),
          Offset(shipX + 0.03, shipY - 0.05)
        ]);
      } else {
        bullets.add(Offset(shipX, shipY - 0.06));
      }
    }
    for (var i = 0; i < bullets.length; i++) {
      bullets[i] = bullets[i] - Offset(0, 1.5 * dt);
    }
    bullets.removeWhere((b) => b.dy < -0.05);
    for (var i = 0; i < enemyShots.length; i++) {
      enemyShots[i] = enemyShots[i] + Offset(0, 0.7 * dt);
    }
    enemyShots.removeWhere((b) => b.dy > viewH + 0.05);
    for (var i = 0; i < powerUps.length; i++) {
      powerUps[i] = powerUps[i] + Offset(0, 0.3 * dt);
    }
    powerUps.removeWhere((p) => p.dy > viewH);
    // Aliens drift down in a wave pattern; shooters fire.
    for (final a in aliens) {
      a.y += (0.05 + wave * 0.008) * dt;
      a.x = (a.baseX + sin(now / 900 + a.phase) * 0.06).clamp(0.05, 0.95);
      if (a.y > 0 && a.kind == 1 && now >= a.nextShotAt) {
        enemyShots.add(Offset(a.x, a.y + 0.03));
        a.nextShotAt = now + 1600 + rng.nextInt(1500);
      }
    }
    // Hits on aliens.
    final spent = <Offset>{};
    for (final a in aliens) {
      for (final b in bullets) {
        if (spent.contains(b)) continue;
        if ((b.dx - a.x).abs() < 0.045 && (b.dy - a.y).abs() < 0.04) {
          spent.add(b);
          a.hp--;
          if (a.hp <= 0) {
            score += const [10, 20, 50][a.kind];
            booms.add((a.x, a.y, now));
            if (rng.nextDouble() < 0.08) powerUps.add(Offset(a.x, a.y));
          }
        }
      }
    }
    bullets.removeWhere(spent.contains);
    aliens.removeWhere((a) => a.hp <= 0);
    if (aliens.isEmpty && _nextWaveAt < now) _nextWaveAt = now + 1500;
    // Power-ups.
    final got = powerUps
        .where(
            (p) => (p.dx - shipX).abs() < 0.06 && (p.dy - shipY).abs() < 0.06)
        .toList();
    if (got.isNotEmpty) {
      doubleUntil = now + 8000;
      powerUps.removeWhere(got.contains);
      HapticFeedback.selectionClick().ignore();
    }
    // Getting hit (shots, or aliens reaching you / getting past).
    if (now >= hitUntil) {
      final shot = enemyShots
          .where(
              (b) => (b.dx - shipX).abs() < 0.04 && (b.dy - shipY).abs() < 0.04)
          .toList();
      final rammed = aliens
          .where((a) =>
              ((a.x - shipX).abs() < 0.06 && (a.y - shipY).abs() < 0.05) ||
              a.y > viewH)
          .toList();
      if (shot.isNotEmpty || rammed.isNotEmpty) {
        enemyShots.removeWhere(shot.contains);
        aliens.removeWhere(rammed.contains);
        lives--;
        hitUntil = now + 1500;
        booms.add((shipX, shipY, now));
        HapticFeedback.heavyImpact().ignore();
        if (lives <= 0) gameOver(1300);
      }
    }
    booms.removeWhere((b) => now - b.$3 > 500);
    notifyListeners();
  }
}

final spaceInfo = LocalGameInfo(
  id: 'space_shooter',
  title: 'Space Shooter',
  emoji: '🚀',
  color: const Color(0xFF5E35B1),
  tagline: 'Blast the alien waves!',
  rules: const [
    'Drag to fly your ship. It fires by itself.',
    'Shoot the aliens: green bugs 10, purple shooters 20, UFO tanks (3 hits) 50. Dodge their shots.',
    'Grab the lightning bolt for double shots. You have 3 lives.',
  ],
  scoreUnit: 'points',
  splitScreen: false,
  minPlayers: 1,
  maxPlayers: 1,
  play: (players, onFinished) => TickingPlay<SpaceLogic>(
    create: () => SpaceLogic(),
    onFinished: onFinished,
    builder: (context, g) => SoloFrame(
      title: 'Wave ${max(1, g.wave)}',
      score: g.score,
      extra: g.now < g.doubleUntil ? 'Double shots!' : null,
      lives: g.lives,
      child: LayoutBuilder(builder: (context, c) {
        final w = min(c.maxWidth, c.maxHeight / SpaceLogic.viewH);
        return Center(
          child: SizedBox(
            width: w,
            height: w * SpaceLogic.viewH,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanDown: (d) => g.steer(
                  d.localPosition.dx / w, d.localPosition.dy / w - 0.12),
              onPanUpdate: (d) => g.steer(
                  d.localPosition.dx / w, d.localPosition.dy / w - 0.12),
              child:
                  SceneFrame(child: CustomPaint(painter: _SpacePainter(g, w))),
            ),
          ),
        );
      }),
    ),
  ),
);

class _SpacePainter extends CustomPainter {
  final SpaceLogic g;
  final double s;
  _SpacePainter(this.g, this.s);

  static void _icon(Canvas canvas, GameIcons icon, Offset at, double size,
      {Color? tint}) {
    final r = Rect.fromCenter(center: at, width: size, height: size);
    if (tint == null) return paintIcon(canvas, icon, r);
    canvas.saveLayer(r.inflate(2),
        Paint()..colorFilter = ColorFilter.mode(tint, BlendMode.modulate));
    paintIcon(canvas, icon, r);
    canvas.restore();
  }

  /// The player's ship, nose up: a white hull, blue cockpit and red fins.
  static void _ship(Canvas canvas, Offset c, double h) {
    final w = h * 0.8;
    Offset p(double x, double y) => c + Offset(x * w, y * h);
    final fin = Paint()..color = const Color(0xFFE53935);
    canvas.drawPath(
        Path()
          ..addPolygon([p(-0.18, 0.05), p(-0.5, 0.42), p(-0.15, 0.32)], true),
        fin);
    canvas.drawPath(
        Path()..addPolygon([p(0.18, 0.05), p(0.5, 0.42), p(0.15, 0.32)], true),
        fin);
    final hull = Path()
      ..moveTo(p(0, -0.5).dx, p(0, -0.5).dy)
      ..quadraticBezierTo(p(0.24, -0.15).dx, p(0.24, -0.15).dy,
          p(0.17, 0.38).dx, p(0.17, 0.38).dy)
      ..lineTo(p(-0.17, 0.38).dx, p(-0.17, 0.38).dy)
      ..quadraticBezierTo(
          p(-0.24, -0.15).dx, p(-0.24, -0.15).dy, p(0, -0.5).dx, p(0, -0.5).dy)
      ..close();
    canvas.drawPath(
        hull,
        Paint()
          ..shader = const LinearGradient(
                  colors: [Color(0xFFFFFFFF), Color(0xFFB0BEC5)])
              .createShader(Rect.fromCenter(center: c, width: w, height: h)));
    canvas.drawPath(
        hull,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0xFF455A64));
    canvas.drawOval(
        Rect.fromCenter(center: p(0, -0.12), width: w * 0.2, height: h * 0.24),
        Paint()..color = const Color(0xFF29B6F6));
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0B0320), Color(0xFF261056)])
              .createShader(Offset.zero & size));
    // Scrolling star field in two layers.
    final rng = Random(3);
    for (var i = 0; i < 60; i++) {
      final layer = i % 2 == 0 ? 0.04 : 0.1;
      final x = rng.nextDouble() * size.width;
      final y = (rng.nextDouble() * size.height + g.now * layer) % size.height;
      canvas.drawCircle(
          Offset(x, y),
          layer == 0.1 ? 1.6 : 1,
          Paint()
            ..color = Colors.white.withValues(alpha: layer == 0.1 ? 0.9 : 0.5));
    }
    // A distant ringed planet drifting down very slowly.
    final pc = Offset(
        size.width * 0.78,
        (size.height * 0.22 + g.now * 0.004) % (size.height * 1.4) -
            size.height * 0.2);
    final pr = size.width * 0.11;
    canvas.drawCircle(
        pc,
        pr,
        Paint()
          ..shader = const RadialGradient(
              center: Alignment(-0.4, -0.4),
              colors: [
                Color(0xFFFFB74D),
                Color(0xFFD84315),
                Color(0xFF4A1A0A)
              ]).createShader(Rect.fromCircle(center: pc, radius: pr)));
    canvas.drawOval(
        Rect.fromCenter(center: pc, width: pr * 3, height: pr * 0.7),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0x88FFE0B2));
    Offset o(double x, double y) => Offset(x * s, y * s);
    for (final p in g.powerUps) {
      canvas.drawCircle(
          o(p.dx, p.dy), s * 0.04, Paint()..color = const Color(0x55FFEB3B));
      _icon(canvas, GameIcons.bolt, o(p.dx, p.dy), s * 0.06);
    }
    for (final a in g.aliens) {
      _icon(canvas, a.kind == 2 ? GameIcons.ufo : GameIcons.alien, o(a.x, a.y),
          s * (a.kind == 2 ? 0.085 : 0.07),
          tint: a.kind == 1 ? const Color(0xFFB388FF) : null);
      if (a.kind == 2) {
        // Health pips under the tank.
        for (var k = 0; k < 3; k++) {
          canvas.drawCircle(
              o(a.x, a.y) + Offset((k - 1) * 8.0, s * 0.052),
              3,
              Paint()
                ..color = k < a.hp
                    ? const Color(0xFF66BB6A)
                    : const Color(0x55FFFFFF));
        }
      }
    }
    final laser = Paint()
      ..color = const Color(0xFF80DEEA)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final b in g.bullets) {
      canvas.drawLine(o(b.dx, b.dy), o(b.dx, b.dy + 0.03), laser);
    }
    final enemy = Paint()..color = const Color(0xFFFF5252);
    for (final b in g.enemyShots) {
      canvas.drawCircle(o(b.dx, b.dy), 4, enemy);
    }
    // The ship blinks while it's recovering from a hit.
    if (!(g.now < g.hitUntil && (g.now ~/ 120).isEven) && !g.over) {
      final flame = 0.6 + 0.4 * sin(g.now / 50);
      canvas.drawOval(
          Rect.fromCenter(
              center: o(g.shipX, g.shipY + 0.045),
              width: s * 0.022,
              height: s * 0.05 * flame),
          Paint()..color = const Color(0xFFFFA726));
      canvas.drawOval(
          Rect.fromCenter(
              center: o(g.shipX, g.shipY + 0.04),
              width: s * 0.012,
              height: s * 0.028 * flame),
          Paint()..color = const Color(0xFFFFF59D));
      _ship(canvas, o(g.shipX, g.shipY), s * 0.085);
    }
    for (final (x, y, ms) in g.booms) {
      final u = (g.now - ms) / 500;
      canvas.drawCircle(
          o(x, y),
          s * (0.02 + u * 0.06),
          Paint()
            ..color =
                Color.lerp(const Color(0xFFFFF176), const Color(0xFFFF5722), u)!
                    .withValues(alpha: 1 - u));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
