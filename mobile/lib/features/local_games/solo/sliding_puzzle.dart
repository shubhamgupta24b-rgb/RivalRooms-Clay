import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/ui/components.dart';
import 'package:flutter/services.dart';
import '../shell/local_game_info.dart';
import '../shell/ticking_play.dart';
import 'solo_common.dart';

/// Sliding Puzzle: put the tiles 1..15 in order by sliding them into the gap. Solve 3x3,
/// then 4x4. Fewer moves = more points.
class SlidingLogic extends SoloLogic {
  final Random rng;
  int size = 3;
  late List<int> tiles; // 0 = the gap
  int moves = 0, totalMoves = 0;
  int? solvedAt;

  SlidingLogic({Random? random}) : rng = random ?? Random() {
    _shuffle();
  }

  bool get solved =>
      [for (var i = 0; i < tiles.length - 1; i++) tiles[i] == i + 1]
          .every((x) => x) &&
      tiles.last == 0;

  /// Shuffles by making random legal moves from the solved board, so it's always solvable.
  void _shuffle() {
    tiles = [for (var i = 1; i < size * size; i++) i, 0];
    var gap = tiles.length - 1, prev = -1;
    for (var i = 0; i < size * size * 40 || solved; i++) {
      final options = _neighbours(gap).where((n) => n != prev).toList();
      final n = options[rng.nextInt(options.length)];
      tiles[gap] = tiles[n];
      tiles[n] = 0;
      prev = gap;
      gap = n;
    }
    moves = 0;
  }

  List<int> _neighbours(int i) {
    final r = i ~/ size, c = i % size;
    return [
      if (r > 0) i - size,
      if (r < size - 1) i + size,
      if (c > 0) i - 1,
      if (c < size - 1) i + 1
    ];
  }

  /// Slides the tile at [i] into the gap if it's next to it.
  void tap(int i) {
    if (over || solvedAt != null) return;
    final gap = tiles.indexOf(0);
    if (!_neighbours(gap).contains(i)) return;
    tiles[gap] = tiles[i];
    tiles[i] = 0;
    moves++;
    totalMoves++;
    HapticFeedback.selectionClick().ignore();
    if (solved) {
      score += max(50, (size == 3 ? 400 : 1200) - moves * (size == 3 ? 4 : 3));
      solvedAt = now;
    }
    notifyListeners();
  }

  @override
  void step(int now) {
    final at = solvedAt;
    if (at == null || now - at < 1400) return;
    solvedAt = null;
    if (size == 3) {
      size = 4;
      _shuffle();
      notifyListeners();
    } else {
      gameOver(200);
    }
  }
}

final slidingInfo = LocalGameInfo(
  id: 'sliding_puzzle',
  title: 'Sliding Puzzle',
  emoji: '🔢',
  color: const Color(0xFF5C6BC0),
  tagline: 'Slide the tiles back in order!',
  rules: const [
    'Tap a tile next to the gap to slide it.',
    'Put the numbers in order, gap at the end. First 3×3, then 4×4.',
    'Fewer moves score more points.',
  ],
  scoreUnit: 'points',
  splitScreen: false,
  minPlayers: 1,
  maxPlayers: 1,
  play: (players, onFinished) => TickingPlay<SlidingLogic>(
    create: () => SlidingLogic(),
    onFinished: onFinished,
    builder: (context, g) => SoloFrame(
      title: g.solvedAt != null ? 'Solved!' : '${g.size}×${g.size} puzzle',
      score: g.score,
      extra: '${g.moves} moves',
      child: Center(
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            padding: const EdgeInsets.all(8),
            // A dark wooden frame around the tiles.
            decoration: BoxDecoration(
                color: const Color(0xFF4A2C14),
                borderRadius: Radii.rBoard,
                border: Border.all(color: const Color(0xFF7A4A22), width: 4),
                boxShadow: Shadows.large),
            child: LayoutBuilder(builder: (context, c) {
              final cell = c.maxWidth / g.size;
              return Stack(children: [
                for (var i = 0; i < g.tiles.length; i++)
                  if (g.tiles[i] != 0)
                    AnimatedPositioned(
                      key: ValueKey('t${g.size}-${g.tiles[i]}'),
                      duration: const Duration(milliseconds: 120),
                      curve: Curves.easeOut,
                      left: (i % g.size) * cell,
                      top: (i ~/ g.size) * cell,
                      width: cell,
                      height: cell,
                      child: GestureDetector(
                        onTap: () => g.tap(i),
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            // Light wooden blocks with a bevel; tiles in their home spot get a green edge.
                            gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFFF3D19C),
                                  Color(0xFFD9A863),
                                  Color(0xFFC08A48)
                                ]),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: g.tiles[i] == i + 1
                                    ? StatusColors.success
                                    : const Color(0x66FFF3D6),
                                width: g.tiles[i] == i + 1 ? 3 : 1.5),
                            boxShadow: const [
                              BoxShadow(
                                  color: Color(0xFF3A200C),
                                  offset: Offset(0, 4))
                            ],
                          ),
                          child: Text('${g.tiles[i]}',
                              style: TextStyle(
                                  fontFamily: Fonts.display,
                                  color: const Color(0xFF4A2C14),
                                  fontSize: cell * 0.42)),
                        ),
                      ),
                    ),
              ]);
            }),
          ),
        ),
      ),
    ),
  ),
);
