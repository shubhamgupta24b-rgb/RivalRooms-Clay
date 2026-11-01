import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/audio/game_audio.dart';
import '../../../core/ui/components.dart';
import 'package:flutter/services.dart';
import '../shell/local_game_info.dart';
import '../shell/ticking_play.dart';
import 'solo_common.dart';

const hangmanWords = {
  '🎬 Bollywood': [
    'SHOLAY',
    'DANGAL',
    'LAGAAN',
    'BAAHUBALI',
    'PATHAAN',
    'ANDHADHUN',
    'BARFI',
    'QUEEN',
    'DEVDAS',
    'SWADES',
    'KAHAANI',
    'PADMAAVAT'
  ],
  '🍛 Food': [
    'BIRYANI',
    'SAMOSA',
    'DOSA',
    'PANEER',
    'JALEBI',
    'PAKORA',
    'KHICHDI',
    'RASGULLA',
    'CHOLE',
    'PARATHA',
    'LASSI',
    'MOMOS'
  ],
  '🐾 Animals': [
    'ELEPHANT',
    'GIRAFFE',
    'PEACOCK',
    'KANGAROO',
    'DOLPHIN',
    'PENGUIN',
    'TIGER',
    'CHEETAH',
    'OCTOPUS',
    'RHINO',
    'ZEBRA',
    'CAMEL'
  ],
  '🌍 Countries': [
    'INDIA',
    'JAPAN',
    'BRAZIL',
    'CANADA',
    'EGYPT',
    'NEPAL',
    'FRANCE',
    'MEXICO',
    'KENYA',
    'NORWAY',
    'TURKEY',
    'BHUTAN'
  ],
  '🏏 Sports': [
    'CRICKET',
    'KABADDI',
    'HOCKEY',
    'TENNIS',
    'BADMINTON',
    'FOOTBALL',
    'CHESS',
    'BOXING',
    'ARCHERY',
    'CYCLING',
    'KHOKHO',
    'SWIMMING'
  ],
  '🏙️ Cities': [
    'MUMBAI',
    'DELHI',
    'JAIPUR',
    'KOLKATA',
    'CHENNAI',
    'PUNE',
    'GOA',
    'AGRA',
    'LUCKNOW',
    'INDORE',
    'SHIMLA',
    'MYSORE'
  ],
};

const hangmanClues = {
  'SHOLAY': 'Two friends take on a bandit in a village',
  'DANGAL': 'A wrestling family story',
  'LAGAAN': 'A village cricket match against the British',
  'BAAHUBALI': 'A kingdom split by a waterfall',
  'PATHAAN': 'A spy action film',
  'ANDHADHUN': 'A pianist who pretends he cannot see',
  'BARFI': 'A silent, cheerful lead',
  'QUEEN': 'A honeymoon taken alone',
  'DEVDAS': 'A man lost to a lost love',
  'SWADES': 'An engineer returns to a village',
  'KAHAANI': 'A search through Kolkata',
  'PADMAAVAT': 'A queen and a sultan',
  'BIRYANI': 'Rice cooked with spices',
  'SAMOSA': 'A fried triangular snack',
  'DOSA': 'A thin South Indian crepe',
  'PANEER': 'Fresh Indian cheese',
  'JALEBI': 'A sweet spiral fried in syrup',
  'PAKORA': 'Vegetables fried in batter',
  'KHICHDI': 'Rice and lentils cooked together',
  'RASGULLA': 'A spongy syrup sweet',
  'CHOLE': 'Spiced chickpeas',
  'PARATHA': 'A layered flatbread',
  'LASSI': 'A yogurt drink',
  'MOMOS': 'Steamed dumplings',
  'ELEPHANT': 'The largest land animal',
  'GIRAFFE': 'The tallest land animal',
  'PEACOCK': 'A bird that fans its tail',
  'KANGAROO': 'It hops and has a pouch',
  'DOLPHIN': 'A smart sea mammal',
  'PENGUIN': 'A bird that swims and cannot fly',
  'TIGER': 'A striped big cat',
  'CHEETAH': 'The fastest land animal',
  'OCTOPUS': 'Eight arms in the sea',
  'RHINO': 'A horn on its nose',
  'ZEBRA': 'Stripes, and a relative of the horse',
  'CAMEL': 'A desert animal with a hump',
  'INDIA': 'Home of the Taj Mahal',
  'JAPAN': 'An island country in East Asia',
  'BRAZIL': 'Famous for carnival and football',
  'CANADA': 'A large country north of the United States',
  'EGYPT': 'Home of the pyramids',
  'NEPAL': 'Home of Mount Everest',
  'FRANCE': 'Home of the Eiffel Tower',
  'MEXICO': 'Tacos and ancient pyramids',
  'KENYA': 'Known for safaris',
  'NORWAY': 'Fjords in northern Europe',
  'TURKEY': 'A country between Europe and Asia',
  'BHUTAN': 'A small kingdom in the Himalayas',
  'CRICKET': 'Bat, ball, and wickets',
  'KABADDI': 'A contact sport of raids',
  'HOCKEY': 'A stick and a goal',
  'TENNIS': 'A racket and a net',
  'BADMINTON': 'A shuttlecock over a net',
  'FOOTBALL': 'Kick a ball into a goal',
  'CHESS': 'Kings, queens, and a checkmate',
  'BOXING': 'Gloves and a ring',
  'ARCHERY': 'Bows and arrows',
  'CYCLING': 'A race on two wheels',
  'KHOKHO': 'A chasing game played in teams',
  'SWIMMING': 'A race through water',
  'MUMBAI': 'A huge city on the Arabian Sea',
  'DELHI': 'India\'s capital',
  'JAIPUR': 'The pink city',
  'KOLKATA': 'A city on the Hooghly',
  'CHENNAI': 'A coastal city in Tamil Nadu',
  'PUNE': 'A city near Mumbai',
  'GOA': 'Beaches on India\'s west coast',
  'AGRA': 'The city of the Taj Mahal',
  'LUCKNOW': 'A city known for kebabs',
  'INDORE': 'A city in Madhya Pradesh',
  'SHIMLA': 'A hill station in Himachal',
  'MYSORE': 'A palace city in Karnataka',
};

/// Hangman: guess the word one letter at a time. 6 wrong guesses and the drawing is
/// complete. Every word you get is a point; the game ends when you miss one.
class HangmanLogic extends SoloLogic {
  static const lives = 6;
  final Random rng;
  late String category, word;
  final Set<String> guessed = {};
  int wrong = 0;
  int? wonAt;
  final List<String> _used = [];

  HangmanLogic({Random? random}) : rng = random ?? Random() {
    _next();
  }

  void _next() {
    final cats = hangmanWords.keys.toList();
    do {
      category = cats[rng.nextInt(cats.length)];
      final list = hangmanWords[category]!;
      word = list[rng.nextInt(list.length)];
    } while (_used.contains(word) && _used.length < 40);
    _used.add(word);
    guessed.clear();
    wrong = 0;
    hinted = false;
    clue = null;
  }

  bool hinted = false;
  String? clue;

  void useHint() {
    if (hinted || over || wonAt != null) return;
    hinted = true;
    clue = hangmanClues[word] ?? 'A word from this category';
    wrong++;
    if (wrong >= lives) gameOver(2200);
    notifyListeners();
  }

  bool get won => word.split('').every(guessed.contains);
  String get shown => [
        for (final ch in word.split('')) guessed.contains(ch) || over ? ch : '_'
      ].join(' ');

  void guess(String letter) {
    if (over || wonAt != null || guessed.contains(letter)) return;
    guessed.add(letter);
    if (!word.contains(letter)) {
      wrong++;
      HapticFeedback.heavyImpact().ignore();
      if (wrong >= lives) gameOver(2200);
    } else {
      HapticFeedback.selectionClick().ignore();
      if (won) {
        score++;
        wonAt = now;
      }
    }
    notifyListeners();
  }

  @override
  void step(int now) {
    final at = wonAt;
    if (at != null && now - at > 1200) {
      wonAt = null;
      _next();
      notifyListeners();
    }
  }
}

final hangmanInfo = LocalGameInfo(
  id: 'hangman',
  title: 'Hangman',
  emoji: '🪢',
  color: const Color(0xFF8D6E63),
  tagline: 'Guess the word before you run out of lives!',
  rules: const [
    'A secret word and its category. Tap letters to guess.',
    'A wrong letter costs a life: 6 and the drawing is done.',
    'Every word you get is a point. Miss one and the game ends.',
  ],
  scoreUnit: 'words',
  splitScreen: false,
  minPlayers: 1,
  maxPlayers: 1,
  play: (players, onFinished) => TickingPlay<HangmanLogic>(
    create: () => HangmanLogic(),
    onFinished: onFinished,
    builder: (context, g) => SoloFrame(
      title: g.wonAt != null
          ? 'Got it!'
          : (g.over ? 'It was ${g.word}' : 'Hangman'),
      score: g.score,
      extra: stripEmoji(g.category),
      lives: HangmanLogic.lives - g.wrong,
      maxLives: HangmanLogic.lives,
      child: Column(children: [
        // A chalkboard in a wooden frame; the gallows and figure are drawn in chalk.
        Expanded(
          flex: 5,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF23423A),
              borderRadius: Radii.rCard,
              border: Border.all(color: const Color(0xFF8A5A2B), width: 6),
              boxShadow: Shadows.large,
            ),
            child: Stack(children: [
              Positioned.fill(
                  child: CustomPaint(
                      painter: _GallowsPainter(g.wrong, g.over && !g.won))),
              Positioned(
                left: 10,
                top: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                      borderRadius: Radii.rChip,
                      border: Border.all(color: Colors.white54, width: 1.5)),
                  child: Text(stripEmoji(g.category).toUpperCase(),
                      style: const TextStyle(
                          fontFamily: Fonts.body,
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4)),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        if (g.clue != null)
          Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(g.clue!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFFFFE08A), fontWeight: FontWeight.w700))),
        FittedBox(
          child: Text(g.shown,
              style: TextStyle(
                  color: g.wonAt != null
                      ? StatusColors.success
                      : (g.over ? const Color(0xFFFF6B6B) : Colors.white),
                  fontSize: 36,
                  fontFamily: Fonts.display,
                  letterSpacing: 2)),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.center,
          child: TextButton(
            onPressed: g.hinted || g.over || g.wonAt != null
                ? null
                : () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Use a hint?'),
                        content: const Text(
                            'A hint costs 1 life and gives a clue. It does not reveal the word.'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel')),
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Use hint')),
                        ],
                      ),
                    );
                    if (ok == true) g.useHint();
                  },
            child: Text(g.hinted ? 'Hint used' : 'Hint · costs 1 life'),
          ),
        ),
        const SizedBox(height: 6),
        // Keys at least 48dp wide: 7 a row where they fit, else 6.
        LayoutBuilder(builder: (context, c) {
          const gap = 5.0;
          final perRow = c.maxWidth >= 7 * kTouchTarget + 6 * gap ? 7 : 6;
          final keyW = ((c.maxWidth - gap * (perRow - 1)) / perRow)
              .clamp(kTouchTarget, 58.0);
          return Wrap(
              alignment: WrapAlignment.center,
              spacing: gap,
              runSpacing: 6,
              children: [
                for (final l in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split(''))
                  SizedBox(
                    width: keyW,
                    height: 50,
                    child: Semantics(
                      button: !g.guessed.contains(l),
                      label: g.guessed.contains(l)
                          ? '$l, ${g.word.contains(l) ? 'in the word' : 'not in the word'}'
                          : l,
                      excludeSemantics: true,
                      // Chalk keys: unused keys are board-green with chalk letters; right guesses
                      // turn green, wrong ones grey out with a red cross.
                      child: Material(
                        color: !g.guessed.contains(l)
                            ? const Color(0xFF2E5448)
                            : (g.word.contains(l)
                                ? fillFor(context.tk.success)
                                : const Color(0xFF1A2A26)),
                        shape: RoundedRectangleBorder(
                            borderRadius: Radii.rMd,
                            side: BorderSide(
                                color: Colors.white.withValues(
                                    alpha:
                                        g.guessed.contains(l) ? 0.08 : 0.35))),
                        child: InkWell(
                          borderRadius: Radii.rMd,
                          onTap: g.guessed.contains(l)
                              ? null
                              : () {
                                  haptic(HapticWeight.selection);
                                  GameAudio.sfx(
                                      g.word.contains(l) ? 'pop' : 'tap');
                                  g.guess(l);
                                },
                          child: Stack(alignment: Alignment.center, children: [
                            Text(l,
                                style: TextStyle(
                                    fontFamily: Fonts.display,
                                    color: !g.guessed.contains(l) ||
                                            g.word.contains(l)
                                        ? Colors.white
                                        : Colors.white30,
                                    fontSize: 21)),
                            if (g.guessed.contains(l) && !g.word.contains(l))
                              const GameIcon(GameIcons.cross,
                                  size: 26, color: Color(0xCCFF6B6B)),
                          ]),
                        ),
                      ),
                    ),
                  ),
              ]);
        }),
      ]),
    ),
  ),
);

class _GallowsPainter extends CustomPainter {
  final int wrong;
  final bool lost;
  _GallowsPainter(this.wrong, this.lost);

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height, w = size.width;
    final cx = w / 2;
    final wood = Paint()
      ..color = const Color(0xE6F4F1E8)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx - 90, h * 0.95), Offset(cx + 40, h * 0.95), wood);
    canvas.drawLine(Offset(cx - 60, h * 0.95), Offset(cx - 60, h * 0.06), wood);
    canvas.drawLine(Offset(cx - 60, h * 0.06), Offset(cx + 30, h * 0.06), wood);
    canvas.drawLine(Offset(cx - 60, h * 0.2), Offset(cx - 35, h * 0.06),
        wood..strokeWidth = 5);
    final rope = Paint()
      ..color = const Color(0xB3F4F1E8)
      ..strokeWidth = 3;
    canvas.drawLine(Offset(cx + 30, h * 0.06), Offset(cx + 30, h * 0.18), rope);
    final body = Paint()
      ..color = lost ? const Color(0xFFFF8A80) : const Color(0xFFF4F1E8)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final head = h * 0.08;
    if (wrong > 0)
      canvas.drawCircle(Offset(cx + 30, h * 0.18 + head), head, body);
    final neck = h * 0.18 + head * 2, hip = h * 0.62;
    if (wrong > 1)
      canvas.drawLine(Offset(cx + 30, neck), Offset(cx + 30, hip), body);
    if (wrong > 2)
      canvas.drawLine(
          Offset(cx + 30, neck + 12), Offset(cx + 5, h * 0.48), body);
    if (wrong > 3)
      canvas.drawLine(
          Offset(cx + 30, neck + 12), Offset(cx + 55, h * 0.48), body);
    if (wrong > 4)
      canvas.drawLine(Offset(cx + 30, hip), Offset(cx + 8, h * 0.82), body);
    if (wrong > 5)
      canvas.drawLine(Offset(cx + 30, hip), Offset(cx + 52, h * 0.82), body);
  }

  @override
  bool shouldRepaint(_GallowsPainter old) =>
      old.wrong != wrong || old.lost != lost;
}
