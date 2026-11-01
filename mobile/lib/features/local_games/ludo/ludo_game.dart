import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/ui/components.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/services.dart';
import '../../../core/audio/game_audio.dart';
import '../../../core/ui/materials/materials.dart';
import '../../guess_person/models/gp_player.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_shell.dart' show ResultScope;
import '../widgets/pawn.dart';
import '../shell/game_hud.dart';
import '../shell/ticking_play.dart';
import '../widgets/dice.dart';
import 'ludo_logic.dart';

export 'ludo_logic.dart';

/// Ludo: everyone for themselves.
final ludoInfo = _ludo(teams: false);

/// Ludo 2 vs 2 (in rooms as its own game; on one phone it's the TEAMS switch on Ludo).
final ludoTeamsInfo = _ludo(teams: true);

LocalGameInfo _ludo({required bool teams}) => LocalGameInfo(
      id: teams ? 'ludo_teams' : 'ludo',
      title: teams ? 'Ludo 2 vs 2' : 'Ludo',
      emoji: teams ? '🤝' : '🎲',
      color: const Color(0xFF1E7BE0),
      tagline: teams
          ? 'Team up with your partner across the board!'
          : 'Race all four tokens home!',
      rules: [
        'Roll a 6 to bring a token out of your base. Move round the board and up your coloured path to the centre.',
        'Land on a rival token to send it back to base (not on ★ safe squares).',
        'A 6, a capture or getting a token home gives you another roll. Three 6s in a row lose your turn.',
        if (!teams)
          'First to bring all four tokens home wins. 2 to 4 players. With 4 players you can play in teams.',
        if (teams)
          'Teams: Player 1 + 3 against Player 2 + 4. Partners never capture each other.',
        if (teams)
          'All your tokens home? Your turns now move your partner\'s. Both partners home and the team wins!',
      ],
      scoreUnit: 'wins',
      splitScreen: false,
      minPlayers: teams ? 4 : 2,
      maxPlayers: 4,
      teamVariant: teams ? null : ludoTeamsInfo,
      bot: botFor<LudoLogic>((g, b, now) {
        if (g.finished || g.turn != b.seat) return;
        // Slow enough to watch: a roll, a pause, then the token walks (about 0.2 s a square).
        if (!b.thinkFirst((g.rolls, g.phase), now, 1100, 1800)) return;
        if (g.phase == LudoPhase.roll) {
          g.roll();
          return;
        }
        final moves = g.movable;
        if (moves.isEmpty) return;
        final r = g.lastRoll!;
        final me =
            g.mover; // the bot's tokens, or its partner's once its own are home
        int value(int t) {
          final p = g.tokens[me][t];
          final np = p == -1 ? 0 : p + r;
          final cell = g.trackIndex(me, np);
          var v = np; // further along is better
          if (cell != null && !LudoLogic.safeCells.contains(cell)) {
            for (var o = 0; o < g.players; o++) {
              if (o != me &&
                  !g.sameTeam(o, me) &&
                  g.tokens[o].any((x) => g.trackIndex(o, x) == cell))
                v += 200; // capture!
            }
          }
          if (np == LudoLogic.home) v += 150;
          if (p == -1) v += 100;
          if (cell != null && LudoLogic.safeCells.contains(cell)) v += 40;
          return v + b.rng.nextInt(10);
        }

        g.move(moves.reduce((a, c) => value(a) >= value(c) ? a : c));
      }),
      online: RelaySpec<LudoLogic>(
        create: (n) => LudoLogic(players: n, teams: teams),
        save: (g) => {
          'tokens': [for (final t in g.tokens) ...t],
          'turn': g.turn,
          'phase': g.phase.index,
          'roll': g.lastRoll,
          'rolls': g.rolls,
          'sixes': g.sixesInARow,
          'winner': g.winner,
          'msg': g.message,
        },
        load: (g, s, me) {
          final t = ints(s['tokens']);
          for (var p = 0; p < g.players; p++) {
            g.tokens[p].setAll(
                0,
                t.sublist(
                    p * LudoLogic.tokensEach, (p + 1) * LudoLogic.tokensEach));
          }
          g.turn = asInt(s['turn']);
          g.phase = LudoPhase.values[asInt(s['phase'])];
          g.lastRoll = nInt(s['roll']);
          g.rolls = asInt(s['rolls']);
          g.sixesInARow = asInt(s['sixes']);
          g.winner = nInt(s['winner']);
          g.message = s['msg'] as String;
        },
        apply: (g, from, name, a) {
          if (from != g.turn) return;
          if (name == 'roll') g.roll();
          if (name == 'move') g.move(asInt(a[0]));
        },
        view: (context, g, players, me) => _LudoTable(players: players, g: g),
      ),
      play: (players, onFinished) => TickingPlay<LudoLogic>(
        create: () => LudoLogic(players: players.length, teams: teams),
        onFinished: onFinished,
        builder: (context, g) => _LudoTable(players: players, g: g),
      ),
    );

class _LudoTable extends StatelessWidget {
  final List<GpPlayer> players;
  final LudoLogic g;
  const _LudoTable({required this.players, required this.g});

  int _home(int i) => g.tokens[i].where((t) => t == LudoLogic.home).length;

  @override
  Widget build(BuildContext context) {
    final current = players[g.turn];
    final mover = players[g.mover];
    // Results: each player's tokens home.
    ResultScope.of(context)
      ?..subtitle = g.winner == null
          ? null
          : (g.teams ? 'Both partners home' : 'All four tokens home')
      ..detail = (context, i) => Pips(
          filled: _home(i),
          total: LudoLogic.tokensEach,
          color: players[i].color,
          size: 11);
    return MomentWatcher<String>(
      value: '${g.rolls}|${g.message}',
      onChange: (fx, _, now) {
        final m = g.message;
        if (m.contains('Captured')) {
          keyMoment(fx, 'CAPTURED!',
              sub: 'Roll again',
              sound: 'hit',
              buzz: HapticWeight.heavy,
              shake: true);
        } else if (m.contains('All home')) {
          keyMoment(fx, 'ALL HOME!',
              sub: 'Now move your partner\'s tokens', sound: 'coin');
        } else if (m.contains('Token home')) {
          keyMoment(fx, 'HOME!',
              sub: 'Roll again', sound: 'coin', confetti: true);
        } else if (m.contains('Three 6s')) {
          keyMoment(fx, 'TURN LOST',
              sub: 'Three 6s in a row',
              sound: 'lose',
              color: StatusColors.danger);
        } else if (m.startsWith('Rolled a 6') ||
            m.startsWith('No moves. Roll again')) {
          fx?.pop('ROLL AGAIN');
        }
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.s, Space.xs, Space.s, Space.m),
        child: Column(children: [
          ScoreHud(
            title: g.teams ? 'Ludo 2 vs 2' : 'Ludo',
            state: g.finished
                ? 'Game over'
                : (g.phase == LudoPhase.move
                    ? 'Move ${g.lastRoll}'
                    : '${current.name}: roll'),
            players: players,
            turn: g.finished ? null : g.turn,
            score: (i) => '${_home(i)}',
            tag: (i) => g.teams
                ? (i.isEven ? 'TEAM A' : 'TEAM B')
                : (i == g.turn && !g.finished
                    ? (g.phase == LudoPhase.move ? 'MOVE' : 'ROLL')
                    : null),
            detail: (i, compact) => Pips(
                filled: _home(i),
                total: LudoLogic.tokensEach,
                color: players[i].color,
                size: compact ? 7 : 10),
          ),
          const SizedBox(height: Space.s),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: Semantics(
                  label:
                      'Ludo board. ${current.name} to ${g.phase == LudoPhase.move ? 'move ${g.lastRoll}' : 'roll'}',
                  child: BoardFrame(
                      child: RepaintBoundary(
                          child: _Board(players: players, g: g))),
                ),
              ),
            ),
          ),
          const SizedBox(height: Space.s),
          DiceTray(
            message: g.message,
            player: current,
            turnText: g.phase == LudoPhase.move
                ? '${current.name}: move ${g.lastRoll}${g.mover != g.turn ? ' for ${mover.name}' : ''}'
                : '${possessive(current.name)} roll',
            dice: RollingDice(
              value: g.lastRoll ?? 6,
              rollId: g.rolls,
              color: current.color,
              size: 60,
              onTap: g.phase == LudoPhase.roll
                  ? () {
                      haptic(HapticWeight.medium);
                      GameAudio.sfx('throw');
                      g.roll();
                    }
                  : null,
            ),
          ),
        ]),
      ),
    );
  }
}

class _Board extends StatefulWidget {
  final List<GpPlayer> players;
  final LudoLogic g;
  const _Board({required this.players, required this.g});

  @override
  State<_Board> createState() => _BoardState();
}

/// Tokens walk to their new square one square at a time, so everyone can follow a move.
/// A captured token goes back to base once the attacker has landed.
class _BoardState extends State<_Board> {
  static const stepMs = 200;
  static const _baseOrigins = [(0, 0), (9, 0), (9, 9), (0, 9)];
  static const _homeOffsets = [
    Offset(-0.35, 0),
    Offset(0, -0.35),
    Offset(0.35, 0),
    Offset(0, 0.35)
  ];

  LudoLogic get g => widget.g;
  List<GpPlayer> get players => widget.players;
  late List<List<int>> shown = [for (final t in g.tokens) List.of(t)];
  Timer? _timer;

  @override
  void didUpdateWidget(_Board old) {
    super.didUpdateWidget(old);
    if (shown.length != g.tokens.length)
      shown = [for (final t in g.tokens) List.of(t)];
    _walk();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool get _settled {
    for (var p = 0; p < g.tokens.length; p++) {
      for (var t = 0; t < LudoLogic.tokensEach; t++) {
        if (shown[p][t] != g.tokens[p][t]) return false;
      }
    }
    return true;
  }

  void _walk() {
    if (_timer != null || _settled) return;
    _timer = Timer.periodic(const Duration(milliseconds: stepMs), (_) {
      if (!mounted) return;
      setState(_step);
      if (_settled) {
        _timer?.cancel();
        _timer = null;
      }
    });
  }

  /// One step: walking tokens move a square; sent-home tokens wait for the walkers to land.
  void _step() {
    var walking = false;
    for (var p = 0; p < g.tokens.length; p++) {
      for (var t = 0; t < LudoLogic.tokensEach; t++) {
        final want = g.tokens[p][t], now = shown[p][t];
        if (want > now) {
          shown[p][t] = now +
              1; // out of base onto the start square, then square by square
          walking = true;
        } else if (want < now && want >= 0) {
          shown[p][t] =
              want; // (only if the state jumped, e.g. online catching up)
        }
      }
    }
    if (walking) return;
    for (var p = 0; p < g.tokens.length; p++) {
      for (var t = 0; t < LudoLogic.tokensEach; t++) {
        if (g.tokens[p][t] == -1 && shown[p][t] != -1)
          shown[p][t] = -1; // captured: back to base
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _walk();
    final seatColors = List<Color?>.filled(4, null);
    for (var p = 0; p < players.length; p++) {
      seatColors[g.seats[p]] = players[p].color;
    }
    return LayoutBuilder(builder: (context, c) {
      final s = c.maxWidth / 15;
      // Where each token sits, in cell units (centre).
      final placed = <(int, int, Offset)>[];
      for (var p = 0; p < players.length; p++) {
        final seat = g.seats[p];
        for (var t = 0; t < LudoLogic.tokensEach; t++) {
          final prog = shown[p][t];
          Offset at;
          if (prog == -1) {
            final (bx, by) = _baseOrigins[seat];
            at = Offset(bx + 2.0 + (t % 2) * 2, by + 2.0 + (t ~/ 2) * 2);
          } else if (prog == LudoLogic.home) {
            at = const Offset(7.5, 7.5) +
                _homeOffsets[seat] * 2.2 +
                Offset((t - 1.5) * 0.18, (t - 1.5) * 0.18);
          } else {
            final (col, row) = g.squareOf(p, prog)!;
            at = Offset(col + 0.5, row + 0.5);
          }
          placed.add((p, t, at));
        }
      }
      // Spread tokens sharing a square.
      final widgets = <Widget>[], onTop = <Widget>[];
      for (final (p, t, at) in placed) {
        final same = placed.where((o) => (o.$3 - at).distance < 0.01).toList();
        final k = same.indexWhere((o) => o.$1 == p && o.$2 == t);
        final spread = same.length > 1 && shown[p][t] >= 0
            ? Offset(cos(k * 2 * pi / same.length),
                    sin(k * 2 * pi / same.length)) *
                0.22
            : Offset.zero;
        final pos = (at + spread) * s;
        final movable = g.canMove(p, t);
        final moving = shown[p][t] != g.tokens[p][t];
        final size = s *
            (shown[p][t] == LudoLogic.home
                ? 0.55
                : (moving ? 0.95 : 0.8)); // a walking token is lifted a little
        (movable || moving ? onTop : widgets).add(AnimatedPositioned(
          key: ValueKey('tok$p-$t'),
          duration: const Duration(milliseconds: stepMs - 30),
          curve: Curves.easeOut,
          left: pos.dx - size / 2,
          top: pos.dy - size / 2,
          width: size,
          height: size,
          child: Semantics(
            button: movable,
            label: '${players[p].name} token ${t + 1}',
            child: GestureDetector(
              onTap: movable
                  ? () {
                      HapticFeedback.selectionClick().ignore();
                      g.move(t);
                    }
                  : null,
              child: _Pawn(
                  color: players[p].color,
                  seat: PlayerPalette.indexOf(players[p].color) ?? p,
                  glow: movable),
            ),
          ),
        ));
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(children: [
          Positioned.fill(
              child: RepaintBoundary(
                  child: CustomPaint(painter: _LudoPainter(seatColors)))),
          ...widgets,
          ...onTop, // movable tokens above the rest so they're easy to tap
        ]),
      );
    });
  }
}

/// A glossy dome token: the seat colour with a rim, a shadow, and the player's shape on top
/// so tokens never differ by colour alone. Movable tokens get a gold ring.
class _Pawn extends StatelessWidget {
  final Color color;
  final int seat;
  final bool glow;
  const _Pawn({required this.color, required this.seat, required this.glow});
  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: PawnPainter(color, seat, glow: glow));
}

/// The board: a wood table with cream inlaid squares, seat-coloured bases and home paths,
/// drawn star safe squares and a trophy at the centre.
class _LudoPainter extends CustomPainter {
  final List<Color?> seatColors;
  _LudoPainter(this.seatColors);

  static const _cream = Color(0xFFF6EBD2), _creamLine = Color(0x33704A20);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 15;
    Color seat(int i) => seatColors[i] ?? const Color(0xFF9A9AB0);
    Rect cell(int c, int r) =>
        Rect.fromLTWH(c * s, r * s, s, s).deflate(s * 0.04);
    RRect tile(int c, int r) =>
        RRect.fromRectAndRadius(cell(c, r), Radius.circular(s * 0.14));
    const WoodPainter(radius: 0).paint(canvas, size);
    // Bases: seat colour with a cream yard and four token spots.
    const origins = [(0, 0), (9, 0), (9, 9), (0, 9)];
    for (var i = 0; i < 4; i++) {
      final (bx, by) = origins[i];
      final base = RRect.fromRectAndRadius(
          Rect.fromLTWH(bx * s, by * s, 6 * s, 6 * s).deflate(s * 0.12),
          Radius.circular(s * 0.5));
      canvas.drawRRect(
          base,
          Paint()
            ..shader = LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(seat(i), Colors.white, 0.12)!,
                  Color.lerp(seat(i), Colors.black, 0.18)!
                ]).createShader(base.outerRect));
      final yard = RRect.fromRectAndRadius(
          base.outerRect.deflate(s * 0.75), Radius.circular(s * 0.45));
      canvas.drawRRect(yard, Paint()..color = _cream);
      for (var t = 0; t < 4; t++) {
        final c =
            Offset((bx + 2.0 + (t % 2) * 2) * s, (by + 2.0 + (t ~/ 2) * 2) * s);
        canvas.drawCircle(
            c, s * 0.6, Paint()..color = seat(i).withValues(alpha: 0.3));
        canvas.drawCircle(
            c,
            s * 0.6,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = s * 0.06
              ..color = seat(i).withValues(alpha: 0.7));
      }
    }
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = _creamLine;
    // Track squares, inlaid.
    for (var i = 0; i < 52; i++) {
      final (c, r) = LudoLogic.track[i];
      final startSeat = i % 13 == 0 ? i ~/ 13 : null;
      canvas.drawRRect(tile(c, r),
          Paint()..color = startSeat != null ? seat(startSeat) : _cream);
      canvas.drawRRect(tile(c, r), edge);
      if (LudoLogic.safeCells.contains(i))
        _star(canvas, cell(c, r).center, s * 0.32,
            startSeat != null ? Colors.white : const Color(0xFFD9A441));
    }
    // Home paths.
    for (var i = 0; i < 4; i++) {
      for (final (c, r) in LudoLogic.homeColumns[i]) {
        canvas.drawRRect(tile(c, r), Paint()..color = seat(i));
      }
    }
    // Centre: four triangles pointing in, a cream disc and a drawn trophy.
    final centre = Offset(7.5 * s, 7.5 * s);
    final corners = [
      Offset(6 * s, 6 * s),
      Offset(9 * s, 6 * s),
      Offset(9 * s, 9 * s),
      Offset(6 * s, 9 * s)
    ];
    // Triangle i sits on the side facing seat i's home column: left, top, right, bottom.
    final sides = [
      (corners[3], corners[0]),
      (corners[0], corners[1]),
      (corners[1], corners[2]),
      (corners[2], corners[3])
    ];
    for (var i = 0; i < 4; i++) {
      final (a, b) = sides[i];
      canvas.drawPath(
          Path()
            ..moveTo(a.dx, a.dy)
            ..lineTo(b.dx, b.dy)
            ..lineTo(centre.dx, centre.dy)
            ..close(),
          Paint()..color = seat(i));
    }
    canvas.drawCircle(centre, s * 0.55, Paint()..color = _cream);
    paintIcon(canvas, GameIcons.trophy,
        Rect.fromCircle(center: centre, radius: s * 0.4),
        color: Brand.gold);
  }

  void _star(Canvas canvas, Offset c, double r, Color color) {
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final rr = i.isEven ? r : r * 0.45;
      final a = -pi / 2 + i * pi / 5;
      final pt = c + Offset(cos(a) * rr, sin(a) * rr);
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(p..close(), Paint()..color = color);
    canvas.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.12
          ..color = const Color(0x55000000));
  }

  @override
  bool shouldRepaint(_LudoPainter old) =>
      !listEquals(old.seatColors, seatColors);
}
