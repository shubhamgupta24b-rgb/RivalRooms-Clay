import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/ui/components.dart';
import '../../guess_person/models/gp_player.dart';
import '../shell/game_hud.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/ticking_play.dart';
import '../solo/solo_common.dart';

const fruitKinds = [
  Color(0xFFFF4D6D),
  Color(0xFFFFBE0B),
  Color(0xFF7DDE92),
  Color(0xFFFF8C42),
  Color(0xFFC77DFF)
];

class CutFruit {
  double x, y, vx, vy;
  final int kind; // -1 bomb
  final double r;
  bool sliced = false;
  bool missed = false;
  CutFruit(this.x, this.y, this.vx, this.vy, this.kind, this.r);
}

bool _hits(double x1, double y1, double x2, double y2, CutFruit f) {
  final dx = x2 - x1, dy = y2 - y1;
  final len2 = dx * dx + dy * dy;
  final t = len2 == 0
      ? 0.0
      : (((f.x - x1) * dx + (f.y - y1) * dy) / len2).clamp(0.0, 1.0);
  final px = x1 + dx * t, py = y1 + dy * t;
  return (px - f.x) * (px - f.x) + (py - f.y) * (py - f.y) <= f.r * f.r;
}

/// Fruits rise from the bottom of the screen. Slice them; a sliced bomb ends the run.
class FruitCutLogic extends SoloLogic {
  static const width = 1.0, height = 1.7;
  final Random rng;
  final List<CutFruit> fruits = [];
  int lives = 3;
  double _spawn = 0.4;
  int _last = 0;

  FruitCutLogic({Random? random}) : rng = random ?? Random();

  void swipe(double x1, double y1, double x2, double y2) {
    if (over) return;
    if ((Offset(x2, y2) - Offset(x1, y1)).distance < 0.02) return;
    for (final f in fruits) {
      if (f.sliced || f.missed) continue;
      if (!_hits(x1, y1, x2, y2, f)) continue;
      f.sliced = true;
      f.vx *= 0.2;
      f.vy = -0.4;
      if (f.kind < 0) {
        gameOver(900);
        return;
      }
      score++;
    }
    notifyListeners();
  }

  @override
  void step(int now) {
    final dt = ((now - _last) / 1000).clamp(0.0, 0.05);
    _last = now;
    _spawn -= dt;
    if (_spawn <= 0) {
      _launch(false);
      if (score >= 3 &&
          rng.nextDouble() < min(0.22, 0.08 + score * 0.004) &&
          !fruits.any((f) => f.kind < 0 && !f.sliced)) {
        _launch(true);
      }
      _spawn = max(0.35, 1.15 - score * 0.02);
    }
    for (final f in fruits) {
      f.vy += 1.8 * dt;
      f.x += f.vx * dt;
      f.y += f.vy * dt;
      if (!f.sliced && !f.missed && f.y > height + 0.05 && f.vy > 0) {
        f.missed = true;
        if (f.kind >= 0) {
          lives--;
          if (lives <= 0) gameOver(800);
        }
      }
    }
    fruits.removeWhere((f) => f.y > height + 0.4);
    notifyListeners();
  }

  void _launch(bool bomb) {
    final x = 0.12 + rng.nextDouble() * 0.76;
    fruits.add(CutFruit(
        x,
        height * 0.92,
        (rng.nextDouble() - 0.5) * 0.55,
        -(1.35 + rng.nextDouble() * 0.55),
        bomb ? -1 : rng.nextInt(fruitKinds.length),
        bomb ? 0.055 : 0.045));
  }
}

class FruitRace extends TimedDuel {
  final List<FruitCutLogic> boards;
  final List<bool> out;
  FruitRace({int players = 2, int? seed, int durationMs = 60000})
      : boards = [
          for (var i = 0; i < players; i++)
            FruitCutLogic(random: Random(seed ?? 1))
        ],
        out = List.filled(players, false),
        super(durationMs);

  @override
  bool get finished => out.every((e) => e) || super.finished;
  @override
  List<int> get scores => [for (final b in boards) b.score];

  void swipe(int player, double x1, double y1, double x2, double y2) {
    if (forward('swipe', [player, x1, y1, x2, y2])) return;
    if (finished || player < 0 || player >= boards.length || out[player])
      return;
    boards[player].swipe(x1, y1, x2, y2);
    if (boards[player].over) out[player] = true;
    notifyListeners();
  }

  @override
  void onUpdate() {
    for (var i = 0; i < boards.length; i++) {
      if (!out[i]) {
        boards[i].update(elapsedMs);
        if (boards[i].over) out[i] = true;
      }
    }
  }

  Map<String, dynamic> save() => {
        't': elapsedMs,
        's': [for (final b in boards) b.score],
        'lives': [for (final b in boards) b.lives],
        'out': out,
        'f': [
          for (final b in boards)
            [
              for (final f in b.fruits) [f.x, f.y, f.kind, f.sliced ? 1 : 0],
            ],
        ],
      };

  void load(Map<String, dynamic> s) {
    elapsedMs = asInt(s['t']);
    final scores = ints(s['s']);
    final lives = ints(s['lives']);
    final outs = (s['out'] as List);
    final all = s['f'] as List;
    for (var i = 0; i < boards.length; i++) {
      boards[i].score = scores[i];
      boards[i].lives = lives[i];
      out[i] = outs[i] == true;
      boards[i].fruits
        ..clear()
        ..addAll([
          for (final row in all[i] as List)
            CutFruit((row[0] as num).toDouble(), (row[1] as num).toDouble(), 0,
                0, (row[2] as num).toInt(), 0.045)
              ..sliced = (row[3] as num) == 1,
        ]);
    }
  }
}

final fruitCutInfo = LocalGameInfo(
  id: 'fruit_cut',
  title: 'Fruit Cut',
  emoji: '🍉',
  color: const Color(0xFFFF5A36),
  tagline: 'Slice the fruit. Dodge the bombs!',
  rules: const [
    'Fruits fly up from the bottom. Swipe through them to score.',
    'Missing a fruit costs a life. Slicing a bomb ends the run.',
    'Two players: same minute, highest score wins. Each phone plays its own fruit.',
  ],
  scoreUnit: 'points',
  splitScreen: false,
  minPlayers: 1,
  maxPlayers: 2,
  online: RelaySpec<FruitRace>(
    create: (n) => FruitRace(players: n, seed: 42),
    save: (g) => g.save(),
    load: (g, s, me) => g.load(s),
    apply: (g, from, name, a) {
      if (name == 'swipe' && asInt(a[0]) == from)
        g.swipe(from, asDouble(a[1]), asDouble(a[2]), asDouble(a[3]),
            asDouble(a[4]));
    },
    view: (context, g, players, me) =>
        _RaceView(g: g, players: players, me: me),
  ),
  play: (players, onFinished) => players.length < 2
      ? TickingPlay<FruitCutLogic>(
          create: () => FruitCutLogic(),
          onFinished: onFinished,
          builder: (context, g) => _Solo(g: g))
      : TickingPlay<FruitRace>(
          create: () => FruitRace(players: players.length),
          onFinished: onFinished,
          builder: (context, g) => _RaceView(g: g, players: players, me: 0)),
);

class _Solo extends StatelessWidget {
  final FruitCutLogic g;
  const _Solo({required this.g});
  @override
  Widget build(BuildContext context) => SoloFrame(
        title: g.over
            ? (g.lives <= 0 || g.fruits.any((f) => f.kind < 0 && f.sliced)
                ? 'Sliced a bomb'
                : 'Fruit Cut')
            : 'Fruit Cut',
        score: g.score,
        lives: g.lives,
        child: _Canvas(fruits: g.fruits, onSwipe: g.swipe),
      );
}

class _RaceView extends StatelessWidget {
  final FruitRace g;
  final List<GpPlayer> players;
  final int me;
  const _RaceView({required this.g, required this.players, required this.me});
  @override
  Widget build(BuildContext context) => Column(children: [
        GameHud(
            players: players,
            scores: g.scores,
            trailing: Text('${g.secondsLeft}s',
                style: const TextStyle(
                    fontFamily: Fonts.display,
                    color: Colors.white,
                    fontSize: 22))),
        Expanded(
            child: _Canvas(
                fruits: g.boards[me].fruits,
                onSwipe: (a, b, c, d) => g.swipe(me, a, b, c, d))),
      ]);
}

class _Canvas extends StatefulWidget {
  final List<CutFruit> fruits;
  final void Function(double, double, double, double) onSwipe;
  const _Canvas({required this.fruits, required this.onSwipe});
  @override
  State<_Canvas> createState() => _CanvasState();
}

class _CanvasState extends State<_Canvas> {
  Offset? _from;
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      Offset n(Offset p) =>
          Offset(p.dx / c.maxWidth, p.dy / c.maxHeight * FruitCutLogic.height);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (d) => _from = n(d.localPosition),
        onPanUpdate: (d) {
          final a = _from;
          if (a == null) return;
          final b = n(d.localPosition);
          widget.onSwipe(a.dx, a.dy, b.dx, b.dy);
          _from = b;
        },
        onPanEnd: (_) => _from = null,
        child: CustomPaint(
            painter: _FruitPainter(widget.fruits, c.biggest), size: c.biggest),
      );
    });
  }
}

class _FruitPainter extends CustomPainter {
  final List<CutFruit> fruits;
  final Size size;
  _FruitPainter(this.fruits, this.size);
  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF1B1030));
    for (final f in fruits) {
      final c = Offset(f.x * s.width, f.y / FruitCutLogic.height * s.height);
      final rad = f.r * s.width;
      if (f.kind < 0) {
        canvas.drawCircle(c, rad, Paint()..color = const Color(0xFF2B2B2B));
        canvas.drawCircle(
            c, rad * 0.35, Paint()..color = const Color(0xFFFFC21A));
      } else {
        canvas.drawCircle(
            c, rad, Paint()..color = fruitKinds[f.kind % fruitKinds.length]);
        if (f.sliced) {
          canvas.drawLine(
              c - Offset(rad, 0),
              c + Offset(rad, 0),
              Paint()
                ..color = Colors.white
                ..strokeWidth = 2);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FruitPainter old) => true;
}
