import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/audio/game_audio.dart';
import '../../../core/ui/components.dart';
import '../../guess_person/models/gp_player.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/game_hud.dart';
import '../shell/ticking_play.dart';

/// One hole on a course 1 wide and [GolfLogic.courseH] tall.
class GolfHole {
  final Offset tee, cup;
  final List<Rect> walls, sand;
  const GolfHole(this.tee, this.cup,
      {this.walls = const [], this.sand = const []});
}

const golfHoles = [
  GolfHole(Offset(0.5, 1.3), Offset(0.5, 0.25)),
  GolfHole(Offset(0.5, 1.3), Offset(0.5, 0.2),
      walls: [Rect.fromLTWH(0.28, 0.65, 0.44, 0.08)],
      sand: [Rect.fromLTWH(0.05, 0.35, 0.2, 0.2)]),
  GolfHole(Offset(0.2, 1.3), Offset(0.78, 0.22),
      walls: [Rect.fromLTWH(0, 0.7, 0.66, 0.07)]),
  GolfHole(Offset(0.5, 1.35), Offset(0.5, 0.15), walls: [
    Rect.fromLTWH(0, 1.0, 0.62, 0.06),
    Rect.fromLTWH(0.38, 0.55, 0.62, 0.06)
  ], sand: [
    Rect.fromLTWH(0.05, 0.62, 0.3, 0.3)
  ]),
  GolfHole(Offset(0.5, 1.35), Offset(0.5, 0.18), walls: [
    Rect.fromLTWH(0.22, 0.92, 0.09, 0.09),
    Rect.fromLTWH(0.62, 0.92, 0.09, 0.09),
    Rect.fromLTWH(0.42, 0.64, 0.09, 0.09),
    Rect.fromLTWH(0.14, 0.4, 0.09, 0.09),
    Rect.fromLTWH(0.76, 0.4, 0.09, 0.09),
  ]),
  GolfHole(Offset(0.5, 1.35), Offset(0.5, 0.24), walls: [
    Rect.fromLTWH(0.24, 0.08, 0.06, 0.38),
    Rect.fromLTWH(0.7, 0.08, 0.06, 0.38),
    Rect.fromLTWH(0.24, 0.08, 0.52, 0.05),
    Rect.fromLTWH(0.24, 0.46, 0.19, 0.06),
    Rect.fromLTWH(0.57, 0.46, 0.19, 0.06),
  ], sand: [
    Rect.fromLTWH(0.3, 0.8, 0.4, 0.18),
  ]),
];

/// Mini Golf: pull back and release to putt. Bounce off walls, avoid the sand, sink it in
/// as few strokes as you can. Each hole is worth 7 minus your strokes (a hole in one is 6);
/// after 6 strokes the ball is picked up. 6 holes, taking turns.
class GolfLogic extends LocalGameLogic {
  static const courseH = 1.5,
      ballR = 0.018,
      cupR = 0.03,
      maxSpeed = 1.7,
      maxStrokes = 6;
  final int players;
  final List<int> score;
  final List<List<int>> card; // strokes per player per hole
  int hole = 0, turn = 0, strokes = 0, now = 0, _last = 0;
  late Offset ball;
  Offset vel = Offset.zero;
  int? sunkAt;
  String? message;
  int messageAt = -10000;
  bool done = false;

  GolfLogic({this.players = 2})
      : score = List.filled(players, 0),
        card = [for (var i = 0; i < players; i++) <int>[]] {
    ball = golfHoles[0].tee;
  }

  @override
  bool get finished => done;
  @override
  List<int> get scores => score;

  GolfHole get course => golfHoles[hole];
  bool get moving => vel != Offset.zero;
  bool get ready => !done && !moving && sunkAt == null;

  void putt(int player, double angle, double power) {
    if (forward('putt', [player, angle, power])) return;
    if (!ready || player != turn) return;
    final p = power.clamp(0.05, 1.0) * maxSpeed;
    vel = Offset(cos(angle) * p, sin(angle) * p);
    strokes++;
    HapticFeedback.lightImpact().ignore();
    GameAudio.sfx('tap');
    notifyListeners();
  }

  /// Moves a ball ([s] = x, y, vx, vy) on [h] by [dt] seconds. True once it drops in.
  static bool stepBall(GolfHole h, List<double> s, double dt) {
    var x = s[0] + s[2] * dt, y = s[1] + s[3] * dt, vx = s[2], vy = s[3];
    // Rolling friction; much more in the sand.
    final inSand = h.sand.any((r) => r.contains(Offset(x, y)));
    final speed = sqrt(vx * vx + vy * vy);
    if (speed > 0) {
      final slow =
          (inSand ? 2.2 : 0.22) * dt + speed * (inSand ? 2.0 : 0.9) * dt;
      final k = max(0.0, speed - slow) / speed;
      vx *= k;
      vy *= k;
    }
    // Edges of the course.
    if (x < ballR) (x, vx) = (ballR, vx.abs() * 0.8);
    if (x > 1 - ballR) (x, vx) = (1 - ballR, -vx.abs() * 0.8);
    if (y < ballR) (y, vy) = (ballR, vy.abs() * 0.8);
    if (y > courseH - ballR) (y, vy) = (courseH - ballR, -vy.abs() * 0.8);
    // Walls: push out along the shallower side and bounce.
    for (final r in h.walls) {
      final cx = x.clamp(r.left, r.right), cy = y.clamp(r.top, r.bottom);
      final dx = x - cx, dy = y - cy;
      if (dx * dx + dy * dy >= ballR * ballR) continue;
      if (dx == 0 && dy == 0) {
        // Centre inside the wall (very fast ball): back out the way it came.
        x = s[0];
        y = s[1];
        vx = -vx * 0.8;
        vy = -vy * 0.8;
        continue;
      }
      if (dx.abs() > dy.abs()) {
        x = cx + dx.sign * ballR;
        vx = dx.sign * vx.abs() * 0.8;
      } else {
        y = cy + dy.sign * ballR;
        vy = dy.sign * vy.abs() * 0.8;
      }
    }
    s
      ..[0] = x
      ..[1] = y
      ..[2] = vx
      ..[3] = vy;
    // Into the cup if it's slow enough not to skip over it; a fast ball lips out a little.
    final d = (Offset(x, y) - h.cup).distance;
    final v = sqrt(vx * vx + vy * vy);
    if (d < cupR && v < 1.0) return true;
    if (d < cupR) {
      s[2] = vx * 0.85 + (x - h.cup.dx) * 3;
      s[3] = vy * 0.85 + (y - h.cup.dy) * 3;
    }
    if (v < 0.012) {
      s[2] = 0;
      s[3] = 0;
    }
    return false;
  }

  /// Where a putt ends up: (resting spot, sunk?).
  static (Offset, bool) simulate(
      GolfHole h, Offset from, double angle, double power,
      {double dt = 1 / 60}) {
    final p = power.clamp(0.05, 1.0) * maxSpeed;
    final s = [from.dx, from.dy, cos(angle) * p, sin(angle) * p];
    for (var i = 0; i < 1200; i++) {
      if (stepBall(h, s, dt)) return (h.cup, true);
      if (s[2] == 0 && s[3] == 0) break;
    }
    return (Offset(s[0], s[1]), false);
  }

  @override
  void update(int ms) {
    final dt = ((ms - _last) / 1000).clamp(0.0, 0.05);
    _last = now = ms;
    if (moving) {
      final s = [ball.dx, ball.dy, vel.dx, vel.dy];
      var sunk = false;
      for (var i = 0; i < 4 && !sunk; i++) {
        sunk = stepBall(course, s, dt / 4);
      }
      ball = Offset(s[0], s[1]);
      vel = Offset(s[2], s[3]);
      if (sunk) {
        ball = course.cup;
        vel = Offset.zero;
        _holeOut();
      } else if (!moving && strokes >= maxStrokes) {
        _holeOut(pickedUp: true);
      }
    } else if (sunkAt != null && ms - sunkAt! > 1300) {
      _next();
    }
    notifyListeners();
  }

  void _holeOut({bool pickedUp = false}) {
    sunkAt = now;
    final taken = pickedUp ? maxStrokes + 1 : strokes;
    card[turn].add(taken);
    score[turn] += 7 - taken;
    message = pickedUp
        ? 'Picked up · +0'
        : (strokes == 1
            ? '⛳ HOLE IN ONE! +6'
            : (strokes == 2
                ? '🐦 BIRDIE! +5'
                : 'In the cup in $strokes · +${7 - strokes}'));
    messageAt = now;
    HapticFeedback.mediumImpact().ignore();
    GameAudio.sfx(pickedUp ? 'lose' : 'coin');
  }

  void _next() {
    sunkAt = null;
    strokes = 0;
    turn = (turn + 1) % players;
    if (turn == 0) hole++;
    if (hole >= golfHoles.length) {
      hole = golfHoles.length - 1;
      done = true;
      return;
    }
    ball = course.tee;
  }
}

/// The bot tries a spread of putts on a copy of the physics and plays the best, a bit shakily.
(double, double) golfBotShot(GolfLogic g, Random rng) {
  var best = (0.0, 0.5);
  var bestD = double.infinity;
  for (var a = 0; a < 48; a++) {
    final angle = a / 48 * 2 * pi;
    for (var p = 1; p <= 7; p++) {
      final (end, sunk) = GolfLogic.simulate(g.course, g.ball, angle, p / 7);
      final d = sunk ? -1.0 + p * 0.01 : (end - g.course.cup).distance;
      if (d < bestD) (bestD, best) = (d, (angle, p / 7));
    }
  }
  // Fine-tune around the best one.
  for (var i = 0; i < 40; i++) {
    final angle = best.$1 + (rng.nextDouble() - 0.5) * 0.12,
        power = (best.$2 + (rng.nextDouble() - 0.5) * 0.12).clamp(0.05, 1.0);
    final (end, sunk) = GolfLogic.simulate(g.course, g.ball, angle, power);
    final d = sunk ? -1.0 + power * 0.01 : (end - g.course.cup).distance;
    if (d < bestD) (bestD, best) = (d, (angle, power));
  }
  return (
    best.$1 + (rng.nextDouble() - 0.5) * 0.06,
    best.$2 * (0.93 + rng.nextDouble() * 0.14)
  );
}

final golfInfo = LocalGameInfo(
  id: 'mini_golf',
  title: 'Mini Golf',
  emoji: '⛳',
  color: const Color(0xFF43A047),
  tagline: 'Six tricky holes. Sink it!',
  rules: const [
    'Drag back from the ball and let go to putt: the further you pull, the harder you hit.',
    'Bounce off the walls, keep out of the sand. Each hole is worth 7 minus your strokes.',
    'A hole in one is 6 points! After 6 strokes the ball is picked up. 6 holes, 1 to 4 players.',
  ],
  scoreUnit: 'points',
  splitScreen: false,
  minPlayers: 1,
  maxPlayers: 4,
  bot: botFor<GolfLogic>((g, b, now) {
    if (!g.ready || g.turn != b.seat) return;
    if (!b.thinkFirst((g.hole, g.turn, g.strokes), now, 1000, 1700)) return;
    final (angle, power) = golfBotShot(g, b.rng);
    g.putt(b.seat, angle, power);
  }),
  online: RelaySpec<GolfLogic>(
    create: (n) => GolfLogic(players: n),
    save: (g) => {
      'score': g.score,
      'card': [for (final c in g.card) c],
      'hole': g.hole,
      'turn': g.turn,
      'strokes': g.strokes,
      'ball': [g.ball.dx, g.ball.dy, g.vel.dx, g.vel.dy],
      'sunk': g.sunkAt,
      'now': g.now,
      'msg': g.message,
      'msgAt': g.messageAt,
      'done': g.done,
    },
    load: (g, s, me) {
      g.score.setAll(0, ints(s['score']));
      final card = s['card'] as List;
      for (var i = 0; i < g.card.length && i < card.length; i++) {
        g.card[i]
          ..clear()
          ..addAll(ints(card[i]));
      }
      g.hole = asInt(s['hole']);
      g.turn = asInt(s['turn']);
      g.strokes = asInt(s['strokes']);
      final b = doubles(s['ball']);
      g.ball = Offset(b[0], b[1]);
      g.vel = Offset(b[2], b[3]);
      g.sunkAt = nInt(s['sunk']);
      g.now = asInt(s['now']);
      g.message = s['msg'] as String?;
      g.messageAt = asInt(s['msgAt']);
      g.done = s['done'] == true;
    },
    apply: (g, from, name, a) {
      if (name == 'putt' && asInt(a[0]) == from)
        g.putt(from, asDouble(a[1]), asDouble(a[2]));
    },
    view: (context, g, players, me) =>
        _GolfView(g: g, players: players, me: me),
  ),
  play: (players, onFinished) => TickingPlay<GolfLogic>(
    create: () => GolfLogic(players: players.length),
    onFinished: onFinished,
    builder: (context, g) => _GolfView(g: g, players: players, bots: {
      for (var i = 0; i < players.length; i++)
        if (BotScope.isBot(context, i)) i
    }),
  ),
);

class _GolfView extends StatefulWidget {
  final GolfLogic g;
  final List<GpPlayer> players;
  final int? me;
  final Set<int> bots;
  const _GolfView(
      {required this.g, required this.players, this.me, this.bots = const {}});
  @override
  State<_GolfView> createState() => _GolfViewState();
}

class _GolfViewState extends State<_GolfView> {
  Offset? _from, _to;

  bool get _mine =>
      !widget.bots.contains(widget.g.turn) &&
      (widget.me == null || widget.me == widget.g.turn) &&
      widget.g.ready;

  /// (angle, power) for the current drag, pulling back like a slingshot.
  (double, double)? _aim(double w) {
    final f = _from, t = _to;
    if (f == null || t == null) return null;
    final d = f - t;
    if (d.distance < 8) return null;
    return (atan2(d.dy, d.dx), (d.distance / (w * 0.45)).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final current = widget.players[g.turn];
    final showMsg = g.message != null && g.now - g.messageAt < 1500;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      child: Column(children: [
        GameHud(
            players: widget.players,
            scores: g.score,
            turn: g.finished ? null : g.turn,
            trailing: HudLabel('HOLE ${g.hole + 1}/${golfHoles.length}')),
        const SizedBox(height: 8),
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            final w = min(c.maxWidth, c.maxHeight / GolfLogic.courseH);
            final aim = _mine ? _aim(w) : null;
            return Center(
              child: SizedBox(
                width: w,
                height: w * GolfLogic.courseH,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: _mine
                      ? (d) => setState(() => _from = _to = d.localPosition)
                      : null,
                  onPanUpdate: _mine
                      ? (d) => setState(() => _to = d.localPosition)
                      : null,
                  onPanEnd: _mine
                      ? (_) {
                          final a = _aim(w);
                          setState(() => _from = _to = null);
                          if (a != null && a.$2 > 0.04)
                            g.putt(g.turn, a.$1, a.$2);
                        }
                      : null,
                  child: SceneFrame(
                      child: CustomPaint(
                          painter: _CoursePainter(g, w, aim, current.color))),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        GameStatus(
          player: current,
          turnText: g.finished
              ? 'Round over!'
              : (_mine
                  ? '${current.whose} PUTT · stroke ${g.strokes + 1}'
                  : (g.moving ? 'Rolling…' : '${current.name} is lining up…')),
          message: showMsg ? g.message : null,
        ),
      ]),
    );
  }
}

class _CoursePainter extends CustomPainter {
  final GolfLogic g;
  final double s;
  final (double, double)? aim;
  final Color colour;
  _CoursePainter(this.g, this.s, this.aim, this.colour);

  @override
  void paint(Canvas canvas, Size size) {
    final h = g.course;
    Offset o(Offset p) => p * s;
    // Striped mown grass with a darker border.
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFF2E7D32));
    for (var i = 0; i < 12; i++) {
      if (i.isEven)
        canvas.drawRect(
            Rect.fromLTWH(
                0, i * size.height / 12, size.width, size.height / 12),
            Paint()..color = const Color(0xFF388E3C));
    }
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..color = const Color(0xFF5D4037));
    for (final r in h.sand) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTRB(r.left * s, r.top * s, r.right * s, r.bottom * s),
              Radius.circular(s * 0.05)),
          Paint()..color = const Color(0xFFE6C98A));
      final dots = Random(r.left.hashCode);
      for (var i = 0; i < 25; i++) {
        canvas.drawCircle(
            Offset((r.left + dots.nextDouble() * r.width) * s,
                (r.top + dots.nextDouble() * r.height) * s),
            1.2,
            Paint()..color = const Color(0xFFC8A96A));
      }
    }
    for (final r in h.walls) {
      final rect =
          Rect.fromLTRB(r.left * s, r.top * s, r.right * s, r.bottom * s);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              rect.shift(const Offset(2, 3)), const Radius.circular(4)),
          Paint()..color = Colors.black26);
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)),
          Paint()
            ..shader = const LinearGradient(
                    colors: [Color(0xFFA1887F), Color(0xFF6D4C41)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight)
                .createShader(rect));
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect.deflate(1.5), const Radius.circular(3)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = const Color(0x55FFE0B2));
    }
    // Tee box, cup and flag.
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: o(h.tee), width: s * 0.12, height: s * 0.07),
            const Radius.circular(6)),
        Paint()..color = Colors.white12);
    final cup = o(h.cup);
    canvas.drawCircle(
        cup, GolfLogic.cupR * s, Paint()..color = const Color(0xFF111111));
    canvas.drawCircle(
        cup,
        GolfLogic.cupR * s,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white54);
    final wave = sin(g.now / 250) * 3;
    canvas.drawLine(
        cup,
        cup - Offset(0, s * 0.13),
        Paint()
          ..color = Colors.white
          ..strokeWidth = 2.5);
    canvas.drawPath(
        Path()
          ..moveTo(cup.dx, cup.dy - s * 0.13)
          ..lineTo(cup.dx + s * 0.07 + wave, cup.dy - s * 0.11)
          ..lineTo(cup.dx, cup.dy - s * 0.09)
          ..close(),
        Paint()..color = colour);
    // Aim: dotted line ahead of the ball, longer and redder with power.
    final ball = o(g.ball);
    if (aim != null) {
      final (a, p) = aim!;
      final dir = Offset(cos(a), sin(a));
      for (var i = 1; i <= 10; i++) {
        canvas.drawCircle(
            ball + dir * (i * p * s * 0.045),
            2.5 + p * 1.5,
            Paint()
              ..color = Color.lerp(Colors.white, const Color(0xFFFF5252), p)!
                  .withValues(alpha: 1 - i / 12));
      }
      canvas.drawCircle(
          ball,
          GolfLogic.ballR * s * 2.2,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = colour);
    }
    if (g.sunkAt == null || g.now - g.sunkAt! < 200) {
      canvas.drawCircle(ball + const Offset(1.5, 2), GolfLogic.ballR * s,
          Paint()..color = Colors.black38);
      canvas.drawCircle(
          ball,
          GolfLogic.ballR * s,
          Paint()
            ..shader = RadialGradient(
                center: const Alignment(-0.4, -0.4),
                colors: [
                  Colors.white,
                  colour.withValues(alpha: 0.5)
                ]).createShader(
                Rect.fromCircle(center: ball, radius: GolfLogic.ballR * s)));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
