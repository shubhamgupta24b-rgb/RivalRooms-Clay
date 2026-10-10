import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/ui/components.dart';
import '../../guess_person/models/gp_player.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_shell.dart' show PauseButton;
import '../shell/ticking_play.dart';
import 'smash_karts_logic.dart';

export 'smash_karts_logic.dart';

/// Drawn icons for the power-ups (the logic's emoji map stays for the online screens).
const _weaponIcon = {
  Weapon.rocket: GameIcons.rocket,
  Weapon.triple: GameIcons.tripleRocket,
  Weapon.mine: GameIcons.mine,
  Weapon.gun: GameIcons.gun,
  Weapon.boost: GameIcons.bolt,
  Weapon.shield: GameIcons.shield,
};

final LocalGameInfo smashKartsInfo = LocalGameInfo(
  id: 'smash_karts',
  title: 'Smash Karts',
  emoji: '🏎️',
  color: const Color(0xFFFF5722),
  tagline: 'Grab a box, wreck your friends!',
  rules: const [
    'Drag the joystick to drive round Sunset Park. Drive through a mystery box for a power-up, then tap FIRE.',
    'Rocket, Triple rocket and Mine wreck a kart in one hit. Machine gun: 1 damage a bullet. Boost. Shield.',
    'Karts have 3 hearts. A wrecked kart respawns with a shield. Yellow pads give a speed boost.',
    'Most wrecks in 2 minutes wins! Playing alone, the camera follows your kart. 2 to 4 players.',
  ],
  scoreUnit: 'wrecks',
  splitScreen: true,
  maxPlayers: 4,
  bot: botFor<SmashKartsLogic>((g, b, now) {
    if (!b.due(now)) return;
    smashKartsBot(g, b.seat, b.rng, nowMs: now, memory: b.memory);
    b.wait(now, 90, 160);
  }),
  online: RelaySpec<SmashKartsLogic>(
    create: (n) => SmashKartsLogic(players: n),
    continuous: const {'steer'},
    save: (g) => {
      't': g.elapsedMs,
      'k': [
        for (final k in g.karts) ...[(k.x * 1000).round(), (k.y * 1000).round(), (k.angle * 100).round(), k.weapon.index, k.hp, k.wreckedUntil, k.shieldUntil, k.boostUntil],
      ],
      'h': g.kills,
      's': [
        for (final s in g.shots) ...[(s.x * 1000).round(), (s.y * 1000).round(), (s.angle * 100).round(), s.owner, s.bullet ? 1 : 0]
      ],
      'm': [
        for (final m in g.mines) ...[(m.x * 1000).round(), (m.y * 1000).round(), m.owner, m.bornMs]
      ],
      'b': [for (final b in g.boxes) b.readyAt],
      'x': [
        for (final b in g.blasts) ...[(b.$1 * 1000).round(), (b.$2 * 1000).round(), b.$3, b.$4 ? 1 : 0]
      ],
      'f': [
        for (final f in g.feed) ...[f.killer, f.victim, f.weapon.index, f.ms]
      ],
      'e': g.lastEvent,
      'ea': g.eventAt,
    },
    load: (g, s, me) {
      g.elapsedMs = asInt(s['t']);
      final k = ints(s['k']);
      for (var i = 0; i < g.karts.length; i++) {
        final o = i * 8, kart = g.karts[i];
        kart
          ..x = k[o] / 1000
          ..y = k[o + 1] / 1000
          ..angle = k[o + 2] / 100
          ..weapon = Weapon.values[k[o + 3]]
          ..hp = k[o + 4]
          ..wreckedUntil = k[o + 5]
          ..shieldUntil = k[o + 6]
          ..boostUntil = k[o + 7];
      }
      g.kills.setAll(0, ints(s['h']));
      final sh = ints(s['s']);
      g.shots
        ..clear()
        ..addAll([for (var i = 0; i + 4 < sh.length; i += 5) Shot(sh[i] / 1000, sh[i + 1] / 1000, sh[i + 2] / 100, sh[i + 3], g.elapsedMs, bullet: sh[i + 4] == 1)]);
      final m = ints(s['m']);
      g.mines
        ..clear()
        ..addAll([for (var i = 0; i + 3 < m.length; i += 4) Mine(m[i] / 1000, m[i + 1] / 1000, m[i + 2], m[i + 3])]);
      final b = ints(s['b']);
      for (var i = 0; i < g.boxes.length && i < b.length; i++) {
        g.boxes[i].readyAt = b[i];
      }
      final x = ints(s['x']);
      g.blasts
        ..clear()
        ..addAll([for (var i = 0; i + 3 < x.length; i += 4) (x[i] / 1000, x[i + 1] / 1000, x[i + 2], x[i + 3] == 1)]);
      final f = ints(s['f']);
      g.feed
        ..clear()
        ..addAll([for (var i = 0; i + 3 < f.length; i += 4) Kill(f[i], f[i + 1], Weapon.values[f[i + 2]], f[i + 3])]);
      final e = s['e'] as List, ea = ints(s['ea']);
      for (var i = 0; i < g.lastEvent.length && i < e.length; i++) {
        g.lastEvent[i] = e[i] as String?;
        g.eventAt[i] = ea[i];
      }
    },
    apply: (g, from, name, a) {
      if (a.isEmpty || asInt(a[0]) != from) return;
      if (name == 'steer' && a.length >= 3) g.steer(from, asDouble(a[1]), asDouble(a[2]));
      if (name == 'fire') g.fire(from);
    },
    view: (context, g, players, me) => _Solo(g: g, players: players, me: me),
  ),
  play: (players, onFinished) => TickingPlay<SmashKartsLogic>(
    create: () => SmashKartsLogic(players: players.length),
    onFinished: onFinished,
    builder: (context, g) {
      final people = [
        for (var i = 0; i < players.length; i++)
          if (!BotScope.isBot(context, i)) i
      ];
      // One person (against bots): the camera follows their kart, like the real thing.
      if (people.length == 1) return _Solo(g: g, players: players, me: people.single);
      // Several people on one phone: the whole park, each driving from their own edge.
      final bottom = people.where((i) => i.isEven).toList(), top = people.where((i) => i.isOdd).toList();
      Widget bar(List<int> seats) => Row(children: [for (final i in seats) Expanded(child: _Controls(g: g, player: players[i], index: i, compact: true))]);
      return Column(children: [
        if (top.isNotEmpty) SizedBox(height: 120, child: RotatedBox(quarterTurns: 2, child: bar(top))),
        Expanded(
          child: Stack(children: [
            Positioned.fill(child: _Scene(g: g, players: players, focus: null)),
            Positioned.fill(child: _Hud(g: g, players: players, me: null)),
          ]),
        ),
        if (bottom.isNotEmpty) SizedBox(height: 120, child: bar(bottom)),
      ]);
    },
  ),
);

/// One driver's view: the camera follows [me], HUD on top, controls at the bottom.
class _Solo extends StatelessWidget {
  final SmashKartsLogic g;
  final List<GpPlayer> players;
  final int me;
  const _Solo({required this.g, required this.players, required this.me});
  @override
  Widget build(BuildContext context) => Stack(children: [
        Positioned.fill(child: _Scene(g: g, players: players, focus: me)),
        Positioned.fill(child: _Hud(g: g, players: players, me: me)),
        Positioned(left: 0, right: 0, bottom: 0, height: 170, child: _Controls(g: g, player: players[me], index: me)),
      ]);
}

/// The park, drawn in 2.5D: a perspective tilt over a painted top-down world.
class _Scene extends StatelessWidget {
  final SmashKartsLogic g;
  final List<GpPlayer> players;
  final int? focus; // the kart the camera follows; null: show the whole park
  const _Scene({required this.g, required this.players, required this.focus});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final follow = focus != null;
        return ClipRect(
          child: Container(
            color: const Color(0xFF7CC4F5), // sky beyond the far edge
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateX(follow ? 0.72 : 0.5),
              child: CustomPaint(
                size: Size(c.maxWidth, c.maxHeight),
                painter: _ParkPainter(g, players, focus, follow ? c.maxWidth / 0.85 : min(c.maxWidth / (KartMap.size * 1.04), c.maxHeight * 1.25 / (KartMap.size * 1.04))),
              ),
            ),
          ),
        );
      });
}

class _ParkPainter extends CustomPainter {
  final SmashKartsLogic g;
  final List<GpPlayer> players;
  final int? focus;
  final double s; // pixels per world unit
  _ParkPainter(this.g, this.players, this.focus, this.s);

  static final _text = <String, TextPainter>{};
  static TextPainter _tp(String t, double size, {Color color = Colors.white, FontWeight weight = FontWeight.w900}) {
    final key = '$t|${size.round()}|${color.toARGB32()}';
    return _text.putIfAbsent(key, () {
      if (_text.length > 400) _text.clear();
      return TextPainter(text: TextSpan(text: t, style: TextStyle(fontFamily: Fonts.body, fontSize: size, color: color, fontWeight: weight)), textDirection: TextDirection.ltr)..layout();
    });
  }

  late double _cx, _cy, _ox, _oy;
  Offset o(double x, double y) => Offset(_ox + (x - _cx) * s, _oy + (y - _cy) * s);

  @override
  void paint(Canvas canvas, Size size) {
    if (focus != null) {
      final k = g.karts[focus!];
      _cx = k.x;
      _cy = k.y;
      _oy = size.height * 0.6; // a little below the middle: more road ahead
    } else {
      _cx = KartMap.size / 2;
      _cy = KartMap.size / 2;
      _oy = size.height / 2;
    }
    _ox = size.width / 2;
    final t = g.elapsedMs;
    _ground(canvas);
    _arena(canvas, t);
    // Ground-level things first, then everything that stands up, back to front.
    for (final m in g.mines) {
      _mine(canvas, m, t);
    }
    final standing = <(double, void Function())>[
      for (final b in KartMap.blocks) (b.$4, () => _block(canvas, b)),
      for (final tr in KartMap.trees) (tr.$2 + tr.$3, () => _tree(canvas, tr)),
      for (final b in g.boxes)
        if (g.boxReady(b)) (b.y, () => _box(canvas, b, t)),
      for (var i = 0; i < g.karts.length; i++) (g.karts[i].y + SmashKartsLogic.kartR, () => _kart(canvas, i, t)),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    for (final d in standing) {
      d.$2();
    }
    for (final sh in g.shots) {
      _shot(canvas, sh);
    }
    for (final b in g.blasts) {
      _blast(canvas, b, t);
    }
  }

  void _ground(Canvas canvas) {
    final r = Rect.fromPoints(o(-4, -4), o(KartMap.size + 4, KartMap.size + 4));
    canvas.drawRect(r, Paint()..color = const Color(0xFF5BB34A));
    final stripe = Paint()..color = const Color(0xFF66BE53);
    for (var y = -4.0; y < KartMap.size + 4; y += 0.3) {
      canvas.drawRect(Rect.fromPoints(o(-4, y), o(KartMap.size + 4, y + 0.15)), stripe);
    }
  }

  void _arena(Canvas canvas, int t) {
    final rect = Rect.fromPoints(o(0, 0), o(KartMap.size, KartMap.size));
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(0.12 * s));
    canvas.drawRRect(
        rr, Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF4A4E58), Color(0xFF3A3D45)]).createShader(rect));
    // Painted markings.
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.012 * s
      ..color = Colors.white.withValues(alpha: 0.18);
    canvas.drawCircle(o(1.2, 1.2), 0.42 * s, paint);
    canvas.drawCircle(o(1.2, 1.2), 0.58 * s, paint..color = const Color(0x22FFC107));
    for (var i = 0.0; i < KartMap.size; i += 0.16) {
      canvas.drawLine(o(i, 1.2), o(i + 0.08, 1.2), paint..color = Colors.white.withValues(alpha: 0.12));
      canvas.drawLine(o(1.2, i), o(1.2, i + 0.08), paint);
    }
    // Skid marks.
    final skid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.01 * s
      ..color = Colors.black.withValues(alpha: 0.12);
    for (final (x, y, r) in const [(0.6, 0.75, 0.25), (1.8, 1.7, 0.3), (1.5, 0.6, 0.2)]) {
      canvas.drawArc(Rect.fromCircle(center: o(x, y), radius: r * s), 0.4, 2.2, false, skid);
    }
    // Kerbs: red and white blocks all round the edge.
    final kerb = 0.05 * s;
    var n = 0;
    for (var p = 0.0; p < KartMap.size * 4; p += 0.12, n++) {
      final side = (p / KartMap.size).floor(), along = p % KartMap.size;
      final (a, b) = switch (side) {
        0 => (o(along, 0), o(min(along + 0.12, KartMap.size), 0)),
        1 => (o(KartMap.size, along), o(KartMap.size, min(along + 0.12, KartMap.size))),
        2 => (o(KartMap.size - along, KartMap.size), o(max(KartMap.size - along - 0.12, 0), KartMap.size)),
        _ => (o(0, KartMap.size - along), o(0, max(KartMap.size - along - 0.12, 0))),
      };
      canvas.drawLine(
          a,
          b,
          Paint()
            ..strokeWidth = kerb
            ..color = n.isEven ? const Color(0xFFE53935) : Colors.white);
    }
    // Boost pads: glowing yellow plates with chevrons pointing the way.
    for (final (x, y, a) in KartMap.pads) {
      canvas.save();
      canvas.translate(o(x, y).dx, o(x, y).dy);
      canvas.rotate(a);
      final h = KartMap.padHalf * s;
      final glow = 0.6 + 0.4 * sin(t / 180);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: h * 2, height: h * 2), Radius.circular(h * 0.3)),
          Paint()..color = Color.lerp(const Color(0xFFFFA000), const Color(0xFFFFEB3B), glow)!);
      final chev = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = h * 0.22
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF5D4037);
      for (final dx in [-0.45, 0.15]) {
        canvas.drawPath(
            Path()
              ..moveTo(h * dx, -h * 0.5)
              ..lineTo(h * (dx + 0.35), 0)
              ..lineTo(h * dx, h * 0.5),
            chev);
      }
      canvas.restore();
    }
  }

  /// A crate or wall standing up out of the ground (its front face towards the camera).
  void _block(Canvas canvas, (double, double, double, double) b) {
    final (l, top, r, bot) = b;
    final wide = (r - l) > 0.2 || (bot - top) > 0.2;
    final hgt = (wide ? 0.09 : 0.1) * s;
    final base = Rect.fromPoints(o(l, top), o(r, bot));
    canvas.drawRect(base.shift(Offset(0.02 * s, 0.025 * s)), Paint()..color = Colors.black.withValues(alpha: 0.28)); // shadow
    final topFace = base.shift(Offset(0, -hgt));
    final front = Rect.fromLTRB(base.left, topFace.bottom, base.right, base.bottom);
    final col = wide ? const Color(0xFF90A4AE) : const Color(0xFFB0773D);
    canvas.drawRect(front, Paint()..color = Color.lerp(col, Colors.black, 0.35)!);
    canvas.drawRect(topFace, Paint()..color = col);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.0, 0.006 * s)
      ..color = Color.lerp(col, Colors.black, 0.5)!;
    canvas.drawRect(topFace, edge);
    if (wide) {
      // Hazard stripes on concrete walls.
      final stripe = Paint()..color = const Color(0xFFFFC107);
      for (var x = front.left; x < front.right; x += 0.06 * s) {
        canvas.drawRect(Rect.fromLTWH(x, front.top + front.height * 0.3, 0.03 * s, front.height * 0.4), stripe);
      }
    } else {
      // Planks and a cross brace on wooden crates.
      canvas.drawLine(topFace.topLeft, topFace.bottomRight, edge);
      canvas.drawLine(topFace.topRight, topFace.bottomLeft, edge);
    }
  }

  void _tree(Canvas canvas, (double, double, double) tr) {
    final (x, y, r) = tr;
    final base = o(x, y);
    canvas.drawOval(Rect.fromCenter(center: base + Offset(0.03 * s, 0.03 * s), width: r * 2.6 * s, height: r * 1.6 * s), Paint()..color = Colors.black.withValues(alpha: 0.25));
    canvas.drawRect(Rect.fromCenter(center: base - Offset(0, 0.06 * s), width: r * 0.5 * s, height: 0.12 * s), Paint()..color = const Color(0xFF6D4C41));
    final crown = base - Offset(0, 0.15 * s);
    canvas.drawCircle(crown, r * 1.35 * s, Paint()..color = const Color(0xFF2E7D32));
    canvas.drawCircle(crown - Offset(r * 0.35 * s, r * 0.4 * s), r * 0.8 * s, Paint()..color = const Color(0xFF43A047));
    canvas.drawCircle(crown - Offset(r * 0.55 * s, r * 0.6 * s), r * 0.35 * s, Paint()..color = const Color(0xFF66BB6A));
  }

  /// A floating golden mystery box.
  void _box(Canvas canvas, BoxSpot b, int t) {
    final base = o(b.x, b.y);
    final bob = sin(t / 260 + b.x * 7) * 0.012 * s;
    final w = 0.075 * s;
    canvas.drawOval(Rect.fromCenter(center: base, width: w * 1.3, height: w * 0.55), Paint()..color = Colors.black.withValues(alpha: 0.25));
    final center = base - Offset(0, 0.08 * s) + Offset(0, bob);
    final topFace = Rect.fromCenter(center: center - Offset(0, w * 0.35), width: w, height: w * 0.45);
    final front = Rect.fromLTWH(topFace.left, topFace.bottom, w, w * 0.75);
    canvas.drawRect(front, Paint()..color = const Color(0xFFE6A100));
    canvas.drawRect(topFace, Paint()..color = const Color(0xFFFFD54F));
    canvas.drawRect(
        front,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0xFF8D6E00));
    final q = _tp('?', w * 0.65, color: Colors.white);
    q.paint(canvas, front.center - Offset(q.width / 2, q.height / 2));
    // Sparkle.
    canvas.drawCircle(topFace.topRight, w * 0.08 * (1 + sin(t / 150)), Paint()..color = Colors.white);
  }

  void _mine(Canvas canvas, Mine m, int t) {
    final armed = t - m.bornMs >= SmashKartsLogic.mineArmMs;
    final c = o(m.x, m.y), r = 0.022 * s;
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF263238));
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.3
          ..color = players[m.owner % players.length].color);
    canvas.drawCircle(c, r * 0.35, Paint()..color = armed && (t ~/ 250).isEven ? const Color(0xFFFF1744) : const Color(0xFF616161));
  }

  void _kart(Canvas canvas, int i, int t) {
    final k = g.karts[i];
    final col = players[i % players.length].color;
    final wreck = g.wrecked(i);
    final c = o(k.x, k.y);
    final r = SmashKartsLogic.kartR * s;
    // Shadow.
    canvas.drawOval(Rect.fromCenter(center: c + Offset(r * 0.25, r * 0.35), width: r * 2.6, height: r * 1.7), Paint()..color = Colors.black.withValues(alpha: 0.32));
    canvas.save();
    canvas.translate(c.dx, c.dy - r * 0.25);
    canvas.rotate(k.angle);
    final l = r * 2.3, w = r * 1.55;
    // Boost flames out of the back.
    if (g.boosted(i) && !wreck) {
      final f = 0.8 + 0.2 * sin(t / 40);
      canvas.drawPath(
          Path()
            ..moveTo(-l * 0.45, -w * 0.25)
            ..lineTo(-l * (0.45 + 0.5 * f), 0)
            ..lineTo(-l * 0.45, w * 0.25),
          Paint()..color = const Color(0xFFFFA726));
      canvas.drawPath(
          Path()
            ..moveTo(-l * 0.45, -w * 0.12)
            ..lineTo(-l * (0.45 + 0.3 * f), 0)
            ..lineTo(-l * 0.45, w * 0.12),
          Paint()..color = const Color(0xFFFFF59D));
    }
    // Wheels.
    final tyre = Paint()..color = const Color(0xFF1B1B1B);
    for (final dx in [-l * 0.3, l * 0.3]) {
      for (final dy in [-w * 0.56, w * 0.56]) {
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(dx, dy), width: l * 0.3, height: w * 0.28), Radius.circular(w * 0.08)), tyre);
      }
    }
    final body = wreck ? const Color(0xFF424242) : col;
    // The body: a darker skirt under a lighter top, so it looks solid.
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(0, w * 0.06), width: l, height: w), Radius.circular(w * 0.32)),
        Paint()..color = Color.lerp(body, Colors.black, 0.35)!);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(0, -w * 0.03), width: l * 0.96, height: w * 0.9), Radius.circular(w * 0.3)),
      Paint()
        ..shader = LinearGradient(colors: [Color.lerp(body, Colors.white, 0.35)!, body], begin: Alignment.topCenter, end: Alignment.bottomCenter)
            .createShader(Rect.fromCenter(center: Offset.zero, width: l, height: w)),
    );
    // Nose and bumper.
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(l * 0.42, 0), width: l * 0.16, height: w * 0.86), Radius.circular(w * 0.15)),
        Paint()..color = const Color(0xFF263238));
    // Driver: helmet with a visor.
    canvas.drawCircle(Offset(-l * 0.06, 0), w * 0.3, Paint()..color = Colors.white);
    canvas.drawCircle(
        Offset(-l * 0.06, 0),
        w * 0.3,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.08
          ..color = Color.lerp(col, Colors.black, 0.2)!);
    canvas.drawArc(
        Rect.fromCircle(center: Offset(-l * 0.06, 0), radius: w * 0.22),
        -0.9,
        1.8,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.12
          ..color = const Color(0xFF263238));
    // Spoiler.
    canvas.drawRect(Rect.fromCenter(center: Offset(-l * 0.46, 0), width: l * 0.08, height: w * 1.05), Paint()..color = Color.lerp(body, Colors.black, 0.45)!);
    canvas.restore();

    if (g.shielded(i) && !wreck) {
      canvas.drawCircle(c - Offset(0, r * 0.3), r * 1.9, Paint()..color = const Color(0x334FC3F7));
      canvas.drawCircle(
          c - Offset(0, r * 0.3),
          r * 1.9,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = const Color(0xAA81D4FA));
    }
    if (wreck) {
      // Smoke rising from the wreck.
      final age = (t - (k.wreckedUntil - SmashKartsLogic.wreckMs)).clamp(0, SmashKartsLogic.wreckMs);
      for (var p = 0; p < 4; p++) {
        final u = ((age / 700) + p * 0.25) % 1;
        canvas.drawCircle(c - Offset(sin(p * 2.0) * r * 0.5, r * (0.6 + u * 2.4)), r * (0.35 + u * 0.6), Paint()..color = Colors.grey.withValues(alpha: 0.55 * (1 - u)));
      }
    }
    // Name tag and health above the kart.
    final name = _tp(players[i].name, max(9.0, 0.032 * s));
    final tagCenter = c - Offset(0, r * 2.6);
    final tag = Rect.fromCenter(center: tagCenter, width: name.width + 10, height: name.height + 2);
    canvas.drawRRect(RRect.fromRectAndRadius(tag, const Radius.circular(6)), Paint()..color = col.withValues(alpha: 0.9));
    name.paint(canvas, tag.center - Offset(name.width / 2, name.height / 2));
    final hpW = tag.width * 0.8, seg = hpW / SmashKartsLogic.maxHp;
    for (var h = 0; h < SmashKartsLogic.maxHp; h++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(tagCenter.dx - hpW / 2 + h * seg + 1, tag.bottom + 2, seg - 2, 4), const Radius.circular(2)),
        Paint()..color = h < k.hp ? const Color(0xFF66BB6A) : Colors.black45,
      );
    }
    if (k.weapon != Weapon.none) {
      final ws = max(12.0, 0.045 * s);
      paintIcon(canvas, _weaponIcon[k.weapon]!, Rect.fromLTWH(tag.right + 2, tag.center.dy - ws / 2, ws, ws), color: Colors.white);
    }
  }

  void _shot(Canvas canvas, Shot sh) {
    final c = o(sh.x, sh.y) - Offset(0, 0.03 * s);
    if (sh.bullet) {
      final back = c - Offset(cos(sh.angle), sin(sh.angle)) * 0.06 * s;
      canvas.drawLine(
          back,
          c,
          Paint()
            ..strokeWidth = max(2.0, 0.008 * s)
            ..strokeCap = StrokeCap.round
            ..shader = const LinearGradient(colors: [Color(0x00FFEB3B), Color(0xFFFFF176)]).createShader(Rect.fromPoints(back, c)));
      return;
    }
    final back = c - Offset(cos(sh.angle), sin(sh.angle)) * 0.12 * s;
    canvas.drawLine(
        back,
        c,
        Paint()
          ..strokeWidth = 0.022 * s
          ..strokeCap = StrokeCap.round
          ..shader = LinearGradient(colors: [Colors.white.withValues(alpha: 0), const Color(0xFFFFA726)]).createShader(Rect.fromPoints(back, c)));
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(sh.angle);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: 0.06 * s, height: 0.022 * s), Radius.circular(0.011 * s)), Paint()..color = const Color(0xFFECEFF1));
    canvas.drawCircle(Offset(0.03 * s, 0), 0.011 * s, Paint()..color = const Color(0xFFE53935));
    canvas.restore();
  }

  void _blast(Canvas canvas, (double, double, int, bool) b, int t) {
    final (x, y, ms, big) = b;
    final u = ((t - ms) / (big ? 900 : 450)).clamp(0.0, 1.0);
    final c = o(x, y) - Offset(0, 0.04 * s);
    final r = (big ? 0.16 : 0.06) * s;
    canvas.drawCircle(c, r * (0.4 + u), Paint()..color = Color.lerp(const Color(0xFFFFF176), const Color(0xFFFF5722), u)!.withValues(alpha: (1 - u) * 0.95));
    canvas.drawCircle(c, r * (0.3 + u * 0.6), Paint()..color = Colors.white.withValues(alpha: (1 - u) * 0.6));
    if (big) {
      canvas.drawCircle(
          c,
          r * (0.6 + u * 1.6),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4 * (1 - u)
            ..color = Colors.white.withValues(alpha: 1 - u));
      // Flying debris.
      for (var p = 0; p < 8; p++) {
        final a = p * pi / 4 + ms * 0.001;
        canvas.drawCircle(c + Offset(cos(a), sin(a)) * r * (0.5 + u * 1.8), r * 0.08 * (1 - u), Paint()..color = const Color(0xFF5D4037));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Scores, the clock, the kill feed and big announcements, over the scene.
class _Hud extends StatelessWidget {
  final SmashKartsLogic g;
  final List<GpPlayer> players;
  final int? me;
  const _Hud({required this.g, required this.players, required this.me});

  @override
  Widget build(BuildContext context) {
    final order = [for (var i = 0; i < players.length; i++) i]..sort((a, b) => g.kills[b] - g.kills[a]);
    final feed = g.feed.where((f) => g.elapsedMs - f.ms < 5000).toList().reversed.take(3).toList();
    final event = me == null ? null : g.lastEvent[me!];
    final showEvent = event != null && g.elapsedMs - g.eventAt[me!] < 1300;
    final s = g.secondsLeft;
    return IgnorePointer(
      ignoring: false,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          child: Stack(children: [
            // Left: pause and the leaderboard.
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const PauseButton(),
              const SizedBox(height: 4),
              for (var r = 0; r < order.length; r++)
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.fromLTRB(3, 3, 10, 3),
                  decoration: BoxDecoration(
                    color: NeonPalette.overlay,
                    borderRadius: Radii.rChip,
                    border: Border.all(color: order[r] == me ? Colors.white : players[order[r]].color, width: order[r] == me ? 2 : 1.5),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    // Rank medal: gold, silver, bronze.
                    Container(
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: const [Brand.gold, Color(0xFFC7CEDB), Color(0xFFD08A4E), Color(0xFF5A6072)][r]),
                      child: Text('${r + 1}', style: const TextStyle(fontFamily: Fonts.display, fontSize: 11, color: Color(0xFF2A1E05), height: 1)),
                    ),
                    const SizedBox(width: 5),
                    PlayerBadge(index: PlayerPalette.indexOf(players[order[r]].color) ?? order[r], size: 16, color: players[order[r]].color, initial: players[order[r]].name),
                    const SizedBox(width: 5),
                    Text(players[order[r]].name, style: const TextStyle(fontFamily: Fonts.body, color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                    const SizedBox(width: 8),
                    Text('${g.kills[order[r]]}', style: const TextStyle(fontFamily: Fonts.display, color: Brand.gold, fontSize: 15, height: 1)),
                  ]),
                ),
            ]),
            // Centre top: the clock.
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(color: NeonPalette.overlay, borderRadius: Radii.rChip, border: Border.all(color: Colors.white24)),
                child: Text('${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}',
                    style: TextStyle(fontFamily: Fonts.display, color: s <= 10 ? const Color(0xFFFF5252) : Colors.white, fontSize: 22, fontFeatures: const [FontFeature.tabularFigures()])),
              ),
            ),
            // Right: the kill feed.
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 48),
                child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  for (final f in feed)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: NeonPalette.overlay, borderRadius: Radii.rChip),
                      child: Text.rich(
                          TextSpan(children: [
                            TextSpan(text: players[f.killer].name, style: TextStyle(color: Color.lerp(players[f.killer].color, Colors.white, 0.35))),
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 5), child: GameIcon(_weaponIcon[f.weapon] ?? GameIcons.bomb, size: 14, color: Colors.white)),
                            ),
                            TextSpan(text: players[f.victim].name, style: TextStyle(color: Color.lerp(players[f.victim].color, Colors.white, 0.35))),
                          ]),
                          style: const TextStyle(fontFamily: Fonts.body, color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                    ),
                ]),
              ),
            ),
            // Big announcements in the middle.
            if (showEvent || (me != null && g.wrecked(me!)))
              Align(
                alignment: const Alignment(0, -0.35),
                child: TweenAnimationBuilder<double>(
                  key: ValueKey('${g.eventAt[me!]}'),
                  tween: Tween(begin: 1.6, end: 1),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  builder: (_, v, child) => Transform.scale(scale: v, child: child),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                      g.wrecked(me!) ? 'WRECKED!' : stripEmoji(event!),
                      style: TextStyle(
                        fontFamily: Fonts.display,
                        color: (event ?? '').startsWith('+') ? Brand.gold : const Color(0xFFFF5252),
                        fontSize: 38,
                        shadows: const [Shadow(color: Colors.black87, offset: Offset(0, 3), blurRadius: 6)],
                      ),
                    ),
                    if (g.wrecked(me!))
                      const Text('Respawning...',
                          style: TextStyle(fontFamily: Fonts.body, color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15, shadows: [Shadow(color: Colors.black, blurRadius: 4)])),
                  ]),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

/// One driver's joystick (left) and the big power-up button (right).
class _Controls extends StatefulWidget {
  final SmashKartsLogic g;
  final GpPlayer player;
  final int index;
  final bool compact; // a strip at the edge of a shared phone
  const _Controls({required this.g, required this.player, required this.index, this.compact = false});
  @override
  State<_Controls> createState() => _ControlsState();
}

class _ControlsState extends State<_Controls> {
  Offset knob = Offset.zero;

  void _stick(Offset local, double radius) {
    final v = (local - Offset(radius, radius)) / radius;
    final d = v.distance;
    setState(() => knob = d > 1 ? v / d : v);
    // Rotated players (far side of a shared phone): their "up" is the arena's "down".
    final turned = context.findAncestorWidgetOfExactType<RotatedBox>()?.quarterTurns == 2;
    widget.g.steer(widget.index, atan2(knob.dy, knob.dx) + (turned ? pi : 0), knob.distance);
  }

  void _release() {
    setState(() => knob = Offset.zero);
    widget.g.steer(widget.index, 0, 0);
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g, i = widget.index, c = widget.player.color;
    final weapon = g.karts[i].weapon;
    final has = weapon != Weapon.none;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      decoration: widget.compact
          ? BoxDecoration(color: c.withValues(alpha: 0.16), border: Border(top: BorderSide(color: c, width: 2)))
          : const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00000000), Color(0x99000000)])),
      child: LayoutBuilder(builder: (context, box) {
        final r = min(box.maxHeight * 0.48, box.maxWidth * 0.2);
        return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          GestureDetector(
            onPanStart: (d) => _stick(d.localPosition, r),
            onPanUpdate: (d) => _stick(d.localPosition, r),
            onPanEnd: (_) => _release(),
            onPanCancel: _release,
            child: SizedBox(width: r * 2, height: r * 2, child: CustomPaint(painter: _StickPainter(knob, c))),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              // Shrinks to fit when two drivers share a strip on a small phone.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.bottomCenter,
                child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.end, children: [
                  if (widget.compact)
                    Text(widget.player.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: Fonts.body, color: nameColor(c), fontWeight: FontWeight.w900, fontSize: 13)),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    GameIcon(has ? _weaponIcon[weapon]! : GameIcons.mysteryBox, size: 16, color: Colors.white),
                    const SizedBox(width: 5),
                    Text(has ? weaponName[weapon]! : 'Find a box',
                        textAlign: TextAlign.center, style: TextStyle(fontFamily: Fonts.body, color: has ? Colors.white : Colors.white60, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.6)),
                  ]),
                  const SizedBox(height: 4),
                  // Health hearts.
                  Semantics(
                    label: '${g.karts[i].hp} of ${SmashKartsLogic.maxHp} hearts',
                    excludeSemantics: true,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      for (var h = 0; h < SmashKartsLogic.maxHp; h++)
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 1.5), child: GameIcon(h < g.karts[i].hp ? GameIcons.heart : GameIcons.heartEmpty, size: 16, color: const Color(0xFFFF5B6E))),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
          Semantics(
            button: true,
            label: 'Fire',
            child: GestureDetector(
              onTapDown: (_) {
                if (!has) return;
                HapticFeedback.mediumImpact().ignore();
                g.fire(i);
              },
              child: TweenAnimationBuilder<double>(
                key: ValueKey(weapon),
                tween: Tween(begin: has ? 1.3 : 1, end: 1),
                duration: const Duration(milliseconds: 350),
                curve: Curves.elasticOut,
                builder: (_, v, child) => Transform.scale(scale: v, child: child),
                child: Container(
                  width: r * 1.7,
                  height: r * 1.7,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: has
                        ? RadialGradient(colors: [Color.lerp(c, Colors.white, 0.3)!, c, Color.lerp(c, Colors.black, 0.3)!])
                        : const RadialGradient(colors: [Color(0x55FFFFFF), Color(0x22FFFFFF)]),
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [if (has) BoxShadow(color: c.withValues(alpha: 0.8), blurRadius: 18)],
                  ),
                  child: FittedBox(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: has
                          ? Column(mainAxisSize: MainAxisSize.min, children: [
                              GameIcon(_weaponIcon[weapon]!, size: 34, color: Colors.white),
                              const Text('FIRE', style: TextStyle(fontFamily: Fonts.display, color: Colors.white, fontSize: 16, height: 1)),
                            ])
                          : Text('FIRE', style: TextStyle(fontFamily: Fonts.display, color: Colors.white.withValues(alpha: 0.5), fontSize: 26)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ]);
      }),
    );
  }
}

class _StickPainter extends CustomPainter {
  final Offset knob;
  final Color color;
  _StickPainter(this.knob, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2, c = Offset(r, r);
    canvas.drawCircle(c, r, Paint()..color = Colors.black.withValues(alpha: 0.3));
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Colors.white54);
    // Direction arrows.
    final arrow = Paint()..color = Colors.white38;
    for (var a = 0; a < 4; a++) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(a * pi / 2);
      canvas.drawPath(
          Path()
            ..moveTo(0, -r * 0.88)
            ..lineTo(-r * 0.1, -r * 0.72)
            ..lineTo(r * 0.1, -r * 0.72),
          arrow);
      canvas.restore();
    }
    final k = c + knob * r * 0.55;
    canvas.drawCircle(k + const Offset(0, 3), r * 0.4, Paint()..color = Colors.black38);
    canvas.drawCircle(
        k,
        r * 0.4,
        Paint()
          ..shader = RadialGradient(center: const Alignment(-0.3, -0.3), colors: [Color.lerp(color, Colors.white, 0.4)!, color])
              .createShader(Rect.fromCircle(center: k, radius: r * 0.4)));
    canvas.drawCircle(
        k,
        r * 0.4,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Colors.white);
  }

  @override
  bool shouldRepaint(_StickPainter old) => old.knob != knob;
}
