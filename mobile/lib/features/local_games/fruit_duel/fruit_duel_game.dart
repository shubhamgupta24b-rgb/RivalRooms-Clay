import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../guess_person/models/gp_player.dart';
import '../../../core/ui/components.dart';
import '../../../core/ui/materials/materials.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/split_screen.dart';
import '../shell/ticking_play.dart';
import '../shell/turns_play.dart';

class Slash {
  final int fruit;
  final int lane;
  final int points; // 0 = wrong lane
  const Slash(this.fruit, this.lane, this.points);
}

/// Like the online version (pick the fruit's lane, one slash per fruit, 20s) with a
/// duel twist for the shared screen: first correct slash +2, second +1. Fruits speed up.
class FruitDuelLogic extends TimedDuel {
  static const lanes = 3;
  static const fruits = ['🍉', '🍎', '🍊', '🍍', '🍇', '🍌', '🍓', '🥝'];
  final List<int> score;
  final List<int> hits;
  final List<Slash?> lastSlash;
  final List<int> _starts = [];
  final List<int> _lanes = [];
  final List<String> _emoji = [];
  int current = 0;
  bool _firstHitTaken = false;

  FruitDuelLogic({int durationMs = 20000, int players = 2, Random? random})
      : score = List.filled(players, 0),
        hits = List.filled(players, 0),
        lastSlash = List.filled(players, null),
        super(durationMs) {
    final r = random ?? Random();
    var t = 0;
    for (var i = 0; t < durationMs; i++) {
      _starts.add(t);
      // Never the same lane twice in a row, so every fruit visibly moves.
      var lane = r.nextInt(lanes);
      if (i > 0 && lane == _lanes.last)
        lane = (lane + 1 + r.nextInt(lanes - 1)) % lanes;
      _lanes.add(lane);
      _emoji.add(fruits[r.nextInt(fruits.length)]);
      t += max(550, 1000 - i * 15);
    }
  }

  @override
  List<int> get scores => score;
  int get fruitLane => _lanes[current];
  String get fruitEmoji => _emoji[current];
  int get fruitCount => _starts.length;

  /// 1 -> 0 as the current fruit's time runs out.
  double get fruitTimeLeft {
    final end =
        current + 1 < _starts.length ? _starts[current + 1] : durationMs;
    final span = end - _starts[current];
    return span <= 0
        ? 0
        : (1 - (elapsedMs - _starts[current]) / span).clamp(0.0, 1.0);
  }

  @override
  void onUpdate() {
    while (current + 1 < _starts.length && elapsedMs >= _starts[current + 1]) {
      current++;
      _firstHitTaken = false;
    }
  }

  bool slashedCurrent(int player) => lastSlash[player]?.fruit == current;

  /// Returns points scored, or null if this player already slashed this fruit.
  int? slash(int player, int lane) {
    if (finished || lane < 0 || lane >= lanes || slashedCurrent(player))
      return null;
    var pts = 0;
    if (lane == fruitLane) {
      pts = _firstHitTaken ? 1 : 2;
      _firstHitTaken = true;
      hits[player]++;
      score[player] += pts;
    }
    lastSlash[player] = Slash(current, lane, pts);
    notifyListeners();
    return pts;
  }
}

final LocalGameInfo fruitDuelInfo = LocalGameInfo(
  id: 'fruit_duel',
  title: 'Fruit Duel',
  emoji: '🍉',
  color: const Color(0xFF2ECC71),
  tagline: 'Slice it before your rival does!',
  rules: const [
    'A fruit pops up in one of three lanes on both sides.',
    'Tap the lane with the fruit to slice it. One try per fruit!',
    'First to slice gets +2, everyone else who gets it +1. Fruits get faster. Take turns (1-5 minutes each) or split the screen (20 seconds). 2 to 4 players.',
  ],
  scoreUnit: 'points',
  splitScreen: true,
  maxPlayers: 4,
  bot: botFor<FruitDuelLogic>((g, b, now) {
    if (g.finished || g.slashedCurrent(b.seat)) return;
    if (!b.thinkFirst(g.current, now, 380, 900)) return;
    final lane = b.chance(0.85)
        ? g.fruitLane
        : (g.fruitLane + 1 + b.rng.nextInt(FruitDuelLogic.lanes - 1)) %
            FruitDuelLogic.lanes;
    g.slash(b.seat, lane);
  }),
  // One phone: each player gets the whole screen for the chosen time.
  turns: TurnsSpec(
    play: (player, ms, onDone) => TickingPlay<FruitDuelLogic>(
      create: () => FruitDuelLogic(players: 1, durationMs: ms),
      onFinished: (s) => onDone(s.first),
      builder: (context, g) => Column(children: [
        TurnBar(
            player: player, score: g.scores.first, secondsLeft: g.secondsLeft),
        Expanded(child: _FruitHalf(player: player, index: 0, g: g)),
      ]),
    ),
    simulate: (ms, rng) => simulateTurn(
        FruitDuelLogic(players: 1, durationMs: ms, random: rng),
        fruitDuelInfo.bot!,
        ms,
        rng),
  ),
  play: (players, onFinished) => TickingPlay<FruitDuelLogic>(
    create: () => FruitDuelLogic(players: players.length),
    onFinished: onFinished,
    builder: (context, g) => PlayerZones(
      count: players.length,
      colors: [for (final p in players) p.color],
      middle: DuelMiddleBar(
          players: players,
          scores: g.scores,
          secondsLeft: g.secondsLeft,
          progress: g.progress),
      center: ZoneCenterChip('${g.secondsLeft}s'),
      zone: (i) => _FruitHalf(player: players[i], index: i, g: g),
    ),
  ),
);

class _FruitHalf extends StatelessWidget {
  final GpPlayer player;
  final int index;
  final FruitDuelLogic g;
  const _FruitHalf(
      {required this.player, required this.index, required this.g});

  @override
  Widget build(BuildContext context) {
    final mine = g.lastSlash[index];
    final usedTry = g.slashedCurrent(index);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
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
                      fontSize: 15))),
          Text('${g.score[index]}',
              style: const TextStyle(
                  fontFamily: Fonts.display,
                  color: Colors.white,
                  fontSize: 24,
                  fontFeatures: [FontFeature.tabularFigures()])),
        ]),
        const SizedBox(height: 8),
        Expanded(
          child: Row(children: [
            for (var lane = 0; lane < FruitDuelLogic.lanes; lane++)
              Expanded(
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (_) {
                    final pts = g.slash(index, lane);
                    if (pts != null)
                      (pts > 0
                              ? HapticFeedback.lightImpact()
                              : HapticFeedback.heavyImpact())
                          .ignore();
                  },
                  child: _Lane(
                    color: player.color,
                    fruit: lane == g.fruitLane ? g.fruitEmoji : null,
                    fruitId: g.current,
                    timeLeft: g.fruitTimeLeft,
                    slashHere: usedTry && mine!.lane == lane ? mine : null,
                    dim: usedTry,
                  ),
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}

/// The drawn fruit and its juice colour for each fruit key (the logic keeps emoji keys).
const _fruitArt = <String, (GameIcons, Color)>{
  '🍉': (GameIcons.watermelon, Color(0xFFEF5350)),
  '🍎': (GameIcons.apple, Color(0xFFE53935)),
  '🍊': (GameIcons.orange, Color(0xFFFF9800)),
  '🍍': (GameIcons.pineapple, Color(0xFFFFC107)),
  '🍇': (GameIcons.grapes, Color(0xFF7E57C2)),
  '🍌': (GameIcons.banana, Color(0xFFFFD54F)),
  '🍓': (GameIcons.strawberry, Color(0xFFE53935)),
  '🥝': (GameIcons.kiwi, Color(0xFF8BC34A)),
};

/// A wooden lane (spec 5.3 #27). The fruit pops up; a slice draws a blade arc with a juice
/// splash in the fruit's colour and the two halves fall apart.
class _Lane extends StatelessWidget {
  final Color color;
  final String? fruit;
  final int fruitId;
  final double timeLeft;
  final Slash? slashHere;
  final bool dim;
  const _Lane(
      {required this.color,
      required this.fruit,
      required this.fruitId,
      required this.timeLeft,
      required this.slashHere,
      required this.dim});

  @override
  Widget build(BuildContext context) {
    final s = slashHere;
    final art = fruit == null ? null : _fruitArt[fruit!];
    final sliced = s != null && s.points > 0;
    return Container(
      // Fill the whole column, fruit or not (otherwise the fruit's lane shrinks to fit it).
      width: double.infinity,
      height: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: fruit != null ? color : Colors.black.withValues(alpha: 0.4),
            width: fruit != null ? 3 : 1.5),
        boxShadow: [
          if (fruit != null)
            BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 16)
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CustomPaint(
          painter: const WoodPainter(radius: 0),
          child: Stack(alignment: Alignment.center, children: [
            // A faint blade at the bottom of every lane: tap here to slice.
            Positioned(
                bottom: 12,
                child: Opacity(
                    opacity: 0.35,
                    child: GameIcon(GameIcons.arrowUp,
                        size: 20, color: Colors.white.withValues(alpha: 0.9)))),
            if (art != null)
              TweenAnimationBuilder<double>(
                key: ValueKey('$fruitId${sliced ? 's' : ''}'),
                tween: Tween(begin: sliced ? 0 : 0.2, end: 1),
                duration: Duration(milliseconds: sliced ? 420 : 180),
                curve: sliced ? Curves.easeIn : Curves.easeOutBack,
                builder: (_, v, __) => sliced
                    ? SizedBox(
                        width: 90,
                        height: 120,
                        child: CustomPaint(
                            painter: _SlicePainter(art.$1, art.$2, v)))
                    : Transform.scale(
                        scale: v,
                        child: Opacity(
                          opacity:
                              dim && (s == null || s.points == 0) ? 0.35 : 1,
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            GameIcon(art.$1, size: 56, semanticLabel: 'fruit'),
                            const SizedBox(height: 6),
                            SizedBox(
                                width: 50,
                                child: MeterBar(value: timeLeft, height: 5)),
                          ]),
                        ),
                      ),
              ),
            if (s != null)
              Positioned(
                bottom: 30,
                child: Text(
                  s.points == 0
                      ? 'MISS'
                      : (s.points > 1 ? '+${s.points} FIRST!' : '+${s.points}'),
                  style: TextStyle(
                      fontFamily: Fonts.display,
                      color:
                          s.points == 0 ? const Color(0xFFFF8E8B) : Brand.gold,
                      fontSize: 20,
                      shadows: const [
                        Shadow(color: Color(0x99000000), offset: Offset(0, 2))
                      ]),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

/// The slice: a white blade arc, a juice splash, and the fruit's two halves falling apart.
class _SlicePainter extends CustomPainter {
  final GameIcons icon;
  final Color juice;
  final double t; // 0 -> 1
  _SlicePainter(this.icon, this.juice, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.4);
    const s = 56.0;
    // Juice splash.
    final splash = Paint()..color = juice.withValues(alpha: (1 - t) * 0.8);
    for (var k = 0; k < 7; k++) {
      final a = k * 0.9 + 0.3;
      canvas.drawCircle(
          c + Offset(cos(a), sin(a)) * (10 + t * 30), 5 * (1 - t) + 2, splash);
    }
    // Two halves sliding apart and falling.
    for (final side in [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(c.dx + side * t * 18, c.dy + t * t * 40);
      canvas.rotate(side * t * 0.6);
      canvas.clipRect(side < 0
          ? const Rect.fromLTWH(-s / 2, -s / 2, s / 2, s)
          : const Rect.fromLTWH(0, -s / 2, s / 2, s));
      paintIcon(canvas, icon, const Rect.fromLTWH(-s / 2, -s / 2, s, s));
      canvas.restore();
    }
    // The blade arc.
    if (t < 0.6) {
      final arc = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 1 - t / 0.6);
      canvas.drawArc(
          Rect.fromCircle(center: c + const Offset(0, 6), radius: 34),
          -2.4,
          1.9,
          false,
          arc);
    }
  }

  @override
  bool shouldRepaint(_SlicePainter o) => o.t != t;
}
