import 'dart:math';
import 'package:flutter/material.dart';
import '../../guess_person/models/gp_player.dart';
import '../../../core/audio/game_audio.dart';
import '../../../core/ui/components.dart';
import '../shell/game_hud.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/local_game_shell.dart' show PauseButton, ResultScope;
import '../shell/ticking_play.dart';

enum CupPhase { aim, flying, result }

/// Cup pong for two at opposite ends of a table. Table units: x 0..1 across, y 0..[length]
/// from player 2's end (top) to player 1's end (bottom). Each player defends six cups at
/// their end and throws at the other end. Drag back from your end to aim, release to throw;
/// a cup hit means another throw. Clear all six of your rival's cups to win.
class CupPongLogic extends LocalGameLogic {
  static const length = 1.6, cupR = 0.065;
  static const flightMs = 650;
  final Random _rng;
  final List<List<Offset>> cups; // cups[p]: the cups standing at player p's end
  int turn = 0;
  CupPhase phase = CupPhase.aim;
  Offset? from, to; // the flight
  bool? lastHit;
  int throws = 0;
  int _now = 0, _phaseStart = 0;

  CupPongLogic({Random? random})
      : _rng = random ?? Random(),
        cups = [_rack(true), _rack(false)];

  /// Six cups in a triangle, point toward the middle of the table.
  static List<Offset> _rack(bool bottom) {
    final out = <Offset>[];
    const d = cupR * 2.1;
    for (var row = 0; row < 3; row++) {
      for (var k = 0; k <= row; k++) {
        final x = 0.5 + (k - row / 2) * d;
        final y = bottom
            ? length - 0.12 - (2 - row) * d * 0.9
            : 0.12 + (2 - row) * d * 0.9;
        out.add(Offset(x, y));
      }
    }
    return out;
  }

  /// Where a throw starts: the thrower's end, centred.
  static Offset launch(int player) =>
      Offset(0.5, player == 0 ? length - 0.04 : 0.04);

  double? shownFlight; // online guests: the flight as the host last saw it
  double get flight =>
      shownFlight ??
      (phase == CupPhase.flying
          ? ((_now - _phaseStart) / flightMs).clamp(0.0, 1.0)
          : 1.0);

  int? get winner => cups[1].isEmpty ? 0 : (cups[0].isEmpty ? 1 : null);
  @override
  bool get finished => winner != null && phase != CupPhase.flying;
  @override
  List<int> get scores => [6 - cups[1].length, 6 - cups[0].length];

  @override
  void update(int elapsedMs) {
    _now = elapsedMs;
    if (phase == CupPhase.flying && _now - _phaseStart >= flightMs) {
      final target = cups[1 - turn];
      final hit = target.indexWhere((c) => (c - to!).distance < cupR * 0.95);
      lastHit = hit >= 0;
      if (hit >= 0) target.removeAt(hit);
      throws++;
      phase = CupPhase.result;
      _phaseStart = _now;
      notifyListeners();
    } else if (phase == CupPhase.result &&
        _now - _phaseStart >= 700 &&
        winner == null) {
      if (lastHit != true) turn = 1 - turn; // a hit throws again
      phase = CupPhase.aim;
      from = to = null;
      notifyListeners();
    } else if (phase == CupPhase.flying) {
      notifyListeners();
    }
  }

  /// Throws at the table point [aimX], [aimY]; the hand adds a little spread.
  void throwAt(int player, double aimX, double aimY) {
    if (forward('throw', [player, aimX, aimY])) return;
    if (finished || phase != CupPhase.aim || player != turn) return;
    final spread = Offset(
        (_rng.nextDouble() - 0.5) * 0.05, (_rng.nextDouble() - 0.5) * 0.05);
    from = launch(player);
    to = Offset(aimX.clamp(0.0, 1.0), aimY.clamp(0.0, length)) + spread;
    phase = CupPhase.flying;
    _phaseStart = _now;
    notifyListeners();
  }
}

final cupPongInfo = LocalGameInfo(
  id: 'cup_pong',
  title: 'Cup Pong',
  emoji: '🥤',
  color: const Color(0xFFD7263D),
  tagline: 'Sink the ball, clear their cups!',
  rules: const [
    'Sit at opposite ends. On your turn, drag back from your end of the table and let go to throw.',
    'Pull further to throw further; the ring shows where the ball will land.',
    'Sink a ball in a cup to remove it and throw again. Clear all six rival cups to win.',
  ],
  scoreUnit: 'cups',
  splitScreen: false,
  bot: botFor<CupPongLogic>((g, b, now) {
    if (g.finished || g.turn != b.seat || g.phase != CupPhase.aim) return;
    if (!b.thinkFirst(g.throws, now, 800, 1400)) return;
    final c = b.pick(g.cups[1 - b.seat]);
    final miss = 0.07;
    g.throwAt(b.seat, c.dx + (b.rng.nextDouble() - 0.5) * miss,
        c.dy + (b.rng.nextDouble() - 0.5) * miss);
  }),
  online: RelaySpec<CupPongLogic>(
    create: (n) => CupPongLogic(),
    save: (g) => {
      'cups': [
        for (final side in g.cups)
          [
            for (final c in side) [c.dx, c.dy]
          ]
      ],
      'turn': g.turn,
      'phase': g.phase.index,
      'from': g.from == null ? null : [g.from!.dx, g.from!.dy],
      'to': g.to == null ? null : [g.to!.dx, g.to!.dy],
      'hit': g.lastHit,
      'throws': g.throws,
      'f': g.flight,
    },
    load: (g, s, me) {
      final cups = s['cups'] as List;
      for (var p = 0; p < 2; p++) {
        g.cups[p]
          ..clear()
          ..addAll([
            for (final c in cups[p] as List)
              Offset(asDouble(c[0]), asDouble(c[1]))
          ]);
      }
      g.turn = asInt(s['turn']);
      g.phase = CupPhase.values[asInt(s['phase'])];
      Offset? pt(Object? v) =>
          v == null ? null : Offset(asDouble((v as List)[0]), asDouble(v[1]));
      g.from = pt(s['from']);
      g.to = pt(s['to']);
      g.lastHit = s['hit'] as bool?;
      g.throws = asInt(s['throws']);
      g.shownFlight = asDouble(s['f']);
    },
    apply: (g, from, name, a) {
      if (name == 'throw' && asInt(a[0]) == from)
        g.throwAt(from, asDouble(a[1]), asDouble(a[2]));
    },
    view: (context, g, players, me) =>
        _CupTable(g: g, players: players, me: me),
  ),
  play: (players, onFinished) => TickingPlay<CupPongLogic>(
    create: () => CupPongLogic(),
    onFinished: onFinished,
    builder: (context, g) => _CupTable(g: g, players: players),
  ),
);

class _CupTable extends StatefulWidget {
  final CupPongLogic g;
  final List<GpPlayer> players;
  final int?
      me; // online: this phone's player (player 2 sees the table turned round)
  const _CupTable({required this.g, required this.players, this.me});
  @override
  State<_CupTable> createState() => _CupTableState();
}

class _CupTableState extends State<_CupTable> {
  Offset? _dragStart, _dragNow; // in table units

  CupPongLogic get g => widget.g;

  /// Pulling back by d throws forward by about 2.4 d, mirrored for the top player.
  Offset? get _aim {
    if (_dragStart == null || _dragNow == null) return null;
    final pull = _dragStart! - _dragNow!;
    return CupPongLogic.launch(g.turn) + pull * 2.4;
  }

  @override
  Widget build(BuildContext context) {
    final players = widget.players;
    final current = players[g.turn];
    ResultScope.of(context)?.subtitle =
        g.finished ? 'All six cups cleared' : null;
    return MomentWatcher<int>(
      value: g.throws,
      onChange: (fx, _, __) {
        if (g.winner != null) {
          keyMoment(fx, 'ALL CUPS!',
              sub: '${players[g.winner!].name} wins',
              sound: 'win',
              confetti: true);
        } else if (g.lastHit == true) {
          keyMoment(fx, 'SPLASH!', sub: 'Throw again', sound: 'coin');
        } else {
          fx?.pop('MISS', color: Colors.white);
          GameAudio.sfx('pop');
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(Space.s),
        child: Column(children: [
          Row(children: [
            const PauseButton(),
            Expanded(
              child: Text(
                  g.finished
                      ? '${players[g.winner!].name} wins!'
                      : "${possessive(current.name)} throw",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: Fonts.display,
                      fontSize: 20,
                      color: Colors.white)),
            ),
            const SizedBox(width: kTouchTarget),
          ]),
          Expanded(
            child: LayoutBuilder(builder: (context, c) {
              // The table keeps its shape and fits the space.
              final scale = min(c.maxWidth, c.maxHeight / CupPongLogic.length);
              final w = scale, h = scale * CupPongLogic.length;
              Offset toTable(Offset p) => Offset(p.dx / scale, p.dy / scale);
              final mine = (widget.me != null
                      ? widget.me == g.turn
                      : !BotScope.isBot(context, g.turn)) &&
                  g.phase == CupPhase.aim &&
                  !g.finished;
              return Center(
                child: RotatedBox(
                    quarterTurns: widget.me == 1 ? 2 : 0,
                    child: SizedBox(
                      width: w,
                      height: h,
                      child: GestureDetector(
                        onPanStart: mine
                            ? (d) => setState(() => _dragStart =
                                _dragNow = toTable(d.localPosition))
                            : null,
                        onPanUpdate: mine
                            ? (d) => setState(
                                () => _dragNow = toTable(d.localPosition))
                            : null,
                        onPanEnd: mine
                            ? (_) {
                                final a = _aim;
                                setState(() => _dragStart = _dragNow = null);
                                if (a != null &&
                                    (a - CupPongLogic.launch(g.turn)).distance >
                                        0.1) {
                                  g.throwAt(g.turn, a.dx, a.dy);
                                  GameAudio.sfx('throw');
                                  haptic(HapticWeight.light);
                                }
                              }
                            : null,
                        child: Semantics(
                          label:
                              'Cup pong table. ${players[0].name} has ${g.cups[0].length} cups, ${players[1].name} has ${g.cups[1].length}. ${current.name} to throw: drag back and release.',
                          child: CustomPaint(
                              painter: _TablePainter(g, players, _aim, scale)),
                        ),
                      ),
                    )),
              );
            }),
          ),
        ]),
      ),
    );
  }
}

class _TablePainter extends CustomPainter {
  final CupPongLogic g;
  final List<GpPlayer> players;
  final Offset? aim;
  final double s;
  _TablePainter(this.g, this.players, this.aim, this.s);

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final table = RRect.fromRectAndRadius(r, Radius.circular(s * 0.05));
    canvas.drawRRect(
        table.shift(const Offset(0, 6)), Paint()..color = Colors.black45);
    canvas.drawRRect(
        table,
        Paint()
          ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF1F5FA8),
                Color(0xFF2A74C4),
                Color(0xFF1F5FA8)
              ]).createShader(r));
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 2;
    canvas.drawLine(
        Offset(0, size.height / 2), Offset(size.width, size.height / 2), line);
    canvas.drawLine(
        Offset(size.width / 2, 0),
        Offset(size.width / 2, size.height),
        line..color = Colors.white.withValues(alpha: 0.25));
    canvas.drawRRect(
        table,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = Colors.white);
    // Each player's end glows faintly in their colour, brighter on their turn.
    for (final p in [0, 1]) {
      final band = p == 0
          ? Rect.fromLTWH(0, size.height - s * 0.08, size.width, s * 0.08)
          : Rect.fromLTWH(0, 0, size.width, s * 0.08);
      canvas.drawRect(
          band,
          Paint()
            ..color = players[p]
                .color
                .withValues(alpha: g.turn == p && !g.finished ? 0.55 : 0.2));
    }
    // Cups, seen from above: a rim, the drink inside, a shine.
    for (final p in [0, 1]) {
      for (final c in g.cups[p]) {
        final at = c * s, rad = CupPongLogic.cupR * s;
        canvas.drawCircle(
            at + const Offset(0, 3), rad, Paint()..color = Colors.black38);
        canvas.drawCircle(at, rad, Paint()..color = const Color(0xFFE23B3B));
        canvas.drawCircle(
            at, rad * 0.78, Paint()..color = const Color(0xFF8A1E1E));
        canvas.drawCircle(at, rad * 0.7,
            Paint()..color = const Color(0xFFF2C14E).withValues(alpha: 0.85));
        canvas.drawCircle(
            at,
            rad,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = Colors.white.withValues(alpha: 0.9));
        canvas.drawCircle(at - Offset(rad * 0.3, rad * 0.3), rad * 0.18,
            Paint()..color = Colors.white.withValues(alpha: 0.5));
      }
    }
    // Aim line and landing ring while dragging.
    if (aim case final a?) {
      final start = CupPongLogic.launch(g.turn) * s,
          end = Offset(
                  a.dx.clamp(0.0, 1.0), a.dy.clamp(0.0, CupPongLogic.length)) *
              s;
      final dash = Paint()
        ..color = Colors.white.withValues(alpha: 0.8)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      for (var k = 0.0; k < 1; k += 0.08) {
        canvas.drawLine(Offset.lerp(start, end, k)!,
            Offset.lerp(start, end, min(1, k + 0.04))!, dash);
      }
      canvas.drawCircle(
          end,
          CupPongLogic.cupR * s,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = Brand.gold);
    }
    // The ball: rises and falls along its flight (bigger when higher), with its shadow.
    if (g.from != null && g.to != null) {
      final f = g.flight;
      final ground = Offset.lerp(g.from! * s, g.to! * s, f)!;
      final height = sin(pi * f) * s * 0.12;
      canvas.drawCircle(ground, s * 0.018, Paint()..color = Colors.black38);
      final ball = ground - Offset(0, height);
      final br = s * (0.02 + 0.012 * sin(pi * f));
      canvas.drawCircle(
          ball,
          br,
          Paint()
            ..shader = RadialGradient(
                    center: const Alignment(-0.3, -0.4),
                    colors: const [Colors.white, Color(0xFFE8E2D0)])
                .createShader(Rect.fromCircle(center: ball, radius: br)));
    } else if (g.phase == CupPhase.aim && !g.finished) {
      final at = CupPongLogic.launch(g.turn) * s;
      canvas.drawCircle(at, s * 0.022, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(_TablePainter o) => true;
}
