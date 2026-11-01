import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/features/local_games/colour_clash/colour_clash_logic.dart';
import 'package:multiplayer_game/features/local_games/dots_boxes/dots_boxes_game.dart';
import 'package:multiplayer_game/features/local_games/ludo/ludo_logic.dart';
import 'package:multiplayer_game/features/local_games/snakes_ladders/snakes_ladders_game.dart';
import 'package:multiplayer_game/features/local_games/truth_dare/truth_dare_game.dart';

/// Builds a Colour Clash game whose deck is dealt exactly as listed: each player's hand,
/// then the starting card, then the draw pile (drawn from the end of [rest]).
ColourClashLogic rigged(List<List<ClashCard>> hands, ClashCard start,
    [List<ClashCard> rest = const []]) {
  final n = hands.length;
  // The constructor deals round-robin from the end, then flips one card.
  final dealOrder = <ClashCard>[];
  for (var r = 0; r < ColourClashLogic.handSize; r++) {
    for (var p = 0; p < n; p++) {
      dealOrder.add(hands[p][r]);
    }
  }
  dealOrder.add(start);
  final deck = [...rest, ...dealOrder.reversed];
  final g = ColourClashLogic(players: n, deck: deck);
  g.reveal();
  return g;
}

var _id = 1000;
ClashCard n(ClashColor c, int v) => ClashCard(_id++, c, ClashKind.number, v);
ClashCard k(ClashColor c, ClashKind kind) => ClashCard(_id++, c, kind);
List<ClashCard> fill(int count, ClashColor c, [int value = 9]) =>
    [for (var i = 0; i < count; i++) n(c, value)];

void main() {
  group('Colour Clash', () {
    test('108-card deck with the classic mix', () {
      final d = ColourClashLogic.fullDeck();
      expect(d.length, 108);
      expect(d.map((c) => c.id).toSet().length, 108);
      expect(d.where((c) => c.kind == ClashKind.wildFour).length, 4);
      expect(d.where((c) => c.kind == ClashKind.wild).length, 4);
      expect(d.where((c) => c.kind == ClashKind.number && c.number == 0).length,
          4);
      expect(d.where((c) => c.kind == ClashKind.drawTwo).length, 8);
    });

    test('deals 7 each, starts on a number card, hand hidden until revealed',
        () {
      for (var seed = 0; seed < 20; seed++) {
        final g = ColourClashLogic(players: 4, random: Random(seed));
        expect(g.hands.every((h) => h.length == 7), isTrue);
        expect(g.top.kind, ClashKind.number);
        expect(g.phase, ClashPhase.handoff);
        expect(
            g.hands.expand((h) => h).length +
                g.drawPile.length +
                g.discard.length,
            108);
      }
    });

    test('only matching colour, number, symbol or wild can be played', () {
      final red5 = n(ClashColor.red, 5),
          blue5 = n(ClashColor.blue, 5),
          green7 = n(ClashColor.green, 7),
          wild = k(ClashColor.wild, ClashKind.wild);
      final g = rigged([
        [red5, blue5, green7, wild, ...fill(3, ClashColor.yellow)],
        fill(7, ClashColor.green),
      ], n(ClashColor.red, 3));
      expect(g.canPlay(red5), isTrue, reason: 'colour');
      expect(g.canPlay(blue5), isFalse);
      expect(g.canPlay(green7), isFalse);
      expect(g.canPlay(wild), isTrue);
      expect(g.play(green7.id), isFalse);
      expect(g.play(blue5.id), isFalse);
      expect(g.play(red5.id), isTrue);
      expect(g.turn, 1);
      expect(g.phase, ClashPhase.handoff);
      expect(g.play(1), isFalse, reason: 'hand hidden until reveal');
      g.reveal();
      // Player 2 has only green 9s: blue/red 5 on top -> can't play; number 5 matches? no.
      expect(g.playable, isEmpty);
    });

    test('skip, reverse (3 players), +2 and wild +4', () {
      final skip = k(ClashColor.red, ClashKind.skip);
      final g = rigged([
        [skip, ...fill(6, ClashColor.red)],
        fill(7, ClashColor.blue),
        fill(7, ClashColor.green),
      ], n(ClashColor.red, 1));
      g.play(skip.id);
      expect(g.turn, 2, reason: 'player 2 skipped');

      final rev = k(ClashColor.red, ClashKind.reverse);
      final g2 = rigged([
        [rev, ...fill(6, ClashColor.red)],
        fill(7, ClashColor.blue),
        fill(7, ClashColor.green),
      ], n(ClashColor.red, 1));
      g2.play(rev.id);
      expect(g2.direction, -1);
      expect(g2.turn, 2, reason: 'goes the other way round');

      final plus2 = k(ClashColor.red, ClashKind.drawTwo);
      final g3 = rigged([
        [plus2, ...fill(6, ClashColor.red)],
        fill(7, ClashColor.blue),
      ], n(ClashColor.red, 1), fill(10, ClashColor.yellow));
      g3.play(plus2.id);
      expect(g3.hands[1].length, 9);
      expect(g3.turn, 0, reason: '2 players: the victim is skipped');

      final plus4 = k(ClashColor.wild, ClashKind.wildFour);
      final g4 = rigged([
        [plus4, ...fill(6, ClashColor.red)],
        fill(7, ClashColor.blue),
      ], n(ClashColor.red, 1), fill(10, ClashColor.yellow));
      g4.play(plus4.id);
      expect(g4.phase, ClashPhase.chooseColor);
      expect(g4.chooseColor(ClashColor.wild), isFalse);
      g4.chooseColor(ClashColor.green);
      expect(g4.color, ClashColor.green);
      expect(g4.hands[1].length, 11);
      expect(g4.turn, 0);
    });

    test('draw: unplayable ends the turn, playable may be played or passed',
        () {
      final g = rigged([fill(7, ClashColor.blue), fill(7, ClashColor.green)],
          n(ClashColor.red, 1), [n(ClashColor.yellow, 2)]);
      final drawn = g.draw();
      expect(drawn!.color, ClashColor.yellow);
      expect(g.hands[0].length, 8);
      expect(g.turn, 1, reason: 'could not play it');

      final red4 = n(ClashColor.red, 4);
      final g2 = rigged([fill(7, ClashColor.blue), fill(7, ClashColor.green)],
          n(ClashColor.red, 1), [red4]);
      g2.draw();
      expect(g2.turn, 0);
      expect(g2.playable.map((c) => c.id), [red4.id],
          reason: 'only the drawn card');
      expect(g2.draw(), isNull, reason: 'one draw per turn');
      expect(g2.play(red4.id), isTrue);
      expect(g2.turn, 1);
    });

    test('forgetting ONE! costs 2 cards; calling it and going out wins', () {
      final a = n(ClashColor.red, 2), b = n(ClashColor.red, 3);
      // Player 1 holds 7 cards; get them to 2 by playing reds while player 2 draws.
      final g = rigged([
        [a, b, ...fill(5, ClashColor.red)],
        fill(7, ClashColor.blue, 8),
      ], n(ClashColor.red, 1), fill(30, ClashColor.yellow, 8));
      for (var i = 0; i < 5; i++) {
        g.play(g.hands[0].firstWhere((c) => c.number == 9).id);
        g.reveal();
        g.draw(); // player 2 can't play, draws, passes automatically
        g.reveal();
      }
      expect(g.hands[0].length, 2);
      g.play(a.id); // forgot to call ONE!
      expect(g.hands[0].length, 3, reason: '1 left + 2 penalty');
      expect(g.message, contains('ONE!'));

      final g2 = rigged([
        [a, b, ...fill(5, ClashColor.red)],
        fill(7, ClashColor.blue, 8),
      ], n(ClashColor.red, 1), fill(30, ClashColor.yellow, 8));
      for (var i = 0; i < 5; i++) {
        g2.play(g2.hands[0].firstWhere((c) => c.number == 9).id);
        g2.reveal();
        g2.draw();
        g2.reveal();
      }
      expect(g2.callOne(), isTrue);
      g2.play(a.id);
      expect(g2.hands[0].length, 1);
      g2.reveal();
      g2.draw();
      g2.reveal();
      g2.play(b.id);
      expect(g2.finished, isTrue);
      expect(g2.scores, [1, 0]);
    });

    test('draw pile reshuffles the discard pile when it runs out', () {
      final g = ColourClashLogic(players: 2, random: Random(3));
      var guard = 0;
      while (g.drawPile.isNotEmpty && guard++ < 200) {
        g.reveal();
        if (g.phase != ClashPhase.play) break;
        final p = g.playable.toList();
        if (p.isNotEmpty) {
          g.play(p.first.id, chosen: ClashColor.red);
        } else {
          g.draw();
          if (g.drewThisTurn) g.pass();
        }
      }
      // Whatever happened, no card was lost or duplicated.
      expect(
          g.hands.expand((h) => h).length +
              g.drawPile.length +
              g.discard.length,
          108);
    });
  });

  group('Snakes & Ladders', () {
    test('board numbering snakes left-right from the bottom', () {
      expect(SnakesLaddersLogic.cell(1), (0, 9));
      expect(SnakesLaddersLogic.cell(10), (9, 9));
      expect(SnakesLaddersLogic.cell(11), (9, 8));
      expect(SnakesLaddersLogic.cell(100), (0, 0));
    });

    test('ladders, snakes, 6 rolls again, exact 100 wins', () {
      final g = SnakesLaddersLogic(players: 2);
      g.roll(4);
      expect(g.pos[0], 14, reason: 'ladder 4 -> 14');
      expect(g.turn, 1);
      g.roll(6);
      expect(g.pos[1], 6);
      expect(g.turn, 1, reason: '6 rolls again');
      g.roll(5); // 6 + 5 = 11
      expect(g.turn, 0);
      g.roll(3); // 14 + 3 = 17 snake -> 7
      expect(g.pos[0], 7);
      g.pos[1] = 97;
      g.roll(5);
      expect(g.pos[1], 97, reason: 'overshoot: stay');
      g.roll(1);
      g.roll(3);
      expect(g.pos[1], 100);
      expect(g.finished, isTrue);
      expect(g.scores, [0, 1]);
      expect(g.roll(2), isNull);
    });
  });

  group('Ludo', () {
    test('track and home columns are consistent', () {
      expect(LudoLogic.track.length, 52);
      expect(LudoLogic.track.toSet().length, 52);
      for (var seat = 0; seat < 4; seat++) {
        // The square before each home column is next to its first square.
        final (ec, er) = LudoLogic.track[(seat * 13 + 50) % 52];
        final (hc, hr) = LudoLogic.homeColumns[seat].first;
        expect((ec - hc).abs() + (er - hr).abs(), 1, reason: 'seat $seat');
      }
    });

    test('needs a 6 to leave base; 6 rolls again', () {
      final g = LudoLogic(players: 2);
      expect(g.seats, [0, 2]);
      g.roll(3);
      expect(g.turn, 1, reason: 'no moves');
      g.roll(6);
      expect(g.phase, LudoPhase.move);
      expect(g.movable, [0, 1, 2, 3]);
      expect(g.move(0), isTrue);
      expect(g.tokens[1][0], 0);
      expect(g.turn, 1, reason: 'rolled 6');
      g.roll(4);
      g.move(0);
      expect(g.tokens[1][0], 4);
      expect(g.turn, 0);
    });

    test('capturing sends a token home and earns a roll; safe squares protect',
        () {
      final g = LudoLogic(players: 2);
      // Player 0 (seat 0, start 0) and player 1 (seat 2, start 26).
      g.tokens[1][0] = 30; // absolute (26 + 30) % 52 = 4
      g.tokens[0][0] = 1; // absolute 1
      g.roll(3);
      g.move(0);
      expect(g.tokens[0][0], 4);
      expect(g.tokens[1][0], -1, reason: 'captured');
      expect(g.turn, 0, reason: 'capture earns another roll');

      final s = LudoLogic(players: 2);
      s.tokens[1][0] = 34; // absolute 8: a star
      s.tokens[0][0] = 5;
      s.roll(3);
      s.move(0);
      expect(s.tokens[1][0], 34, reason: 'safe square');
    });

    test('exact roll to get home; all four home wins; three 6s lose the turn',
        () {
      final g = LudoLogic(players: 2);
      g.tokens[0] = [56, 56, 56, 53];
      g.roll(4);
      expect(g.movable, isEmpty, reason: '53 + 4 overshoots');
      expect(g.turn, 1);
      g.roll(1);
      g.roll(3);
      expect(g.turn, 0);
      g.roll(3);
      g.move(3);
      expect(g.finished, isTrue);
      expect(g.scores, [1, 0]);

      final t = LudoLogic(players: 2);
      t.tokens[0] = [10, -1, -1, -1];
      t.roll(6);
      t.move(0);
      t.roll(6);
      t.move(0);
      t.roll(6);
      expect(t.turn, 1, reason: 'third 6');
      expect(t.tokens[0][0], 22);
    });
  });

  group('Dots & Boxes', () {
    test('closing a box scores and keeps the turn; full board ends', () {
      final g = DotsBoxesLogic(players: 2, size: 2);
      expect(g.totalLines, 12);
      g.drawLine(horizontal: true, row: 0, col: 0); // p0
      g.drawLine(horizontal: true, row: 1, col: 0); // p1
      g.drawLine(horizontal: false, row: 0, col: 0); // p0
      expect(g.drawLine(horizontal: false, row: 0, col: 0), isNull,
          reason: 'already drawn');
      expect(g.turn, 1);
      expect(g.drawLine(horizontal: false, row: 0, col: 1), 1,
          reason: 'p1 closes the box');
      expect(g.boxes[0][0], 1);
      expect(g.turn, 1, reason: 'goes again');
      expect(g.drawLine(horizontal: true, row: 5, col: 0), isNull,
          reason: 'off the grid');
      // Fill the rest.
      for (var r = 0; r <= 2; r++) {
        for (var c = 0; c < 2; c++) {
          g.drawLine(horizontal: true, row: r, col: c);
        }
      }
      for (var r = 0; r < 2; r++) {
        for (var c = 0; c <= 2; c++) {
          g.drawLine(horizontal: false, row: r, col: c);
        }
      }
      expect(g.finished, isTrue);
      expect(g.scores.reduce((a, b) => a + b), 4);
    });
  });

  group('Truth or Dare', () {
    test('spin, choose, complete; ends after everyone had their spins', () {
      final g = TruthDareLogic(players: 3, spinsEach: 2, random: Random(1));
      expect(g.totalSpins, 6);
      expect(TruthDareLogic.truths.length, greaterThanOrEqualTo(20));
      expect(TruthDareLogic.dares.length, greaterThanOrEqualTo(20));
      for (var i = 0; i < 6; i++) {
        expect(g.spin(i % 3), i % 3);
        g.choose(truth: true); // ignored: still spinning
        expect(g.phase, TodPhase.spinning);
        g.landed();
        g.choose(truth: i.isEven);
        expect(g.prompt, isNotEmpty);
        expect(
            (i.isEven ? TruthDareLogic.truths : TruthDareLogic.dares)
                .contains(g.prompt),
            isTrue);
        g.complete(done: i != 5);
      }
      expect(g.finished, isTrue);
      expect(g.scores, [2, 2, 1]);
    });
  });
}
