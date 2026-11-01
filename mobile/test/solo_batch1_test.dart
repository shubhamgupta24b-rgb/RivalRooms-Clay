import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/features/local_games/solo/ball_sort.dart';
import 'package:multiplayer_game/features/local_games/solo/dino_run.dart';
import 'package:multiplayer_game/features/local_games/solo/hangman.dart';
import 'package:multiplayer_game/features/local_games/solo/sliding_puzzle.dart';
import 'package:multiplayer_game/features/local_games/solo/sudoku.dart';

void main() {
  group('Ball Sort', () {
    test(
        'a level has every colour exactly 4 times plus two empty tubes, not already solved',
        () {
      final g = BallSortLogic(random: Random(1));
      expect(g.tubes.length, g.colors + 2);
      final all = [for (final t in g.tubes) ...t];
      for (var c = 0; c < g.colors; c++) {
        expect(all.where((b) => b == c).length, 4);
      }
      expect(g.solved, isFalse);
    });

    test(
        'pour rules: only onto the same colour or into an empty tube, never over capacity',
        () {
      final g = BallSortLogic(random: Random(2));
      g.tubes = [
        [0, 1, 1],
        [2, 1, 1],
        [0, 0, 0, 2],
        [],
      ];
      expect(g.pourable(0, 1), 1, reason: 'one slot left on the matching 1');
      expect(g.pourable(0, 3), 2, reason: 'both top 1s go into the empty tube');
      expect(g.pourable(2, 1), 0, reason: 'colours differ');
      expect(g.pourable(1, 2), 0, reason: 'full tube');
      g.tap(0);
      g.tap(3);
      expect(g.tubes[3], [1, 1]);
      g.undo();
      expect(g.tubes[0], [0, 1, 1]);
    });

    test('a solved level scores and moves on to a harder one', () {
      final g = BallSortLogic(random: Random(3));
      g.tubes = [
        [0, 0, 0],
        [1, 1, 1, 1],
        [0],
        [],
      ];
      g.tap(2);
      g.tap(0);
      expect(g.solved, isTrue);
      expect(g.score, 1);
      final colours = g.colors;
      for (var t = 0; t <= 1500; t += 100) {
        g.update(t);
      }
      expect(g.level, 2);
      expect(g.colors, colours + 1);
    });
  });

  group('Sliding Puzzle', () {
    test(
        'the shuffle is solvable and not already solved; tiles only slide into the gap',
        () {
      final g = SlidingLogic(random: Random(4));
      expect(g.solved, isFalse);
      expect(g.tiles.toSet(), {for (var i = 0; i < 9; i++) i});
      final gap = g.tiles.indexOf(0);
      final far = [for (var i = 0; i < 9; i++) i].firstWhere(
          (i) => (i ~/ 3 - gap ~/ 3).abs() + (i % 3 - gap % 3).abs() > 1);
      final before = List.of(g.tiles);
      g.tap(far);
      expect(g.tiles, before, reason: 'not next to the gap');
    });

    test('solving 3x3 scores and moves on to 4x4', () {
      final g = SlidingLogic(random: Random(5));
      g.tiles = [1, 2, 3, 4, 5, 6, 7, 0, 8];
      g.tap(8);
      expect(g.solved, isTrue);
      expect(g.score, greaterThan(0));
      for (var t = 0; t <= 1600; t += 100) {
        g.update(t);
      }
      expect(g.size, 4);
      expect(g.tiles.length, 16);
    });
  });

  group('Sudoku', () {
    test('the puzzle has exactly one solution and matches it', () {
      final g = SudokuLogic(random: Random(6), blanks: 40);
      expect(SudokuMaker.count(List.of(g.puzzle)), 1);
      for (var i = 0; i < 81; i++) {
        if (g.puzzle[i] != 0) expect(g.puzzle[i], g.solution[i]);
      }
      expect(g.puzzle.where((v) => v == 0).length, 40);
    });

    test('right numbers fill in, wrong ones cost a mistake, 3 mistakes ends it',
        () {
      final g = SudokuLogic(random: Random(7), blanks: 30);
      final blank = g.puzzle.indexOf(0);
      g.select(blank);
      final wrong = g.solution[blank] % 9 + 1;
      g.enter(wrong);
      expect(g.mistakes, 1);
      expect(g.cells[blank], 0);
      g.enter(g.solution[blank]);
      expect(g.cells[blank], g.solution[blank]);
      final other = g.puzzle.indexOf(0, blank + 1);
      g.select(other);
      g.enter(g.solution[other] % 9 + 1);
      g.enter(g.solution[other] % 9 + 1);
      expect(g.over, isTrue);
    });

    test('filling every blank solves it and scores', () {
      final g = SudokuLogic(random: Random(8), blanks: 20);
      for (var i = 0; i < 81; i++) {
        if (g.puzzle[i] != 0) continue;
        g.select(i);
        g.enter(g.solution[i]);
      }
      expect(g.solved, isTrue);
      expect(g.score, greaterThan(0));
    });
  });

  group('Hangman', () {
    test(
        'right letters show, wrong ones cost lives, a full word scores and a new one comes',
        () {
      final g = HangmanLogic(random: Random(9));
      final first = g.word;
      for (final l in first.split('').toSet()) {
        g.guess(l);
      }
      expect(g.won, isTrue);
      expect(g.score, 1);
      for (var t = 0; t <= 1300; t += 100) {
        g.update(t);
      }
      expect(g.guessed, isEmpty, reason: 'next word');
    });

    test('six wrong letters ends the game', () {
      final g = HangmanLogic(random: Random(10));
      final misses = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
          .split('')
          .where((l) => !g.word.contains(l))
          .take(6);
      for (final l in misses) {
        g.guess(l);
      }
      expect(g.over, isTrue);
      expect(g.shown.replaceAll(' ', ''), g.word,
          reason: 'the word is shown at the end');
    });

    test('every word is letters only', () {
      for (final words in hangmanWords.values) {
        for (final w in words) {
          expect(RegExp(r'^[A-Z]+$').hasMatch(w), isTrue, reason: w);
        }
      }
    });
  });

  group('Dino Run', () {
    test('running scores metres and speeds up; never jumping hits a cactus',
        () {
      final g = DinoLogic(random: Random(11));
      var t = 0;
      while (!g.over && t < 60000) {
        t += 16;
        g.update(t);
      }
      expect(g.over, isTrue);
      expect(g.score, greaterThan(10));
    });

    test('jumping at the right moments keeps the dino alive much longer', () {
      final g = DinoLogic(random: Random(12));
      var t = 0;
      while (!g.over && t < 60000) {
        t += 16;
        g.update(t);
        // Jump when a cactus or low bird is just ahead.
        final close = g.obstacles.any((o) =>
            !(o.bird && o.high) &&
            o.x - g.dinoX < 2.2 + g.speed * 0.05 &&
            o.x - g.dinoX > 0.3);
        if (close) g.jump();
      }
      expect(g.score, greaterThan(200));
    });
  });
}
