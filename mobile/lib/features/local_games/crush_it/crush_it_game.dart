import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../guess_person/models/gp_player.dart';
import 'dart:math';
import '../../../core/ui/components.dart';
import '../shell/local_game_shell.dart' show ResultScope;
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/split_screen.dart';
import '../shell/ticking_play.dart';

/// Same rules as the online version: most taps in 10 seconds wins.
class CrushItLogic extends TimedDuel {
  final List<int> taps;
  CrushItLogic({int durationMs = 10000, int players = 2})
      : taps = List.filled(players, 0),
        super(durationMs);

  @override
  List<int> get scores => taps;

  void tap(int player) {
    if (finished) return;
    taps[player]++;
    notifyListeners();
  }
}

final crushItInfo = LocalGameInfo(
  id: 'crush_it',
  title: 'Crush It',
  emoji: '👊',
  color: const Color(0xFFFF6B6B),
  tagline: 'Tap faster than your friend!',
  rules: const [
    'Smash your zone of the screen as fast as you can.',
    'Every tap counts for 10 seconds.',
    'Most taps wins. 2 to 6 players.'
  ],
  scoreUnit: 'taps',
  splitScreen: true,
  maxPlayers: 6,
  bot: botFor<CrushItLogic>((g, b, now) {
    if (g.finished || !b.due(now)) return;
    g.tap(b.seat);
    b.wait(now, 130, 230); // about 5-7 taps a second
  }),
  play: (players, onFinished) => TickingPlay<CrushItLogic>(
    create: () => CrushItLogic(players: players.length),
    onFinished: onFinished,
    builder: (context, g) {
      final top = g.taps.reduce(max);
      ResultScope.of(context)?.subtitle = '${g.taps.reduce(max)} taps to win';
      return PlayerZones(
        count: players.length,
        colors: [for (final p in players) p.color],
        middle: DuelMiddleBar(
            players: players,
            scores: g.scores,
            secondsLeft: g.secondsLeft,
            progress: g.progress),
        center: ZoneCenterChip('${g.secondsLeft}s'),
        zone: (i) => _CrushHalf(
            player: players[i],
            seat: PlayerPalette.indexOf(players[i].color) ?? i,
            taps: g.taps[i],
            onTap: () => g.tap(i),
            done: g.finished,
            leading: top > 0 && g.taps[i] == top),
      );
    },
  ),
);

/// A player's tactile pad (spec 5.3 #25): it squashes on every tap with a burst and a +1;
/// the leader's pad glows gold.
class _CrushHalf extends StatelessWidget {
  final GpPlayer player;
  final int seat;
  final int taps;
  final VoidCallback onTap;
  final bool done;
  final bool leading;
  const _CrushHalf(
      {required this.player,
      required this.seat,
      required this.taps,
      required this.onTap,
      required this.done,
      required this.leading});

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    // Listener (not a tap recogniser) so both players can hammer at the same time with no gesture delay.
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: done
          ? null
          : (_) {
              onTap();
              HapticFeedback.selectionClick().ignore();
            },
      child: Semantics(
        button: !done,
        label: '${player.name}: $taps taps. Tap fast!',
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.all(10),
          // Scales down on short screens instead of overflowing.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                PlayerBadge(
                    index: seat,
                    size: 22,
                    color: player.color,
                    initial: player.name),
                const SizedBox(width: 6),
                Text(player.name,
                    style: TextStyle(
                        fontFamily: Fonts.body,
                        color: nameColor(player.color),
                        fontWeight: FontWeight.w900,
                        fontSize: 16)),
              ]),
              const SizedBox(height: 10),
              SizedBox(
                width: 190,
                height: 170,
                child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // Burst rays from the last tap.
                      if (!reduced && taps > 0)
                        TweenAnimationBuilder<double>(
                          key: ValueKey('b$taps'),
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 260),
                          builder: (_, v, __) => CustomPaint(
                              size: const Size(190, 170),
                              painter: _Burst(v, player.color, taps)),
                        ),
                      // The pad squashes and springs back on every tap.
                      TweenAnimationBuilder<double>(
                        key: ValueKey(taps),
                        tween: Tween(begin: reduced ? 1 : 0.86, end: 1.0),
                        duration: const Duration(milliseconds: 160),
                        curve: Curves.easeOutBack,
                        builder: (_, s, child) => Transform.scale(
                            scaleX: 2 - s, scaleY: s, child: child),
                        child: Container(
                          width: 140,
                          height: 140,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                                center: const Alignment(-0.3, -0.35),
                                colors: [
                                  Color.lerp(player.color, Colors.white, 0.35)!,
                                  player.color,
                                  Color.lerp(player.color, Colors.black, 0.25)!
                                ]),
                            border: Border.all(
                                color:
                                    leading && done ? Brand.gold : Colors.white,
                                width: 4),
                            boxShadow: [
                              BoxShadow(
                                  color: Color.lerp(
                                      player.color, Colors.black, 0.5)!,
                                  offset: const Offset(0, 8)),
                              if (leading)
                                BoxShadow(
                                    color: Brand.gold
                                        .withValues(alpha: done ? 0.8 : 0.4),
                                    blurRadius: 24,
                                    spreadRadius: 2),
                            ],
                          ),
                          child: const GameIcon(GameIcons.hammer, size: 64),
                        ),
                      ),
                      // +1 floating up.
                      if (!reduced && taps > 0)
                        TweenAnimationBuilder<double>(
                          key: ValueKey('p$taps'),
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 420),
                          builder: (_, v, child) => Positioned(
                              top: 4 - v * 30,
                              right: 6,
                              child: Opacity(opacity: 1 - v, child: child)),
                          child: const Text('+1',
                              style: TextStyle(
                                  fontFamily: Fonts.display,
                                  fontSize: 26,
                                  color: Brand.gold,
                                  shadows: [
                                    Shadow(
                                        color: Color(0xFF7A4B00),
                                        offset: Offset(0, 2))
                                  ])),
                        ),
                    ]),
              ),
              const SizedBox(height: 6),
              Text('$taps',
                  style: const TextStyle(
                      fontFamily: Fonts.display,
                      color: Colors.white,
                      fontSize: 48,
                      height: 1,
                      fontFeatures: [FontFeature.tabularFigures()])),
              Text(done ? (leading ? 'Winner!' : 'Time!') : 'Tap! Tap! Tap!',
                  style: TextStyle(
                      fontFamily: Fonts.display,
                      color:
                          done && leading ? Brand.gold : NeonPalette.textMuted,
                      fontSize: 18)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Short rays bursting out from the pad (each tap gets a slightly different angle).
class _Burst extends CustomPainter {
  final double t;
  final Color color;
  final int seed;
  _Burst(this.t, this.color, this.seed);
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final p = Paint()
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = Color.lerp(color, Colors.white, 0.4)!.withValues(alpha: 1 - t);
    for (var k = 0; k < 8; k++) {
      final a = k * pi / 4 + seed * 0.37;
      final d = Offset(cos(a), sin(a));
      canvas.drawLine(c + d * (74 + t * 10), c + d * (84 + t * 22), p);
    }
  }

  @override
  bool shouldRepaint(_Burst o) => o.t != t;
}
