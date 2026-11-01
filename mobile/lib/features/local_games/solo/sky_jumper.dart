import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../shell/local_game_info.dart';
import '../shell/ticking_play.dart';
import 'solo_common.dart';

enum PadKind { normal, moving, breaking, spring }

class Pad {
  double x; // centre, 0..1 across
  final double y; // height in the world (grows upwards)
  final PadKind kind;
  double dir;
  bool broken = false;
  Pad(this.x, this.y, this.kind, [this.dir = 1]);
}

/// Sky Jumper: you bounce automatically; steer left and right to land on platforms and
/// climb. Moving pads slide, cracked pads break, springs launch you. Falling off the bottom
/// ends it. Score = height climbed. The screen is 1 wide and [viewH] tall.
class SkyLogic extends SoloLogic {
  static const viewH = 1.6,
      padW = 0.2,
      gravity = -2.6,
      bounce = 1.65,
      springBounce = 2.7;
  final Random rng;
  double x = 0.5, y = 0.1, vy = bounce; // the jumper
  double targetX = 0.5; // where the finger is
  double camera = 0; // world height at the bottom of the screen
  double best = 0;
  final List<Pad> pads = [];
  double _topPad = 0;
  int _last = 0;

  SkyLogic({Random? random}) : rng = random ?? Random() {
    pads.add(Pad(0.5, 0.05, PadKind.normal));
    _topPad = 0.05;
    _fill();
  }

  void _fill() {
    while (_topPad < camera + viewH + 0.5) {
      final h = best;
      _topPad += 0.12 + rng.nextDouble() * min(0.2, 0.08 + h / 60);
      final r = rng.nextDouble();
      final kind = h < 3
          ? PadKind.normal
          : r < 0.12
              ? PadKind.spring
              : r < 0.32
                  ? PadKind.moving
                  : r < 0.45
                      ? PadKind.breaking
                      : PadKind.normal;
      pads.add(Pad(padW / 2 + rng.nextDouble() * (1 - padW), _topPad, kind,
          rng.nextBool() ? 1 : -1));
      // Never leave a gap made only of breaking pads.
      if (kind == PadKind.breaking) {
        _topPad += 0.06;
        pads.add(Pad(
            padW / 2 + rng.nextDouble() * (1 - padW), _topPad, PadKind.normal));
      }
    }
    pads.removeWhere((p) => p.y < camera - 0.2);
  }

  void steer(double fingerX) {
    targetX = fingerX.clamp(0.0, 1.0);
  }

  @override
  void step(int now) {
    final dt = ((now - _last) / 1000).clamp(0.0, 0.04);
    _last = now;
    // Glide towards the finger; wrap round the sides.
    x += ((targetX - x).clamp(-1.0, 1.0)) * min(1, dt * 9);
    final prevY = y;
    vy += gravity * dt;
    y += vy * dt;
    for (final p in pads) {
      if (p.kind == PadKind.moving) {
        p.x += p.dir * 0.25 * dt;
        if (p.x < padW / 2 || p.x > 1 - padW / 2) p.dir = -p.dir;
      }
    }
    // Land on a pad only while falling, crossing its top.
    if (vy < 0) {
      for (final p in pads) {
        if (p.broken ||
            (x - p.x).abs() > padW / 2 + 0.02 ||
            !(prevY >= p.y && y <= p.y)) continue;
        if (p.kind == PadKind.breaking) {
          p.broken = true;
          HapticFeedback.selectionClick().ignore();
          continue;
        }
        y = p.y;
        vy = p.kind == PadKind.spring ? springBounce : bounce;
        HapticFeedback.lightImpact().ignore();
        break;
      }
    }
    if (y - camera > viewH * 0.45) camera = y - viewH * 0.45;
    best = max(best, y);
    score = (best * 10).floor();
    _fill();
    if (y < camera - 0.15) gameOver(1000);
    notifyListeners();
  }
}

final skyInfo = LocalGameInfo(
  id: 'sky_jumper',
  title: 'Sky Jumper',
  emoji: '🐸',
  color: const Color(0xFF66BB6A),
  tagline: 'Bounce higher and higher into the sky!',
  rules: const [
    'You bounce by yourself. Slide your finger left and right to steer.',
    'Land on platforms to keep climbing. Blue ones move, cracked stone breaks, yellow springs launch you high.',
    'Fall off the bottom and it\'s over. Score = how high you got.',
  ],
  scoreUnit: 'metres',
  splitScreen: false,
  minPlayers: 1,
  maxPlayers: 1,
  play: (players, onFinished) => TickingPlay<SkyLogic>(
    create: () => SkyLogic(),
    onFinished: onFinished,
    builder: (context, g) => SoloFrame(
      title: 'Sky Jumper',
      score: g.score,
      child: LayoutBuilder(builder: (context, c) {
        final w = min(c.maxWidth, c.maxHeight / SkyLogic.viewH);
        return Center(
          child: SizedBox(
            width: w,
            height: w * SkyLogic.viewH,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanDown: (d) => g.steer(d.localPosition.dx / w),
              onPanUpdate: (d) => g.steer(d.localPosition.dx / w),
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CustomPaint(painter: _SkyPainter(g, w))),
            ),
          ),
        );
      }),
    ),
  ),
);

class _SkyPainter extends CustomPainter {
  final SkyLogic g;
  final double s;
  _SkyPainter(this.g, this.s);

  /// The jumper: a round green hopper with big eyes, feet at [foot].
  static void _jumper(Canvas canvas, Offset foot) {
    const r = 15.0;
    final c = foot - const Offset(0, r);
    canvas.drawOval(
        Rect.fromCenter(
            center: foot + const Offset(-8, -2), width: 12, height: 6),
        Paint()..color = const Color(0xFF2E7D32));
    canvas.drawOval(
        Rect.fromCenter(
            center: foot + const Offset(8, -2), width: 12, height: 6),
        Paint()..color = const Color(0xFF2E7D32));
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = const RadialGradient(
              center: Alignment(-0.3, -0.4),
              colors: [
                Color(0xFFA5E26B),
                Color(0xFF4CAF50),
                Color(0xFF2E7D32)
              ]).createShader(Rect.fromCircle(center: c, radius: r)));
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0xFF1B5E20));
    for (final dx in [-6.0, 6.0]) {
      canvas.drawCircle(c + Offset(dx, -9), 5.5, Paint()..color = Colors.white);
      canvas.drawCircle(c + Offset(dx + 1, -8.5), 2.6,
          Paint()..color = const Color(0xFF1B1B1B));
    }
    canvas.drawArc(
        Rect.fromCenter(center: c + const Offset(0, 2), width: 14, height: 8),
        0.2,
        pi - 0.4,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFF1B5E20));
  }

  @override
  void paint(Canvas canvas, Size size) {
    // The sky darkens towards space as you climb.
    final t = (g.camera / 40).clamp(0.0, 1.0);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(const Color(0xFF4FC3F7), const Color(0xFF1A237E), t)!,
              Color.lerp(const Color(0xFFE1F5FE), const Color(0xFF5C6BC0), t)!,
            ]).createShader(Offset.zero & size),
    );
    // Stars appear high up; clouds lower down (slow parallax).
    final rng = Random(7);
    for (var i = 0; i < 25; i++) {
      final sx = rng.nextDouble() * size.width;
      final sy = (rng.nextDouble() * size.height * 2 + g.camera * s * 0.2) %
          size.height;
      canvas.drawCircle(Offset(sx, sy), 1.5,
          Paint()..color = Colors.white.withValues(alpha: t));
    }
    double sy(double worldY) => size.height - (worldY - g.camera) * s;
    for (final p in g.pads) {
      if (p.broken) continue;
      final col = switch (p.kind) {
        PadKind.normal => const Color(0xFF66BB6A),
        PadKind.moving => const Color(0xFF42A5F5),
        PadKind.breaking => const Color(0xFF8D6E63),
        PadKind.spring => const Color(0xFF66BB6A),
      };
      final r = Rect.fromCenter(
          center: Offset(p.x * s, sy(p.y) + 6),
          width: SkyLogic.padW * s,
          height: 12);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              r.shift(const Offset(0, 3)), const Radius.circular(6)),
          Paint()..color = Colors.black26);
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(6)),
          Paint()..color = col);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(r.left + 4, r.top + 2, r.width - 8, 3),
              const Radius.circular(2)),
          Paint()..color = Colors.white38);
      if (p.kind == PadKind.breaking) {
        final crack = Paint()
          ..color = const Color(0xFF4E342E)
          ..strokeWidth = 2;
        canvas.drawLine(r.topCenter + const Offset(-4, 0),
            r.bottomCenter + const Offset(3, 0), crack);
      }
      if (p.kind == PadKind.spring) {
        canvas.drawRect(
            Rect.fromCenter(
                center: Offset(p.x * s, sy(p.y) - 4), width: 16, height: 10),
            Paint()..color = const Color(0xFFFFD54F));
      }
    }
    _jumper(canvas, Offset(g.x * s, sy(g.y)));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
