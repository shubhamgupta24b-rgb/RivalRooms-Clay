import 'dart:math';
import 'package:flutter/material.dart';
import '../../guess_person/models/gp_player.dart';
import '../../../core/audio/game_audio.dart';
import '../../../core/ui/components.dart';
import '../shell/game_hud.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/local_game_shell.dart' show ResultScope;
import '../shell/split_screen.dart';
import '../shell/ticking_play.dart';

/// Each player has their own spinning log and throws knives into it from below. A knife
/// that hits another knife bounces off: the log is cleared and you lose [penalty] points.
/// Every [perLog] knives the log is full: +2 bonus and a fresh, faster log. First to
/// [target] points wins; otherwise the most points when time runs out.
class KnifeHitLogic extends TimedDuel {
  static const flightMs = 110;
  static const gap = 0.2; // radians: closer than this to a stuck knife is a hit
  final int players, target, perLog, penalty;
  final Random _rng;
  final List<int> points;
  final List<List<double>>
      stuck; // knife angles on each log, in the log's own frame
  final List<int> logs; // logs finished, makes the next one faster
  final List<int?> flyingSince;
  final List<int> stunUntil;
  final List<double> _spin; // each log's angle
  final List<double> _phase;
  final List<int> events; // counts hits (+) and bounces, for the view
  final List<bool> lastBounced;
  int _last = 0;

  KnifeHitLogic(
      {this.players = 2,
      this.target = 20,
      this.perLog = 8,
      this.penalty = 3,
      int durationMs = 45000,
      Random? random})
      : _rng = random ?? Random(),
        points = List.filled(players, 0),
        stuck = List.generate(players, (_) => <double>[]),
        logs = List.filled(players, 0),
        flyingSince = List.filled(players, null),
        stunUntil = List.filled(players, 0),
        _spin = List.filled(players, 0),
        _phase = List.filled(players, 0),
        events = List.filled(players, 0),
        lastBounced = List.filled(players, false),
        super(durationMs) {
    for (var p = 0; p < players; p++) {
      _phase[p] = _rng.nextDouble() * 6;
      _seed(p);
    }
  }

  /// A new log starts with a couple of knives already in it.
  void _seed(int p) {
    stuck[p].clear();
    for (var k = 0; k < 2; k++) {
      stuck[p].add(_rng.nextDouble() * 2 * pi);
    }
  }

  double angle(int p) => _spin[p];

  /// Where a knife thrown now would land, in the log's frame (knives hit the bottom, angle pi/2).
  double impactAngle(int p) => (pi / 2 - _spin[p]) % (2 * pi);

  bool wouldBounce(int p) {
    final a = impactAngle(p);
    return stuck[p].any((s) {
      final d = (s - a).abs() % (2 * pi);
      return min(d, 2 * pi - d) < gap;
    });
  }

  @override
  bool get finished => points.any((s) => s >= target) || super.finished;
  @override
  List<int> get scores => points;

  @override
  void onUpdate() {
    final dt = (elapsedMs - _last) / 1000;
    _last = elapsedMs;
    for (var p = 0; p < players; p++) {
      // Speed swells and eases, sometimes reversing, and grows with every finished log.
      final t = elapsedMs / 1000 + _phase[p];
      final speed = (1.6 + logs[p] * 0.35) *
          (0.55 + 0.45 * sin(t * 0.9)) *
          (sin(t * 0.23) > -0.6 ? 1 : -1);
      _spin[p] = (_spin[p] + speed * dt) % (2 * pi);
      final since = flyingSince[p];
      if (since != null && elapsedMs - since >= flightMs) {
        flyingSince[p] = null;
        _land(p);
      }
    }
  }

  void _land(int p) {
    events[p]++;
    if (wouldBounce(p)) {
      lastBounced[p] = true;
      points[p] = max(0, points[p] - penalty);
      stunUntil[p] = elapsedMs + 700;
      _seed(p);
      return;
    }
    lastBounced[p] = false;
    stuck[p].add(impactAngle(p));
    points[p]++;
    if (stuck[p].length >= perLog + 2) {
      points[p] += 2;
      logs[p]++;
      _seed(p);
    }
  }

  void throwKnife(int p) {
    if (forward('throw', [p])) return;
    if (finished || flyingSince[p] != null || elapsedMs < stunUntil[p]) return;
    flyingSince[p] = elapsedMs;
    notifyListeners();
  }
}

final knifeHitInfo = LocalGameInfo(
  id: 'knife_hit',
  title: 'Knife Hit',
  emoji: '🔪',
  color: const Color(0xFF8D5A2B),
  tagline: 'Stick it in the log, miss the knives!',
  rules: const [
    'Your log spins in your zone. Tap to throw a knife into it.',
    'Hit a knife already in the log and it bounces: the log is cleared and you lose 3 points.',
    'Fill a log for +2. First to 20 points wins, or the most after 45 seconds. 2 to 4 players.',
  ],
  scoreUnit: 'points',
  splitScreen: true,
  maxPlayers: 4,
  bot: botFor<KnifeHitLogic>((g, b, now) {
    if (g.finished || !b.due(now)) return;
    // Throws when the spot looks clear; now and then it misjudges.
    if (!g.wouldBounce(b.seat) || b.chance(0.08)) {
      g.throwKnife(b.seat);
      b.wait(now, 380, 800);
    }
  }),
  online: RelaySpec<KnifeHitLogic>(
    create: (n) => KnifeHitLogic(players: n),
    save: (g) => {
      't': g.elapsedMs,
      'points': g.points,
      'stuck': g.stuck,
      'logs': g.logs,
      'fly': g.flyingSince,
      'stun': g.stunUntil,
      'spin': g._spin,
      'ev': g.events,
      'bounced': g.lastBounced,
    },
    load: (g, s, me) {
      g.elapsedMs = asInt(s['t']);
      g.points.setAll(0, ints(s['points']));
      final stuck = s['stuck'] as List;
      for (var p = 0; p < g.players; p++) {
        g.stuck[p]
          ..clear()
          ..addAll(doubles(stuck[p]));
      }
      g.logs.setAll(0, ints(s['logs']));
      g.flyingSince.setAll(0, nInts(s['fly']));
      g.stunUntil.setAll(0, ints(s['stun']));
      g._spin.setAll(0, doubles(s['spin']));
      g.events.setAll(0, ints(s['ev']));
      g.lastBounced
          .setAll(0, [for (final b in s['bounced'] as List) b == true]);
    },
    apply: (g, from, name, a) {
      if (name == 'throw' && asInt(a[0]) == from) g.throwKnife(from);
    },
    // Each phone shows its own log, with everyone's points and the clock along the top.
    view: (context, g, players, me) => Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(Space.s, Space.xs, Space.s, 0),
        child: ScoreHud(
          title: 'Knife Hit',
          state: '${g.secondsLeft}s left · first to ${g.target}',
          players: players,
          score: (i) => '${g.points[i]}',
          tag: (i) => i == me ? 'YOU' : null,
        ),
      ),
      Expanded(child: _KnifeZone(g: g, player: players[me], index: me)),
    ]),
  ),
  play: (players, onFinished) => TickingPlay<KnifeHitLogic>(
    create: () => KnifeHitLogic(players: players.length),
    onFinished: onFinished,
    builder: (context, g) {
      ResultScope.of(context)?.subtitle = g.points.any((s) => s >= g.target)
          ? 'First to ${g.target}'
          : (g.finished ? 'Time up' : null);
      return PlayerZones(
        count: players.length,
        colors: [for (final p in players) p.color],
        middle: DuelMiddleBar(
            players: players,
            scores: g.scores,
            secondsLeft: g.secondsLeft,
            progress: g.progress),
        center: ZoneCenterChip('${g.secondsLeft}s'),
        zone: (i) => _KnifeZone(g: g, player: players[i], index: i),
      );
    },
  ),
);

class _KnifeZone extends StatelessWidget {
  final KnifeHitLogic g;
  final GpPlayer player;
  final int index;
  const _KnifeZone(
      {required this.g, required this.player, required this.index});

  @override
  Widget build(BuildContext context) {
    final stunned = g.elapsedMs < g.stunUntil[index];
    return MomentWatcher<int>(
      value: g.events[index],
      onChange: (fx, _, __) {
        if (g.lastBounced[index]) {
          GameAudio.sfx('hit');
          haptic(HapticWeight.heavy);
        } else {
          GameAudio.sfx('tap');
          haptic(HapticWeight.light);
        }
      },
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => g.throwKnife(index),
        child: Semantics(
          button: true,
          label:
              '${player.name}: ${g.points[index]} points. Tap to throw a knife.',
          excludeSemantics: true,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                PlayerBadge(
                    index: PlayerPalette.indexOf(player.color) ?? index,
                    size: 18,
                    color: player.color,
                    initial: player.name),
                const SizedBox(width: 6),
                Flexible(
                    child: Text(
                        '${player.name}  Lv ${g.logs[index] + 1}  ${g.points[index]}/${g.target}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: Fonts.body,
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14))),
                if (stunned) ...[
                  const SizedBox(width: 8),
                  const Text('BOUNCED -3',
                      style: TextStyle(
                          fontFamily: Fonts.body,
                          color: StatusColors.danger,
                          fontWeight: FontWeight.w900,
                          fontSize: 12))
                ],
              ]),
            ),
            Expanded(
              child: RepaintBoundary(
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _LogPainter(
                    angle: g.angle(index),
                    stuck: g.stuck[index],
                    flying: g.flyingSince[index] == null
                        ? null
                        : (g.elapsedMs - g.flyingSince[index]!) /
                            KnifeHitLogic.flightMs,
                    ready: !stunned,
                    color: player.color,
                    left: KnifeHitLogic.gap,
                    filled: g.stuck[index].length - 2,
                    perLog: g.perLog,
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// The log (a wooden disc with rings), the knives stuck in it, and the next knife below.
class _LogPainter extends CustomPainter {
  final double angle;
  final List<double> stuck;
  final double? flying; // 0..1 while a knife is in the air
  final bool ready;
  final Color color;
  final double left;
  final int filled, perLog;
  _LogPainter(
      {required this.angle,
      required this.stuck,
      required this.flying,
      required this.ready,
      required this.color,
      required this.left,
      required this.filled,
      required this.perLog});

  void _knife(Canvas canvas, Offset tip, double dir, double len, Color handle) {
    // dir: the way the blade points. Blade first, then the handle behind it.
    final u = Offset(cos(dir), sin(dir)), n = Offset(-u.dy, u.dx);
    final bladeEnd = tip - u * len * 0.55;
    final blade = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(bladeEnd.dx + n.dx * len * 0.07, bladeEnd.dy + n.dy * len * 0.07)
      ..lineTo(bladeEnd.dx - n.dx * len * 0.07, bladeEnd.dy - n.dy * len * 0.07)
      ..close();
    canvas.drawPath(blade, Paint()..color = const Color(0xFFDCE3EA));
    canvas.drawPath(
        blade,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0xFF7C8794));
    canvas.drawLine(
        bladeEnd,
        bladeEnd - u * len * 0.45,
        Paint()
          ..strokeWidth = len * 0.13
          ..strokeCap = StrokeCap.round
          ..color = handle);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final r = min(size.width * 0.32, size.height * 0.3);
    final c = Offset(size.width / 2, size.height * 0.4);
    final len = r * 0.75;
    // Knives in the log stick out from its rim.
    for (final s in stuck) {
      final a = s + angle;
      final tip = c + Offset(cos(a), sin(a)) * (r * 0.8);
      _knife(canvas, tip, a + pi, len, const Color(0xFF5A4636));
    }
    canvas.drawCircle(
        c + const Offset(0, 5), r, Paint()..color = Colors.black38);
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(colors: const [
            Color(0xFFE2B57A),
            Color(0xFFB9834A),
            Color(0xFF7F5428)
          ], stops: const [
            0,
            0.75,
            1
          ]).createShader(Rect.fromCircle(center: c, radius: r)));
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = const Color(0x557A4A20);
    for (final k in [0.25, 0.45, 0.65, 0.85]) {
      canvas.drawCircle(c, r * k, ring);
    }
    // A notch so you can see it spin.
    canvas.drawLine(
        c,
        c + Offset(cos(angle), sin(angle)) * r * 0.9,
        Paint()
          ..strokeWidth = 2
          ..color = const Color(0x667A4A20));
    // Progress pips under the log.
    for (var k = 0; k < perLog; k++) {
      final x = c.dx + (k - (perLog - 1) / 2) * 12;
      canvas.drawCircle(Offset(x, c.dy + r + 14), 4,
          Paint()..color = k < filled ? Brand.gold : Colors.white24);
    }
    // The next knife waits at the bottom, pointing up; in flight it shoots to the log.
    final start = Offset(c.dx, size.height - 8);
    final end = c + Offset(0, r * 0.8);
    if (flying case final f?) {
      _knife(
          canvas,
          Offset.lerp(start - Offset(0, len), end, f.clamp(0.0, 1.0))!,
          -pi / 2,
          len,
          color);
    } else if (ready) {
      _knife(canvas, start - Offset(0, len), -pi / 2, len, color);
    }
  }

  @override
  bool shouldRepaint(_LogPainter o) => true;
}
