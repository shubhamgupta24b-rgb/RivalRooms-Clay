import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/ui/components.dart';
import 'package:flutter/services.dart';
import '../shell/local_game_info.dart';
import '../shell/ticking_play.dart';
import 'solo_common.dart';

/// Classic Snake: eat the food to grow (and speed up). Don't hit a wall or yourself.
class ClassicSnakeLogic extends SoloLogic {
  static const cols = 15, rows = 21;
  static const _dx = [0, 1, 0, -1], _dy = [-1, 0, 1, 0];
  final Random _rng;
  final List<int> body = []; // head first
  int dir = 0;
  int? _queued;
  late int food;
  int _nextStep = 600;

  ClassicSnakeLogic({Random? random}) : _rng = random ?? Random() {
    final start = (rows ~/ 2) * cols + cols ~/ 2;
    body.addAll([start, start + cols, start + 2 * cols]);
    _placeFood();
  }

  int get stepMs => max(70, 170 - score * 5);

  void _placeFood() {
    final free = [
      for (var i = 0; i < cols * rows; i++)
        if (!body.contains(i)) i
    ];
    food = free[_rng.nextInt(free.length)];
  }

  /// Turn to [d] (0 up, 1 right, 2 down, 3 left); reversing into yourself is ignored.
  void turn(int d) {
    if (over || d == (dir + 2) % 4) return;
    _queued = d;
  }

  @override
  void step(int now) {
    var moved = false;
    while (now >= _nextStep && !over) {
      _nextStep += stepMs;
      if (_queued != null) dir = _queued!;
      _queued = null;
      final h = body.first;
      final x = h % cols + _dx[dir], y = h ~/ cols + _dy[dir];
      final next = y * cols + x;
      // Moving into the tail's cell is fine: the tail moves away this step.
      if (x < 0 ||
          x >= cols ||
          y < 0 ||
          y >= rows ||
          (body.contains(next) && next != body.last)) {
        HapticFeedback.heavyImpact().ignore();
        gameOver();
        return;
      }
      body.insert(0, next);
      if (next == food) {
        score++;
        HapticFeedback.selectionClick().ignore();
        if (body.length < cols * rows) _placeFood();
      } else {
        body.removeLast();
      }
      moved = true;
    }
    if (moved) notifyListeners();
  }
}

final classicSnakeInfo = LocalGameInfo(
  id: 'classic_snake',
  title: 'Classic Snake',
  emoji: '🐍',
  color: const Color(0xFF55B33B),
  tagline: 'Eat, grow, don\'t bite yourself!',
  rules: const [
    'Swipe on the board (or tap the arrows) to steer.',
    'Eat the apple to grow longer. You get faster as you grow.',
    'Hit a wall or your own tail and it\'s game over.',
  ],
  scoreUnit: 'apples',
  splitScreen: false,
  minPlayers: 1,
  maxPlayers: 1,
  play: (players, onFinished) => TickingPlay<ClassicSnakeLogic>(
    create: () => ClassicSnakeLogic(),
    onFinished: onFinished,
    builder: (context, g) => SoloFrame(
      title: 'Classic Snake',
      score: g.score,
      child: Column(children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanEnd: (d) {
              final dir = swipeDir(d.velocity.pixelsPerSecond, minSpeed: 60);
              if (dir != null) g.turn(dir);
            },
            child: Center(
                child: AspectRatio(
                    aspectRatio:
                        ClassicSnakeLogic.cols / ClassicSnakeLogic.rows,
                    child: CustomPaint(painter: _SnakePainter(g)))),
          ),
        ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (final (d, icon) in const [
            (3, Icons.arrow_back_rounded),
            (0, Icons.arrow_upward_rounded),
            (2, Icons.arrow_downward_rounded),
            (1, Icons.arrow_forward_rounded)
          ])
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: IconButton.filled(
                iconSize: 30,
                style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF55B33B)),
                onPressed: () => g.turn(d),
                icon: Icon(icon),
              ),
            ),
        ]),
      ]),
    ),
  ),
);

class _SnakePainter extends CustomPainter {
  final ClassicSnakeLogic g;
  _SnakePainter(this.g);
  @override
  void paint(Canvas canvas, Size size) {
    const c = ClassicSnakeLogic.cols;
    final s = size.width / c;
    // A lawn with checker shading.
    canvas.drawRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
        Paint()..color = const Color(0xFF4E9A3A));
    for (var i = 0; i < c * ClassicSnakeLogic.rows; i++) {
      if (((i % c) + (i ~/ c)).isEven)
        canvas.drawRect(Rect.fromLTWH((i % c) * s, (i ~/ c) * s, s, s),
            Paint()..color = const Color(0xFF5AA944));
    }
    Rect cell(int i, [double inset = 1]) => Rect.fromLTWH((i % c) * s + inset,
        (i ~/ c) * s + inset, s - 2 * inset, s - 2 * inset);
    paintIcon(canvas, GameIcons.apple, cell(g.food, -s * 0.05));
    for (var k = g.body.length - 1; k >= 0; k--) {
      final color = Color.lerp(const Color(0xFF3B82F6), const Color(0xFF1D4ED8),
          k / max(1, g.body.length - 1))!;
      canvas.drawRRect(
          RRect.fromRectAndRadius(cell(g.body[k]), Radius.circular(s * 0.3)),
          Paint()..color = g.over ? Colors.redAccent : color);
    }
    // Eyes on the head.
    final h = cell(g.body.first).center;
    for (final o in [
      Offset(-s * 0.18, -s * 0.12),
      Offset(s * 0.18, -s * 0.12)
    ]) {
      canvas.drawCircle(h + o, s * 0.1, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
