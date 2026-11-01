import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/features/local_games/solo/block_drop.dart';
import 'package:multiplayer_game/features/local_games/solo/bubble_shooter.dart';
import 'package:multiplayer_game/features/local_games/solo/color_switch.dart';
import 'package:multiplayer_game/features/local_games/solo/sky_jumper.dart';
import 'package:multiplayer_game/features/local_games/solo/space_shooter.dart';

void main() {
  group('Block Drop', () {
    test('every piece is 4 blocks in every rotation', () {
      for (var k = 0; k < 7; k++) {
        for (var r = 0; r < 4; r++) {
          final cells = Piece(k, 3, 3, r).cells();
          expect(cells.toSet().length, 4, reason: 'piece $k rotation $r');
        }
      }
    });

    test('a full row clears and scores; the rows above drop down', () {
      final g = BlockDropLogic(random: Random(1));
      for (var c = 0; c < BlockDropLogic.cols; c++) {
        if (c < 4 || c > 7) g.board[BlockDropLogic.rows - 1][c] = 2;
      }
      g.board[BlockDropLogic.rows - 2][0] = 5;
      // An I piece lying flat fills columns 4-7 of the bottom row.
      g.piece = Piece(0, 4, BlockDropLogic.rows - 3);
      g.hardDrop();
      expect(g.lines, 1);
      expect(g.score, greaterThanOrEqualTo(100));
      expect(g.board[BlockDropLogic.rows - 1][0], 5,
          reason: 'the block above dropped');
    });

    test('pieces never leave the board; stacking to the top ends the game', () {
      final g = BlockDropLogic(random: Random(2));
      for (var i = 0; i < 30; i++) {
        g.move(-1);
        g.move(-1);
        g.move(-1);
        g.move(-1);
        g.rotate();
        for (final (c, _) in g.piece.cells()) {
          expect(c, inInclusiveRange(0, BlockDropLogic.cols - 1));
        }
        g.hardDrop();
        if (g.over) break;
      }
      expect(g.over, isTrue);
    });
  });

  group('Bubble Shooter', () {
    test('three of a colour pop, and bubbles left hanging fall', () {
      final g = BubbleLogic(random: Random(3));
      g.grid
        ..clear()
        ..[(0, 0)] = 1
        ..[(0, 1)] = 1
        ..[(1, 0)] = 2 // hangs only from (0,0)/(0,1)
        ..[(0, 5)] = 4;
      g.current = 1;
      // Fire straight at the gap next to the pair.
      final (tx, ty) = BubbleLogic.pos(0, 2);
      g.setAim(tx, ty);
      g.fire();
      for (var t = 0; t < 3000 && g.flying != null; t += 16) {
        g.update(t);
      }
      expect(g.grid.containsKey((0, 0)), isFalse, reason: 'popped');
      expect(g.grid.containsKey((1, 0)), isFalse, reason: 'fell');
      expect(g.grid[(0, 5)], 4, reason: 'still hanging from the top');
      expect(g.score, greaterThan(0));
    });

    test(
        'shots that don\'t pop bring new rows; reaching the line ends the game',
        () {
      final g = BubbleLogic(random: Random(4));
      var t = 0;
      for (var i = 0; i < 200 && !g.over; i++) {
        g.setAim(0.5, 0);
        g.fire();
        while (g.flying != null && t < 600000) {
          t += 16;
          g.update(t);
        }
      }
      expect(g.over, isTrue);
    });
  });

  group('Sky Jumper', () {
    test(
        'bouncing on the start pad keeps you alive; steering away makes you fall',
        () {
      final g = SkyLogic(random: Random(5));
      var t = 0;
      for (; t < 3000; t += 16) {
        g.update(t);
      }
      expect(g.over, isFalse);
      g.steer(0.0); // off the edge of the pad
      for (; t < 15000 && !g.over; t += 16) {
        g.update(t);
        g.steer(t.isEven ? 0.0 : 1.0);
      }
      expect(g.best, greaterThan(0));
    });

    test('a steering bot that aims for the next pad climbs', () {
      final g = SkyLogic(random: Random(6));
      var t = 0;
      for (; t < 60000 && !g.over; t += 16) {
        g.update(t);
        // Head for the nearest pad above (or below while falling).
        final candidates = g.pads.where((p) =>
            !p.broken &&
            p.kind != PadKind.breaking &&
            (g.vy > 0 ? p.y > g.y : p.y < g.y));
        if (candidates.isNotEmpty) {
          final p = candidates
              .reduce((a, b) => (a.y - g.y).abs() < (b.y - g.y).abs() ? a : b);
          g.steer(p.x);
        }
      }
      expect(g.score, greaterThan(20));
    });
  });

  group('Space Shooter', () {
    test('the ship shoots aliens down; getting hit costs lives until the end',
        () {
      final g = SpaceLogic(random: Random(7));
      var t = 0;
      for (; t < 20000; t += 16) {
        g.update(t);
        if (g.aliens.isNotEmpty) g.steer(g.aliens.first.x, 1.4);
      }
      expect(g.score, greaterThan(0));
      // Park under incoming fire and let things run: eventually all lives are lost.
      for (; t < 600000 && !g.over; t += 16) {
        g.steer(0.5, 1.4);
        g.update(t);
      }
      expect(g.over, isTrue);
      expect(g.lives, 0);
    });
  });

  group('Color Switch', () {
    test('not tapping falls off the bottom', () {
      final g = SwitchLogic(random: Random(8));
      g.tap();
      for (var t = 0; t < 5000 && !g.over; t += 16) {
        g.update(t);
      }
      expect(g.over, isTrue);
    });

    test('passing a ring is only allowed through your own colour', () {
      final g = SwitchLogic(random: Random(9));
      final ring = g.rings.first;
      final here = g.colourAt(ring, above: false);
      expect(here, inInclusiveRange(0, 3));
      g.colour = (here + 1) % 4;
      g.tap();
      g.y = ring.y - ring.radius; // right on the bottom of the ring
      g.update(16);
      g.update(32);
      expect(g.over, isTrue, reason: 'wrong colour');
    });

    test(
        'your own colour lets you through the ring, and the star in the middle is a point',
        () {
      final g = SwitchLogic(random: Random(10));
      final ring = g.rings.first;
      g.tap();
      g.update(0);
      // Just under the ring, rising; match whatever colour is at the bottom right now.
      g.y = ring.y - ring.radius - SwitchLogic.thick;
      g.colour = g.colourAt(ring, above: false);
      g.vy = 1.4;
      for (var t = 16; t <= 600 && !g.over && g.score == 0; t += 16) {
        g.colour = g.colourAt(ring,
            above: false); // stay matched while crossing the band
        g.update(t);
      }
      expect(g.over, isFalse, reason: 'matching colour passes');
      expect(g.score, 1, reason: 'collected the star in the middle');
    });
  });
}
