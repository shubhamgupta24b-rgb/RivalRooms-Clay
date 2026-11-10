import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/audio/game_audio.dart';
import '../../../core/ui/components.dart';
import '../../guess_person/models/gp_player.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/game_hud.dart';
import '../shell/sky.dart';
import '../shell/ticking_play.dart';

/// Fort cells.
abstract final class Cell {
  static const empty = 0, wood = 1, stone = 2, pig = 3, cracked = 4;
}

/// Slingshot: pull back and fling birds at the pigs' fort. Wood breaks, stone takes two
/// hits, and blocks that fall on a pig squash it. 3 birds a fort; every pig is 100,
/// every block 10, and a bird left over is a 50 bonus. Players take turns on the same fort.
/// The scene is 1 wide and [h] tall; columns go left to right, rows up from the ground.
class SlingLogic extends LocalGameLogic {
  static const h = 0.62,
      ground = 0.56,
      cols = 7,
      rows = 8,
      cell = 0.05,
      fortX = 0.58;
  static const launchX = 0.13,
      launchY = 0.4,
      gravity = 0.95,
      maxSpeed = 1.75,
      birdR = 0.018;
  static const birdsEach = 3, rounds = 3;
  final int players;
  final List<int> score;
  int turn = 0, round = 1, birds = birdsEach, now = 0, _last = 0, _settleAt = 0;
  late List<List<int>> grid; // [col][row]
  List<List<int>> fall = [];
  List<double>? bird; // x, y, vx, vy
  bool settling = false, done = false;
  int? nextAt; // the turn passes at this time
  final List<(double, double, int, int)> puffs =
      []; // x, y, when, kind (pig / block)
  String? message;
  int messageAt = -10000;

  SlingLogic({this.players = 2}) : score = List.filled(players, 0) {
    grid = buildFort(round);
  }

  @override
  bool get finished => done;
  @override
  List<int> get scores => score;

  bool get ready => !done && bird == null && !settling && nextAt == null;
  int get pigsLeft =>
      grid.fold(0, (n, c) => n + c.where((x) => x == Cell.pig).length);

  /// The same fort for everyone in a round.
  static List<List<int>> buildFort(int round) {
    final rng = Random(round * 7919 + 13);
    final g = [for (var c = 0; c < cols; c++) List.filled(rows, Cell.empty)];
    final heights = [
      for (var c = 0; c < cols; c++) 1 + rng.nextInt(min(5, 2 + round))
    ];
    for (var c = 0; c < cols; c++) {
      for (var r = 0; r < heights[c]; r++) {
        g[c][r] = (r == 0 && rng.nextDouble() < 0.4) ||
                rng.nextDouble() < 0.18 + round * 0.05
            ? Cell.stone
            : Cell.wood;
      }
    }
    // Pigs on top of three towers (some with a lid on), and one hiding inside.
    final tops = [for (var c = 0; c < cols; c++) c]..shuffle(rng);
    for (final c in tops.take(3)) {
      if (heights[c] < rows - 1) {
        g[c][heights[c]] = Cell.pig;
        if (rng.nextBool() && heights[c] + 1 < rows)
          g[c][heights[c] + 1] = Cell.wood;
      }
    }
    final inside = tops[3];
    if (heights[inside] >= 2) g[inside][1] = Cell.pig;
    return g;
  }

  Rect cellRect(int c, int r) =>
      Rect.fromLTWH(fortX + c * cell, ground - (r + 1) * cell, cell, cell);

  /// Which cell a point is in, if it's inside the fort.
  static (int, int)? cellAt(double x, double y) {
    if (x < fortX || x >= fortX + cols * cell || y > ground) return null;
    final c = ((x - fortX) / cell).floor(), r = ((ground - y) / cell).floor();
    if (r < 0 || r >= rows) return null;
    return (c, r);
  }

  void fling(int player, double angle, double power) {
    if (forward('fling', [player, angle, power])) return;
    if (!ready || player != turn || birds <= 0) return;
    final v = power.clamp(0.1, 1.0) * maxSpeed;
    bird = [launchX, launchY, cos(angle) * v, -sin(angle) * v];
    HapticFeedback.lightImpact().ignore();
    GameAudio.sfx('throw');
    notifyListeners();
  }

  /// The first fort cell a shot would touch (for aiming), or null for a miss.
  (int, int)? firstHit(double angle, double power) {
    final v = power.clamp(0.1, 1.0) * maxSpeed;
    var (x, y, vx, vy) = (launchX, launchY, cos(angle) * v, -sin(angle) * v);
    for (var i = 0; i < 600; i++) {
      x += vx / 120;
      vy += gravity / 120;
      y += vy / 120;
      if (y > ground || x > 1.05) return null;
      final at = cellAt(x, y);
      if (at != null && grid[at.$1][at.$2] != Cell.empty) return at;
    }
    return null;
  }

  @override
  void update(int ms) {
    final dt = ((ms - _last) / 1000).clamp(0.0, 0.05);
    _last = now = ms;
    puffs.removeWhere((p) => ms - p.$3 > 600);
    final b = bird;
    if (b != null) {
      for (var i = 0; i < 6 && bird != null; i++) {
        _fly(b, dt / 6);
      }
    } else if (settling && ms >= _settleAt) {
      _settleAt = ms + 70;
      if (!_settleStep()) {
        settling = false;
        _shotOver();
      }
    } else if (nextAt != null && ms >= nextAt!) {
      nextAt = null;
      _nextTurn();
    }
    notifyListeners();
  }

  void _fly(List<double> b, double dt) {
    b[0] += b[2] * dt;
    b[3] += gravity * dt;
    b[1] += b[3] * dt;
    if (b[1] > ground - birdR || b[0] > 1.05 || b[0] < -0.05) {
      _landed();
      return;
    }
    final at = cellAt(b[0], b[1]);
    if (at == null) return;
    final (c, r) = at;
    final kind = grid[c][r];
    if (kind == Cell.empty) return;
    final rect = cellRect(c, r);
    var slow = 0.6;
    switch (kind) {
      case Cell.pig:
        grid[c][r] = Cell.empty;
        _pop(c, r, rect, true);
        slow = 0.8;
      case Cell.stone:
        grid[c][r] = Cell.cracked;
        slow = 0.3;
        b[2] = -b[2].abs(); // bounces off
        b[0] = rect.left - birdR;
        GameAudio.sfx('hit');
      case _:
        grid[c][r] = Cell.empty;
        _pop(c, r, rect, false);
    }
    b[2] *= slow;
    b[3] *= slow;
    HapticFeedback.selectionClick().ignore();
    if (sqrt(b[2] * b[2] + b[3] * b[3]) < 0.25) _landed();
  }

  void _pop(int c, int r, Rect rect, bool pig) {
    score[turn] += pig ? 100 : 10;
    puffs.add((rect.center.dx, rect.center.dy, now, pig ? 1 : 0));
    GameAudio.sfx(pig ? 'pop' : 'hit');
  }

  void _landed() {
    bird = null;
    settling = true;
    _settleAt = now + 150;
    fall = [for (var c = 0; c < cols; c++) List.filled(rows, 0)];
  }

  /// Drops everything with a gap under it by one row. A block that has fallen and lands on
  /// a pig squashes it; a pig that falls two rows is done for too. False once nothing moves.
  bool _settleStep() {
    var moved = false;
    for (var c = 0; c < cols; c++) {
      for (var r = 1; r < rows; r++) {
        final k = grid[c][r];
        if (k == Cell.empty) continue;
        final below = grid[c][r - 1];
        if (below == Cell.empty) {
          grid[c][r - 1] = k;
          grid[c][r] = Cell.empty;
          fall[c][r - 1] = fall[c][r] + 1;
          fall[c][r] = 0;
          moved = true;
        } else if (below == Cell.pig && k != Cell.pig && fall[c][r] > 0) {
          grid[c][r - 1] = Cell.empty;
          _pop(c, r - 1, cellRect(c, r - 1), true);
          moved = true;
        }
      }
      // Pigs that hit the ground (or a block) after a long fall.
      for (var r = 0; r < rows; r++) {
        if (grid[c][r] == Cell.pig &&
            fall[c][r] >= 2 &&
            (r == 0 || grid[c][r - 1] != Cell.empty)) {
          grid[c][r] = Cell.empty;
          fall[c][r] = 0;
          _pop(c, r, cellRect(c, r), true);
          moved = true;
        }
      }
    }
    return moved;
  }

  void _shotOver() {
    birds--;
    if (pigsLeft == 0) {
      score[turn] += 50 * birds;
      message = birds > 0
          ? '🎉 FORT CLEARED! +${50 * birds} bonus'
          : '🎉 FORT CLEARED!';
      GameAudio.sfx('win');
    } else if (birds == 0) {
      message = 'Out of birds!';
    } else {
      message = null;
      return;
    }
    messageAt = now;
    nextAt = now + 1500;
  }

  void _nextTurn() {
    birds = birdsEach;
    turn = (turn + 1) % players;
    if (turn == 0) round++;
    if (round > rounds) {
      round = rounds;
      done = true;
      return;
    }
    grid = buildFort(round);
  }
}

/// Aims for a pig: first one it can hit directly, else the block holding one up.
(double, double) slingBotShot(SlingLogic g, Random rng) {
  var best = (0.6, 0.8);
  var bestScore = -1.0;
  for (var a = 0; a <= 40; a++) {
    final angle = -0.3 + a * 0.035;
    for (var p = 0; p <= 12; p++) {
      final power = 0.45 + p * 0.045;
      final hit = g.firstHit(angle, power);
      if (hit == null) continue;
      final (c, r) = hit;
      final k = g.grid[c][r];
      final pigAbove = g.grid[c].skip(r + 1).contains(Cell.pig);
      // Prefer shots that still hit the same thing if the hand wobbles a little.
      final steady = [
        g.firstHit(angle - 0.03, power),
        g.firstHit(angle + 0.03, power)
      ].where((x) => x == hit).length;
      final s = (k == Cell.pig ? 3.0 : (pigAbove ? 2.0 : 1.0)) +
          (k == Cell.wood ? 0.3 : 0) +
          steady * 0.6 +
          rng.nextDouble() * 0.2;
      if (s > bestScore) (bestScore, best) = (s, (angle, power));
    }
  }
  return (
    best.$1 + (rng.nextDouble() - 0.5) * 0.05,
    best.$2 * (0.96 + rng.nextDouble() * 0.08)
  );
}

final slingInfo = LocalGameInfo(
  id: 'slingshot',
  title: 'Slingshot',
  emoji: '🐦',
  color: const Color(0xFFE53935),
  tagline: 'Fling birds, flatten the pigs\' fort!',
  rules: const [
    'Pull back anywhere and let go to fling a bird. The dots show where it\'s heading.',
    'Wood breaks, stone takes two hits, and falling blocks squash pigs. Pig 100, block 10.',
    '3 birds a fort; a bird left over is a 50 bonus. 3 forts, taking turns. 1 to 4 players.',
  ],
  scoreUnit: 'points',
  splitScreen: false,
  minPlayers: 1,
  maxPlayers: 4,
  bot: botFor<SlingLogic>((g, b, now) {
    if (!g.ready || g.turn != b.seat) return;
    if (!b.thinkFirst((g.round, g.turn, g.birds), now, 1000, 1600)) return;
    final (angle, power) = slingBotShot(g, b.rng);
    g.fling(b.seat, angle, power);
  }),
  online: RelaySpec<SlingLogic>(
    create: (n) => SlingLogic(players: n),
    save: (g) => {
      'score': g.score,
      'turn': g.turn,
      'round': g.round,
      'birds': g.birds,
      'grid': [for (final c in g.grid) ...c],
      'bird': g.bird,
      'settling': g.settling,
      'next': g.nextAt,
      'now': g.now,
      'puffs': [
        for (final p in g.puffs) ...[p.$1, p.$2, p.$3, p.$4]
      ],
      'msg': g.message,
      'msgAt': g.messageAt,
      'done': g.done,
    },
    load: (g, s, me) {
      g.score.setAll(0, ints(s['score']));
      g.turn = asInt(s['turn']);
      g.round = asInt(s['round']);
      g.birds = asInt(s['birds']);
      final cells = ints(s['grid']);
      for (var c = 0; c < SlingLogic.cols; c++) {
        for (var r = 0; r < SlingLogic.rows; r++) {
          g.grid[c][r] = cells[c * SlingLogic.rows + r];
        }
      }
      g.bird = s['bird'] == null ? null : doubles(s['bird']);
      g.settling = s['settling'] == true;
      g.nextAt = nInt(s['next']);
      g.now = asInt(s['now']);
      final p = doubles(s['puffs']);
      g.puffs
        ..clear()
        ..addAll([
          for (var i = 0; i + 3 < p.length; i += 4)
            (p[i], p[i + 1], p[i + 2].round(), p[i + 3].round())
        ]);
      g.message = s['msg'] as String?;
      g.messageAt = asInt(s['msgAt']);
      g.done = s['done'] == true;
    },
    apply: (g, from, name, a) {
      if (name == 'fling' && asInt(a[0]) == from)
        g.fling(from, asDouble(a[1]), asDouble(a[2]));
    },
    view: (context, g, players, me) =>
        _SlingView(g: g, players: players, me: me),
  ),
  play: (players, onFinished) => TickingPlay<SlingLogic>(
    create: () => SlingLogic(players: players.length),
    onFinished: onFinished,
    builder: (context, g) => _SlingView(g: g, players: players, bots: {
      for (var i = 0; i < players.length; i++)
        if (BotScope.isBot(context, i)) i
    }),
  ),
);

class _SlingView extends StatefulWidget {
  final SlingLogic g;
  final List<GpPlayer> players;
  final int? me;
  final Set<int> bots;
  const _SlingView(
      {required this.g, required this.players, this.me, this.bots = const {}});
  @override
  State<_SlingView> createState() => _SlingViewState();
}

class _SlingViewState extends State<_SlingView> {
  Offset? _from, _to;

  bool get _mine =>
      !widget.bots.contains(widget.g.turn) &&
      (widget.me == null || widget.me == widget.g.turn) &&
      widget.g.ready;

  /// Pulling back (like a real slingshot) aims the other way.
  (double, double)? _aim(double w) {
    final f = _from, t = _to;
    if (f == null || t == null) return null;
    final d = f - t;
    if (d.distance < 8) return null;
    return (atan2(-d.dy, d.dx), (d.distance / (w * 0.3)).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final current = widget.players[g.turn];
    final showMsg = g.message != null && g.now - g.messageAt < 1500;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      child: Column(children: [
        GameHud(
            players: widget.players,
            scores: g.score,
            turn: g.finished ? null : g.turn),
        const SizedBox(height: 4),
        Text('Fort ${g.round} of ${SlingLogic.rounds}',
            style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w800,
                fontSize: 13)),
        const SizedBox(height: 4),
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            final w = min(c.maxWidth, c.maxHeight / SlingLogic.h);
            final aim = _mine ? _aim(w) : null;
            return Center(
              child: SizedBox(
                width: w,
                height: min(c.maxHeight,
                    w * 1.15), // extra sky above the scene on tall screens
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: _mine
                      ? (d) => setState(() => _from = _to = d.localPosition)
                      : null,
                  onPanUpdate: _mine
                      ? (d) => setState(() => _to = d.localPosition)
                      : null,
                  onPanEnd: _mine
                      ? (_) {
                          final a = _aim(w);
                          setState(() => _from = _to = null);
                          if (a != null && a.$2 > 0.1)
                            g.fling(g.turn, a.$1, a.$2);
                        }
                      : null,
                  child: SceneFrame(
                      child: CustomPaint(
                          painter: _SlingPainter(g, w, aim, current.color))),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        GameStatus(
          player: current,
          turnText: g.finished
              ? 'All forts done!'
              : (_mine
                  ? '${current.whose} TURN · ${g.birds} left'
                  : '${current.name} aiming · ${g.pigsLeft} pigs'),
          message: showMsg ? g.message : null,
        ),
      ]),
    );
  }
}

class _SlingPainter extends CustomPainter {
  final SlingLogic g;
  final double s;
  final (double, double)? aim;
  final Color birdColor; // the shooter's colour
  _SlingPainter(this.g, this.s, this.aim, this.birdColor);

  @override
  void paint(Canvas canvas, Size size) {
    Offset o(double x, double y) => Offset(x * s, y * s);
    // Sky, clouds, far hills, grass.
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0288D1),
                Color(0xFF4FC3F7),
                Color(0xFFB3E5FC)
              ]).createShader(Offset.zero & size));
    drawSkyExtras(canvas, size, s, size.height - SlingLogic.h * s, g.now);
    canvas.translate(
        0, size.height - SlingLogic.h * s); // the scene sits at the bottom
    for (final (cx, cy) in const [(0.2, 0.1), (0.62, 0.07), (0.88, 0.15)]) {
      final drift = (g.now / 60000) % 1.2;
      final p = o((cx + drift) % 1.2 - 0.1, cy);
      for (final (dx, dy, r) in const [
        (0.0, 0.0, 0.035),
        (0.035, -0.012, 0.03),
        (-0.035, 0.005, 0.025)
      ]) {
        canvas.drawCircle(p + Offset(dx * s, dy * s), r * s,
            Paint()..color = Colors.white.withValues(alpha: 0.9));
      }
    }
    final hills = Path()..moveTo(0, SlingLogic.ground * s);
    for (var x = 0.0; x <= 1.0; x += 0.02) {
      hills.lineTo(x * s, (SlingLogic.ground - 0.08 - sin(x * 7) * 0.04) * s);
    }
    hills
      ..lineTo(s, SlingLogic.ground * s)
      ..close();
    canvas.drawPath(hills, Paint()..color = const Color(0xFF81C784));
    canvas.drawRect(
        Rect.fromLTRB(0, SlingLogic.ground * s, size.width, size.height),
        Paint()..color = const Color(0xFF6D4C41));
    canvas.drawRect(
        Rect.fromLTRB(0, SlingLogic.ground * s, size.width,
            (SlingLogic.ground + 0.015) * s),
        Paint()..color = const Color(0xFF43A047));
    // Fort.
    for (var c = 0; c < SlingLogic.cols; c++) {
      for (var r = 0; r < SlingLogic.rows; r++) {
        final k = g.grid[c][r];
        if (k == Cell.empty) continue;
        final rc = g.cellRect(c, r);
        final rect =
            Rect.fromLTRB(rc.left * s, rc.top * s, rc.right * s, rc.bottom * s)
                .deflate(0.5);
        if (k == Cell.pig) {
          _pig(canvas, rect.center, rect.width * 0.46);
          continue;
        }
        final wood = k == Cell.wood;
        canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(2)),
            Paint()
              ..color =
                  wood ? const Color(0xFFD7A15A) : const Color(0xFF9E9E9E));
        final line = Paint()
          ..color = wood ? const Color(0xFFA0702F) : const Color(0xFF616161)
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke;
        canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(2)), line);
        if (wood) {
          canvas.drawLine(rect.centerLeft + Offset(3, -3),
              rect.centerRight + Offset(-3, -3), line);
          canvas.drawLine(rect.centerLeft + Offset(5, 4),
              rect.centerRight + Offset(-6, 4), line);
        } else if (k == Cell.cracked) {
          canvas.drawPath(
              Path()
                ..moveTo(rect.left + 3, rect.top + 4)
                ..lineTo(rect.center.dx, rect.center.dy)
                ..lineTo(rect.right - 4, rect.top + 6)
                ..moveTo(rect.center.dx, rect.center.dy)
                ..lineTo(rect.center.dx - 2, rect.bottom - 3),
              line..strokeWidth = 1.6);
        }
      }
    }
    // Puffs where things broke.
    for (final (x, y, at, pig) in g.puffs) {
      final u = ((g.now - at) / 600).clamp(0.0, 1.0);
      final colour =
          pig == 1 ? const Color(0xFFC5E1A5) : const Color(0xFFD7CCC8);
      for (var i = 0; i < 6; i++) {
        final a = i * pi / 3;
        canvas.drawCircle(
            o(x, y) + Offset(cos(a), sin(a)) * (u * s * 0.05),
            s * 0.012 * (1 - u * 0.6),
            Paint()..color = colour.withValues(alpha: 1 - u));
      }
    }
    // Slingshot, band, bird in the pouch, birds waiting.
    final base = o(SlingLogic.launchX, SlingLogic.ground),
        fork = o(SlingLogic.launchX, SlingLogic.launchY + 0.03);
    final woodPaint = Paint()
      ..color = const Color(0xFF5D4037)
      ..strokeWidth = s * 0.016
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(base, fork, woodPaint);
    final l = fork + Offset(-s * 0.025, -s * 0.045),
        r = fork + Offset(s * 0.025, -s * 0.045);
    canvas.drawLine(fork, l, woodPaint);
    canvas.drawLine(fork, r, woodPaint);
    final launch = o(SlingLogic.launchX, SlingLogic.launchY);
    var pouch = launch;
    if (aim != null) {
      final (a, p) = aim!;
      pouch = launch - Offset(cos(a), -sin(a)) * (p * s * 0.07);
      // Dotted path ahead.
      final v = p.clamp(0.1, 1.0) * SlingLogic.maxSpeed;
      var (x, y, vx, vy) =
          (SlingLogic.launchX, SlingLogic.launchY, cos(a) * v, -sin(a) * v);
      for (var i = 1; i <= 14; i++) {
        for (var k = 0; k < 4; k++) {
          x += vx / 60;
          vy += SlingLogic.gravity / 60;
          y += vy / 60;
        }
        if (y > SlingLogic.ground) break;
        canvas.drawCircle(o(x, y), 3,
            Paint()..color = Colors.white.withValues(alpha: 1 - i / 16));
      }
    }
    final band = Paint()
      ..color = const Color(0xFF3E2723)
      ..strokeWidth = 3;
    final waiting = g.ready && g.birds > 0;
    if (waiting) {
      canvas.drawLine(l, pouch, band);
      canvas.drawLine(r, pouch, band);
      _bird(canvas, pouch, SlingLogic.birdR * s * 1.3);
    } else {
      canvas.drawLine(l, r, band);
    }
    for (var i = 0; i < g.birds - (waiting ? 1 : 0); i++) {
      _bird(canvas, o(0.035 + i * 0.035, SlingLogic.ground - 0.017),
          SlingLogic.birdR * s);
    }
    final b = g.bird;
    if (b != null) {
      canvas.save();
      canvas.translate(b[0] * s, b[1] * s);
      canvas.rotate(atan2(b[3], b[2]) * 0.5);
      _bird(canvas, Offset.zero, SlingLogic.birdR * s * 1.3);
      canvas.restore();
    }
  }

  void _bird(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader =
              RadialGradient(center: const Alignment(-0.35, -0.4), colors: [
            Color.lerp(birdColor, Colors.white, 0.35)!,
            birdColor,
            Color.lerp(birdColor, Colors.black, 0.3)!
          ]).createShader(Rect.fromCircle(center: c, radius: r)));
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1.0, r * 0.08)
          ..color = Color.lerp(birdColor, Colors.black, 0.5)!);
    canvas.drawOval(
        Rect.fromCenter(
            center: c + Offset(0, r * 0.45), width: r * 1.2, height: r * 0.8),
        Paint()..color = const Color(0xFFFFE0B2));
    for (final dx in [-0.3, 0.3]) {
      canvas.drawCircle(c + Offset(r * dx, -r * 0.2), r * 0.26,
          Paint()..color = Colors.white);
      canvas.drawCircle(c + Offset(r * dx + r * 0.08, -r * 0.18), r * 0.12,
          Paint()..color = Colors.black);
    }
    final brow = Paint()
      ..color = Colors.black
      ..strokeWidth = r * 0.18
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        c + Offset(-r * 0.6, -r * 0.65), c + Offset(-r * 0.05, -r * 0.4), brow);
    canvas.drawLine(
        c + Offset(r * 0.6, -r * 0.65), c + Offset(r * 0.05, -r * 0.4), brow);
    canvas.drawPath(
        Path()
          ..moveTo(c.dx + r * 0.2, c.dy)
          ..lineTo(c.dx + r * 0.85, c.dy + r * 0.15)
          ..lineTo(c.dx + r * 0.2, c.dy + r * 0.35)
          ..close(),
        Paint()..color = const Color(0xFFFFA000));
  }

  void _pig(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF7CB342));
    canvas.drawCircle(c + Offset(-r * 0.6, -r * 0.75), r * 0.25,
        Paint()..color = const Color(0xFF7CB342));
    canvas.drawCircle(c + Offset(r * 0.6, -r * 0.75), r * 0.25,
        Paint()..color = const Color(0xFF7CB342));
    canvas.drawOval(
        Rect.fromCenter(
            center: c + Offset(0, r * 0.15), width: r * 0.8, height: r * 0.55),
        Paint()..color = const Color(0xFFAED581));
    for (final dx in [-0.15, 0.15]) {
      canvas.drawCircle(c + Offset(r * dx, r * 0.15), r * 0.09,
          Paint()..color = const Color(0xFF33691E));
    }
    for (final dx in [-0.45, 0.45]) {
      canvas.drawCircle(c + Offset(r * dx, -r * 0.3), r * 0.18,
          Paint()..color = Colors.white);
      canvas.drawCircle(c + Offset(r * dx, -r * 0.28), r * 0.08,
          Paint()..color = Colors.black);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
