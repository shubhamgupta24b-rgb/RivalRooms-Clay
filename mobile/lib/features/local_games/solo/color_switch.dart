import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/ui/components.dart';
import 'package:flutter/services.dart';
import '../../guess_person/models/gp_player.dart';
import '../shell/game_hud.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/local_game_shell.dart' show PauseButton;
import '../shell/ticking_play.dart';
import 'solo_common.dart';

const switchColors = [
  Color(0xFFFF1E6E),
  Color(0xFFFFD600),
  Color(0xFF00E5FF),
  Color(0xFF9C4DFF)
];

/// A spinning ring of 4 coloured quarters, with a ⭐ in the middle and a colour orb above.
class Ring {
  final double y; // world height of its centre
  final double radius, speed, start;
  bool star = true, orb = true;
  Ring(this.y, this.radius, this.speed, this.start);
  double angleAt(int ms) => start + ms / 1000 * speed;
}

/// Color Switch: tap to hop up. Pass through a ring only where its colour matches your
/// ball. Orbs change your colour; stars are points. The screen is 1 wide, [viewH] tall,
/// heights grow upwards.
class SwitchLogic extends SoloLogic {
  static const viewH = 1.7,
      ballR = 0.022,
      thick = 0.035,
      gravity = -2.4,
      hop = 0.95;
  final Random rng;
  final double pace;
  double y = 0.25, vy = 0, camera = 0;
  int colour = 0;
  bool started = false;
  final List<Ring> rings = [];
  int _last = 0;

  SwitchLogic({Random? random, this.pace = 1}) : rng = random ?? Random() {
    for (var i = 0; i < 4; i++) {
      _addRing();
    }
  }

  void _addRing() {
    final y = rings.isEmpty ? 0.95 : rings.last.y + 0.9;
    final n = rings.length;
    rings.add(Ring(
        y,
        0.2 + rng.nextDouble() * 0.05,
        pace * (1.1 + min(n * 0.08, 1.4)) * (rng.nextBool() ? 1 : -1),
        rng.nextDouble() * 2 * pi));
  }

  void tap() {
    if (over) return;
    started = true;
    vy = hop;
    HapticFeedback.selectionClick().ignore();
    notifyListeners();
  }

  /// Which colour of [ring] is at the ball's position (straight above or below its centre).
  int colourAt(Ring ring, {required bool above}) {
    final a = ((above ? -pi / 2 : pi / 2) - ring.angleAt(now)) % (2 * pi);
    return (a / (pi / 2)).floor() % 4;
  }

  @override
  void step(int now) {
    final dt = ((now - _last) / 1000).clamp(0.0, 0.04);
    _last = now;
    if (!started) {
      notifyListeners();
      return;
    }
    vy += gravity * dt;
    y += vy * dt;
    if (y - camera > viewH * 0.45) camera = y - viewH * 0.45;
    for (final r in rings) {
      // Star in the middle, orb just above the ring.
      if (r.star && (y - r.y).abs() < 0.04) {
        r.star = false;
        score++;
        HapticFeedback.lightImpact().ignore();
      }
      if (r.orb && (y - (r.y + r.radius + 0.17)).abs() < 0.04) {
        r.orb = false;
        colour = (colour + 1 + rng.nextInt(3)) % 4;
      }
      // Touching the ring band: the colour there must match.
      final d = (y - r.y).abs();
      if (d > r.radius - thick / 2 - ballR &&
          d < r.radius + thick / 2 + ballR) {
        if (colourAt(r, above: y > r.y) != colour) {
          HapticFeedback.heavyImpact().ignore();
          gameOver(1200);
          break;
        }
      }
    }
    if (rings.last.y < camera + viewH + 0.5) _addRing();
    rings.removeWhere((r) => r.y < camera - 0.5);
    if (y < camera - 0.05) gameOver(1000); // fell off the bottom
    notifyListeners();
  }

  Map<String, dynamic> dump() => {
        'y': y,
        'vy': vy,
        'cam': camera,
        'col': colour,
        'score': score,
        'go': started,
        'over': over,
        'rings': [
          for (final r in rings)
            [r.y, r.radius, r.speed, r.start, r.star ? 1 : 0, r.orb ? 1 : 0]
        ],
      };

  void adopt(Map<String, dynamic> m) {
    y = asDouble(m['y']);
    vy = asDouble(m['vy']);
    camera = asDouble(m['cam']);
    colour = asInt(m['col']);
    score = asInt(m['score']);
    started = m['go'] == true;
    rings
      ..clear()
      ..addAll([
        for (final row in m['rings'] as List)
          Ring((row[0] as num).toDouble(), (row[1] as num).toDouble(),
              (row[2] as num).toDouble(), (row[3] as num).toDouble())
            ..star = (row[4] as num) == 1
            ..orb = (row[5] as num) == 1,
      ]);
    if (m['over'] == true && !over) gameOver(0);
  }
}

/// Survival race. Same rings, separate phones. Highest star count wins; equal scores tie.
class SwitchDuel extends TimedDuel {
  final List<SwitchLogic> seats;
  final List<bool> out;
  SwitchDuel({int players = 2, int seed = 5, int durationMs = 90000})
      : seats = [
          for (var i = 0; i < players; i++) SwitchLogic(random: Random(seed))
        ],
        out = List.filled(players, false),
        super(durationMs);

  @override
  bool get finished => out.every((e) => e) || super.finished;
  @override
  List<int> get scores => [for (final s in seats) s.score];

  void tap(int player) {
    if (forward('tap', [player])) return;
    if (finished || elapsedMs < 3000 || out[player]) return;
    seats[player].tap();
  }

  @override
  void onUpdate() {
    if (elapsedMs < 3000) return;
    for (var i = 0; i < seats.length; i++) {
      if (out[i]) continue;
      seats[i].update(elapsedMs);
      if (seats[i].over) out[i] = true;
    }
  }

  Map<String, dynamic> save() => {
        't': elapsedMs,
        'out': out,
        'seats': [for (final s in seats) s.dump()]
      };
  void load(Map<String, dynamic> s) {
    elapsedMs = asInt(s['t']);
    final flags = s['out'] as List;
    final seatsJson = s['seats'] as List;
    for (var i = 0; i < seats.length && i < seatsJson.length; i++) {
      out[i] = flags[i] == true;
      seats[i].adopt(Map<String, dynamic>.from(seatsJson[i] as Map));
    }
  }
}

final colorSwitchInfo = LocalGameInfo(
  id: 'color_switch',
  title: 'Color Switch',
  emoji: '🎨',
  color: const Color(0xFFFF1E6E),
  tagline: 'Only pass through your own colour!',
  rules: const [
    'Tap to hop up. Don\'t fall off the bottom.',
    'Pass through a spinning ring only where it\'s the same colour as your ball.',
    'Online, both phones share the course. The higher score when you fall, or when time runs out, wins. A tie stays a tie.',
  ],
  scoreUnit: 'stars',
  splitScreen: false,
  minPlayers: 1,
  maxPlayers: 2,
  online: RelaySpec<SwitchDuel>(
    create: (n) => SwitchDuel(players: n, seed: 5),
    save: (g) => g.save(),
    load: (g, s, me) => g.load(s),
    apply: (g, from, name, a) {
      if (name == 'tap' && asInt(a[0]) == from) g.tap(from);
    },
    view: (context, g, players, me) =>
        _DuelView(g: g, players: players, me: me),
  ),
  play: (players, onFinished) => players.length < 2
      ? _SwitchMenu(onFinished: onFinished)
      : TickingPlay<SwitchDuel>(
          create: () => SwitchDuel(players: players.length),
          onFinished: onFinished,
          builder: (context, g) => _DuelView(g: g, players: players, me: 0)),
);

class _SwitchPainter extends CustomPainter {
  final SwitchLogic g;
  final double s;
  _SwitchPainter(this.g, this.s);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFF16161D));
    double sy(double y) => size.height - (y - g.camera) * s;
    final cx = size.width / 2;
    for (final r in g.rings) {
      final c = Offset(cx, sy(r.y));
      final rect = Rect.fromCircle(center: c, radius: r.radius * s);
      final a0 = r.angleAt(g.now);
      for (var q = 0; q < 4; q++) {
        canvas.drawArc(
            rect,
            a0 + q * pi / 2 + 0.02,
            pi / 2 - 0.04,
            false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = SwitchLogic.thick * s
              ..color = switchColors[q]);
      }
      if (r.star)
        paintIcon(canvas, GameIcons.star,
            Rect.fromCenter(center: c, width: 28, height: 28));
      if (r.orb) {
        final oc = Offset(cx, sy(r.y + r.radius + 0.17));
        for (var q = 0; q < 4; q++) {
          canvas.drawArc(Rect.fromCircle(center: oc, radius: 0.025 * s),
              q * pi / 2, pi / 2, true, Paint()..color = switchColors[q]);
        }
      }
    }
    final ball = Offset(cx, sy(g.y));
    canvas.drawCircle(ball, SwitchLogic.ballR * s * 1.8,
        Paint()..color = switchColors[g.colour].withValues(alpha: 0.25));
    canvas.drawCircle(
        ball, SwitchLogic.ballR * s, Paint()..color = switchColors[g.colour]);
    if (!g.started) {
      final tp = TextPainter(
          text: const TextSpan(
              text: 'TAP TO START',
              style: TextStyle(
                  fontFamily: Fonts.display,
                  color: Colors.white70,
                  fontSize: 18,
                  letterSpacing: 2)),
          textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, ball.dy + 30));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _SwitchMenu extends StatefulWidget {
  final void Function(List<int>) onFinished;
  const _SwitchMenu({required this.onFinished});
  @override
  State<_SwitchMenu> createState() => _SwitchMenuState();
}

class _SwitchMenuState extends State<_SwitchMenu> {
  double? pace;
  @override
  Widget build(BuildContext context) {
    final picked = pace;
    if (picked == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Align(alignment: Alignment.centerLeft, child: PauseButton()),
          const SizedBox(height: 8),
          const Text('Pick a pace',
              style: TextStyle(
                  fontFamily: Fonts.display,
                  color: Colors.white,
                  fontSize: 26)),
          const SizedBox(height: 12),
          for (final (label, p) in [
            ('Easy', 0.75),
            ('Medium', 1.0),
            ('Hard', 1.35)
          ])
            Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GoldButton(label,
                    height: 56, onPressed: () => setState(() => pace = p))),
        ]),
      );
    }
    return TickingPlay<SwitchLogic>(
      create: () => SwitchLogic(pace: picked),
      onFinished: widget.onFinished,
      builder: (context, g) {
        return SoloFrame(
          title: 'Color Switch',
          score: g.score,
          extra: g.started ? null : 'Tap to start',
          child: LayoutBuilder(builder: (context, c) {
            final w = min(c.maxWidth, c.maxHeight / SwitchLogic.viewH);
            return Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (_) => g.tap(),
                child: SizedBox(
                  width: w,
                  height: w * SwitchLogic.viewH,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CustomPaint(painter: _SwitchPainter(g, w)),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _DuelView extends StatelessWidget {
  final SwitchDuel g;
  final List<GpPlayer> players;
  final int me;
  const _DuelView({required this.g, required this.players, required this.me});
  @override
  Widget build(BuildContext context) {
    final seat = g.seats[me];
    return Column(children: [
      GameHud(
          players: players,
          scores: g.scores,
          trailing: Text(
              g.elapsedMs < 3000
                  ? '${(3 - g.elapsedMs / 1000).ceil()}'
                  : '${g.secondsLeft}s',
              style: const TextStyle(
                  fontFamily: Fonts.display,
                  color: Colors.white,
                  fontSize: 18))),
      Expanded(
        child: LayoutBuilder(builder: (context, c) {
          final w = min(c.maxWidth, c.maxHeight / SwitchLogic.viewH);
          return Center(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => g.tap(me),
              child: SizedBox(
                  width: w,
                  height: w * SwitchLogic.viewH,
                  child: CustomPaint(painter: _SwitchPainter(seat, w))),
            ),
          );
        }),
      ),
    ]);
  }
}
