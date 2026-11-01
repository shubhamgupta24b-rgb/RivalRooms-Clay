import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../shell/local_game_info.dart';
import '../shell/ticking_play.dart';
import 'solo_common.dart';

class Block {
  final double left, width;
  const Block(this.left, this.width);
  double get right => left + width;
}

/// Stack Tower: a block slides back and forth; tap to drop it on the tower. Whatever
/// hangs over the edge is cut off. A perfect drop keeps the full width. Miss and it's over.
class StackLogic extends SoloLogic {
  static const perfect = 0.012;
  final List<Block> tower = [const Block(0.2, 0.6)];
  double movingLeft = 0;
  int _dirSign = 1;
  int _last = 0;
  int perfects = 0;
  int? lastPerfectAt;

  double get width => tower.last.width;
  double get speed => min(1.3, 0.45 + tower.length * 0.025);

  @override
  void step(int now) {
    final dt = ((now - _last) / 1000).clamp(0.0, 0.05);
    _last = now;
    movingLeft += _dirSign * speed * dt;
    if (movingLeft + width > 1.15) _dirSign = -1;
    if (movingLeft < -0.15) _dirSign = 1;
    notifyListeners();
  }

  void drop() {
    if (over) return;
    final below = tower.last;
    var left = movingLeft;
    if ((left - below.left).abs() <= perfect) {
      left = below.left; // snap: perfect!
      perfects++;
      lastPerfectAt = now;
      HapticFeedback.mediumImpact().ignore();
    }
    final l = max(left, below.left), r = min(left + width, below.right);
    if (r - l <= 0.005) {
      HapticFeedback.heavyImpact().ignore();
      gameOver();
      return;
    }
    tower.add(Block(l, r - l));
    score = tower.length - 1;
    // The next block starts from a side.
    _dirSign = tower.length.isEven ? 1 : -1;
    movingLeft = _dirSign == 1 ? -0.1 : 1.1 - (r - l);
    HapticFeedback.selectionClick().ignore();
    notifyListeners();
  }
}

final stackInfo = LocalGameInfo(
  id: 'stack_tower',
  title: 'Stack Tower',
  emoji: '🏗️',
  color: const Color(0xFF7E57C2),
  tagline: 'Stack it high, cut it fine!',
  rules: const [
    'A block slides across. Tap to drop it onto the tower.',
    'Whatever hangs over the edge gets sliced off, so your blocks get thinner.',
    'Line it up perfectly to keep its width. Miss completely and the tower is done!',
  ],
  scoreUnit: 'blocks',
  splitScreen: false,
  minPlayers: 1,
  maxPlayers: 1,
  play: (players, onFinished) => TickingPlay<StackLogic>(
    create: () => StackLogic(),
    onFinished: onFinished,
    builder: (context, g) => SoloFrame(
      title: g.lastPerfectAt != null && g.now - g.lastPerfectAt! < 900
          ? 'Perfect!'
          : 'Stack Tower',
      score: g.score,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => g.drop(),
        child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: CustomPaint(size: Size.infinite, painter: _StackPainter(g))),
      ),
    ),
  ),
);

class _StackPainter extends CustomPainter {
  final StackLogic g;
  _StackPainter(this.g);
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, bh = min(size.height / 14, 40.0);
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF311B92), Color(0xFF7E57C2)])
              .createShader(Offset.zero & size));
    // Keep the top of the tower in view.
    final visible = (size.height / bh).floor() - 4;
    final first = max(0, g.tower.length - visible);
    Color colorOf(int i) =>
        HSVColor.fromAHSV(1, (i * 13) % 360, 0.55, 0.95).toColor();
    for (var i = first; i < g.tower.length; i++) {
      final b = g.tower[i];
      final y = size.height - (i - first + 1) * bh;
      canvas.drawRect(Rect.fromLTWH(b.left * w, y, b.width * w, bh - 1),
          Paint()..color = colorOf(i));
    }
    if (!g.over) {
      final y = size.height - (g.tower.length - first + 1) * bh - bh * 0.6;
      canvas.drawRect(Rect.fromLTWH(g.movingLeft * w, y, g.width * w, bh - 1),
          Paint()..color = colorOf(g.tower.length));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
