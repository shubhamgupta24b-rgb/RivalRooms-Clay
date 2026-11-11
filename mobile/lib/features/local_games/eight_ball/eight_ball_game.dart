import 'dart:math';
import 'package:flutter/material.dart';
import '../../guess_person/models/gp_player.dart';
import '../shell/game_hud.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/ticking_play.dart';
import '../table/table_physics.dart';

/// Eight-ball on a 2:1 table. Solids are 1–7, stripes 9–15, the 8 is last.
/// The first legal pocket assigns the groups. A scratch or a missed ball is
/// ball-in-hand for the other player.
class EightBallLogic extends LocalGameLogic {
  static const ballR = 0.062;
  final TableSim table;
  int turn = 0;
  int? group; // 0 solids for [groupOwner], null until assigned
  int? groupOwner;
  int? winner;
  bool moving = false;
  bool ballInHand = false;
  String message = 'Pull back from the cue ball and let go';
  int _last = 0;
  int _shotStart = 0;
  bool _clock = false;
  final Set<int> _before = {};

  EightBallLogic() : table = _rack() {
    _before.addAll(_down());
  }

  static TableSim _rack() {
    const gap = 0.135;
    final pucks = <Puck>[Puck(0, 0.46, 0.5, r: ballR, mass: 1.05)];
    var id = 1;
    var x = 1.12;
    for (var n = 1; n <= 5; n++) {
      for (var i = 0; i < n; i++) {
        pucks.add(Puck(id, x, 0.5 + (i - (n - 1) / 2) * gap, r: ballR));
        id++;
      }
      x += gap * 0.9;
    }
    // Standard six pockets: four corners and one in the middle of each long rail.
    return TableSim(
      w: 2,
      h: 1,
      pucks: pucks,
      pockets: const [
        Offset(0.08, 0.08),
        Offset(1, 0.0),
        Offset(1.92, 0.08),
        Offset(0.08, 0.92),
        Offset(1, 1.0),
        Offset(1.92, 0.92),
      ],
      pocketR: 0.09,
      friction: 0.95,
      restitution: 0.9,
    );
  }

  bool solid(int id) => id >= 1 && id <= 7;
  bool stripe(int id) => id >= 9 && id <= 15;
  bool wants(int id) {
    if (id == 0 || id == 8) return false;
    if (groupOwner == null) return solid(id) || stripe(id);
    final solids = (groupOwner == turn) == (group == 0);
    return solids ? solid(id) : stripe(id);
  }

  Set<int> _down() => {
        for (final p in table.pucks)
          if (p.pocketed) p.id
      };
  int left(bool solids) => table.pucks
      .where((p) => !p.pocketed && (solids ? solid(p.id) : stripe(p.id)))
      .length;

  @override
  bool get finished => winner != null;
  @override
  List<int> get scores => [winner == 0 ? 1 : 0, winner == 1 ? 1 : 0];

  @override
  void update(int ms) {
    if (!moving) return;
    if (!_clock) {
      _clock = true;
      _last = ms;
      _shotStart = ms;
      return;
    }
    table.step(((ms - _last) / 1000).clamp(0.0, 0.05));
    _last = ms;
    for (final p in table.pucks) {
      if (p.pocketed) continue;
      if (p.x < -0.3 || p.y < -0.3 || p.x > table.w + 0.3 || p.y > table.h + 0.3) {
        p.vx = 0;
        p.vy = 0;
        p.x = p.x.clamp(p.r, table.w - p.r);
        p.y = p.y.clamp(p.r, table.h - p.r);
      }
    }
    // A shot that never quite rests used to leave "No ball pocketed" up and
    // lock the table, so the next player never got the turn back.
    if (table.resting || ms - _shotStart > 8000) {
      for (final p in table.pucks) {
        p.vx = 0;
        p.vy = 0;
      }
      _settle();
    }
    notifyListeners();
  }

  void placeCue(int player, double x, double y) {
    if (forward('place', [player, x, y])) return;
    if (!ballInHand || player != turn || moving) return;
    final c = table.byId(0);
    c.pocketed = false;
    c.x = x.clamp(0.16, table.w - 0.16);
    c.y = y.clamp(0.16, table.h - 0.16);
    for (final p in table.pucks) {
      if (p.pocketed || p.id == 0) continue;
      final dx = c.x - p.x, dy = c.y - p.y;
      final dist = sqrt(dx * dx + dy * dy);
      final minD = c.r + p.r + 0.01;
      if (dist < minD && dist > 1e-6) {
        c.x = p.x + dx / dist * minD;
        c.y = p.y + dy / dist * minD;
      }
    }
    c.x = c.x.clamp(0.14, table.w - 0.14);
    c.y = c.y.clamp(0.14, table.h - 0.14);
    c.vx = c.vy = 0;
    ballInHand = false;
    message = 'Pull back from the cue ball and let go';
    notifyListeners();
  }

  void shoot(int player, double angle, double power) {
    if (forward('shoot', [player, angle, power])) return;
    if (finished || moving || player != turn || ballInHand) return;
    final c = table.byId(0);
    if (c.pocketed) return;
    final p = power.clamp(0.28, 1.7);
    c.vx = cos(angle) * p * 3.4;
    c.vy = sin(angle) * p * 3.4;
    _before
      ..clear()
      ..addAll(_down());
    table.clearHits();
    moving = true;
    _clock = false;
    notifyListeners();
  }

  int? _firstCueHit() {
    for (var i = 0; i < table.hitA.length; i++) {
      final a = table.hitA[i], b = table.hitB[i];
      if (a == 0) return b;
      if (b == 0) return a;
    }
    return null;
  }

  void _switch(String why, {bool hand = false}) {
    message = why;
    turn = 1 - turn;
    if (hand) {
      ballInHand = true;
      final c = table.byId(0);
      c.pocketed = true;
      c.vx = c.vy = 0;
    }
  }

  void _settle() {
    moving = false;
    final fresh = _down().difference(_before);
    final scratch = fresh.contains(0);
    final eight = fresh.contains(8);
    final mine = fresh.where((id) => id != 0 && id != 8 && wants(id)).toList();
    final theirs =
        fresh.where((id) => id != 0 && id != 8 && !wants(id)).toList();
    final first = _firstCueHit();
    final noHit = first == null;
    final wrongFirst =
        groupOwner != null && first != null && first != 8 && !wants(first);
    if (groupOwner == null && !scratch && !noHit && !wrongFirst) {
      final got = fresh.where((id) => solid(id) || stripe(id));
      if (got.isNotEmpty) {
        group = solid(got.first) ? 0 : 1;
        groupOwner = turn;
      }
    }
    final myGroup = groupOwner == turn ? group == 0 : group != 0;
    final myGroupClear = groupOwner != null && left(myGroup) == 0;
    if (eight) {
      if (scratch || !myGroupClear || noHit || wrongFirst) {
        winner = 1 - turn;
        message = scratch ? 'Scratched on the 8' : '8-ball too early';
      } else {
        winner = turn;
        message = 'Eight ball!';
      }
      return;
    }
    if (scratch) {
      _switch('Foul. Ball in hand', hand: true);
      return;
    }
    if (noHit) {
      _switch('Foul. No ball hit', hand: true);
      return;
    }
    if (wrongFirst) {
      _switch('Foul. Hit the wrong ball first', hand: true);
      return;
    }
    if (mine.isNotEmpty && theirs.isEmpty) {
      message = myGroupClear ? 'On the 8-ball' : 'Your ball. Shoot again';
    } else {
      turn = 1 - turn;
      ballInHand = false;
      message = theirs.isNotEmpty ? 'Opponent ball' : 'No ball pocketed';
      if (groupOwner != null &&
          left(groupOwner == turn ? group == 0 : group != 0) == 0) {
        message = 'On the 8-ball';
      }
    }
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
    'Pull back from the cue ball and let go. The line shows the shot. The bar shows the power.',
    'The first ball you pocket assigns solids or stripes. Keep shooting after pocketing your own.',
    'A scratch, a miss, or hitting the wrong ball first is ball-in-hand. Pocket the 8 early and you lose.',
  ],
  scoreUnit: 'wins',
  splitScreen: false,
  minPlayers: 2,
  maxPlayers: 2,
  bot: botFor<EightBallLogic>((g, b, now) {
    if (g.finished || g.moving || g.turn != b.seat) return;
    final down = g.table.pucks.where((p) => p.pocketed).length;
    if (!b.thinkFirst((g.turn, g.ballInHand, down), now, 450, 1100)) return;
    if (g.ballInHand) {
      g.placeCue(b.seat, 0.42 + b.aimNoise(0.15), 0.5 + b.aimNoise(0.2));
      return;
    }
    final cue = g.table.byId(0);
    final balls = [
      for (final p in g.table.pucks)
        if (!p.pocketed && p.id != 0 && (g.groupOwner == null || g.wants(p.id)))
          p
    ];
    final target = balls.isEmpty
        ? g.table.pucks.firstWhere((p) => p.id == 8 && !p.pocketed,
            orElse: () => cue)
        : b.prefer(balls);
    if (identical(target, cue)) return;
    var angle = atan2(target.y - cue.y, target.x - cue.x);
    if (b.slips()) angle += b.aimNoise(1.4);
    final power = b.slips() ? 0.45 + b.rng.nextDouble() : 0.85 + b.rng.nextDouble() * 0.5;
    g.shoot(b.seat, angle, power);
  }),
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

class _PoolView extends StatefulWidget {
  final EightBallLogic g;
  final List<GpPlayer> players;
  final int? me;
  const _PoolView({required this.g, required this.players, required this.me});
  @override
  State<_PoolView> createState() => _PoolViewState();
}

class _PoolViewState extends State<_PoolView> {
  Offset? _finger;
  double _power = 0;

  int _seat(BuildContext context) {
    if (widget.me != null) return widget.me!;
    return BotScope.humanSeat(context) ?? widget.g.turn;
  }

  bool _mine(BuildContext context) {
    final seat = _seat(context);
    return seat == widget.g.turn &&
        !widget.g.moving &&
        widget.g.winner == null;
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final seat = _seat(context);
    final mine = _mine(context);
    return Column(children: [
      GameHud(
          players: widget.players,
          turn: g.finished ? null : g.turn,
          extra: g.groupLabel),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Text(g.message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white70, fontWeight: FontWeight.w800))),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
          child: Row(children: [
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 2,
                  child: LayoutBuilder(builder: (context, c) {
                    final size = Size(c.maxWidth, c.maxHeight);
                    Offset tableOf(Offset p) =>
                        Offset(p.dx / size.width * 2, p.dy / size.height);
                    Offset screenOf(double x, double y) =>
                        Offset(x / 2 * size.width, y * size.height);
                    final cue = g.table.byId(0);
                    final cuePx = screenOf(cue.x, cue.y);
                    void aim(Offset finger) {
                      final pull = finger - cuePx;
                      setState(() {
                        _finger = finger;
                        _power = (pull.distance / (size.width * 0.42))
                            .clamp(0.0, 1.0);
                      });
                    }

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: mine && g.ballInHand
                          ? (d) {
                              final t = tableOf(d.localPosition);
                              g.placeCue(seat, t.dx, t.dy);
                            }
                          : null,
                      onPanStart: mine && !g.ballInHand
                          ? (d) => aim(d.localPosition)
                          : null,
                      onPanUpdate: mine && !g.ballInHand
                          ? (d) => aim(d.localPosition)
                          : null,
                      onPanEnd: mine && !g.ballInHand
                          ? (_) {
                              final finger = _finger;
                              setState(() {
                                _finger = null;
                                _power = 0;
                              });
                              if (finger == null) return;
                              final pull = finger - cuePx;
                              if (pull.distance < 18) return;
                              g.shoot(
                                  seat,
                                  atan2(-pull.dy, -pull.dx),
                                  (pull.distance / (size.width * 0.42))
                                      .clamp(0.3, 1.6));
                            }
                          : null,
                      onPanCancel: () => setState(() {
                        _finger = null;
                        _power = 0;
                      }),
                      child: CustomPaint(
                          painter: _PoolPainter(g, _finger, cuePx),
                          child: const SizedBox.expand()),
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _PowerBar(power: _power),
          ]),
        ),
      ),
    ]);
  }
}

class _PowerBar extends StatelessWidget {
  final double power;
  const _PowerBar({required this.power});
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Power ${(power * 100).round()} percent',
      excludeSemantics: true,
      child: SizedBox(
        width: 28,
        child: Column(children: [
          const Text('PWR',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                  color: const Color(0xFF102418),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF8D6A3A))),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor: power.clamp(0.0, 1.0),
                  widthFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        gradient: const LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Color(0xFF2ECC71), Color(0xFFFFC21A), Color(0xFFE53935)])),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _PoolPainter extends CustomPainter {
  final EightBallLogic g;
  final Offset? finger;
  final Offset cuePx;
  _PoolPainter(this.g, this.finger, this.cuePx);
  @override
  void paint(Canvas canvas, Size size) {
    final rail = RRect.fromRectAndRadius(
        Offset.zero & size, const Radius.circular(14));
    canvas.drawRRect(
        rail.shift(const Offset(0, 4)), Paint()..color = Colors.black38);
    canvas.drawRRect(
        rail,
        Paint()
          ..shader = const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF8A5A2B), Color(0xFF5C3A1E)])
              .createShader(Offset.zero & size));
    final felt = Rect.fromLTWH(14, 14, size.width - 28, size.height - 28);
    canvas.drawRRect(
        RRect.fromRectAndRadius(felt, const Radius.circular(8)),
        Paint()..color = const Color(0xFF0E6B32));
    canvas.drawRRect(
        RRect.fromRectAndRadius(felt.deflate(3), const Radius.circular(6)),
        Paint()..color = const Color(0xFF178A3E));
    Offset at(double x, double y) =>
        Offset(x / 2 * size.width, y * size.height);
    final pocketPaint = Paint()..color = const Color(0xFF070B09);
    for (final c in g.table.pockets) {
      final center = at(c.dx, c.dy);
      final rad = max(g.table.pocketR / 2 * size.width, 13.0);
      canvas.drawCircle(center, rad + 2, Paint()..color = const Color(0xFF3E2714));
      canvas.drawCircle(center, rad, pocketPaint);
    }
    final aim = finger;
    final cue = g.table.byId(0);
    if (aim != null && !cue.pocketed) {
      final pull = aim - cuePx;
      if (pull.distance > 8) {
        final dir = Offset(-pull.dx, -pull.dy);
        final len = dir.distance;
        final unit = dir / len;
        final from = cuePx + unit * (EightBallLogic.ballR / 2 * size.width + 4);
        final to = from + unit * min(size.width * 0.42, 28 + len);
        canvas.drawLine(
            from,
            to,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.9)
              ..strokeWidth = 2
              ..strokeCap = StrokeCap.round);
        canvas.drawCircle(aim, 5, Paint()..color = Colors.white70);
      }
    }
    for (final p in g.table.pucks) {
      if (p.pocketed) continue;
      final c = at(p.x, p.y);
      final rad = max(p.r / 2 * size.width, 11.0);
      final col = p.id == 0
          ? Colors.white
          : p.id == 8
              ? const Color(0xFF111111)
              : (p.id <= 7 ? const Color(0xFFFFC21A) : const Color(0xFF3A86FF));
      canvas.drawCircle(c + const Offset(1.5, 2), rad, Paint()..color = Colors.black26);
      canvas.drawCircle(c, rad, Paint()..color = col);
      if (p.id >= 9 && p.id <= 15) {
        canvas.drawCircle(
            c,
            rad * 0.72,
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2);
      }
      if (p.id != 0) {
        final tp = TextPainter(
            text: TextSpan(
                text: '${p.id}',
                style: TextStyle(
                    color: p.id == 8 ? Colors.white : const Color(0xFF1A1440),
                    fontSize: max(8, rad * 0.9),
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
