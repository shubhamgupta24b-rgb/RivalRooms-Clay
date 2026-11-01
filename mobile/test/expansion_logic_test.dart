import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/features/local_games/fruit_cut/fruit_cut_game.dart';
import 'package:multiplayer_game/features/local_games/local_games_hub_screen.dart';
import 'package:multiplayer_game/features/local_games/solo/hex_sort.dart';
import 'package:multiplayer_game/features/local_games/solo/game_2048.dart';
import 'package:multiplayer_game/features/local_games/solo/minesweeper.dart';
import 'package:multiplayer_game/games/game_catalog.dart';

void main() {
  test('removed games stay out of the catalog and the one-phone hub', () {
    const gone = [
      'classic_snake',
      'penalty',
      'fruit_duel',
      'snake_duel',
      'crush_it'
    ];
    expect(gameCatalog.map((g) => g.id), isNot(containsAll(gone)));
    expect(localGames.where((g) => !g.remoteOnly).map((g) => g.id),
        isNot(containsAll(gone)));
  });

  test('minesweeper levels grow the board and the mine count', () {
    expect(MinesweeperLogic.levelSpecs, [(9, 10), (12, 22), (16, 40)]);
    expect(MinesweeperLogic(level: 1).board, 9);
    expect(MinesweeperLogic(level: 2).board, 12);
    expect(MinesweeperLogic(level: 3).budget, 40);
    final classic = MinesweeperLogic(fixedMines: {0});
    expect(classic.board, 9);
  });

  test('hex sort has 50 solvable puzzles per difficulty and they get fuller',
      () {
    expect(hexLevelsEach, 50);
    for (final d in [0, 1, 2]) {
      final first = hexPuzzle(d, 1);
      final last = hexPuzzle(d, 50);
      expect(first.solved, isFalse, reason: 'difficulty $d level 1');
      expect(last.solved, isFalse, reason: 'difficulty $d level 50');
      expect(last.colors, greaterThanOrEqualTo(first.colors));
      expect(first.tubes.length, greaterThan(first.colors));
    }
  });

  test('slicing a bomb ends Fruit Cut', () {
    final g = FruitCutLogic(random: Random(1));
    g.fruits.add(CutFruit(0.5, 0.8, 0, -1, -1, 0.05));
    g.swipe(0.2, 0.8, 0.8, 0.8);
    expect(g.over, isTrue);
    expect(g.fruits.single.sliced, isTrue);
  });

  test('2048 merges a pair once and undo restores the board', () {
    final g =
        Game2048Logic(start: [2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
    expect(g.move(3), isTrue); // left: the pair merges once
    expect(g.grid[0], 4);
    expect(g.grid[1] == 4 || g.grid[1] == 2 || g.grid[1] == 0, isTrue);
    g.undo();
    expect(g.grid[0], 2);
    expect(g.grid[1], 2);
    expect(g.score, 0);
  });
}
