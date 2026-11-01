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

class Penguin {
  Offset p, v = Offset.zero;
  double facing; // radians
  double turnDir;
  bool out = false;
  int fellAt = 0;
  int dashAt = -10000;
  Penguin(this.p, this.facing, this.turnDir);
}

/// Sumo on ice for 2-4 players. The rink is a circle of radius 1 around the origin. Every
/// penguin keeps turning on the spot; tap near your edge to dash the way it faces (and spin
/// the other way). Bump the others off the ice: the last one standing wins the round. First
/// to [target] rounds wins.
class PenguinPushLogic extends LocalGameLogic {
  static const radius = 0.14,
      dashSpeed = 1.9,
      cooldownMs = 650,
      roundMs = 30000;
  final int players, target;
  final Random _rng;
  final List<int> wins;
  late List<Penguin> penguins;
  int round = 0;
  int _now = 0, _last = 0, roundStart = 0;
  int? pauseUntil; // between rounds
  int? roundWinner; // -1: nobody (all fell, or time up)
  int bumps = 0, falls = 0;

  PenguinPushLogic({this.players = 2, this.target = 3, Random? random})
      : _rng = random ?? Random(),
        wins = List.filled(players, 0) {
    _reset();
  }

  void _reset() {
    penguins = [
      for (var i = 0; i < players; i++)
        Penguin(edgeDir(i) * 0.6, atan2(-edgeDir(i).dy, -edgeDir(i).dx),
            _rng.nextBool() ? 1 : -1),
    ];
    roundStart = _now;
    roundWinner = null;
  }

  int get now => _now;
  int get secondsLeft =>
      max(0, ((roundMs - (_now - roundStart)) / 1000).ceil());

  @override
  bool get finished => wins.any((w) => w >= target) && pauseUntil == null;
  @override
  List<int> get scores => wins;

  @override
  void update(int elapsedMs) {
    _now = elapsedMs;
    final dt = min(0.05, (elapsedMs - _last) / 1000);
    _last = elapsedMs;
    if (pauseUntil != null) {
      if (_now >= pauseUntil!) {
        pauseUntil = null;
        if (!finished) {
          round++;
          _reset();
        }
      }
      notifyListeners();
      return;
    }
    if (finished) return;
    for (final pg in penguins) {
      if (pg.out) continue;
      pg.facing += pg.turnDir * 2.6 * dt;
      pg.p += pg.v * dt;
      pg.v =
          pg.v * pow(0.25, dt).toDouble(); // ice: slides a long way, then stops
    }
    // Bumps: equal masses swap their speed along the line between them.
    for (var a = 0; a < players; a++) {
      for (var b = a + 1; b < players; b++) {
        final pa = penguins[a], pb = penguins[b];
        if (pa.out || pb.out) continue;
        final d = pb.p - pa.p;
        final dist = d.distance;
        if (dist >= radius * 2 || dist == 0) continue;
        final n = d / dist;
        final rel = (pa.v - pb.v).dx * n.dx + (pa.v - pb.v).dy * n.dy;
        if (rel > 0) {
          final j = n * (rel * 1.1);
          pa.v -= j;
          pb.v += j;
          bumps++;
        }
        final push = n * ((radius * 2 - dist) / 2);
        pa.p -= push;
        pb.p += push;
      }
    }
    for (final pg in penguins) {
      if (!pg.out && pg.p.distance > 1 + radius * 0.2) {
        pg.out = true;
        pg.fellAt = _now;
        falls++;
      }
    }
    final standing = [
      for (var i = 0; i < players; i++)
        if (!penguins[i].out) i
    ];
    if (standing.length <= 1 || _now - roundStart >= roundMs) {
      roundWinner = standing.length == 1 ? standing.single : -1;
      if (roundWinner! >= 0) wins[roundWinner!]++;
      pauseUntil = _now + 1800;
    }
    notifyListeners();
  }

  void dash(int seat) {
    if (forward('dash', [seat])) return;
    if (finished || pauseUntil != null || seat >= players) return;
    final pg = penguins[seat];
    if (pg.out || _now - pg.dashAt < cooldownMs) return;
    pg.dashAt = _now;
    pg.v += Offset(cos(pg.facing), sin(pg.facing)) * dashSpeed;
    pg.turnDir = -pg.turnDir;
    notifyListeners();
  }
}

final penguinPushInfo = LocalGameInfo(
  id: 'penguin_push',
  title: 'Penguin Push',
  emoji: '🐧',
  color: const Color(0xFF3B9AD9),
  tagline: 'Dash, bump, knock them off the ice!',
  rules: const [
    'Your penguin keeps turning. Tap near your side to dash the way its arrow points.',
    'Bump the others off the ice. The last penguin standing wins the round.',
    'First to 3 rounds wins. 2 to 4 players.',
  ],
  scoreUnit: 'rounds',
  splitScreen: true,
  maxPlayers: 4,
  bot: botFor<PenguinPushLogic>((g, b, now) {
    if (g.finished || g.pauseUntil != null || !b.due(now)) return;
    final me = g.penguins[b.seat];
    if (me.out) return;
    final f = Offset(cos(me.facing), sin(me.facing));
    // Dash toward a rival if it's lined up, or back to the middle if near the edge.
    final toward = me.p.distance > 0.65 ? -me.p : null;
    bool aligned(Offset d) =>
        d.distance > 0 && (d.dx * f.dx + d.dy * f.dy) / d.distance > 0.93;
    final hunt = [
      for (var i = 0; i < g.players; i++)
        if (i != b.seat && !g.penguins[i].out) g.penguins[i].p - me.p
    ].any(aligned);
    if ((toward != null && aligned(toward)) || (toward == null && hunt)) {
      g.dash(b.seat);
      b.wait(now, 300, 700);
    }
  }),
  online: RelaySpec<PenguinPushLogic>(
    create: (n) => PenguinPushLogic(players: n),
    save: (g) => {
      'wins': g.wins,
      'round': g.round,
      'now': g._now,
      'start': g.roundStart,
      'pause': g.pauseUntil,
      'rw': g.roundWinner,
      'bumps': g.bumps,
      'falls': g.falls,
      'pg': [
        for (final p in g.penguins)
          [p.p.dx, p.p.dy, p.facing, p.out ? 1 : 0, p.fellAt, p.v.dx, p.v.dy]
      ],
    },
    load: (g, s, me) {
      g.wins.setAll(0, ints(s['wins']));
      g.round = asInt(s['round']);
      g._now = asInt(s['now']);
      g.roundStart = asInt(s['start']);
      g.pauseUntil = nInt(s['pause']);
      g.roundWinner = nInt(s['rw']);
      g.bumps = asInt(s['bumps']);
      g.falls = asInt(s['falls']);
      final pg = s['pg'] as List;
      for (var i = 0; i < g.players; i++) {
        final v = doubles(pg[i]);
        g.penguins[i]
          ..p = Offset(v[0], v[1])
          ..facing = v[2]
          ..out = v[3] == 1
          ..fellAt = v[4].toInt()
          ..v = Offset(v[5], v[6]);
      }
    },
    apply: (g, from, name, a) {
      if (name == 'dash' && asInt(a[0]) == from) g.dash(from);
    },
    view: (context, g, players, me) => RotatedBox(
        quarterTurns: seatToBottom(me),
        child: _Rink(g: g, players: players, me: me)),
  ),
  play: (players, onFinished) => TickingPlay<PenguinPushLogic>(
    create: () => PenguinPushLogic(players: players.length),
    onFinished: onFinished,
    builder: (context, g) => _Rink(g: g, players: players),
  ),
);

class _Rink extends StatelessWidget {
  final PenguinPushLogic g;
  final List<GpPlayer> players;
  final int? me; // online: every tap is this phone's penguin
  const _Rink({required this.g, required this.players, this.me});

  @override
  Widget build(BuildContext context) {
    ResultScope.of(context)?.subtitle =
        g.finished ? 'First to ${g.target} rounds' : null;
    return MomentWatcher<(int, int, int?)>(
      value: (g.bumps, g.falls, g.roundWinner),
      onChange: (fx, before, now) {
        if (now.$3 != null && before.$3 == null) {
          if (now.$3! >= 0) {
            keyMoment(fx, 'ROUND!',
                sub: '${players[now.$3!].name} is the last one standing',
                sound: g.wins.any((w) => w >= g.target) ? 'win' : 'coin',
                confetti: g.wins.any((w) => w >= g.target));
          } else {
            keyMoment(fx, 'NO WINNER',
                sub: 'Nobody left standing', color: Colors.white);
          }
        } else if (now.$2 > before.$2) {
          GameAudio.sfx('lose');
          haptic(HapticWeight.heavy);
        } else if (now.$1 > before.$1) {
          GameAudio.sfx('hit');
          haptic(HapticWeight.medium);
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(Space.xs),
        child: EdgeArena(
          players: players.length,
          onSeatTap: (seat) {
            if (me case final m?) return g.dash(m);
            if (BotScope.isBot(context, seat)) return;
            g.dash(seat);
          },
          label: (i) => EdgeScore(
              player: players[i],
              seat: i,
              score: '${g.wins[i]}',
              dim: g.penguins[i].out,
              tag: g.penguins[i].out ? 'OUT' : null),
          corner: Container(
            padding: const EdgeInsets.only(right: 10),
            decoration: Skin.pill(color: NeonPalette.sheet),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const PauseButton(),
              Text('R${g.round + 1}  ${g.secondsLeft}s',
                  style: const TextStyle(
                      fontFamily: Fonts.display,
                      fontSize: 15,
                      color: Colors.white,
                      fontFeatures: [FontFeature.tabularFigures()])),
            ]),
          ),
          arena: Semantics(
            label: 'Ice rink, round ${g.round + 1}. ${[
              for (var i = 0; i < players.length; i++)
                if (!g.penguins[i].out) players[i].name
            ].join(', ')} still on the ice.',
            child: RepaintBoundary(
                child: CustomPaint(painter: _RinkPainter(g, players))),
          ),
        ),
      ),
    );
  }
}

class _RinkPainter extends CustomPainter {
  final PenguinPushLogic g;
  final List<GpPlayer> players;
  _RinkPainter(this.g, this.players);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final s = size.width / 2 * 0.86; // rink radius in pixels
    // Dark water around a round ice floe.
    canvas.drawCircle(
        c,
        size.width / 2,
        Paint()
          ..shader = const RadialGradient(
                  colors: [Color(0xFF1C4E7A), Color(0xFF0E2B48)])
              .createShader(Offset.zero & size));
    canvas.drawCircle(
        c + const Offset(0, 8), s, Paint()..color = const Color(0xFF9CC9E6));
    canvas.drawCircle(
        c,
        s,
        Paint()
          ..shader = const RadialGradient(
                  center: Alignment(-0.3, -0.4),
                  colors: [Colors.white, Color(0xFFDDF0FB), Color(0xFFB7DDF2)])
              .createShader(Rect.fromCircle(center: c, radius: s)));
    canvas.drawCircle(
        c,
        s * 0.25,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0x553A9CC0));
    // Scratches in the ice.
    final scratch = Paint()
      ..strokeWidth = 1.2
      ..color = const Color(0x333A6A90);
    for (var k = 0; k < 8; k++) {
      final a = k * 0.8;
      canvas.drawLine(c + Offset(cos(a), sin(a)) * s * 0.4,
          c + Offset(cos(a + 0.3), sin(a + 0.3)) * s * 0.7, scratch);
    }
    for (var i = 0; i < g.players; i++) {
      final pg = g.penguins[i];
      final col = players[i].color;
      var at = c + pg.p * s;
      var scale = 1.0;
      if (pg.out) {
        // Sinks into the water.
        final t = ((g.now - pg.fellAt) / 600).clamp(0.0, 1.0);
        scale = 1 - t;
        if (scale <= 0) continue;
        at += pg.v * (t * s * 0.1);
      }
      final r = PenguinPushLogic.radius * s * scale;
      canvas.drawOval(
          Rect.fromCenter(
              center: at + Offset(0, r * 0.5), width: r * 2, height: r),
          Paint()..color = Colors.black26);
      // Facing arrow.
      if (!pg.out) {
        final f = Offset(cos(pg.facing), sin(pg.facing));
        final tip = at + f * r * 2.1;
        final n = Offset(-f.dy, f.dx);
        canvas.drawLine(
            at + f * r,
            tip - f * r * 0.3,
            Paint()
              ..strokeWidth = r * 0.22
              ..strokeCap = StrokeCap.round
              ..color = col.withValues(alpha: 0.85));
        canvas.drawPath(
            Path()
              ..moveTo(tip.dx, tip.dy)
              ..lineTo(tip.dx - f.dx * r * 0.55 + n.dx * r * 0.4,
                  tip.dy - f.dy * r * 0.55 + n.dy * r * 0.4)
              ..lineTo(tip.dx - f.dx * r * 0.55 - n.dx * r * 0.4,
                  tip.dy - f.dy * r * 0.55 - n.dy * r * 0.4)
              ..close(),
            Paint()..color = col);
      }
      // Body: dark back in the player's colour, white belly, orange beak toward the arrow.
      canvas.drawCircle(
          at, r, Paint()..color = Color.lerp(col, Colors.black, 0.45)!);
      canvas.drawCircle(
          at,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.18
            ..color = col);
      final f = Offset(cos(pg.facing), sin(pg.facing));
      canvas.drawCircle(
          at + f * r * 0.2, r * 0.6, Paint()..color = Colors.white);
      for (final side in [-0.35, 0.35]) {
        final e = at + f * r * 0.45 + Offset(-f.dy, f.dx) * r * side;
        canvas.drawCircle(e, r * 0.12, Paint()..color = Colors.black);
      }
      canvas.drawCircle(
          at + f * r * 0.85, r * 0.2, Paint()..color = const Color(0xFFFF9F1C));
    }
  }

  @override
  bool shouldRepaint(_RinkPainter o) => true;
}
