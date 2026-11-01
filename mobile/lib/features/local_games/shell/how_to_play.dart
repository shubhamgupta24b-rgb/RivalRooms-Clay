import 'package:flutter/material.dart';
import '../../../core/ui/components.dart';
import 'game_art.dart';
import 'local_game_info.dart';

/// Icon tile colours for rule steps, in turn (Intro mockup: blue, green, gold, ...).
const _stepTiles = [
  (Color(0xFF2E8BFF), Color(0xFF9CC9FF)),
  (Color(0xFF2ECC71), Color(0xFFB5F0CD)),
  (Color(0xFFFFC93C), Color(0xFFFFE7A0)),
  (Color(0xFFFF8A1F), Color(0xFFFFD2A8)),
  (Color(0xFFB07CFF), Color(0xFFDDC9FF)),
  (Color(0xFFFF5C8A), Color(0xFFFFC2D4)),
];

/// One rule: a 34 px icon tile (the rule's own icon, or its number) and the text, with any
/// emoji drawn as icons.
class RuleStep extends StatelessWidget {
  final int index;
  final String rule;
  const RuleStep({super.key, required this.index, required this.rule});

  @override
  Widget build(BuildContext context) {
    final (tile, ink) = _stepTiles[index % _stepTiles.length];
    final icon = leadingRuleIcon(rule);
    // The tile shows the rule's first icon; drop it from the text so it isn't drawn twice.
    final text = icon == null ? stripEmoji(rule) : _dropFirstEmoji(rule);
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: Skin.surface(tint: tile, radius: Radii.card, depth: 0.45),
        child: icon != null
            ? GameIcon(icon, size: 20, color: ink)
            : Text('${index + 1}',
                style: TextStyle(
                    fontFamily: Fonts.display, fontSize: 17, color: ink)),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text.rich(
          icon == null
              ? TextSpan(text: text)
              : ruleSpan(text, const TextStyle()),
          style: const TextStyle(
              fontFamily: Fonts.body,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              height: 1.3,
              color: Colors.white),
        ),
      ),
    ]);
  }
}

/// [s] without a leading emoji (the tile already shows it); emoji later in the text stay
/// and are drawn inline.
String _dropFirstEmoji(String s) {
  final t = s.trimLeft();
  final rest = stripEmoji(t.substring(0, t.length.clamp(0, 4)));
  if (rest == t.substring(0, t.length.clamp(0, 4)).trim()) return t;
  final first = t.indexOf(RegExp(r'[A-Za-z0-9(]'));
  return first < 0 ? t : t.substring(first);
}

/// Opens How to play for [game] (spec 2.11): game art, every rule as an icon step, Got it.
Future<void> showHowToPlay(BuildContext context, LocalGameInfo game) =>
    Navigator.of(context).push(PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: Motion.of(context, Motion.normal),
      reverseTransitionDuration: Motion.of(context, Motion.fast),
      pageBuilder: (_, __, ___) => HowToPlay(game: game),
      transitionsBuilder: (_, a, __, child) => FadeTransition(
        opacity: a,
        child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.04), end: Offset.zero)
                .animate(CurvedAnimation(parent: a, curve: Motion.standard)),
            child: child),
      ),
    ));

class HowToPlay extends StatelessWidget {
  final LocalGameInfo game;
  const HowToPlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return TokenScope(
      flat: false,
      child: Builder(builder: (context) {
        final t = context.tk;
        return Scaffold(
          backgroundColor: t.bg,
          body: DecoratedBox(
            decoration: const BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                  NeonPalette.bgTop,
                  NeonPalette.bg,
                  NeonPalette.bgBottom
                ],
                    stops: [
                  0,
                  0.45,
                  1
                ])),
            child: Column(children: [
              Expanded(
                child: ListView(padding: EdgeInsets.zero, children: [
                  SizedBox(
                    height: 200 + MediaQuery.paddingOf(context).top,
                    child: Stack(fit: StackFit.expand, children: [
                      GameArt(id: game.id, color: game.color),
                      Positioned(
                        left: 16,
                        top: MediaQuery.paddingOf(context).top + 14,
                        child: RoundButton(
                            icon: GameIcons.close,
                            label: 'Close',
                            dark: true,
                            onPressed: () => Navigator.maybePop(context)),
                      ),
                    ]),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -26),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('HOW TO PLAY', style: t.styles.label),
                            const SizedBox(height: 2),
                            Semantics(
                                header: true,
                                child: Text(game.title, style: t.styles.h1)),
                            const SizedBox(height: 2),
                            Text(stripEmoji(game.tagline),
                                style: const TextStyle(
                                    fontFamily: Fonts.body,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFD6DAF7))),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: Skin.surface(
                                  radius: Radii.button, depth: 0.85),
                              child: Column(children: [
                                for (var i = 0; i < game.rules.length; i++) ...[
                                  if (i > 0) const SizedBox(height: 10),
                                  RuleStep(index: i, rule: game.rules[i])
                                ],
                              ]),
                            ),
                          ]),
                    ),
                  ),
                ]),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
                  child: GoldButton('Got it',
                      height: 58,
                      fontSize: 24,
                      onPressed: () => Navigator.maybePop(context)),
                ),
              ),
            ]),
          ),
        );
      }),
    );
  }
}
