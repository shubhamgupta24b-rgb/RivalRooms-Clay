import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/features/local_games/basketball/basketball_game.dart';
import 'package:multiplayer_game/features/local_games/crush_it/crush_it_game.dart';
import 'package:multiplayer_game/features/local_games/fruit_duel/fruit_duel_game.dart';
import 'package:multiplayer_game/features/local_games/memory/memory_game.dart';
import 'package:multiplayer_game/features/local_games/paint_fight/paint_fight_game.dart';
import 'package:multiplayer_game/features/local_games/tic_tac_toe/tic_tac_toe_game.dart';

void main() {
  group('Crush It', () {
    test('counts taps per player and stops at the time limit', () {
      final g = CrushItLogic(durationMs: 10000);
      g.update(100);
      g.tap(0);
      g.tap(0);
      g.tap(1);
      expect(g.scores, [2, 1]);
      expect(g.secondsLeft, 10);
      g.update(10000);
      expect(g.finished, isTrue);
      g.tap(1);
      expect(g.scores, [2, 1]);
    });
  });

  group('Basketball Hoops', () {
    test('points by how far the ball lands from the rim centre', () {
      expect(BasketballLogic.pointsFor(0), 3);
      expect(BasketballLogic.pointsFor(0.1), 3);
      expect(BasketballLogic.pointsFor(0.11), 2);
      expect(BasketballLogic.pointsFor(0.25), 2);
      expect(BasketballLogic.pointsFor(0.26), 0);
    });

    test('hoop stays still at first, then slides within its swing', () {
      final g = BasketballLogic();
      for (var t = 0; t < BasketballLogic.calmMs; t += 250) {
        g.update(t);
        expect(g.hoopX, 0);
      }
      var moved = false;
      for (var t = BasketballLogic.calmMs; t < 30000; t += 37) {
        g.update(t);
        expect(g.hoopX.abs(), lessThanOrEqualTo(BasketballLogic.swing));
        if (g.hoopX.abs() > 0.3) moved = true;
      }
      expect(moved, isTrue);
    });

    test(
        'straight shot at a still hoop is a swish; wide shots miss; cooldown applies',
        () {
      final g = BasketballLogic();
      g.update(1000);
      expect(g.shoot(0, 0), 3);
      expect(g.shoot(0, 0), isNull, reason: 'cooldown');
      g.update(1700);
      expect(g.shoot(0, 0), isNull, reason: 'still cooling down');
      g.update(1800);
      expect(g.shoot(0, 0.2), 2);
      g.update(2600);
      expect(g.shoot(0, -1), 0);
      expect(g.score, [5, 0]);
      expect(g.shots, [3, 0]);
      expect(g.shoot(1, 0.05), 3, reason: 'players have their own cooldown');
    });

    test(
        'a moving hoop has to be led: the ball is judged where the hoop will be',
        () {
      final g = BasketballLogic();
      g.update(12000);
      final later = BasketballLogic.hoopXAt(12000 + BasketballLogic.flightMs);
      expect((later - g.hoopX).abs(), greaterThan(0.25),
          reason: 'the hoop moves a lot during a flight');
      expect(g.shoot(0, later), 3);
      g.update(13000);
      final now = g.hoopX;
      final shot = g.shoot(1, now)!;
      expect(g.lastShot[1]!.hoopX,
          BasketballLogic.hoopXAt(13000 + BasketballLogic.flightMs));
      expect(
          shot, BasketballLogic.pointsFor((now - g.lastShot[1]!.hoopX).abs()));
    });

    test('no shots after time is up', () {
      final g = BasketballLogic();
      g.update(30000);
      expect(g.finished, isTrue);
      expect(g.shoot(0, 0), isNull);
    });
  });

  group('Fruit Duel', () {
    test('first correct slash +2, second +1, wrong lane 0, one try per fruit',
        () {
      final g = FruitDuelLogic(random: Random(3));
      g.update(10);
      final lane = g.fruitLane;
      final wrong = (lane + 1) % FruitDuelLogic.lanes;
      expect(g.slash(1, lane), 2);
      expect(g.slash(0, wrong), 0);
      expect(g.slash(0, lane), isNull, reason: 'already used this fruit');
      expect(g.scores, [0, 2]);

      // Next fruit: player 1 first this time.
      final before = g.current;
      for (var t = 10; g.current == before; t += 10) {
        g.update(t);
      }
      expect(g.slash(0, g.fruitLane), 2);
      expect(g.slash(1, g.fruitLane), 1);
      expect(g.scores, [2, 3]);
    });

    test('fruits never repeat a lane and speed up', () {
      final g = FruitDuelLogic(random: Random(4));
      var lastLane = -1, lastId = -1, changes = 0;
      for (var t = 0; t < 20000; t += 5) {
        g.update(t);
        if (g.current != lastId) {
          expect(g.fruitLane, isNot(lastLane));
          lastLane = g.fruitLane;
          lastId = g.current;
          changes++;
        }
      }
      // At a steady 1 fruit/second there would be 20; speeding up gives more.
      expect(changes, greaterThanOrEqualTo(24));
      g.update(20000);
      expect(g.finished, isTrue);
      expect(g.slash(0, 0), isNull);
    });
  });

  group('Memory', () {
    test('pairs score and keep the turn, misses pass the turn after a delay',
        () {
      final g = MemoryLogic(random: Random(5), mismatchMs: 900);
      int pairOf(int id) => g.cards
          .indexWhere((c) => c.id != id && c.symbol == g.cards[id].symbol);
      int notPairOf(int id) => g.cards
          .indexWhere((c) => c.id != id && c.symbol != g.cards[id].symbol);

      expect(g.flip(0), isTrue);
      expect(g.flip(pairOf(0)), isTrue);
      expect(g.pairs, [1, 0]);
      expect(g.turn, 0, reason: 'match = go again');

      final a = g.cards.indexWhere((c) => !c.matched);
      final b = g.cards
          .indexWhere((c) => !c.matched && c.symbol != g.cards[a].symbol);
      expect(notPairOf(a), isNot(-1));
      g.flip(a);
      g.flip(b);
      expect(g.showingMismatch, isTrue);
      expect(
          g.flip(
              g.cards.indexWhere((c) => !c.matched && c.id != a && c.id != b)),
          isFalse,
          reason: 'board locked during mismatch');
      g.update(899);
      expect(g.turn, 0);
      g.update(900);
      expect(g.turn, 1);
      expect(g.picks, isEmpty);
    });

    test('a full game ends when every pair is found', () {
      final g = MemoryLogic(random: Random(6));
      while (!g.finished) {
        final a = g.cards.firstWhere((c) => !c.matched);
        final b = g.cards.firstWhere(
            (c) => !c.matched && c.id != a.id && c.symbol == a.symbol);
        g.flip(a.id);
        g.flip(b.id);
      }
      expect(g.pairs.reduce((x, y) => x + y), 12);
      expect(g.flip(0), isFalse);
    });

    test('cannot flip the same card twice or an out-of-range card', () {
      final g = MemoryLogic(random: Random(7));
      expect(g.flip(3), isTrue);
      expect(g.flip(3), isFalse);
      expect(g.flip(-1), isFalse);
      expect(g.flip(99), isFalse);
    });
  });

  group('Tic-Tac-Toe', () {
    test('players alternate from the chosen starter', () {
      final g = TicTacToeLogic(starter: 1);
      expect(g.turn, 1);
      g.play(4);
      expect(g.cells[4], 1);
      expect(g.turn, 0);
    });

    test('rejects taken squares, out-of-range squares and moves after the end',
        () {
      final g = TicTacToeLogic();
      expect(g.play(0), isTrue);
      expect(g.play(0), isFalse);
      expect(g.play(-1), isFalse);
      expect(g.play(9), isFalse);
      expect(g.turn, 1, reason: 'rejected moves keep the turn');
    });

    test('every line wins', () {
      for (final line in TicTacToeLogic.lines) {
        final g = TicTacToeLogic();
        final others = [
          for (var i = 0; i < 9; i++)
            if (!line.contains(i)) i
        ];
        // X takes the line, O plays elsewhere in between.
        g.play(line[0]);
        g.play(others[0]);
        g.play(line[1]);
        g.play(others[1]);
        g.play(line[2]);
        expect(g.winner, 0, reason: '$line');
        expect(g.winLine, line);
        expect(g.scores, [1, 0]);
        expect(g.play(others[2]), isFalse, reason: 'game over');
      }
    });

    test('a full board without a line is a draw', () {
      final g = TicTacToeLogic();
      // X O X / X O O / O X X
      for (final c in [0, 1, 2, 4, 3, 5, 7, 6, 8]) {
        g.play(c);
      }
      expect(g.winner, isNull);
      expect(g.isDraw, isTrue);
      expect(g.finished, isTrue);
      expect(g.scores, [0, 0]);
    });

    test('winning on the last square is a win, not a draw', () {
      final g = TicTacToeLogic();
      // X fills the right-hand column with the ninth and final move.
      for (final c in [0, 1, 2, 3, 5, 4, 7, 6, 8]) {
        g.play(c);
      }
      expect(g.winner, 0);
      expect(g.isDraw, isFalse);
    });
  });

  group('Paint Fight', () {
    test('painting claims and steals cells, scores are cell counts', () {
      final g = PaintFightLogic(cols: 4, rows: 4);
      g.update(10);
      expect(g.paint(0, 0, 0), isTrue);
      expect(g.paint(0, 1, 0), isTrue);
      expect(g.paint(0, 1, 0), isFalse, reason: 'already mine');
      expect(g.paint(1, 1, 0), isTrue, reason: 'steal');
      expect(g.scores, [1, 1]);
      expect(g.paint(1, 9, 9), isFalse, reason: 'out of bounds');
      g.update(25000);
      expect(g.finished, isTrue);
      expect(g.paint(0, 2, 2), isFalse);
      expect(g.scores, [1, 1]);
    });
  });
}
