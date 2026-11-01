import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/ui/components.dart';
import 'package:flutter/services.dart';
import '../shell/local_game_info.dart';
import '../shell/ticking_play.dart';
import 'solo_common.dart';

enum Popper { mole, golden, bomb }

class Pop {
  final int hole;
  final Popper kind;
  final int until;
  Pop(this.hole, this.kind, this.until);
}

/// Whack-a-Mole: 30 seconds. Moles +1, golden moles +3, bombs -5 (never below 0).
/// Moles pop up faster as time runs out.
class WhackLogic extends SoloLogic {
  static const holes = 9, durationMs = 30000;
  final Random _rng;
  final List<Pop> up = [];
  int _nextPop = 400;
  int? lastHit; // hole of the last whack, for the splat
  int hits = 0;

  WhackLogic({Random? random}) : _rng = random ?? Random();

  int get msLeft => max(0, durationMs - now);

  @override
  void step(int now) {
    if (now >= durationMs) return gameOver(600);
    up.removeWhere((p) => now >= p.until);
    if (now >= _nextPop) {
      final free = [
        for (var h = 0; h < holes; h++)
          if (!up.any((p) => p.hole == h)) h
      ];
      if (free.isNotEmpty) {
        final r = _rng.nextDouble();
        final kind =
            r < 0.12 ? Popper.bomb : (r < 0.22 ? Popper.golden : Popper.mole);
        final life = (1100 - now * 0.02).round().clamp(550, 1100);
        up.add(Pop(free[_rng.nextInt(free.length)], kind, now + life));
      }
      _nextPop = now + (750 - now * 0.015).round().clamp(320, 750);
    }
    notifyListeners();
  }

  void whack(int hole) {
    if (over) return;
    final i = up.indexWhere((p) => p.hole == hole);
    if (i < 0) return;
    final p = up.removeAt(i);
    lastHit = hole;
    hits++;
    switch (p.kind) {
      case Popper.mole:
        score += 1;
        HapticFeedback.lightImpact().ignore();
      case Popper.golden:
        score += 3;
        HapticFeedback.mediumImpact().ignore();
      case Popper.bomb:
        score = max(0, score - 5);
        HapticFeedback.heavyImpact().ignore();
    }
    notifyListeners();
  }
}

final whackInfo = LocalGameInfo(
  id: 'whack_mole',
  title: 'Whack-a-Mole',
  emoji: '🔨',
  color: const Color(0xFF8D6E63),
  tagline: 'Bonk the moles, skip the bombs!',
  rules: const [
    'Moles pop out of the holes. Tap them before they hide!',
    'Mole +1 · golden mole +3 · bomb -5.',
    '30 seconds, and they get faster. How many can you bonk?',
  ],
  scoreUnit: 'points',
  splitScreen: false,
  minPlayers: 1,
  maxPlayers: 1,
  play: (players, onFinished) => TickingPlay<WhackLogic>(
    create: () => WhackLogic(),
    onFinished: onFinished,
    builder: (context, g) => SoloFrame(
      title: 'Whack-a-Mole',
      score: g.score,
      extra: '${(g.msLeft / 1000).ceil()}s',
      child: Center(
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF8BC34A), Color(0xFF5E9A2E)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF4E7D24), width: 3),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black45, offset: Offset(0, 6), blurRadius: 6)
              ],
            ),
            child: GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var h = 0; h < WhackLogic.holes; h++)
                  () {
                    final pop = g.up.where((p) => p.hole == h).firstOrNull;
                    return GestureDetector(
                      onTapDown: (_) => g.whack(h),
                      child: Container(
                        // A dirt pit: dark in the middle, a lighter rim of earth around it.
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [
                            Color(0xFF1E120D),
                            Color(0xFF3B2519),
                            Color(0xFF6D4A33)
                          ], stops: [
                            0.45,
                            0.8,
                            1
                          ]),
                          boxShadow: [
                            BoxShadow(
                                color: Color(0x66000000),
                                offset: Offset(0, 3),
                                blurRadius: 2)
                          ],
                        ),
                        alignment: Alignment.center,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 120),
                          transitionBuilder: (child, a) =>
                              ScaleTransition(scale: a, child: child),
                          child: pop == null
                              ? const SizedBox.shrink(key: ValueKey('empty'))
                              : FittedBox(
                                  key: ValueKey('${pop.until}'),
                                  child: Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Container(
                                      decoration: pop.kind == Popper.golden
                                          ? const BoxDecoration(
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                  BoxShadow(
                                                      color: Color(0xAAFFD54F),
                                                      blurRadius: 18,
                                                      spreadRadius: 2)
                                                ])
                                          : null,
                                      child: GameIcon(
                                          switch (pop.kind) {
                                            Popper.mole => GameIcons.mole,
                                            Popper.golden =>
                                              GameIcons.goldenMole,
                                            Popper.bomb => GameIcons.bomb
                                          },
                                          size: 64),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    );
                  }(),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);
