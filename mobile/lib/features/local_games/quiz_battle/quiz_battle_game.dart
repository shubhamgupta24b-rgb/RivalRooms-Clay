import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/audio/game_audio.dart';
import '../../../core/ui/components.dart';
import '../../guess_person/models/gp_player.dart';
import '../shell/game_hud.dart' show MomentWatcher;
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/split_screen.dart';
import '../shell/ticking_play.dart';

/// (category, question, correct answer, three wrong answers)
const quizBank = [
  (
    '🎬',
    'Who played "Rancho" in 3 Idiots?',
    'Aamir Khan',
    ['Shah Rukh Khan', 'R. Madhavan', 'Sharman Joshi']
  ),
  (
    '🎬',
    'Which film has the dialogue "Kitne aadmi the?"',
    'Sholay',
    ['Deewar', 'Don', 'Zanjeer']
  ),
  (
    '🎬',
    'Who directed Baahubali?',
    'S. S. Rajamouli',
    ['Mani Ratnam', 'Shankar', 'Rohit Shetty']
  ),
  (
    '🎬',
    'Which song from RRR won an Oscar?',
    'Naatu Naatu',
    ['Jai Ho', 'Komuram Bheemudo', 'Dosti']
  ),
  (
    '🎬',
    'Who is called the "King Khan" of Bollywood?',
    'Shah Rukh Khan',
    ['Salman Khan', 'Aamir Khan', 'Saif Ali Khan']
  ),
  (
    '🎬',
    'In which film does Raj say "Palat!"?',
    'Dilwale Dulhania Le Jayenge',
    ['Kuch Kuch Hota Hai', 'Dil To Pagal Hai', 'Mohabbatein']
  ),
  (
    '🎬',
    'Which film is about a girls\' hockey team?',
    'Chak De! India',
    ['Dangal', 'Lagaan', 'Sultan']
  ),
  (
    '🎬',
    'Who played the wrestler Mahavir Singh Phogat in Dangal?',
    'Aamir Khan',
    ['Salman Khan', 'Ranveer Singh', 'Akshay Kumar']
  ),
  (
    '🎬',
    'Which 2001 film features a cricket match against the British?',
    'Lagaan',
    ['Iqbal', '83', 'Jannat']
  ),
  (
    '🎬',
    '"Mogambo khush hua" is from which film?',
    'Mr. India',
    ['Karma', 'Tezaab', 'Ram Lakhan']
  ),
  (
    '🏏',
    'Who captained India to the 2011 World Cup win?',
    'MS Dhoni',
    ['Virat Kohli', 'Sourav Ganguly', 'Rahul Dravid']
  ),
  ('🏏', 'How many balls are there in an over?', '6', ['5', '8', '10']),
  (
    '🏏',
    'Who is known as the "Master Blaster"?',
    'Sachin Tendulkar',
    ['Virender Sehwag', 'Brian Lara', 'Virat Kohli']
  ),
  (
    '🏏',
    'Which country won the first Cricket World Cup in 1975?',
    'West Indies',
    ['England', 'Australia', 'India']
  ),
  (
    '🏏',
    'Which IPL team is called "Yellow Army"?',
    'Chennai Super Kings',
    ['Mumbai Indians', 'Sunrisers Hyderabad', 'Rajasthan Royals']
  ),
  (
    '🏏',
    'What is the highest individual Test score (400*)? By…',
    'Brian Lara',
    ['Sachin Tendulkar', 'Matthew Hayden', 'Virender Sehwag']
  ),
  (
    '🏏',
    'In which year did India win its first T20 World Cup?',
    '2007',
    ['2011', '2014', '2003']
  ),
  (
    '🏏',
    'What does LBW stand for?',
    'Leg Before Wicket',
    ['Long Ball Wide', 'Leg Bye Wicket', 'Last Ball Wicket']
  ),
  (
    '🇮🇳',
    'What is the capital of India?',
    'New Delhi',
    ['Mumbai', 'Kolkata', 'Chennai']
  ),
  (
    '🇮🇳',
    'Which is the national animal of India?',
    'Tiger',
    ['Lion', 'Elephant', 'Peacock']
  ),
  (
    '🇮🇳',
    'Which river is the longest in India?',
    'Ganga',
    ['Yamuna', 'Godavari', 'Brahmaputra']
  ),
  (
    '🇮🇳',
    'Who wrote the Indian national anthem?',
    'Rabindranath Tagore',
    ['Bankim Chandra Chatterjee', 'Sarojini Naidu', 'Mahatma Gandhi']
  ),
  (
    '🇮🇳',
    'Which state is known as "God\'s Own Country"?',
    'Kerala',
    ['Goa', 'Karnataka', 'Assam']
  ),
  (
    '🇮🇳',
    'In which city is the Gateway of India?',
    'Mumbai',
    ['New Delhi', 'Hyderabad', 'Chennai']
  ),
  (
    '🇮🇳',
    'Which festival is called the festival of lights?',
    'Diwali',
    ['Holi', 'Eid', 'Pongal']
  ),
  (
    '🇮🇳',
    'Which Indian mission landed near the Moon\'s south pole in 2023?',
    'Chandrayaan-3',
    ['Mangalyaan', 'Chandrayaan-2', 'Gaganyaan']
  ),
  (
    '🇮🇳',
    'Who was the first Prime Minister of India?',
    'Jawaharlal Nehru',
    ['Sardar Patel', 'Mahatma Gandhi', 'Lal Bahadur Shastri']
  ),
  (
    '🇮🇳',
    'The Taj Mahal is in which city?',
    'Agra',
    ['Delhi', 'Jaipur', 'Lucknow']
  ),
  (
    '🇮🇳',
    'Which is the smallest state of India by area?',
    'Goa',
    ['Sikkim', 'Tripura', 'Mizoram']
  ),
  ('🇮🇳', 'How many states does India have?', '28', ['29', '27', '30']),
  (
    '🌍',
    'Which planet is known as the Red Planet?',
    'Mars',
    ['Venus', 'Jupiter', 'Mercury']
  ),
  (
    '🌍',
    'What is the largest ocean on Earth?',
    'Pacific',
    ['Atlantic', 'Indian', 'Arctic']
  ),
  ('🌍', 'How many continents are there?', '7', ['5', '6', '8']),
  (
    '🌍',
    'Which is the tallest mountain in the world?',
    'Mount Everest',
    ['K2', 'Kangchenjunga', 'Makalu']
  ),
  (
    '🌍',
    'Which is the fastest land animal?',
    'Cheetah',
    ['Lion', 'Horse', 'Leopard']
  ),
  (
    '🌍',
    'Which country has the largest population (2024)?',
    'India',
    ['China', 'USA', 'Indonesia']
  ),
  ('🌍', 'What is the capital of Japan?', 'Tokyo', ['Kyoto', 'Osaka', 'Seoul']),
  (
    '🌍',
    'Which is the largest desert in the world?',
    'Antarctic',
    ['Sahara', 'Gobi', 'Thar']
  ),
  (
    '🔬',
    'What gas do plants take in from the air?',
    'Carbon dioxide',
    ['Oxygen', 'Nitrogen', 'Hydrogen']
  ),
  (
    '🔬',
    'H2O is the formula for…',
    'Water',
    ['Hydrogen peroxide', 'Salt', 'Oxygen']
  ),
  (
    '🔬',
    'How many bones are in the adult human body?',
    '206',
    ['201', '212', '196']
  ),
  (
    '🔬',
    'What is the boiling point of water at sea level?',
    '100 °C',
    ['90 °C', '110 °C', '120 °C']
  ),
  (
    '🔬',
    'Which organ pumps blood around the body?',
    'Heart',
    ['Lungs', 'Liver', 'Brain']
  ),
  (
    '🔬',
    'Which planet is the largest in our solar system?',
    'Jupiter',
    ['Saturn', 'Neptune', 'Earth']
  ),
  ('🔬', 'Light travels fastest through…', 'Vacuum', ['Water', 'Glass', 'Air']),
  (
    '🔬',
    'Who proposed the theory of relativity?',
    'Albert Einstein',
    ['Isaac Newton', 'C. V. Raman', 'Galileo']
  ),
  (
    '💻',
    'Who founded Microsoft?',
    'Bill Gates',
    ['Steve Jobs', 'Elon Musk', 'Mark Zuckerberg']
  ),
  (
    '💻',
    'What does "WWW" stand for?',
    'World Wide Web',
    ['World Web Wide', 'Wide World Web', 'Web World Wide']
  ),
  (
    '💻',
    'Which company makes the iPhone?',
    'Apple',
    ['Samsung', 'Google', 'OnePlus']
  ),
  (
    '💻',
    'Which language is this app written in?',
    'Dart',
    ['Java', 'Python', 'Swift']
  ),
  (
    '😋',
    'Which state is famous for Dhokla?',
    'Gujarat',
    ['Rajasthan', 'Punjab', 'Bihar']
  ),
  (
    '😋',
    'Rasgulla is most associated with…',
    'West Bengal',
    ['Tamil Nadu', 'Punjab', 'Goa']
  ),
  (
    '😋',
    'Which spice is called "yellow gold"?',
    'Turmeric',
    ['Saffron', 'Cumin', 'Chilli']
  ),
  (
    '😋',
    'Idli and dosa are made from rice and…',
    'Urad dal',
    ['Wheat', 'Chana', 'Moong']
  ),
  (
    '⚽',
    'How many players does a football team have on the field?',
    '11',
    ['9', '10', '12']
  ),
  (
    '⚽',
    'Who has won the most Ballon d\'Or awards?',
    'Lionel Messi',
    ['Cristiano Ronaldo', 'Pelé', 'Neymar']
  ),
  (
    '🏸',
    'P. V. Sindhu plays which sport?',
    'Badminton',
    ['Tennis', 'Squash', 'Table tennis']
  ),
  (
    '🏅',
    'Neeraj Chopra won Olympic gold in…',
    'Javelin throw',
    ['Shot put', 'Long jump', 'Discus']
  ),
  (
    '♟️',
    'Viswanathan Anand is a champion of…',
    'Chess',
    ['Carrom', 'Snooker', 'Badminton']
  ),
  (
    '🎵',
    'Who is known as the "Nightingale of India" (singer)?',
    'Lata Mangeshkar',
    ['Asha Bhosle', 'Shreya Ghoshal', 'Alka Yagnik']
  ),
];

class QuizQuestion {
  final String category, text, answer;
  final List<String> options;
  const QuizQuestion(this.category, this.text, this.answer, this.options);
}

/// Everyone sees the same question. First correct answer scores; a wrong answer locks you
/// out of that question. If everyone is wrong, the next question comes. First to [target].
class QuizBattleLogic extends LocalGameLogic {
  final int target;
  final int pauseMs;
  final Random _rng;
  final List<int> score;
  late final List<int> order;
  int questionNo = 0;
  late QuizQuestion question;
  final Set<int> lockedOut = {};
  int? solvedBy;
  int _now = 0;
  int? _nextAt;

  QuizBattleLogic(
      {this.target = 7, this.pauseMs = 1500, int players = 2, Random? random})
      : _rng = random ?? Random(),
        score = List.filled(players, 0) {
    order = [for (var i = 0; i < quizBank.length; i++) i]..shuffle(_rng);
    question = make(order[0], _rng);
  }

  static QuizQuestion make(int i, Random r) {
    final (cat, text, answer, wrong) = quizBank[i];
    return QuizQuestion(cat, text, answer, [answer, ...wrong]..shuffle(r));
  }

  bool get betweenQuestions => _nextAt != null;
  @override
  List<int> get scores => score;
  @override
  bool get finished => score
      .any((s) => s >= target); // questions cycle, so someone always gets there

  @override
  void update(int elapsedMs) {
    _now = elapsedMs;
    final next = _nextAt;
    if (next != null && _now >= next && !finished) {
      _nextAt = null;
      questionNo = (questionNo + 1) % quizBank.length;
      question = make(order[questionNo], _rng);
      lockedOut.clear();
      solvedBy = null;
      notifyListeners();
    }
  }

  bool? answer(int player, String value) {
    if (forward('answer', [player, value])) return null;
    if (finished ||
        betweenQuestions ||
        lockedOut.contains(player) ||
        player < 0 ||
        player >= score.length) return null;
    if (value == question.answer) {
      score[player]++;
      solvedBy = player;
      _nextAt = _now + pauseMs;
      notifyListeners();
      return true;
    }
    lockedOut.add(player);
    if (lockedOut.length == score.length) _nextAt = _now + pauseMs;
    notifyListeners();
    return false;
  }
}

final quizBattleInfo = LocalGameInfo(
  id: 'quiz_battle',
  title: 'Quiz Battle',
  emoji: '🧠',
  color: const Color(0xFF0984E3),
  tagline: 'Bollywood, cricket & GK. Fastest wins!',
  rules: const [
    'Everyone gets the same question with four answers.',
    'Tap the right answer first to score. A wrong answer locks you out of that question.',
    'Questions on Bollywood, cricket, India, science and more. First to 7 wins. 2 to 4 players.',
  ],
  scoreUnit: 'points',
  splitScreen: true,
  maxPlayers: 4,
  bot: botFor<QuizBattleLogic>((g, b, now) {
    if (g.finished ||
        g.betweenQuestions ||
        g.solvedBy != null ||
        g.lockedOut.contains(b.seat)) return;
    // Reads the question for a few seconds, then knows the answer about two times in three.
    if (!b.thinkFirst(g.questionNo, now, 2500, 6000)) return;
    final q = g.question;
    g.answer(
        b.seat,
        b.chance(0.65)
            ? q.answer
            : b.pick(q.options.where((o) => o != q.answer).toList()));
  }),
  online: RelaySpec<QuizBattleLogic>(
    create: (n) => QuizBattleLogic(players: n),
    save: (g) => {
      'score': g.score, 'cat': g.question.category, 'q': g.question.text,
      'answer': g.question.answer, 'options': g.question.options, //
      'locked': g.lockedOut.toList(), 'solvedBy': g.solvedBy,
      'between': g.betweenQuestions, 'no': g.questionNo,
    },
    load: (g, s, me) {
      g.score.setAll(0, ints(s['score']));
      g.question = QuizQuestion(s['cat'] as String, s['q'] as String,
          s['answer'] as String, (s['options'] as List).cast<String>());
      g.lockedOut
        ..clear()
        ..addAll(ints(s['locked']));
      g.solvedBy = nInt(s['solvedBy']);
      g._nextAt = s['between'] == true ? 1 << 40 : null;
      g.questionNo = asInt(s['no']);
    },
    apply: (g, from, name, a) {
      if (name == 'answer' && asInt(a[0]) == from) g.answer(from, '${a[1]}');
    },
    view: (context, g, players, me) => Column(children: [
      ScoreMiddleBar(
          players: players, scores: g.scores, label: 'FIRST TO ${g.target}'),
      Expanded(child: _QuizHalf(player: players[me], index: me, g: g)),
    ]),
  ),
  play: (players, onFinished) => TickingPlay<QuizBattleLogic>(
    create: () => QuizBattleLogic(players: players.length),
    onFinished: onFinished,
    builder: (context, g) => MomentWatcher<int?>(
      value: g.solvedBy,
      onChange: (fx, _, who) {
        if (who == null) return;
        fx?.flash(StatusColors.success);
        fx?.pop('+1 ${players[who].name}');
      },
      child: PlayerZones(
        count: players.length,
        colors: [for (final p in players) p.color],
        middle: ScoreMiddleBar(
            players: players, scores: g.scores, label: 'First to ${g.target}'),
        center: ZoneCenterChip('First to ${g.target}'),
        zone: (i) => _QuizHalf(player: players[i], index: i, g: g),
      ),
    ),
  ),
);

/// The category chips: the logic keys categories by emoji; the UI shows a drawn icon and a word.
(GameIcons, String) _category(String key) {
  final k = key.replaceAll('\u{FE0F}', '');
  return switch (k) {
    '🎬' => (GameIcons.clapper, 'Bollywood'),
    '🏏' => (GameIcons.bat, 'Cricket'),
    '🇮🇳' => (GameIcons.flag, 'India'),
    '🌍' => (GameIcons.globe, 'World'),
    '🔬' => (GameIcons.magnifier, 'Science'),
    '💻' => (GameIcons.lightbulb, 'Tech'),
    '😋' => (GameIcons.cherry, 'Food'),
    '⚽' => (GameIcons.football, 'Football'),
    '♟' => (GameIcons.crownKing, 'Games'),
    '🎵' => (GameIcons.sound, 'Music'),
    '🏅' => (GameIcons.trophy, 'Sports'),
    '🏸' => (GameIcons.ball, 'Sports'),
    _ => (GameIcons.lightbulb, 'Quiz'),
  };
}

class _QuizHalf extends StatelessWidget {
  final GpPlayer player;
  final int index;
  final QuizBattleLogic g;
  const _QuizHalf({required this.player, required this.index, required this.g});

  @override
  Widget build(BuildContext context) {
    final locked = g.lockedOut.contains(index);
    final status = g.solvedBy == null
        ? (locked
            ? (g.betweenQuestions
                ? 'Nobody got it!'
                : 'Wrong! Wait for the next one')
            : '')
        : (g.solvedBy == index ? 'Correct! +1' : 'Too slow!');
    final (icon, label) = _category(g.question.category);
    final seat = PlayerPalette.indexOf(player.color) ?? index;
    // Small zones (3-4 players sit sideways): lay out at 270 px tall and scale down to fit.
    return LayoutBuilder(builder: (context, c) {
      const design = 270.0;
      final k = c.maxHeight < design ? design / c.maxHeight : 1.0;
      final half = _half(locked, status, icon, label, seat);
      return k == 1.0
          ? half
          : FittedBox(
              child:
                  SizedBox(width: c.maxWidth * k, height: design, child: half));
    });
  }

  Widget _half(
      bool locked, String status, GameIcons icon, String label, int seat) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(children: [
        Row(children: [
          PlayerBadge(
              index: seat, size: 22, color: player.color, initial: player.name),
          const SizedBox(width: 6),
          Flexible(
              child: Text(player.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontFamily: Fonts.body,
                      color: nameColor(player.color),
                      fontWeight: FontWeight.w900,
                      fontSize: 14))),
          const SizedBox(width: 6),
          Text('${g.score[index]}',
              style: const TextStyle(
                  fontFamily: Fonts.display,
                  color: Colors.white,
                  fontSize: 22)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(status,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontFamily: Fonts.body,
                    fontWeight: FontWeight.w900,
                    color: g.solvedBy == index
                        ? StatusColors.success
                        : (status.isEmpty
                            ? Colors.white
                            : const Color(0xFFFF8E8B)))),
          ),
        ]),
        const SizedBox(height: 4),
        // First to N: a pip per point.
        Align(
            alignment: Alignment.centerLeft,
            child: Pips(
                filled: g.score[index],
                total: g.target,
                color: player.color,
                size: 9)),
        Expanded(
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.fromLTRB(8, 3, 10, 3),
                decoration: BoxDecoration(
                    color: NeonPalette.overlay,
                    borderRadius: Radii.rChip,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  GameIcon(icon, size: 14, color: Brand.gold),
                  const SizedBox(width: 5),
                  Text(label.toUpperCase(),
                      style: const TextStyle(
                          fontFamily: Fonts.body,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                          color: Colors.white)),
                ]),
              ),
              const SizedBox(height: 6),
              Flexible(
                child: Text(g.question.text,
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: Fonts.display,
                        color: Colors.white,
                        fontSize: 20,
                        height: 1.15)),
              ),
            ]),
          ),
        ),
        Stack(alignment: Alignment.center, children: [
          Column(children: [
            for (var row = 0; row < 2; row++)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(children: [
                  for (final v in g.question.options.skip(row * 2).take(2))
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Opacity(
                          opacity: locked && !g.betweenQuestions ? 0.35 : 1,
                          child: Semantics(
                            button: true,
                            label: v,
                            excludeSemantics: true,
                            child: GestureDetector(
                              onTap: () {
                                final r = g.answer(index, v);
                                if (r != null) {
                                  haptic(r
                                      ? HapticWeight.light
                                      : HapticWeight.heavy);
                                  GameAudio.sfx(r ? 'coin' : 'lose');
                                }
                              },
                              child: Container(
                                height: 48,
                                alignment: Alignment.center,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 6),
                                decoration: BoxDecoration(
                                  color: g.solvedBy != null &&
                                          v == g.question.answer
                                      ? StatusColors.success
                                      : fillFor(player.color),
                                  borderRadius: Radii.rChip,
                                  boxShadow: Shadows.edge(
                                      Color.lerp(
                                          g.solvedBy != null &&
                                                  v == g.question.answer
                                              ? StatusColors.success
                                              : player.color,
                                          Colors.black,
                                          0.45)!,
                                      depth: 3),
                                ),
                                child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(v,
                                        style: const TextStyle(
                                            fontFamily: Fonts.body,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 15))),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ]),
              ),
          ]),
          // Locked out after a wrong answer: a lock over this player's buttons.
          if (locked && !g.betweenQuestions)
            IgnorePointer(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: NeonPalette.overlay,
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: const Color(0xFFFF8E8B), width: 2)),
                child: const GameIcon(GameIcons.lock,
                    size: 26, color: Color(0xFFFF8E8B)),
              ),
            ),
        ]),
      ]),
    );
  }
}
