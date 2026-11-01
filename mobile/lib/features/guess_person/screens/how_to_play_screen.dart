import 'package:flutter/material.dart';
import '../../../core/ui/components.dart';
import '../widgets/gp_theme.dart';

/// How to play Guess the Person: numbered steps with drawn icons, then Got it.
class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  static const _steps = [
    (GameIcons.lock, 'One player secretly chooses a person.'),
    (GameIcons.people, 'Pass the device to the other player.'),
    (
      GameIcons.speech,
      'Ask questions and use the YES / NO clues to eliminate people.'
    ),
    (
      GameIcons.target,
      'Select your final guess (before the timer runs out, if one is set).'
    ),
    (GameIcons.star, 'Correct guesses earn 1 point. Roles switch every round.'),
  ];
  static const _tints = [
    Color(0xFF2E8BFF),
    Color(0xFF2ECC71),
    Color(0xFFFFC93C),
    Color(0xFFFF8A1F),
    Color(0xFFB07CFF)
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CoralBackground(
        child: SafeArea(
          child: Column(children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const PageHeader(
                              label: 'Guess the Person',
                              title: 'How to play',
                              backIcon: GameIcons.close),
                          const SizedBox(height: 18),
                          DarkPanel(
                            padding: const EdgeInsets.all(12),
                            child: Column(children: [
                              for (var i = 0; i < _steps.length; i++) ...[
                                if (i > 0) const SizedBox(height: 10),
                                Row(children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                        color: _tints[i].withValues(alpha: 0.2),
                                        borderRadius: Radii.rCard),
                                    child: GameIcon(_steps[i].$1,
                                        size: 22,
                                        color: Color.lerp(
                                            _tints[i], Colors.white, 0.5)!),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('STEP ${i + 1}',
                                              style: const TextStyle(
                                                  fontFamily: Fonts.body,
                                                  color: NeonPalette.label,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 11,
                                                  letterSpacing: 1.4)),
                                          Text(_steps[i].$2,
                                              style: const TextStyle(
                                                  fontFamily: Fonts.body,
                                                  color: Colors.white,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w800,
                                                  height: 1.3)),
                                        ]),
                                  ),
                                ]),
                              ],
                            ]),
                          ),
                        ]),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 22),
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: GoldButton('Got it',
                      height: 58, onPressed: () => Navigator.pop(context))),
            ),
          ]),
        ),
      ),
    );
  }
}
