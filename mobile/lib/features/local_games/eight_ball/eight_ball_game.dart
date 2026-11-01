import 'dart:math';
import 'package:flutter/material.dart';
import '../../guess_person/models/gp_player.dart';
import '../shell/game_hud.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/ticking_play.dart';
import '../table/table_physics.dart';

/// Eight-ball. Solids are 1–7, stripes 9–15, the 8 is last. The first legal pocket
/// assigns the groups. Scratching gives the opponent ball-in-hand.
class EightBallLogic extends LocalGameLogic {
  final TableSim table;
  int turn = 0;
  int? group; // 0 solids for the player who pocketed them, null until assigned
  int? groupOwner;
  int? winner;
  bool moving = false;
  bool ballInHand = false;
  String message = 'Drag to aim and shoot';
  int _last = 0;
  final Set<int> _before = {};

  EightBallLogic() : table = _rack() {
    _before.addAll(_down());
  }

  static TableSim _rack() {
    final pucks = <Puck>[Puck(0, 0.25, 0.5, r: 0.02, mass: 1.1)];
    const rows = [1, 2, 3, 4, 5];
    var id = 1;
    var x = 1.35;
    for (final n in rows) {
      for (var i = 0; i < n; i++) {
        pucks.add(Puck(id, x, 0.5 + (i - (n - 1) / 2) * 0.042, r: 0.018));
        id++;
      }
      x += 0.04;
    }
    return TableSim(
      w: 2,
      h: 1,
      pucks: pucks,
      pockets: const [
        Offset(0.06, 0.06),
        Offset(1, 0.05),
        Offset(1.94, 0.06),
        Offset(0.06, 0.94),
        Offset(1, 0.95),
        Offset(1.94, 0.94)
      ],
      pocketR: 0.045,
      friction: 0.85,
      restitution: 0.92,
    );
  }

  bool solid(int id) => id >= 1 && id <= 7;
  bool stripe(int id) => id >= 9 && id <= 15;
  Set<int> _down() => {
        for (final p in table.pucks)
          if (p.pocketed) p.id
      };
  int left(bool solids) => table.pucks
      .where((p) => !p.pocketed && (solids ? solid(p.id) : stripe(p.id)))
      .length;

  bool _isMine(int id) {
    if (groupOwner == null) return solid(id) || stripe(id);
    final solids = (groupOwner == turn) == (group == 0);
    return solids ? solid(id) : stripe(id);
  }

  @override
  bool get finished => winner != null;
  @override
  List<int> get scores => [winner == 0 ? 1 : 0, winner == 1 ? 1 : 0];

  @override
  void update(int ms) {
    if (!moving) return;
    table.step(((ms - _last) / 1000).clamp(0.0, 0.05));
    _last = ms;
    if (table.resting) _settle();
    notifyListeners();
  }

  void placeCue(int player, double x, double y) {
    if (forward('place', [player, x, y])) return;
    if (!ballInHand || player != turn || moving) return;
    final c = table.byId(0);
    c.pocketed = false;
    c.x = x.clamp(0.12, 0.7);
    c.y = y.clamp(0.12, 0.88);
    c.vx = c.vy = 0;
    ballInHand = false;
    notifyListeners();
  }

  void shoot(int player, double angle, double power) {
    if (forward('shoot', [player, angle, power])) return;
    if (finished || moving || player != turn || ballInHand) return;
    final c = table.byId(0);
    if (c.pocketed) return;
    final p = power.clamp(0.3, 1.6);
    c.vx = cos(angle) * p * 3.2;
    c.vy = sin(angle) * p * 3.2;
    _before
      ..clear()
      ..addAll(_down());
    moving = true;
    _last = 0;
    notifyListeners();
  }

  void _settle() {
    moving = false;
    final fresh = _down().difference(_before);
    final scratch = fresh.contains(0);
    final eight = fresh.contains(8);
    final mine =
        fresh.where((id) => id != 0 && id != 8 && _isMine(id)).toList();
    final theirs =
        fresh.where((id) => id != 0 && id != 8 && !_isMine(id)).toList();
    if (groupOwner == null) {
      final got = fresh.where((id) => solid(id) || stripe(id));
      if (got.isNotEmpty) {
        group = solid(got.first) ? 0 : 1;
        groupOwner = turn;
      }
    }
    final cleared =
        groupOwner != null && left(group == 0) == 0 && groupOwner == turn ||
            groupOwner != null && left(group != 0) == 0 && groupOwner != turn;
    if (eight) {
      final myGroupClear =
          groupOwner == turn ? left(group == 0) == 0 : left(group != 0) == 0;
      if (scratch || !myGroupClear) {
        winner = 1 - turn;
        message = scratch ? 'Scratched on the 8' : '8-ball too early';
      } else {
        winner = turn;
        message = 'Eight ball!';
      }
      return;
    }
    if (scratch) {
      ballInHand = true;
      table.byId(0).pocketed = true;
      message = 'Foul. Ball in hand';
      turn = 1 - turn;
      return;
    }
    if (mine.isNotEmpty && theirs.isEmpty) {
      message = 'Your ball. Shoot again';
    } else {
      message = theirs.isNotEmpty ? 'Opponent ball' : 'No ball pocketed';
      turn = 1 - turn;
    }
    if (cleared) message = 'On the 8-ball';
  }

  String groupLabel(int player) {
    if (groupOwner == null) return 'Open';
    final solids = player == groupOwner ? group == 0 : group != 0;
    return solids ? 'Solids' : 'Stripes';
  }

  List<double> pack() => [
        for (final p in table.pucks) ...[p.x, p.y, p.pocketed ? 1.0 : 0.0]
      ];
  void unpack(List<double> v) {
    for (var i = 0; i < table.pucks.length; i++) {
      table.pucks[i]
        ..x = v[i * 3]
        ..y = v[i * 3 + 1]
        ..pocketed = v[i * 3 + 2] > 0.5
        ..vx = 0
        ..vy = 0;
    }
  }
}

final eightBallInfo = LocalGameInfo(
  id: 'eight_ball',
  title: 'Eight Ball',
  emoji: '🎱',
  color: const Color(0xFF1B6B3A),
  tagline: 'Pocket your group, then the 8!',
  rules: const [
    'Drag back from the cue ball and release to shoot.',
    'The first ball you pocket assigns solids or stripes. Keep shooting after pocketing your own.',
    'A scratch is ball-in-hand for the other player. Pocket the 8 early, or scratch on it, and you lose.',
  ],
  scoreUnit: 'wins',
  splitScreen: false,
  minPlayers: 2,
  maxPlayers: 2,
  online: RelaySpec<EightBallLogic>(
    create: (n) => EightBallLogic(),
    save: (g) => {
      'p': g.pack(),
      'turn': g.turn,
      'group': g.group,
      'owner': g.groupOwner,
      'win': g.winner,
      'hand': g.ballInHand,
      'msg': g.message,
      'moving': g.moving
    },
    load: (g, s, me) {
      g.unpack(doubles(s['p']));
      g.turn = asInt(s['turn']);
      g.group = nInt(s['group']);
      g.groupOwner = nInt(s['owner']);
      g.winner = nInt(s['win']);
      g.ballInHand = s['hand'] == true;
      g.message = s['msg'] as String;
      g.moving = s['moving'] == true;
    },
    apply: (g, from, name, a) {
      if (from != g.turn) return;
      if (name == 'shoot') g.shoot(from, asDouble(a[1]), asDouble(a[2]));
      if (name == 'place') g.placeCue(from, asDouble(a[1]), asDouble(a[2]));
    },
    view: (context, g, players, me) =>
        _PoolView(g: g, players: players, me: me),
  ),
  play: (players, onFinished) => TickingPlay<EightBallLogic>(
      create: () => EightBallLogic(),
      onFinished: onFinished,
      builder: (context, g) => _PoolView(g: g, players: players, me: null)),
);

class _PoolView extends StatelessWidget {
  final EightBallLogic g;
  final List<GpPlayer> players;
  final int? me;
  const _PoolView({required this.g, required this.players, required this.me});
  @override
  Widget build(BuildContext context) {
    final seat = me ?? g.turn;
    final mine = seat == g.turn && !g.moving && g.winner == null;
    return Column(children: [
      GameHud(
          players: players,
          turn: g.finished ? null : g.turn,
          extra: g.groupLabel),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Text(g.message,
              style: const TextStyle(
                  color: Colors.white70, fontWeight: FontWeight.w800))),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: AspectRatio(
            aspectRatio: 2,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: mine && g.ballInHand
                  ? (d) {
                      final box = context.size ?? const Size(300, 150);
                      g.placeCue(seat, d.localPosition.dx / box.width * 2,
                          d.localPosition.dy / box.height);
                    }
                  : null,
              onPanEnd: mine && !g.ballInHand
                  ? (d) {
                      final v = d.velocity.pixelsPerSecond;
                      if (v.distance < 40) return;
                      g.shoot(seat, atan2(v.dy, v.dx),
                          (v.distance / 1800).clamp(0.3, 1.6));
                    }
                  : null,
              child: CustomPaint(
                  painter: _PoolPainter(g), child: const SizedBox.expand()),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _PoolPainter extends CustomPainter {
  final EightBallLogic g;
  _PoolPainter(this.g);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
        Paint()..color = const Color(0xFF0E4D28));
    final felt = Rect.fromLTWH(10, 10, size.width - 20, size.height - 20);
    canvas.drawRRect(RRect.fromRectAndRadius(felt, const Radius.circular(8)),
        Paint()..color = const Color(0xFF1B7A3A));
    for (final c in g.table.pockets) {
      canvas.drawCircle(Offset(c.dx / 2 * size.width, c.dy * size.height), 8,
          Paint()..color = Colors.black);
    }
    for (final p in g.table.pucks) {
      if (p.pocketed) continue;
      final c = Offset(p.x / 2 * size.width, p.y * size.height);
      final col = p.id == 0
          ? Colors.white
          : p.id == 8
              ? Colors.black
              : (p.id <= 7 ? const Color(0xFFFFC21A) : const Color(0xFF3A86FF));
      canvas.drawCircle(c, p.r / 2 * size.width, Paint()..color = col);
      if (p.id != 0) {
        final tp = TextPainter(
            text: TextSpan(
                text: '${p.id}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w900)),
            textDirection: TextDirection.ltr)
          ..layout();
        tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PoolPainter old) => true;
}
