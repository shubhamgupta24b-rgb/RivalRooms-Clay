import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/ui/components.dart';
import 'package:flutter/services.dart';
import '../shell/local_game_info.dart';
import '../shell/ticking_play.dart';
import 'solo_common.dart';

/// Makes a full valid 9x9 grid (random), then removes cells while the puzzle still has
/// exactly one solution.
class SudokuMaker {
  final Random rng;
  SudokuMaker(this.rng);

  static bool _ok(List<int> g, int i, int v) {
    final r = i ~/ 9, c = i % 9;
    for (var k = 0; k < 9; k++) {
      if (g[r * 9 + k] == v || g[k * 9 + c] == v) return false;
    }
    final br = r ~/ 3 * 3, bc = c ~/ 3 * 3;
    for (var dr = 0; dr < 3; dr++) {
      for (var dc = 0; dc < 3; dc++) {
        if (g[(br + dr) * 9 + bc + dc] == v) return false;
      }
    }
    return true;
  }

  bool _fill(List<int> g) {
    final i = g.indexOf(0);
    if (i < 0) return true;
    for (final v in [for (var v = 1; v <= 9; v++) v]..shuffle(rng)) {
      if (_ok(g, i, v)) {
        g[i] = v;
        if (_fill(g)) return true;
        g[i] = 0;
      }
    }
    return false;
  }

  /// Number of solutions, stopping at [limit].
  static int count(List<int> g, [int limit = 2]) {
    final i = g.indexOf(0);
    if (i < 0) return 1;
    var n = 0;
    for (var v = 1; v <= 9 && n < limit; v++) {
      if (_ok(g, i, v)) {
        g[i] = v;
        n += count(g, limit - n);
        g[i] = 0;
      }
    }
    return n;
  }

  /// (puzzle with 0 for blanks, solution).
  (List<int>, List<int>) make({int blanks = 42}) {
    final solution = List.filled(81, 0);
    _fill(solution);
    final puzzle = List.of(solution);
    var removed = 0;
    for (final i in [for (var i = 0; i < 81; i++) i]..shuffle(rng)) {
      if (removed >= blanks) break;
      final keep = puzzle[i];
      puzzle[i] = 0;
      if (count(List.of(puzzle)) != 1) {
        puzzle[i] = keep;
      } else {
        removed++;
      }
    }
    return (puzzle, solution);
  }
}

/// Sudoku: fill the grid so every row, column and 3x3 box has 1-9. Three mistakes and it's
/// over. Faster solves score more.
class SudokuLogic extends SoloLogic {
  static const maxMistakes = 3;
  late final List<int> puzzle, solution, cells;
  int? selected;
  int mistakes = 0;
  int? wrongAt, wrongCell;
  bool notes = false;
  final List<Set<int>> marks = List.generate(81, (_) => <int>{});

  SudokuLogic({Random? random, int blanks = 42}) {
    final (p, s) = SudokuMaker(random ?? Random()).make(blanks: blanks);
    puzzle = p;
    solution = s;
    cells = List.of(p);
  }

  bool get solved =>
      [for (var i = 0; i < 81; i++) cells[i] == solution[i]].every((x) => x);
  int remaining(int v) => 9 - cells.where((x) => x == v).length;

  void select(int i) {
    if (over) return;
    selected = i;
    notifyListeners();
  }

  void toggleNotes() {
    notes = !notes;
    notifyListeners();
  }

  void enter(int v) {
    final i = selected;
    if (over || i == null || puzzle[i] != 0 || cells[i] == solution[i]) return;
    if (notes) {
      if (!marks[i].remove(v)) marks[i].add(v);
      notifyListeners();
      return;
    }
    if (solution[i] == v) {
      cells[i] = v;
      marks[i].clear();
      HapticFeedback.selectionClick().ignore();
      if (solved) {
        score = max(100, 2000 - now ~/ 1000 * 3 - mistakes * 200);
        gameOver(1500);
      }
    } else {
      mistakes++;
      wrongAt = now;
      wrongCell = i;
      HapticFeedback.heavyImpact().ignore();
      if (mistakes >= maxMistakes) gameOver(1500);
    }
    notifyListeners();
  }
}

final sudokuInfo = LocalGameInfo(
  id: 'sudoku',
  title: 'Sudoku',
  emoji: '📝',
  color: const Color(0xFF3949AB),
  tagline: 'The classic number puzzle!',
  rules: const [
    'Fill the grid so every row, column and 3×3 box has the numbers 1 to 9 once.',
    'Tap a square, then a number. Notes (the pencil) lets you pencil in ideas.',
    '3 mistakes and the game is over. Solve it fast for more points!',
  ],
  scoreUnit: 'points',
  splitScreen: false,
  minPlayers: 1,
  maxPlayers: 1,
  play: (players, onFinished) => TickingPlay<SudokuLogic>(
    create: () => SudokuLogic(),
    onFinished: onFinished,
    builder: (context, g) => SoloFrame(
      title: g.over && g.solved ? 'Solved!' : 'Sudoku',
      score: g.score,
      extra:
          '${g.now ~/ 60000}:${(g.now ~/ 1000 % 60).toString().padLeft(2, '0')}',
      lives: SudokuLogic.maxMistakes - g.mistakes,
      maxLives: SudokuLogic.maxMistakes,
      child: Column(children: [
        Expanded(
            child:
                Center(child: AspectRatio(aspectRatio: 1, child: _Grid(g: g)))),
        const SizedBox(height: 10),
        // Number pad in two rows (keys stay at least 48dp on small phones); NOTES is the last key.
        for (final row in const [
          [1, 2, 3, 4, 5],
          [6, 7, 8, 9, 0],
        ]) ...[
          Row(children: [
            for (final v in row)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: v == 0
                      ? Semantics(
                          button: true,
                          toggled: g.notes,
                          label: 'Notes',
                          excludeSemantics: true,
                          child: Material(
                            color: g.notes ? Brand.gold : Colors.white,
                            borderRadius: Radii.rMd,
                            child: InkWell(
                              borderRadius: Radii.rMd,
                              onTap: () {
                                haptic(HapticWeight.selection);
                                g.toggleNotes();
                              },
                              child: SizedBox(
                                height: 52,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const GameIcon(GameIcons.pencil,
                                            size: 20, color: Brand.ink),
                                        Text(g.notes ? 'NOTES ON' : 'NOTES',
                                            style: const TextStyle(
                                                fontFamily: Fonts.body,
                                                color: Brand.ink,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 10.5)),
                                      ]),
                                ),
                              ),
                            ),
                          ),
                        )
                      : Semantics(
                          button: g.remaining(v) > 0,
                          label: '$v, ${g.remaining(v)} left',
                          excludeSemantics: true,
                          child: Material(
                            color: g.remaining(v) == 0 ? Colors.white10 : _key,
                            borderRadius: Radii.rMd,
                            elevation: g.remaining(v) == 0 ? 0 : 2,
                            child: InkWell(
                              borderRadius: Radii.rMd,
                              onTap: g.remaining(v) == 0
                                  ? null
                                  : () {
                                      haptic(HapticWeight.selection);
                                      g.enter(v);
                                    },
                              child: SizedBox(
                                height: 52,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('$v',
                                            style: TextStyle(
                                                color: g.remaining(v) == 0
                                                    ? Colors.white24
                                                    : Colors.white,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 22)),
                                        Text('${g.remaining(v)}',
                                            style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700)),
                                      ]),
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
          ]),
        ],
      ]),
    ),
  ),
);

const _key = Color(0xFF3949AB); // number pad keys

class _Grid extends StatelessWidget {
  final SudokuLogic g;
  const _Grid({required this.g});

  @override
  Widget build(BuildContext context) {
    final sel = g.selected;
    final selVal = sel == null ? 0 : g.cells[sel];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: const Color(0xFF1A237E),
          borderRadius: BorderRadius.circular(12)),
      child: LayoutBuilder(builder: (context, c) {
        final cell = c.maxWidth / 9;
        return Stack(children: [
          for (var i = 0; i < 81; i++)
            Positioned(
              left: (i % 9) * cell,
              top: (i ~/ 9) * cell,
              width: cell,
              height: cell,
              child: GestureDetector(
                onTap: () => g.select(i),
                child: Builder(builder: (context) {
                  final r = i ~/ 9, col = i % 9;
                  final related = sel != null &&
                      (sel ~/ 9 == r ||
                          sel % 9 == col ||
                          (sel ~/ 27 == i ~/ 27 && sel % 9 ~/ 3 == col ~/ 3));
                  final same = selVal != 0 && g.cells[i] == selVal;
                  final wrong = g.wrongCell == i &&
                      g.wrongAt != null &&
                      g.now - g.wrongAt! < 700;
                  final bg = i == sel
                      ? const Color(0xFFFFE082)
                      : wrong
                          ? const Color(0xFFFFCDD2)
                          : same
                              ? const Color(0xFFC5CAE9)
                              : related
                                  ? const Color(0xFFE8EAF6)
                                  : Colors.white;
                  return Container(
                    margin: EdgeInsets.only(
                      right: col % 3 == 2 && col < 8 ? 2.5 : 0.5,
                      bottom: r % 3 == 2 && r < 8 ? 2.5 : 0.5,
                    ),
                    color: bg,
                    alignment: Alignment.center,
                    child: g.cells[i] != 0
                        ? Text('${g.cells[i]}',
                            style: TextStyle(
                                fontSize: cell * 0.55,
                                fontWeight: g.puzzle[i] != 0
                                    ? FontWeight.w900
                                    : FontWeight.w700,
                                color: g.puzzle[i] != 0
                                    ? const Color(0xFF1E1B3A)
                                    : const Color(0xFF3949AB)))
                        : g.marks[i].isEmpty
                            ? null
                            : Padding(
                                padding: const EdgeInsets.all(1),
                                child: GridView.count(
                                  crossAxisCount: 3,
                                  physics: const NeverScrollableScrollPhysics(),
                                  children: [
                                    for (var v = 1; v <= 9; v++)
                                      Center(
                                          child: Text(
                                              g.marks[i].contains(v)
                                                  ? '$v'
                                                  : '',
                                              style: TextStyle(
                                                  fontSize: cell * 0.2,
                                                  color: Colors.black54,
                                                  fontWeight:
                                                      FontWeight.w700))),
                                  ],
                                ),
                              ),
                  );
                }),
              ),
            ),
        ]);
      }),
    );
  }
}
