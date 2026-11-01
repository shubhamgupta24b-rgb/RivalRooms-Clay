import 'dart:math';
import 'package:flutter/material.dart';
import '../../guess_person/models/gp_player.dart';
import '../../../core/audio/game_audio.dart';
import '../../../core/ui/components.dart';
import '../shell/edge_seats.dart';
import '../shell/game_hud.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/local_game_shell.dart' show PauseButton, ResultScope;
import '../shell/ticking_play.dart';

/// A marble rolling in the pond (unit square, 0..1 each way).
class Marble {
  Offset p, v;
  final bool gold; // worth 3
  Marble(this.p, this.v, {this.gold = false});
}

/// Hungry hippos for 2-4 players around a square pond, one hippo per edge. Tap near your
/// edge to chomp: the head lunges in and eats every marble in reach. Marbles drop in from
/// the middle in waves. When they're all eaten (or time runs out), most points wins.
class HungryHipposLogic extends TimedDuel {
  static const marbleR = 0.022, reach = 0.24, mouthR = 0.1;
  static const chompMs = 320, cooldownMs = 520;
  final int players, total;
  final Random _rng;
  final List<Marble> marbles = [];
  final List<int> points;
  final List<int> chompAt; // when each hippo last chomped
  final List<int> eats; // counts each hippo's successful bites, for the view
  int dropped = 0;
  int _last = 0;

  HungryHipposLogic(
      {this.players = 2,
      this.total = 30,
      int durationMs = 40000,
      Random? random})
      : _rng = random ?? Random(),
        points = List.filled(players, 0),
        chompAt = List.filled(players, -10000),
        eats = List.filled(players, 0),
        super(durationMs);

  /// The hippo's mouth centre for [seat], given how far the chomp has lunged (0..1).
  static Offset mouth(int seat, double lunge) {
    final d = edgeDir(seat);
    final edge = const Offset(0.5, 0.5) + d * 0.5;
    return edge - d * (0.05 + reach * lunge);
  }

  /// 0 resting, rising to 1 at mid-chomp, back to 0.
  double lunge(int seat) {
    final t = (elapsedMs - chompAt[seat]) / chompMs;
    return t < 0 || t > 1 ? 0 : sin(pi * t);
  }

  @override
  bool get finished => super.finished || (dropped >= total && marbles.isEmpty);
  @override
  List<int> get scores => points;

  @override
  void onUpdate() {
    final dt = min(0.05, (elapsedMs - _last) / 1000);
    _last = elapsedMs;
    // A new marble every 0.35 s in waves, from the middle, in a random direction.
    final due = min(total, (elapsedMs / 350).floor() + 4);
    while (dropped < due) {
      final a = _rng.nextDouble() * 2 * pi,
          speed = 0.25 + _rng.nextDouble() * 0.2;
      marbles.add(Marble(const Offset(0.5, 0.5), Offset(cos(a), sin(a)) * speed,
          gold: _rng.nextDouble() < 0.12));
      dropped++;
    }
    for (final m in marbles) {
      m.p += m.v * dt;
      // Bounce off the pond walls.
      if (m.p.dx < marbleR && m.v.dx < 0 || m.p.dx > 1 - marbleR && m.v.dx > 0)
        m.v = Offset(-m.v.dx, m.v.dy);
      if (m.p.dy < marbleR && m.v.dy < 0 || m.p.dy > 1 - marbleR && m.v.dy > 0)
        m.v = Offset(m.v.dx, -m.v.dy);
      // Keep them moving: a gentle push back toward a cruising speed.
      final s = m.v.distance;
      if (s < 0.18) m.v = m.v * (0.18 / max(s, 0.001));
    }
    // Hippos bite at the peak of the lunge.
    for (var seat = 0; seat < players; seat++) {
      final l = lunge(seat);
      if (l < 0.6) continue;
      final mouthAt = mouth(seat, l);
      final before = marbles.length;
      marbles.removeWhere((m) {
        if ((m.p - mouthAt).distance > mouthR) return false;
        points[seat] += m.gold ? 3 : 1;
        return true;
      });
      if (marbles.length < before) eats[seat]++;
    }
  }

  void chomp(int seat) {
    if (forward('chomp', [seat])) return;
    if (finished || seat >= players || elapsedMs - chompAt[seat] < cooldownMs)
      return;
    chompAt[seat] = elapsedMs;
    notifyListeners();
  }
}

final hungryHipposInfo = LocalGameInfo(
  id: 'hungry_hippos',
  title: 'Hungry Hippos',
  emoji: '🦛',
  color: const Color(0xFF7E57C2),
  tagline: 'Chomp the marbles before the others!',
  rules: const [
    'Each player has a hippo on one side of the pond. Tap near your side to chomp.',
    'Your hippo lunges in and eats every marble in reach. Gold marbles are worth 3.',
    'When the marbles are gone (or after 40 seconds), most points wins. 2 to 4 players.',
  ],
  scoreUnit: 'points',
  splitScreen: true,
  maxPlayers: 4,
  bot: botFor<HungryHipposLogic>((g, b, now) {
    if (g.finished || !b.due(now)) return;
    // Chomps when a marble is heading into reach, a bit late or early sometimes.
    final target = HungryHipposLogic.mouth(b.seat, 0.8);
    final close = g.marbles
        .any((m) => (m.p - target).distance < HungryHipposLogic.mouthR * 1.6);
    if (close && b.chance(0.5)) {
      g.chomp(b.seat);
      b.wait(now, 450, 900);
    }
  }),
  online: RelaySpec<HungryHipposLogic>(
    create: (n) => HungryHipposLogic(players: n),
    save: (g) => {
      't': g.elapsedMs,
      'points': g.points,
      'chomp': g.chompAt,
      'eats': g.eats,
      'dropped': g.dropped,
      'marbles': [
        for (final m in g.marbles) [m.p.dx, m.p.dy, m.gold ? 1 : 0]
      ],
    },
    load: (g, s, me) {
      g.elapsedMs = asInt(s['t']);
      g.points.setAll(0, ints(s['points']));
      g.chompAt.setAll(0, ints(s['chomp']));
      g.eats.setAll(0, ints(s['eats']));
      g.dropped = asInt(s['dropped']);
      g.marbles
        ..clear()
        ..addAll([
          for (final m in s['marbles'] as List)
            Marble(Offset(asDouble(m[0]), asDouble(m[1])), Offset.zero,
                gold: asInt(m[2]) == 1)
        ]);
    },
    apply: (g, from, name, a) {
      if (name == 'chomp' && asInt(a[0]) == from) g.chomp(from);
    },
    view: (context, g, players, me) => RotatedBox(
        quarterTurns: seatToBottom(me),
        child: _Pond(g: g, players: players, me: me)),
  ),
  play: (players, onFinished) => TickingPlay<HungryHipposLogic>(
    create: () => HungryHipposLogic(players: players.length),
    onFinished: onFinished,
    builder: (context, g) => _Pond(g: g, players: players),
  ),
);

class _Pond extends StatelessWidget {
  final HungryHipposLogic g;
  final List<GpPlayer> players;
  final int? me; // online: every tap is this phone's hippo
  const _Pond({required this.g, required this.players, this.me});

  @override
  Widget build(BuildContext context) {
    ResultScope.of(context)?.subtitle = g.finished
        ? (g.marbles.isEmpty && g.dropped >= g.total
            ? 'Every marble eaten'
            : 'Time up')
        : null;
    final best = g.points.reduce(max);
    return MomentWatcher<int>(
      value: g.eats.fold(0, (a, b) => a + b),
      onChange: (fx, _, __) {
        GameAudio.sfx('pop');
        haptic(HapticWeight.light);
      },
      child: Padding(
        padding: const EdgeInsets.all(Space.xs),
        child: EdgeArena(
          players: players.length,
          onSeatTap: (seat) {
            if (me case final m?) return g.chomp(m);
            if (BotScope.isBot(context, seat)) return;
            g.chomp(seat);
          },
          label: (i) => EdgeScore(
              player: players[i],
              seat: i,
              score: '${g.points[i]}',
              tag: best > 0 && g.points[i] == best ? 'TOP' : null),
          corner: Container(
            padding: const EdgeInsets.only(right: 10),
            decoration: Skin.pill(color: NeonPalette.sheet),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const PauseButton(),
              Text('${g.secondsLeft}s',
                  style: const TextStyle(
                      fontFamily: Fonts.display,
                      fontSize: 16,
                      color: Colors.white,
                      fontFeatures: [FontFeature.tabularFigures()])),
            ]),
          ),
          arena: Semantics(
            label:
                'Pond with ${g.marbles.length} marbles. Tap near your side to chomp.',
            child: RepaintBoundary(
                child: CustomPaint(painter: _PondPainter(g, players))),
          ),
        ),
      ),
    );
  }
}

class _PondPainter extends CustomPainter {
  final HungryHipposLogic g;
  final List<GpPlayer> players;
  _PondPainter(this.g, this.players);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final r = Offset.zero & size;
    final pond = RRect.fromRectAndRadius(r, Radius.circular(s * 0.08));
    canvas.drawRRect(
        pond.shift(const Offset(0, 6)), Paint()..color = Colors.black45);
    canvas.drawRRect(
        pond,
        Paint()
          ..shader = const RadialGradient(
              colors: [Color(0xFF7FD3E8), Color(0xFF3A9CC0), Color(0xFF2A7397)],
              stops: [0, 0.7, 1]).createShader(r));
    canvas.drawRRect(
        pond,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.025
          ..color = const Color(0xFFF2E6C9));
    // Ripples.
    final ripple = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.white.withValues(alpha: 0.18);
    for (final k in [0.12, 0.24, 0.36]) {
      canvas.drawCircle(
          r.center, s * (k + (g.elapsedMs % 3000) / 3000 * 0.12), ripple);
    }
    // Marbles.
    for (final m in g.marbles) {
      final at = m.p * s, rad = HungryHipposLogic.marbleR * s;
      canvas.drawCircle(
          at + Offset(0, rad * 0.4), rad, Paint()..color = Colors.black26);
      final col = m.gold ? Brand.gold : Colors.white;
      canvas.drawCircle(
          at,
          rad,
          Paint()
            ..shader = RadialGradient(
                center: const Alignment(-0.4, -0.4),
                colors: [
                  Colors.white,
                  col,
                  Color.lerp(col, Colors.black, 0.3)!
                ]).createShader(Rect.fromCircle(center: at, radius: rad)));
    }
    // Hippos: a round head at each seat's edge that lunges in with the mouth open.
    for (var seat = 0; seat < g.players; seat++) {
      final l = g.lunge(seat);
      final d = edgeDir(seat);
      final mouthAt = HungryHipposLogic.mouth(seat, l) * s;
      final col = players[seat].color;
      final headR = s * 0.11;
      final head = mouthAt + d * headR * 0.9;
      // Neck back to the edge.
      final edgeAt = (const Offset(0.5, 0.5) + d * 0.56) * s;
      canvas.drawLine(
          edgeAt,
          head,
          Paint()
            ..strokeWidth = headR * 1.3
            ..strokeCap = StrokeCap.round
            ..color = Color.lerp(col, Colors.black, 0.15)!);
      canvas.drawCircle(
          head,
          headR,
          Paint()
            ..shader = RadialGradient(
                center: const Alignment(-0.3, -0.4),
                colors: [
                  Color.lerp(col, Colors.white, 0.4)!,
                  col,
                  Color.lerp(col, Colors.black, 0.3)!
                ]).createShader(Rect.fromCircle(center: head, radius: headR)));
      // Mouth: a dark opening that widens with the lunge, with two teeth.
      final n = Offset(-d.dy, d.dx);
      final open = headR * (0.25 + 0.45 * l);
      final mouthRect = Rect.fromCenter(
          center: head - d * headR * 0.55,
          width: (n.dx.abs() * headR * 1.3 + d.dx.abs() * open),
          height: (n.dy.abs() * headR * 1.3 + d.dy.abs() * open));
      canvas.drawOval(mouthRect, Paint()..color = const Color(0xFF5A1D2A));
      for (final side in [-0.35, 0.35]) {
        final tooth = head - d * headR * 0.62 + n * headR * side;
        canvas.drawRect(
            Rect.fromCenter(
                center: tooth, width: headR * 0.16, height: headR * 0.16),
            Paint()..color = Colors.white);
      }
      // Eyes, on the far side of the head.
      for (final side in [-0.45, 0.45]) {
        final eye = head + d * headR * 0.35 + n * headR * side;
        canvas.drawCircle(eye, headR * 0.17, Paint()..color = Colors.white);
        canvas.drawCircle(eye - d * headR * 0.05, headR * 0.08,
            Paint()..color = Colors.black);
      }
    }
  }

  @override
  bool shouldRepaint(_PondPainter o) => true;
}
