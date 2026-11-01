import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/features/local_games/chess/chess_game.dart';
import 'package:multiplayer_game/features/local_games/cup_pong/cup_pong_game.dart';
import 'package:multiplayer_game/features/local_games/darts/darts_game.dart';
import 'package:multiplayer_game/features/local_games/hot_potato/hot_potato_game.dart';
import 'package:multiplayer_game/features/local_games/hungry_hippos/hungry_hippos_game.dart';
import 'package:multiplayer_game/features/local_games/knife_hit/knife_hit_game.dart';
import 'package:multiplayer_game/features/local_games/penguin_push/penguin_push_game.dart';
import 'package:multiplayer_game/features/local_games/shell/local_game_info.dart';
import 'package:multiplayer_game/features/local_games/shell/local_game_logic.dart';
import 'package:multiplayer_game/features/local_games/tug_of_war/tug_of_war_game.dart';

int sq(String s) => (8 - int.parse(s[1])) * 8 + 'abcdefgh'.indexOf(s[0]);

void move(ChessLogic g, String from, String to) {
  g.tap(sq(from));
  g.tap(sq(to));
}

LocalGameLogic runBots(
    LocalGameInfo info, LocalGameLogic g, int players, int limitMs) {
  final bots = [for (var s = 0; s < players; s++) BotSeat(s, Random(7 + s))];
  for (var t = 0; t <= limitMs && !g.finished; t += 16) {
    g.update(t);
    for (final b in bots) {
      info.bot!(g, b, t);
    }
  }
  return g;
}

void main() {
  group('chess rules', () {
    test("fool's mate is checkmate for player 2", () {
      final g = ChessLogic();
      move(g, 'f2', 'f3');
      move(g, 'e7', 'e5');
      move(g, 'g2', 'g4');
      move(g, 'd8', 'h4');
      expect(g.end, ChessEnd.checkmate);
      expect(g.winner, 1);
      expect(g.scores, [0, 1]);
    });

    test('castling moves the rook, and is gone after the king moves', () {
      final g = ChessLogic();
      for (final (a, b) in [
        ('e2', 'e4'),
        ('e7', 'e5'),
        ('g1', 'f3'),
        ('b8', 'c6'),
        ('f1', 'c4'),
        ('g8', 'f6')
      ]) {
        move(g, a, b);
      }
      expect(g.legal.any((m) => m.castle), isTrue);
      move(g, 'e1', 'g1');
      expect(g.pos.board[sq('g1')], Piece.make(Piece.king, 0));
      expect(g.pos.board[sq('f1')], Piece.make(Piece.rook, 0));
      expect(g.pos.castling.take(2), [false, false]);
    });

    test('en passant captures the pawn that skipped past', () {
      final g = ChessLogic();
      for (final (a, b) in [
        ('e2', 'e4'),
        ('a7', 'a6'),
        ('e4', 'e5'),
        ('d7', 'd5')
      ]) {
        move(g, a, b);
      }
      move(g, 'e5', 'd6');
      expect(g.pos.board[sq('d5')], 0);
      expect(g.taken[0], [Piece.pawn]);
    });

    test('you cannot move into check', () {
      final g = ChessLogic();
      for (final (a, b) in [('e2', 'e4'), ('f7', 'f5'), ('d1', 'h5')]) {
        move(g, a, b);
      }
      expect(g.check, isTrue);
      expect(
          g.legal.every((m) => !(g.pos.copy()..apply(m)).inCheck(1)), isTrue);
    });

    test('stalemate position has no moves and no check', () {
      final b = List.filled(64, 0);
      b[sq('a8')] = Piece.make(Piece.king, 1);
      b[sq('b6')] = Piece.make(Piece.queen, 0);
      b[sq('h1')] = Piece.make(Piece.king, 0);
      final p = ChessPosition(b, [false, false, false, false], null);
      expect(p.legal(1), isEmpty);
      expect(p.inCheck(1), isFalse);
    });
  });

  test('darts scoring', () {
    expect(DartsLogic.score(Offset.zero).points, 50);
    expect(DartsLogic.score(const Offset(0, -0.1)).points, 25);
    expect(DartsLogic.score(const Offset(0, -0.58)).label, 'T20');
    expect(DartsLogic.score(const Offset(0, -0.95)).label, 'D20');
    expect(DartsLogic.score(const Offset(0, 0.4)).points,
        3); // the 3 is straight down
    expect(DartsLogic.score(const Offset(0, 1.2)).points, 0);
  });

  test('tug of war: pulling over the line wins', () {
    final g = TugOfWarLogic();
    for (var k = 0; k < 40; k++) {
      g.update(100 + (k + 1) * 90);
      g.pull(1);
    }
    expect(g.winner, 1);
    expect(g.scores, [0, 1]);
  });

  test('knife hit: a spot taken by a knife bounces, a clear one sticks', () {
    final g = KnifeHitLogic(random: Random(1));
    g.update(16);
    g.stuck[0]
      ..clear()
      ..add(g.impactAngle(0));
    expect(g.wouldBounce(0), isTrue);
    g.stuck[0]
      ..clear()
      ..add(g.impactAngle(0) + 1.5);
    expect(g.wouldBounce(0), isFalse);
  });

  group('the computer finishes every new game', () {
    for (final (info, make, players, limit)
        in <(LocalGameInfo, LocalGameLogic Function(int), int, int)>[
      (chessInfo, (_) => ChessLogic(), 2, 3600000),
      (tugOfWarInfo, (_) => TugOfWarLogic(), 2, 40000),
      (dartsInfo, (n) => DartsLogic(players: n, random: Random(3)), 3, 900000),
      (
        hotPotatoInfo,
        (n) => HotPotatoLogic(players: n, random: Random(3)),
        4,
        300000
      ),
      (
        knifeHitInfo,
        (n) => KnifeHitLogic(players: n, random: Random(3)),
        4,
        60000
      ),
      (cupPongInfo, (_) => CupPongLogic(random: Random(3)), 2, 900000),
      (
        hungryHipposInfo,
        (n) => HungryHipposLogic(players: n, random: Random(3)),
        4,
        60000
      ),
      (
        penguinPushInfo,
        (n) => PenguinPushLogic(players: n, random: Random(3)),
        3,
        900000
      ),
    ]) {
      test(info.id, () {
        final g = runBots(info, make(players), players, limit);
        expect(g.finished, isTrue, reason: '${info.id} did not finish');
        expect(g.scores.length, players);
      });
    }
  });
}
