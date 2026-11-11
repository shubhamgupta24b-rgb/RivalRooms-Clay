import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/ui/components.dart';
import '../../guess_person/models/gp_player.dart';
import '../shell/game_hud.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/ticking_play.dart';

class _Tank {
  double x, y, aim;
  int cool = 0;
  _Tank(this.x, this.y, this.aim);
}

class _Shot {
  double x, y, vx, vy;
  final int owner;
  _Shot(this.x, this.y, this.vx, this.vy, this.owner);
}

/// Top-down tank duel. Drag in your half to drive. Fire sits above the field
/// so it never covers the tanks. First to 5 hits, or the leader after a minute.
class TankBattleLogic extends LocalGameLogic {
  static const width = 1.0, height = 1.45, target = 5;
  final List<_Tank> tanks;
  final List<_Shot> shots = [];
  final List<int> hits = [0, 0];
  int elapsed = 0;
  int? winner;
  int _last = 0;

  static const obstacles = <Rect>[
    Rect.fromLTWH(0.08, 0.62, 0.28, 0.08),
    Rect.fromLTWH(0.64, 0.78, 0.28, 0.08),
    Rect.fromLTWH(0.38, 0.32, 0.24, 0.1),
  ];

  TankBattleLogic()
      : tanks = [_Tank(0.5, 1.15, -1.57), _Tank(0.5, 0.3, 1.57)];

  static bool blocked(double x, double y) {
    const pad = 0.05;
    for (final r in obstacles) {
      if (x > r.left - pad &&
          x < r.right + pad &&
          y > r.top - pad &&
          y < r.bottom + pad) {
        return true;
      }
    }
    return false;
  }

  @override
  bool get finished => winner != null || elapsed >= 60000;
  @override
  List<int> get scores => [
        for (var i = 0; i < 2; i++) winner == i ? hits[i] + 10 : hits[i]
      ];

  void drive(int player, double x, double y) {
    if (forward('drive', [player, x, y])) return;
    if (finished || player < 0 || player > 1) return;
    final t = tanks[player];
    final dx = x - t.x, dy = y - t.y;
    final dist = sqrt(dx * dx + dy * dy);
    if (dist < 0.02) return;
    t.aim = atan2(dy, dx);
    final step = min(0.045, dist);
    final nx = (t.x + cos(t.aim) * step).clamp(0.08, width - 0.08);
    final ny = (t.y + sin(t.aim) * step).clamp(0.08, height - 0.08);
    if (!blocked(nx, ny)) {
      t.x = nx;
      t.y = ny;
    }
    notifyListeners();
  }

  void fire(int player) {
    if (forward('fire', [player])) return;
    if (finished || player < 0 || player > 1) return;
    final t = tanks[player];
    if (elapsed < t.cool) return;
    t.cool = elapsed + 700;
    shots.add(_Shot(t.x + cos(t.aim) * 0.06, t.y + sin(t.aim) * 0.06,
        cos(t.aim) * 0.85, sin(t.aim) * 0.85, player));
    notifyListeners();
  }

  @override
  void update(int ms) {
    if (finished) return;
    final dt = ((ms - _last) / 1000).clamp(0.0, 0.05);
    _last = elapsed = ms;
    shots.removeWhere((s) {
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      if (s.x < 0 || s.y < 0 || s.x > width || s.y > height) return true;
      if (blocked(s.x, s.y)) return true;
      final other = 1 - s.owner;
      final t = tanks[other];
      if ((Offset(s.x, s.y) - Offset(t.x, t.y)).distance < 0.07) {
        hits[s.owner]++;
        if (hits[s.owner] >= target) winner = s.owner;
        return true;
      }
      return false;
    });
    if (elapsed >= 60000 && winner == null) {
      if (hits[0] != hits[1]) winner = hits[0] > hits[1] ? 0 : 1;
    }
    notifyListeners();
  }

  Map<String, dynamic> save() => {
        't': elapsed,
        'hits': hits,
        'win': winner,
        'tanks': [for (final t in tanks) [t.x, t.y, t.aim, t.cool]],
        'shots': [
          for (final s in shots) [s.x, s.y, s.vx, s.vy, s.owner]
        ],
      };

  void load(Map<String, dynamic> s) {
    elapsed = asInt(s['t']);
    hits.setAll(0, ints(s['hits']));
    winner = nInt(s['win']);
    final body = s['tanks'] as List;
    for (var i = 0; i < 2; i++) {
      final row = body[i] as List;
      tanks[i]
        ..x = (row[0] as num).toDouble()
        ..y = (row[1] as num).toDouble()
        ..aim = (row[2] as num).toDouble()
        ..cool = (row[3] as num).toInt();
    }
    shots
      ..clear()
      ..addAll([
        for (final row in s['shots'] as List)
          _Shot((row[0] as num).toDouble(), (row[1] as num).toDouble(),
              (row[2] as num).toDouble(), (row[3] as num).toDouble(),
              (row[4] as num).toInt())
      ]);
  }
}

final tankBattleInfo = LocalGameInfo(
  id: 'tank_battle',
  title: 'Tank Battle',
  emoji: '🛡️',
  color: const Color(0xFF6B8F71),
  tagline: 'Drive, fire, land five hits!',
  rules: const [
    'Drag in your half of the field to drive that way.',
    'The Fire buttons sit above the field, clear of the tanks.',
    'First to 5 hits wins. After a minute, the most hits wins.',
  ],
  scoreUnit: 'hits',
  splitScreen: true,
  bot: botFor<TankBattleLogic>((g, b, now) {
    if (g.finished) return;
    final me = g.tanks[b.seat];
    final them = g.tanks[1 - b.seat];
    final aim = atan2(them.y - me.y, them.x - me.x) + b.aimNoise(0.8);
    final lead = b.skill.tracking;
    g.drive(b.seat, me.x + cos(aim) * 0.2 * lead, me.y + sin(aim) * 0.2 * lead);
    if (!b.thinkFirst('fire${g.hits[b.seat]}', now, 400, 900)) return;
    if (!b.slips()) g.fire(b.seat);
  }),
  online: RelaySpec<TankBattleLogic>(
    create: (n) => TankBattleLogic(),
    save: (g) => g.save(),
    load: (g, s, me) => g.load(s),
    apply: (g, from, name, a) {
      if (a.isEmpty || asInt(a[0]) != from) return;
      if (name == 'drive' && a.length >= 3) {
        g.drive(from, asDouble(a[1]), asDouble(a[2]));
      }
      if (name == 'fire') g.fire(from);
    },
    continuous: const {'drive'},
    view: (context, g, players, me) =>
        _Field(g: g, players: players, me: me),
  ),
  play: (players, onFinished) => TickingPlay<TankBattleLogic>(
      create: () => TankBattleLogic(),
      onFinished: onFinished,
      builder: (context, g) => _Field(g: g, players: players, me: null)),
);

class _Field extends StatelessWidget {
  final TankBattleLogic g;
  final List<GpPlayer> players;
  final int? me;
  const _Field({required this.g, required this.players, required this.me});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      GameHud(players: players, scores: g.hits, turn: null),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        child: Row(children: [
          Expanded(child: _fire(0)),
          const SizedBox(width: 8),
          Expanded(child: _fire(1)),
        ]),
      ),
      const SizedBox(height: 6),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: LayoutBuilder(builder: (context, c) {
            Offset table(Offset p) => Offset(
                p.dx / c.maxWidth * TankBattleLogic.width,
                p.dy / c.maxHeight * TankBattleLogic.height);
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (d) {
                final at = table(d.localPosition);
                final seat = me ?? (at.dy > TankBattleLogic.height / 2 ? 0 : 1);
                if (me != null && seat != me) return;
                g.drive(seat, at.dx, at.dy);
              },
              child: CustomPaint(
                  painter: _TankPainter(g, players.map((p) => p.color).toList()),
                  child: const SizedBox.expand()),
            );
          }),
        ),
      ),
    ]);
  }

  Widget _fire(int seat) {
    if (me != null && me != seat) return const SizedBox.shrink();
    return GoldButton(me == null ? 'P${seat + 1} fire' : 'Fire',
        height: 44, fontSize: 16, onPressed: () => g.fire(seat));
  }
}

class _TankPainter extends CustomPainter {
  final TankBattleLogic g;
  final List<Color> colors;
  _TankPainter(this.g, this.colors);
  @override
  void paint(Canvas canvas, Size size) {
    final arena = RRect.fromRectAndRadius(
        Offset.zero & size, const Radius.circular(28));
    canvas.drawRRect(
        arena.shift(const Offset(0, 6)), Paint()..color = const Color(0xFF5C3A1E));
    canvas.drawRRect(
        arena,
        Paint()
          ..shader = const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFE7C48A), Color(0xFFC48A4A)])
              .createShader(Offset.zero & size));
    canvas.drawRRect(
        arena,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..color = const Color(0xFF6B4423));
    Offset at(double x, double y) => Offset(
        x / TankBattleLogic.width * size.width,
        y / TankBattleLogic.height * size.height);
    for (final r in TankBattleLogic.obstacles) {
      final rect = Rect.fromLTRB(
          at(r.left, r.top).dx,
          at(r.left, r.top).dy,
          at(r.right, r.bottom).dx,
          at(r.right, r.bottom).dy);
      final block = RRect.fromRectAndRadius(rect, const Radius.circular(10));
      canvas.drawRRect(
          block.shift(const Offset(0, 3)), Paint()..color = const Color(0xFF3A2414));
      canvas.drawRRect(
          block,
          Paint()
            ..shader = const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF8D6A3A), Color(0xFF5C3A1E)])
                .createShader(rect));
    }
    for (var i = 0; i < 2; i++) {
      final t = g.tanks[i];
      final c = at(t.x, t.y);
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(t.aim);
      final body = RRect.fromRectAndRadius(
          const Rect.fromLTWH(-18, -14, 36, 28), const Radius.circular(10));
      canvas.drawRRect(
          body.shift(const Offset(0, 3)), Paint()..color = Colors.black26);
      canvas.drawRRect(body, Paint()..color = colors[i]);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTWH(-10, -8, 16, 10), const Radius.circular(6)),
          Paint()..color = Colors.white.withValues(alpha: 0.35));
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTWH(8, -4, 16, 8), const Radius.circular(4)),
          Paint()..color = const Color(0xFF2B2118));
      canvas.restore();
    }
    for (final s in g.shots) {
      canvas.drawCircle(
          at(s.x, s.y) + const Offset(1, 2), 5, Paint()..color = Colors.black26);
      canvas.drawCircle(at(s.x, s.y), 5, Paint()..color = const Color(0xFFFFC21A));
    }
  }

  @override
  bool shouldRepaint(covariant _TankPainter old) => true;
}
