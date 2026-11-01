import 'dart:math';
import 'package:flutter/material.dart';
import '../data/person_data.dart';
import '../logic/gp_settings.dart';
import '../../../core/ui/components.dart';
import '../widgets/gp_theme.dart';
import '../widgets/person_portrait.dart';
import 'gp_settings_screen.dart';
import 'guess_person_game_screen.dart';
import 'how_to_play_screen.dart';

class GuessPersonMenuScreen extends StatefulWidget {
  const GuessPersonMenuScreen({super.key});
  @override
  State<GuessPersonMenuScreen> createState() => _GuessPersonMenuScreenState();
}

class _GuessPersonMenuScreenState extends State<GuessPersonMenuScreen>
    with SingleTickerProviderStateMixin {
  GpSettings settings = const GpSettings();
  late final AnimationController _bob =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))
        ..repeat();

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  Future<void> _openSettings() async {
    final s = await Navigator.push<GpSettings>(context,
        MaterialPageRoute(builder: (_) => GpSettingsScreen(initial: settings)));
    if (s != null && mounted) setState(() => settings = s);
  }

  @override
  Widget build(BuildContext context) {
    final faces = [
      allPeople[3],
      allPeople[0],
      allPeople[11],
      allPeople[4],
      allPeople[15]
    ];
    return Scaffold(
      body: CoralBackground(
        child: SafeArea(
          child: Stack(children: [
            Positioned(
                top: 14,
                left: 16,
                child: RoundButton(
                    icon: GameIcons.back,
                    label: 'Back',
                    onPressed: () => Navigator.maybePop(context))),
            Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Bobbing row of characters.
                        SizedBox(
                          height: 86,
                          child: AnimatedBuilder(
                            animation: _bob,
                            builder: (_, __) => FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    for (var i = 0; i < faces.length; i++)
                                      Transform.translate(
                                        offset: Offset(0,
                                            sin(_bob.value * 2 * pi + i) * 6),
                                        child: Container(
                                          width: 58,
                                          height: 58,
                                          margin: const EdgeInsets.symmetric(
                                              horizontal: 4),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: Colors.white, width: 3),
                                            boxShadow: const [
                                              BoxShadow(
                                                  color: Colors.black38,
                                                  blurRadius: 6,
                                                  offset: Offset(0, 3))
                                            ],
                                          ),
                                          child: ClipOval(
                                              child: PersonPortrait(faces[i])),
                                        ),
                                      ),
                                  ]),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text('Guess the\nPerson',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontFamily: Fonts.display,
                                color: Colors.white,
                                fontSize: 48,
                                height: 1.0)),
                        const SizedBox(height: 10),
                        Text(
                            '${settings.playerCount} players · one device · pass & play',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontFamily: Fonts.body,
                                color: NeonPalette.textMuted,
                                fontSize: 15,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 36),
                        GpButton('PLAY', icon: Icons.play_arrow_rounded,
                            onPressed: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => GuessPersonGameScreen(
                                      settings: settings)));
                        }),
                        const SizedBox(height: 14),
                        GpButton('HOW TO PLAY',
                            icon: Icons.help_outline_rounded,
                            color: const Color(0xFF4D96FF),
                            textColor: Colors.white, onPressed: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const HowToPlayScreen()));
                        }),
                        const SizedBox(height: 14),
                        GpButton('SETTINGS',
                            icon: Icons.tune_rounded,
                            outlined: true,
                            onPressed: _openSettings),
                        const SizedBox(height: 18),
                        Text(
                          '${settings.peopleCount} people · ${settings.rounds} rounds ·${settings.hasTimer ? '${settings.timerSeconds}s timer' : 'no timer'} ·${settings.autoEliminate ? 'auto' : 'manual'} elimination · sound ${settings.sound ? 'on' : 'off'}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontFamily: Fonts.body,
                              color: NeonPalette.label,
                              fontSize: 12,
                              fontWeight: FontWeight.w700),
                        ),
                      ]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
