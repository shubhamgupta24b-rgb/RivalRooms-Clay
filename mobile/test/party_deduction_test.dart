import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/features/local_games/charades/charades_game.dart';
import 'package:multiplayer_game/features/local_games/draw_guess/draw_guess_game.dart';
import 'package:multiplayer_game/features/local_games/find_spy/find_spy_game.dart';
import 'package:multiplayer_game/features/local_games/hand_cricket/hand_cricket_game.dart';
import 'package:multiplayer_game/features/local_games/mafia/mafia_game.dart';
import 'package:multiplayer_game/features/local_games/most_likely/most_likely_game.dart';
import 'package:multiplayer_game/features/local_games/party/party_widgets.dart';
import 'package:multiplayer_game/features/local_games/party/prompt_vote.dart';
import 'package:multiplayer_game/features/local_games/party/word_turns.dart';
import 'package:multiplayer_game/features/local_games/quiz_battle/quiz_battle_game.dart';
import 'package:multiplayer_game/features/local_games/undercover/undercover_game.dart';
import 'package:multiplayer_game/features/local_games/would_rather/would_rather_game.dart';

void main() {
  test('voteWinner: most votes, ties and no votes give -1', () {
    expect(voteWinner([1, 1, 2]), 1);
    expect(voteWinner([1, 2, null]), -1);
    expect(voteWinner([null, null]), -1);
  });

  group('Find the Spy', () {
    FindSpyLogic revealed(int seed, [int n = 4]) {
      final g = FindSpyLogic(players: n, random: Random(seed));
      for (var i = 0; i < n; i++) {
        expect(g.revealTurn, i);
        g.seenCard(i);
      }
      return g;
    }

    test('setup: one spy, a location, 8 guess options including the answer',
        () {
      final g = FindSpyLogic(players: 5, random: Random(1));
      expect(g.spy, inInclusiveRange(0, 4));
      expect(g.options, hasLength(8));
      expect(g.options, contains(g.place));
      expect(g.options.toSet(), hasLength(8));
    });

    test('everyone looks, then 3 minutes of questions, then the vote', () {
      final g = revealed(2);
      expect(g.phase, SpyPhase.discuss);
      g.update(179999);
      expect(g.phase, SpyPhase.discuss);
      g.update(180000);
      expect(g.phase, SpyPhase.vote);
    });

    test('accusing an innocent: the spy wins +2', () {
      final g = revealed(3)..startVote();
      g.accuse((g.spy + 1) % 4);
      expect(g.phase, SpyPhase.result);
      expect(g.spyWins, isTrue);
      g.finish();
      expect(g.finished, isTrue);
      expect(g.scores[g.spy], 2);
      expect(g.scores.reduce((a, b) => a + b), 2);
    });

    test(
        'spy caught: a wrong guess means everyone else +1, a right guess steals it',
        () {
      final g = revealed(4)..startVote();
      g.accuse(g.spy);
      expect(g.phase, SpyPhase.spyGuess);
      g.guess(g.options.firstWhere((o) => o != g.place));
      expect(g.spyWins, isFalse);
      expect(g.scores, [for (var i = 0; i < 4; i++) i == g.spy ? 0 : 1]);

      final h = revealed(5)..startVote();
      h.accuse(h.spy);
      h.guess(h.place);
      expect(h.spyWins, isTrue);
    });

    test('online votes: most votes accused, a tie lets the spy escape', () {
      final g = revealed(6, 3)..startVote();
      final innocent = (g.spy + 1) % 3, other = (g.spy + 2) % 3;
      g.vote(g.spy, innocent);
      g.vote(innocent, other);
      expect(g.phase, SpyPhase.vote);
      g.vote(other, innocent);
      expect(g.accused, innocent);
      expect(g.spyWins, isTrue);

      final t = revealed(7, 4)..startVote();
      t.vote(0, 1);
      t.vote(1, 0);
      t.vote(2, 3);
      t.vote(3, 2);
      expect(t.accused, -1, reason: 'tie');
      expect(t.spyWins, isTrue);
    });
  });

  group('Undercover', () {
    test(
        'one player has the other word; voting out civilians to the last two: undercover wins',
        () {
      final g = UndercoverLogic(players: 4, random: Random(1));
      final words = [for (var i = 0; i < 4; i++) g.wordFor(i)];
      expect(words.toSet(), hasLength(2));
      expect(words.where((w) => w == g.undercoverWord), hasLength(1));
      for (var i = 0; i < 4; i++) {
        g.seenCard(i);
      }
      final civilians = [
        for (var i = 0; i < 4; i++)
          if (i != g.undercover) i
      ];
      g.startVote();
      g.accuse(civilians[0]);
      expect(g.phase, UcPhase.out);
      g.nextRound();
      expect(g.round, 2);
      g.startVote();
      g.accuse(civilians[1]);
      expect(g.phase, UcPhase.result);
      expect(g.undercoverWins, isTrue);
      g.finish();
      expect(g.scores[g.undercover], 3);
    });

    test(
        'catching the undercover: +1 for everyone else; the out player cannot vote',
        () {
      final g = UndercoverLogic(players: 3, random: Random(2));
      for (var i = 0; i < 3; i++) {
        g.seenCard(i);
      }
      g.startVote();
      final civ = [
        for (var i = 0; i < 3; i++)
          if (i != g.undercover) i
      ];
      g.vote(civ[0], g.undercover);
      g.vote(civ[1], g.undercover);
      g.vote(g.undercover, civ[0]);
      expect(g.undercoverWins, isFalse);
      g.finish();
      expect(g.scores, [for (var i = 0; i < 3; i++) i == g.undercover ? 0 : 1]);
    });
  });

  group('Mafia', () {
    MafiaLogic start(int n, int seed) {
      final g = MafiaLogic(players: n, random: Random(seed));
      for (var i = 0; i < n; i++) {
        g.seenCard(i);
      }
      return g;
    }

    int roleOf(MafiaLogic g, MafiaRole r) => g.roles.indexOf(r);

    test('roles: 1 mafia (2 with six), a doctor and a detective', () {
      for (final n in [4, 5, 6]) {
        final g = MafiaLogic(players: n, random: Random(n));
        expect(g.roles.where((r) => r == MafiaRole.mafia),
            hasLength(n >= 6 ? 2 : 1));
        expect(g.roles.where((r) => r == MafiaRole.doctor), hasLength(1));
        expect(g.roles.where((r) => r == MafiaRole.detective), hasLength(1));
      }
    });

    test('night: the doctor saves the target; next night the victim dies', () {
      final g = start(5, 1);
      expect(g.phase, MafiaPhase.night);
      final mafia = roleOf(g, MafiaRole.mafia),
          doctor = roleOf(g, MafiaRole.doctor),
          det = roleOf(g, MafiaRole.detective);
      final victim = roleOf(g, MafiaRole.villager);
      g.act(mafia, mafia); // can't target mafia
      expect(g.acted, isEmpty);
      for (var p = 0; p < 5; p++) {
        if (p == mafia) g.act(p, victim);
        if (p == doctor) g.act(p, victim);
        if (p == det) g.act(p, mafia);
        if (g.roles[p] == MafiaRole.villager) g.act(p, -1);
      }
      expect(g.phase, MafiaPhase.morning);
      expect(g.saved, isTrue);
      expect(g.killed, -1);
      expect(g.detectiveCheck, mafia);

      g.startVote();
      g.accuse(-1); // nobody (ignored)
      g.accuse(victim); // an innocent voted out
      expect(g.phase, MafiaPhase.out);
      g.nextNight();
      expect(g.day, 2);
      for (final p in [...g.alive]) {
        // The doctor guards the detective, so the mafia's hit on the doctor goes through.
        g.act(
            p,
            p == mafia
                ? doctor
                : (g.roles[p] == MafiaRole.doctor
                    ? det
                    : (p == det ? mafia : -1)));
      }
      expect(g.killed, doctor);
      expect(g.alive.contains(doctor), isFalse);
    });

    test(
        'town wins when the mafia is voted out; mafia wins when it equals the rest',
        () {
      final g = start(4, 2);
      final mafia = roleOf(g, MafiaRole.mafia);
      for (final p in [...g.alive]) {
        g.act(
            p,
            g.isMafia(p)
                ? (mafia + 1) % 4
                : (g.roles[p] == MafiaRole.detective
                    ? (p + 1) % 4 == p
                        ? (p + 2) % 4
                        : (p + 1) % 4
                    : p));
      }
      if (g.phase == MafiaPhase.morning) {
        g.startVote();
        g.accuse(mafia);
      }
      expect(g.phase, MafiaPhase.result);
      expect(g.mafiaWins, isFalse);
      g.finish();
      expect(g.scores[mafia], 0);

      final m = start(4, 3);
      final boss = roleOf(m, MafiaRole.mafia);
      final town = [
        for (var i = 0; i < 4; i++)
          if (i != boss) i
      ];
      // Night 1: kill a villager-side player nobody saves.
      final doc = roleOf(m, MafiaRole.doctor);
      final t1 = town.firstWhere((i) => i != doc);
      for (final p in [...m.alive]) {
        m.act(
            p,
            p == boss
                ? t1
                : (p == doc
                    ? doc
                    : (m.roles[p] == MafiaRole.detective ? boss : -1)));
      }
      m.startVote();
      m.accuse(
          m.alive.firstWhere((i) => i != boss)); // town votes out an innocent
      expect(m.phase, MafiaPhase.result);
      expect(m.mafiaWins, isTrue);
      m.finish();
      expect(m.scores[boss], 2);
    });
  });

  group('Word turns (Charades, Heads Up)', () {
    test(
        'timed turns: GOT IT scores the performer, SKIP moves on, time up ends the turn',
        () {
      final g = WordTurnsLogic(
          players: 2,
          words: charadesMovies,
          turnsEach: 1,
          turnMs: 1000,
          random: Random(1));
      final first = g.current;
      g.gotIt();
      expect(g.score, [0, 0], reason: 'not started');
      g.start();
      g.gotIt();
      expect(g.current, isNot(first));
      g.skip();
      g.gotIt();
      expect(g.score, [2, 0]);
      g.update(999);
      expect(g.phase, TurnPhase.playing);
      g.update(1000);
      expect(g.phase, TurnPhase.turnEnd);
      g.gotIt();
      expect(g.score[0], 2, reason: 'too late');
      g.next();
      expect(g.performer, 1);
      g.update(1100);
      g.start();
      g.gotIt();
      g.update(2200);
      g.next();
      expect(g.finished, isTrue);
      expect(g.scores, [2, 1]);
    });
  });

  group('Draw & Guess', () {
    test(
        'drawing, typed guesses (wrong ones listed, right one scores both), turns end',
        () {
      final g = DrawGuessLogic(players: 3, random: Random(1));
      expect(g.turnsEach, 2);
      g.start();
      g.addPoint(0.1, 0.1, newStroke: true);
      g.addPoint(0.5, 0.5);
      g.addPoint(2, -1); // clamped
      expect(g.strokes.single, [0.1, 0.1, 0.5, 0.5, 1.0, 0.0]);
      g.inkBatch(true, '0.200,0.300;0.400,0.500');
      expect(g.strokes, hasLength(2));
      g.guess(1, 'definitely wrong');
      expect(g.wrongGuesses, ['definitely wrong']);
      g.guess(0, g.word); // the artist can't guess
      expect(g.phase, DrawPhase.drawing);
      g.guess(2, '  ${g.word.toUpperCase()}! ');
      expect(g.phase, DrawPhase.turnEnd);
      expect(g.guessedBy, 2);
      expect(g.score, [1, 0, 1]);
      g.next();
      expect(g.drawer, 1);
      g.start();
      expect(g.strokes, isEmpty);
      g.update(DrawGuessLogic.turnMs + 1);
      expect(g.phase, DrawPhase.turnEnd);
    });
  });

  group('Most Likely To / Would You Rather', () {
    test('most likely: the most-voted (all of them on a tie) get a point', () {
      final g = PromptVoteLogic(
          mode: VoteMode.mostLikely,
          players: 3,
          prompts: mostLikelyPrompts,
          rounds: 2,
          random: Random(1));
      g.vote(0, 2);
      g.vote(1, 2);
      g.vote(2, 0);
      expect(g.phase, PromptPhase.reveal);
      expect(g.lastWinners, [2]);
      g.next();
      g.vote(0, 1);
      g.vote(1, 0);
      g.vote(2, 2);
      expect(g.lastWinners, [0, 1, 2], reason: 'three-way tie');
      g.next();
      expect(g.finished, isTrue);
      expect(g.scores, [1, 1, 2]);
    });

    test('would you rather: the majority scores, a split scores nobody', () {
      final g = PromptVoteLogic(
          mode: VoteMode.wouldRather,
          players: 4,
          prompts: wouldRatherPrompts,
          rounds: 2,
          random: Random(2));
      expect(g.prompt.split('|'), hasLength(2));
      g.vote(0, 0);
      g.vote(1, 0);
      g.vote(2, 1);
      g.vote(3, 5); // invalid option ignored
      expect(g.phase, PromptPhase.vote);
      g.vote(3, 0);
      expect(g.score, [1, 1, 0, 1]);
      g.next();
      g.vote(0, 0);
      g.vote(1, 1);
      g.vote(2, 0);
      g.vote(3, 1);
      expect(g.lastWinners, isEmpty);
      expect(g.score, [1, 1, 0, 1]);
    });
  });

  group('Hand Cricket', () {
    test('runs unless the numbers match; innings swap; the chase', () {
      final g = HandCricketLogic(showMs: 10);
      g.pick(0, 4);
      g.pick(1, 2);
      expect(g.runs, [4, 0]);
      g.pick(0, 6);
      expect(g.picks[0], 4,
          reason: 'still showing the last ball: no new pick yet');
      g.update(20);
      g.pick(0, 6);
      g.pick(1, 3);
      g.update(40);
      g.pick(0, 5);
      g.pick(1, 5); // OUT
      expect(g.runs, [10, 0]);
      g.update(60);
      expect(g.innings, 1);
      expect(g.target, 11);
      for (final (bat, bowl) in [(6, 1), (5, 2)]) {
        g.pick(1, bat);
        g.pick(0, bowl);
        g.update(g.balls[1].length * 100 + 100);
      }
      expect(g.runs, [10, 11]);
      expect(g.finished, isTrue);
      expect(g.scores, [10, 11]);
    });
  });

  group('Quiz Battle', () {
    test(
        'bank is well formed; first right answer scores; wrong answers lock you out',
        () {
      for (final (_, q, a, wrong) in quizBank) {
        expect(q, isNotEmpty);
        expect(wrong, hasLength(3));
        expect(wrong, isNot(contains(a)));
      }
      final g = QuizBattleLogic(players: 2, pauseMs: 10, random: Random(1));
      expect(g.question.options, contains(g.question.answer));
      final wrong =
          g.question.options.firstWhere((o) => o != g.question.answer);
      expect(g.answer(0, wrong), isFalse);
      expect(g.answer(0, g.question.answer), isNull, reason: 'locked out');
      expect(g.answer(1, g.question.answer), isTrue);
      expect(g.scores, [0, 1]);
      final before = g.question.text;
      g.update(20);
      expect(g.question.text, isNot(before));
    });
  });
}
