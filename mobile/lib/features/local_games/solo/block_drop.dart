import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../shell/local_game_info.dart';
import '../shell/ticking_play.dart';
import 'solo_common.dart';

const _pieceColors = [
  Color(0xFF00BCD4),
  Color(0xFFFFEB3B),
  Color(0xFF9C27B0),
  Color(0xFF4CAF50),
  Color(0xFFF44336),
  Color(0xFF2196F3),
  Color(0xFFFF9800)
];

/// The 7 pieces (I O T S Z J L) as cells in a 4x4 box, rotation 0.
const _shapes = [
  [(0, 1), (1, 1), (2, 1), (3, 1)],
  [(1, 0), (2, 0), (1, 1), (2, 1)],
  [(1, 0), (0, 1), (1, 1), (2, 1)],
  [(1, 0), (2, 0), (0, 1), (1, 1)],
  [(0, 0), (1, 0), (1, 1), (2, 1)],
  [(0, 0), (0, 1), (1, 1), (2, 1)],
  [(2, 0), (0, 1), (1, 1), (2, 1)],
];

class Piece {
  final int kind;
  int x, y, rot;
  Piece(this.kind, this.x, this.y, [this.rot = 0]);

  /// Board cells (col, row) the piece covers.
  List<(int, int)> cells([int? r]) {
    final turns = (r ?? rot) % 4;
    final size = kind == 0 ? 4 : (kind == 1 ? 2 : 3);
    return [
      for (var (cx, cy) in kind == 1
          ? [for (final (a, b) in _shapes[1]) (a - 1, b)]
          : _shapes[kind])
        () {
          var (px, py) = (cx, cy);
          for (var t = 0; t < turns; t++) {
            (px, py) = (size - 1 - py, px);
          }
          return (x + px, y + py);
        }(),
    ];
  }
}

/// Block Drop: falling pieces; fill whole rows to clear them. It speeds up every 10 lines.
class BlockDropLogic extends SoloLogic {
  static const cols = 10, rows = 20;
  final Random rng;
  final List<List<int>> board = List.generate(
      rows, (_) => List.filled(cols, -1)); // -1 empty, else piece kind
  late Piece piece;
  late int next;
  int lines = 0;
  int _fallAt = 0;
  List<int> clearing = [];
  int clearedAt = -10000;
  final List<int> _bag = [];

  BlockDropLogic({Random? random}) : rng = random ?? Random() {
    next = _draw();
    _spawn();
  }

  int get level => 1 + lines ~/ 10;
  int get fallMs => max(90, 800 - (level - 1) * 70);

  int _draw() {
    if (_bag.isEmpty)
      _bag.addAll([for (var i = 0; i < 7; i++) i]..shuffle(rng));
    return _bag.removeLast();
  }

  void _spawn() {
    piece = Piece(next, 3, 0);
    next = _draw();
    if (!_fits(piece.cells())) gameOver(1200);
  }

  bool _fits(List<(int, int)> cells) => cells.every((c) =>
      c.$1 >= 0 &&
      c.$1 < cols &&
      c.$2 < rows &&
      (c.$2 < 0 || board[c.$2][c.$1] < 0));

  bool move(int dx) {
    if (over) return false;
    piece.x += dx;
    if (_fits(piece.cells())) {
      notifyListeners();
      return true;
    }
    piece.x -= dx;
    return false;
  }

  void rotate() {
    if (over) return;
    final r = piece.rot + 1;
    for (final kick in const [0, -1, 1, -2, 2]) {
      piece.x += kick;
      if (_fits(piece.cells(r))) {
        piece.rot = r;
        HapticFeedback.selectionClick().ignore();
        notifyListeners();
        return;
      }
      piece.x -= kick;
    }
  }

  /// One row down; locks the piece if it can't go further.
  bool down() {
    if (over) return false;
    piece.y++;
    if (_fits(piece.cells())) {
      notifyListeners();
      return true;
    }
    piece.y--;
    _lock();
    return false;
  }

  void hardDrop() {
    if (over) return;
    var dropped = 0;
    while (true) {
      piece.y++;
      if (!_fits(piece.cells())) {
        piece.y--;
        break;
      }
      dropped++;
    }
    score += dropped * 2;
    HapticFeedback.mediumImpact().ignore();
    _lock();
  }

  /// Where the piece would land (the ghost).
  int get ghostY {
    final g = Piece(piece.kind, piece.x, piece.y, piece.rot);
    while (_fits(g.cells())) {
      g.y++;
    }
    return g.y - 1;
  }

  void _lock() {
    for (final (c, r) in piece.cells()) {
      if (r < 0) {
        gameOver(1200);
        notifyListeners();
        return;
      }
      board[r][c] = piece.kind;
    }
    final full = [
      for (var r = 0; r < rows; r++)
        if (board[r].every((v) => v >= 0)) r
    ];
    if (full.isNotEmpty) {
      score += const [0, 100, 300, 500, 800][full.length] * level;
      lines += full.length;
      clearing = full;
      clearedAt = now;
      for (final r in full.reversed) {
        board.removeAt(r);
      }
      for (var i = 0; i < full.length; i++) {
        board.insert(0, List.filled(cols, -1));
      }
      HapticFeedback.heavyImpact().ignore();
    }
    _spawn();
    _fallAt = now + fallMs;
    notifyListeners();
  }

  @override
  void step(int now) {
    if (now >= _fallAt) {
      _fallAt = now + fallMs;
      down();
    }
  }
}

final blockDropInfo = LocalGameInfo(
  id: 'block_drop',
  title: 'Block Drop',
  emoji: '🧱',
  color: const Color(0xFF7E57C2),
  tagline: 'Fit the falling blocks, clear the lines!',
  rules: const [
    'Swipe sideways to move. Tap to rotate. Drag down to drop one row, and flick down to slam the piece.',
    'Fill a whole row to clear it. Clear several at once for big points.',
    'Every 10 lines it gets faster. Stack to the top and it\'s over.',
  ],
  scoreUnit: 'points',
  splitScreen: false,
  minPlayers: 1,
  maxPlayers: 1,
  play: (players, onFinished) => TickingPlay<BlockDropLogic>(
    create: () => BlockDropLogic(),
    onFinished: onFinished,
    builder: (context, g) => SoloFrame(
      title: 'Level ${g.level}',
      score: g.score,
      extra: '${g.lines} lines',
      child: Column(children: [
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _BoardView(g: g)),
            const SizedBox(width: 8),
            Column(children: [
              const Text('NEXT',
                  style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 1.2)),
              const SizedBox(height: 4),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(12)),
                child: CustomPaint(painter: _NextPainter(g.next)),
              ),
            ]),
          ]),
        ),
      ]),
    ),
  ),
);

class _BoardView extends StatefulWidget {
  final BlockDropLogic g;
  const _BoardView({required this.g});
  @override
  State<_BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends State<_BoardView> {
  double _dragX = 0, _dragY = 0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final cell = min(c.maxWidth / BlockDropLogic.cols,
            c.maxHeight / BlockDropLogic.rows);
        return Center(
          child: GestureDetector(
            onTap: widget.g.rotate,
            onHorizontalDragStart: (_) => _dragX = 0,
            onHorizontalDragUpdate: (d) {
              _dragX += d.delta.dx;
              while (_dragX.abs() >= cell) {
                widget.g.move(_dragX.sign.toInt());
                _dragX -= _dragX.sign * cell;
              }
            },
            onVerticalDragStart: (_) => _dragY = 0,
            onVerticalDragUpdate: (d) {
              _dragY += d.delta.dy;
              if (_dragY > cell) {
                widget.g.down();
                _dragY = 0;
              }
            },
            onVerticalDragEnd: (d) {
              if ((d.primaryVelocity ?? 0) > 500) widget.g.hardDrop();
            },
            child: Container(
              width: cell * BlockDropLogic.cols,
              height: cell * BlockDropLogic.rows,
              decoration: BoxDecoration(
                  color: const Color(0xFF120E2A),
                  border: Border.all(color: const Color(0xFF7E57C2), width: 2),
                  borderRadius: BorderRadius.circular(6)),
              child: CustomPaint(painter: _BoardPainter(widget.g, cell)),
            ),
          ),
        );
      });
}

void _block(Canvas canvas, Rect r, Color c, {double alpha = 1}) {
  final rr =
      RRect.fromRectAndRadius(r.deflate(1), Radius.circular(r.width * 0.18));
  canvas.drawRRect(rr, Paint()..color = c.withValues(alpha: alpha));
  if (alpha < 1) return;
  canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(r.left + r.width * 0.15, r.top + r.height * 0.12,
              r.width * 0.7, r.height * 0.25),
          Radius.circular(r.width * 0.1)),
      Paint()..color = Colors.white.withValues(alpha: 0.35));
  canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Color.lerp(c, Colors.black, 0.35)!);
}

class _BoardPainter extends CustomPainter {
  final BlockDropLogic g;
  final double cell;
  _BoardPainter(this.g, this.cell);
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = Colors.white.withValues(alpha: 0.04);
    for (var r = 0; r < BlockDropLogic.rows; r++) {
      for (var c = 0; c < BlockDropLogic.cols; c++) {
        final rect = Rect.fromLTWH(c * cell, r * cell, cell, cell);
        final v = g.board[r][c];
        if (v >= 0) {
          _block(canvas, rect, _pieceColors[v]);
        } else {
          canvas.drawRect(rect.deflate(cell * 0.45), grid);
        }
      }
    }
    if (g.over) return;
    final col = _pieceColors[g.piece.kind];
    final gy = g.ghostY;
    for (final (c, r) in g.piece.cells()) {
      final ghostR = r + gy - g.piece.y;
      if (ghostR >= 0)
        _block(canvas, Rect.fromLTWH(c * cell, ghostR * cell, cell, cell), col,
            alpha: 0.22);
    }
    for (final (c, r) in g.piece.cells()) {
      if (r >= 0)
        _block(canvas, Rect.fromLTWH(c * cell, r * cell, cell, cell), col);
    }
    // Flash where lines were just cleared.
    final u = (g.now - g.clearedAt) / 300;
    if (u < 1) {
      for (final r in g.clearing) {
        canvas.drawRect(Rect.fromLTWH(0, r * cell, size.width, cell),
            Paint()..color = Colors.white.withValues(alpha: (1 - u) * 0.7));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _NextPainter extends CustomPainter {
  final int kind;
  _NextPainter(this.kind);
  @override
  void paint(Canvas canvas, Size size) {
    final cells = Piece(kind, 0, 0).cells();
    final minX = cells.map((c) => c.$1).reduce(min),
        maxX = cells.map((c) => c.$1).reduce(max);
    final minY = cells.map((c) => c.$2).reduce(min),
        maxY = cells.map((c) => c.$2).reduce(max);
    final cell = size.width / 5;
    final ox = (size.width - (maxX - minX + 1) * cell) / 2,
        oy = (size.height - (maxY - minY + 1) * cell) / 2;
    for (final (c, r) in cells) {
      _block(
          canvas,
          Rect.fromLTWH(
              ox + (c - minX) * cell, oy + (r - minY) * cell, cell, cell),
          _pieceColors[kind]);
    }
  }

  @override
  bool shouldRepaint(_NextPainter old) => old.kind != kind;
}
