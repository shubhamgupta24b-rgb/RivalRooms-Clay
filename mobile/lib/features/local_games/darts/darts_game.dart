import 'dart:math';
import 'package:flutter/material.dart';
import '../../guess_person/models/gp_player.dart';
import '../../../core/audio/game_audio.dart';
import '../../../core/ui/components.dart';
import '../shell/game_hud.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/local_game_shell.dart' show ResultScope;
import '../shell/ticking_play.dart';

/// One dart on the board: where it landed (board units, radius 1 = outer edge) and its score.
class Dart {
  final Offset at;
  final int points;
  final String label; // "T20", "BULL", "MISS"
  const Dart(this.at, this.points, this.label);
}

enum DartsPhase { aim, flying, turnEnd }

/// Darts for 2-4 players taking turns on one phone. The aim drifts around the board; tap to
/// throw where it is. Three darts a turn, [rounds] rounds, highest total wins.
class DartsLogic extends LocalGameLogic {
  static const order = [
    20,
    1,
    18,
    4,
    13,
    6,
    10,
    15,
    2,
    17,
    3,
    19,
    7,
    16,
    8,
    11,
    14,
    9,
    12,
    5
  ];
  // Ring edges as a fraction of the board radius (a little wider than a real board, for fingers).
  static const bull = 0.07,
      outerBull = 0.15,
      trebleIn = 0.54,
      trebleOut = 0.62,
      doubleIn = 0.91;

  final int players, rounds;
  final List<int> total;
  final Random _rng;
  int turn = 0, round = 0;
  final List<Dart> darts = []; // this turn's darts
  DartsPhase phase = DartsPhase.aim;
  int _now = 0, _phaseUntil = 0, _aimStart = 0;
  Offset? _target;
  int throws = 0; // counts every throw, so the view knows when one lands
  Offset? shownAim; // online guests: the aim as the host last saw it

  DartsLogic({this.players = 2, this.rounds = 5, Random? random})
      : total = List.filled(players, 0),
        _rng = random ?? Random();

  @override
  bool get finished => round >= rounds;
  @override
  List<int> get scores => total;

  /// Where the aim is now: a slow wandering loop that sweeps the whole board.
  Offset get aim {
    if (shownAim case final a?) return a;
    final t = (_now - _aimStart) / 1000;
    final speed = 1 + round * 0.12; // a little faster each round
    return Offset(0.62 * sin(t * 1.7 * speed + turn),
        0.62 * sin(t * 2.3 * speed + 0.7 * turn) * cos(t * 0.6));
  }

  static Dart score(Offset p) {
    final d = p.distance;
    if (d <= bull) return Dart(p, 50, 'BULL');
    if (d <= outerBull) return Dart(p, 25, '25');
    if (d > 1) return Dart(p, 0, 'MISS');
    // Angle clockwise from straight up, in 20 slices with 20 at the top.
    final a = (atan2(p.dx, -p.dy) + 2 * pi + pi / 20) % (2 * pi);
    final n = order[(a / (2 * pi / 20)).floor() % 20];
    if (d >= trebleIn && d <= trebleOut) return Dart(p, n * 3, 'T$n');
    if (d >= doubleIn) return Dart(p, n * 2, 'D$n');
    return Dart(p, n, '$n');
  }

  @override
  void update(int elapsedMs) {
    _now = elapsedMs;
    if (phase == DartsPhase.flying && _now >= _phaseUntil) {
      final d = score(_target!);
      darts.add(d);
      total[turn] += d.points;
      throws++;
      if (darts.length == 3) {
        phase = DartsPhase.turnEnd;
        _phaseUntil = _now + 1300;
      } else {
        phase = DartsPhase.aim;
      }
      notifyListeners();
    } else if (phase == DartsPhase.turnEnd && _now >= _phaseUntil) {
      darts.clear();
      turn = (turn + 1) % players;
      if (turn == 0) round++;
      phase = DartsPhase.aim;
      _aimStart = _now;
      notifyListeners();
    } else if (phase == DartsPhase.aim) {
      notifyListeners(); // the aim moves every frame
    }
  }

  void throwDart(int player) {
    if (forward('throw', [player])) return;
    if (finished || phase != DartsPhase.aim || player != turn) return;
    // A small wobble of the hand.
    final wobble = Offset(
        (_rng.nextDouble() - 0.5) * 0.06, (_rng.nextDouble() - 0.5) * 0.06);
    _target = aim + wobble;
    phase = DartsPhase.flying;
    _phaseUntil = _now + 220;
    notifyListeners();
  }
}

final dartsInfo = LocalGameInfo(
  id: 'darts',
  title: 'Darts',
  emoji: '🎯',
  color: const Color(0xFF2E7D5B),
  tagline: 'Time your throw, hit the treble 20!',
  rules: const [
    'The aim drifts around the board. Tap anywhere to throw your dart where it is.',
    'Outer thin ring doubles the number, inner thin ring trebles it. Bullseye scores 50.',
    'Three darts each turn, five rounds. Highest total wins. 2 to 4 players take turns.',
  ],
  scoreUnit: 'points',
  splitScreen: false,
  maxPlayers: 4,
  bot: botFor<DartsLogic>((g, b, now) {
    if (g.finished || g.turn != b.seat || g.phase != DartsPhase.aim) return;
    if (!b.thinkFirst((g.round, g.turn, g.darts.length), now, 500, 900)) return;
    // Wait for a good moment (near the bull or the top), but don't wait forever.
    final a = g.aim;
    final good = a.distance < 0.2 || (a.dy < -0.45 && a.dx.abs() < 0.12);
    if (good || b.chance(0.012)) g.throwDart(b.seat);
  }),
  online: RelaySpec<DartsLogic>(
    create: (n) => DartsLogic(players: n),
    save: (g) => {
      'total': g.total,
      'turn': g.turn,
      'round': g.round,
      'darts': [
        for (final d in g.darts) [d.at.dx, d.at.dy, d.points, d.label]
      ],
      'phase': g.phase.index,
      'throws': g.throws,
      'aim': [g.aim.dx, g.aim.dy],
    },
    load: (g, s, me) {
      g.total.setAll(0, ints(s['total']));
      g.turn = asInt(s['turn']);
      g.round = asInt(s['round']);
      g.darts
        ..clear()
        ..addAll([
          for (final d in s['darts'] as List)
            Dart(Offset(asDouble(d[0]), asDouble(d[1])), asInt(d[2]), '${d[3]}')
        ]);
      g.phase = DartsPhase.values[asInt(s['phase'])];
      g.throws = asInt(s['throws']);
      final a = doubles(s['aim']);
      g.shownAim = Offset(a[0], a[1]);
    },
    apply: (g, from, name, a) {
      if (name == 'throw' && asInt(a[0]) == from) g.throwDart(from);
    },
    view: (context, g, players, me) =>
        _DartsView(g: g, players: players, me: me),
  ),
  play: (players, onFinished) => TickingPlay<DartsLogic>(
    create: () => DartsLogic(players: players.length),
    onFinished: onFinished,
    builder: (context, g) => _DartsView(g: g, players: players),
  ),
);

class _DartsView extends StatelessWidget {
  final DartsLogic g;
  final List<GpPlayer> players;
  final int? me; // online: only this phone's player throws from here
  const _DartsView({required this.g, required this.players, this.me});

  @override
  Widget build(BuildContext context) {
    final current = players[g.turn];
    ResultScope.of(context)?.subtitle =
        g.finished ? '${g.rounds} rounds, 3 darts each' : null;
    final turnTotal = g.darts.fold(0, (a, d) => a + d.points);
    return MomentWatcher<int>(
      value: g.throws,
      onChange: (fx, _, __) {
        final d = g.darts.lastOrNull;
        if (d == null) return;
        if (d.label == 'BULL') {
          keyMoment(fx, 'BULLSEYE!', sub: '+50', sound: 'coin', confetti: true);
        } else if (d.label.startsWith('T') && d.points >= 45) {
          keyMoment(fx, 'TREBLE ${d.points ~/ 3}!',
              sub: '+${d.points}', sound: 'coin');
        } else if (d.points == 0) {
          fx?.pop('MISS', color: Colors.white);
          GameAudio.sfx('lose');
        } else {
          fx?.pop('+${d.points}');
          GameAudio.sfx('hit');
          haptic(HapticWeight.medium);
        }
      },
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) {
          if (me != null ? me != g.turn : BotScope.isBot(context, g.turn))
            return;
          g.throwDart(g.turn);
        },
        child: Padding(
          padding:
              const EdgeInsets.fromLTRB(Space.s, Space.xs, Space.s, Space.m),
          child: Column(children: [
            ScoreHud(
              title: 'Darts',
              state: g.finished
                  ? 'Game over'
                  : 'Round ${g.round + 1} of ${g.rounds}: ${possessive(current.name)} throw',
              players: players,
              turn: g.finished ? null : g.turn,
              score: (i) => '${g.total[i]}',
              tag: (i) => !g.finished && i == g.turn ? 'THROWING' : null,
            ),
            const SizedBox(height: Space.s),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Semantics(
                    label:
                        'Dartboard. ${current.name} has thrown ${g.darts.length} of 3 darts. Tap to throw.',
                    child: RepaintBoundary(
                        child: CustomPaint(
                            painter: _BoardPainter(
                                g.darts,
                                g.phase == DartsPhase.aim && !g.finished
                                    ? g.aim
                                    : null,
                                current.color))),
                  ),
                ),
              ),
            ),
            const SizedBox(height: Space.s),
            FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  for (var k = 0; k < 3; k++)
                    Container(
                      width: 72,
                      height: 40,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      decoration: Skin.surface(
                          tint: k < g.darts.length ? current.color : null,
                          ring: k == g.darts.length && !g.finished
                              ? Brand.gold
                              : null,
                          radius: Radii.chip,
                          depth: 0.6),
                      child: Text(k < g.darts.length ? g.darts[k].label : '-',
                          style: const TextStyle(
                              fontFamily: Fonts.display,
                              fontSize: 18,
                              color: Colors.white)),
                    ),
                  const SizedBox(width: 8),
                  Text('= $turnTotal',
                      style: const TextStyle(
                          fontFamily: Fonts.display,
                          fontSize: 22,
                          color: Colors.white)),
                ])),
            const SizedBox(height: Space.xs),
            Text(
                g.finished
                    ? ''
                    : (me != null && me != g.turn
                        ? 'Waiting for ${current.name}'
                        : 'Tap anywhere to throw'),
                style: const TextStyle(
                    fontFamily: Fonts.body,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: NeonPalette.label)),
          ]),
        ),
      ),
    );
  }
}

/// The dartboard on a cork surround, the darts in it and the aim ring.
class _BoardPainter extends CustomPainter {
  final List<Dart> darts;
  final Offset? aim;
  final Color color;
  _BoardPainter(this.darts, this.aim, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final outer = size.width / 2;
    final r = outer * 0.84; // the scoring area; the rest is the number ring
    canvas.drawCircle(
        c + const Offset(0, 6), outer, Paint()..color = Colors.black38);
    canvas.drawCircle(c, outer, Paint()..color = const Color(0xFF1B1B1F));
    const cream = Color(0xFFF1E3C4),
        black = Color(0xFF26231F),
        red = Color(0xFFD23C3C),
        green = Color(0xFF2E8B57);
    const slice = 2 * pi / 20;
    void ring(double from, double to, Color Function(int i) col) {
      for (var i = 0; i < 20; i++) {
        final start = -pi / 2 - slice / 2 + i * slice;
        final path = Path()
          ..arcTo(
              Rect.fromCircle(center: c, radius: r * to), start, slice, true)
          ..arcTo(Rect.fromCircle(center: c, radius: r * from), start + slice,
              -slice, false)
          ..close();
        canvas.drawPath(path, Paint()..color = col(i));
      }
    }

    ring(DartsLogic.outerBull, 1, (i) => i.isEven ? black : cream);
    ring(DartsLogic.trebleIn, DartsLogic.trebleOut,
        (i) => i.isEven ? red : green);
    ring(DartsLogic.doubleIn, 1, (i) => i.isEven ? red : green);
    canvas.drawCircle(c, r * DartsLogic.outerBull, Paint()..color = green);
    canvas.drawCircle(c, r * DartsLogic.bull, Paint()..color = red);
    // Wire.
    final wire = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFFB8B8B8);
    for (final k in [
      DartsLogic.bull,
      DartsLogic.outerBull,
      DartsLogic.trebleIn,
      DartsLogic.trebleOut,
      DartsLogic.doubleIn,
      1.0
    ]) {
      canvas.drawCircle(c, r * k, wire);
    }
    // Numbers.
    for (var i = 0; i < 20; i++) {
      final a = -pi / 2 + i * slice;
      final tp = TextPainter(
        text: TextSpan(
            text: '${DartsLogic.order[i]}',
            style: TextStyle(
                fontSize: outer * 0.085,
                fontWeight: FontWeight.w900,
                color: Colors.white)),
        textDirection: TextDirection.ltr,
      )..layout();
      final at = c + Offset(cos(a), sin(a)) * (outer * 0.92);
      tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
    }
    // Darts: a flight and a shaft angled slightly, stuck where they landed.
    for (final d in darts) {
      final p = c + d.at * r;
      canvas.drawLine(
          p,
          p + Offset(outer * 0.07, outer * 0.11),
          Paint()
            ..strokeWidth = 3
            ..color = const Color(0xFFDADADA));
      final tail = p + Offset(outer * 0.07, outer * 0.11);
      final flight = Path()
        ..moveTo(tail.dx, tail.dy)
        ..lineTo(tail.dx + outer * 0.05, tail.dy + outer * 0.02)
        ..lineTo(tail.dx + outer * 0.02, tail.dy + outer * 0.06)
        ..close();
      canvas.drawPath(flight, Paint()..color = color);
      canvas.drawCircle(p, 3, Paint()..color = Colors.white);
    }
    if (aim case final a?) {
      final p = c + a * r;
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Brand.gold;
      canvas.drawCircle(
          p, outer * 0.07, Paint()..color = Brand.gold.withValues(alpha: 0.18));
      canvas.drawCircle(p, outer * 0.07, ring);
      canvas.drawLine(
          p - Offset(outer * 0.11, 0), p - Offset(outer * 0.04, 0), ring);
      canvas.drawLine(
          p + Offset(outer * 0.04, 0), p + Offset(outer * 0.11, 0), ring);
      canvas.drawLine(
          p - Offset(0, outer * 0.11), p - Offset(0, outer * 0.04), ring);
      canvas.drawLine(
          p + Offset(0, outer * 0.04), p + Offset(0, outer * 0.11), ring);
    }
  }

  @override
  bool shouldRepaint(_BoardPainter o) => true;
}
