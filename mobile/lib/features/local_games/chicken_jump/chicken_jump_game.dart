import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/records/level_progress.dart';
import '../../../core/ui/components.dart';
import '../../guess_person/models/gp_player.dart';
import '../shell/game_hud.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_shell.dart' show PauseButton;
import '../shell/start_gate.dart';
import '../shell/local_game_logic.dart';
import '../shell/ticking_play.dart';
import '../solo/solo_common.dart';

class _Plat {
  double x, y, w;
  final bool moving;
  double dir;
  _Plat(this.x, this.y, this.w, this.moving, this.dir);
}

/// Tap to flap. Reach the flag for the level. Wider gaps and moving platforms come later.
class ChickenLogic extends SoloLogic {
  static const viewH = 1.6;
  final int level;
  final Random rng;
  double y = 0.4, vy = 0, cam = 0, run = 0;
  final List<_Plat> plats = [];
  bool dead = false;
  int _last = 0;

  ChickenLogic({this.level = 1, Random? random}) : rng = random ?? Random() {
    var y = 0.15;
    for (var i = 0; i < 14; i++) {
      _add(y);
      y += _gap;
    }
  }

  double get _gap => 0.28 + (level - 1) * 0.08;
  double get _speed => 0.28 + (level - 1) * 0.1;
  double get goal => 8 + level * 4.0;

  void flap() {
    if (over) return;
    vy = 0.85;
    notifyListeners();
  }

  void _add(double y) {
    final w = max(0.16, 0.42 - (level - 1) * 0.08);
    plats.add(_Plat(rng.nextDouble() * (1 - w), y, w,
        level >= 3 && rng.nextBool(), rng.nextBool() ? 1 : -1));
  }

  @override
  void step(int now) {
    final dt = ((now - _last) / 1000).clamp(0.0, 0.04);
    _last = now;
    vy -= 1.7 * dt;
    y += vy * dt;
    run += _speed * dt;
    if (y - cam > viewH * 0.55) cam = y - viewH * 0.55;
    for (final p in plats) {
      if (!p.moving) continue;
      p.x += p.dir * 0.25 * dt;
      if (p.x < 0 || p.x > 1 - p.w) p.dir *= -1;
    }
    const bx = 0.28;
    if (vy < 0) {
      for (final p in plats) {
        if ((y - p.y).abs() < 0.04 && bx > p.x && bx < p.x + p.w) {
          y = p.y;
          vy = 0;
        }
      }
    }
    while (plats.last.y < run + viewH) {
      _add(plats.last.y + _gap);
    }
    if (y < cam - 0.05 || y < run - 0.2) {
      dead = true;
      gameOver(700);
    }
    score = run.floor();
    if (run >= goal) {
      score = goal.floor() + level * 10;
      LevelProgress.unlock('chicken_jump', min(3, level + 1));
      gameOver(800);
    }
    notifyListeners();
  }
}

class ChickenRace extends LocalGameLogic {
  final int level;
  final List<ChickenLogic> birds;
  final List<bool> done;
  int elapsed = 0;
  int? winner;
  ChickenRace({this.level = 1, int players = 2, int seed = 7})
      : birds = [
          for (var i = 0; i < players; i++)
            ChickenLogic(level: level, random: Random(seed))
        ],
        done = List.filled(players, false);

  @override
  bool get finished =>
      winner != null || elapsed > 90000 || done.every((d) => d);
  @override
  List<int> get scores => [
        for (var i = 0; i < birds.length; i++)
          winner == i ? 100000 - elapsed : birds[i].score
      ];

  void flap(int player) {
    if (forward('flap', [player])) return;
    if (finished || elapsed < 2500 || done[player]) return;
    birds[player].flap();
    notifyListeners();
  }

  @override
  void update(int ms) {
    elapsed = ms;
    if (ms < 2500 || finished) {
      notifyListeners();
      return;
    }
    for (var i = 0; i < birds.length; i++) {
      if (done[i]) continue;
      birds[i].update(ms);
      if (birds[i].over) {
        done[i] = true;
        if (!birds[i].dead && winner == null) winner = i;
      }
    }
    notifyListeners();
  }
}

final chickenJumpInfo = LocalGameInfo(
  id: 'chicken_jump',
  title: 'Chicken Jump',
  emoji: '🐤',
  color: const Color(0xFFFFC21A),
  tagline: 'Flap across the platforms!',
  rules: const [
    'Tap to flap. Land on platforms and reach the distance for the level.',
    'Level 1 is slow and wide. Level 3 adds moving platforms and bigger gaps.',
    'Online, both phones get the same level. First to the flag wins.',
  ],
  scoreUnit: 'points',
  splitScreen: false,
  minPlayers: 1,
  maxPlayers: 2,
  online: RelaySpec<ChickenRace>(
    create: (n) => ChickenRace(players: n),
    save: (g) => {
      't': g.elapsed,
      'w': g.winner,
      'run': [for (final b in g.birds) b.run],
      'y': [for (final b in g.birds) b.y],
      'dead': [for (final b in g.birds) b.dead],
    },
    load: (g, s, me) {
      g.elapsed = asInt(s['t']);
      g.winner = nInt(s['w']);
      final runs = doubles(s['run']);
      final ys = doubles(s['y']);
      final dead = s['dead'] as List;
      for (var i = 0; i < g.birds.length; i++) {
        g.birds[i].run = runs[i];
        g.birds[i].y = ys[i];
        g.birds[i].dead = dead[i] == true;
        g.done[i] = g.birds[i].over ||
            g.birds[i].dead ||
            g.birds[i].run >= g.birds[i].goal;
      }
    },
    apply: (g, from, name, a) {
      if (name == 'flap' && asInt(a[0]) == from) g.flap(from);
    },
    view: (context, g, players, me) => _Race(g: g, players: players, me: me),
  ),
  play: (players, onFinished) => players.length < 2
      ? _ChickenMenu(onFinished: onFinished)
      : TickingPlay<ChickenRace>(
          create: () => ChickenRace(players: players.length),
          onFinished: onFinished,
          builder: (context, g) => _Race(g: g, players: players, me: 0)),
);

class _ChickenMenu extends StatefulWidget {
  final void Function(List<int>) onFinished;
  const _ChickenMenu({required this.onFinished});
  @override
  State<_ChickenMenu> createState() => _ChickenMenuState();
}

class _ChickenMenuState extends State<_ChickenMenu> {
  int unlocked = 1;
  int? level;
  @override
  void initState() {
    super.initState();
    LevelProgress.unlocked('chicken_jump').then((n) {
      if (mounted) setState(() => unlocked = n.clamp(1, 3));
    });
  }

  @override
  Widget build(BuildContext context) {
    if (level == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Align(alignment: Alignment.centerLeft, child: PauseButton()),
          const SizedBox(height: 12),
          const Text('Choose a level',
              style: TextStyle(
                  fontFamily: Fonts.display,
                  color: Colors.white,
                  fontSize: 28)),
          const SizedBox(height: 12),
          for (var i = 1; i <= 3; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GoldButton(
                  i <= unlocked
                      ? 'Level $i  ${const ['Easy', 'Medium', 'Hard'][i - 1]}'
                      : 'Level $i locked',
                  height: 56,
                  onPressed:
                      i <= unlocked ? () => setState(() => level = i) : null),
            ),
        ]),
      );
    }
    return StartGate(
      color: const Color(0xFFFFC21A),
      child: (context) => TickingPlay<ChickenLogic>(
      create: () => ChickenLogic(level: level!),
      onFinished: widget.onFinished,
      builder: (context, g) => SoloFrame(
        title: 'Level ${g.level}',
        score: g.score,
        extra: g.dead
            ? 'Fell!'
            : (g.run >= g.goal ? 'Clear!' : '${g.goal.floor()}m'),
        child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: g.flap,
            child: CustomPaint(
                painter: _ChickenPainter(g),                 child: const SizedBox.expand())),
      ),
    ));
  }
}

class _Race extends StatelessWidget {
  final ChickenRace g;
  final List<GpPlayer> players;
  final int me;
  const _Race({required this.g, required this.players, required this.me});
  @override
  Widget build(BuildContext context) => Column(children: [
        GameHud(
            players: players,
            scores: [for (final b in g.birds) b.score],
            trailing: Text(
                g.elapsed < 2500 ? '${(3 - g.elapsed / 1000).ceil()}' : 'GO',
                style: const TextStyle(
                    fontFamily: Fonts.display,
                    color: Colors.white,
                    fontSize: 22))),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => g.flap(me),
            child: CustomPaint(
                painter: _ChickenPainter(g.birds[me]),
                child: const SizedBox.expand()),
          ),
        ),
      ]);
}

class _ChickenPainter extends CustomPainter {
  final ChickenLogic g;
  _ChickenPainter(this.g);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF87CEEB), Color(0xFFB6E3A8)])
              .createShader(Offset.zero & size));
    double sy(double y) =>
        size.height - (y - g.cam) / ChickenLogic.viewH * size.height;
    for (final p in g.plats) {
      final r = Rect.fromLTWH(p.x * size.width, sy(p.y), p.w * size.width, 12);
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(6)),
          Paint()..color = const Color(0xFF8D5A2B));
    }
    final bird = Offset(0.28 * size.width, sy(g.y));
    canvas.drawOval(Rect.fromCenter(center: bird, width: 36, height: 28),
        Paint()..color = const Color(0xFFFFE08A));
    canvas.drawCircle(
        bird + const Offset(10, -4), 4, Paint()..color = Colors.black);
    final beak = Path()
      ..moveTo(bird.dx + 16, bird.dy)
      ..lineTo(bird.dx + 26, bird.dy + 3)
      ..lineTo(bird.dx + 16, bird.dy + 6)
      ..close();
    canvas.drawPath(beak, Paint()..color = const Color(0xFFFF8C42));
  }

  @override
  bool shouldRepaint(covariant _ChickenPainter old) => true;
}
