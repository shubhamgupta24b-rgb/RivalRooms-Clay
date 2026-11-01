import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/audio/game_audio.dart';
import '../../../core/settings/app_settings.dart';
import '../../guess_person/models/gp_player.dart';
import '../../../core/ui/components.dart';
import '../shell/game_hud.dart' show MomentWatcher;
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/split_screen.dart';
import '../shell/ticking_play.dart';

class MathQuestion {
  final String text;
  final int answer;
  final List<int> options; // 4 choices, one of them correct
  const MathQuestion(this.text, this.answer, this.options);
}

/// Both players see the same sum. First correct answer scores; a wrong answer locks
/// you out of that question. If both are wrong, a new sum comes up. First to [target].
class MathDuelLogic extends LocalGameLogic {
  final int target;
  final int pauseMs;
  final Random _rng;
  final List<int> score;
  late MathQuestion question;
  final Set<int> lockedOut = {};
  int? solvedBy;
  int _now = 0;
  int? _nextAt;
  int questionNo = 0;

  MathDuelLogic({
    this.target = 7,
    this.pauseMs = 1000,
    int players = 2,
    Random? random,
  }) : _rng = random ?? Random(),
       score = List.filled(players, 0) {
    question = makeQuestion(_rng);
  }

  /// Sums get a little harder as the game goes on.
  static MathQuestion makeQuestion(Random r, [int level = 0]) {
    final op = r.nextInt(level < 3 ? 2 : 3); // + and - first, then × too
    late int a, b, ans;
    late String sym;
    switch (op) {
      case 0:
        a = 2 + r.nextInt(20 + level * 5);
        b = 2 + r.nextInt(20 + level * 5);
        ans = a + b;
        sym = '+';
      case 1:
        a = 10 + r.nextInt(30 + level * 5);
        b = 1 + r.nextInt(a - 1);
        ans = a - b;
        sym = '−';
      default:
        a = 2 + r.nextInt(10);
        b = 2 + r.nextInt(10);
        ans = a * b;
        sym = '×';
    }
    final opts = <int>{ans};
    while (opts.length < 4) {
      final d = 1 + r.nextInt(10);
      final wrong = r.nextBool() ? ans + d : ans - d;
      if (wrong >= 0) opts.add(wrong);
    }
    return MathQuestion('$a $sym $b', ans, opts.toList()..shuffle(r));
  }

  @override
  List<int> get scores => score;
  @override
  bool get finished => score.any((s) => s >= target);
  bool get betweenQuestions => _nextAt != null;

  @override
  void update(int elapsedMs) {
    _now = elapsedMs;
    final next = _nextAt;
    if (next != null && _now >= next && !finished) {
      _nextAt = null;
      questionNo++;
      question = makeQuestion(_rng, questionNo ~/ 3);
      lockedOut.clear();
      solvedBy = null;
      notifyListeners();
    }
  }

  /// Returns true for a correct answer, false for a wrong one, null if the tap didn't count.
  bool? answer(int player, int value) {
    if (forward('answer', [player, value])) return null;
    if (finished || betweenQuestions || lockedOut.contains(player)) return null;
    if (value == question.answer) {
      score[player]++;
      solvedBy = player;
      _nextAt = _now + pauseMs;
      notifyListeners();
      return true;
    }
    lockedOut.add(player);
    if (lockedOut.length == score.length)
      _nextAt = _now + pauseMs; // nobody got it
    notifyListeners();
    return false;
  }
}

final mathDuelInfo = LocalGameInfo(
  id: 'math_duel',
  title: 'Math Duel',
  emoji: '🧮',
  color: const Color(0xFF6C5CE7),
  tagline: 'Quick maths, quicker fingers!',
  rules: const [
    'Both of you get the same sum.',
    'Tap the right answer first to score. A wrong answer locks you out of that sum.',
    'Sums get harder as you go. First to 7 wins. 2 to 4 players.',
  ],
  scoreUnit: 'points',
  splitScreen: true,
  maxPlayers: 4,
  bot: botFor<MathDuelLogic>((g, b, now) {
    if (g.finished ||
        g.betweenQuestions ||
        g.solvedBy != null ||
        g.lockedOut.contains(b.seat))
      return;
    if (!b.thinkFirst(g.questionNo, now, 1800, 4500)) return;
    final q = g.question;
    g.answer(
      b.seat,
      b.chance(0.75)
          ? q.answer
          : b.pick(q.options.where((o) => o != q.answer).toList()),
    );
  }),
  online: RelaySpec<MathDuelLogic>(
    create: (n) => MathDuelLogic(players: n),
    save: (g) => {
      'score': g.score,
      'q': g.question.text,
      'answer': g.question.answer,
      'options': g.question.options,
      'locked': g.lockedOut.toList(),
      'solvedBy': g.solvedBy,
      'between': g.betweenQuestions,
      'no': g.questionNo,
    },
    load: (g, s, me) {
      g.score.setAll(0, ints(s['score']));
      g.question = MathQuestion(
        s['q'] as String,
        asInt(s['answer']),
        ints(s['options']),
      );
      g.lockedOut
        ..clear()
        ..addAll(ints(s['locked']));
      g.solvedBy = nInt(s['solvedBy']);
      g._nextAt = s['between'] == true ? 1 << 40 : null;
      g.questionNo = asInt(s['no']);
    },
    apply: (g, from, name, a) {
      if (name == 'answer' && asInt(a[0]) == from) g.answer(from, asInt(a[1]));
    },
    view: (context, g, players, me) => Column(
      children: [
        ScoreMiddleBar(
          players: players,
          scores: g.scores,
          label: 'First to ${g.target}',
        ),
        Expanded(
          child: _MathHalf(player: players[me], index: me, g: g),
        ),
      ],
    ),
  ),
  play: (players, onFinished) => TickingPlay<MathDuelLogic>(
    create: () => MathDuelLogic(players: players.length),
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
          players: players,
          scores: g.scores,
          label: 'First to ${g.target}',
        ),
        center: ZoneCenterChip('First to ${g.target}'),
        zone: (i) => _MathHalf(player: players[i], index: i, g: g),
      ),
    ),
  ),
);

class _MathHalf extends StatelessWidget {
  final GpPlayer player;
  final int index;
  final MathDuelLogic g;
  const _MathHalf({required this.player, required this.index, required this.g});

  @override
  Widget build(BuildContext context) {
    final locked = g.lockedOut.contains(index);
    final revealed = g.betweenQuestions;
    final won = g.solvedBy == index;
    final enabled = !locked && !revealed && !g.finished;
    final status = won
        ? 'Correct! +1'
        : (revealed
              ? (g.solvedBy == null
                    ? 'No correct answers • next sum soon'
                    : 'Point to another player • next sum soon')
              : (locked
                    ? 'Wrong • locked until the next sum'
                    : 'Choose the answer • first correct scores'));
    final statusColor = won
        ? const Color(0xFF93F1C4)
        : (locked ? const Color(0xFFFFB5AB) : const Color(0xFFF6EDCF));

    Widget answers(bool grid) {
      Widget tile(int option) {
        final value = g.question.options[option];
        return _AnswerButton(
          key: ValueKey('math-answer-$index-$option'),
          value: value,
          letter: String.fromCharCode(65 + option),
          correct: revealed && value == g.question.answer,
          enabled: enabled,
          color: player.color,
          onTap: () => g.answer(index, value),
        );
      }

      if (!grid) {
        return Row(
          children: [
            for (var i = 0; i < 4; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: tile(i)),
            ],
          ],
        );
      }
      return Column(
        children: [
          for (var row = 0; row < 2; row++) ...[
            if (row > 0) const SizedBox(height: 8),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: tile(row * 2)),
                  const SizedBox(width: 8),
                  Expanded(child: tile(row * 2 + 1)),
                ],
              ),
            ),
          ],
        ],
      );
    }

    // Confirmed score/lock changes also arrive through relay state. Do not
    // celebrate a forwarded answer before the host has accepted it.
    return MomentWatcher<(int, bool)>(
      value: (g.score[index], locked),
      onChange: (_, before, now) {
        final correct = now.$1 > before.$1;
        final wrong = now.$2 && !before.$2;
        if (!correct && !wrong) return;
        GameAudio.sfx(correct ? 'coin' : 'hit');
        if (AppSettings.haptics.value) {
          (correct
                  ? HapticFeedback.lightImpact()
                  : HapticFeedback.heavyImpact())
              .ignore();
        }
      },
      child: LayoutBuilder(
        builder: (context, c) {
          final compact = c.maxHeight < 220;
          final shortSeat = c.maxHeight < 190;
          final shortWide = shortSeat && c.maxWidth >= 400;
          final grid =
              c.maxWidth < 250 || (c.maxHeight >= 290 && c.maxWidth < 600);
          final largeText = MediaQuery.textScalerOf(context).scale(14) > 18;
          final header = SizedBox(
            height: 24,
            child: Row(
              children: [
                PlayerBadge(
                  index: PlayerPalette.indexOf(player.color) ?? index,
                  size: 20,
                  color: player.color,
                  initial: player.name,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    player.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: Fonts.body,
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                SizedBox(
                  width: 54,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${g.score[index]} / ${g.target}',
                      style: const TextStyle(
                        fontFamily: Fonts.display,
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
          final feedback = SizedBox(
            height: compact ? 30 : (largeText ? 42 : 36),
            child: Semantics(
              liveRegion: true,
              child: Row(
                children: [
                  Icon(
                    won
                        ? Icons.check_circle_rounded
                        : (locked ? Icons.lock_rounded : Icons.edit_rounded),
                    size: 16,
                    color: statusColor,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      status,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: Fonts.body,
                        color: statusColor,
                        fontSize: compact ? 11 : 12,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
          final board = _MathBoard(
            key: ValueKey('math-board-$index'),
            g: g,
            compact: compact,
            revealed: revealed,
          );
          // Keep the equation beside the controls in short seats, rather than
          // squeezing it to a sliver above them. Touch targets are never scaled.
          final content = shortWide
              ? Row(
                  children: [
                    Expanded(flex: 2, child: board),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                          header,
                          Expanded(child: feedback),
                          SizedBox(height: 48, child: answers(false)),
                        ],
                      ),
                    ),
                  ],
                )
              : shortSeat
              ? Column(
                  children: [
                    header,
                    const SizedBox(height: 4),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                Expanded(child: board),
                                feedback,
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: answers(true)),
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    header,
                    const SizedBox(height: 6),
                    Expanded(child: board),
                    feedback,
                    SizedBox(
                      height: grid
                          ? (c.maxHeight >= 400 ? 148 : 104)
                          : (largeText && !compact ? 56 : 48),
                      child: answers(grid),
                    ),
                  ],
                );
          return Padding(
            padding: EdgeInsets.all(shortSeat ? 4 : (compact ? 6 : 10)),
            child: DecoratedBox(
              decoration: Skin.surface(
                tint: const Color(0xFFC49364),
                radius: 22,
              ),
              child: Padding(
                padding: EdgeInsets.all(shortSeat ? 6 : (compact ? 8 : 12)),
                child: content,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MathBoard extends StatelessWidget {
  final MathDuelLogic g;
  final bool compact, revealed;
  const _MathBoard({
    super.key,
    required this.g,
    required this.compact,
    required this.revealed,
  });

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: const Color(0xFF193E36),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFD6AB79), width: 3),
      boxShadow: const [BoxShadow(color: Colors.black26, offset: Offset(0, 3))],
    ),
    child: CustomPaint(
      painter: const _ChalkboardPainter(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          children: [
            if (!compact)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'QUICK MATHS / SUM ${g.questionNo + 1}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: Fonts.body,
                    color: Color(0xFFD3E7D8),
                    fontSize: 10,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            Expanded(
              child: Center(
                child: AnimatedSwitcher(
                  duration: Motion.of(context, Motion.fast),
                  child: FittedBox(
                    key: ValueKey((g.questionNo, revealed)),
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${g.question.text} = ${revealed ? g.question.answer : '?'}',
                      style: const TextStyle(
                        fontFamily: Fonts.display,
                        color: Color(0xFFFFFAE7),
                        fontSize: 48,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AnswerButton extends StatelessWidget {
  final int value;
  final String letter;
  final Color color;
  final bool correct, enabled;
  final VoidCallback onTap;
  const _AnswerButton({
    super.key,
    required this.value,
    required this.letter,
    required this.color,
    required this.correct,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fill = correct ? const Color(0xFF9CE9BD) : const Color(0xFFFFE9B9);
    const ink = Color(0xFF253B36);
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Answer $letter: $value${correct ? ', correct answer' : ''}',
      excludeSemantics: true,
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.fast),
        width: double.infinity,
        height: double.infinity,
        decoration: Skin.primary(
          color: !enabled && !correct ? const Color(0xFFC1C4B6) : fill,
          pressed: !enabled,
          radius: 14,
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onTap : null,
            enableFeedback: false,
            splashFactory: Motion.reduced(context)
                ? NoSplash.splashFactory
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Text(
                    correct ? '✓' : letter,
                    style: TextStyle(
                      fontFamily: Fonts.body,
                      color: correct ? ink : Color.lerp(color, ink, 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '$value',
                          style: const TextStyle(
                            fontFamily: Fonts.display,
                            color: ink,
                            fontSize: 30,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChalkboardPainter extends CustomPainter {
  const _ChalkboardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.045)
      ..strokeWidth = 1;
    for (var y = 24.0; y < size.height - 8; y += 24) {
      canvas.drawLine(Offset(8, y), Offset(size.width - 8, y), paint);
    }
    paint
      ..color = const Color(0xFFEDE6CC)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width - 40, size.height - 7),
      Offset(size.width - 22, size.height - 7),
      paint,
    );
    paint.color = const Color(0xFFE9BC85);
    canvas.drawLine(
      Offset(size.width - 15, size.height - 7),
      Offset(size.width - 9, size.height - 7),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ChalkboardPainter oldDelegate) => false;
}
