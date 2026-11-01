import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/ui/components.dart';
import 'package:flutter/services.dart';
import '../shell/local_game_info.dart';
import '../shell/ticking_play.dart';
import 'solo_common.dart';

const scrambleWords = [
  'APPLE', 'TIGER', 'CRICKET', 'GUITAR', 'PLANET', 'ROCKET', 'BANANA', 'GARDEN',
  'MANGO', 'RIVER', 'PENCIL', 'CAMERA', //
  'SCHOOL', 'FRIEND', 'WINTER', 'SUMMER', 'MONKEY', 'DOCTOR', 'TRAIN', 'CASTLE',
  'DRAGON', 'JUNGLE', 'BUTTER', 'COFFEE', //
  'LAPTOP', 'MOBILE', 'SILVER', 'PUZZLE', 'SPICY', 'SAMOSA', 'CANDLE', 'MIRROR',
  'ORANGE', 'PIRATE', 'WIZARD', 'TICKET', //
  'BRIDGE', 'FOREST', 'HAMMER', 'ISLAND', 'KITTEN', 'LEMON', 'MARKET', 'NEEDLE',
  'OCEAN', 'PARROT', 'QUEEN', 'RABBIT', //
  'SPIDER', 'TOMATO', 'VIOLIN', 'WALLET', 'YELLOW', 'ZEBRA', 'CLOUD', 'DANCE',
  'EAGLE', 'FLOWER', 'GHOST', 'HONEY',
];

/// Word Scramble: 60 seconds. Tap the letters in order to rebuild the hidden word.
/// Each solved word scores its length. SKIP if you're stuck.
class WordScrambleLogic extends SoloLogic {
  static const durationMs = 60000;
  final Random _rng;
  late final List<String> deck = [...scrambleWords]..shuffle(_rng);
  int index = 0;
  late List<String> letters; // shuffled tiles
  final List<int> picked = []; // tile indexes in tapping order
  int solved = 0;
  bool wrongFlash = false;

  WordScrambleLogic({Random? random}) : _rng = random ?? Random() {
    _deal();
  }

  String get word => deck[index % deck.length];
  String get attempt => picked.map((i) => letters[i]).join();
  int get msLeft => max(0, durationMs - now);

  void _deal() {
    picked.clear();
    final w = word.split('');
    do {
      w.shuffle(_rng);
    } while (w.join() == word && word.length > 1);
    letters = w;
  }

  void tapLetter(int i) {
    if (over || picked.contains(i)) return;
    picked.add(i);
    wrongFlash = false;
    HapticFeedback.selectionClick().ignore();
    if (picked.length == letters.length) {
      if (attempt == word) {
        score += word.length;
        solved++;
        HapticFeedback.mediumImpact().ignore();
        index++;
        _deal();
      } else {
        wrongFlash = true;
        picked.clear();
      }
    }
    notifyListeners();
  }

  void undo() {
    if (picked.isNotEmpty) picked.removeLast();
    notifyListeners();
  }

  void skip() {
    if (over) return;
    index++;
    _deal();
    notifyListeners();
  }

  @override
  void step(int now) {
    if (now >= durationMs) return gameOver(1500);
    notifyListeners(); // the clock
  }
}

final wordScrambleInfo = LocalGameInfo(
  id: 'word_scramble',
  title: 'Word Scramble',
  emoji: '🔤',
  color: const Color(0xFF00897B),
  tagline: 'Unscramble as many as you can!',
  rules: const [
    'The letters of a word are mixed up. Tap them in the right order.',
    'Each word you solve scores its number of letters.',
    '60 seconds. Stuck? SKIP to the next word.',
  ],
  scoreUnit: 'points',
  splitScreen: false,
  minPlayers: 1,
  maxPlayers: 1,
  play: (players, onFinished) => TickingPlay<WordScrambleLogic>(
    create: () => WordScrambleLogic(),
    onFinished: onFinished,
    builder: (context, g) => SoloFrame(
      title: 'Word Scramble',
      score: g.score,
      extra: '${(g.msLeft / 1000).ceil()}s',
      child: Column(children: [
        const Spacer(),
        if (g.over)
          Text('The word was ${g.word}',
              style: const TextStyle(
                  fontFamily: Fonts.display,
                  color: Colors.white70,
                  fontSize: 18)),
        // The answer slots: underlined spaces that fill with wooden tiles.
        Semantics(
          label: g.picked.isEmpty
              ? 'Empty answer'
              : 'Answer so far: ${[
                  for (final k in g.picked) g.letters[k]
                ].join()}',
          excludeSemantics: true,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            decoration: BoxDecoration(
                color: g.wrongFlash
                    ? const Color(0x66FF6B6B)
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: Radii.rCard),
            child: FittedBox(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                for (var i = 0; i < g.letters.length; i++)
                  Container(
                    width: 50,
                    height: 60,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                        border: Border(
                            bottom:
                                BorderSide(color: Colors.white54, width: 3))),
                    child: i < g.picked.length
                        ? _WoodTile(g.letters[g.picked[i]], size: 46)
                        : null,
                  ),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(g.wrongFlash ? 'Not quite! Try again' : '${g.solved} solved',
            style: TextStyle(
                fontFamily: Fonts.body,
                color: g.wrongFlash
                    ? const Color(0xFFFF6B6B)
                    : NeonPalette.textMuted,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 20),
        Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < g.letters.length; i++)
                Opacity(
                  opacity: g.picked.contains(i) ? 0.2 : 1,
                  child: Semantics(
                    button: true,
                    label: g.letters[i],
                    excludeSemantics: true,
                    child: GestureDetector(
                        onTap:
                            g.picked.contains(i) ? null : () => g.tapLetter(i),
                        child: _WoodTile(g.letters[i], size: 58)),
                  ),
                ),
            ]),
        const Spacer(),
        Row(children: [
          Expanded(
              child: KitButton('Undo',
                  icon: GameIcons.undo,
                  style: KitButtonStyle.outline,
                  onPressed: g.undo)),
          const SizedBox(width: 12),
          Expanded(
              child: KitButton('Skip',
                  icon: GameIcons.skip,
                  style: KitButtonStyle.soft,
                  onPressed: g.skip)),
        ]),
      ]),
    ),
  ),
);

/// A wooden letter tile (like a word-game tile, without letter values).
class _WoodTile extends StatelessWidget {
  final String letter;
  final double size;
  const _WoodTile(this.letter, {required this.size});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFF6DCAA),
                Color(0xFFE0B672),
                Color(0xFFC99752)
              ]),
          borderRadius: BorderRadius.circular(size * 0.18),
          border: Border.all(color: const Color(0x66FFF3D6), width: 1.5),
          boxShadow: const [
            BoxShadow(color: Color(0xFF5A3514), offset: Offset(0, 4))
          ],
        ),
        child: Text(letter,
            style: TextStyle(
                fontFamily: Fonts.display,
                color: const Color(0xFF4A2C14),
                fontSize: size * 0.55,
                height: 1)),
      );
}
