import 'dart:convert';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/features/local_games/ring_sort/ring_sort_game.dart';
import 'package:multiplayer_game/features/local_games/shell/local_game_info.dart';

void main() {
  group('Ring Sort levels', () {
    test('every level is unsorted, solvable and adds a colour up to 6', () {
      for (var level = 1; level <= 6; level++) {
        final pegs = ringLevel(42, level);
        expect(pegs.length, ringColorsFor(level) + 2);
        expect(pegsSolved(pegs), isFalse);
        expect(solveRings(pegs), isNotNull, reason: 'level $level');
      }
      expect(ringColorsFor(1), 3);
      expect(ringColorsFor(9), 6);
    });

    test('everyone in a match gets the same puzzle', () {
      final g = RingSortRace(players: 4, random: Random(3));
      for (final b in g.boards.skip(1)) {
        expect(b.pegs, g.boards.first.pegs);
      }
    });
  });

  group('moving rings', () {
    test('only onto the same colour or an empty peg, the whole top run at once',
        () {
      final pegs = [
        [0, 1, 1],
        [2, 1],
        [2, 2, 2, 0],
        <int>[],
      ];
      expect(ringsMovable(pegs, 0, 1), 2); // both 1s onto a 1
      expect(ringsMovable(pegs, 0, 3), 2);
      expect(ringsMovable(pegs, 1, 0), 1);
      expect(ringsMovable(pegs, 2, 0), 0); // 0 onto a 1
      expect(ringsMovable(pegs, 0, 2), 0); // full peg
      expect(ringsMovable(pegs, 3, 0), 0); // nothing to move
    });

    test('tap to pick, tap to drop; undo and reset', () {
      final g = RingSortRace(players: 2, random: Random(1));
      final b = g.boards[0];
      final start = copyPegs(b.pegs);
      final empty = b.pegs.indexWhere((p) => p.isEmpty);
      g.tap(0, 0);
      expect(b.selected, 0);
      g.tap(0, empty);
      expect(b.selected, isNull);
      expect(b.moves, 1);
      expect(b.pegs[empty], isNotEmpty);
      expect(g.boards[1].pegs, start, reason: 'the other player is untouched');
      g.undo(0);
      expect(b.pegs, start);
      g.tap(0, 0);
      g.tap(0, empty);
      g.tap(0, 1);
      g.tap(0, empty + 1);
      g.reset(0);
      expect(b.pegs, start);
      expect(b.moves, 0);
    });

    test('solving a board scores a level and deals the next, harder one', () {
      final g = RingSortRace(players: 2, random: Random(5));
      g.update(0);
      for (final (f, t) in solveRings(g.boards[0].pegs)!) {
        g.move(0, f, t);
      }
      expect(g.scores, [1, 0]);
      expect(g.boards[0].clearedAt, isNotNull);
      g.move(0, 0, 1); // no moves while the "cleared" banner shows
      g.update(RingSortRace.celebrateMs + 10);
      expect(g.boards[0].level, 2);
      expect(g.boards[0].pegs.length, ringColorsFor(2) + 2);
      expect(g.boards[0].moves, 0);
    });

    test('the race ends when the time runs out', () {
      final g = RingSortRace(players: 2, durationMs: 1000, random: Random(2));
      g.update(1000);
      expect(g.finished, isTrue);
      final before = copyPegs(g.boards[0].pegs);
      g.move(0, 0, before.indexWhere((p) => p.isEmpty));
      expect(g.boards[0].pegs, before);
    });
  });

  group('online', () {
    final spec = ringSortInfo.online!;

    test('a guest mirrors the host and keeps its own pick', () {
      final host = spec.create(3) as RingSortRace;
      final empty = host.boards[1].pegs.indexWhere((p) => p.isEmpty);
      spec.apply(host, 1, 'move', [1, 0, empty]);
      spec.apply(host, 0, 'move', [1, 1, empty]); // not your board: ignored
      expect(host.boards[1].moves, 1);

      final guest = spec.create(3) as RingSortRace;
      guest.isGuest = true;
      final sent = <(String, List<Object?>)>[];
      guest.sendToHost = (n, a) => sent.add((n, a));
      guest.boards[2].selected = 0;
      spec.load(guest,
          jsonDecode(jsonEncode(spec.save(host))) as Map<String, dynamic>, 2);
      expect(guest.boards[1].pegs, host.boards[1].pegs);
      expect(guest.boards[1].moves, 1);
      expect(guest.boards[2].selected, 0);

      // A guest's tap picks locally and sends only the move.
      guest.tap(2, 0); // tapping the picked peg again puts it down
      expect(guest.boards[2].selected, isNull);
      guest.tap(2, 0);
      expect(sent, isEmpty);
      guest.tap(2, empty);
      expect(sent.single.$1, 'move');
      expect(sent.single.$2, [2, 0, empty]);
    });

    test('the state stays small', () {
      final g = RingSortRace(players: 4);
      expect(jsonEncode(spec.save(g)).length, lessThan(2000));
    });
  });

  test('a computer player clears levels', () {
    final g = RingSortRace(players: 1, durationMs: 120000, random: Random(9));
    final seat = BotSeat(0, Random(9));
    for (var t = 0; t <= 120000 && !g.finished; t += 50) {
      g.update(t);
      ringSortInfo.bot!(g, seat, t);
    }
    expect(g.scores.first, greaterThanOrEqualTo(2));
  });
}
