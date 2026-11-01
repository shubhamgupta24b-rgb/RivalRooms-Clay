import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/audio/game_audio.dart';
import '../../../core/ui/components.dart';
import '../../guess_person/models/gp_player.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/game_hud.dart';
import '../shell/ticking_play.dart';

/// A bottle in the pyramid: row 0 is the bottom (3), row 1 (2), row 2 the top (1).
class Bottle {
  final int row, col;
  bool down = false;
  int fellAt = 0;
  Bottle(this.row, this.col);
}

/// Bottle Smash: a fairground pyramid of 6 bottles. Swipe up to throw: where you swipe aims
/// left/right, how far sets the height. A bottle knocked out takes the ones resting on it
/// down too, and can knock its neighbour. 3 balls a round, taking turns; from round 3 the
/// shelf slides. Clear all 6 for +3. Most bottles wins.
class BottleLogic extends LocalGameLogic {
  static const ballsPerRound = 3, rounds = 4, bottleW = 0.11, bottleH = 0.16;
  final int players;
  final Random rng;
  final List<int> score;
  int turn = 0, round = 1, balls = ballsPerRound;
  late List<Bottle> bottles;
  (
    double x,
    double y,
    int at
  )? ball; // where the ball is going, and when it was thrown
  int now = 0;
  String? message;
  int messageAt = -10000;
  bool done = false;

  BottleLogic({this.players = 2, Random? random})
      : rng = random ?? Random(),
        score = List.filled(players, 0) {
    _rack();
  }

  void _rack() => bottles = [
        for (var r = 0; r < 3; r++)
          for (var c = 0; c < 3 - r; c++) Bottle(r, c)
      ];

  @override
  bool get finished => done;
  @override
  List<int> get scores => score;

  /// How far the shelf has slid (rounds 3 and 4).
  double get shelfShift => round >= 3 ? sin(now / 700) * 0.18 : 0;

  /// Centre of a bottle, in a 1-wide scene where the shelf top is at y = 0.62.
  Offset bottleAt(Bottle b) => Offset(
      0.5 + shelfShift + (b.col - (2 - b.row) / 2) * (bottleW + 0.012),
      0.62 - bottleH / 2 - b.row * bottleH);

  /// Throws at [x] across (0..1) and [height] (0 = shelf level, 1 = well above the top).
  void throwBall(int player, double x, double height) {
    if (forward('throw', [player, x, height])) return;
    if (done || ball != null || player != turn || balls <= 0) return;
    ball = (x.clamp(0.05, 0.95), 0.62 - height.clamp(0.0, 1.0) * 0.6, now);
    balls--;
    HapticFeedback.lightImpact().ignore();
    GameAudio.sfx('throw');
    notifyListeners();
  }

  @override
  void update(int ms) {
    now = ms;
    final b = ball;
    if (b == null) {
      notifyListeners();
      return;
    }
    if (ms - b.$3 < 450) {
      notifyListeners();
      return; // still flying
    }
    ball = null;
    // What did it hit? The bottle whose shape contains the point (with a little slack).
    final up = bottles.where((x) => !x.down).toList();
    Bottle? hit;
    for (final x in up) {
      final c = bottleAt(x);
      if ((b.$1 - c.dx).abs() < bottleW * 0.62 &&
          (b.$2 - c.dy).abs() < bottleH * 0.55) hit = x;
    }
    var knocked = 0;
    if (hit != null) {
      knocked += _knock(hit);
      // Its neighbour on the same row may go too.
      for (final n in up.where((x) =>
          !x.down && x.row == hit!.row && (x.col - hit.col).abs() == 1)) {
        if (rng.nextDouble() < 0.35) knocked += _knock(n);
      }
      HapticFeedback.mediumImpact().ignore();
      GameAudio.sfx('hit');
    }
    score[turn] += knocked;
    final cleared = bottles.every((x) => x.down);
    if (cleared) {
      score[turn] += 3;
      GameAudio.sfx('coin');
    }
    message = cleared
        ? '🎉 ALL DOWN! +${knocked + 3}'
        : (knocked == 0 ? 'Missed!' : '🍾 +$knocked');
    messageAt = ms;
    if (cleared || balls == 0) _nextTurn();
    notifyListeners();
  }

  /// Knocks [b] down, and everything resting on it.
  int _knock(Bottle b) {
    if (b.down) return 0;
    b
      ..down = true
      ..fellAt = now;
    var n = 1;
    for (final above in bottles.where((x) =>
        !x.down &&
        x.row == b.row + 1 &&
        (x.col == b.col || x.col == b.col - 1))) {
      n += _knock(above);
    }
    return n;
  }

  void _nextTurn() {
    balls = ballsPerRound;
    turn = (turn + 1) % players;
    if (turn == 0) round++;
    if (round > rounds) {
      done = true;
      return;
    }
    _rack();
  }
}

final bottleInfo = LocalGameInfo(
  id: 'bottle_smash',
  title: 'Bottle Smash',
  emoji: '🍾',
  color: const Color(0xFF00897B),
  tagline: 'Knock the bottle pyramid down!',
  rules: const [
    'Swipe up to throw the ball. Where you swipe aims it; a longer swipe throws it higher.',
    'Knock a bottle out and the ones on top come down too. 3 balls a round; clear all 6 for +3.',
    'From round 3 the shelf slides! 4 rounds each, taking turns. 1 to 4 players.',
  ],
  scoreUnit: 'bottles',
  splitScreen: false,
  minPlayers: 1,
  maxPlayers: 4,
  bot: botFor<BottleLogic>((g, b, now) {
    if (g.finished || g.ball != null || g.turn != b.seat) return;
    if (!b.thinkFirst((g.round, g.balls, g.turn), now, 900, 1500)) return;
    // Aim at a bottom bottle that's still up (it takes the most down), with a shaky hand.
    final up = g.bottles.where((x) => !x.down).toList()
      ..sort((a, c) => a.row - c.row);
    final target = up.isEmpty ? g.bottles.first : up.first;
    final c = g.bottleAt(target);
    final height = (0.62 - c.dy) / 0.6;
    g.throwBall(b.seat, c.dx + (b.rng.nextDouble() - 0.5) * 0.12,
        height + (b.rng.nextDouble() - 0.5) * 0.12);
  }),
  online: RelaySpec<BottleLogic>(
    create: (n) => BottleLogic(players: n),
    save: (g) => {
      'score': g.score,
      'turn': g.turn,
      'round': g.round,
      'balls': g.balls,
      'down': [for (final b in g.bottles) b.down ? 1 : 0],
      'ball': g.ball == null ? null : [g.ball!.$1, g.ball!.$2, g.ball!.$3],
      'now': g.now,
      'msg': g.message,
      'msgAt': g.messageAt,
      'done': g.done,
    },
    load: (g, s, me) {
      g.score.setAll(0, ints(s['score']));
      g.turn = asInt(s['turn']);
      g.round = asInt(s['round']);
      g.balls = asInt(s['balls']);
      final down = ints(s['down']);
      for (var i = 0; i < g.bottles.length; i++) {
        if (down[i] == 1 && !g.bottles[i].down)
          g.bottles[i].fellAt = asInt(s['now']);
        g.bottles[i].down = down[i] == 1;
      }
      final b = s['ball'] as List?;
      g.ball = b == null ? null : (asDouble(b[0]), asDouble(b[1]), asInt(b[2]));
      g.now = asInt(s['now']);
      g.message = s['msg'] as String?;
      g.messageAt = asInt(s['msgAt']);
      g.done = s['done'] == true;
    },
    apply: (g, from, name, a) {
      if (name == 'throw' && asInt(a[0]) == from)
        g.throwBall(from, asDouble(a[1]), asDouble(a[2]));
    },
    view: (context, g, players, me) =>
        _BottleView(g: g, players: players, me: me),
  ),
  play: (players, onFinished) => TickingPlay<BottleLogic>(
    create: () => BottleLogic(players: players.length),
    onFinished: onFinished,
    builder: (context, g) => _BottleView(g: g, players: players, bots: {
      for (var i = 0; i < players.length; i++)
        if (BotScope.isBot(context, i)) i
    }),
  ),
);

class _BottleView extends StatefulWidget {
  final BottleLogic g;
  final List<GpPlayer> players;
  final int? me;
  final Set<int> bots;
  const _BottleView(
      {required this.g, required this.players, this.me, this.bots = const {}});
  @override
  State<_BottleView> createState() => _BottleViewState();
}

class _BottleViewState extends State<_BottleView> {
  Offset? _from, _to;

  bool get _myTurn =>
      !widget.bots.contains(widget.g.turn) &&
      (widget.me == null || widget.me == widget.g.turn) &&
      widget.g.ball == null &&
      !widget.g.finished;

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final current = widget.players[g.turn];
    final showMsg = g.message != null && g.now - g.messageAt < 1300;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      child: Column(children: [
        GameHud(
            players: widget.players,
            scores: g.score,
            turn: g.finished ? null : g.turn,
            trailing: HudLabel(
                'ROUND ${min(g.round, BottleLogic.rounds)}/${BottleLogic.rounds}')),
        const SizedBox(height: 8),
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            final w = c.maxWidth, h = c.maxHeight;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: _myTurn
                  ? (d) => setState(() => _from = _to = d.localPosition)
                  : null,
              onPanUpdate:
                  _myTurn ? (d) => setState(() => _to = d.localPosition) : null,
              onPanEnd: _myTurn
                  ? (_) {
                      final f = _from, t = _to;
                      setState(() => _from = _to = null);
                      if (f == null || t == null || f.dy - t.dy < 30)
                        return; // swipe up
                      // The ball goes where the swipe ends (the shelf is drawn [top] lower).
                      final top = max(0.0, h * 0.56 - 0.62 * w);
                      g.throwBall(g.turn, t.dx / w,
                          ((0.62 - (t.dy - top) / w) / 0.6).clamp(0.0, 1.0));
                    }
                  : null,
              child: SceneFrame(
                  child: CustomPaint(
                      size: Size(w, h), painter: _StallPainter(g, _from, _to))),
            );
          }),
        ),
        const SizedBox(height: 10),
        GameStatus(
          player: current,
          turnText: g.finished
              ? 'All rounds done!'
              : (_myTurn
                  ? '${current.whose} TURN · ${g.balls} ${g.balls == 1 ? 'ball' : 'balls'} left'
                  : '${current.name} is throwing…'),
          message: showMsg ? g.message : null,
        ),
      ]),
    );
  }
}

class _StallPainter extends CustomPainter {
  final BottleLogic g;
  final Offset? from, to;
  _StallPainter(this.g, this.from, this.to);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width; // the scene is 1 wide
    // Striped fairground tent and a wooden counter.
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFF3E2723));
    for (var i = 0; i < 8; i++) {
      canvas.drawRect(Rect.fromLTWH(i * s / 8, 0, s / 16, size.height * 0.75),
          Paint()..color = const Color(0x22FFFFFF));
    }
    final awning = Path()..moveTo(0, 0);
    for (var i = 0; i <= 8; i++) {
      awning.arcToPoint(Offset((i + 1) * s / 8, 0),
          radius: Radius.circular(s / 16), clockwise: false);
    }
    canvas.drawRect(Rect.fromLTWH(0, 0, s, size.height * 0.05),
        Paint()..color = const Color(0xFFE53935));
    for (var i = 0; i < 8; i++) {
      canvas.drawCircle(Offset((i + 0.5) * s / 8, size.height * 0.05), s / 16,
          Paint()..color = i.isEven ? const Color(0xFFE53935) : Colors.white);
    }
    // Wooden counter at the front, with the balls still to throw.
    final counterTop = size.height * 0.84;
    canvas.drawRect(Rect.fromLTRB(0, counterTop, size.width, size.height),
        Paint()..color = const Color(0xFF8D6E63));
    canvas.drawRect(Rect.fromLTRB(0, counterTop, size.width, counterTop + 6),
        Paint()..color = const Color(0xFFBCAAA4));
    final waiting = g.balls;
    for (var i = 0; i < waiting; i++) {
      final p = Offset(size.width * 0.12 + i * 26, counterTop + 18);
      canvas.drawCircle(p, 10, Paint()..color = Colors.white);
      canvas.drawArc(
          Rect.fromCircle(center: p, radius: 7),
          0.5,
          2,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = const Color(0xFFE53935));
    }
    // The shelf stands in the middle of the booth.
    final top = max(0.0, size.height * 0.56 - 0.62 * s);
    canvas.save();
    canvas.translate(0, top);
    // Shelf.
    final shelfTop = 0.62 * s;
    canvas.drawRect(
        Rect.fromLTWH((0.2 + g.shelfShift) * s, shelfTop, 0.6 * s, 0.03 * s),
        Paint()..color = const Color(0xFF8D6E63));
    canvas.drawRect(
        Rect.fromLTWH(
            (0.48 + g.shelfShift) * s, shelfTop + 0.03 * s, 0.04 * s, 0.25 * s),
        Paint()..color = const Color(0xFF6D4C41));
    // Bottles: standing ones upright, knocked ones tumbling off and fading.
    for (final b in g.bottles) {
      final c = g.bottleAt(b) * s;
      final bw = BottleLogic.bottleW * s, bh = BottleLogic.bottleH * s;
      if (b.down) {
        final u = ((g.now - b.fellAt) / 500).clamp(0.0, 1.0);
        if (u >= 1) continue;
        canvas.save();
        canvas.translate(c.dx + u * bw, c.dy + u * u * bh * 2);
        canvas.rotate(u * 2.2);
        _bottle(canvas, bw, bh, alpha: 1 - u);
        canvas.restore();
        continue;
      }
      canvas.save();
      canvas.translate(c.dx, c.dy);
      _bottle(canvas, bw, bh);
      canvas.restore();
    }
    canvas.restore();
    // The ball on its way: from the bottom of the screen, shrinking into the distance.
    final b = g.ball;
    if (b != null) {
      final u = ((g.now - b.$3) / 450).clamp(0.0, 1.0);
      final start = Offset(size.width / 2, size.height * 0.98);
      final end = Offset(b.$1 * s, b.$2 * s + top);
      final p = Offset.lerp(start, end, u)! -
          Offset(0, sin(u * pi) * size.height * 0.12);
      final r = 22 - 12 * u;
      canvas.drawCircle(
          p,
          r,
          Paint()
            ..shader = RadialGradient(
                    center: const Alignment(-0.3, -0.3),
                    colors: const [Colors.white, Color(0xFFE0E0E0)])
                .createShader(Rect.fromCircle(center: p, radius: r)));
      canvas.drawArc(
          Rect.fromCircle(center: p, radius: r * 0.8),
          0.5,
          2,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = const Color(0xFFE53935));
    }
    // Aim line while swiping.
    if (from != null && to != null && from!.dy - to!.dy > 10) {
      final dash = Paint()
        ..color = Colors.white.withValues(alpha: 0.6)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(size.width / 2, size.height * 0.98), to!, dash);
      canvas.drawCircle(
          to!,
          10,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Colors.white);
    }
  }

  /// A green glass bottle: shaded body and neck, a dark outline, a paper label, a cork and
  /// two highlights so it reads as glass.
  void _bottle(Canvas canvas, double w, double h, {double alpha = 1}) {
    final bodyRect = Rect.fromCenter(
        center: Offset(0, h * 0.12), width: w * 0.8, height: h * 0.7);
    final body = RRect.fromRectAndRadius(bodyRect, Radius.circular(w * 0.2));
    final neck = Rect.fromCenter(
        center: Offset(0, -h * 0.3), width: w * 0.3, height: h * 0.32);
    final shape = Path()
      ..addRRect(body)
      ..addRRect(RRect.fromRectAndRadius(neck, Radius.circular(w * 0.05)));
    final full =
        Rect.fromLTRB(bodyRect.left, neck.top, bodyRect.right, bodyRect.bottom);
    canvas.drawPath(
        shape,
        Paint()
          ..shader = LinearGradient(colors: [
            const Color(0xFF1B5E20).withValues(alpha: 0.9 * alpha),
            const Color(0xFF4CAF50).withValues(alpha: 0.85 * alpha),
            const Color(0xFF2E7D32).withValues(alpha: 0.9 * alpha),
          ], stops: const [
            0,
            0.4,
            1
          ]).createShader(full));
    canvas.drawPath(
        shape,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1.0, w * 0.04)
          ..color = const Color(0xFF0E3B12).withValues(alpha: alpha));
    // Cork.
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(0, -h * 0.47),
                width: w * 0.32,
                height: h * 0.07),
            Radius.circular(w * 0.04)),
        Paint()..color = const Color(0xFFC08A4E).withValues(alpha: alpha));
    // Paper label.
    final label = Rect.fromCenter(
        center: Offset(0, h * 0.15), width: w * 0.8, height: h * 0.2);
    canvas.drawRect(
        label,
        Paint()
          ..color = const Color(0xFFFFF4DC).withValues(alpha: 0.95 * alpha));
    canvas.drawRect(
        Rect.fromCenter(
            center: label.center,
            width: label.width,
            height: label.height * 0.25),
        Paint()
          ..color = const Color(0xFFE53935).withValues(alpha: 0.85 * alpha));
    // Glass highlights.
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(-w * 0.28, -h * 0.13, w * 0.09, h * 0.22),
            Radius.circular(w * 0.05)),
        Paint()..color = Colors.white.withValues(alpha: 0.45 * alpha));
    canvas.drawRect(Rect.fromLTWH(-w * 0.1, -h * 0.42, w * 0.05, h * 0.18),
        Paint()..color = Colors.white.withValues(alpha: 0.35 * alpha));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
