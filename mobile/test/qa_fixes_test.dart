import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/core/text/agreement.dart';
import 'package:multiplayer_game/features/local_games/eight_ball/eight_ball_game.dart';
import 'package:multiplayer_game/features/local_games/fruit_cut/fruit_cut_game.dart';
import 'package:multiplayer_game/features/local_games/local_games_hub_screen.dart';
import 'package:multiplayer_game/features/local_games/shell/bots.dart';

void main() {
  group('You takes a plural verb', () {
    test('win and have agree', () {
      expect(isYou('You'), isTrue);
      expect(isYou(' you '), isTrue);
      expect(isYou('Mina'), isFalse);
      expect(winsBang('You'), 'You win!');
      expect(winsBang('Mina'), 'Mina wins!');
      expect(winsPhrase('You'), 'You win');
      expect(hasWord('You'), 'have');
      expect(hasWord('Ravi'), 'has');
    });
  });

  group('computer difficulty', () {
    test('easy is slower, less accurate and more likely to slip', () {
      final easy = const CpuSkill(CpuDifficulty.easy);
      final medium = const CpuSkill(CpuDifficulty.medium);
      final hard = const CpuSkill(CpuDifficulty.hard);
      expect(easy.delayScale, greaterThan(medium.delayScale));
      expect(medium.delayScale, greaterThan(hard.delayScale));
      expect(medium.delayScale, 1);
      expect(easy.aimError, greaterThan(medium.aimError));
      expect(medium.aimError, greaterThan(hard.aimError));
      expect(easy.mistakeRate, greaterThan(medium.mistakeRate));
      expect(hard.tracking, greaterThan(medium.tracking));
      expect(medium.tracking, greaterThan(easy.tracking));
    });

    test('think time stretches on easy and the best move is skipped more often',
        () {
      final easy = BotSeat(1, Random(1), true, CpuDifficulty.easy);
      final hard = BotSeat(1, Random(1), true, CpuDifficulty.hard);
      easy.wait(0, 400, 400);
      hard.wait(0, 400, 400);
      expect(easy.due(500), isFalse);
      expect(hard.due(500), isTrue);
      var easySlips = 0, hardSlips = 0;
      for (var i = 0; i < 200; i++) {
        if (easy.slips()) easySlips++;
        if (hard.slips()) hardSlips++;
      }
      expect(easySlips, greaterThan(hardSlips));
    });
  });

  group('Eight Ball', () {
    test('the table has six pockets, including both long-rail middles', () {
      final g = EightBallLogic();
      expect(g.table.pockets, hasLength(6));
      final middles =
          g.table.pockets.where((p) => (p.dx - 1).abs() < 0.05).toList();
      expect(middles, hasLength(2));
      expect(middles.map((p) => p.dy).toSet(), containsAll([0, 1]));
      final cue = g.table.byId(0);
      expect(cue.r, EightBallLogic.ballR);
      expect(g.table.pucks.where((p) => p.id != 0).every((p) => p.r == cue.r),
          isTrue);
      expect(cue.r, greaterThan(0.05));
    });

    test('a pull-back shot moves the cue and a scratch switches the turn', () {
      final g = EightBallLogic();
      final cue = g.table.byId(0);
      final x0 = cue.x;
      g.shoot(0, 0, 1.2);
      for (var t = 16; t < 4000 && g.moving; t += 16) {
        g.update(t);
      }
      expect(g.moving, isFalse);
      expect(cue.x, greaterThan(x0));

      final scratch = EightBallLogic();
      final c = scratch.table.byId(0);
      c.x = 0.28;
      c.y = 0.28;
      scratch.shoot(0, atan2(0.08 - 0.28, 0.08 - 0.28), 1.6);
      for (var t = 16; t < 5000 && scratch.moving; t += 16) {
        scratch.update(t);
      }
      expect(scratch.moving, isFalse);
      expect(scratch.ballInHand || scratch.turn == 1 || scratch.winner != null,
          isTrue);
    });

    test('missing every ball is a foul and ball-in-hand', () {
      final g = EightBallLogic();
      for (final p in g.table.pucks) {
        if (p.id != 0) p.pocketed = true;
      }
      g.shoot(0, -pi / 2, 0.4);
      for (var t = 16; t < 8000 && g.moving; t += 16) {
        g.update(t);
      }
      expect(g.turn, 1);
      expect(g.ballInHand, isTrue);
      expect(g.message, contains('Foul'));
    });
  });

  test('a missed fruit empties a life', () {
    final g = FruitCutLogic(random: Random(1));
    g.fruits.add(CutFruit(0.5, 1.9, 0, 0.5, 0, 0.045));
    g.update(16);
    expect(g.lives, 2);
  });

  test('Colour Clash is in the one-phone catalog and search can see it', () {
    expect(localGames.any((g) => g.id == 'colour_clash' && !g.remoteOnly),
        isTrue);
  });
}
