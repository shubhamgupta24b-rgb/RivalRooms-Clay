import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/ui/tokens.dart';
import '../shell/local_game_info.dart';
import '../shell/ticking_play.dart';
import 'solo_common.dart';

class Tile {
  final int lane;
  double y; // top edge, in screen heights (0 = top)
  bool tapped = false;
  Tile(this.lane, this.y);
}

/// Piano Tiles: black tiles fall in 4 lanes. Tap the lowest one before it leaves the
/// screen. Tapping a white square or missing a tile ends the game. It speeds up.
class PianoLogic extends SoloLogic {
  static const lanes = 4, tileH = 0.24;
  final Random _rng;
  final List<Tile> tiles = [];
  bool started = false;
  int? wrongLane;
  double? wrongY;
  int _last = 0;

  PianoLogic({Random? random}) : _rng = random ?? Random() {
    // A full screen of tiles to start, the lowest one ready to tap.
    var y = 1 - tileH - 0.02;
    while (y > -tileH) {
      tiles.add(Tile(_rng.nextInt(lanes), y));
      y -= tileH;
    }
  }

  double get speed =>
      min(1.9, 0.55 + score * 0.018); // screen heights per second
  Tile? get next => tiles.where((t) => !t.tapped).firstOrNull;

  @override
  void step(int now) {
    final dt = ((now - _last) / 1000).clamp(0.0, 0.05);
    _last = now;
    if (!started) return;
    for (final t in tiles) {
      t.y += speed * dt;
    }
    // Keep the column full from the top.
    while (tiles.isEmpty || tiles.last.y > 0) {
      tiles.add(Tile(
          _rng.nextInt(lanes), (tiles.isEmpty ? 0 : tiles.last.y) - tileH));
    }
    tiles.removeWhere((t) => t.tapped && t.y > 1);
    final n = next;
    if (n != null && n.y > 1) {
      wrongLane = n.lane;
      wrongY = 1 - tileH;
      HapticFeedback.heavyImpact().ignore();
      gameOver();
    }
    notifyListeners();
  }

  /// A tap at lane [lane], height [y] (0..1).
  void tap(int lane, double y) {
    if (over) return;
    final n = next;
    if (n == null) return;
    if (lane == n.lane && y >= n.y - 0.05 && y <= n.y + tileH + 0.05) {
      n.tapped = true;
      started = true;
      score++;
      HapticFeedback.selectionClick().ignore();
    } else if (started) {
      // (Before the first tile is tapped, stray taps don't count.)
      wrongLane = lane;
      wrongY = y;
      HapticFeedback.heavyImpact().ignore();
      gameOver();
    }
    notifyListeners();
  }
}

final pianoInfo = LocalGameInfo(
  id: 'piano_tiles',
  title: 'Piano Tiles',
  emoji: '🎹',
  color: const Color(0xFF263238),
  tagline: "Don't tap the white tiles!",
  rules: const [
    'Tap the black tiles as they fall, from the bottom up.',
    'Tap a white square or let a black tile slip off the screen and it\'s over.',
    'Tap the first tile to start. It keeps getting faster!',
  ],
  scoreUnit: 'tiles',
  splitScreen: false,
  minPlayers: 1,
  maxPlayers: 1,
  play: (players, onFinished) => TickingPlay<PianoLogic>(
    create: () => PianoLogic(),
    onFinished: onFinished,
    builder: (context, g) => SoloFrame(
      title: 'Piano Tiles',
      score: g.score,
      child: LayoutBuilder(
        builder: (context, c) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => g.tap(
              (d.localPosition.dx / c.maxWidth * PianoLogic.lanes)
                  .floor()
                  .clamp(0, PianoLogic.lanes - 1),
              d.localPosition.dy / c.maxHeight),
          child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CustomPaint(size: c.biggest, painter: _PianoPainter(g))),
        ),
      ),
    ),
  ),
);

class _PianoPainter extends CustomPainter {
  final PianoLogic g;
  _PianoPainter(this.g);
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width / PianoLogic.lanes, h = size.height;
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    for (var l = 1; l < PianoLogic.lanes; l++) {
      canvas.drawLine(Offset(l * w, 0), Offset(l * w, h),
          Paint()..color = const Color(0xFFCFD8DC));
    }
    for (final t in g.tiles) {
      final r = Rect.fromLTWH(
          t.lane * w + 1, t.y * h + 1, w - 2, PianoLogic.tileH * h - 2);
      canvas.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(6)),
          Paint()
            ..color =
                t.tapped ? const Color(0xFFB0BEC5) : const Color(0xFF1E1B3A));
    }
    final n = g.next;
    if (!g.started && n != null) {
      final tp = TextPainter(
          text: const TextSpan(
              text: 'START',
              style: TextStyle(
                  fontFamily: Fonts.display,
                  color: Colors.white,
                  fontSize: 20,
                  letterSpacing: 1)),
          textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(
          canvas,
          Offset(n.lane * w + (w - tp.width) / 2,
              (n.y + PianoLogic.tileH / 2) * h - tp.height / 2));
    }
    if (g.wrongLane != null) {
      canvas.drawRect(
          Rect.fromLTWH(
              g.wrongLane! * w, (g.wrongY! * h - 30).clamp(0, h - 60), w, 60),
          Paint()..color = Colors.redAccent.withValues(alpha: 0.8));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
