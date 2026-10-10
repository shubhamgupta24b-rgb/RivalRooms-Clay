import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/ui/components.dart';
import 'package:flutter/services.dart';
import '../shell/local_game_info.dart';
import '../shell/ticking_play.dart';
import 'solo_common.dart';

const switchColors = [Color(0xFFFF1E6E), Color(0xFFFFD600), Color(0xFF00E5FF), Color(0xFF9C4DFF)];

/// A spinning ring of 4 coloured quarters, with a ⭐ in the middle and a colour orb above.
class Ring {
  final double y; // world height of its centre
  final double radius, speed, start;
  bool star = true, orb = true;
  Ring(this.y, this.radius, this.speed, this.start);
  double angleAt(int ms) => start + ms / 1000 * speed;
}

/// Color Switch: tap to hop up. Pass through a ring only where its colour matches your
/// ball. Orbs change your colour; stars are points. The screen is 1 wide, [viewH] tall,
/// heights grow upwards.
class SwitchLogic extends SoloLogic {
  static const viewH = 1.7, ballR = 0.022, thick = 0.035, gravity = -2.4, hop = 0.95;
  final Random rng;
  double y = 0.25, vy = 0, camera = 0;
  int colour = 0;
  bool started = false;
  final List<Ring> rings = [];
  int _last = 0;

  SwitchLogic({Random? random}) : rng = random ?? Random() {
    for (var i = 0; i < 4; i++) {
      _addRing();
    }
  }

  void _addRing() {
    final y = rings.isEmpty ? 0.95 : rings.last.y + 0.9;
    final n = rings.length;
    rings.add(Ring(y, 0.2 + rng.nextDouble() * 0.05, (1.1 + min(n * 0.08, 1.4)) * (rng.nextBool() ? 1 : -1), rng.nextDouble() * 2 * pi));
  }

  void tap() {
    if (over) return;
    started = true;
    vy = hop;
    HapticFeedback.selectionClick().ignore();
    notifyListeners();
  }

  /// Which colour of [ring] is at the ball's position (straight above or below its centre).
  int colourAt(Ring ring, {required bool above}) {
    final a = ((above ? -pi / 2 : pi / 2) - ring.angleAt(now)) % (2 * pi);
    return (a / (pi / 2)).floor() % 4;
  }

  @override
  void step(int now) {
    final dt = ((now - _last) / 1000).clamp(0.0, 0.04);
    _last = now;
    if (!started) {
      notifyListeners();
      return;
    }
    vy += gravity * dt;
    y += vy * dt;
    if (y - camera > viewH * 0.45) camera = y - viewH * 0.45;
    for (final r in rings) {
      // Star in the middle, orb just above the ring.
      if (r.star && (y - r.y).abs() < 0.04) {
        r.star = false;
        score++;
        HapticFeedback.lightImpact().ignore();
      }
      if (r.orb && (y - (r.y + r.radius + 0.17)).abs() < 0.04) {
        r.orb = false;
        colour = (colour + 1 + rng.nextInt(3)) % 4;
      }
      // Touching the ring band: the colour there must match.
      final d = (y - r.y).abs();
      if (d > r.radius - thick / 2 - ballR && d < r.radius + thick / 2 + ballR) {
        if (colourAt(r, above: y > r.y) != colour) {
          HapticFeedback.heavyImpact().ignore();
          gameOver(1200);
          break;
        }
      }
    }
    if (rings.last.y < camera + viewH + 0.5) _addRing();
    rings.removeWhere((r) => r.y < camera - 0.5);
    if (y < camera - 0.05) gameOver(1000); // fell off the bottom
    notifyListeners();
  }
}

final colorSwitchInfo = LocalGameInfo(
  id: 'color_switch',
  title: 'Color Switch',
  emoji: '🎨',
  color: const Color(0xFFFF1E6E),
  tagline: 'Only pass through your own colour!',
  rules: const [
    'Tap to hop up. Don\'t fall off the bottom.',
    'Pass through a spinning ring only where it\'s the same colour as your ball.',
    'The colour orb above each ring changes your colour. Every star is a point.',
  ],
  scoreUnit: 'stars',
  splitScreen: false,
  minPlayers: 1,
  maxPlayers: 1,
  play: (players, onFinished) => TickingPlay<SwitchLogic>(
    create: () => SwitchLogic(),
    onFinished: onFinished,
    builder: (context, g) => SoloFrame(
      title: 'Color Switch',
      score: g.score,
      extra: g.started ? null : 'Tap to start',
      child: LayoutBuilder(builder: (context, c) {
        final w = min(c.maxWidth, c.maxHeight / SwitchLogic.viewH);
        return Center(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => g.tap(),
            child: SizedBox(width: w, height: w * SwitchLogic.viewH, child: ClipRRect(borderRadius: BorderRadius.circular(16), child: CustomPaint(painter: _SwitchPainter(g, w)))),
          ),
        );
      }),
    ),
  ),
);

class _SwitchPainter extends CustomPainter {
  final SwitchLogic g;
  final double s;
  _SwitchPainter(this.g, this.s);



  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF16161D));
    double sy(double y) => size.height - (y - g.camera) * s;
    final cx = size.width / 2;
    for (final r in g.rings) {
      final c = Offset(cx, sy(r.y));
      final rect = Rect.fromCircle(center: c, radius: r.radius * s);
      final a0 = r.angleAt(g.now);
      for (var q = 0; q < 4; q++) {
        canvas.drawArc(rect, a0 + q * pi / 2 + 0.02, pi / 2 - 0.04, false, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = SwitchLogic.thick * s
          ..color = switchColors[q]);
      }
      if (r.star) paintIcon(canvas, GameIcons.star, Rect.fromCenter(center: c, width: 28, height: 28));
      if (r.orb) {
        final oc = Offset(cx, sy(r.y + r.radius + 0.17));
        for (var q = 0; q < 4; q++) {
          canvas.drawArc(Rect.fromCircle(center: oc, radius: 0.025 * s), q * pi / 2, pi / 2, true, Paint()..color = switchColors[q]);
        }
      }
    }
    final ball = Offset(cx, sy(g.y));
    canvas.drawCircle(ball, SwitchLogic.ballR * s * 1.8, Paint()..color = switchColors[g.colour].withValues(alpha: 0.25));
    canvas.drawCircle(ball, SwitchLogic.ballR * s, Paint()..color = switchColors[g.colour]);
    if (!g.started) {
      final tp = TextPainter(text: const TextSpan(text: 'TAP TO START', style: TextStyle(fontFamily: Fonts.display, color: Colors.white70, fontSize: 18, letterSpacing: 2)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, ball.dy + 30));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
