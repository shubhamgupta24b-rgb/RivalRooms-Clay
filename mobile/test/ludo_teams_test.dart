import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/features/local_games/local_games_hub_screen.dart';
import 'package:multiplayer_game/features/local_games/ludo/ludo_game.dart';
import 'package:multiplayer_game/features/local_games/shell/bots.dart';
import 'package:multiplayer_game/features/local_games/shell/local_game_shell.dart';
import 'shell_helpers.dart';

void main() {
  test('teams only with 4 players; 1+3 vs 2+4', () {
    expect(LudoLogic(players: 2, teams: true).teams, isFalse);
    final g = LudoLogic(players: 4, teams: true);
    expect(g.teams, isTrue);
    expect(g.sameTeam(0, 2), isTrue);
    expect(g.sameTeam(1, 3), isTrue);
    expect(g.sameTeam(0, 1), isFalse);
    expect(LudoLogic(players: 4).sameTeam(0, 2), isFalse,
        reason: 'free-for-all has no teams');
  });

  test('partners do not capture each other, rivals still do', () {
    final g = LudoLogic(players: 4, teams: true);
    // Player 3 (seat 2) sits on the square player 1 (seat 0) is about to land on.
    final target = 10; // player 1's progress
    final cell = g.trackIndex(0, target)!;
    final partnerProgress = (cell - g.startOf(2) + 52) % 52;
    g.tokens[2][0] = partnerProgress;
    g.tokens[0][0] = target - 3;
    g.roll(3);
    expect(g.move(0), isTrue);
    expect(g.tokens[2][0], partnerProgress, reason: 'partner token stays put');

    // The same move onto a rival (player 2, seat 1) captures it.
    final h = LudoLogic(players: 4, teams: true);
    final rivalProgress = (cell - h.startOf(1) + 52) % 52;
    h.tokens[1][0] = rivalProgress;
    h.tokens[0][0] = target - 3;
    h.roll(3);
    h.move(0);
    expect(h.tokens[1][0], -1, reason: 'rival sent back to base');
  });

  test('all your tokens home: you move your partner\'s; the team wins together',
      () {
    final g = LudoLogic(players: 4, teams: true);
    g.tokens[0].setAll(0,
        [LudoLogic.home, LudoLogic.home, LudoLogic.home, LudoLogic.home - 2]);
    g.roll(2);
    expect(g.move(3), isTrue);
    expect(g.finished, isFalse, reason: 'partner still has tokens out');
    expect(g.message, contains('partner'));
    // Bringing a token home gives another roll; now player 1 moves player 3's tokens.
    expect(g.turn, 0);
    expect(g.mover, 2);
    g.tokens[2].setAll(0,
        [LudoLogic.home, LudoLogic.home, LudoLogic.home, LudoLogic.home - 4]);
    g.roll(4);
    expect(g.movable, [3]);
    expect(g.move(3), isTrue);
    expect(g.finished, isTrue);
    expect(g.scores, [1, 0, 1, 0], reason: 'both partners win');
  });

  test('without teams, finishing alone still wins', () {
    final g = LudoLogic(players: 4);
    g.tokens[0].setAll(0,
        [LudoLogic.home, LudoLogic.home, LudoLogic.home, LudoLogic.home - 1]);
    g.roll(1);
    g.move(3);
    expect(g.scores, [1, 0, 0, 0]);
  });

  test('four bots finish a team game', () {
    final g = LudoLogic(players: 4, teams: true, random: Random(3));
    final bots = [for (var i = 0; i < 4; i++) BotSeat(i, Random(i))];
    final turn = ludoTeamsInfo.bot!;
    for (var t = 0; t < 4 * 3600000 && !g.finished; t += 50) {
      for (final b in bots) {
        turn(g, b, t);
      }
    }
    expect(g.finished, isTrue);
    final s = g.scores;
    expect(s.where((x) => x == 1).length, 2);
    expect(s[0] == s[2] && s[1] == s[3], isTrue, reason: 'a whole team wins');
  });

  test('online: team flag and partner moves survive the trip to a guest', () {
    final spec = ludoTeamsInfo.online!;
    final host = spec.create(4) as LudoLogic;
    expect(host.teams, isTrue);
    host.tokens[0].setAll(
        0, [LudoLogic.home, LudoLogic.home, LudoLogic.home, LudoLogic.home]);
    final guest = spec.create(4) as LudoLogic;
    spec.load(guest, spec.save(host), 2);
    expect(guest.mover, 2,
        reason: 'the guest knows player 1 now moves player 3');
  });

  testWidgets(
      'the TEAMS switch shows with 4 players and the result names both winners',
      (tester) async {
    tester.view.physicalSize = const Size(411, 914);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        home: LocalGameShell(
            game: localGames.firstWhere((g) => g.id == 'ludo'))));
    expect(find.text('Teams 2 vs 2'), findsNothing,
        reason: '2 players: no teams');
    await setPlayers(tester, 4);
    await tapFound(tester, find.text('Teams 2 vs 2'));
    expect(find.text('Player 1 + Player 3 vs Player 2 + Player 4'),
        findsOneWidget);
    await tapStart(tester);
    await tester.pump(const Duration(milliseconds: 2800));
    expect(find.text('TEAM A'), findsNWidgets(2),
        reason: 'team tags on the score cards');
    expect(find.text('TEAM B'), findsNWidgets(2));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
