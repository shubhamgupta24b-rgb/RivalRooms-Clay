import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/ui/components.dart';
import 'package:flutter/services.dart';
import '../shell/local_game_info.dart';
import '../shell/ticking_play.dart';
import 'solo_common.dart';

enum SimonPhase { showing, input, pause }

/// Simon Says: watch the pads light up, then repeat the pattern. One more step each round.
/// Score: the longest pattern you repeated.
class SimonLogic extends SoloLogic {
  static const pads = 4;
  final Random _rng;
  final List<int> sequence = [];
  SimonPhase phase = SimonPhase.pause;
  int _phaseAt = 0;
  int typed = 0;
  int? lit; // pad lit right now
  int? wrongPad;

  SimonLogic({Random? random}) : _rng = random ?? Random() {
    sequence.add(_rng.nextInt(pads));
    _phaseAt = 700;
  }

  int get flashMs => max(260, 560 - sequence.length * 20);

  @override
  void step(int now) {
    if (phase == SimonPhase.pause) {
      if (now >= _phaseAt) {
        phase = SimonPhase.showing;
        _phaseAt = now;
      }
      lit = null;
    } else if (phase == SimonPhase.showing) {
      final k = (now - _phaseAt) ~/ (flashMs + 180);
      final into = (now - _phaseAt) % (flashMs + 180);
      if (k >= sequence.length) {
        phase = SimonPhase.input;
        typed = 0;
        lit = null;
      } else {
        lit = into < flashMs ? sequence[k] : null;
      }
    }
    notifyListeners();
  }

  void press(int pad) {
    if (over || phase != SimonPhase.input) return;
    HapticFeedback.selectionClick().ignore();
    if (pad != sequence[typed]) {
      wrongPad = pad;
      HapticFeedback.heavyImpact().ignore();
      gameOver(1500);
      return;
    }
    typed++;
    if (typed == sequence.length) {
      score = sequence.length;
      sequence.add(_rng.nextInt(pads));
      phase = SimonPhase.pause;
      _phaseAt = now + 800;
    }
    notifyListeners();
  }
}

final simonInfo = LocalGameInfo(
  id: 'simon_says',
  title: 'Simon Says',
  emoji: '🟢',
  color: const Color(0xFF26A69A),
  tagline: 'Watch, remember, repeat!',
  rules: const [
    'Watch the coloured pads light up one by one.',
    'Then tap them back in exactly the same order.',
    'Each round adds one more step. How long a pattern can you remember?',
  ],
  scoreUnit: 'steps',
  splitScreen: false,
  minPlayers: 1,
  maxPlayers: 1,
  play: (players, onFinished) => TickingPlay<SimonLogic>(
    create: () => SimonLogic(),
    onFinished: onFinished,
    builder: (context, g) => SoloFrame(
      title: switch (g.phase) {
        _ when g.over => 'Wrong pad!',
        SimonPhase.input => 'Your turn (${g.typed}/${g.sequence.length})',
        _ => 'Watch...',
      },
      score: g.score,
      // A round console (spec 5.4 #52): four pads with rounded outer corners and a hub
      // in the middle showing the step count.
      child: Center(
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                  colors: [Color(0xFF2A2440), Color(0xFF14101F)]),
              border: Border.all(color: const Color(0xFF3D3560), width: 3),
              boxShadow: Shadows.large,
            ),
            child: Stack(alignment: Alignment.center, children: [
              GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (var p = 0; p < SimonLogic.pads; p++)
                    () {
                      const colors = [
                        Color(0xFF3B82F6),
                        Color(0xFFFF8A1F),
                        Color(0xFF22C55E),
                        Color(0xFFA855F7)
                      ];
                      const names = ['blue', 'orange', 'green', 'purple'];
                      const big = Radius.circular(400),
                          small = Radius.circular(18);
                      final radius = BorderRadius.only(
                        topLeft: p == 0 ? big : small,
                        topRight: p == 1 ? big : small,
                        bottomLeft: p == 2 ? big : small,
                        bottomRight: p == 3 ? big : small,
                      );
                      final on = g.lit == p || (g.wrongPad == p);
                      return Semantics(
                        button: true,
                        label: '${names[p]} pad',
                        excludeSemantics: true,
                        child: GestureDetector(
                          onTapDown: (_) => g.press(p),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 90),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: on
                                    ? [
                                        Colors.white,
                                        Color.lerp(
                                            colors[p], Colors.white, 0.45)!
                                      ]
                                    : [
                                        Color.lerp(
                                            colors[p], Colors.white, 0.15)!,
                                        Color.lerp(
                                            colors[p],
                                            Colors.black,
                                            g.phase == SimonPhase.input
                                                ? 0.15
                                                : 0.45)!
                                      ],
                              ),
                              borderRadius: radius,
                              border: Border.all(
                                  color: Colors.white
                                      .withValues(alpha: on ? 0.9 : 0.18),
                                  width: 3),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    offset: const Offset(0, 5)),
                                if (on)
                                  BoxShadow(
                                      color: colors[p],
                                      blurRadius: 34,
                                      spreadRadius: 6),
                              ],
                            ),
                          ),
                        ),
                      );
                    }(),
                ],
              ),
              // The hub.
              FractionallySizedBox(
                widthFactor: 0.34,
                heightFactor: 0.34,
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1B1630),
                    border:
                        Border.all(color: const Color(0xFF3D3560), width: 5),
                    boxShadow: const [
                      BoxShadow(color: Color(0x88000000), blurRadius: 10)
                    ],
                  ),
                  child: FittedBox(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('${g.sequence.length}',
                            style: const TextStyle(
                                fontFamily: Fonts.display,
                                color: Colors.white,
                                fontSize: 40,
                                height: 1)),
                        const Text('STEPS',
                            style: TextStyle(
                                fontFamily: Fonts.body,
                                color: Colors.white60,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5)),
                      ]),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    ),
  ),
);
