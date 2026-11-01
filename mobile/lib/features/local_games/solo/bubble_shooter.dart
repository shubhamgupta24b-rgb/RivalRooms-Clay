import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../shell/local_game_info.dart';
import '../shell/ticking_play.dart';
import 'solo_common.dart';

const _bubbleColors = [
  Color(0xFFE53935),
  Color(0xFF1E88E5),
  Color(0xFF43A047),
  Color(0xFFFDD835),
  Color(0xFF8E24AA)
];

/// Bubble Shooter. The board is 1 unit wide; bubbles sit on a staggered grid of [cols]
/// across (odd rows shifted half a bubble). Aim and fire; 3 or more of a colour pop, and
/// anything left hanging falls. Every few shots that don't pop, a new row pushes down.
class BubbleLogic extends SoloLogic {
  static const cols = 8, deadRow = 13, shotsPerRow = 6;
  static const r = 1 / (cols * 2); // bubble radius
  static final rowH = r * sqrt(3);
  static const speed = 2.4; // units a second

  final Random rng;
  final Map<(int, int), int> grid = {}; // (row, col) -> colour
  late int current, next;
  double aim = -pi / 2; // straight up
  (double, double, double)? flying; // x, y, angle
  int _flyColor = 0;
  int shotsSincePop = 0;
  final List<(double, double, int, int, bool)> effects =
      []; // x, y, colour, start ms, fell (vs popped)
  int _last = 0;

  BubbleLogic({Random? random}) : rng = random ?? Random() {
    for (var row = 0; row < 5; row++) {
      for (var c = 0; c < colsIn(row); c++) {
        grid[(row, c)] = rng.nextInt(_bubbleColors.length);
      }
    }
    current = _pick();
    next = _pick();
  }

  static int colsIn(int row) => row.isOdd ? cols - 1 : cols;
  static (double, double) pos(int row, int col) =>
      (r + col * 2 * r + (row.isOdd ? r : 0), r + row * rowH);
  double get shooterY => r + deadRow * rowH + r * 2.6;
  double get height => shooterY + r * 2;

  /// A colour still on the board (so every shot can be useful).
  int _pick() {
    final left = grid.values.toSet().toList();
    return left.isEmpty
        ? rng.nextInt(_bubbleColors.length)
        : left[rng.nextInt(left.length)];
  }

  void setAim(double x, double y) {
    final a = atan2(y - shooterY, x - 0.5);
    aim = a.clamp(-pi + 0.15, -0.15);
    notifyListeners();
  }

  void fire() {
    if (over || flying != null) return;
    flying = (0.5, shooterY, aim);
    _flyColor = current;
    current = next;
    next = _pick();
    HapticFeedback.selectionClick().ignore();
    notifyListeners();
  }

  void swap() {
    if (flying != null) return;
    final spare = next;
    next = current;
    current = spare;
    notifyListeners();
  }

  @override
  void step(int now) {
    final dt = ((now - _last) / 1000).clamp(0.0, 0.05);
    _last = now;
    effects.removeWhere((e) => now - e.$4 > 700);
    final f = flying;
    if (f == null) {
      notifyListeners();
      return;
    }
    var (x, y, a) = f;
    // Move in small steps so a fast bubble can't skip through others.
    for (var i = 0; i < 6; i++) {
      x += cos(a) * speed * dt / 6;
      y += sin(a) * speed * dt / 6;
      if (x < r) {
        x = r;
        a = pi - a;
      } else if (x > 1 - r) {
        x = 1 - r;
        a = pi - a;
      }
      final touching = y <= r ||
          grid.keys.any((k) {
            final (bx, by) = pos(k.$1, k.$2);
            return (bx - x) * (bx - x) + (by - y) * (by - y) <
                (2 * r * 0.9) * (2 * r * 0.9);
          });
      if (touching) {
        flying = null;
        _stick(x, y);
        notifyListeners();
        return;
      }
    }
    flying = (x, y, a);
    notifyListeners();
  }

  /// Snaps the shot into the nearest free spot, then pops and drops.
  void _stick(double x, double y) {
    (int, int)? best;
    var bestD = double.infinity;
    final row0 = max(0, ((y - r) / rowH).round() - 1);
    for (var row = row0; row <= row0 + 2; row++) {
      for (var c = 0; c < colsIn(row); c++) {
        if (grid.containsKey((row, c))) continue;
        final (bx, by) = pos(row, c);
        final d = (bx - x) * (bx - x) + (by - y) * (by - y);
        if (d < bestD) {
          bestD = d;
          best = (row, c);
        }
      }
    }
    if (best == null) return;
    grid[best] = _flyColor;
    final group = _connected(best, sameColour: true);
    if (group.length >= 3) {
      for (final k in group) {
        final (bx, by) = pos(k.$1, k.$2);
        effects.add((bx, by, grid[k]!, now, false));
        grid.remove(k);
      }
      score += group.length * 10;
      // Anything no longer hanging from the top row falls.
      final held = <(int, int)>{};
      for (final k in grid.keys.where((k) => k.$1 == 0)) {
        held.addAll(_connected(k, sameColour: false));
      }
      final falling = grid.keys.where((k) => !held.contains(k)).toList();
      for (final k in falling) {
        final (bx, by) = pos(k.$1, k.$2);
        effects.add((bx, by, grid[k]!, now, true));
        grid.remove(k);
      }
      score += falling.length * 20;
      shotsSincePop = 0;
      HapticFeedback.mediumImpact().ignore();
      if (grid.isEmpty) {
        score += 500;
        _addRow();
        _addRow();
      }
    } else {
      shotsSincePop++;
      if (shotsSincePop >= shotsPerRow) {
        shotsSincePop = 0;
        _addRow();
      }
    }
    if (grid.keys.any((k) => k.$1 >= deadRow)) gameOver(1300);
  }

  /// Pushes everything down a row (two rows keep the stagger) and adds a fresh row on top.
  void _addRow() {
    final old = Map.of(grid);
    grid.clear();
    for (final e in old.entries) {
      grid[(e.key.$1 + 2, e.key.$2)] = e.value;
    }
    for (var row = 0; row < 2; row++) {
      for (var c = 0; c < colsIn(row); c++) {
        grid[(row, c)] = rng.nextInt(_bubbleColors.length);
      }
    }
  }

  List<(int, int)> _neighbours((int, int) k) {
    final (row, c) = k;
    final odd = row.isOdd;
    return [
      (row, c - 1),
      (row, c + 1),
      (row - 1, odd ? c : c - 1),
      (row - 1, odd ? c + 1 : c),
      (row + 1, odd ? c : c - 1),
      (row + 1, odd ? c + 1 : c),
    ];
  }

  Set<(int, int)> _connected((int, int) start, {required bool sameColour}) {
    final colour = grid[start];
    final seen = <(int, int)>{start};
    final todo = [start];
    while (todo.isNotEmpty) {
      for (final n in _neighbours(todo.removeLast())) {
        if (seen.contains(n) || !grid.containsKey(n)) continue;
        if (sameColour && grid[n] != colour) continue;
        seen.add(n);
        todo.add(n);
      }
    }
    return seen;
  }
}

final bubbleInfo = LocalGameInfo(
  id: 'bubble_shooter',
  title: 'Bubble Shooter',
  emoji: '🫧',
  color: const Color(0xFF29B6F6),
  tagline: 'Aim, bounce, pop three in a row!',
  rules: const [
    'Drag to aim (the dotted line shows the shot), let go to fire. Bubbles bounce off the walls.',
    '3 or more of the same colour pop. Bubbles left hanging fall for bonus points.',
    'Every 6 shots without a pop, new rows push down. Reach the line and it\'s over. Tap the spare bubble to swap.',
  ],
  scoreUnit: 'points',
  splitScreen: false,
  minPlayers: 1,
  maxPlayers: 1,
  play: (players, onFinished) => TickingPlay<BubbleLogic>(
    create: () => BubbleLogic(),
    onFinished: onFinished,
    builder: (context, g) => SoloFrame(
      title: 'Bubble Shooter',
      score: g.score,
      extra: 'New rows in ${BubbleLogic.shotsPerRow - g.shotsSincePop} shots',
      child: LayoutBuilder(builder: (context, c) {
        final w = min(c.maxWidth, c.maxHeight / g.height);
        Offset toUnits(Offset p) => p / w;
        return Center(
          child: SizedBox(
            width: w,
            height: w * g.height,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (d) => g.setAim(
                  toUnits(d.localPosition).dx, toUnits(d.localPosition).dy),
              onPanUpdate: (d) => g.setAim(
                  toUnits(d.localPosition).dx, toUnits(d.localPosition).dy),
              onPanEnd: (_) => g.fire(),
              onTapUp: (d) {
                final u = toUnits(d.localPosition);
                // The spare bubble (bottom right) swaps; anywhere else aims and fires.
                if ((u - Offset(0.85, g.shooterY)).distance <
                    BubbleLogic.r * 2) {
                  g.swap();
                } else {
                  g.setAim(u.dx, u.dy);
                  g.fire();
                }
              },
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CustomPaint(painter: _BubblePainter(g, w))),
            ),
          ),
        );
      }),
    ),
  ),
);

void _bubble(Canvas canvas, Offset c, double radius, Color col,
    {double alpha = 1}) {
  canvas.drawCircle(
      c,
      radius,
      Paint()
        ..shader =
            RadialGradient(center: const Alignment(-0.35, -0.4), colors: [
          Color.lerp(col, Colors.white, 0.55)!.withValues(alpha: alpha),
          col.withValues(alpha: alpha),
          Color.lerp(col, Colors.black, 0.3)!.withValues(alpha: alpha)
        ], stops: const [
          0,
          0.6,
          1
        ]).createShader(Rect.fromCircle(center: c, radius: radius)));
  canvas.drawCircle(c - Offset(radius * 0.35, radius * 0.4), radius * 0.2,
      Paint()..color = Colors.white.withValues(alpha: 0.7 * alpha));
}

class _BubblePainter extends CustomPainter {
  final BubbleLogic g;
  final double s;
  _BubblePainter(this.g, this.s);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0D47A1), Color(0xFF4FC3F7)])
              .createShader(Offset.zero & size));
    final rad = BubbleLogic.r * s;
    // The danger line.
    final dy = (BubbleLogic.r +
            BubbleLogic.deadRow * BubbleLogic.rowH -
            BubbleLogic.r) *
        s;
    for (var x = 0.0; x < size.width; x += 12) {
      canvas.drawLine(
          Offset(x, dy),
          Offset(x + 6, dy),
          Paint()
            ..color = const Color(0x99FF5252)
            ..strokeWidth = 2);
    }
    for (final e in g.grid.entries) {
      final (x, y) = BubbleLogic.pos(e.key.$1, e.key.$2);
      _bubble(canvas, Offset(x * s, y * s), rad * 0.96, _bubbleColors[e.value]);
    }
    // Pops burst, drops fall.
    for (final (x, y, col, ms, fell) in g.effects) {
      final u = (g.now - ms) / 700;
      if (fell) {
        _bubble(canvas, Offset(x * s, (y + u * u * 0.8) * s), rad * 0.96,
            _bubbleColors[col],
            alpha: 1 - u);
      } else {
        canvas.drawCircle(
            Offset(x * s, y * s),
            rad * (1 + u),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3 * (1 - u)
              ..color = _bubbleColors[col].withValues(alpha: 1 - u));
      }
    }
    // Aim guide: dotted, bouncing off the walls.
    if (g.flying == null && !g.over) {
      var x = 0.5, y = g.shooterY, a = g.aim;
      final dot = Paint()..color = Colors.white.withValues(alpha: 0.7);
      for (var i = 0; i < 40; i++) {
        x += cos(a) * 0.035;
        y += sin(a) * 0.035;
        if (x < BubbleLogic.r || x > 1 - BubbleLogic.r) a = pi - a;
        if (y < 0) break;
        canvas.drawCircle(Offset(x * s, y * s), 2.5 * (1 - i / 50), dot);
      }
    }
    final f = g.flying;
    if (f != null)
      _bubble(
          canvas, Offset(f.$1 * s, f.$2 * s), rad, _bubbleColors[g._flyColor]);
    // Shooter and the spare.
    final base = Offset(0.5 * s, g.shooterY * s);
    canvas.drawCircle(
        base, rad * 1.45, Paint()..color = Colors.white.withValues(alpha: 0.2));
    if (g.flying == null) _bubble(canvas, base, rad, _bubbleColors[g.current]);
    _bubble(canvas, Offset(0.85 * s, g.shooterY * s), rad * 0.75,
        _bubbleColors[g.next]);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
