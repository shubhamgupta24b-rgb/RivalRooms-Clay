import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:multiplayer_game/features/local_games/rps/rps_game.dart';
import 'package:multiplayer_game/features/local_games/solo/brick_breaker.dart';
import 'package:multiplayer_game/features/local_games/solo/classic_snake.dart';
import 'package:multiplayer_game/features/local_games/solo/flappy_jump.dart';
import 'package:multiplayer_game/features/local_games/solo/game_2048.dart';
import 'package:multiplayer_game/features/local_games/solo/minesweeper.dart';
import 'package:multiplayer_game/features/local_games/solo/piano_tiles.dart';
import 'package:multiplayer_game/features/local_games/solo/simon_says.dart';
import 'package:multiplayer_game/features/local_games/solo/stack_tower.dart';
import 'package:multiplayer_game/features/local_games/solo/whack_mole.dart';
import 'package:multiplayer_game/features/local_games/solo/word_scramble.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  group('Rock Paper Scissors', () {
    test('rock > scissors > paper > rock; a point for each player you beat',
        () {
      expect(RpsLogic.beats(0, 2), isTrue);
      expect(RpsLogic.beats(2, 1), isTrue);
      expect(RpsLogic.beats(1, 0), isTrue);
      expect(RpsLogic.beats(0, 0), isFalse);
      expect(RpsLogic.beats(2, 0), isFalse);
      final g = RpsLogic(players: 3, revealMs: 10);
      g.pick(0, 0);
      g.pick(0, 1);
      expect(g.picks[0], 0, reason: 'locked in');
      g.pick(1, 2);
      expect(g.phase, RpsPhase.pick);
      g.pick(2, 2);
      expect(g.phase, RpsPhase.reveal);
      expect(g.lastPoints, [2, 0, 0], reason: 'rock beats both scissors');
      g.update(20);
      expect(g.round, 2);
      expect(g.picks, [null, null, null]);
    });

    test('first to 5 with two players', () {
      final g = RpsLogic(players: 2, revealMs: 1);
      var t = 0;
      while (!g.finished && t < 100) {
        g.pick(0, 1);
        g.pick(1, 0);
        g.update(t += 5);
      }
      expect(g.scores, [5, 0]);
      expect(g.finished, isTrue);
    });
  });

  group('2048', () {
    test('slides, merges once per move, scores the merged value', () {
      final g = Game2048Logic(
          random: Random(1),
          start: [2, 2, 2, 2, 4, 0, 4, 8, 0, 0, 0, 0, 0, 0, 0, 0]);
      expect(g.move(3), isTrue); // left
      expect(g.grid.sublist(0, 2), [4, 4]);
      expect(g.grid.sublist(4, 6), [8, 8]);
      expect(g.score, 4 + 4 + 8);
      expect(g.grid.where((v) => v != 0).length, 5, reason: 'one new tile');
    });

    test('no move = nothing spawns; a stuck board ends the game', () {
      final g = Game2048Logic(
          random: Random(2),
          start: [2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
      expect(g.move(3), isFalse);
      expect(g.move(0), isFalse);
      // A full board with no equal neighbours: nothing can move.
      final stuck = Game2048Logic(
          random: Random(3),
          start: [2, 4, 2, 4, 4, 2, 4, 2, 2, 4, 2, 4, 4, 2, 4, 2]);
      expect(stuck.canMove, isFalse);
      for (var d = 0; d < 4; d++) {
        expect(stuck.move(d), isFalse);
      }
      // One move away from stuck: play until the board locks up.
      final g2 = Game2048Logic(random: Random(4));
      for (var i = 0; i < 2000 && !g2.over; i++) {
        g2.move(i % 4);
      }
      expect(g2.over, isTrue);
      g2.update(10000);
      expect(g2.finished, isTrue);
      expect(g2.scores, [g2.score]);
    });
  });

  group('Classic Snake', () {
    test('moves on its own, can\'t reverse, eats and grows, dies at the wall',
        () {
      final g = ClassicSnakeLogic(random: Random(1));
      final head = g.body.first;
      g.turn(2); // straight back into itself: ignored
      g.update(600);
      expect(g.body.first, head - ClassicSnakeLogic.cols, reason: 'moved up');
      g.food = g.body.first - ClassicSnakeLogic.cols;
      g.update(600 + g.stepMs);
      expect(g.score, 1);
      expect(g.body.length, 4);
      for (var t = 1000; !g.over && t < 20000; t += 50) {
        g.update(t);
      }
      expect(g.over, isTrue, reason: 'ran into the top wall');
    });
  });

  group('Flappy Jump', () {
    test('waits for the first flap, falls, scores pipes, hits the ground', () {
      final g = FlappyLogic(random: Random(1));
      g.update(1000);
      expect(g.birdY, FlappyLogic.height / 2, reason: 'not started yet');
      g.flap();
      expect(g.vy, FlappyLogic.flapVy);
      for (var t = 1000; !g.over && t < 20000; t += 16) {
        g.update(t);
      }
      expect(g.over, isTrue, reason: 'never flapping again: it falls');
      // Flap through a pipe by steering to its gap.
      final h = FlappyLogic(random: Random(2))..flap();
      for (var t = 0; t < 8000 && !h.over; t += 16) {
        final p = h.pipes
            .where((p) => p.x + FlappyLogic.pipeW > FlappyLogic.birdX - 0.1)
            .firstOrNull;
        final targetY = p?.gapY ?? FlappyLogic.height / 2;
        if (h.birdY > targetY + 0.04 && h.vy > -0.2) h.flap();
        h.update(t);
      }
      expect(h.score, greaterThan(0));
    });
  });

  group('Minesweeper', () {
    test('first tap is always safe; flood fill; flags; boom', () {
      for (var seed = 0; seed < 20; seed++) {
        final g = MinesweeperLogic(random: Random(seed));
        g.reveal(40);
        expect(g.over, isFalse, reason: 'seed $seed');
        expect(g.mines, hasLength(MinesweeperLogic.mineCount));
        expect(g.mines.contains(40), isFalse);
        expect(g.open.length, greaterThan(1),
            reason: 'opened at least the 3x3 around');
      }
      final g = MinesweeperLogic(fixedMines: {0});
      g.toggleFlag(0);
      g.reveal(0);
      expect(g.over, isFalse, reason: 'flagged squares are protected');
      g.toggleFlag(0);
      g.reveal(80); // opens everything except the mine
      expect(g.won, isTrue);
      expect(g.score, greaterThan(80));
      final b = MinesweeperLogic(fixedMines: {0});
      b.reveal(0);
      expect(b.exploded, 0);
      expect(b.over, isTrue);
    });
  });

  group('Brick Breaker', () {
    test('launch, bounce, break bricks, lose lives', () {
      final g = BrickBreakerLogic();
      g.movePaddle(0.3);
      expect(g.ball.x, 0.3, reason: 'ball rides the paddle before launch');
      g.launch();
      for (var t = 0; t < 30000 && !g.over; t += 16) {
        g.movePaddle(g.ball.x); // perfect player
        g.update(t);
      }
      expect(g.score, greaterThan(0));
      final lazy = BrickBreakerLogic()..launch();
      lazy.movePaddle(0.05);
      for (var t = 0; t < 60000 && !lazy.over; t += 16) {
        lazy.update(t);
        if (!lazy.launched) lazy.launch();
      }
      expect(lazy.lives, 0);
      expect(lazy.over, isTrue);
    });
  });

  group('Whack-a-Mole', () {
    test('moles pop up; whacks score; bombs cost 5 (not below 0); 30 seconds',
        () {
      final g = WhackLogic(random: Random(1));
      var whacked = 0;
      for (var t = 0; t <= 31000; t += 50) {
        g.update(t);
        for (final p in [...g.up]) {
          if (p.kind != Popper.bomb) {
            g.whack(p.hole);
            whacked++;
          }
        }
      }
      expect(whacked, greaterThan(20));
      expect(g.score, greaterThanOrEqualTo(whacked));
      expect(g.over, isTrue);
      final b = WhackLogic(random: Random(2));
      b.up.add(Pop(4, Popper.bomb, 99999));
      b.whack(4);
      expect(b.score, 0);
    });
  });

  group('Piano Tiles', () {
    test(
        'tap the lowest black tile; wrong lane ends it; stray taps before start are ignored',
        () {
      final g = PianoLogic(random: Random(1));
      final first = g.next!;
      g.tap((first.lane + 1) % 4, first.y + 0.1);
      expect(g.over, isFalse, reason: 'not started yet');
      g.tap(first.lane, first.y + 0.1);
      expect(g.score, 1);
      final second = g.next!;
      g.tap((second.lane + 1) % 4, second.y + 0.1);
      expect(g.over, isTrue);
    });

    test('a tile that slips past ends the game', () {
      final g = PianoLogic(random: Random(2));
      final first = g.next!;
      g.tap(first.lane, first.y + 0.1);
      for (var t = 0; t < 20000 && !g.over; t += 16) {
        g.update(t);
      }
      expect(g.over, isTrue);
    });
  });

  group('Word Scramble', () {
    test(
        'letters are a shuffle of the word; solving scores its length; wrong resets',
        () {
      final g = WordScrambleLogic(random: Random(1));
      expect([...g.letters]..sort(), [...g.word.split('')]..sort());
      // Tap the letters in the right order.
      final word = g.word;
      final used = <int>{};
      for (final ch in word.split('')) {
        final i = [
          for (var k = 0; k < g.letters.length; k++)
            if (g.letters[k] == ch && !used.contains(k)) k
        ].first;
        used.add(i);
        g.tapLetter(i);
      }
      expect(g.score, word.length);
      expect(g.word, isNot(word));
      // A wrong order flashes and clears.
      for (var i = g.letters.length - 1; i >= 0; i--) {
        g.tapLetter(i);
      }
      if (g.attempt != g.word) expect(g.picked, isEmpty);
      g.update(60000);
      expect(g.over, isTrue);
    });
  });

  group('Stack Tower', () {
    test('perfect drops keep the width, overhang is cut, a miss ends it', () {
      final g = StackLogic();
      g.movingLeft = g.tower.last.left; // perfectly aligned
      g.drop();
      expect(g.tower.last.width, closeTo(0.6, 1e-9));
      expect(g.perfects, 1);
      g.movingLeft = g.tower.last.left + 0.2; // hangs 0.2 over
      g.drop();
      expect(g.tower.last.width, closeTo(0.4, 1e-9));
      expect(g.score, 2);
      g.movingLeft = 5; // nowhere near
      g.drop();
      expect(g.over, isTrue);
    });
  });

  group('Simon Says', () {
    test(
        'shows the pattern, then you repeat it; each round adds one; a wrong pad ends it',
        () {
      final g = SimonLogic(random: Random(1));
      expect(g.phase, SimonPhase.pause);
      g.press(g.sequence.first);
      expect(g.typed, 0, reason: 'not your turn yet');
      var t = 0;
      for (var round = 1; round <= 3; round++) {
        while (g.phase != SimonPhase.input) {
          g.update(t += 20);
        }
        for (final p in [...g.sequence]) {
          g.press(p);
        }
        expect(g.score, round);
        expect(g.sequence, hasLength(round + 1));
      }
      while (g.phase != SimonPhase.input) {
        g.update(t += 20);
      }
      g.press((g.sequence.first + 1) % 4);
      expect(g.over, isTrue);
      expect(g.score, 3);
    });
  });
}
