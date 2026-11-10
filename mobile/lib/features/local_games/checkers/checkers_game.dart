import 'dart:async';
import '../../../core/text/agreement.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../guess_person/models/gp_player.dart';
import '../../../core/ui/components.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/game_hud.dart';
import '../../../core/audio/game_audio.dart';
import '../party/party_widgets.dart' show GameTopBar;
import '../shell/local_game_shell.dart' show ResultScope;
import '../shell/ticking_play.dart';

/// A move: from square, the squares landed on, and the pieces jumped.
class CheckersMove {
  final int from;
  final List<int>
      path; // landing squares in order (one for a step, several for a multi-jump)
  final List<int> captured;
  const CheckersMove(this.from, this.path, this.captured);
  int get to => path.last;
}

/// Checkers (English draughts) on 8x8. Player 1 (index 0) starts at the bottom and moves up.
/// Pieces move diagonally forward; kings (reaching the far row) move both ways. Capturing is
/// compulsory and a capture continues for as long as it can. Take every piece, or leave your
/// rival without a move, to win. 80 moves without a capture is a draw.
class CheckersLogic extends LocalGameLogic {
  static const size = 8;
  static const drawAfter = 80;

  /// board[square] = 0 empty, 1/2 player 1/2 man, 3/4 player 1/2 king.
  final List<int> board = List.filled(size * size, 0);
  int turn = 0;
  int? selected;
  int quietMoves = 0;
  bool draw = false;
  (int, int)? lastMove;
  int moveNo = 0; // counts moves, so the board knows when to animate a new one
  List<int> lastPath = const []; // the last move: squares landed on, in order
  List<int> lastCaptured = const []; // and the pieces it jumped, in order

  CheckersLogic() {
    for (var sq = 0; sq < 64; sq++) {
      final r = sq ~/ 8, c = sq % 8;
      if ((r + c).isOdd) {
        if (r <= 2) board[sq] = 2; // player 2 at the top
        if (r >= 5) board[sq] = 1; // player 1 at the bottom
      }
    }
  }

  static int ownerOf(int piece) =>
      piece == 0 ? -1 : (piece == 1 || piece == 3 ? 0 : 1);
  static bool isKing(int piece) => piece >= 3;
  int pieces(int player) => board.where((x) => ownerOf(x) == player).length;

  List<(int, int)> _dirs(int piece) {
    if (isKing(piece)) return const [(-1, -1), (-1, 1), (1, -1), (1, 1)];
    return ownerOf(piece) == 0
        ? const [(-1, -1), (-1, 1)]
        : const [(1, -1), (1, 1)];
  }

  bool _on(int r, int c) => r >= 0 && r < 8 && c >= 0 && c < 8;

  /// Every multi-jump from [sq] for [piece], given the pieces already [taken].
  List<CheckersMove> _jumps(
      int start, int sq, int piece, List<int> path, List<int> taken) {
    final out = <CheckersMove>[];
    final r = sq ~/ 8, c = sq % 8;
    for (final (dr, dc) in _dirs(piece)) {
      final mr = r + dr, mc = c + dc, lr = r + 2 * dr, lc = c + 2 * dc;
      if (!_on(lr, lc)) continue;
      final mid = mr * 8 + mc, land = lr * 8 + lc;
      final midPiece = board[mid];
      if (ownerOf(midPiece) != 1 - ownerOf(piece) || taken.contains(mid))
        continue;
      if (board[land] != 0 && land != start) continue;
      final nextPath = [...path, land], nextTaken = [...taken, mid];
      // A man that reaches the far row is crowned and the move ends there.
      final crowned = !isKing(piece) && (lr == 0 || lr == 7);
      final more = crowned
          ? const <CheckersMove>[]
          : _jumps(start, land, piece, nextPath, nextTaken);
      out.addAll(
          more.isEmpty ? [CheckersMove(start, nextPath, nextTaken)] : more);
    }
    return out;
  }

  /// Legal moves for [player]. Captures are compulsory.
  List<CheckersMove> movesFor(int player) {
    final jumps = <CheckersMove>[], steps = <CheckersMove>[];
    for (var sq = 0; sq < 64; sq++) {
      final p = board[sq];
      if (ownerOf(p) != player) continue;
      jumps.addAll(_jumps(sq, sq, p, const [], const []));
      final r = sq ~/ 8, c = sq % 8;
      for (final (dr, dc) in _dirs(p)) {
        if (_on(r + dr, c + dc) && board[(r + dr) * 8 + c + dc] == 0)
          steps.add(CheckersMove(sq, [(r + dr) * 8 + c + dc], const []));
      }
    }
    return jumps.isNotEmpty ? jumps : steps;
  }

  List<CheckersMove> get legal => movesFor(turn);

  @override
  bool get finished => draw || legal.isEmpty;
  int? get winner =>
      draw || !finished ? null : 1 - turn; // whoever can't move loses
  @override
  List<int> get scores => [for (var p = 0; p < 2; p++) winner == p ? 1 : 0];
  @override
  void update(int elapsedMs) {}

  /// Taps a square: picks one of your pieces, or moves the picked piece there.
  void tap(int sq) {
    if (forward('tap', [sq])) return;
    if (finished) return;
    final moves = legal;
    if (ownerOf(board[sq]) == turn && moves.any((m) => m.from == sq)) {
      selected = sq;
      notifyListeners();
      return;
    }
    final s = selected;
    if (s == null) return;
    final options = moves.where((m) => m.from == s && m.to == sq).toList();
    if (options.isEmpty) return;
    // Two different jump routes to the same square: take the one that captures most.
    options.sort((a, b) => b.captured.length - a.captured.length);
    play(options.first);
  }

  void play(CheckersMove m) {
    var piece = board[m.from];
    board[m.from] = 0;
    for (final c in m.captured) {
      board[c] = 0;
    }
    final row = m.to ~/ 8;
    if (!isKing(piece) &&
        ((ownerOf(piece) == 0 && row == 0) ||
            (ownerOf(piece) == 1 && row == 7))) piece += 2;
    board[m.to] = piece;
    quietMoves = m.captured.isEmpty ? quietMoves + 1 : 0;
    if (quietMoves >= drawAfter) draw = true;
    lastMove = (m.from, m.to);
    lastPath = List.of(m.path);
    lastCaptured = List.of(m.captured);
    moveNo++;
    selected = null;
    turn = 1 - turn;
    notifyListeners();
  }
}

/// The computer: biggest capture, crowning, then safe moves forward; a little randomness.
CheckersMove checkersBotPick(CheckersLogic g, Random rng) {
  final moves = g.legal;
  double value(CheckersMove m) {
    var v = m.captured.length * 10.0 + rng.nextDouble();
    final piece = g.board[m.from];
    final row = m.to ~/ 8;
    if (!CheckersLogic.isKing(piece) && (row == 0 || row == 7)) v += 6;
    // Would the piece be jumped right away? (rough look at its new neighbours)
    final r = row, c = m.to % 8;
    for (final (dr, dc) in const [(-1, -1), (-1, 1), (1, -1), (1, 1)]) {
      final ar = r + dr, ac = c + dc, br = r - dr, bc = c - dc;
      if (ar < 0 ||
          ar > 7 ||
          ac < 0 ||
          ac > 7 ||
          br < 0 ||
          br > 7 ||
          bc < 0 ||
          bc > 7) continue;
      final attacker = g.board[ar * 8 + ac];
      final behind = br * 8 + bc;
      if (CheckersLogic.ownerOf(attacker) == 1 - g.turn &&
          (g.board[behind] == 0 || behind == m.from)) v -= 5;
    }
    if (c == 0 || c == 7) v += 1; // edges are safe
    return v;
  }

  return moves.reduce((a, b) => value(a) >= value(b) ? a : b);
}

final checkersInfo = LocalGameInfo(
  id: 'checkers',
  title: 'Checkers',
  emoji: '⚫',
  color: const Color(0xFFB71C1C),
  tagline: 'Jump, capture, crown your king!',
  rules: const [
    'Move a piece one square diagonally forward. Tap a piece, then where it goes.',
    'Jump over a rival piece to capture it. Captures are compulsory and keep going if they can.',
    'Reach the far side to become a king, which moves backwards too.',
    'Take every rival piece (or leave them with no move) to win. Sit at opposite ends of the phone.',
  ],
  scoreUnit: 'wins',
  splitScreen: false,
  bot: botFor<CheckersLogic>((g, b, now) {
    if (g.finished || g.turn != b.seat) return;
    if (!b.thinkFirst((g.turn, g.lastMove), now, 1300, 2000))
      return; // slow enough to watch the previous move finish
    g.play(checkersBotPick(g, b.rng));
  }),
  online: RelaySpec<CheckersLogic>(
    create: (n) => CheckersLogic(),
    save: (g) => {
      'board': g.board,
      'turn': g.turn,
      'sel': g.selected,
      'quiet': g.quietMoves,
      'draw': g.draw,
      'last': g.lastMove == null ? null : [g.lastMove!.$1, g.lastMove!.$2],
      'no': g.moveNo,
      'path': g.lastPath,
      'caps': g.lastCaptured,
    },
    load: (g, s, me) {
      g.board.setAll(0, ints(s['board']));
      g.turn = asInt(s['turn']);
      g.quietMoves = asInt(s['quiet']);
      g.draw = s['draw'] == true;
      final last = s['last'] == null ? null : ints(s['last']);
      g.lastMove = last == null ? null : (last[0], last[1]);
      g.moveNo = asInt(s['no']);
      g.lastPath = ints(s['path']);
      g.lastCaptured = ints(s['caps']);
      g.selected = g.turn == me
          ? nInt(s['sel'])
          : null; // a picked piece is only shown to its player
    },
    apply: (g, from, name, a) {
      if (name == 'tap' && from == g.turn) g.tap(asInt(a[0]));
    },
    view: (context, g, players, me) =>
        _CheckersTable(g: g, players: players, flipped: me == 1),
  ),
  play: (players, onFinished) => TickingPlay<CheckersLogic>(
    create: () => CheckersLogic(),
    onFinished: onFinished,
    builder: (context, g) => _CheckersTable(g: g, players: players),
  ),
);

class _CheckersTable extends StatelessWidget {
  final CheckersLogic g;
  final List<GpPlayer> players;
  final bool flipped; // online player 2 sees their own pieces at the bottom
  const _CheckersTable(
      {required this.g, required this.players, this.flipped = false});

  int get _kings => g.board.where(CheckersLogic.isKing).length;

  @override
  Widget build(BuildContext context) {
    final current = players[g.turn];
    final mustCapture = !g.finished && g.legal.first.captured.isNotEmpty;
    ResultScope.of(context)
      ?..subtitle = g.draw
          ? 'Draw: 80 moves without a capture'
          : (g.winner == null ? null : '${g.pieces(g.winner!)} pieces left')
      ..detail = (context, i) =>
          _Captured(count: 12 - g.pieces(1 - i), color: players[1 - i].color);
    Widget card(int p) => PlayerScoreCard(
          seat: PlayerPalette.indexOf(players[p].color) ?? p,
          color: players[p].color,
          name: players[p].name,
          score: '${g.pieces(p)}',
          active: !g.finished && g.turn == p,
          tag: !g.finished && g.turn == p
              ? (mustCapture ? 'MUST CAPTURE' : 'YOUR TURN')
              : null,
          detail: _Captured(
              count: 12 - g.pieces(1 - p), color: players[1 - p].color),
        );
    // Player 2 sits at the far end: their card faces them (not when online: each phone is its own).
    final far = flipped ? 0 : 1, near = flipped ? 1 : 0;
    return MomentWatcher<(int, int)>(
      value: (g.moveNo, _kings),
      onChange: (fx, before, now) {
        if (now.$1 == before.$1) return;
        if (now.$2 > before.$2) {
          keyMoment(fx, 'KING!',
              sub: '${players[1 - g.turn].name} is crowned',
              sound: 'coin',
              confetti: true);
        } else if (g.lastCaptured.length > 1) {
          keyMoment(
              fx, '${g.lastCaptured.length == 2 ? 'DOUBLE' : 'MULTI'} JUMP!',
              sub: '${g.lastCaptured.length} pieces taken',
              sound: 'boom',
              buzz: HapticWeight.heavy,
              shake: true);
        } else if (g.lastCaptured.isNotEmpty) {
          fx?.pop('CAPTURE!');
          GameAudio.sfx('hit');
          haptic(HapticWeight.medium);
        }
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.s, Space.xs, Space.s, Space.m),
        child: Column(children: [
          GameTopBar(
            title: 'Checkers',
            subtitle: g.draw
                ? 'Draw'
                : (g.finished
                    ? winsPhrase(players[g.winner!].name)
                    : (mustCapture
                        ? '${current.name}: must capture'
                        : '${possessive(current.name)} turn')),
          ),
          const SizedBox(height: Space.s),
          if (flipped)
            card(far)
          else
            RotatedBox(
                quarterTurns: 2,
                child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: card(far))),
          const SizedBox(height: Space.s),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: Semantics(
                  label:
                      'Checkers board. ${current.name} to move${mustCapture ? ', must capture' : ''}. ${players[0].name} ${g.pieces(0)} pieces, ${players[1].name} ${g.pieces(1)}.',
                  child: _Board(g: g, players: players, flipped: flipped),
                ),
              ),
            ),
          ),
          const SizedBox(height: Space.s),
          Padding(padding: const EdgeInsets.only(top: 10), child: card(near)),
        ]),
      ),
    );
  }
}

/// Pieces a player has taken, as a small stack of discs in the rival's colour.
class _Captured extends StatelessWidget {
  final int count;
  final Color color;
  const _Captured({required this.count, required this.color});
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 14,
        child: count == 0
            ? Align(
                alignment: Alignment.centerLeft,
                child: Text('No captures yet',
                    style: TextStyle(
                        fontFamily: Fonts.body,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: context.tk.flat
                            ? FlatPalette.inkMuted
                            : NeonPalette.label)))
            : Stack(children: [
                for (var i = 0; i < count; i++)
                  Positioned(
                    left: i * 9.0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.8),
                              width: 1.2),
                          boxShadow: const [
                            BoxShadow(
                                color: Color(0x66000000), offset: Offset(0, 1))
                          ]),
                    ),
                  ),
              ]),
      );
}

// Board palette: a wooden board with maple and walnut squares.
const _lightSq = Color(0xFFF1DDB6);
const _darkSq = Color(0xFF7A4B2E);
const _lastSq = Color(0xFF9B6A45);

/// Maple and walnut squares with a little grain; the last move's squares a shade lighter.
class _SquaresPainter extends CustomPainter {
  final bool flipped;
  final int? from, to;
  _SquaresPainter(this.flipped, this.from, this.to);

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 8;
    final grain = Paint()
      ..strokeWidth = 0.8
      ..color = const Color(0x1F3A2010);
    for (var i = 0; i < 64; i++) {
      final sq = flipped ? 63 - i : i;
      final dark = (sq ~/ 8 + sq % 8).isOdd;
      final r = Rect.fromLTWH((i % 8) * cell, (i ~/ 8) * cell, cell, cell);
      canvas.drawRect(
          r,
          Paint()
            ..color = dark
                ? ((sq == from || sq == to) ? _lastSq : _darkSq)
                : _lightSq);
      for (var k = 1; k < 4; k++) {
        final y = r.top + r.height * k / 4 + sin(i + k) * 2;
        canvas.drawLine(Offset(r.left, y),
            Offset(r.right, y + cos(i * 1.3 + k) * 2), grain);
      }
    }
  }

  @override
  bool shouldRepaint(_SquaresPainter old) =>
      old.flipped != flipped || old.from != from || old.to != to;
}

/// A checker: a stacked disc with a darker side band, grooved rings on top and the
/// player's shape (or a crown for a king). [lifted] when picked.
class _PiecePainter extends CustomPainter {
  final Color color;
  final int seat;
  final bool king, lifted, ring, mustCapture;
  _PiecePainter(this.color, this.seat,
      {this.king = false,
      this.lifted = false,
      this.ring = false,
      this.mustCapture = false});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final lift = lifted ? r * 0.12 : 0.0;
    canvas.drawOval(
        Rect.fromCenter(
            center: c + Offset(0, r * 0.22 + lift),
            width: r * 1.9 + lift,
            height: r * 1.5),
        Paint()
          ..color = Color.fromRGBO(0, 0, 0, lifted ? 0.35 : 0.5)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, lifted ? 5 : 2));
    final top = c - Offset(0, r * 0.12 + lift);
    canvas.drawCircle(top + Offset(0, r * 0.16), r * 0.88,
        Paint()..color = Color.lerp(color, Colors.black, 0.45)!); // side band
    canvas.drawCircle(
        top,
        r * 0.88,
        Paint()
          ..shader =
              RadialGradient(center: const Alignment(-0.3, -0.35), colors: [
            Color.lerp(color, Colors.white, 0.3)!,
            color,
            Color.lerp(color, Colors.black, 0.2)!
          ]).createShader(Rect.fromCircle(center: top, radius: r)));
    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.05;
    for (final k in [0.7, 0.52]) {
      canvas.drawCircle(
          top,
          r * k,
          groove
            ..color =
                Color.lerp(color, Colors.black, 0.3)!.withValues(alpha: 0.7));
      canvas.drawCircle(top + Offset(0, r * 0.03), r * k,
          groove..color = Colors.white.withValues(alpha: 0.25));
    }
    if (king) {
      paintIcon(canvas, GameIcons.crownKing,
          Rect.fromCircle(center: top, radius: r * 0.5),
          color: Colors.white);
    } else {
      final m = r * 0.5;
      canvas.save();
      canvas.translate(top.dx - m / 2, top.dy - m / 2);
      PlayerShapePainter(
              PlayerPalette.shape(seat), Colors.white.withValues(alpha: 0.5))
          .paint(canvas, Size(m, m));
      canvas.restore();
    }
    if (ring || lifted || mustCapture) {
      canvas.drawCircle(
          top,
          r * 0.92,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = lifted ? r * 0.14 : r * 0.08
            ..color = lifted || mustCapture
                ? Brand.gold
                : Colors.white.withValues(alpha: 0.85));
    }
  }

  @override
  bool shouldRepaint(_PiecePainter o) =>
      o.color != color ||
      o.king != king ||
      o.lifted != lifted ||
      o.ring != ring ||
      o.mustCapture != mustCapture ||
      o.seat != seat;
}

/// The board. Pieces sit in a layer above the squares so a move can be shown: the piece
/// slides square by square along its path and every piece it jumps fades away as it passes.
class _Board extends StatefulWidget {
  final CheckersLogic g;
  final List<GpPlayer> players;
  final bool flipped;
  const _Board({required this.g, required this.players, required this.flipped});

  @override
  State<_Board> createState() => _BoardState();
}

class _BoardState extends State<_Board> {
  static const stepMs = 320;
  CheckersLogic get g => widget.g;
  late int _seen = g.moveNo; // the last move already shown
  int? _step; // while showing a move: how many landing squares it has reached
  Timer? _timer;

  @override
  void didUpdateWidget(_Board old) {
    super.didUpdateWidget(old);
    _maybeAnimate();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _maybeAnimate() {
    if (g.moveNo == _seen || g.lastPath.isEmpty) return;
    _seen = g.moveNo;
    _timer?.cancel();
    _step = 0;
    // Start sliding on the next frame, then one landing square every [stepMs].
    _timer = Timer.periodic(const Duration(milliseconds: stepMs), (t) {
      if (!mounted) return t.cancel();
      setState(() {
        _step = _step! + 1;
        if (_step! > g.lastPath.length) {
          _step = null;
          t.cancel();
        }
      });
    });
    // The first slide begins straight away.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _step == 0) setState(() => _step = 0);
    });
  }

  Offset _cell(int sq, double cell) {
    final d = widget.flipped ? 63 - sq : sq;
    return Offset((d % 8) * cell, (d ~/ 8) * cell);
  }

  @override
  Widget build(BuildContext context) {
    _maybeAnimate();
    final legal = g.finished ? const <CheckersMove>[] : g.legal;
    final movable = {for (final m in legal) m.from};
    final targets = g.selected == null
        ? const <int>{}
        : {
            for (final m in legal)
              if (m.from == g.selected) m.to
          };
    final showing = _step != null && g.lastMove != null;
    final from = g.lastMove?.$1, to = g.lastMove?.$2;

    final capturing = legal.isNotEmpty && legal.first.captured.isNotEmpty;
    return BoardFrame(
      child: LayoutBuilder(builder: (context, c) {
        final cell = c.maxWidth / 8;
        Widget piece(int value, {bool selected = false, bool canMove = false}) {
          final owner = CheckersLogic.ownerOf(value);
          final col = widget.players[owner].color;
          return Padding(
            padding: EdgeInsets.all(cell * 0.06),
            child: CustomPaint(
              painter: _PiecePainter(col, PlayerPalette.indexOf(col) ?? owner,
                  king: CheckersLogic.isKing(value),
                  lifted: selected,
                  ring: canMove,
                  mustCapture: canMove && capturing && !selected),
            ),
          );
        }

        final pieces = <Widget>[];
        for (var sq = 0; sq < 64; sq++) {
          final v = g.board[sq];
          if (v == 0 || (showing && sq == to))
            continue; // the moving piece is drawn on its way
          final at = _cell(sq, cell);
          pieces.add(Positioned(
            key: ValueKey('p$sq'),
            left: at.dx,
            top: at.dy,
            width: cell,
            height: cell,
            child: IgnorePointer(
                child: piece(v,
                    selected: g.selected == sq,
                    canMove: movable.contains(sq) &&
                        CheckersLogic.ownerOf(v) == g.turn)),
          ));
        }
        if (showing) {
          // Jumped pieces stay until the mover passes them, then fade out.
          final mover = g.board[to!];
          for (var k = 0; k < g.lastCaptured.length; k++) {
            final at = _cell(g.lastCaptured[k], cell);
            pieces.add(Positioned(
              key: ValueKey('cap$k'),
              left: at.dx,
              top: at.dy,
              width: cell,
              height: cell,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: stepMs),
                  opacity: _step! > k ? 0 : 1,
                  child: piece(CheckersLogic.ownerOf(mover) == 0 ? 2 : 1),
                ),
              ),
            ));
          }
          final where = _step == 0
              ? from!
              : g.lastPath[min(_step!, g.lastPath.length) - 1];
          final at = _cell(where, cell);
          pieces.add(AnimatedPositioned(
            key: const ValueKey('mover'),
            duration: const Duration(milliseconds: stepMs - 40),
            curve: Curves.easeInOut,
            left: at.dx - cell * 0.06,
            top: at.dy - cell * 0.06,
            width: cell * 1.12, // lifted while it moves
            height: cell * 1.12,
            child: IgnorePointer(child: piece(mover)),
          ));
        }

        return Stack(children: [
          Positioned.fill(
              child: RepaintBoundary(
                  child: CustomPaint(
                      painter: _SquaresPainter(widget.flipped,
                          showing ? null : from, showing ? null : to)))),
          GridView.count(
            crossAxisCount: 8,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (var i = 0; i < 64; i++)
                Builder(builder: (context) {
                  final sq = widget.flipped ? 63 - i : i;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      haptic(HapticWeight.selection);
                      g.tap(sq);
                    },
                    child: Center(
                      child: targets.contains(sq)
                          ? FractionallySizedBox(
                              widthFactor: 0.3,
                              heightFactor: 0.3,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Brand.gold.withValues(alpha: 0.75),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                        color:
                                            Brand.gold.withValues(alpha: 0.6),
                                        blurRadius: 8)
                                  ],
                                ),
                              ),
                            )
                          : null,
                    ),
                  );
                }),
            ],
          ),
          ...pieces,
        ]);
      }),
    );
  }
}
