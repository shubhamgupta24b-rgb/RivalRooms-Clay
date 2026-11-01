import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/features/guess_person/logic/gp_settings.dart';
import 'package:multiplayer_game/features/guess_person/logic/guess_person_controller.dart';
import 'package:multiplayer_game/features/guess_person/models/gp_player.dart';
import 'package:multiplayer_game/features/local_games/air_hockey/air_hockey_game.dart';
import 'package:multiplayer_game/features/local_games/basketball/basketball_game.dart';
import 'package:multiplayer_game/features/local_games/connect_four/connect_four_game.dart';
import 'package:multiplayer_game/features/local_games/crush_it/crush_it_game.dart';
import 'package:multiplayer_game/features/local_games/fruit_duel/fruit_duel_game.dart';
import 'package:multiplayer_game/features/local_games/local_games_hub_screen.dart';
import 'package:multiplayer_game/features/local_games/math_duel/math_duel_game.dart';
import 'package:multiplayer_game/features/local_games/memory/memory_game.dart';
import 'package:multiplayer_game/features/local_games/penalty/penalty_game.dart';
import 'package:multiplayer_game/features/local_games/ping_pong/ping_pong_game.dart';
import 'package:multiplayer_game/features/local_games/reaction_tap/reaction_tap_game.dart';
import 'package:multiplayer_game/features/local_games/shell/split_screen.dart';
import 'package:multiplayer_game/features/local_games/snake_duel/snake_duel_game.dart';

void main() {
  test(
      '70 shell entries, 71 visible hub games, unique ids, 1-6 local seats',
      () {
    expect(localGames, hasLength(70));
    expect(localGames.map((g) => g.id).toSet(), hasLength(70));
    expect(localGames.where((g) => g.solo), hasLength(20));
    expect(localGames.where((g) => !g.remoteOnly), hasLength(69));
    expect(totalGameCount, 71);
    for (final g in localGames) {
      expect(g.maxPlayers, inInclusiveRange(1, 6), reason: g.id);
    }
    expect(
        localGames.map((g) => g.id),
        isNot(containsAll([
          'crush_it',
          'fruit_duel',
          'snake_duel',
          'penalty',
          'classic_snake'
        ])));
    expect({for (final g in localGames) g.id: g.maxPlayers},
        containsPair('colour_clash', 2));
    expect(defaultPlayers(6).map((p) => p.color).toSet(), hasLength(6),
        reason: 'six distinct colours');
  });

  test('3-6 player layouts put half the players on each long side', () {
    expect(
        [for (var n = 3; n <= 6; n++) PlayerZones.leftCount(n)], [2, 2, 3, 3]);
  });

  group('Reaction Tap', () {
    test(
        'green-light tap scores; early tap costs a point (not below 0); works for 3 players',
        () {
      final g = ReactionTapLogic(players: 3, random: Random(1));
      g.update(100);
      expect(g.phase, ReactionPhase.wait);
      expect(g.tap(0), isTrue);
      expect(g.falseStart, isTrue);
      expect(g.scores, [0, 0, 0], reason: 'never below zero');
      expect(g.tap(1), isFalse,
          reason: 'taps ignored while showing the result');
      g.update(100 + g.resultMs);
      expect(g.phase, ReactionPhase.wait);
      final go = g.goAt;
      g.update(go + 5);
      expect(g.phase, ReactionPhase.go);
      g.update(go + 250);
      expect(g.tap(2), isTrue);
      expect(g.scores, [0, 0, 1]);
      expect(g.reactionMs, 250);
      // An early tap now takes the point back off player 3.
      g.update(go + 250 + g.resultMs);
      g.tap(2);
      expect(g.scores, [0, 0, 0]);
    });

    test('first to the target wins', () {
      final g = ReactionTapLogic(target: 2, random: Random(2));
      var t = 0;
      while (!g.finished) {
        t = g.goAt + 1;
        g.update(t);
        g.tap(1);
        t += g.resultMs;
        g.update(t);
      }
      expect(g.scores, [0, 2]);
    });
  });

  group('Math Duel', () {
    test('questions always offer 4 different answers including the right one',
        () {
      final r = Random(3);
      for (var level = 0; level < 6; level++) {
        for (var i = 0; i < 50; i++) {
          final q = MathDuelLogic.makeQuestion(r, level);
          expect(q.options, contains(q.answer));
          expect(q.options.toSet(), hasLength(4));
          expect(q.options.every((o) => o >= 0), isTrue);
        }
      }
    });

    test(
        'first right answer scores; wrong locks you out; all wrong moves on (4 players)',
        () {
      final g = MathDuelLogic(players: 4, random: Random(4), pauseMs: 500);
      final wrong =
          g.question.options.firstWhere((o) => o != g.question.answer);
      for (var p = 0; p < 3; p++) {
        expect(g.answer(p, wrong), isFalse);
        expect(g.answer(p, g.question.answer), isNull, reason: 'locked out');
      }
      expect(g.betweenQuestions, isFalse);
      expect(g.answer(3, wrong), isFalse);
      expect(g.betweenQuestions, isTrue, reason: 'all four were wrong');
      g.update(500);
      expect(g.lockedOut, isEmpty);
      expect(g.answer(2, g.question.answer), isTrue);
      expect(g.scores, [0, 0, 1, 0]);
      expect(g.answer(0, g.question.answer), isNull, reason: 'already solved');
    });
  });

  group('Connect Four', () {
    test('discs stack, full columns refuse, players alternate', () {
      final g = ConnectFourLogic();
      expect(g.drop(3), 5);
      expect(g.drop(3), 4);
      expect(g.at(3, 5), 0);
      expect(g.at(3, 4), 1);
      for (var i = 0; i < 4; i++) {
        g.drop(3);
      }
      expect(g.drop(3), isNull);
      expect(g.drop(-1), isNull);
      expect(g.drop(7), isNull);
    });

    test('wins across, down and both diagonals', () {
      // Across: X on 0,1,2,3 (O stacks on top of them).
      var g = ConnectFourLogic();
      for (final c in [0, 0, 1, 1, 2, 2, 3]) {
        g.drop(c);
      }
      expect(g.winner, 0);
      expect(g.winCells, hasLength(4));
      // Down.
      g = ConnectFourLogic();
      for (final c in [0, 1, 0, 1, 0, 1, 0]) {
        g.drop(c);
      }
      expect(g.winner, 0);
      // Diagonal up-right.
      g = ConnectFourLogic();
      for (final c in [0, 1, 1, 2, 2, 3, 2, 3, 3, 6, 3]) {
        g.drop(c);
      }
      expect(g.winner, 0);
      // Diagonal down-right, won by O.
      g = ConnectFourLogic(starter: 1);
      for (final c in [3, 2, 2, 1, 1, 0, 1, 0, 0, 6, 0]) {
        g.drop(c);
      }
      expect(g.winner, 1);
      expect(g.drop(5), isNull, reason: 'game over');
      expect(g.scores, [0, 1]);
    });
  });

  group('Penalty Shootout', () {
    test(
        'different side = goal, same side = save, roles alternate, picks are one-shot',
        () {
      final g = PenaltyLogic(showMs: 100);
      expect(g.kicker, 0);
      expect(g.pick(0, 0), isTrue);
      expect(g.pick(0, 1), isFalse, reason: 'already picked');
      expect(g.pick(1, 2), isTrue); // keeper dives the other way
      expect(g.lastKick!.goal, isTrue);
      expect(g.scores, [1, 0]);
      expect(g.pick(0, 1), isFalse, reason: 'showing the result');
      g.update(100);
      expect(g.kicker, 1);
      g.pick(1, 1);
      g.pick(0, 1); // same side: saved
      expect(g.lastKick!.goal, isFalse);
      expect(g.scores, [1, 0]);
      expect(g.pick(0, 3), isFalse);
    });

    test('ends early once the other side cannot catch up', () {
      final g = PenaltyLogic(showMs: 0);
      var t = 0;
      void kick(bool goal) {
        g.pick(g.kicker, 0);
        g.pick(g.keeper, goal ? 1 : 0);
        g.update(t += 1);
      }

      for (var i = 0; i < 3; i++) {
        kick(true); // player 1 scores
        kick(false); // player 2 misses
      }
      expect(g.scores, [3, 0]);
      expect(g.finished, isTrue, reason: 'player 2 can reach at most 2');
    });

    test('sudden death after 5 each', () {
      final g = PenaltyLogic(showMs: 0);
      var t = 0;
      for (var i = 0; i < 10; i++) {
        g.pick(g.kicker, 0);
        g.pick(g.keeper, 1);
        g.update(t += 1);
      }
      expect(g.scores, [5, 5]);
      expect(g.finished, isFalse);
      g.pick(g.kicker, 0);
      g.pick(g.keeper, 2); // player 1 scores
      g.update(t += 1);
      g.pick(g.kicker, 0);
      g.pick(g.keeper, 0); // player 2 saved
      g.update(t += 1);
      expect(g.finished, isTrue);
      expect(g.scores, [6, 5]);
    });
  });

  group('Snake Duel', () {
    test('both hitting the wall on the same step is a tie', () {
      final g = SnakeDuelLogic(cols: 10, rows: 10, stepMs: 100, pauseMs: 300);
      var t = 0;
      while (g.roundWinner == null) {
        g.update(t += 50);
      }
      expect(g.roundWinner, -1);
      expect(g.scores, [0, 0]);
      g.update(t + 300);
      expect(g.round, 1, reason: 'next round started');
      expect(g.roundWinner, isNull);
    });

    test('turning steers relative to the heading; crashing first loses', () {
      final g = SnakeDuelLogic(cols: 10, rows: 10, stepMs: 100);
      g.turn(0,
          1); // player 1 turns right, away from player 2's path, and hits the wall first
      var t = 0;
      while (g.roundWinner == null) {
        g.update(t += 50);
      }
      expect(g.dir[0], 1, reason: 'up + right turn = heading right');
      expect(g.roundWinner, 1);
      expect(g.scores, [0, 1]);
    });

    test(
        'crashing into a trail ends the round and the match ends at the target',
        () {
      final g = SnakeDuelLogic(
          cols: 10, rows: 10, stepMs: 100, pauseMs: 100, target: 2);
      var t = 0;
      for (var round = 0; round < 2; round++) {
        g.turn(1,
            1); // player 2 (heading down) turns right = screen left, hits the wall first
        while (g.roundWinner == null) {
          g.update(t += 50);
        }
        expect(g.roundWinner, 0);
        g.update(t += 100);
      }
      expect(g.finished, isTrue);
      expect(g.scores, [2, 0]);
    });
  });

  group('Air Hockey', () {
    test('puck into the top goal scores for player 1 and pauses', () {
      final g = AirHockeyLogic();
      g.puck = const V(0.5, 0.06);
      g.vel = const V(0, -2);
      for (var t = 16; t <= 160 && g.goals[0] == 0; t += 16) {
        g.update(t);
      }
      expect(g.goals, [1, 0]);
      expect(g.paused, isTrue);
    });

    test('puck bounces off walls outside the goal mouth', () {
      final g = AirHockeyLogic();
      g.puck = const V(0.06, 0.8);
      g.vel = const V(-1.5, 0);
      for (var t = 16; t <= 96; t += 16) {
        g.update(t);
      }
      expect(g.vel.x, greaterThan(0));
      g.puck = const V(0.1, 0.06); // beside the goal, not in it
      g.vel = const V(0, -1.5);
      for (var t = 112; t <= 200; t += 16) {
        g.update(t);
      }
      expect(g.goals, [0, 0]);
      expect(g.vel.y, greaterThan(0));
    });

    test('mallets stay in their own half and knock the puck away', () {
      final g = AirHockeyLogic();
      g.moveMallet(0, const V(0.5, 0.1));
      expect(g.mallet[0].y, greaterThanOrEqualTo(AirHockeyLogic.length / 2));
      g.moveMallet(1, const V(-1, 99));
      expect(g.mallet[1].y, lessThanOrEqualTo(AirHockeyLogic.length / 2));
      expect(g.mallet[1].x, greaterThan(0));

      g.moveMallet(0, const V(0.5, 1.25));
      g.puck = const V(0.5, 1.12);
      g.vel = const V(0, 1);
      for (var t = 16; t <= 96; t += 16) {
        g.update(t);
      }
      expect(g.vel.y, lessThan(0), reason: 'bounced back up the table');
    });

    test('first to 5 ends the game', () {
      final g = AirHockeyLogic(target: 2);
      g.goals[1] = 2;
      expect(g.finished, isTrue);
      expect(g.scores, [0, 2]);
    });
  });

  group('Ping Pong', () {
    test(
        'serves after a pause, paddles return the ball faster, misses score for the other side',
        () {
      final g = PingPongLogic(random: Random(5));
      g.update(500);
      expect(g.waitingToServe, isTrue);
      g.update(950);
      expect(g.waitingToServe, isFalse);
      // Steer the ball at player 1's paddle.
      g.ball = V(g.paddleX[0], PingPongLogic.paddleLine(0) - 0.05);
      g.vel = const V(0, 1);
      final before = g.speed;
      for (var t = 966; t <= 1100; t += 16) {
        g.update(t);
      }
      expect(g.vel.y, lessThan(0));
      expect(g.speed, greaterThan(before));

      // Now let it past player 2's paddle.
      g.movePaddle(1, 0.9);
      g.ball = const V(0.2, 0.2);
      g.vel = const V(0, -1.5);
      for (var t = 1116; t <= 1500 && g.points[0] == 0; t += 16) {
        g.update(t);
      }
      expect(g.points, [1, 0]);
      expect(g.waitingToServe, isTrue);
    });

    test('paddles stay on the table', () {
      final g = PingPongLogic();
      g.movePaddle(0, -5);
      g.movePaddle(1, 5);
      expect(g.paddleX[0], PingPongLogic.paddleHalf);
      expect(g.paddleX[1], 1 - PingPongLogic.paddleHalf);
    });
  });

  group('more than 2 players', () {
    test('Crush It counts 5 players separately', () {
      final g = CrushItLogic(players: 5);
      g.update(10);
      for (var p = 0; p < 5; p++) {
        for (var i = 0; i <= p; i++) {
          g.tap(p);
        }
      }
      expect(g.scores, [1, 2, 3, 4, 5]);
    });

    test('Fruit Duel with 4: first correct +2, everyone else correct +1', () {
      final g = FruitDuelLogic(players: 4, random: Random(6));
      g.update(10);
      final lane = g.fruitLane;
      expect(g.slash(2, lane), 2);
      expect(g.slash(0, lane), 1);
      expect(g.slash(3, lane), 1);
      expect(g.slash(1, (lane + 1) % 3), 0);
      expect(g.scores, [1, 0, 2, 1]);
    });

    test('Memory with 3: a miss passes the turn round the table', () {
      final g = MemoryLogic(players: 3, random: Random(7), mismatchMs: 10);
      var t = 0;
      for (final expected in [1, 2, 0]) {
        final a = g.cards.firstWhere((c) => !c.matched);
        final b = g.cards.firstWhere((c) => !c.matched && c.symbol != a.symbol);
        g.flip(a.id);
        g.flip(b.id);
        g.update(t += 10);
        expect(g.turn, expected);
      }
    });

    test('Basketball with 4: everyone shoots at the same hoop', () {
      final g = BasketballLogic(players: 4);
      g.update(2000);
      expect(g.shoot(3, 0), 3);
      expect(g.shoot(1, 1), 0);
      expect(g.shots, [0, 1, 0, 1]);
      expect(g.scores, [0, 0, 0, 3]);
    });

    test('Guess the Person with 3 players rotates chooser and guesser', () {
      final c = GuessPersonController(
          settings: const GpSettings(rounds: 3, playerCount: 3),
          players: defaultPlayers(3));
      c.startGame();
      final roles = <(int, int)>[];
      for (var r = 0; r < 3; r++) {
        roles.add((c.chooserIndex, c.guesserIndex));
        c.beginSelection();
        c.selectSecretPerson(c.people.first.id);
        c.requestConfirm();
        c.confirmSecretPerson();
        c.switchToGuessing();
        c.startFinalGuess();
        c.chooseGuess(c.people.first.id);
        c.makeFinalGuess();
        c.nextRound();
      }
      expect(roles, [(0, 1), (1, 2), (2, 0)]);
      expect(c.players.map((p) => p.score).toList(), [1, 1, 1],
          reason: 'each guesser was right once');
      expect(c.phase, GpPhase.gameOver);
      expect(c.isDraw, isTrue);
      c.dispose();
    });
  });
}
