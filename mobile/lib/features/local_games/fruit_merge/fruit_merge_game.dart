import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/ui/components.dart';
import '../../guess_person/models/gp_player.dart';
import '../shell/local_game_info.dart';
import '../shell/split_screen.dart';
import '../shell/ticking_play.dart';
import '../shell/turns_play.dart';
import '../solo/solo_common.dart';
import 'fruit_merge_logic.dart';

export 'fruit_merge_logic.dart';

const _rules = [
  'Drag to aim, let go to drop the fruit.',
  'Two of the same fruit touching merge into a bigger one: cherry, strawberry, grapes, orange, lemon, apple, pear, peach, pineapple, melon, watermelon.',
  'Bigger fruits score more. Keep the pile below the red line!',
];

const _fruitColors = [
  Color(0xFFE53950),
  Color(0xFFFF5A6E),
  Color(0xFF9B59D0),
  Color(0xFFFF9F2E),
  Color(0xFFFFE04A),
  Color(0xFFE8473C),
  Color(0xFFB5D96A),
  Color(0xFFFFB38A),
  Color(0xFFFFCB3B),
  Color(0xFF9BE08A),
  Color(0xFF3FBF5A),
];

final fruitMergeInfo = LocalGameInfo(
  id: 'fruit_merge',
  title: 'Fruit Merge',
  emoji: '🍉',
  color: const Color(0xFF3FBF5A),
  tagline: 'Merge small fruits into a watermelon!',
  rules: [
    ..._rules,
    'If fruit stays above the line for a few seconds, the box is full and the game ends.'
  ],
  scoreUnit: 'points',
  splitScreen: false,
  minPlayers: 1,
  maxPlayers: 1,
  play: (players, onFinished) => TickingPlay<FruitMergeSolo>(
    create: () => FruitMergeSolo(),
    onFinished: onFinished,
    builder: (context, g) => SoloFrame(
      title: 'Fruit Merge',
      score: g.score,
      extra: 'Biggest: ${_fruitNames[g.box.biggest]}',
      child: FruitBoxView(
          box: g.box, onAim: g.aim, onDrop: g.drop, showNext: true),
    ),
  ),
);

final LocalGameInfo fruitBattleInfo = LocalGameInfo(
  id: 'fruit_merge_battle',
  title: 'Fruit Merge Battle',
  emoji: '🍓',
  color: const Color(0xFFE84393),
  tagline: 'Everyone merges at once. Biggest score wins!',
  rules: [
    ..._rules,
    'Take turns (the whole box for 1-5 minutes each) or split the screen and play at once (2 minutes). Overflow and your score is frozen. Highest score wins! 2 to 4 players.',
  ],
  scoreUnit: 'points',
  splitScreen: true,
  maxPlayers: 4,
  bot: botFor<FruitMergeBattle>((g, b, now) {
    final box = g.boxes[b.seat];
    if (g.finished || box.over || !box.canDrop) return;
    if (!b.thinkFirst(box.lastDropMs, now, 700, 1600)) return;
    g.drop(b.seat, botAim(box, b.rng));
  }),
  online: RelaySpec<FruitMergeBattle>(
    create: (n) => FruitMergeBattle(players: n),
    save: (g) => {
      't': g.elapsedMs,
      'b': [for (final b in g.boxes) b.save()]
    },
    load: (g, s, me) {
      g.elapsedMs = asInt(s['t']);
      final boxes = s['b'] as List;
      for (var i = 0; i < g.boxes.length && i < boxes.length; i++) {
        g.boxes[i]
            .load(Map<String, dynamic>.from(boxes[i] as Map), g.elapsedMs);
      }
    },
    apply: (g, from, name, a) {
      if (name == 'drop' && asInt(a[0]) == from) g.drop(from, asDouble(a[1]));
    },
    view: (context, g, players, me) =>
        _BattleOnline(g: g, players: players, me: me),
  ),
  // One phone: each player gets the whole box for the chosen time.
  turns: TurnsSpec(
    play: (player, ms, onDone) => TickingPlay<FruitMergeBattle>(
      create: () => FruitMergeBattle(players: 1, durationMs: ms),
      onFinished: (s) => onDone(s.first),
      builder: (context, g) => Column(children: [
        TurnBar(
            player: player,
            score: g.boxes.first.score,
            secondsLeft: g.secondsLeft),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
            child: FruitBoxView(
                box: g.boxes.first,
                showNext: true,
                enabled: !g.finished,
                onAim: (x) => g.aim(0, x),
                onDrop: (x) => g.drop(0, x)),
          ),
        ),
      ]),
    ),
    simulate: (ms, rng) => simulateTurn(
        FruitMergeBattle(players: 1, durationMs: ms, random: rng),
        fruitBattleInfo.bot!,
        ms,
        rng),
  ),
  play: (players, onFinished) => TickingPlay<FruitMergeBattle>(
    create: () => FruitMergeBattle(players: players.length),
    onFinished: onFinished,
    builder: (context, g) => PlayerZones(
      count: players.length,
      middle: ScoreMiddleBar(
          players: players, scores: g.scores, label: '${g.secondsLeft}s'),
      center: ZoneCenterChip('${g.secondsLeft}s'),
      zone: (i) => _BattleZone(g: g, player: players[i], index: i),
    ),
  ),
);

/// Where the computer drops: on top of a matching fruit if one is reachable, else somewhere sensible.
double botAim(FruitBox box, Random rng) {
  Fruit? best;
  for (final f in box.fruits) {
    if (f.level != box.next) continue;
    // Is anything resting on top of it? Then it's buried.
    final covered = box.fruits
        .any((o) => o != f && o.y < f.y && (o.x - f.x).abs() < o.r + f.r * 0.6);
    if (covered) continue;
    if (best == null || f.y < best.y) best = f;
  }
  final jitter = (rng.nextDouble() - 0.5) * 0.06;
  if (best != null) return (best.x + jitter).clamp(0.0, 1.0);
  // Small fruits to the left, big ones to the right, so like sizes meet.
  return (box.next <= 1
          ? 0.15 + rng.nextDouble() * 0.25
          : 0.55 + rng.nextDouble() * 0.35)
      .clamp(0.0, 1.0);
}

/// One box: drag to aim, release to drop. [onAim]/[onDrop] get 0..1 across the box.
class FruitBoxView extends StatelessWidget {
  final FruitBox box;
  final void Function(double x) onAim;
  final void Function(double x) onDrop;
  final bool showNext;
  final bool enabled;
  const FruitBoxView(
      {super.key,
      required this.box,
      required this.onAim,
      required this.onDrop,
      this.showNext = false,
      this.enabled = true});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      // Keep the box's shape (1 wide, 1.5 tall) and centre it.
      final w = min(c.maxWidth, c.maxHeight / FruitBox.height);
      final h = w * FruitBox.height;
      double toX(Offset p) => (p.dx / w).clamp(0.0, 1.0);
      return Center(
        child: SizedBox(
          width: w,
          height: h,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanDown: enabled ? (d) => onAim(toX(d.localPosition)) : null,
            onPanUpdate: enabled ? (d) => onAim(toX(d.localPosition)) : null,
            onPanEnd: enabled
                ? (_) {
                    HapticFeedback.selectionClick().ignore();
                    onDrop(box.aimX);
                  }
                : null,
            onTapUp: enabled
                ? (d) {
                    HapticFeedback.selectionClick().ignore();
                    onDrop(toX(d.localPosition));
                  }
                : null,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(w * 0.05),
              child: CustomPaint(
                  size: Size(w, h), painter: _BoxPainter(box, showNext)),
            ),
          ),
        ),
      );
    });
  }
}

class _BattleZone extends StatelessWidget {
  final FruitMergeBattle g;
  final GpPlayer player;
  final int index;
  const _BattleZone(
      {required this.g, required this.player, required this.index});

  @override
  Widget build(BuildContext context) {
    final box = g.boxes[index];
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Column(children: [
        Row(children: [
          PlayerBadge(
              index: PlayerPalette.indexOf(player.color) ?? index,
              size: 22,
              color: player.color,
              initial: player.name),
          const SizedBox(width: 6),
          Expanded(
              child: Text(player.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontFamily: Fonts.body,
                      color: nameColor(player.color),
                      fontWeight: FontWeight.w900,
                      fontSize: 14))),
          if (box.over)
            const Text('Box full!  ',
                style: TextStyle(
                    fontFamily: Fonts.display,
                    color: Color(0xFFFF6B6B),
                    fontSize: 15)),
          Text('${box.score}',
              style: const TextStyle(
                  fontFamily: Fonts.display,
                  color: Colors.white,
                  fontSize: 22,
                  fontFeatures: [FontFeature.tabularFigures()])),
        ]),
        const SizedBox(height: 4),
        Expanded(
          child: FruitBoxView(
            box: box,
            enabled: !g.finished && !box.over,
            showNext: true,
            onAim: (x) => g.aim(index, x),
            onDrop: (x) => g.drop(index, x),
          ),
        ),
      ]),
    );
  }
}

/// Online: your own box big, everyone's score above it.
class _BattleOnline extends StatelessWidget {
  final FruitMergeBattle g;
  final List<GpPlayer> players;
  final int me;
  const _BattleOnline(
      {required this.g, required this.players, required this.me});

  @override
  Widget build(BuildContext context) => Column(children: [
        ScoreMiddleBar(
            players: players, scores: g.scores, label: '${g.secondsLeft}s'),
        Expanded(child: _BattleZone(g: g, player: players[me], index: me)),
      ]);
}

/// The merge chain drawn as fruit (the logic keeps its emoji list for the online screens).
const _fruitIcons = [
  GameIcons.cherry,
  GameIcons.strawberry,
  GameIcons.grapes,
  GameIcons.orange,
  GameIcons.lemon,
  GameIcons.apple,
  GameIcons.pear,
  GameIcons.peach,
  GameIcons.pineapple,
  GameIcons.melon,
  GameIcons.watermelon,
];
const _fruitNames = [
  'cherry',
  'strawberry',
  'grapes',
  'orange',
  'lemon',
  'apple',
  'pear',
  'peach',
  'pineapple',
  'melon',
  'watermelon'
];

class _BoxPainter extends CustomPainter {
  final FruitBox box;
  final bool showNext;
  _BoxPainter(this.box, this.showNext);

  void _fruit(Canvas canvas, Offset c, double r, int level,
      {double alpha = 1}) {
    final col = _fruitColors[level];
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.4),
          colors: [
            Color.lerp(col, Colors.white, 0.45)!.withValues(alpha: alpha),
            col.withValues(alpha: alpha),
            Color.lerp(col, Colors.black, 0.25)!.withValues(alpha: alpha)
          ],
          stops: const [0, 0.6, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1.0, r * 0.06)
          ..color = Color.lerp(col, Colors.black, 0.4)!
              .withValues(alpha: 0.6 * alpha));
    if (alpha >= 1)
      paintIcon(canvas, _fruitIcons[level],
          Rect.fromCenter(center: c, width: r * 1.45, height: r * 1.45));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width; // board units -> pixels
    // Box: warm wood with a lighter inside.
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFFF6E7C8));
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFF5E1), Color(0xFFF1D9A8)])
            .createShader(Offset.zero & size),
    );
    // Glass jar reflections down the left and right.
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(size.width * 0.04, size.height * 0.1,
                size.width * 0.035, size.height * 0.75),
            const Radius.circular(8)),
        Paint()..color = const Color(0x55FFFFFF));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(size.width * 0.93, size.height * 0.2,
                size.width * 0.015, size.height * 0.5),
            const Radius.circular(8)),
        Paint()..color = const Color(0x40FFFFFF));
    // Danger line (flashes red when fruit is over it).
    final dy = FruitBox.dangerY * s;
    final flash = box.inDanger && (box.nowMs ~/ 250).isEven;
    final line = Paint()
      ..color = flash ? const Color(0xFFFF2D2D) : const Color(0x88E05050)
      ..strokeWidth = flash ? 3 : 2;
    for (var x = 0.0; x < size.width; x += 14) {
      canvas.drawLine(Offset(x, dy), Offset(min(x + 8, size.width), dy), line);
    }
    // Aim guide and the held fruit.
    if (!box.over) {
      final r = fruitRadius[box.next] * s;
      final x =
          box.aimX.clamp(fruitRadius[box.next], 1 - fruitRadius[box.next]) * s;
      final guide = Paint()
        ..color = const Color(0x55000000)
        ..strokeWidth = 1.5;
      for (var y = FruitBox.spawnY * s + r; y < size.height; y += 12) {
        canvas.drawLine(Offset(x, y), Offset(x, y + 6), guide);
      }
      _fruit(canvas, Offset(x, FruitBox.spawnY * s), r, box.next,
          alpha: box.canDrop ? 1 : 0.45);
    }
    for (final f in box.fruits) {
      _fruit(canvas, Offset(f.x * s, f.y * s), f.r * s, f.level);
    }
    // Merge pops: a ring that grows and fades.
    for (final p in box.pops) {
      final t = ((box.nowMs - p.$4) / 600).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(p.$1 * s, p.$2 * s),
        fruitRadius[p.$3] * s * (1 + t * 0.8),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4 * (1 - t)
          ..color = Colors.white.withValues(alpha: 1 - t),
      );
    }
    // Next fruit, top right.
    if (showNext) {
      final r = s * 0.035;
      final c = Offset(size.width - r * 2.2, r * 2.2);
      canvas.drawCircle(c, r * 1.7, Paint()..color = const Color(0x22000000));
      _fruit(canvas, c, r, box.after);
      final tp = TextPainter(
        text: const TextSpan(
            text: 'NEXT',
            style: TextStyle(
                fontFamily: Fonts.body,
                color: Color(0xAA5A4630),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c + Offset(-tp.width / 2, r * 1.8));
    }
    if (box.over) {
      canvas.drawRect(
          Offset.zero & size, Paint()..color = const Color(0x66000000));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
