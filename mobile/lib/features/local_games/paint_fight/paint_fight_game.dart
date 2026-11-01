import 'dart:math';
import 'package:flutter/material.dart';
import '../../guess_person/models/gp_player.dart';
import '../../../core/ui/components.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/split_screen.dart';
import '../shell/ticking_play.dart';

/// Same rules as the online version: claim cells, painting over a rival's cell
/// steals it, most cells after 25 seconds wins.
class PaintFightLogic extends TimedDuel {
  final int cols;
  final int rows;
  final List<int> owner; // -1 = empty
  final List<int> cells;

  PaintFightLogic(
      {int durationMs = 25000, this.cols = 8, this.rows = 12, int players = 2})
      : owner = List.filled(cols * rows, -1),
        cells = List.filled(players, 0),
        super(durationMs);

  @override
  List<int> get scores => cells;

  /// Returns true if the cell changed hands.
  bool paint(int player, int col, int row) {
    if (finished || col < 0 || col >= cols || row < 0 || row >= rows)
      return false;
    final i = row * cols + col;
    final prev = owner[i];
    if (prev == player) return false;
    if (prev >= 0) cells[prev]--;
    owner[i] = player;
    cells[player]++;
    notifyListeners();
    return true;
  }
}

final paintFightInfo = LocalGameInfo(
  id: 'paint_fight',
  title: 'Paint Fight',
  emoji: '🎨',
  color: const Color(0xFF4D96FF),
  tagline: 'Cover the board in your colour!',
  rules: const [
    'Drag your finger to paint the board in your colour.',
    'Start each stroke on your own half, then paint anywhere, even over your rival.',
    'Painting over their cells steals them. Most cells after 25 seconds wins.',
  ],
  scoreUnit: 'cells',
  splitScreen: true,
  bot: botFor<PaintFightLogic>((g, b, now) {
    if (g.finished || !b.due(now)) return;
    b.wait(now, 45, 90); // a fast but human-ish brush
    var (c, r) = (b.memory['pos'] as (int, int)?) ??
        (g.cols ~/ 2, b.seat == 0 ? g.rows - 2 : 1);
    g.paint(b.seat, c, r);
    // Step to a neighbouring cell, preferring ones that aren't ours yet.
    final steps = [
      for (final (dc, dr) in const [(1, 0), (-1, 0), (0, 1), (0, -1)])
        (c + dc, r + dr)
    ]
        .where((p) => p.$1 >= 0 && p.$1 < g.cols && p.$2 >= 0 && p.$2 < g.rows)
        .toList();
    final fresh =
        steps.where((p) => g.owner[p.$2 * g.cols + p.$1] != b.seat).toList();
    (c, r) = fresh.isNotEmpty && b.chance(0.85) ? b.pick(fresh) : b.pick(steps);
    b.memory['pos'] = (c, r);
  }),
  play: (players, onFinished) => TickingPlay<PaintFightLogic>(
    create: () => PaintFightLogic(),
    onFinished: onFinished,
    builder: (context, g) => Column(children: [
      RotatedBox(
          quarterTurns: 2,
          child: _Hud(
              player: players[1],
              seat: 1,
              cells: g.cells[1],
              total: g.owner.length)),
      _Coverage(
          cells: g.cells,
          total: g.owner.length,
          colors: [for (final p in players) p.color]),
      Expanded(child: _PaintBoard(players: players, g: g)),
      DuelMiddleBar(
          players: players,
          scores: g.scores,
          secondsLeft: g.secondsLeft,
          progress: g.progress),
    ]),
  ),
);

class _Hud extends StatelessWidget {
  final GpPlayer player;
  final int seat;
  final int cells;
  final int total;
  const _Hud(
      {required this.player,
      required this.seat,
      required this.cells,
      required this.total});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
        child: Row(children: [
          PlayerBadge(
              index: PlayerPalette.indexOf(player.color) ?? seat,
              size: 24,
              color: player.color,
              initial: player.name),
          const SizedBox(width: 8),
          Expanded(
              child: Text(player.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontFamily: Fonts.body,
                      color: nameColor(player.color),
                      fontWeight: FontWeight.w900,
                      fontSize: 15))),
          Text('${(cells * 100 / total).round()}%',
              style: const TextStyle(
                  fontFamily: Fonts.display,
                  color: Colors.white,
                  fontSize: 26,
                  height: 1,
                  fontFeatures: [FontFeature.tabularFigures()])),
        ]),
      );
}

/// How much of the board each colour covers, as one split bar (empty cells in the middle).
class _Coverage extends StatelessWidget {
  final List<int> cells;
  final int total;
  final List<Color> colors;
  const _Coverage(
      {required this.cells, required this.total, required this.colors});
  @override
  Widget build(BuildContext context) {
    final int empty = max(0, total - cells.fold<int>(0, (a, b) => a + b));
    return Semantics(
      label: 'Board covered: ${[
        for (var i = 0; i < cells.length; i++)
          '${(cells[i] * 100 / total).round()}%'
      ].join(' vs ')}',
      excludeSemantics: true,
      child: Container(
        height: 10,
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
        decoration: BoxDecoration(
            borderRadius: Radii.rChip,
            border: Border.all(color: Colors.white.withValues(alpha: 0.25))),
        clipBehavior: Clip.antiAlias,
        child: Row(children: [
          // Player 2 (top of the screen) on the left so it reads like the board.
          for (final (flex, color) in [
            if (cells.length > 1) (cells[1], colors[1]),
            (empty, const Color(0xFFE6DDCC)),
            (cells[0], colors[0])
          ])
            if (flex > 0)
              Expanded(
                  flex: flex,
                  child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      color: color)),
        ]),
      ),
    );
  }
}

/// Shared board. Each finger belongs to whoever's half it first touched.
class _PaintBoard extends StatefulWidget {
  final List<GpPlayer> players;
  final PaintFightLogic g;
  const _PaintBoard({required this.players, required this.g});
  @override
  State<_PaintBoard> createState() => _PaintBoardState();
}

class _PaintBoardState extends State<_PaintBoard> {
  final _fingers = <int, (int player, Offset last)>{};
  Size _boardSize = Size.zero;
  Offset _origin = Offset.zero;

  PaintFightLogic get g => widget.g;
  double get _cell =>
      min(_boardSize.width / g.cols, _boardSize.height / g.rows);

  void _paintAt(int player, Offset p) {
    final c = _cell;
    if (c <= 0) return;
    final local = p - _origin;
    g.paint(player, (local.dx / c).floor(), (local.dy / c).floor());
  }

  /// Paints every cell along the drag so fast swipes don't leave gaps.
  void _stroke(int player, Offset from, Offset to) {
    final steps = max(1, ((to - from).distance / (_cell / 2)).ceil());
    for (var s = 1; s <= steps; s++) {
      _paintAt(player, Offset.lerp(from, to, s / steps)!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      _boardSize = c.biggest;
      final cell = _cell;
      final w = cell * g.cols, h = cell * g.rows;
      _origin = Offset((c.maxWidth - w) / 2, (c.maxHeight - h) / 2);
      return Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) {
          if (g.finished) return;
          // Bottom half = player 1 (index 0), top half = player 2.
          final player = e.localPosition.dy >= c.maxHeight / 2 ? 0 : 1;
          _fingers[e.pointer] = (player, e.localPosition);
          _paintAt(player, e.localPosition);
        },
        onPointerMove: (e) {
          final f = _fingers[e.pointer];
          if (f == null) return;
          _stroke(f.$1, f.$2, e.localPosition);
          _fingers[e.pointer] = (f.$1, e.localPosition);
        },
        onPointerUp: (e) => _fingers.remove(e.pointer),
        onPointerCancel: (e) => _fingers.remove(e.pointer),
        child: Stack(children: [
          Positioned(
            left: _origin.dx,
            top: _origin.dy,
            width: w,
            height: h,
            child: RepaintBoundary(
                child: CustomPaint(
                    painter: _BoardPainter(
                        g, widget.players.map((p) => p.color).toList(), cell))),
          ),
        ]),
      );
    });
  }
}

class _BoardPainter extends CustomPainter {
  final PaintFightLogic g;
  final List<Color> colors;
  final double cell;
  // Snapshot so shouldRepaint can compare boards.
  final List<int> _owners;
  _BoardPainter(this.g, this.colors, this.cell) : _owners = List.of(g.owner);

  @override
  void paint(Canvas canvas, Size size) {
    final w = g.cols * cell, h = g.rows * cell;
    // A cream canvas; each half lightly tinted in its painter's colour (player 2 on top).
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(0, 0, w, h), Radius.circular(cell * 0.3)),
        Paint()..color = const Color(0xFFF6F0E4));
    if (colors.length >= 2) {
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h / 2),
          Paint()..color = colors[1].withValues(alpha: 0.07));
      canvas.drawRect(Rect.fromLTWH(0, h / 2, w, h / 2),
          Paint()..color = colors[0].withValues(alpha: 0.07));
    }
    // Paper texture: faint grid dots where nobody has painted yet.
    final dot = Paint()..color = const Color(0xFFE2D8C4);
    for (var r = 0; r < g.rows; r++) {
      for (var c = 0; c < g.cols; c++) {
        if (_owners[r * g.cols + c] < 0)
          canvas.drawCircle(
              Offset((c + 0.5) * cell, (r + 0.5) * cell), cell * 0.08, dot);
      }
    }
    // Painted cells are overlapping blobs with a few drips, so the board looks splattered.
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, w, h), Radius.circular(cell * 0.3)));
    final gloss = Paint()..color = Colors.white.withValues(alpha: 0.22);
    for (var r = 0; r < g.rows; r++) {
      for (var c = 0; c < g.cols; c++) {
        final i = r * g.cols + c;
        final o = _owners[i];
        if (o < 0) continue;
        final ctr = Offset((c + 0.5) * cell, (r + 0.5) * cell);
        final paint = Paint()..color = colors[o];
        canvas.drawCircle(ctr, cell * 0.64, paint);
        // Two small drops per cell, placed by its index so they never jump around.
        final a1 = (i * 2.399) % (2 * pi), a2 = a1 + 2.2;
        canvas.drawCircle(
            ctr + Offset(cos(a1), sin(a1)) * cell * 0.62, cell * 0.14, paint);
        canvas.drawCircle(
            ctr + Offset(cos(a2), sin(a2)) * cell * 0.58, cell * 0.1, paint);
      }
    }
    for (var r = 0; r < g.rows; r++) {
      for (var c = 0; c < g.cols; c++) {
        if (_owners[r * g.cols + c] < 0) continue;
        canvas.drawOval(
            Rect.fromLTWH(
                (c + 0.18) * cell, (r + 0.14) * cell, cell * 0.34, cell * 0.2),
            gloss);
      }
    }
    canvas.restore();
    // Halfway line: where each player's strokes must start.
    final y = g.rows * cell / 2;
    final line = Paint()
      ..color = Colors.black38
      ..strokeWidth = 2;
    for (double x = 0; x < size.width; x += 14) {
      canvas.drawLine(Offset(x, y), Offset(min(x + 7, size.width), y), line);
    }
  }

  @override
  bool shouldRepaint(_BoardPainter old) =>
      cell != old.cell || !_listEquals(_owners, old._owners);

  static bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
