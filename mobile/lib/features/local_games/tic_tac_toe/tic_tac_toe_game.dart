import 'package:flutter/material.dart';
import '../../../core/audio/game_audio.dart';
import '../../../core/ui/components.dart';
import '../../guess_person/models/gp_player.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/game_hud.dart';
import '../shell/local_game_shell.dart' show ResultScope;
import '../shell/ticking_play.dart';

/// Classic noughts and crosses. Player 1 is X, player 2 is O; whoever starts
/// alternates every match. The winner scores 1, a full board is a draw (0-0).
class TicTacToeLogic extends LocalGameLogic {
  static const lines = [
    [0, 1, 2], [3, 4, 5], [6, 7, 8], // rows
    [0, 3, 6], [1, 4, 7], [2, 5, 8], // columns
    [0, 4, 8], [2, 4, 6], // diagonals
  ];

  final List<int> cells = List.filled(9, -1); // -1 empty, else player index
  int turn;
  List<int>? winLine;
  int? winner;

  TicTacToeLogic({int starter = 0}) : turn = starter;

  bool get isDraw => winner == null && cells.every((c) => c >= 0);
  @override
  bool get finished => winner != null || isDraw;
  @override
  List<int> get scores => [for (var p = 0; p < 2; p++) winner == p ? 1 : 0];

  @override
  void update(int elapsedMs) {} // turn-based: nothing happens on its own

  /// Returns true if the move was accepted.
  bool play(int cell) {
    if (forward('play', [cell])) return false;
    if (finished || cell < 0 || cell > 8 || cells[cell] >= 0) return false;
    cells[cell] = turn;
    for (final l in lines) {
      if (cells[l[0]] == turn && cells[l[1]] == turn && cells[l[2]] == turn) {
        winLine = l;
        winner = turn;
      }
    }
    if (!finished) turn = 1 - turn;
    notifyListeners();
    return true;
  }
}

var _matchesStarted = 0;

final ticTacToeInfo = LocalGameInfo(
  id: 'tic_tac_toe',
  title: 'Tic-Tac-Toe',
  emoji: '❌',
  color: const Color(0xFF00B8D9),
  tagline: 'Three in a row wins!',
  rules: const [
    'Player 1 is X, Player 2 is O. Take turns tapping an empty square.',
    'Get three of your marks in a row (across, down or diagonal) to win.',
    'A full board with no line is a draw. The starting player switches every match.',
  ],
  scoreUnit: 'wins',
  splitScreen: false,
  bot: botFor<TicTacToeLogic>((g, b, now) {
    if (g.finished || g.turn != b.seat) return;
    final empty = [
      for (var i = 0; i < 9; i++)
        if (g.cells[i] < 0) i
    ];
    if (!b.thinkFirst(empty.length, now, 500, 1100)) return;
    int? finishing(int who) {
      for (final l in TicTacToeLogic.lines) {
        final mine = l.where((c) => g.cells[c] == who).length;
        final free = l.where((c) => g.cells[c] < 0).toList();
        if (mine == 2 && free.length == 1) return free.single;
      }
      return null;
    }

    // Win, else block, else centre, else a corner, else anything. Sometimes it slips up.
    final int move = b.chance(0.12)
        ? b.pick(empty)
        : finishing(b.seat) ??
            finishing(1 - b.seat) ??
            (g.cells[4] < 0 ? 4 : null) ??
            [0, 2, 6, 8].where(empty.contains).firstOrNull ??
            b.pick<int>(empty);
    g.play(move);
  }),
  online: RelaySpec<TicTacToeLogic>(
    create: (n) => TicTacToeLogic(),
    save: (g) => {
      'cells': g.cells,
      'turn': g.turn,
      'winLine': g.winLine,
      'winner': g.winner
    },
    load: (g, s, me) {
      g.cells.setAll(0, ints(s['cells']));
      g.turn = asInt(s['turn']);
      g.winLine = s['winLine'] == null ? null : ints(s['winLine']);
      g.winner = nInt(s['winner']);
    },
    apply: (g, from, name, a) {
      if (name == 'play' && from == g.turn) g.play(asInt(a[0]));
    },
    view: (context, g, players, me) => _Board(players: players, g: g),
  ),
  play: (players, onFinished) => TickingPlay<TicTacToeLogic>(
    create: () => TicTacToeLogic(starter: _matchesStarted++ % 2),
    onFinished: onFinished,
    builder: (context, g) => _Board(players: players, g: g),
  ),
);

// Board palette: a chalkboard in a wooden frame.
const _wood = [Color(0xFFA06A35), Color(0xFF6B4220)];
const _slate = [Color(0xFF2B4A40), Color(0xFF1C3129)];
const _chalk = Color(0xFFF2F0E6);

class _Board extends StatefulWidget {
  final List<GpPlayer> players;
  final TicTacToeLogic g;
  const _Board({required this.players, required this.g});

  static String mark(int p) => p == 0 ? 'X' : 'O';

  @override
  State<_Board> createState() => _BoardState();
}

class _BoardState extends State<_Board> {
  int _bumps = 0; // shakes the board after a tap on a taken square

  void _tap(int i) {
    final g = widget.g;
    if (g.finished) return;
    if (g.cells[i] >= 0) {
      haptic(HapticWeight.heavy);
      setState(() => _bumps++);
      return;
    }
    if (g.play(i)) {
      haptic(HapticWeight.selection);
      GameAudio.sfx('tap');
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g, players = widget.players;
    final current = players[g.turn];
    ResultScope.of(context)?.subtitle = g.winner != null
        ? 'Three in a row'
        : (g.isDraw ? 'Every square taken' : null);
    return MomentWatcher<bool>(
      value: g.finished,
      onChange: (fx, _, done) {
        if (!done) return;
        if (g.winner != null) {
          keyMoment(fx, 'THREE IN A ROW!',
              sub: '${players[g.winner!].name} wins',
              sound: 'win',
              confetti: true);
        } else {
          keyMoment(fx, 'DRAW!',
              sub: 'Every square taken', color: Colors.white);
        }
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.s, Space.xs, Space.s, Space.l),
        child: Column(children: [
          ScoreHud(
            title: 'Tic-Tac-Toe',
            state: g.winner != null
                ? '${players[g.winner!].name} wins'
                : (g.isDraw
                    ? 'Draw'
                    : '${possessive(current.name)} turn (${_Board.mark(g.turn)})'),
            players: players,
            turn: g.finished ? null : g.turn,
            score: (i) => _Board.mark(i),
            tag: (i) => !g.finished && i == g.turn
                ? 'YOUR TURN'
                : (g.winner == i ? 'WINNER' : null),
          ),
          const Spacer(),
          LayoutBuilder(builder: (context, c) {
            final side = c.maxWidth.clamp(0.0, 460.0);
            return Shake(
              trigger: _bumps == 0 ? null : _bumps,
              child: SizedBox(
                width: side,
                height: side,
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: const _SlatePainter(),
                    child: Padding(
                      padding: EdgeInsets.all(side * 0.07),
                      child: Stack(children: [
                        GridView.count(
                          crossAxisCount: 3,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            for (var i = 0; i < 9; i++)
                              Semantics(
                                button: g.cells[i] < 0 && !g.finished,
                                label:
                                    'Row ${i ~/ 3 + 1}, column ${i % 3 + 1}: ${g.cells[i] < 0 ? 'empty' : _Board.mark(g.cells[i])}',
                                excludeSemantics: true,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => _tap(i),
                                  child: g.cells[i] < 0
                                      ? const SizedBox.expand()
                                      : _Mark(
                                          key: ValueKey('m$i${g.cells[i]}'),
                                          x: g.cells[i] == 0,
                                          color: Color.lerp(
                                              players[g.cells[i]].color,
                                              _chalk,
                                              0.25)!,
                                          glow:
                                              g.winLine?.contains(i) ?? false),
                                ),
                              ),
                          ],
                        ),
                        if (g.winLine != null)
                          Positioned.fill(
                              child: IgnorePointer(
                                  child: _WinLine(line: g.winLine!))),
                      ]),
                    ),
                  ),
                ),
              ),
            );
          }),
          const Spacer(flex: 2),
        ]),
      ),
    );
  }
}

/// The board: wooden frame, slate, and a hand-drawn chalk grid.
class _SlatePainter extends CustomPainter {
  const _SlatePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final frame =
        RRect.fromRectAndRadius(r, Radius.circular(size.width * 0.06));
    canvas.drawRRect(
        frame.shift(const Offset(0, 6)), Paint()..color = Colors.black38);
    canvas.drawRRect(
        frame,
        Paint()
          ..shader = LinearGradient(
                  colors: _wood,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight)
              .createShader(r));
    // Wood grain.
    final grain = Paint()
      ..color = Colors.black.withValues(alpha: 0.12)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    for (var k = 0; k < 14; k++) {
      final y = size.height * (k + 0.5) / 14;
      canvas.drawPath(
          Path()
            ..moveTo(0, y)
            ..quadraticBezierTo(
                size.width / 2, y + (k.isEven ? 6 : -6), size.width, y),
          grain);
    }
    final inner = r.deflate(size.width * 0.045);
    final slate =
        RRect.fromRectAndRadius(inner, Radius.circular(size.width * 0.03));
    canvas.drawRRect(
        slate,
        Paint()
          ..shader = LinearGradient(
                  colors: _slate,
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter)
              .createShader(inner));
    // Chalk dust smudges.
    for (final (x, y, rad) in const [
      (0.3, 0.25, 0.18),
      (0.72, 0.6, 0.22),
      (0.4, 0.8, 0.15)
    ]) {
      final c =
          Offset(inner.left + inner.width * x, inner.top + inner.height * y);
      canvas.drawCircle(
          c,
          inner.width * rad,
          Paint()
            ..shader = RadialGradient(colors: [
              Colors.white.withValues(alpha: 0.05),
              Colors.white.withValues(alpha: 0)
            ]).createShader(
                Rect.fromCircle(center: c, radius: inner.width * rad)));
    }
    // Grid: two slightly wobbly chalk lines each way.
    final play = r.deflate(size.width * 0.07);
    final chalk = Paint()
      ..color = _chalk.withValues(alpha: 0.85)
      ..strokeWidth = size.width * 0.018
      ..strokeCap = StrokeCap.round;
    for (var k = 1; k <= 2; k++) {
      final x = play.left + play.width * k / 3,
          y = play.top + play.height * k / 3;
      canvas.drawPath(
          Path()
            ..moveTo(x - 2, play.top + 6)
            ..quadraticBezierTo(x + 3, play.center.dy, x - 1, play.bottom - 6),
          chalk..style = PaintingStyle.stroke);
      canvas.drawPath(
          Path()
            ..moveTo(play.left + 6, y + 2)
            ..quadraticBezierTo(play.center.dx, y - 3, play.right - 6, y + 1),
          chalk);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// An X or O drawn in with a chalk stroke.
class _Mark extends StatelessWidget {
  final bool x;
  final Color color;
  final bool glow;
  const _Mark(
      {super.key, required this.x, required this.color, required this.glow});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: Motion.reduced(context) ? 1 : 0, end: 1),
        duration: Motion.of(context, const Duration(milliseconds: 260)),
        curve: Motion.standard,
        builder: (_, p, __) => CustomPaint(
            painter: _MarkPainter(x, color, p, glow), size: Size.infinite),
      );
}

class _MarkPainter extends CustomPainter {
  final bool x;
  final Color color;
  final double p;
  final bool glow;
  _MarkPainter(this.x, this.color, this.p, this.glow);

  @override
  void paint(Canvas canvas, Size size) {
    final r = (Offset.zero & size).deflate(size.width * 0.2);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.11
      ..strokeCap = StrokeCap.round;
    if (glow)
      canvas.drawCircle(r.center, size.width * 0.42,
          Paint()..color = Brand.gold.withValues(alpha: 0.28));
    if (x) {
      final a = (p * 2).clamp(0.0, 1.0), b = (p * 2 - 1).clamp(0.0, 1.0);
      canvas.drawLine(
          r.topLeft, Offset.lerp(r.topLeft, r.bottomRight, a)!, paint);
      if (b > 0)
        canvas.drawLine(
            r.topRight, Offset.lerp(r.topRight, r.bottomLeft, b)!, paint);
    } else {
      canvas.drawArc(r, -1.6, 6.283 * p, false, paint);
    }
  }

  @override
  bool shouldRepaint(_MarkPainter o) =>
      o.p != p || o.color != color || o.glow != glow;
}

/// The chalk line struck through the winning three.
class _WinLine extends StatelessWidget {
  final List<int> line;
  const _WinLine({required this.line});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: Motion.reduced(context) ? 1 : 0, end: 1),
        duration: Motion.of(context, Motion.slow),
        curve: Motion.standard,
        builder: (_, p, __) => CustomPaint(painter: _WinLinePainter(line, p)),
      );
}

class _WinLinePainter extends CustomPainter {
  final List<int> line;
  final double p;
  _WinLinePainter(this.line, this.p);
  @override
  void paint(Canvas canvas, Size size) {
    Offset centre(int i) => Offset(
        (i % 3 + 0.5) * size.width / 3, (i ~/ 3 + 0.5) * size.height / 3);
    final a = centre(line.first), b = centre(line.last);
    final dir = (b - a) / (b - a).distance;
    final start = a - dir * size.width * 0.12,
        end = b + dir * size.width * 0.12;
    canvas.drawLine(
        start,
        Offset.lerp(start, end, p)!,
        Paint()
          ..color = Brand.gold
          ..strokeWidth = size.width * 0.04
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_WinLinePainter o) => o.p != p;
}
