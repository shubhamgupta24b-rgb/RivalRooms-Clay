import 'package:flutter/material.dart';
import '../../../core/audio/game_audio.dart';
import '../../../core/ui/components.dart';
import '../../guess_person/models/gp_player.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/game_hud.dart';
import '../shell/local_game_shell.dart' show ResultScope;
import '../shell/ticking_play.dart';

/// Classic Connect Four on a 7x6 board. Discs drop to the lowest free row; four in a
/// row (across, down or diagonal) wins. The starting player alternates every match.
class ConnectFourLogic extends LocalGameLogic {
  static const cols = 7, rows = 6;
  final List<int> cells = List.filled(cols * rows, -1); // row 0 is the top
  int turn;
  int? winner;
  List<int>? winCells;
  int? lastDrop;

  ConnectFourLogic({int starter = 0}) : turn = starter;

  int at(int c, int r) => cells[r * cols + c];
  bool get isDraw => winner == null && cells.every((x) => x >= 0);
  @override
  bool get finished => winner != null || isDraw;
  @override
  List<int> get scores => [for (var p = 0; p < 2; p++) winner == p ? 1 : 0];
  @override
  void update(int elapsedMs) {}

  /// Drops a disc in [col]. Returns the row it landed on, or null if not allowed.
  int? drop(int col) {
    if (forward('drop', [col])) return null;
    if (finished || col < 0 || col >= cols) return null;
    for (var r = rows - 1; r >= 0; r--) {
      if (at(col, r) < 0) {
        cells[r * cols + col] = turn;
        lastDrop = r * cols + col;
        _checkWin(col, r);
        if (!finished) turn = 1 - turn;
        notifyListeners();
        return r;
      }
    }
    return null; // column full
  }

  void _checkWin(int c, int r) {
    const dirs = [(1, 0), (0, 1), (1, 1), (1, -1)];
    for (final (dc, dr) in dirs) {
      final line = [r * cols + c];
      for (final sign in [1, -1]) {
        var x = c + dc * sign, y = r + dr * sign;
        while (x >= 0 && x < cols && y >= 0 && y < rows && at(x, y) == turn) {
          line.add(y * cols + x);
          x += dc * sign;
          y += dr * sign;
        }
      }
      if (line.length >= 4) {
        winner = turn;
        winCells = line;
        return;
      }
    }
  }
}

var _matchesStarted = 0;

final connectFourInfo = LocalGameInfo(
  id: 'connect_four',
  title: 'Connect Four',
  emoji: '🔴',
  color: const Color(0xFFE5484D),
  tagline: 'Line up four to win!',
  rules: const [
    'Take turns tapping a column to drop your disc.',
    'Get four of your discs in a row: across, down or diagonal.',
    'Full board with no line is a draw. The starting player switches every match.',
  ],
  scoreUnit: 'wins',
  splitScreen: false,
  bot: botFor<ConnectFourLogic>((g, b, now) {
    if (g.finished || g.turn != b.seat) return;
    if (!b.thinkFirst(g.cells.where((c) => c >= 0).length, now, 600, 1300))
      return;
    const cols = ConnectFourLogic.cols, rows = ConnectFourLogic.rows;
    int? landing(int c) {
      for (var r = rows - 1; r >= 0; r--) {
        if (g.at(c, r) < 0) return r;
      }
      return null;
    }

    bool wins(int c, int who) {
      final r = landing(c);
      if (r == null) return false;
      int at(int x, int y) => x == c && y == r ? who : g.at(x, y);
      for (final (dc, dr) in const [(1, 0), (0, 1), (1, 1), (1, -1)]) {
        var n = 1;
        for (final s in const [1, -1]) {
          var x = c + dc * s, y = r + dr * s;
          while (x >= 0 && x < cols && y >= 0 && y < rows && at(x, y) == who) {
            n++;
            x += dc * s;
            y += dr * s;
          }
        }
        if (n >= 4) return true;
      }
      return false;
    }

    final open = [
      for (var c = 0; c < cols; c++)
        if (landing(c) != null) c
    ];
    final opp = 1 - b.seat;
    // Win, else block, else favour the middle (with a little randomness).
    final int col = open.where((c) => wins(c, b.seat)).firstOrNull ??
        open.where((c) => wins(c, opp)).firstOrNull ??
        (b.chance(0.2)
            ? b.pick<int>(open)
            : (open.toList()
                  ..sort((a, c) => (a - 3).abs().compareTo((c - 3).abs())))
                .first);
    g.drop(col);
  }),
  online: RelaySpec<ConnectFourLogic>(
    create: (n) => ConnectFourLogic(),
    save: (g) => {
      'cells': g.cells,
      'turn': g.turn,
      'winner': g.winner,
      'winCells': g.winCells,
      'lastDrop': g.lastDrop
    },
    load: (g, s, me) {
      g.cells.setAll(0, ints(s['cells']));
      g.turn = asInt(s['turn']);
      g.winner = nInt(s['winner']);
      g.winCells = s['winCells'] == null ? null : ints(s['winCells']);
      g.lastDrop = nInt(s['lastDrop']);
    },
    apply: (g, from, name, a) {
      if (name == 'drop' && from == g.turn) g.drop(asInt(a[0]));
    },
    view: (context, g, players, me) => _Board(players: players, g: g),
  ),
  play: (players, onFinished) => TickingPlay<ConnectFourLogic>(
    create: () => ConnectFourLogic(starter: _matchesStarted++ % 2),
    onFinished: onFinished,
    builder: (context, g) => _Board(players: players, g: g),
  ),
);

// Board palette: the classic blue plastic frame.
const _frame = [Color(0xFF3B6FF0), Color(0xFF2149C2)];
const _hole = Color(0xFF0D1340);

class _Board extends StatefulWidget {
  final List<GpPlayer> players;
  final ConnectFourLogic g;
  const _Board({required this.players, required this.g});
  @override
  State<_Board> createState() => _BoardState();
}

class _BoardState extends State<_Board> {
  int _bumps = 0;
  int _lockedUntil = 0;

  /// The row a disc dropped in column [c] would land on, or null if the column is full.
  int? _landing(int c) {
    for (var r = ConnectFourLogic.rows - 1; r >= 0; r--) {
      if (widget.g.at(c, r) < 0) return r;
    }
    return null;
  }

  void _drop(int c) {
    final g = widget.g;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (g.finished || now < _lockedUntil) return;
    _lockedUntil = now + 160;
    if (_landing(c) == null) {
      haptic(HapticWeight.heavy);
      setState(() => _bumps++);
      return;
    }
    if (g.drop(c) != null) {
      haptic(HapticWeight.light);
      GameAudio.sfx('tap');
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g, players = widget.players;
    final current = players[g.turn];
    ResultScope.of(context)?.subtitle = g.winner != null
        ? 'Four in a row'
        : (g.isDraw ? 'The board is full' : null);
    return MomentWatcher<bool>(
      value: g.finished,
      onChange: (fx, _, done) {
        if (!done) return;
        if (g.winner != null) {
          keyMoment(fx, 'FOUR IN A ROW!',
              sub: '${players[g.winner!].name} wins',
              sound: 'win',
              confetti: true);
        } else {
          keyMoment(fx, 'DRAW!', sub: 'The board is full', color: Colors.white);
        }
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.s, Space.xs, Space.s, Space.l),
        child: Column(children: [
          ScoreHud(
            title: 'Connect Four',
            state: g.winner != null
                ? '${players[g.winner!].name} wins'
                : (g.isDraw ? 'Draw' : '${possessive(current.name)} turn'),
            players: players,
            turn: g.finished ? null : g.turn,
            tag: (i) => !g.finished && i == g.turn
                ? 'YOUR TURN'
                : (g.winner == i ? 'WINNER' : null),
          ),
          const SizedBox(height: Space.m),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio:
                    ConnectFourLogic.cols / (ConnectFourLogic.rows + 1.4),
                child: Shake(
                  trigger: _bumps == 0 ? null : _bumps,
                  child: Column(children: [
                    Expanded(
                      child: Stack(clipBehavior: Clip.none, children: [
                        // Feet.
                        Positioned(left: 4, bottom: -2, child: _Foot()),
                        Positioned(right: 4, bottom: -2, child: _Foot()),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Container(
                            padding: const EdgeInsets.all(Space.s),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                  colors: _frame,
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter),
                              borderRadius: Radii.rXl,
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  width: 2),
                              boxShadow: const [
                                BoxShadow(
                                    color: Colors.black54,
                                    offset: Offset(0, 8),
                                    blurRadius: 6)
                              ],
                            ),
                            child: Stack(children: [
                              RepaintBoundary(
                                child: Row(children: [
                                  for (var c = 0;
                                      c < ConnectFourLogic.cols;
                                      c++)
                                    Expanded(
                                      child: Semantics(
                                        button:
                                            _landing(c) != null && !g.finished,
                                        label:
                                            'Column ${c + 1}${_landing(c) == null ? ', full' : ''}',
                                        excludeSemantics: true,
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () => _drop(c),
                                          child: Column(children: [
                                            for (var r = 0;
                                                r < ConnectFourLogic.rows;
                                                r++)
                                              Expanded(
                                                child: _Hole(
                                                  owner: g.at(c, r),
                                                  players: players,
                                                  row: r,
                                                  win: g.winCells?.contains(r *
                                                              ConnectFourLogic
                                                                  .cols +
                                                          c) ??
                                                      false,
                                                  fresh: g.lastDrop ==
                                                      r *
                                                              ConnectFourLogic
                                                                  .cols +
                                                          c,
                                                  ghost: !g.finished &&
                                                          _landing(c) == r
                                                      ? current.color
                                                      : null,
                                                ),
                                              ),
                                          ]),
                                        ),
                                      ),
                                    ),
                                ]),
                              ),
                              if (g.winCells != null)
                                Positioned.fill(
                                    child: IgnorePointer(
                                        child: _WinLine(g.winCells!))),
                            ]),
                          ),
                        ),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// A gold line through the winning four, drawn in over a moment.
class _WinLine extends StatelessWidget {
  final List<int> cells;
  const _WinLine(this.cells);
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: Motion.reduced(context) ? 1 : 0, end: 1),
        duration: const Duration(milliseconds: 500),
        curve: Motion.standard,
        builder: (_, t, __) => CustomPaint(painter: _WinLinePainter(cells, t)),
      );
}

class _WinLinePainter extends CustomPainter {
  final List<int> cells;
  final double t;
  _WinLinePainter(this.cells, this.t);
  @override
  void paint(Canvas canvas, Size size) {
    const cols = ConnectFourLogic.cols, rows = ConnectFourLogic.rows;
    Offset at(int i) => Offset((i % cols + 0.5) * size.width / cols,
        (i ~/ cols + 0.5) * size.height / rows);
    final pts = cells.map(at).toList()
      ..sort(
          (a, b) => a.dx != b.dx ? a.dx.compareTo(b.dx) : a.dy.compareTo(b.dy));
    final a = pts.first, b = Offset.lerp(pts.first, pts.last, t)!;
    canvas.drawLine(
        a,
        b,
        Paint()
          ..color = const Color(0x99000000)
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round);
    canvas.drawLine(
        a,
        b,
        Paint()
          ..color = Brand.gold
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_WinLinePainter o) => o.t != t || o.cells != cells;
}

class _Foot extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 46,
        height: 18,
        decoration: BoxDecoration(
            color: _frame.last,
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(8)),
            boxShadow: const [
              BoxShadow(color: Colors.black45, offset: Offset(0, 3))
            ]),
      );
}

class _Hole extends StatelessWidget {
  final int owner;
  final List<GpPlayer> players;
  final int row;
  final bool win;
  final bool fresh;
  final Color? ghost; // where the current player's disc would land
  const _Hole(
      {required this.owner,
      required this.players,
      required this.row,
      required this.win,
      required this.fresh,
      this.ghost});

  @override
  Widget build(BuildContext context) {
    final c = owner < 0 ? null : players[owner].color;
    final seat = c == null ? null : PlayerPalette.indexOf(c);
    final disc = Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c == null ? (ghost?.withValues(alpha: 0.25) ?? _hole) : null,
        // Discs get a shine so they look like plastic counters.
        gradient: c == null
            ? null
            : RadialGradient(center: const Alignment(-0.3, -0.35), colors: [
                Color.lerp(c, Colors.white, 0.45)!,
                c,
                Color.lerp(c, Colors.black, 0.3)!
              ]),
        border: win
            ? Border.all(color: Brand.gold, width: 4)
            : (ghost != null && c == null
                ? Border.all(color: ghost!.withValues(alpha: 0.8), width: 2)
                : null),
        boxShadow: c == null
            ? const [
                BoxShadow(
                    color: Colors.black87,
                    offset: Offset(0, -2),
                    blurRadius: 3,
                    spreadRadius: -1)
              ]
            : const [BoxShadow(color: Colors.black38, offset: Offset(0, 2))],
      ),
      // The player's shape pressed into the disc: colour is never the only clue.
      child: seat == null
          ? null
          : FractionallySizedBox(
              widthFactor: 0.38,
              heightFactor: 0.38,
              child: CustomPaint(
                  painter: PlayerShapePainter(PlayerPalette.shape(seat),
                      Colors.white.withValues(alpha: 0.45))),
            ),
    );
    return Padding(
      padding: const EdgeInsets.all(3),
      child: AspectRatio(
        aspectRatio: 1,
        child: fresh && !Motion.reduced(context)
            ? TweenAnimationBuilder<double>(
                key: ValueKey(owner),
                // Falls from above the board down to its row.
                tween: Tween(begin: -(row + 1.0) * 1.1, end: 0),
                duration: Duration(milliseconds: 180 + 45 * row),
                curve: Curves.bounceOut,
                builder: (_, y, child) => FractionalTranslation(
                    translation: Offset(0, y), child: child),
                child: disc,
              )
            : disc,
      ),
    );
  }
}
