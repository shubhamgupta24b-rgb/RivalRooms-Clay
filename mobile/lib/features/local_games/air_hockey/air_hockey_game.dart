import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../guess_person/models/gp_player.dart';
import '../../../core/ui/components.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_shell.dart' show PauseButton;
import '../shell/local_game_logic.dart';
import '../shell/ticking_play.dart';

/// Simple 2D vector for the table physics.
class V {
  static const zero = V(0, 0);
  final double x, y;
  const V(this.x, this.y);
  V operator +(V o) => V(x + o.x, y + o.y);
  V operator -(V o) => V(x - o.x, y - o.y);
  V operator *(double k) => V(x * k, y * k);
  double dot(V o) => x * o.x + y * o.y;
  double get length => sqrt(x * x + y * y);
}

/// Air hockey on a 1 x [length] table. Player 1 defends the bottom goal, player 2 the
/// top. Each moves a mallet inside their own half. First to [target] goals, or the
/// leader when the clock runs out.
class AirHockeyLogic extends TimedDuel {
  static const length = 1.6;
  static const puckR = 0.045, malletR = 0.075, goalHalf = 0.18, maxSpeed = 2.6;
  final int target;
  final List<int> goals = [0, 0];
  V puck = const V(0.5, length / 2);
  V vel = V.zero;
  final List<V> mallet = [const V(0.5, length - 0.2), const V(0.5, 0.2)];
  final List<V> _malletVel = [V.zero, V.zero];
  int? lastGoalBy;
  int _last = 0;
  int? _resumeAt;

  AirHockeyLogic({this.target = 5, int durationMs = 120000})
      : super(durationMs);

  @override
  List<int> get scores => goals;
  @override
  bool get finished => super.finished || goals.any((g) => g >= target);
  bool get paused => _resumeAt != null;

  /// Moves a player's mallet to [to] (table coordinates), kept inside their own half.
  void moveMallet(int p, V to) {
    final minY = p == 0 ? length / 2 + malletR : malletR;
    final maxY = p == 0 ? length - malletR : length / 2 - malletR;
    final clamped = V(to.x.clamp(malletR, 1 - malletR), to.y.clamp(minY, maxY));
    if (forward('mallet', [p, to.x, to.y])) {
      mallet[p] = clamped; // show my own mallet straight away
      changed();
      return;
    }
    _malletVel[p] =
        (clamped - mallet[p]) * 60; // roughly per-frame movement -> per second
    mallet[p] = clamped;
  }

  @override
  void onUpdate() {
    final dt = ((elapsedMs - _last) / 1000).clamp(0.0, 0.05);
    _last = elapsedMs;
    final resume = _resumeAt;
    if (resume != null) {
      if (elapsedMs < resume) return;
      _resumeAt = null;
    }
    const steps = 4;
    for (var i = 0; i < steps; i++) {
      _step(dt / steps);
      if (paused) break;
    }
    for (var p = 0; p < 2; p++) {
      _malletVel[p] =
          _malletVel[p] * 0.6; // stop "pushing" when the finger stops
    }
  }

  void _step(double dt) {
    puck = puck + vel * dt;
    vel = vel * (1 - 0.35 * dt); // table friction
    // Side walls.
    if (puck.x < puckR && vel.x < 0 || puck.x > 1 - puckR && vel.x > 0)
      vel = V(-vel.x * 0.95, vel.y);
    puck = V(puck.x.clamp(puckR, 1 - puckR), puck.y);
    // End walls and goals.
    final inGoalMouth = (puck.x - 0.5).abs() < goalHalf;
    if (puck.y < -puckR && inGoalMouth) return _goal(0);
    if (puck.y > length + puckR && inGoalMouth) return _goal(1);
    if (!inGoalMouth) {
      if (puck.y < puckR && vel.y < 0 || puck.y > length - puckR && vel.y > 0)
        vel = V(vel.x, -vel.y * 0.95);
      puck = V(puck.x, puck.y.clamp(puckR, length - puckR));
    }
    // Mallets.
    for (var p = 0; p < 2; p++) {
      final d = puck - mallet[p];
      final dist = d.length;
      if (dist < puckR + malletR && dist > 0) {
        final n = d * (1 / dist);
        puck = mallet[p] + n * (puckR + malletR);
        final rel = vel - _malletVel[p];
        final along = rel.dot(n);
        if (along < 0) vel = vel - n * (1.9 * along);
        vel = vel + n * 0.15; // always a little kick away from the mallet
        // A mallet must never shove the puck through a wall (only into a goal mouth).
        final mouth = (puck.x - 0.5).abs() < goalHalf;
        puck = V(puck.x.clamp(puckR, 1 - puckR),
            mouth ? puck.y : puck.y.clamp(puckR, length - puckR));
      }
    }
    final speed = vel.length;
    if (speed > maxSpeed) vel = vel * (maxSpeed / speed);
  }

  void _goal(int scorer) {
    goals[scorer]++;
    HapticFeedback.heavyImpact().ignore();
    lastGoalBy = scorer;
    // Puck restarts in the conceding player's half.
    puck = V(0.5, scorer == 0 ? length * 0.3 : length * 0.7);
    vel = V.zero;
    _resumeAt = elapsedMs + 900;
  }
}

final airHockeyInfo = LocalGameInfo(
  id: 'air_hockey',
  title: 'Air Hockey',
  emoji: '🏒',
  color: const Color(0xFF4D96FF),
  tagline: 'Smash the puck into their goal!',
  rules: const [
    'Drag your mallet around your half of the table.',
    'Hit the puck into the goal at the far end.',
    'First to 5 goals wins (or the leader after 2 minutes).',
  ],
  scoreUnit: 'goals',
  splitScreen: true,
  bot: botFor<AirHockeyLogic>((g, b, now) {
    // The computer defends the top goal: chase the puck in its half, otherwise guard the goal.
    final last = (b.memory['t'] as int?) ?? now;
    b.memory['t'] = now;
    final dt = ((now - last) / 1000).clamp(0.0, 0.05);
    final me = g.mallet[b.seat];
    // Go for the puck in its half, or a slow one sitting on the centre line within reach.
    final slow = g.vel.length < 0.3;
    final inMyHalf = g.puck.y <
        AirHockeyLogic.length / 2 + (slow ? AirHockeyLogic.puckR + 0.02 : 0);
    // Strike the puck a little off-centre so shots angle off the walls instead of straight at the keeper.
    if (!inMyHalf) b.memory['side'] = b.chance(0.5) ? -1.0 : 1.0;
    final side = (b.memory['side'] as double?) ?? 1.0;
    // Puck trapped against my back wall: hit it from the middle side so it bounces off the side wall
    // and back into play, instead of pinning it in the corner.
    final trapped = g.puck.y < 0.15;
    final target = trapped
        ? V(g.puck.x + (g.puck.x > 0.5 ? -0.13 : 0.13), g.puck.y + 0.01)
        : inMyHalf
            ? V(g.puck.x + side * 0.05 + b.aimNoise(0.35),
                g.puck.y - 0.06 + b.aimNoise(0.2))
            : V(0.5 + (g.puck.x - 0.5) * 0.5, 0.18);
    final d = target - me;
    final step = 1.4 * b.skill.tracking * dt;
    final len = d.length;
    g.moveMallet(b.seat, len <= step ? target : me + d * (step / len));
  }),
  online: RelaySpec<AirHockeyLogic>(
    create: (n) => AirHockeyLogic(),
    save: (g) => {
      't': g.elapsedMs,
      'goals': g.goals,
      'puck': [g.puck.x, g.puck.y],
      'm': [g.mallet[0].x, g.mallet[0].y, g.mallet[1].x, g.mallet[1].y],
      'last': g.lastGoalBy,
      'paused': g.paused,
    },
    load: (g, s, me) {
      g.elapsedMs = asInt(s['t']);
      g.goals.setAll(0, ints(s['goals']));
      final p = doubles(s['puck']), m = doubles(s['m']);
      g.puck = V(p[0], p[1]);
      for (var i = 0; i < 2; i++) {
        if (i != me)
          g.mallet[i] = V(m[i * 2], m[i * 2 + 1]); // keep my own, it's ahead
      }
      g.lastGoalBy = nInt(s['last']);
      g._resumeAt = s['paused'] == true ? 1 << 40 : null;
    },
    apply: (g, from, name, a) {
      if (name == 'mallet' && asInt(a[0]) == from)
        g.moveMallet(from, V(asDouble(a[1]), asDouble(a[2])));
    },
    continuous: const {'mallet'},
    // Player 2 sees the table turned round, so their goal is at the bottom too.
    view: (context, g, players, me) => RotatedBox(
      quarterTurns: me == 1 ? 2 : 0,
      child: _PlainRink(players: players, g: g),
    ),
  ),
  play: (players, onFinished) => TickingPlay<AirHockeyLogic>(
    create: () => AirHockeyLogic(),
    onFinished: onFinished,
    builder: (context, g) => _PlainRink(players: players, g: g),
  ),
);

/// Scores sit beside the ice. Nothing is drawn on top of the numbers, and the
/// pause control is above the rink, outside the mallet touch area.
class _PlainRink extends StatelessWidget {
  final List<GpPlayer> players;
  final AirHockeyLogic g;
  const _PlainRink({required this.players, required this.g});

  @override
  Widget build(BuildContext context) {
    final farUpright = BotScope.isBot(context, 1);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 12, 0),
        child: Row(children: [
          const PauseButton(),
          const Spacer(),
          Text('${g.secondsLeft}s',
              style: const TextStyle(
                  fontFamily: Fonts.display, color: Colors.white, fontSize: 22)),
        ]),
      ),
      Expanded(
        child: Row(children: [
          _RinkScore(player: players[0], score: g.scores[0]),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: TableView(players: players, logic: g),
            ),
          ),
          _RinkScore(
              player: players[1], score: g.scores[1], upright: farUpright),
        ]),
      ),
    ]);
  }
}

class _RinkScore extends StatelessWidget {
  final GpPlayer player;
  final int score;
  final bool upright;
  const _RinkScore(
      {required this.player, required this.score, this.upright = true});

  @override
  Widget build(BuildContext context) {
    final chip = SizedBox(
      width: 64,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(player.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w800,
                fontSize: 11)),
        Text('$score',
            style: TextStyle(
                fontFamily: Fonts.display,
                fontSize: 32,
                height: 1,
                color: player.color)),
      ]),
    );
    return RotatedBox(quarterTurns: upright ? 0 : 2, child: chip);
  }
}

/// Shared table widget: draws the table and turns touches into mallet moves.
/// Touches in the bottom half drive player 1, the top half player 2.
class TableView extends StatefulWidget {
  final List<GpPlayer> players;
  final AirHockeyLogic logic;
  const TableView({super.key, required this.players, required this.logic});
  @override
  State<TableView> createState() => _TableViewState();
}

class _TableViewState extends State<TableView> {
  final _fingers = <int, int>{}; // pointer -> player
  Rect _table = Rect.zero;

  V _toTable(Offset p) => V(
      (p.dx - _table.left) / _table.width, (p.dy - _table.top) / _table.width);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      // Fit a 1 x length table into the space.
      // Leave room for the rail drawn around the ice (3.5% of the width each side).
      final w =
          min(c.maxWidth / 1.07, c.maxHeight / (AirHockeyLogic.length + 0.07));
      final h = w * AirHockeyLogic.length;
      _table = Rect.fromLTWH((c.maxWidth - w) / 2, (c.maxHeight - h) / 2, w, h);
      void move(PointerEvent e) {
        final p = _fingers[e.pointer];
        if (p != null) widget.logic.moveMallet(p, _toTable(e.localPosition));
      }

      return Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) {
          _fingers[e.pointer] = e.localPosition.dy > c.maxHeight / 2 ? 0 : 1;
          move(e);
        },
        onPointerMove: move,
        onPointerUp: (e) => _fingers.remove(e.pointer),
        onPointerCancel: (e) => _fingers.remove(e.pointer),
        child: CustomPaint(
            size: c.biggest,
            painter: _TablePainter(widget.logic, _table,
                widget.players.map((p) => p.color).toList())),
      );
    });
  }
}

class _TablePainter extends CustomPainter {
  final AirHockeyLogic g;
  final Rect table;
  final List<Color> colors;
  final V puck;
  final List<V> mallets;
  _TablePainter(this.g, this.table, this.colors)
      : puck = g.puck,
        mallets = List.of(g.mallet);

  // Rink palette.
  static const _rail = [Color(0xFF39404F), Color(0xFF1C212B)];
  static const _ice = [Color(0xFFF3F8FF), Color(0xFFDDE9F7)];
  static const _marking = Color(0xFFE5484D);
  static const _puck = Color(0xFF15181F);

  @override
  void paint(Canvas canvas, Size size) {
    final s = table.width;
    Offset at(V v) => Offset(table.left + v.x * s, table.top + v.y * s);
    // Rail, then the ice inside it.
    final outer = RRect.fromRectAndRadius(
        table.inflate(s * 0.035), Radius.circular(s * 0.11));
    canvas.drawRRect(
        outer.shift(const Offset(0, 6)), Paint()..color = Colors.black54);
    canvas.drawRRect(
        outer,
        Paint()
          ..shader = const LinearGradient(
                  colors: _rail,
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter)
              .createShader(outer.outerRect));
    final ice = RRect.fromRectAndRadius(table, Radius.circular(s * 0.08));
    canvas.drawRRect(
        ice,
        Paint()
          ..shader = const LinearGradient(
                  colors: _ice,
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter)
              .createShader(table));
    canvas.save();
    canvas.clipRRect(ice);
    // Air holes.
    final hole = Paint()..color = const Color(0x1F2A3B55);
    for (var y = s * 0.05; y < table.height; y += s * 0.07) {
      for (var x = s * 0.05; x < s; x += s * 0.07) {
        canvas.drawCircle(Offset(table.left + x, table.top + y), 1.2, hole);
      }
    }
    // Markings: centre line and circle, goal creases in each player's colour.
    final line = Paint()
      ..color = _marking.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawLine(at(const V(0, AirHockeyLogic.length / 2)),
        at(const V(1, AirHockeyLogic.length / 2)), line);
    canvas.drawCircle(
        at(const V(0.5, AirHockeyLogic.length / 2)), s * 0.06, line);
    for (final (y, c) in [
      (0.0, colors[1]),
      (AirHockeyLogic.length, colors[0])
    ]) {
      canvas.drawArc(
          Rect.fromCircle(center: at(V(0.5, y)), radius: s * 0.24),
          y == 0 ? 0 : 3.1416,
          3.1416,
          false,
          Paint()
            ..color = c.withValues(alpha: 0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3);
    }
    canvas.restore();
    // Goal slots in the rail.
    for (final (y, c) in [
      (0.0, colors[1]),
      (AirHockeyLogic.length, colors[0])
    ]) {
      canvas.drawLine(
          at(V(0.5 - AirHockeyLogic.goalHalf, y)),
          at(V(0.5 + AirHockeyLogic.goalHalf, y)),
          Paint()
            ..color = const Color(0xFF0A0C10)
            ..strokeWidth = 12
            ..strokeCap = StrokeCap.round);
      canvas.drawLine(
          at(V(0.5 - AirHockeyLogic.goalHalf, y)),
          at(V(0.5 + AirHockeyLogic.goalHalf, y)),
          Paint()
            ..color = c
            ..strokeWidth = 4
            ..strokeCap = StrokeCap.round);
    }
    // Puck (with shadow), then the mallets on top.
    final pc = at(puck), pr = AirHockeyLogic.puckR * s;
    canvas.drawCircle(
        pc + const Offset(2, 3), pr, Paint()..color = Colors.black26);
    canvas.drawCircle(
        pc,
        pr,
        Paint()
          ..shader = RadialGradient(
                  center: const Alignment(-0.3, -0.4),
                  colors: [const Color(0xFF4A5060), _puck])
              .createShader(Rect.fromCircle(center: pc, radius: pr)));
    canvas.drawCircle(
        pc,
        pr * 0.62,
        Paint()
          ..color = Colors.white24
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    for (var p = 0; p < 2; p++) {
      final m = at(mallets[p]), mr = AirHockeyLogic.malletR * s;
      canvas.drawCircle(
          m + const Offset(3, 5), mr, Paint()..color = Colors.black38);
      canvas.drawCircle(
          m,
          mr,
          Paint()
            ..shader =
                RadialGradient(center: const Alignment(-0.35, -0.4), colors: [
              Color.lerp(colors[p], Colors.white, 0.35)!,
              colors[p],
              Color.lerp(colors[p], Colors.black, 0.35)!
            ]).createShader(Rect.fromCircle(center: m, radius: mr)));
      // The handle knob.
      canvas.drawCircle(m, mr * 0.42,
          Paint()..color = Color.lerp(colors[p], Colors.black, 0.25)!);
      canvas.drawCircle(m - Offset(mr * 0.1, mr * 0.12), mr * 0.3,
          Paint()..color = Color.lerp(colors[p], Colors.white, 0.45)!);
    }
    if (g.paused && g.lastGoalBy != null) {
      final tp = TextPainter(
        text: TextSpan(
          text: 'GOAL!',
          style: TextStyle(
              fontFamily: Fonts.display,
              color: colors[g.lastGoalBy!],
              fontSize: s * 0.16,
              shadows: const [
                Shadow(
                    color: Color(0x99000000),
                    blurRadius: 8,
                    offset: Offset(0, 4))
              ]),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, table.center - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_TablePainter old) => true;
}
