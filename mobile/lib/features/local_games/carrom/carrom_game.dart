import 'dart:math';
import 'package:flutter/material.dart';
import '../../guess_person/models/gp_player.dart';
import '../shell/game_hud.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/ticking_play.dart';
import '../table/table_physics.dart';

/// Carrom: 6 white, 6 black, and the queen. Pocket your colour. The queen must be covered
/// by your own coin on the next shot. Pocketing the striker is a foul.
class CarromLogic extends LocalGameLogic {
  static const queen = 1;
  final TableSim table;
  int turn = 0;
  int? winner;
  bool moving = false;
  bool queenCover = false;
  int coverFor = -1;
  bool queenDone = false;
  String message = 'Pull back from the striker and let go';
  int _last = 0;
  double aim = 1.2;
  double power = 0.8;
  final Set<int> _before = {};

  CarromLogic() : table = _rack() {
    _before.addAll(_pocketed());
  }

  static TableSim _rack() {
    final pucks = <Puck>[Puck(0, 0.5, 0.78, r: 0.038, mass: 1.4)];
    pucks.add(Puck(queen, 0.5, 0.42, r: 0.026));
    for (var i = 0; i < 12; i++) {
      final a = i * pi / 6;
      pucks.add(
          Puck(2 + i, 0.5 + cos(a) * 0.09, 0.42 + sin(a) * 0.09, r: 0.026));
    }
    return TableSim(
      w: 1,
      h: 1,
      pucks: pucks,
      pockets: const [
        Offset(0.04, 0.04),
        Offset(0.96, 0.04),
        Offset(0.04, 0.96),
        Offset(0.96, 0.96)
      ],
      pocketR: 0.055,
      friction: 1.5,
    );
  }

  bool white(int id) => id >= 2 && id <= 7;
  bool black(int id) => id >= 8;
  bool mine(int id) => turn == 0 ? white(id) : black(id);
  Set<int> _pocketed() => {
        for (final p in table.pucks)
          if (p.pocketed) p.id
      };
  int pocketed(bool whites) => table.pucks
      .where((p) => p.pocketed && (whites ? white(p.id) : black(p.id)))
      .length;

  @override
  bool get finished => winner != null;
  @override
  List<int> get scores => [
        pocketed(true) + (queenDone && winner == 0 ? 3 : 0),
        pocketed(false) + (queenDone && winner == 1 ? 3 : 0)
      ];
  @override
  void update(int ms) {
    if (!moving) return;
    final dt = ((ms - _last) / 1000).clamp(0.0, 0.05);
    _last = ms;
    table.step(dt);
    if (table.resting || ms - _last > 6000) _settle();
    notifyListeners();
  }

  void shoot(int player, double angle, double pow) {
    if (forward('shoot', [player, angle, pow])) return;
    if (finished || moving || player != turn) return;
    aim = angle;
    power = pow.clamp(0.35, 1.8);
    final s = table.byId(0);
    if (s.pocketed) _resetStriker();
    s.vx = cos(angle) * power * 2.4;
    s.vy = sin(angle) * power * 2.4;
    _before
      ..clear()
      ..addAll(_pocketed());
    table.clearHits();
    moving = true;
    _last = 0;
    notifyListeners();
  }

  void _settle() {
    moving = false;
    final now = _pocketed();
    final fresh = now.difference(_before);
    final strikerIn = fresh.contains(0);
    if (strikerIn) {
      message = 'Foul: striker in the pocket';
      if (queenCover && coverFor == turn) _returnQueen();
      turn = 1 - turn;
      _resetStriker();
      _checkWin();
      return;
    }
    final own = fresh.where(mine).length;
    final queenIn = fresh.contains(queen);
    if (queenIn) {
      queenCover = true;
      coverFor = turn;
      message = 'Cover the queen';
    }
    if (queenCover && coverFor == turn && own > 0) {
      queenCover = false;
      queenDone = true;
      message = 'Queen covered';
    } else if (queenCover && coverFor == turn && own == 0 && !queenIn) {
      _returnQueen();
      message = 'Queen returned';
    }
    final hitCoin = _struckCoin();
    if (!hitCoin) {
      message = 'Foul: missed the coins';
      if (queenCover && coverFor == turn) _returnQueen();
      turn = 1 - turn;
    } else if (own > 0) {
      message = 'Pocket! Shoot again';
    } else {
      turn = 1 - turn;
      message = 'Other player';
    }
    _resetStriker();
    _checkWin();
  }

  bool _struckCoin() {
    for (var i = 0; i < table.hitA.length; i++) {
      final a = table.hitA[i], b = table.hitB[i];
      if (a == 0 && b != 0 || b == 0 && a != 0) return true;
    }
    return false;
  }

  /// The striker always returns to the shooter's baseline, clear of the coins.
  void _resetStriker() {
    final s = table.byId(0);
    s.pocketed = false;
    s.vx = s.vy = 0;
    s.x = 0.5;
    s.y = turn == 0 ? 0.78 : 0.22;
  }

  void _returnQueen() {
    final q = table.byId(queen);
    q.pocketed = false;
    q.x = 0.5;
    q.y = 0.42;
    q.vx = q.vy = 0;
    queenCover = false;
    coverFor = -1;
  }

  void _checkWin() {
    final w = table.pucks.where((p) => white(p.id) && !p.pocketed).isEmpty;
    final b = table.pucks.where((p) => black(p.id) && !p.pocketed).isEmpty;
    if (w && queenDone) winner = 0;
    if (b && queenDone && winner == null) winner = 1;
  }

  List<double> pack() => [
        for (final p in table.pucks) ...[p.x, p.y, p.pocketed ? 1.0 : 0.0]
      ];
  void unpack(List<double> v) {
    for (var i = 0; i < table.pucks.length; i++) {
      final p = table.pucks[i];
      p.x = v[i * 3];
      p.y = v[i * 3 + 1];
      p.pocketed = v[i * 3 + 2] > 0.5;
      p.vx = p.vy = 0;
    }
  }
}

final carromInfo = LocalGameInfo(
  id: 'carrom',
  title: 'Carrom',
  emoji: '🎯',
  color: const Color(0xFFC4A574),
  tagline: 'Pocket your coins, cover the queen!',
  rules: const [
    'Drag from the striker to aim. Release to shoot. Power follows how far you drag.',
    'Pocket your colour to shoot again. The red queen must be covered by your own coin next shot.',
    'The striker returns to your baseline every turn. Pocketing it, or missing the coins, is a foul.',
    'First to pocket all six of their coins, with the queen covered, wins. Scores sit above the board.',
  ],
  scoreUnit: 'coins',
  splitScreen: false,
  minPlayers: 2,
  maxPlayers: 2,
  bot: botFor<CarromLogic>((g, b, now) {
    if (g.finished || g.moving || g.turn != b.seat) return;
    final down = g.table.pucks.where((p) => p.pocketed).length;
    if (!b.thinkFirst((g.turn, down, g.queenCover), now, 500, 1200)) return;
    final striker = g.table.byId(0);
    final mine = [
      for (final p in g.table.pucks)
        if (!p.pocketed && p.id != 0 && (g.mine(p.id) || p.id == CarromLogic.queen))
          p
    ];
    if (mine.isEmpty) return;
    final target = b.prefer(mine);
    var angle = atan2(target.y - striker.y, target.x - striker.x);
    if (b.slips()) angle += b.aimNoise(1.2);
    g.shoot(b.seat, angle, b.slips() ? 0.5 : 1.1);
  }),
  online: RelaySpec<CarromLogic>(
    create: (n) => CarromLogic(),
    save: (g) => {
      'p': g.pack(),
      'turn': g.turn,
      'msg': g.message,
      'win': g.winner,
      'cover': g.queenCover,
      'done': g.queenDone,
      'moving': g.moving
    },
    load: (g, s, me) {
      g.unpack(doubles(s['p']));
      g.turn = asInt(s['turn']);
      g.message = s['msg'] as String;
      g.winner = nInt(s['win']);
      g.queenCover = s['cover'] == true;
      g.queenDone = s['done'] == true;
      g.moving = s['moving'] == true;
    },
    apply: (g, from, name, a) {
      if (name == 'shoot' && from == g.turn)
        g.shoot(from, asDouble(a[1]), asDouble(a[2]));
    },
    view: (context, g, players, me) =>
        _CarromView(g: g, players: players, me: me),
  ),
  play: (players, onFinished) => TickingPlay<CarromLogic>(
      create: () => CarromLogic(),
      onFinished: onFinished,
      builder: (context, g) => _CarromView(g: g, players: players, me: null)),
);

class _CarromView extends StatelessWidget {
  final CarromLogic g;
  final List<GpPlayer> players;
  final int? me;
  const _CarromView({required this.g, required this.players, required this.me});
  @override
  Widget build(BuildContext context) {
    final seat = me ?? g.turn;
    final mine = seat == g.turn && !g.moving && g.winner == null;
    return Column(children: [
      GameHud(
          players: players,
          scores: g.scores,
          turn: g.finished ? null : g.turn,
          trailing: Text(
              g.queenDone
                  ? 'Queen covered'
                  : (g.queenCover ? 'Cover queen' : ''),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800))),
      Padding(
          padding: const EdgeInsets.all(8),
          child: Text(g.message,
              style: const TextStyle(
                  color: Colors.white70, fontWeight: FontWeight.w800))),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: AspectRatio(
            aspectRatio: 1,
            child: _Aim(
              enabled: mine,
              onShoot: (a, p) => g.shoot(seat, a, p),
              child: CustomPaint(
                  painter: _CarromPainter(g), child: const SizedBox.expand()),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _Aim extends StatefulWidget {
  final bool enabled;
  final void Function(double angle, double power) onShoot;
  final Widget child;
  const _Aim(
      {required this.enabled, required this.onShoot, required this.child});
  @override
  State<_Aim> createState() => _AimState();
}

class _AimState extends State<_Aim> {
  Offset? _start;
  Offset? _end;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: widget.enabled
          ? (d) => setState(() => _start = _end = d.localPosition)
          : null,
      onPanUpdate:
          widget.enabled ? (d) => setState(() => _end = d.localPosition) : null,
      onPanEnd: widget.enabled
          ? (_) {
              final a = _start, b = _end;
              if (a != null && b != null) {
                final d = a - b;
                if (d.distance > 12) {
                  final box = context.size ?? const Size(200, 200);
                  final angle = atan2(d.dy / box.height, d.dx / box.width);
                  widget.onShoot(angle, (d.distance / 120).clamp(0.35, 1.8));
                }
              }
              setState(() => _start = _end = null);
            }
          : null,
      child: widget.child,
    );
  }
}

class _CarromPainter extends CustomPainter {
  final CarromLogic g;
  _CarromPainter(this.g);
  @override
  void paint(Canvas canvas, Size size) {
    final wood =
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16));
    canvas.drawRRect(wood, Paint()..color = const Color(0xFFC4A574));
    final inner = Rect.fromLTWH(18, 18, size.width - 36, size.height - 36);
    canvas.drawRRect(RRect.fromRectAndRadius(inner, const Radius.circular(8)),
        Paint()..color = const Color(0xFFE7D3A1));
    final base = Paint()
      ..color = const Color(0xFF8A5A2B)
      ..strokeWidth = 2;
    for (final y in [0.22, 0.78]) {
      final py = y * size.height;
      canvas.drawLine(
          Offset(size.width * 0.12, py), Offset(size.width * 0.88, py), base);
      canvas.drawCircle(Offset(size.width * 0.5, py), 6,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = const Color(0xFF8A5A2B));
    }
    for (final c in g.table.pockets) {
      canvas.drawCircle(
          Offset(c.dx * size.width, c.dy * size.height),
          g.table.pocketR * size.width,
          Paint()..color = const Color(0xFF2B2118));
    }
    for (final p in g.table.pucks) {
      if (p.pocketed && p.id != 0) continue;
      final c = Offset(p.x * size.width, p.y * size.height);
      final col = p.id == 0
          ? const Color(0xFF2E6BFF)
          : p.id == CarromLogic.queen
              ? const Color(0xFFE23B4A)
              : (p.id <= 7 ? Colors.white : const Color(0xFF222222));
      canvas.drawCircle(c, p.r * size.width, Paint()..color = col);
    }
  }

  @override
  bool shouldRepaint(covariant _CarromPainter old) => true;
}
