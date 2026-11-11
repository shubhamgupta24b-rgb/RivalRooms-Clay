import 'package:flutter/material.dart';
import '../../guess_person/models/gp_player.dart';
import '../shell/game_hud.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/ticking_play.dart';

/// Two wrestlers in a ring. Tap your half to shove. Push the other one out.
/// First to 3 wins. The tap zone is the ring; the pause button stays above it.
class SumoLogic extends LocalGameLogic {
  static const target = 3;
  final List<Offset> pos = [const Offset(0.5, 0.62), const Offset(0.5, 0.38)];
  final List<int> points = [0, 0];
  int elapsed = 0;
  int? winner;
  int _lastPush = 0;

  @override
  bool get finished => winner != null;
  @override
  List<int> get scores => points;

  void shove(int player) {
    if (forward('shove', [player])) return;
    if (finished || elapsed - _lastPush < 70) return;
    _lastPush = elapsed;
    final other = 1 - player;
    final away = pos[other] - pos[player];
    final len = away.distance;
    final dir = len < 0.001 ? const Offset(0, -1) : away / len;
    final bias = player == 0 ? const Offset(0, -1) : const Offset(0, 1);
    pos[other] = pos[other] + (dir * 0.045 + bias * 0.02);
    pos[player] = pos[player] + dir * 0.012;
    _bounds();
    notifyListeners();
  }

  void _bounds() {
    for (var i = 0; i < 2; i++) {
      final d = (pos[i] - const Offset(0.5, 0.5)).distance;
      if (d > 0.34) {
        points[1 - i]++;
        pos[0] = const Offset(0.5, 0.62);
        pos[1] = const Offset(0.5, 0.38);
        if (points[1 - i] >= target) winner = 1 - i;
        return;
      }
    }
  }

  @override
  void update(int ms) {
    elapsed = ms;
    if (ms > 90000 && winner == null) {
      winner = points[0] == points[1] ? null : (points[0] > points[1] ? 0 : 1);
      if (winner == null && ms > 90000) winner = 0;
    }
    notifyListeners();
  }
}

final sumoPushInfo = LocalGameInfo(
  id: 'sumo_push',
  title: 'Sumo Push',
  emoji: '🤼',
  color: const Color(0xFFE07A5F),
  tagline: 'Shove them out of the ring!',
  rules: const [
    'Tap in your half of the ring to shove the other wrestler.',
    'Push them past the circle to score. First to 3 wins.',
    'The pause button sits above the ring, not on it.',
  ],
  scoreUnit: 'pushes',
  splitScreen: true,
  bot: botFor<SumoLogic>((g, b, now) {
    if (g.finished) return;
    if (!b.thinkFirst(g.points.join(), now, 180, 420)) return;
    if (b.slips()) return;
    g.shove(b.seat);
    b.wait(now, (260 / b.skill.tracking).round(), (520 / b.skill.tracking).round());
  }),
  online: RelaySpec<SumoLogic>(
    create: (n) => SumoLogic(),
    save: (g) => {
      't': g.elapsed,
      'p': [for (final o in g.pos) ...[o.dx, o.dy]],
      's': g.points,
      'w': g.winner,
    },
    load: (g, s, me) {
      g.elapsed = asInt(s['t']);
      final p = doubles(s['p']);
      g.pos[0] = Offset(p[0], p[1]);
      g.pos[1] = Offset(p[2], p[3]);
      g.points.setAll(0, ints(s['s']));
      g.winner = nInt(s['w']);
    },
    apply: (g, from, name, a) {
      if (name == 'shove' && a.isNotEmpty && asInt(a[0]) == from) {
        g.shove(from);
      }
    },
    view: (context, g, players, me) => _Ring(g: g, players: players, me: me),
  ),
  play: (players, onFinished) => TickingPlay<SumoLogic>(
      create: () => SumoLogic(),
      onFinished: onFinished,
      builder: (context, g) => _Ring(g: g, players: players, me: null)),
);

class _Ring extends StatelessWidget {
  final SumoLogic g;
  final List<GpPlayer> players;
  final int? me;
  const _Ring({required this.g, required this.players, required this.me});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      GameHud(
          players: players,
          scores: g.points,
          trailing: const Text('Shove',
              style: TextStyle(
                  color: Colors.white70, fontWeight: FontWeight.w800))),
      const SizedBox(height: 8),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: AspectRatio(
            aspectRatio: 1,
            child: LayoutBuilder(builder: (context, box) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) {
                  final seat =
                      me ?? (d.localPosition.dy > box.maxHeight / 2 ? 0 : 1);
                  if (me != null && seat != me) return;
                  g.shove(seat);
                },
                child: CustomPaint(
                    painter:
                        _SumoPainter(g, players.map((p) => p.color).toList()),
                    child: const SizedBox.expand()),
              );
            }),
          ),
        ),
      ),
    ]);
  }
}

class _SumoPainter extends CustomPainter {
  final SumoLogic g;
  final List<Color> colors;
  _SumoPainter(this.g, this.colors);
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide * 0.42;
    canvas.drawCircle(c + const Offset(0, 6), r + 14, Paint()..color = const Color(0xFF5C3A1E));
    canvas.drawCircle(c, r + 12, Paint()..color = const Color(0xFF8A5A2B));
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = const RadialGradient(
                  colors: [Color(0xFFFFF1D2), Color(0xFFE7C48A)])
              .createShader(Rect.fromCircle(center: c, radius: r)));
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..color = const Color(0xFF5C3A1E));
    for (var i = 0; i < 2; i++) {
      final p = g.pos[i];
      // Keep the body inside the clay ring at the starting marks.
      final at = c + Offset((p.dx - 0.5) * r * 1.55, (p.dy - 0.5) * r * 1.55);
      canvas.drawCircle(at + const Offset(0, 3), 20, Paint()..color = Colors.black26);
      canvas.drawCircle(at, 20, Paint()..color = colors[i]);
      canvas.drawCircle(
          at + const Offset(-4, -6), 6, Paint()..color = Colors.white.withValues(alpha: 0.35));
      canvas.drawCircle(at + const Offset(-6, -2), 3, Paint()..color = Colors.white);
      canvas.drawCircle(at + const Offset(6, -2), 3, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _SumoPainter old) => true;
}
