import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/records/level_progress.dart';
import '../../../core/ui/components.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_shell.dart' show PauseButton;

const candyColors = [
  Color(0xFFFF4D6D),
  Color(0xFF3A86FF),
  Color(0xFFFFBE0B),
  Color(0xFF2EC4B6),
  Color(0xFF9B5DE5),
  Color(0xFFFF8C42)
];

class CandySpec {
  final int size, colors, moves, target;
  const CandySpec(this.size, this.colors, this.moves, this.target);
  static const levels = [
    CandySpec(6, 4, 18, 400),
    CandySpec(7, 5, 20, 800),
    CandySpec(8, 6, 22, 1200),
  ];
}

/// Match-3. A swap that makes no line snaps back. Four in a row clears that whole line.
class CandyLogic {
  final int level;
  final CandySpec spec;
  final Random rng;
  late List<int> grid;
  int score = 0;
  int moves;
  int? selected;
  bool won = false;
  bool lost = false;
  CandyLogic({this.level = 1, Random? random})
      : spec =
            CandySpec.levels[(level - 1).clamp(0, CandySpec.levels.length - 1)],
        rng = random ?? Random(),
        moves = 0 {
    moves = spec.moves;
    grid = List.filled(spec.size * spec.size, 0);
    _fill();
  }

  int at(int r, int c) => grid[r * spec.size + c];

  void _fill() {
    for (var i = 0; i < grid.length; i++) {
      grid[i] = rng.nextInt(spec.colors);
    }
    // Break any line that the deal happened to make, so the board is not already clearing.
    var guard = 0;
    while (_lines().isNotEmpty && guard++ < 40) {
      for (final i in _lines()) {
        grid[i] = rng.nextInt(spec.colors);
      }
    }
  }

  Set<int> _lines() {
    final n = spec.size;
    final hit = <int>{};
    for (var r = 0; r < n; r++) {
      var run = 1;
      for (var c = 1; c <= n; c++) {
        if (c < n && at(r, c) == at(r, c - 1)) {
          run++;
        } else {
          if (run >= 3) {
            for (var k = 0; k < run; k++) {
              hit.add(r * n + (c - 1 - k));
            }
          }
          run = 1;
        }
      }
    }
    for (var c = 0; c < n; c++) {
      var run = 1;
      for (var r = 1; r <= n; r++) {
        if (r < n && at(r, c) == at(r - 1, c)) {
          run++;
        } else {
          if (run >= 3) {
            for (var k = 0; k < run; k++) {
              hit.add((r - 1 - k) * n + c);
            }
          }
          run = 1;
        }
      }
    }
    return hit;
  }

  bool _adjacent(int a, int b) {
    final n = spec.size;
    final dr = (a ~/ n - b ~/ n).abs(), dc = (a % n - b % n).abs();
    return dr + dc == 1;
  }

  /// Returns true if the swap was a real match.
  bool swap(int a, int b) {
    if (won || lost || !_adjacent(a, b)) return false;
    final n = spec.size;
    void exchange() {
      final t = grid[a];
      grid[a] = grid[b];
      grid[b] = t;
    }

    exchange();
    if (_lines().isEmpty) {
      exchange();
      return false;
    }
    moves--;
    var chain = 1;
    while (true) {
      final hit = _lines();
      if (hit.isEmpty) break;
      final rows = <int>{}, cols = <int>{};
      for (final i in hit) {
        rows.add(i ~/ n);
        cols.add(i % n);
      }
      // Four or more in one line also clears that whole row or column.
      if (hit.length >= 4) {
        if (rows.length == 1) {
          for (var c = 0; c < n; c++) {
            hit.add(rows.first * n + c);
          }
        } else if (cols.length == 1) {
          for (var r = 0; r < n; r++) {
            hit.add(r * n + cols.first);
          }
        }
      }
      score += hit.length * 10 * chain;
      chain++;
      for (final i in hit) {
        grid[i] = -1;
      }
      for (var c = 0; c < n; c++) {
        var write = n - 1;
        for (var r = n - 1; r >= 0; r--) {
          final v = at(r, c);
          if (v >= 0) {
            grid[write * n + c] = v;
            if (write != r) grid[r * n + c] = -1;
            write--;
          }
        }
        for (var r = write; r >= 0; r--) {
          grid[r * n + c] = rng.nextInt(spec.colors);
        }
      }
    }
    if (score >= spec.target) {
      won = true;
      LevelProgress.unlock(
          'candy_crush', min(CandySpec.levels.length, level + 1));
    } else if (moves <= 0) {
      lost = true;
    }
    return true;
  }
}

final candyCrushInfo = LocalGameInfo(
  id: 'candy_crush',
  title: 'Candy Crush',
  emoji: '🍬',
  color: const Color(0xFFFF6B8A),
  tagline: 'Swap the sweets, clear the lines!',
  rules: const [
    'Swap two neighbouring sweets. Three or more in a line clear.',
    'Four or more also clears that whole row or column. Cascades score extra.',
    'Hit the score before you run out of moves. Three levels, and the next stays locked until you win.',
  ],
  scoreUnit: 'points',
  splitScreen: false,
  minPlayers: 1,
  maxPlayers: 1,
  play: (players, onFinished) => _CandyScreen(onFinished: onFinished),
);

class _CandyScreen extends StatefulWidget {
  final void Function(List<int>) onFinished;
  const _CandyScreen({required this.onFinished});
  @override
  State<_CandyScreen> createState() => _CandyScreenState();
}

class _CandyScreenState extends State<_CandyScreen> {
  int unlocked = 1;
  int? level;
  CandyLogic? game;
  @override
  void initState() {
    super.initState();
    LevelProgress.unlocked('candy_crush').then((n) {
      if (mounted)
        setState(() => unlocked = n.clamp(1, CandySpec.levels.length));
    });
  }

  void _start(int lv) {
    setState(() {
      level = lv;
      game = CandyLogic(level: lv);
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = game;
    if (g == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Align(alignment: Alignment.centerLeft, child: PauseButton()),
          const SizedBox(height: 12),
          for (var i = 1; i <= CandySpec.levels.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GoldButton(i <= unlocked ? 'Level $i' : 'Level $i locked',
                  height: 56,
                  onPressed: i <= unlocked ? () => _start(i) : null),
            ),
        ]),
      );
    }
    final n = g.spec.size;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        Row(children: [
          const PauseButton(),
          const SizedBox(width: 8),
          Expanded(
              child: Text('Level ${g.level}   ${g.score}/${g.spec.target}',
                  style: const TextStyle(
                      fontFamily: Fonts.display,
                      color: Colors.white,
                      fontSize: 18))),
          Text('${g.moves} moves',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 8),
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            final cell = min(c.maxWidth, c.maxHeight) / n;
            return Center(
              child: GestureDetector(
                onPanEnd: (d) {
                  final s = g.selected;
                  if (s == null) return;
                  final v = d.velocity.pixelsPerSecond;
                  int dir;
                  if (v.dx.abs() > v.dy.abs()) {
                    dir = v.dx > 0 ? 1 : -1;
                    final col = s % n + dir;
                    if (col < 0 || col >= n) return;
                    g.swap(s, s + dir);
                  } else {
                    dir = v.dy > 0 ? 1 : -1;
                    final row = s ~/ n + dir;
                    if (row < 0 || row >= n) return;
                    g.swap(s, s + dir * n);
                  }
                  setState(() {});
                },
                child: SizedBox(
                  width: cell * n,
                  height: cell * n,
                  child: GridView.count(
                    crossAxisCount: n,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      for (var i = 0; i < n * n; i++)
                        GestureDetector(
                          onTap: () => setState(() => g.selected = i),
                          child: Container(
                            margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color:
                                  candyColors[g.grid[i] % candyColors.length],
                              borderRadius: BorderRadius.circular(8),
                              border: g.selected == i
                                  ? Border.all(color: Colors.white, width: 3)
                                  : null,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
        if (g.won || g.lost)
          Row(children: [
            Expanded(
                child: KitButton('Levels',
                    style: KitButtonStyle.soft,
                    onPressed: () => setState(() => game = null))),
            const SizedBox(width: 8),
            Expanded(
                child: KitButton(g.won ? 'Next' : 'Retry',
                    style: KitButtonStyle.soft, onPressed: () {
              if (g.won && g.level < CandySpec.levels.length) {
                _start(g.level + 1);
              } else {
                _start(g.level);
              }
            })),
          ])
        else
          GoldButton('Exit',
              height: 48, onPressed: () => widget.onFinished([g.score])),
      ]),
    );
  }
}
