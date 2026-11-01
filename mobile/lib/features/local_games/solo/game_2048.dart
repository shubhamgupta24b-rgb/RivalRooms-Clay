import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/ui/components.dart';
import '../../../core/ui/materials/materials.dart';
import 'package:flutter/services.dart';
import '../shell/local_game_info.dart';
import '../shell/ticking_play.dart';
import 'solo_common.dart';

/// 2048: swipe to slide all tiles; equal tiles that meet merge and add to your score.
/// A new 2 (sometimes 4) appears after every move. No moves left: game over.
class Game2048Logic extends SoloLogic {
  static const n = 4;
  final Random _rng;
  final List<int> grid = List.filled(n * n, 0);
  int? lastNew;
  int moves = 0;
  List<int>? _undoGrid;
  int _undoScore = 0;

  Game2048Logic({Random? random, List<int>? start})
      : _rng = random ?? Random() {
    if (start != null) {
      grid.setAll(0, start);
    } else {
      _spawn();
      _spawn();
    }
  }

  int get best => grid.reduce(max);

  void _spawn() {
    final empty = [
      for (var i = 0; i < n * n; i++)
        if (grid[i] == 0) i
    ];
    if (empty.isEmpty) return;
    final i = empty[_rng.nextInt(empty.length)];
    grid[i] = _rng.nextInt(10) == 0 ? 4 : 2;
    lastNew = i;
  }

  /// Cell indexes of each line, listed in the direction tiles slide (0 up, 1 right, 2 down, 3 left).
  static List<List<int>> lines(int dir) => [
        for (var k = 0; k < n; k++)
          switch (dir) {
            0 => [for (var r = 0; r < n; r++) r * n + k],
            1 => [for (var c = n - 1; c >= 0; c--) k * n + c],
            2 => [for (var r = n - 1; r >= 0; r--) r * n + k],
            _ => [for (var c = 0; c < n; c++) k * n + c],
          },
      ];

  bool get canMove {
    if (grid.contains(0)) return true;
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        final v = grid[r * n + c];
        if (c + 1 < n && grid[r * n + c + 1] == v) return true;
        if (r + 1 < n && grid[(r + 1) * n + c] == v) return true;
      }
    }
    return false;
  }

  /// Returns true if anything moved.
  void undo() {
    final prev = _undoGrid;
    if (prev == null || over) return;
    grid.setAll(0, prev);
    score = _undoScore;
    _undoGrid = null;
    moves = max(0, moves - 1);
    notifyListeners();
  }

  bool move(int dir) {
    if (over) return false;
    var changed = false;
    final before = [...grid];
    final beforeScore = score;
    for (final line in lines(dir)) {
      final vals = [
        for (final i in line)
          if (grid[i] != 0) grid[i]
      ];
      final out = <int>[];
      for (var i = 0; i < vals.length; i++) {
        if (i + 1 < vals.length && vals[i] == vals[i + 1]) {
          out.add(vals[i] * 2);
          score += vals[i] * 2;
          i++;
        } else {
          out.add(vals[i]);
        }
      }
      while (out.length < n) {
        out.add(0);
      }
      for (var k = 0; k < n; k++) {
        if (grid[line[k]] != out[k]) changed = true;
        grid[line[k]] = out[k];
      }
    }
    if (changed) {
      _undoGrid = before;
      _undoScore = beforeScore;
      moves++;
      _spawn();
      if (!canMove) gameOver(1500);
      notifyListeners();
    }
    return changed;
  }
}

final game2048Info = LocalGameInfo(
  id: 'game_2048',
  title: '2048',
  emoji: '🔢',
  color: const Color(0xFFEDC22E),
  tagline: 'Merge the tiles, reach 2048!',
  rules: const [
    'Swipe up, down, left or right to slide every tile.',
    'Two tiles with the same number merge into one: 2+2=4, 4+4=8…',
    'A new tile appears after every move. Keep going until no move is left!',
  ],
  scoreUnit: 'points',
  splitScreen: false,
  minPlayers: 1,
  maxPlayers: 1,
  play: (players, onFinished) => TickingPlay<Game2048Logic>(
    create: () => Game2048Logic(),
    onFinished: onFinished,
    builder: (context, g) => SoloFrame(
      title: '2048',
      score: g.score,
      extra: 'BEST TILE ${g.best}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanEnd: (d) {
          final dir = swipeDir(d.velocity.pixelsPerSecond);
          if (dir != null && g.move(dir))
            HapticFeedback.selectionClick().ignore();
        },
        child: Column(children: [
          Expanded(
              child: Center(
                  child: AspectRatio(aspectRatio: 1, child: _Board(g: g)))),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: Text(
                    g.over ? 'No moves left!' : 'Swipe to move the tiles',
                    style: TextStyle(
                        fontFamily: Fonts.display,
                        fontSize: 16,
                        color: g.over
                            ? const Color(0xFFFF8E8B)
                            : Colors.white60))),
            TextButton(onPressed: g.undo, child: const Text('UNDO')),
          ]),
        ]),
      ),
    ),
  ),
);

class _Board extends StatelessWidget {
  final Game2048Logic g;
  const _Board({required this.g});

  static Color tileColor(int v) => switch (v) {
        // Cream through orange to gold (spec 5.4 #43).
        0 => const Color(0x33000000),
        2 => const Color(0xFFFFF4DC),
        4 => const Color(0xFFFFE6B8),
        8 => const Color(0xFFFFC58A),
        16 => const Color(0xFFFFA866),
        32 => const Color(0xFFFF8A4C),
        64 => const Color(0xFFFF6B35),
        128 => const Color(0xFFFFD45C),
        256 => const Color(0xFFFFC93C),
        512 => const Color(0xFFFFBE21),
        1024 => const Color(0xFFF5B000),
        2048 => const Color(0xFFE8A400),
        _ => const Color(0xFF6B3FA0),
      };

  @override
  Widget build(BuildContext context) => Container(
        // A warm wooden tray; the empty slots are recessed (darker, inset).
        decoration:
            BoxDecoration(borderRadius: Radii.rBoard, boxShadow: Shadows.large),
        foregroundDecoration: BoxDecoration(
            borderRadius: Radii.rBoard,
            border: Border.all(color: const Color(0x55FFE0B2), width: 1.5)),
        child: CustomPaint(
          painter: const WoodPainter(radius: Radii.board),
          child: Padding(
              padding: const EdgeInsets.all(10),
              child: GridView.count(
                crossAxisCount: Game2048Logic.n,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (var i = 0; i < Game2048Logic.n * Game2048Logic.n; i++)
                    TweenAnimationBuilder<double>(
                      key: ValueKey(i == g.lastNew ? 'new${g.moves}' : 'c$i'),
                      tween: Tween(begin: i == g.lastNew ? 0.4 : 1, end: 1),
                      duration: const Duration(milliseconds: 160),
                      builder: (_, s, child) =>
                          Transform.scale(scale: s, child: child),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: tileColor(g.grid[i]),
                          borderRadius: BorderRadius.circular(10),
                          // Raised tiles: a darker bottom edge under every numbered tile.
                          boxShadow: g.grid[i] == 0
                              ? null
                              : [
                                  BoxShadow(
                                      color: Color.lerp(tileColor(g.grid[i]),
                                          Colors.black, 0.35)!,
                                      offset: const Offset(0, 3))
                                ],
                        ),
                        child: g.grid[i] == 0
                            ? null
                            : Padding(
                                padding: const EdgeInsets.all(6),
                                child: FittedBox(
                                  child: Text('${g.grid[i]}',
                                      style: TextStyle(
                                          fontFamily: Fonts.display,
                                          color: g.grid[i] <= 4
                                              ? const Color(0xFF6B4A2B)
                                              : Colors.white,
                                          fontSize: 30,
                                          shadows: g.grid[i] <= 4
                                              ? null
                                              : const [
                                                  Shadow(
                                                      color: Color(0x66000000),
                                                      offset: Offset(0, 2))
                                                ])),
                                ),
                              ),
                      ),
                    ),
                ],
              )),
        ),
      );
}
