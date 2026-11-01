import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/features/local_games/battleship/battleship_game.dart';
import 'package:multiplayer_game/features/local_games/bingo/bingo_game.dart';
import 'package:multiplayer_game/features/local_games/checkers/checkers_game.dart';
import 'package:multiplayer_game/features/local_games/shell/local_game_info.dart';
import 'package:multiplayer_game/features/local_games/shell/local_game_logic.dart';

/// Lets bots in every seat play until the game ends (or the limit).
void playOut(LocalGameLogic g, LocalGameInfo info, int seats,
    {int limitMs = 3600000}) {
  final bots = [for (var i = 0; i < seats; i++) BotSeat(i, Random(i + 1))];
  for (var t = 0; t < limitMs && !g.finished; t += 50) {
    g.update(t);
    for (final b in bots) {
      info.bot!(g, b, t);
    }
  }
}

void main() {
  group('Bingo', () {
    test('cards hold 1-25 once each, in a different order', () {
      final g = BingoLogic(players: 3, random: Random(1));
      for (final c in g.cards) {
        expect(c.toSet(), {for (var n = 1; n <= 25; n++) n});
      }
      expect(g.cards[0], isNot(equals(g.cards[1])));
    });

    test('calling crosses a number off every card; turns rotate; no repeats',
        () {
      final g = BingoLogic(players: 3, random: Random(2));
      expect(g.call(7), isTrue);
      expect(g.turn, 1);
      for (var p = 0; p < 3; p++) {
        expect(g.marked(p, g.cards[p].indexOf(7)), isTrue);
      }
      expect(g.call(7), isFalse, reason: 'already called');
      expect(g.call(0), isFalse);
      expect(g.call(26), isFalse);
    });

    test('five lines is BINGO and ends the game', () {
      final g = BingoLogic(players: 2, random: Random(3));
      // Call player 1's first row, first column, then more until five lines.
      final card = g.cards[0];
      final order = [
        for (final l in BingoLogic.lines)
          for (final cell in l) card[cell]
      ];
      for (final n in order) {
        if (g.finished) break;
        if (!g.isCalled(n)) g.call(n);
      }
      expect(g.finished, isTrue);
      expect(g.winners, isNotEmpty);
      for (final w in g.winners) {
        expect(g.lineCount(w), greaterThanOrEqualTo(5));
      }
    });

    test('bots finish a 4-player game; the online state round-trips', () {
      final g = BingoLogic(players: 4, random: Random(4));
      playOut(g, bingoInfo, 4);
      expect(g.finished, isTrue);
      final spec = bingoInfo.online!;
      final guest = spec.create(4) as BingoLogic;
      spec.load(guest, spec.save(g), 1);
      expect(guest.cards, g.cards);
      expect(guest.called, g.called);
      expect(guest.winners, g.winners);
      // Only the player whose turn it is may call.
      final h = spec.create(2) as BingoLogic;
      spec.apply(h, 1, 'call', [5]);
      expect(h.called, isEmpty);
      spec.apply(h, 0, 'call', [5]);
      expect(h.called, [5]);
    });
  });

  group('Battleship', () {
    test('random fleets: 5 ships of 4,3,3,2,2, in the sea, not touching', () {
      for (var seed = 0; seed < 30; seed++) {
        final fleet = BattleshipLogic.randomFleet(Random(seed));
        expect(fleet.map((s) => s.length).toList(), BattleshipLogic.fleet);
        final cells = [for (final s in fleet) ...s];
        expect(cells.toSet().length, cells.length, reason: 'no overlap');
        expect(cells.every((c) => c >= 0 && c < 64), isTrue);
        for (var a = 0; a < fleet.length; a++) {
          for (var b = a + 1; b < fleet.length; b++) {
            for (final x in fleet[a]) {
              for (final y in fleet[b]) {
                final touching =
                    (x ~/ 8 - y ~/ 8).abs() <= 1 && (x % 8 - y % 8).abs() <= 1;
                expect(touching, isFalse, reason: 'seed $seed');
              }
            }
          }
        }
      }
    });

    test('a hit fires again, a miss passes the turn, sinking everything wins',
        () {
      final g = BattleshipLogic(random: Random(5));
      final shipCell = g.ships[1].first.first;
      final water =
          [for (var i = 0; i < 64; i++) i].firstWhere((i) => !g.isShip(1, i));
      expect(g.fire(shipCell), isTrue);
      expect(g.turn, 0, reason: 'hit: go again');
      expect(g.fire(shipCell), isFalse, reason: 'same square twice');
      expect(g.fire(water), isTrue);
      expect(g.turn, 1, reason: 'miss: their turn');
      // Player 2 misses, then player 1 sinks the lot.
      g.fire(
          [for (var i = 0; i < 64; i++) i].firstWhere((i) => !g.isShip(0, i)));
      for (final s in g.ships[1]) {
        for (final c in s) {
          if (!g.shots[0].contains(c)) g.fire(c);
        }
      }
      expect(g.finished, isTrue);
      expect(g.scores, [1, 0]);
    });

    test('bots sink a fleet in a sensible number of shots; online round-trip',
        () {
      final g = BattleshipLogic(random: Random(6));
      playOut(g, battleshipInfo, 2);
      expect(g.finished, isTrue);
      final winner = g.scores.indexOf(1);
      expect(g.shots[winner].length, lessThan(64),
          reason: 'hunting beats firing everywhere');
      final spec = battleshipInfo.online!;
      final guest = spec.create(2) as BattleshipLogic;
      spec.load(guest, spec.save(g), 1);
      expect(guest.ships, g.ships);
      expect(guest.shots, g.shots);
      expect(guest.finished, isTrue);
    });
  });

  group('Checkers', () {
    test('12 pieces each on dark squares; player 1 moves first, forwards only',
        () {
      final g = CheckersLogic();
      expect(g.pieces(0), 12);
      expect(g.pieces(1), 12);
      expect(g.legal.length, 7);
      expect(g.legal.every((m) => m.to ~/ 8 == m.from ~/ 8 - 1), isTrue);
    });

    CheckersLogic empty() => CheckersLogic()..board.fillRange(0, 64, 0);

    test('captures are compulsory and chain into multi-jumps', () {
      final g = empty();
      // Player 1 man at row 6 col 1; rivals at (5,2) and (3,4) with landing squares free.
      g.board[6 * 8 + 1] = 1;
      g.board[5 * 8 + 2] = 2;
      g.board[3 * 8 + 4] = 2;
      g.board[7 * 8 + 6] = 1; // another piece that could just step
      final moves = g.legal;
      expect(moves.every((m) => m.captured.isNotEmpty), isTrue,
          reason: 'must capture');
      expect(moves.single.path, [4 * 8 + 3, 2 * 8 + 5]);
      g.tap(6 * 8 + 1);
      g.tap(2 * 8 + 5);
      expect(g.pieces(1), 0);
      expect(g.finished, isTrue);
      expect(g.winner, 0);
    });

    test('reaching the far row crowns a king that moves both ways', () {
      final g = empty();
      g.board[1 * 8 + 2] = 1;
      g.board[6 * 8 + 1] = 2; // so player 2 still has a move
      g.tap(1 * 8 + 2);
      g.tap(0 * 8 + 1);
      expect(g.board[1], 3, reason: 'crowned');
      g.tap(6 * 8 + 1);
      g.tap(7 * 8 + 0);
      expect(g.turn, 0);
      expect(g.legal.map((m) => m.to).toSet(), {1 * 8 + 0, 1 * 8 + 2},
          reason: 'a king can go back down');
    });

    test('bots finish a game (win or draw); online round-trip', () {
      final g = CheckersLogic();
      playOut(g, checkersInfo, 2);
      expect(g.finished, isTrue);
      final spec = checkersInfo.online!;
      final guest = spec.create(2) as CheckersLogic;
      spec.load(guest, spec.save(g), 1);
      expect(guest.board, g.board);
      expect(guest.finished, isTrue);
      expect(guest.scores, g.scores);
    });
  });
}
