import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/audio/game_audio.dart';
import '../../../core/ui/components.dart';
import '../../guess_person/models/gp_player.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/game_hud.dart';
import '../shell/local_game_shell.dart' show ResultScope;
import '../shell/ticking_play.dart';
import '../widgets/dice.dart';
import '../widgets/pawn.dart';

/// Classic Snakes & Ladders, 2-6 players. Roll, move, climb ladders, slide down snakes.
/// A 6 rolls again. You need the exact number to land on 100 (otherwise you stay put).
class SnakesLaddersLogic extends LocalGameLogic {
  static const ladders = {
    4: 14,
    9: 31,
    20: 38,
    28: 84,
    40: 59,
    51: 67,
    63: 81,
    71: 91
  };
  static const snakes = {
    17: 7,
    54: 34,
    62: 19,
    64: 60,
    87: 24,
    93: 73,
    95: 75,
    99: 78
  };
  final int players;
  final Random _random;
  final List<int> pos; // 0 = not on the board yet
  int turn = 0;
  int? lastRoll;
  int? winner;
  String message = 'Tap the dice to roll';
  int rolls = 0; // bumps on every roll, for the dice animation

  SnakesLaddersLogic({this.players = 2, Random? random})
      : _random = random ?? Random(),
        pos = List.filled(players, 0);

  @override
  bool get finished => winner != null;
  @override
  List<int> get scores =>
      [for (var i = 0; i < players; i++) winner == i ? 1 : 0];
  @override
  void update(int elapsedMs) {}

  /// Rolls for the current player (or uses [value], for tests) and moves them.
  int? roll([int? value]) {
    if (forward('roll', const [])) return null;
    if (finished) return null;
    final r = value ?? _random.nextInt(6) + 1;
    lastRoll = r;
    rolls++;
    final p = turn;
    final target = pos[p] + r;
    if (target > 100) {
      message = 'Need exactly ${100 - pos[p]} to finish';
    } else {
      var land = target;
      if (ladders.containsKey(land)) {
        message = '🪜 Ladder! Up from $land to ${ladders[land]}';
        land = ladders[land]!;
      } else if (snakes.containsKey(land)) {
        message = '🐍 Snake! Down from $land to ${snakes[land]}';
        land = snakes[land]!;
      } else {
        message = 'Moved to $land';
      }
      pos[p] = land;
      if (land == 100) {
        winner = p;
        message = 'Reached 100!';
        notifyListeners();
        return r;
      }
    }
    if (r == 6) {
      message += ' · Rolled 6, go again!';
    } else {
      turn = (turn + 1) % players;
    }
    notifyListeners();
    return r;
  }

  /// Grid position of square [n] (1-100): row 0 is the top. Rows snake left/right.
  static (int col, int row) cell(int n) {
    final i = n - 1;
    final rowFromBottom = i ~/ 10;
    final c = rowFromBottom.isEven ? i % 10 : 9 - i % 10;
    return (c, 9 - rowFromBottom);
  }
}

final snakesLaddersInfo = LocalGameInfo(
  id: 'snakes_ladders',
  title: 'Snakes & Ladders',
  emoji: '🐍',
  color: const Color(0xFF2EAA4F),
  tagline: 'Climb up, slide down, race to 100!',
  rules: const [
    'Take turns tapping the dice. Your token moves that many squares.',
    'Land at the foot of a ladder to climb up; land on a snake head and slide down.',
    'Rolling a 6 gives you another roll. You need the exact number to land on 100.',
  ],
  scoreUnit: 'wins',
  splitScreen: false,
  maxPlayers: 6,
  bot: botFor<SnakesLaddersLogic>((g, b, now) {
    if (g.finished || g.turn != b.seat) return;
    if (b.thinkFirst(g.rolls, now, 800, 1400)) g.roll();
  }),
  online: RelaySpec<SnakesLaddersLogic>(
    create: (n) => SnakesLaddersLogic(players: n),
    save: (g) => {
      'pos': g.pos,
      'turn': g.turn,
      'roll': g.lastRoll,
      'rolls': g.rolls,
      'winner': g.winner,
      'msg': g.message
    },
    load: (g, s, me) {
      g.pos.setAll(0, ints(s['pos']));
      g.turn = asInt(s['turn']);
      g.lastRoll = nInt(s['roll']);
      g.rolls = asInt(s['rolls']);
      g.winner = nInt(s['winner']);
      g.message = s['msg'] as String;
    },
    apply: (g, from, name, a) {
      if (name == 'roll' && from == g.turn) g.roll();
    },
    view: (context, g, players, me) => _SnlTable(players: players, g: g),
  ),
  play: (players, onFinished) => TickingPlay<SnakesLaddersLogic>(
    create: () => SnakesLaddersLogic(players: players.length),
    onFinished: onFinished,
    builder: (context, g) => _SnlTable(players: players, g: g),
  ),
);

class _SnlTable extends StatelessWidget {
  final List<GpPlayer> players;
  final SnakesLaddersLogic g;
  const _SnlTable({required this.players, required this.g});

  @override
  Widget build(BuildContext context) {
    final current = players[g.turn];
    ResultScope.of(context)?.subtitle =
        g.winner == null ? null : '${players[g.winner!].name} reached 100';
    return MomentWatcher<int>(
      value: g.rolls,
      onChange: (fx, _, __) {
        final m = g.message;
        if (m.contains('Ladder!')) {
          keyMoment(fx, 'LADDER!',
              sub: stripEmoji(m).replaceFirst('Ladder! ', ''), sound: 'jump');
        } else if (m.contains('Snake!')) {
          keyMoment(fx, 'SNAKE!',
              sub: stripEmoji(m).replaceFirst('Snake! ', ''),
              sound: 'lose',
              color: StatusColors.danger,
              buzz: HapticWeight.heavy,
              shake: true);
        } else if (g.lastRoll == 6 && !g.finished) {
          fx?.pop('ROLL AGAIN');
        }
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.s, Space.xs, Space.s, Space.m),
        child: Column(children: [
          ScoreHud(
            title: 'Snakes & Ladders',
            state: g.finished ? 'Game over' : '${current.name}: roll',
            players: players,
            turn: g.finished ? null : g.turn,
            score: (i) => '${g.pos[i]}',
            tag: (i) => i == g.turn && !g.finished ? 'ROLL' : null,
          ),
          const SizedBox(height: Space.s),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: Semantics(
                  label: 'Board. ${[
                    for (var i = 0; i < players.length; i++)
                      '${players[i].name} on ${g.pos[i]}'
                  ].join(', ')}',
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
            turnText: '${possessive(current.name)} roll',
            dice: RollingDice(
              value: g.lastRoll ?? 1,
              rollId: g.rolls,
              color: current.color,
              size: 60,
              onTap: g.finished
                  ? null
                  : () {
                      haptic(HapticWeight.medium);
                      GameAudio.sfx('throw');
                      g.roll();
                    },
            ),
          ),
        ]),
      ),
    );
  }
}

class _Board extends StatelessWidget {
  final List<GpPlayer> players;
  final SnakesLaddersLogic g;
  const _Board({required this.players, required this.g});
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final s = c.maxWidth / 10;
      final tokens = <Widget>[];
      for (var p = 0; p < players.length; p++) {
        final n = g.pos[p];
        if (n == 0) continue;
        final (col, row) = SnakesLaddersLogic.cell(n);
        // Fan out tokens sharing a square.
        final same = [
          for (var q = 0; q < players.length; q++)
            if (g.pos[q] == n) q
        ];
        final k = same.indexOf(p);
        final off = same.length == 1
            ? Offset.zero
            : Offset(cos(k * 2 * pi / same.length),
                    sin(k * 2 * pi / same.length)) *
                s *
                0.2;
        tokens.add(AnimatedPositioned(
          key: ValueKey('t$p'),
          duration: Motion.of(context, const Duration(milliseconds: 600)),
          curve: Curves.easeInOutCubic,
          left: col * s + s * 0.17 + off.dx,
          top: row * s + s * 0.12 + off.dy,
          width: s * 0.66,
          height: s * 0.66,
          child: CustomPaint(
              painter: PawnPainter(players[p].color,
                  PlayerPalette.indexOf(players[p].color) ?? p,
                  glow: p == g.turn && !g.finished)),
        ));
      }
      return Stack(children: [
        const Positioned.fill(
            child: RepaintBoundary(child: CustomPaint(painter: _SnlPainter()))),
        ...tokens,
      ]);
    });
  }
}

/// Paper board: alternating cream and pastel squares with Nunito numbers, wooden ladders
/// and patterned snakes with heads, eyes and tongues. The 100 square has a flag.
class _SnlPainter extends CustomPainter {
  const _SnlPainter();
  static const _cream = Color(0xFFFFF8EC);
  static const _pastels = [
    Color(0xFFFFE3B3),
    Color(0xFFD4F1D2),
    Color(0xFFD3E6FB),
    Color(0xFFF6D6E8),
    Color(0xFFE7DDF8)
  ];
  static const _ink = Color(0xFF5A4A3A);
  static const _snakes = [
    (Color(0xFF2EAA4F), Color(0xFF1B7A35)),
    (Color(0xFFE53935), Color(0xFF9E1F1C)),
    (Color(0xFF7B4DFF), Color(0xFF4B2BB0)),
    (Color(0xFFFF8A3D), Color(0xFFB85A1A)),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 10;
    Offset centre(int n) {
      final (c, r) = SnakesLaddersLogic.cell(n);
      return Offset((c + 0.5) * s, (r + 0.5) * s);
    }

    for (var n = 1; n <= 100; n++) {
      final (c, r) = SnakesLaddersLogic.cell(n);
      final rect = Rect.fromLTWH(c * s, r * s, s, s);
      canvas.drawRect(
          rect,
          Paint()
            ..color = (c + r).isEven
                ? _cream
                : _pastels[(n ~/ 10) % _pastels.length]);
      canvas.drawRect(
          rect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.6
            ..color = const Color(0x22704A20));
      if (n == 100) {
        paintIcon(
            canvas,
            GameIcons.flag,
            Rect.fromCenter(
                center: rect.center, width: s * 0.62, height: s * 0.62));
      } else {
        final tp = TextPainter(
          text: TextSpan(
              text: '$n',
              style: TextStyle(
                  fontFamily: Fonts.body,
                  color: _ink.withValues(alpha: 0.75),
                  fontSize: s * 0.24,
                  fontWeight: FontWeight.w900)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(c * s + s * 0.08, r * s + s * 0.04));
      }
    }
    // Ladders: two wooden rails with rungs and a soft shadow.
    SnakesLaddersLogic.ladders.forEach((from, to) {
      final a = centre(from), b = centre(to);
      final dir = b - a;
      final unit = dir / dir.distance;
      final normal = Offset(-unit.dy, unit.dx) * s * 0.18;
      final shadow = Paint()
        ..color = const Color(0x40000000)
        ..strokeWidth = s * 0.1
        ..strokeCap = StrokeCap.round;
      final rail = Paint()
        ..shader =
            LinearGradient(colors: const [Color(0xFFC68A4E), Color(0xFF8B5A2B)])
                .createShader(Rect.fromPoints(a, b))
        ..strokeWidth = s * 0.09
        ..strokeCap = StrokeCap.round;
      final rung = Paint()
        ..color = const Color(0xFFB07A42)
        ..strokeWidth = s * 0.065
        ..strokeCap = StrokeCap.round;
      final rungs = (dir.distance / (s * 0.42)).floor();
      for (final side in [normal, -normal]) {
        canvas.drawLine(a + side + const Offset(2, 3),
            b + side + const Offset(2, 3), shadow);
      }
      for (var i = 1; i < rungs; i++) {
        final p = a + dir * (i / rungs);
        canvas.drawLine(p + normal, p - normal, rung);
      }
      canvas.drawLine(a + normal, b + normal, rail);
      canvas.drawLine(a - normal, b - normal, rail);
    });
    // Snakes: a wavy body with a darker diamond pattern, a head with eyes and a tongue.
    var k = 0;
    SnakesLaddersLogic.snakes.forEach((head, tail) {
      final a = centre(head), b = centre(tail);
      final dir = b - a;
      final normal = Offset(-dir.dy, dir.dx) / dir.distance;
      final pts = <Offset>[];
      const steps = 32;
      for (var i = 0; i <= steps; i++) {
        final t = i / steps;
        pts.add(
            a + dir * t + normal * sin(t * pi * 3) * s * 0.35 * (1 - t * 0.5));
      }
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final p in pts.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      final (body, dark) = _snakes[k++ % _snakes.length];
      canvas.drawPath(
          path.shift(const Offset(2, 3)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * 0.2
            ..strokeCap = StrokeCap.round
            ..color = const Color(0x40000000));
      // Taper: thicker near the head.
      for (var i = 0; i < pts.length - 1; i++) {
        final w = s * (0.22 - 0.12 * i / pts.length);
        canvas.drawLine(
            pts[i],
            pts[i + 1],
            Paint()
              ..strokeWidth = w
              ..strokeCap = StrokeCap.round
              ..color = body);
        if (i.isEven && i > 1)
          canvas.drawCircle(pts[i], w * 0.22, Paint()..color = dark);
      }
      final fwd = (pts[0] - pts[1]) / (pts[0] - pts[1]).distance;
      final side = Offset(-fwd.dy, fwd.dx);
      canvas.drawOval(
          Rect.fromCenter(center: a, width: s * 0.42, height: s * 0.42),
          Paint()..color = body);
      canvas.drawLine(
          a + fwd * s * 0.2,
          a + fwd * s * 0.36,
          Paint()
            ..color = const Color(0xFFE53935)
            ..strokeWidth = s * 0.035
            ..strokeCap = StrokeCap.round);
      for (final sgn in [-1.0, 1.0]) {
        final e = a + side * sgn * s * 0.09 + fwd * s * 0.05;
        canvas.drawCircle(e, s * 0.055, Paint()..color = Colors.white);
        canvas.drawCircle(
            e + fwd * s * 0.012, s * 0.028, Paint()..color = Colors.black);
      }
    });
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
