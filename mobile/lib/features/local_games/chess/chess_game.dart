import 'dart:math';
import 'package:flutter/material.dart';
import '../../guess_person/models/gp_player.dart';
import '../../../core/audio/game_audio.dart';
import '../../../core/ui/components.dart';
import '../party/party_widgets.dart' show GameTopBar;
import '../shell/game_hud.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/local_game_shell.dart' show ResultScope;
import '../shell/ticking_play.dart';

/// Piece types. A square holds 0 (empty) or `type + 8 * owner`.
abstract final class Piece {
  static const pawn = 1, knight = 2, bishop = 3, rook = 4, queen = 5, king = 6;
  static int type(int v) => v & 7;
  static int owner(int v) => v == 0 ? -1 : v >> 3;
  static int make(int type, int owner) => type + 8 * owner;
  static const value = [0, 1, 3, 3, 5, 9, 0];
  static const names = [
    '',
    'pawn',
    'knight',
    'bishop',
    'rook',
    'queen',
    'king'
  ];
}

class ChessMove {
  final int from, to;
  final bool castle, enPassant, promote;
  const ChessMove(this.from, this.to,
      {this.castle = false, this.enPassant = false, this.promote = false});
}

/// A position: the board plus castling rights and the en-passant square.
class ChessPosition {
  final List<int> board;
  List<bool>
      castling; // white king side, white queen side, black king side, black queen side
  int? ep; // the square a pawn skipped over last move
  ChessPosition(this.board, this.castling, this.ep);

  ChessPosition copy() => ChessPosition(List.of(board), List.of(castling), ep);

  static ChessPosition start() {
    const back = [
      Piece.rook,
      Piece.knight,
      Piece.bishop,
      Piece.queen,
      Piece.king,
      Piece.bishop,
      Piece.knight,
      Piece.rook
    ];
    final b = List.filled(64, 0);
    for (var c = 0; c < 8; c++) {
      b[c] = Piece.make(back[c], 1); // player 2 at the top
      b[8 + c] = Piece.make(Piece.pawn, 1);
      b[48 + c] =
          Piece.make(Piece.pawn, 0); // player 1 at the bottom, moving up
      b[56 + c] = Piece.make(back[c], 0);
    }
    return ChessPosition(b, [true, true, true, true], null);
  }

  static bool _on(int r, int c) => r >= 0 && r < 8 && c >= 0 && c < 8;
  static const _knight = [
    (-2, -1),
    (-2, 1),
    (-1, -2),
    (-1, 2),
    (1, -2),
    (1, 2),
    (2, -1),
    (2, 1)
  ];
  static const _king = [
    (-1, -1),
    (-1, 0),
    (-1, 1),
    (0, -1),
    (0, 1),
    (1, -1),
    (1, 0),
    (1, 1)
  ];
  static const _diag = [(-1, -1), (-1, 1), (1, -1), (1, 1)];
  static const _line = [(-1, 0), (1, 0), (0, -1), (0, 1)];

  int kingOf(int who) => board.indexOf(Piece.make(Piece.king, who));

  /// Is [sq] attacked by any piece of [by]?
  bool attacked(int sq, int by) {
    final r = sq ~/ 8, c = sq % 8;
    final pawnRow = by == 0 ? r + 1 : r - 1; // pawns attack toward the far side
    for (final dc in const [-1, 1]) {
      if (_on(pawnRow, c + dc) &&
          board[pawnRow * 8 + c + dc] == Piece.make(Piece.pawn, by))
        return true;
    }
    for (final (dr, dc) in _knight) {
      if (_on(r + dr, c + dc) &&
          board[(r + dr) * 8 + c + dc] == Piece.make(Piece.knight, by))
        return true;
    }
    for (final (dr, dc) in _king) {
      if (_on(r + dr, c + dc) &&
          board[(r + dr) * 8 + c + dc] == Piece.make(Piece.king, by))
        return true;
    }
    bool slide(List<(int, int)> dirs, int a, int b) {
      for (final (dr, dc) in dirs) {
        var rr = r + dr, cc = c + dc;
        while (_on(rr, cc)) {
          final v = board[rr * 8 + cc];
          if (v != 0) {
            if (Piece.owner(v) == by &&
                (Piece.type(v) == a || Piece.type(v) == b)) return true;
            break;
          }
          rr += dr;
          cc += dc;
        }
      }
      return false;
    }

    return slide(_diag, Piece.bishop, Piece.queen) ||
        slide(_line, Piece.rook, Piece.queen);
  }

  bool inCheck(int who) => attacked(kingOf(who), 1 - who);

  List<ChessMove> _pseudo(int who) {
    final out = <ChessMove>[];
    for (var sq = 0; sq < 64; sq++) {
      final v = board[sq];
      if (Piece.owner(v) != who) continue;
      final r = sq ~/ 8, c = sq % 8;
      void add(int to, {bool castle = false, bool ep = false}) {
        final promote =
            Piece.type(v) == Piece.pawn && (to ~/ 8 == 0 || to ~/ 8 == 7);
        out.add(
            ChessMove(sq, to, castle: castle, enPassant: ep, promote: promote));
      }

      void steps(List<(int, int)> dirs, bool slide) {
        for (final (dr, dc) in dirs) {
          var rr = r + dr, cc = c + dc;
          while (_on(rr, cc)) {
            final t = board[rr * 8 + cc];
            if (Piece.owner(t) == who) break;
            add(rr * 8 + cc);
            if (t != 0 || !slide) break;
            rr += dr;
            cc += dc;
          }
        }
      }

      switch (Piece.type(v)) {
        case Piece.pawn:
          final dir = who == 0 ? -1 : 1, home = who == 0 ? 6 : 1;
          if (_on(r + dir, c) && board[(r + dir) * 8 + c] == 0) {
            add((r + dir) * 8 + c);
            if (r == home && board[(r + 2 * dir) * 8 + c] == 0)
              add((r + 2 * dir) * 8 + c);
          }
          for (final dc in const [-1, 1]) {
            if (!_on(r + dir, c + dc)) continue;
            final to = (r + dir) * 8 + c + dc;
            if (Piece.owner(board[to]) == 1 - who) add(to);
            if (to == ep) add(to, ep: true);
          }
        case Piece.knight:
          steps(_knight, false);
        case Piece.bishop:
          steps(_diag, true);
        case Piece.rook:
          steps(_line, true);
        case Piece.queen:
          steps([..._diag, ..._line], true);
        case Piece.king:
          steps(_king, false);
          final row = who == 0 ? 7 : 0;
          if (sq == row * 8 + 4 && !inCheck(who)) {
            final rook = Piece.make(Piece.rook, who);
            if (castling[who * 2] &&
                board[row * 8 + 7] == rook &&
                board[row * 8 + 5] == 0 &&
                board[row * 8 + 6] == 0 &&
                !attacked(row * 8 + 5, 1 - who)) {
              add(row * 8 + 6, castle: true);
            }
            if (castling[who * 2 + 1] &&
                board[row * 8] == rook &&
                board[row * 8 + 1] == 0 &&
                board[row * 8 + 2] == 0 &&
                board[row * 8 + 3] == 0 &&
                !attacked(row * 8 + 3, 1 - who)) {
              add(row * 8 + 2, castle: true);
            }
          }
      }
    }
    return out;
  }

  /// Makes [m] on this position; returns the piece captured (0 if none).
  int apply(ChessMove m) {
    final v = board[m.from], who = Piece.owner(v);
    var taken = board[m.to];
    board[m.to] = m.promote ? Piece.make(Piece.queen, who) : v;
    board[m.from] = 0;
    if (m.enPassant) {
      final behind = m.to + (who == 0 ? 8 : -8);
      taken = board[behind];
      board[behind] = 0;
    }
    if (m.castle) {
      final row = m.to ~/ 8;
      final kingSide = m.to % 8 == 6;
      board[row * 8 + (kingSide ? 5 : 3)] = board[row * 8 + (kingSide ? 7 : 0)];
      board[row * 8 + (kingSide ? 7 : 0)] = 0;
    }
    ep = Piece.type(v) == Piece.pawn && (m.to - m.from).abs() == 16
        ? (m.from + m.to) ~/ 2
        : null;
    // Moving the king or a rook, or losing a rook, ends those castling rights.
    for (final (sq, right) in const [
      (60, 0),
      (60, 1),
      (63, 0),
      (56, 1),
      (4, 2),
      (4, 3),
      (7, 2),
      (0, 3)
    ]) {
      if (m.from == sq || m.to == sq) castling[right] = false;
    }
    return taken;
  }

  List<ChessMove> legal(int who) => [
        for (final m in _pseudo(who))
          if (!(copy()..apply(m)).inCheck(who)) m
      ];

  /// Only kings, or a king and one bishop or knight against a bare king.
  bool get insufficient {
    final rest = [
      for (final v in board)
        if (v != 0 && Piece.type(v) != Piece.king) Piece.type(v)
    ];
    return rest.isEmpty ||
        (rest.length == 1 &&
            (rest.single == Piece.bishop || rest.single == Piece.knight));
  }
}

enum ChessEnd { none, checkmate, stalemate, fiftyMoves, material }

/// Chess for two at opposite ends of the phone. Player 1 (bottom) moves first. Pawns that
/// reach the far row become queens. Checkmate wins; stalemate, bare kings and 50 moves each
/// without a capture or pawn move are draws.
class ChessLogic extends LocalGameLogic {
  ChessPosition pos = ChessPosition.start();
  int turn = 0;
  int? selected;
  (int, int)? lastMove;
  int moveNo = 0;
  bool lastCapture = false;
  int quiet = 0; // half-moves since a capture or pawn move
  final List<List<int>> taken = [
    [],
    []
  ]; // piece types each player has captured
  ChessEnd end = ChessEnd.none;
  List<ChessMove> _legal = const [];

  ChessLogic() {
    _legal = pos.legal(turn);
  }

  List<ChessMove> get legal => _legal;
  bool get check => pos.inCheck(turn);
  int? get winner => end == ChessEnd.checkmate ? 1 - turn : null;
  int material(int p) => taken[p].fold(0, (a, t) => a + Piece.value[t]);

  @override
  bool get finished => end != ChessEnd.none;
  @override
  List<int> get scores => [for (var p = 0; p < 2; p++) winner == p ? 1 : 0];
  @override
  void update(int elapsedMs) {}

  /// Taps a square: picks one of your pieces, or moves the picked piece there.
  void tap(int sq) {
    if (forward('tap', [sq])) return;
    if (finished) return;
    if (Piece.owner(pos.board[sq]) == turn && _legal.any((m) => m.from == sq)) {
      selected = selected == sq ? null : sq;
      notifyListeners();
      return;
    }
    final s = selected;
    if (s == null) return;
    final m = _legal.where((m) => m.from == s && m.to == sq).firstOrNull;
    if (m == null) {
      selected = null;
      notifyListeners();
      return;
    }
    play(m);
  }

  void play(ChessMove m) {
    final pawn = Piece.type(pos.board[m.from]) == Piece.pawn;
    final got = pos.apply(m);
    if (got != 0) taken[turn].add(Piece.type(got));
    lastCapture = got != 0;
    quiet = got != 0 || pawn ? 0 : quiet + 1;
    lastMove = (m.from, m.to);
    moveNo++;
    selected = null;
    turn = 1 - turn;
    _legal = pos.legal(turn);
    if (_legal.isEmpty) {
      end = pos.inCheck(turn) ? ChessEnd.checkmate : ChessEnd.stalemate;
    } else if (quiet >= 100) {
      end = ChessEnd.fiftyMoves;
    } else if (pos.insufficient) {
      end = ChessEnd.material;
    }
    notifyListeners();
  }
}

/// The computer looks two half-moves ahead (its move, your best reply) on material, with a
/// nudge toward the centre and a little randomness so games differ.
ChessMove chessBotPick(ChessLogic g, Random rng) {
  final me = g.turn;
  double score(ChessPosition p) {
    var s = 0.0;
    for (var sq = 0; sq < 64; sq++) {
      final v = p.board[sq];
      if (v == 0) continue;
      final t = Piece.type(v);
      final r = sq ~/ 8, c = sq % 8;
      var worth = Piece.value[t].toDouble();
      if (t == Piece.knight || t == Piece.bishop || t == Piece.pawn)
        worth += (3.5 - ((r - 3.5).abs() + (c - 3.5).abs()) / 2) * 0.06;
      if (t == Piece.pawn)
        worth += (Piece.owner(v) == 0 ? 6 - r : r - 1) * 0.04; // pushed pawns
      s += Piece.owner(v) == me ? worth : -worth;
    }
    return s;
  }

  ChessMove? best;
  var bestScore = double.negativeInfinity;
  for (final m in g.legal) {
    final after = g.pos.copy()..apply(m);
    final replies = after.legal(1 - me);
    double v;
    if (replies.isEmpty) {
      v = after.inCheck(1 - me)
          ? 1000
          : -50; // mate, or a stalemate we don't want
    } else {
      v = double.infinity;
      for (final r in replies) {
        final p2 = after.copy()..apply(r);
        v = min(v, score(p2));
      }
    }
    v += rng.nextDouble() * 0.3;
    if (v > bestScore) {
      bestScore = v;
      best = m;
    }
  }
  return best!;
}

final chessInfo = LocalGameInfo(
  id: 'chess',
  title: 'Chess',
  emoji: '♟️',
  color: const Color(0xFF5B6B8C),
  tagline: 'Checkmate the king to win!',
  rules: const [
    'Tap one of your pieces to see where it can go, then tap the square. Player 1 moves first.',
    'Capture by moving onto a rival piece. Pawns reaching the far side become queens.',
    'Put the rival king in check with no escape (checkmate) to win.',
    'No legal move but not in check is a draw. Sit at opposite ends of the phone.',
  ],
  scoreUnit: 'wins',
  splitScreen: false,
  bot: botFor<ChessLogic>((g, b, now) {
    if (g.finished || g.turn != b.seat) return;
    if (!b.thinkFirst(g.moveNo, now, 700, 1400)) return;
    g.play(chessBotPick(g, b.rng));
  }),
  online: RelaySpec<ChessLogic>(
    create: (n) => ChessLogic(),
    save: (g) => {
      'board': g.pos.board,
      'castle': g.pos.castling,
      'ep': g.pos.ep,
      'turn': g.turn,
      'sel': g.selected,
      'last': g.lastMove == null ? null : [g.lastMove!.$1, g.lastMove!.$2],
      'no': g.moveNo,
      'cap': g.lastCapture,
      'quiet': g.quiet,
      'taken': g.taken,
      'end': g.end.index,
    },
    load: (g, s, me) {
      g.pos = ChessPosition(ints(s['board']),
          [for (final c in s['castle'] as List) c == true], nInt(s['ep']));
      g.turn = asInt(s['turn']);
      g.selected = g.turn == me
          ? nInt(s['sel'])
          : null; // a picked piece is only shown to its player
      final last = s['last'] == null ? null : ints(s['last']);
      g.lastMove = last == null ? null : (last[0], last[1]);
      g.moveNo = asInt(s['no']);
      g.lastCapture = s['cap'] == true;
      g.quiet = asInt(s['quiet']);
      final taken = s['taken'] as List;
      for (var p = 0; p < 2; p++) {
        g.taken[p]
          ..clear()
          ..addAll(ints(taken[p]));
      }
      g.end = ChessEnd.values[asInt(s['end'])];
      g._legal = g.pos.legal(g.turn);
    },
    apply: (g, from, name, a) {
      if (name == 'tap' && from == g.turn) g.tap(asInt(a[0]));
    },
    view: (context, g, players, me) =>
        _ChessTable(g: g, players: players, me: me),
  ),
  play: (players, onFinished) => TickingPlay<ChessLogic>(
    create: () => ChessLogic(),
    onFinished: onFinished,
    builder: (context, g) => _ChessTable(g: g, players: players),
  ),
);

class _ChessTable extends StatelessWidget {
  final ChessLogic g;
  final List<GpPlayer> players;
  final int?
      me; // online: this phone's player (player 2 sees the board turned round)
  const _ChessTable({required this.g, required this.players, this.me});

  String get _endText => switch (g.end) {
        ChessEnd.checkmate => 'Checkmate',
        ChessEnd.stalemate => 'Stalemate: draw',
        ChessEnd.fiftyMoves => 'Draw: 50 moves without a capture',
        ChessEnd.material => 'Draw: not enough pieces to mate',
        ChessEnd.none => '',
      };

  @override
  Widget build(BuildContext context) {
    final current = players[g.turn];
    ResultScope.of(context)?.subtitle = g.finished ? _endText : null;
    Widget card(int p) => PlayerScoreCard(
          seat: PlayerPalette.indexOf(players[p].color) ?? p,
          color: players[p].color,
          name: players[p].name,
          score: '+${g.material(p)}',
          active: !g.finished && g.turn == p,
          tag: !g.finished && g.turn == p
              ? (g.check ? 'CHECK!' : 'YOUR MOVE')
              : (g.winner == p ? 'WINNER' : null),
          tagColor: !g.finished && g.turn == p && g.check
              ? StatusColors.danger
              : null,
          detail: _Taken(types: g.taken[p], color: players[1 - p].color),
        );
    return MomentWatcher<int>(
      value: g.moveNo,
      onChange: (fx, before, now) {
        if (g.end == ChessEnd.checkmate) {
          keyMoment(fx, 'CHECKMATE!',
              sub: '${players[g.winner!].name} wins',
              sound: 'win',
              confetti: true);
        } else if (g.finished) {
          keyMoment(fx, 'DRAW!', sub: _endText, color: Colors.white);
        } else if (g.check) {
          keyMoment(fx, 'CHECK!',
              sub: '${possessive(current.name)} king is attacked',
              sound: 'hit',
              color: StatusColors.danger,
              buzz: HapticWeight.heavy);
        } else {
          GameAudio.sfx(g.lastCapture ? 'hit' : 'tap');
        }
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.s, Space.xs, Space.s, Space.m),
        child: Column(children: [
          GameTopBar(
              title: 'Chess',
              subtitle: g.finished
                  ? _endText
                  : (g.check
                      ? '${current.name} is in check!'
                      : '${possessive(current.name)} move')),
          const SizedBox(height: Space.s),
          if (me != null)
            card(me == 1 ? 0 : 1)
          else
            RotatedBox(
                quarterTurns: 2,
                child: Padding(
                    padding: const EdgeInsets.only(bottom: 6), child: card(1))),
          const SizedBox(height: Space.s),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: Semantics(
                    label:
                        'Chess board. ${current.name} to move${g.check ? ', in check' : ''}.',
                    child: _Board(g: g, players: players, me: me)),
              ),
            ),
          ),
          const SizedBox(height: Space.s),
          Padding(padding: const EdgeInsets.only(top: 6), child: card(me ?? 0)),
        ]),
      ),
    );
  }
}

/// The pieces a player has taken, as small drawings in the rival's colour.
class _Taken extends StatelessWidget {
  final List<int> types;
  final Color color;
  const _Taken({required this.types, required this.color});
  @override
  Widget build(BuildContext context) {
    final sorted = [...types]..sort((a, b) => Piece.value[b] - Piece.value[a]);
    return SizedBox(
      height: 16,
      child: sorted.isEmpty
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
              for (var i = 0; i < sorted.length; i++)
                Positioned(
                    left: i * 9.0,
                    width: 16,
                    height: 16,
                    child: CustomPaint(
                        painter: ChessPiecePainter(sorted[i], color))),
            ]),
    );
  }
}

const _lightSq = Color(0xFFEFE3C8);
const _darkSq = Color(0xFF8A6A4B);

class _SquaresPainter extends CustomPainter {
  final int? from, to, checkSq;
  _SquaresPainter(this.from, this.to, this.checkSq);

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 8;
    for (var sq = 0; sq < 64; sq++) {
      final r = Rect.fromLTWH((sq % 8) * cell, (sq ~/ 8) * cell, cell, cell);
      final dark = (sq ~/ 8 + sq % 8).isOdd;
      var col = dark ? _darkSq : _lightSq;
      if (sq == from || sq == to) col = Color.lerp(col, Brand.gold, 0.45)!;
      canvas.drawRect(r, Paint()..color = col);
      if (sq == checkSq) {
        canvas.drawRect(
            r,
            Paint()
              ..shader = RadialGradient(colors: [
                StatusColors.danger,
                StatusColors.danger.withValues(alpha: 0)
              ]).createShader(r));
      }
    }
    // File letters and rank numbers along the near edges.
    for (var i = 0; i < 8; i++) {
      final tp = TextPainter(
        text: TextSpan(
            text: 'abcdefgh'[i],
            style: TextStyle(
                fontSize: cell * 0.2,
                fontWeight: FontWeight.w800,
                color: (i.isOdd ? _lightSq : _darkSq).withValues(alpha: 0.9))),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas,
          Offset((i + 1) * cell - tp.width - 2, size.height - tp.height - 1));
    }
  }

  @override
  bool shouldRepaint(_SquaresPainter o) =>
      o.from != from || o.to != to || o.checkSq != checkSq;
}

/// A chess piece drawn as a clay figure: a filled silhouette in the player's colour with a
/// dark outline, a soft highlight and a base.
class ChessPiecePainter extends CustomPainter {
  final int type;
  final Color color;
  ChessPiecePainter(this.type, this.color);

  Path _shape(double s) {
    Offset o(double x, double y) => Offset(x * s, y * s);
    Path poly(List<(double, double)> pts) =>
        Path()..addPolygon([for (final (x, y) in pts) o(x, y)], true);
    final p = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTRB(0.2 * s, 0.78 * s, 0.8 * s, 0.92 * s),
          Radius.circular(0.05 * s)));
    switch (type) {
      case Piece.pawn:
        p.addPath(poly([(0.34, 0.8), (0.42, 0.46), (0.58, 0.46), (0.66, 0.8)]),
            Offset.zero);
        p.addOval(Rect.fromCircle(center: o(0.5, 0.34), radius: 0.14 * s));
      case Piece.rook:
        p.addPath(poly([(0.3, 0.8), (0.34, 0.38), (0.66, 0.38), (0.7, 0.8)]),
            Offset.zero);
        p.addPath(
            poly([
              (0.26, 0.4),
              (0.26, 0.16),
              (0.36, 0.16),
              (0.36, 0.24),
              (0.45, 0.24),
              (0.45, 0.16),
              (0.55, 0.16),
              (0.55, 0.24),
              (0.64, 0.24),
              (0.64, 0.16),
              (0.74, 0.16),
              (0.74, 0.4)
            ]),
            Offset.zero);
      case Piece.knight:
        p.addPath(
            poly([
              (0.28, 0.8),
              (0.34, 0.58),
              (0.26, 0.5),
              (0.24, 0.4),
              (0.4, 0.26),
              (0.46, 0.12),
              (0.54, 0.2),
              (0.66, 0.26),
              (0.74, 0.44),
              (0.72, 0.8)
            ]),
            Offset.zero);
      case Piece.bishop:
        p.addPath(poly([(0.32, 0.8), (0.42, 0.6), (0.58, 0.6), (0.68, 0.8)]),
            Offset.zero);
        p.addOval(Rect.fromCenter(
            center: o(0.5, 0.42), width: 0.34 * s, height: 0.42 * s));
        p.addOval(Rect.fromCircle(center: o(0.5, 0.15), radius: 0.06 * s));
      case Piece.queen:
        p.addPath(
            poly([
              (0.3, 0.8),
              (0.24, 0.3),
              (0.37, 0.5),
              (0.42, 0.22),
              (0.5, 0.46),
              (0.58, 0.22),
              (0.63, 0.5),
              (0.76, 0.3),
              (0.7, 0.8)
            ]),
            Offset.zero);
        for (final x in [0.24, 0.42, 0.58, 0.76]) {
          p.addOval(Rect.fromCircle(
              center: o(x, x == 0.24 || x == 0.76 ? 0.27 : 0.19),
              radius: 0.05 * s));
        }
      case Piece.king:
        p.addPath(
            poly([
              (0.28, 0.8),
              (0.26, 0.42),
              (0.38, 0.32),
              (0.62, 0.32),
              (0.74, 0.42),
              (0.72, 0.8)
            ]),
            Offset.zero);
        p.addRect(Rect.fromLTRB(0.45 * s, 0.06 * s, 0.55 * s, 0.32 * s));
        p.addRect(Rect.fromLTRB(0.36 * s, 0.13 * s, 0.64 * s, 0.22 * s));
    }
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final shape = _shape(s);
    canvas.drawPath(shape.shift(Offset(0, s * 0.04)),
        Paint()..color = Colors.black.withValues(alpha: 0.35));
    canvas.drawPath(
        shape,
        Paint()
          ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(color, Colors.white, 0.45)!,
                color,
                Color.lerp(color, Colors.black, 0.25)!
              ]).createShader(Offset.zero & size));
    canvas.drawPath(
        shape,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1.0, s * 0.035)
          ..strokeJoin = StrokeJoin.round
          ..color = Color.lerp(color, Colors.black, 0.65)!);
    if (type == Piece.knight)
      canvas.drawCircle(Offset(0.52 * s, 0.3 * s), s * 0.035,
          Paint()..color = Color.lerp(color, Colors.black, 0.7)!);
    if (type == Piece.bishop) {
      canvas.drawLine(
          Offset(0.44 * s, 0.34 * s),
          Offset(0.56 * s, 0.46 * s),
          Paint()
            ..strokeWidth = s * 0.04
            ..strokeCap = StrokeCap.round
            ..color = Color.lerp(color, Colors.black, 0.6)!);
    }
  }

  @override
  bool shouldRepaint(ChessPiecePainter o) => o.type != type || o.color != color;
}

class _Board extends StatelessWidget {
  final ChessLogic g;
  final List<GpPlayer> players;
  final int? me;
  const _Board({required this.g, required this.players, this.me});

  @override
  Widget build(BuildContext context) {
    final moves = g.finished || g.selected == null
        ? const <ChessMove>[]
        : g.legal.where((m) => m.from == g.selected).toList();
    final targets = {for (final m in moves) m.to};
    final movable =
        g.finished ? const <int>{} : {for (final m in g.legal) m.from};
    final checkSq = !g.finished && g.check
        ? g.pos.kingOf(g.turn)
        : (g.end == ChessEnd.checkmate ? g.pos.kingOf(g.turn) : null);
    // Online player 2 sees the whole board turned round, their pieces at the bottom.
    return BoardFrame(
      child: RotatedBox(
          quarterTurns: me == 1 ? 2 : 0,
          child: LayoutBuilder(builder: (context, c) {
            final cell = c.maxWidth / 8;
            Widget piece(int sq) {
              final v = g.pos.board[sq];
              final owner = Piece.owner(v);
              final lifted = g.selected == sq;
              final art = CustomPaint(
                  painter:
                      ChessPiecePainter(Piece.type(v), players[owner].color));
              // Player 2 sits at the far end, so their pieces face them.
              return AnimatedScale(
                scale: lifted ? 1.15 : 1,
                duration: const Duration(milliseconds: 120),
                child: Padding(
                    padding: EdgeInsets.all(cell * 0.06),
                    child: (me == null ? owner == 1 : me == 1)
                        ? RotatedBox(quarterTurns: 2, child: art)
                        : art),
              );
            }

            final last = g.lastMove;
            return Stack(children: [
              Positioned.fill(
                  child: RepaintBoundary(
                      child: CustomPaint(
                          painter:
                              _SquaresPainter(last?.$1, last?.$2, checkSq)))),
              for (var sq = 0; sq < 64; sq++)
                if (g.pos.board[sq] != 0)
                  if (last != null && sq == last.$2)
                    // The piece that just moved slides in from where it was.
                    TweenAnimationBuilder<double>(
                      key: ValueKey('move${g.moveNo}'),
                      tween:
                          Tween(begin: Motion.reduced(context) ? 1 : 0, end: 1),
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      builder: (context, t, child) {
                        final a = Offset(
                                (last.$1 % 8) * cell, (last.$1 ~/ 8) * cell),
                            b = Offset((sq % 8) * cell, (sq ~/ 8) * cell);
                        final at = Offset.lerp(a, b, t)!;
                        return Positioned(
                            left: at.dx,
                            top: at.dy,
                            width: cell,
                            height: cell,
                            child: child!);
                      },
                      child: IgnorePointer(child: piece(sq)),
                    )
                  else
                    Positioned(
                        left: (sq % 8) * cell,
                        top: (sq ~/ 8) * cell,
                        width: cell,
                        height: cell,
                        child: IgnorePointer(child: piece(sq))),
              GridView.count(
                crossAxisCount: 8,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (var sq = 0; sq < 64; sq++)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        haptic(HapticWeight.selection);
                        g.tap(sq);
                      },
                      child: Semantics(
                        button: true,
                        label:
                            '${'abcdefgh'[sq % 8]}${8 - sq ~/ 8}${g.pos.board[sq] == 0 ? '' : ': ${players[Piece.owner(g.pos.board[sq])].name} ${Piece.names[Piece.type(g.pos.board[sq])]}'}',
                        excludeSemantics: true,
                        child: Center(
                          child: targets.contains(sq)
                              ? (g.pos.board[sq] != 0 ||
                                      moves
                                          .any((m) => m.to == sq && m.enPassant)
                                  ? Container(
                                      margin: EdgeInsets.all(cell * 0.04),
                                      decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: Brand.gold,
                                              width: cell * 0.08)),
                                    )
                                  : FractionallySizedBox(
                                      widthFactor: 0.3,
                                      heightFactor: 0.3,
                                      child: Container(
                                          decoration: BoxDecoration(
                                              color: Brand.gold
                                                  .withValues(alpha: 0.8),
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                            BoxShadow(
                                                color: Brand.gold
                                                    .withValues(alpha: 0.6),
                                                blurRadius: 8)
                                          ])),
                                    ))
                              : (g.selected == null &&
                                      movable.contains(sq) &&
                                      Piece.owner(g.pos.board[sq]) == g.turn
                                  ? Align(
                                      alignment: Alignment.bottomCenter,
                                      child: Container(
                                          width: cell * 0.3,
                                          height: cell * 0.06,
                                          margin: EdgeInsets.only(
                                              bottom: cell * 0.04),
                                          decoration: BoxDecoration(
                                              color: Colors.white
                                                  .withValues(alpha: 0.55),
                                              borderRadius:
                                                  BorderRadius.circular(4))),
                                    )
                                  : null),
                        ),
                      ),
                    ),
                ],
              ),
            ]);
          })),
    );
  }
}
