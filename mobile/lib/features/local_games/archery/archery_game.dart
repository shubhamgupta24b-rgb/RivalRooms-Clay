import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/ui/components.dart';
import '../../../core/audio/game_audio.dart';
import '../../guess_person/models/gp_player.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/game_hud.dart';
import '../shell/sky.dart';
import '../shell/ticking_play.dart';

/// Archery, side view. The field is 1 wide and [h] tall (y grows down). Players take turns:
/// pull back to draw the bow, let go to shoot. Wind pushes the arrow. Rings score 10 (gold
/// centre) down to 1. [arrowsEach] arrows each; most points wins.
class ArcheryLogic extends LocalGameLogic {
  static const h = 0.62, bowX = 0.1, bowY = 0.42, targetX = 0.9, ringR = 0.075;
  static const gravity = 0.9, maxSpeed = 1.55;
  final int players, arrowsEach;
  final Random rng;
  final List<int> score;
  final List<List<int>> shots; // each player's arrow scores
  int turn = 0;
  double wind = 0; // units/s² sideways (+ pushes right/up the range)
  double targetY = 0.36;
  (double x, double y, double vx, double vy)? arrow;
  final List<(double dy, int player)> stuck =
      []; // arrows in the target (offset from centre)
  int? lastScore;
  int lastAt = -10000, now = 0;
  double aimAngle = -0.2, aimPower = 0; // for drawing the bow while pulling

  ArcheryLogic({this.players = 2, this.arrowsEach = 5, Random? random})
      : rng = random ?? Random(),
        score = List.filled(players, 0),
        shots = List.generate(players, (_) => <int>[]) {
    _newWind();
  }

  void _newWind() {
    wind = (rng.nextDouble() - 0.5) *
        0.5 *
        (1 + shots.fold(0, (a, s) => a + s.length) / 6);
    targetY = 0.26 + rng.nextDouble() * 0.2;
  }

  @override
  bool get finished =>
      arrow == null && shots.every((s) => s.length >= arrowsEach);
  @override
  List<int> get scores => score;

  /// Live aim while pulling (local only; not sent anywhere).
  void aim(double angle, double power) {
    aimAngle = angle;
    aimPower = power.clamp(0.0, 1.0);
    notifyListeners();
  }

  /// The player whose turn it is shoots at [angle] (radians, up is negative) with [power] 0..1.
  void shoot(int player, double angle, double power) {
    if (forward('shoot', [player, angle, power])) return;
    if (finished || arrow != null || player != turn) return;
    final v = maxSpeed * (0.35 + 0.65 * power.clamp(0.0, 1.0));
    arrow = (bowX, bowY, cos(angle) * v, sin(angle) * v);
    aimPower = 0;
    HapticFeedback.lightImpact().ignore();
    GameAudio.sfx('throw');
    notifyListeners();
  }

  /// Ring score for an arrow [dy] from the centre.
  static int ringScore(double dy) {
    final d = dy.abs();
    if (d > ringR) return 0;
    return 10 - (d / (ringR / 10)).floor().clamp(0, 9);
  }

  @override
  void update(int ms) {
    final dt = ((ms - now) / 1000).clamp(0.0, 0.04);
    now = ms;
    final a = arrow;
    if (a == null) return;
    var (x, y, vx, vy) = a;
    for (var i = 0; i < 4; i++) {
      final s = dt / 4;
      vy += gravity * s;
      vx += wind * 0.12 * s;
      vy -= wind * 0.25 * s; // wind lifts or drops the arrow a little too
      final nx = x + vx * s, ny = y + vy * s;
      if (nx >= targetX) {
        // Where it crosses the target's plane.
        final t = (targetX - x) / (nx - x);
        final hitY = y + (ny - y) * t;
        _land(hitY - targetY, onTarget: (hitY - targetY).abs() <= ringR * 1.15);
        return;
      }
      if (ny > h || nx < 0) {
        _land(9, onTarget: false);
        return;
      }
      x = nx;
      y = ny;
    }
    arrow = (x, y, vx, vy);
    notifyListeners();
  }

  void _land(double dy, {required bool onTarget}) {
    final pts = onTarget ? ringScore(dy) : 0;
    if (onTarget) stuck.add((dy, turn));
    shots[turn].add(pts);
    score[turn] += pts;
    lastScore = pts;
    lastAt = now;
    arrow = null;
    if (pts >= 9) HapticFeedback.mediumImpact().ignore();
    GameAudio.sfx(pts >= 9 ? 'coin' : (pts > 0 ? 'hit' : 'tap'));
    turn = (turn + 1) % players;
    if (!finished) _newWind();
    if (stuck.length > 12) stuck.removeAt(0);
    notifyListeners();
  }
}

/// Where the arrow would cross the target plane for a shot (no wind/noise), for the bot.
double archeryLanding(ArcheryLogic g, double angle, double power) {
  final v = ArcheryLogic.maxSpeed * (0.35 + 0.65 * power);
  var x = ArcheryLogic.bowX,
      y = ArcheryLogic.bowY,
      vx = cos(angle) * v,
      vy = sin(angle) * v;
  for (var i = 0; i < 2000; i++) {
    const s = 0.005;
    vy += ArcheryLogic.gravity * s;
    vx += g.wind * 0.12 * s;
    vy -= g.wind * 0.25 * s;
    final nx = x + vx * s, ny = y + vy * s;
    if (nx >= ArcheryLogic.targetX)
      return y + (ny - y) * (ArcheryLogic.targetX - x) / (nx - x);
    if (ny > ArcheryLogic.h) return 99;
    x = nx;
    y = ny;
  }
  return 99;
}

final archeryInfo = LocalGameInfo(
  id: 'archery',
  title: 'Archery',
  emoji: '🏹',
  color: const Color(0xFF8D6E63),
  tagline: 'Draw, aim for the gold, mind the wind!',
  rules: const [
    'Pull back anywhere on the screen to draw the bow (further = stronger), aim, and let go.',
    'The wind (the windsock at the top) pushes your arrow. The target moves up and down between shots.',
    'Gold centre = 10 points, rings out to 1. 5 arrows each, taking turns. 1 to 4 players.',
  ],
  scoreUnit: 'points',
  splitScreen: false,
  minPlayers: 1,
  maxPlayers: 4,
  bot: botFor<ArcheryLogic>((g, b, now) {
    if (g.finished || g.arrow != null || g.turn != b.seat) return;
    if (!b.thinkFirst(g.shots[b.seat].length, now, 900, 1600)) return;
    // Try power and angle combinations; take the one landing closest to the gold, then wobble.
    var best = (0.0, 0.0), bestErr = double.infinity;
    for (var p = 0.55; p <= 1.0; p += 0.05) {
      for (var a = -0.6; a <= 0.1; a += 0.01) {
        final err = (archeryLanding(g, a, p) - g.targetY).abs();
        if (err < bestErr) {
          bestErr = err;
          best = (a, p);
        }
      }
    }
    g.shoot(b.seat, best.$1 + (b.rng.nextDouble() - 0.5) * 0.035, best.$2);
  }),
  online: RelaySpec<ArcheryLogic>(
    create: (n) => ArcheryLogic(players: n),
    save: (g) => {
      'score': g.score,
      'shots': [for (final s in g.shots) s],
      'turn': g.turn,
      'wind': g.wind,
      'ty': g.targetY,
      'arrow': g.arrow == null
          ? null
          : [g.arrow!.$1, g.arrow!.$2, g.arrow!.$3, g.arrow!.$4],
      'stuck': [
        for (final s in g.stuck) ...[s.$1, s.$2]
      ],
      'last': g.lastScore,
      'lastAt': g.lastAt,
      'now': g.now,
    },
    load: (g, s, me) {
      g.score.setAll(0, ints(s['score']));
      final sh = s['shots'] as List;
      for (var i = 0; i < g.players; i++) {
        g.shots[i]
          ..clear()
          ..addAll(ints(sh[i]));
      }
      g.turn = asInt(s['turn']);
      g.wind = asDouble(s['wind']);
      g.targetY = asDouble(s['ty']);
      final a = s['arrow'] == null ? null : doubles(s['arrow']);
      g.arrow = a == null ? null : (a[0], a[1], a[2], a[3]);
      final st = s['stuck'] as List;
      g.stuck
        ..clear()
        ..addAll([
          for (var i = 0; i + 1 < st.length; i += 2)
            ((st[i] as num).toDouble(), (st[i + 1] as num).toInt())
        ]);
      g.lastScore = nInt(s['last']);
      g.lastAt = asInt(s['lastAt']);
      g.now = asInt(s['now']);
    },
    apply: (g, from, name, a) {
      if (name == 'shoot' && asInt(a[0]) == from)
        g.shoot(from, asDouble(a[1]), asDouble(a[2]));
    },
    view: (context, g, players, me) =>
        _ArcheryView(g: g, players: players, me: me),
  ),
  play: (players, onFinished) => TickingPlay<ArcheryLogic>(
    create: () => ArcheryLogic(players: players.length),
    onFinished: onFinished,
    builder: (context, g) => _ArcheryView(g: g, players: players, bots: {
      for (var i = 0; i < players.length; i++)
        if (BotScope.isBot(context, i)) i
    }),
  ),
);

class _ArcheryView extends StatefulWidget {
  final ArcheryLogic g;
  final List<GpPlayer> players;
  final int? me; // online: this phone's player
  final Set<int> bots;
  const _ArcheryView(
      {required this.g, required this.players, this.me, this.bots = const {}});
  @override
  State<_ArcheryView> createState() => _ArcheryViewState();
}

class _ArcheryViewState extends State<_ArcheryView> {
  Offset? _from;

  bool get _myTurn =>
      !widget.bots.contains(widget.g.turn) &&
      (widget.me == null || widget.me == widget.g.turn) &&
      widget.g.arrow == null &&
      !widget.g.finished;

  (double, double) _pull(Offset from, Offset to, double w) {
    final d = from - to; // pulling back = shooting the other way
    return (
      atan2(d.dy, d.dx).clamp(-1.2, 0.5),
      (d.distance / (w * 0.45)).clamp(0.0, 1.0)
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final current = widget.players[g.turn];
    final showLast = g.lastScore != null && g.now - g.lastAt < 1400;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      child: Column(children: [
        GameHud(
            players: widget.players,
            scores: g.score,
            turn: g.finished ? null : g.turn,
            extra: (i) => '${g.arrowsEach - g.shots[i].length} left'),
        const SizedBox(height: 8),
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            final w = min(c.maxWidth, c.maxHeight / ArcheryLogic.h);
            return Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: _myTurn ? (d) => _from = d.localPosition : null,
                onPanUpdate: _myTurn
                    ? (d) {
                        final (a, p) = _pull(_from!, d.localPosition, w);
                        g.aim(a, p);
                      }
                    : null,
                onPanEnd: _myTurn
                    ? (_) {
                        if (g.aimPower > 0.08)
                          g.shoot(g.turn, g.aimAngle, g.aimPower);
                        _from = null;
                      }
                    : null,
                child: SizedBox(
                  width: w,
                  height: min(c.maxHeight,
                      w * 1.15), // extra sky above the range on tall screens
                  child: SceneFrame(
                      child: CustomPaint(
                          painter: _RangePainter(g, widget.players, w))),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 10),
        GameStatus(
          player: current,
          height: 52,
          turnText: g.finished
              ? 'All arrows shot!'
              : (_myTurn
                  ? '${current.whose} TURN · pull back and let go'
                  : '${current.name} is aiming…'),
          message: showLast
              ? (g.lastScore == 0
                  ? 'MISS!'
                  : (g.lastScore == 10 ? 'BULLSEYE! +10' : '+${g.lastScore}'))
              : null,
        ),
      ]),
    );
  }
}

class _RangePainter extends CustomPainter {
  final ArcheryLogic g;
  final List<GpPlayer> players;
  final double s;
  _RangePainter(this.g, this.players, this.s);

  @override
  void paint(Canvas canvas, Size size) {
    Offset o(double x, double y) => Offset(x * s, y * s);
    // Golden-hour sky with a low sun, warm hills and mowed grass (spec 5.3 #38).
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF4F6BD8),
                Color(0xFFF7A15C),
                Color(0xFFFFE2A6)
              ]).createShader(Offset.zero & size));
    drawSkyExtras(canvas, size, s, size.height - ArcheryLogic.h * s, g.now);
    canvas.translate(
        0, size.height - ArcheryLogic.h * s); // the range sits at the bottom
    canvas.drawCircle(
        o(0.3, 0.78), 0.36 * s, Paint()..color = const Color(0xFF8DB55A));
    canvas.drawCircle(
        o(0.85, 0.82), 0.42 * s, Paint()..color = const Color(0xFF6E9E45));
    canvas.drawRect(Rect.fromLTRB(0, 0.52 * s, size.width, size.height),
        Paint()..color = const Color(0xFF5E9B3A));
    final stripe = Paint()..color = const Color(0x14FFFFFF);
    for (var k = 0; k < 6; k++) {
      canvas.drawRect(
          Rect.fromLTRB(
              0, (0.52 + k * 0.08) * s, size.width, (0.56 + k * 0.08) * s),
          stripe);
    }
    // Windsock on a pole: it points downwind and stretches with the wind.
    final pole = o(0.5, 0.03);
    canvas.drawLine(
        pole,
        o(0.5, 0.16),
        Paint()
          ..color = const Color(0xFF5D4037)
          ..strokeWidth = 3);
    final dir = g.wind >= 0 ? 1.0 : -1.0;
    final len = (0.05 + min(g.wind.abs(), 1.5) * 0.08) * s;
    for (var k = 0; k < 4; k++) {
      final x0 = pole.dx + dir * len * k / 4,
          x1 = pole.dx + dir * len * (k + 1) / 4;
      final h0 = 0.026 * s * (1 - k * 0.15),
          h1 = 0.026 * s * (1 - (k + 1) * 0.15);
      canvas.drawPath(
          Path()
            ..moveTo(x0, pole.dy - h0 / 2)
            ..lineTo(x1, pole.dy - h1 / 2)
            ..lineTo(x1, pole.dy + h1 / 2)
            ..lineTo(x0, pole.dy + h0 / 2)
            ..close(),
          Paint()..color = k.isEven ? const Color(0xFFFF6B3D) : Colors.white);
    }
    // Wind chip: a drawn arrow and the strength.
    final wt = TextPainter(
      text: TextSpan(
          text: 'WIND ${(g.wind.abs() * 20).toStringAsFixed(1)}',
          style: const TextStyle(
              fontFamily: Fonts.display, color: Colors.white, fontSize: 13)),
      textDirection: TextDirection.ltr,
    )..layout();
    final chip = RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: o(0.5, 0.2), width: wt.width + 34, height: wt.height + 8),
        const Radius.circular(20));
    canvas.drawRRect(chip, Paint()..color = const Color(0x8C1B1036));
    wt.paint(canvas, Offset(chip.left + 8, chip.center.dy - wt.height / 2));
    paintIcon(canvas, g.wind >= 0 ? GameIcons.arrowRight : GameIcons.arrowLeft,
        Rect.fromLTWH(chip.right - 22, chip.center.dy - 8, 16, 16),
        color: Colors.white);
    // Target on its wooden stand, with a straw boss behind the face.
    final tc = o(ArcheryLogic.targetX, g.targetY);
    final legs = Paint()
      ..color = const Color(0xFF6D4C41)
      ..strokeWidth = 4;
    canvas.drawLine(tc, o(ArcheryLogic.targetX - 0.03, 0.56), legs);
    canvas.drawLine(tc, o(ArcheryLogic.targetX + 0.03, 0.56), legs);
    final boss = ArcheryLogic.ringR * 1.15 * s;
    canvas.drawOval(
        Rect.fromCenter(
            center: tc + Offset(boss * 0.12, 0),
            width: boss * 0.7,
            height: boss * 2),
        Paint()..color = const Color(0xFFD9B060));
    canvas.drawOval(
        Rect.fromCenter(
            center: tc + Offset(boss * 0.12, 0),
            width: boss * 0.7,
            height: boss * 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0xFF9C7430));
    const ringColors = [
      Colors.white,
      Colors.white,
      Color(0xFF212121),
      Color(0xFF212121),
      Color(0xFF1E88E5),
      Color(0xFF1E88E5),
      Color(0xFFE53935),
      Color(0xFFE53935),
      Color(0xFFFFD600),
      Color(0xFFFFD600)
    ];
    for (var i = 0; i < 10; i++) {
      final r = ArcheryLogic.ringR * (10 - i) / 10 * s;
      // Seen side-on: an ellipse, thin across, tall up and down.
      canvas.drawOval(
          Rect.fromCenter(center: tc, width: r * 0.5, height: r * 2),
          Paint()..color = ringColors[i]);
      canvas.drawOval(
          Rect.fromCenter(center: tc, width: r * 0.5, height: r * 2),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.6
            ..color = Colors.black26);
    }
    // Arrows stuck in the target.
    for (final (dy, p) in g.stuck) {
      final at = o(ArcheryLogic.targetX, g.targetY + dy);
      canvas.drawLine(
          at,
          at - Offset(0.05 * s, 0.006 * s),
          Paint()
            ..color = players[p % players.length].color
            ..strokeWidth = 3);
    }
    // The archer (in the shooter's colour) and the bow, drawn back while pulling.
    final bow = o(ArcheryLogic.bowX, ArcheryLogic.bowY);
    _archer(canvas, bow, players[g.turn % players.length].color);
    canvas.save();
    canvas.translate(bow.dx, bow.dy);
    canvas.rotate(g.aimAngle);
    final pull = g.aimPower * 0.04 * s;
    final limb = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..color = const Color(0xFF5D4037);
    canvas.drawArc(
        Rect.fromCenter(
            center: Offset(-0.02 * s, 0), width: 0.06 * s, height: 0.14 * s),
        -pi / 2,
        pi,
        false,
        limb);
    final string = Paint()
      ..color = Colors.white70
      ..strokeWidth = 1.2;
    canvas.drawLine(
        Offset(-0.02 * s, -0.07 * s), Offset(-pull - 0.02 * s, 0), string);
    canvas.drawLine(
        Offset(-0.02 * s, 0.07 * s), Offset(-pull - 0.02 * s, 0), string);
    if (g.arrow == null && !g.finished) {
      canvas.drawLine(
          Offset(-pull - 0.02 * s, 0),
          Offset(0.05 * s - pull, 0),
          Paint()
            ..color = const Color(0xFF3E2723)
            ..strokeWidth = 2.5);
    }
    canvas.restore();
    // Power and aim guide while pulling.
    if (g.aimPower > 0.05 && g.arrow == null) {
      final guide = Paint()..color = Colors.white.withValues(alpha: 0.6);
      final v = ArcheryLogic.maxSpeed * (0.35 + 0.65 * g.aimPower);
      var x = ArcheryLogic.bowX,
          y = ArcheryLogic.bowY,
          vx = cos(g.aimAngle) * v,
          vy = sin(g.aimAngle) * v;
      for (var i = 0; i < 9; i++) {
        for (var k = 0; k < 4; k++) {
          vy += ArcheryLogic.gravity * 0.01;
          x += vx * 0.01;
          y += vy * 0.01;
        }
        canvas.drawCircle(o(x, y), 2.5, guide);
      }
    }
    // The arrow in flight, pointing along its path.
    final a = g.arrow;
    if (a != null) {
      final (x, y, vx, vy) = a;
      final dir = Offset(vx, vy) / Offset(vx, vy).distance;
      final tip = o(x, y), tail = tip - dir * 0.06 * s;
      canvas.drawLine(
          tail,
          tip,
          Paint()
            ..color = const Color(0xFF3E2723)
            ..strokeWidth = 2.5);
      canvas.drawLine(
          tail,
          tail + Offset(-dir.dy, dir.dx) * 5 - dir * 4,
          Paint()
            ..color = players[g.turn % players.length].color
            ..strokeWidth = 2);
    }
  }

  /// A simple standing archer behind the bow: legs, body in the player's colour, head, and
  /// the bow arm reaching forward.
  void _archer(Canvas canvas, Offset bow, Color color) {
    final u = 0.01 * s;
    final hip = bow + Offset(-4.2 * u, 3.2 * u);
    final ink = Paint()
      ..color = const Color(0xFF2B2235)
      ..strokeWidth = 1.6 * u
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(hip, hip + Offset(-1.6 * u, 5.4 * u), ink);
    canvas.drawLine(hip, hip + Offset(1.6 * u, 5.4 * u), ink);
    final body = RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: hip - Offset(0, 2.6 * u), width: 3.6 * u, height: 5.6 * u),
        Radius.circular(1.6 * u));
    canvas.drawRRect(body, Paint()..color = color);
    canvas.drawRRect(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5 * u
          ..color = const Color(0xFF2B2235));
    final arm = Paint()
      ..color = const Color(0xFFF2C29B)
      ..strokeWidth = 1.2 * u
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(hip - Offset(0, 4.4 * u), bow - Offset(2 * u, 0), arm);
    final head = hip - Offset(0, 7.4 * u);
    canvas.drawCircle(head, 1.8 * u, Paint()..color = const Color(0xFFF2C29B));
    canvas.drawArc(Rect.fromCircle(center: head, radius: 1.9 * u), pi, pi, true,
        Paint()..color = const Color(0xFF4A2E1E));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
