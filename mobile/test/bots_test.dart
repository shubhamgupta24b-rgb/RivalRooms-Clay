import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/features/local_games/air_hockey/air_hockey_game.dart';
import 'package:multiplayer_game/features/local_games/crush_it/crush_it_game.dart';
import 'package:multiplayer_game/features/local_games/fruit_duel/fruit_duel_game.dart';
import 'package:multiplayer_game/features/local_games/memory/memory_game.dart';
import 'package:multiplayer_game/features/local_games/paint_fight/paint_fight_game.dart';
import 'package:multiplayer_game/features/local_games/tic_tac_toe/tic_tac_toe_game.dart';
import 'package:multiplayer_game/features/local_games/widgets/dice.dart';
import 'package:multiplayer_game/features/local_games/local_games_hub_screen.dart';
import 'package:multiplayer_game/features/local_games/shell/local_game_info.dart';
import 'package:multiplayer_game/features/local_games/shell/local_game_logic.dart';
import 'package:multiplayer_game/features/local_games/shell/local_game_shell.dart';
import 'shell_helpers.dart';

/// Runs a game with computer players in [seats] for up to [limitMs] of game time.
LocalGameLogic simulate(String id,
    {required int players,
    List<int>? seats,
    int limitMs = 600000,
    int seed = 1}) {
  final game = localGames.firstWhere((g) => g.id == id);
  // Same constructors the games use (no network involved).
  final g = switch (id) {
    'memory' => MemoryLogic(players: players),
    'crush_it' => CrushItLogic(players: players, durationMs: 30000),
    'fruit_duel' => FruitDuelLogic(players: players),
    'paint_fight' => PaintFightLogic(players: players),
    _ => game.online!.create(players),
  };
  final bots = [
    for (final s in seats ?? List.generate(players, (i) => i))
      BotSeat(s, Random(seed * 31 + s))
  ];
  for (var t = 0; t <= limitMs && !g.finished; t += 16) {
    g.update(t);
    for (final b in bots) {
      game.bot!(g, b, t);
    }
  }
  return g;
}

void main() {
  test(
      'every game that can be played against someone has a bot (except the talking games)',
      () {
    final withBots = {
      for (final g in localGames)
        if (g.bot != null) g.id
    };
    expect(withBots, {
      'colour_clash', 'ludo', 'snakes_ladders', 'dots_boxes', 'tic_tac_toe',
      'connect_four', 'hand_cricket', 'quiz_battle', 'math_duel', //
      'reaction_tap',
      'basketball_hoops',
      'memory',
      'paint_fight',
      'air_hockey',
      'ping_pong',
      'rock_paper_scissors',
      'fruit_merge_battle',
      'bingo',
      'battleship',
      'checkers',
      'mini_golf', 'slingshot', 'archery', 'shooting_gallery', 'bottle_smash',
      'chess', 'tug_of_war', 'darts', 'hot_potato', 'knife_hit', 'cup_pong',
      'hungry_hippos', 'penguin_push', 'ring_sort',
    });
  });

  group('bots play whole games to the end', () {
    for (final (id, players, limit) in [
      ('tic_tac_toe', 2, 60000),
      ('connect_four', 2, 200000),
      ('dots_boxes', 3, 300000),
      ('snakes_ladders', 4, 1800000),
      ('ludo', 2, 3600000),
      ('colour_clash', 4, 3600000),
      ('hand_cricket', 2, 300000),
      ('quiz_battle', 3, 600000),
      ('math_duel', 2, 600000),
      ('reaction_tap', 4, 600000),
      ('memory', 3, 900000),
      ('basketball_hoops', 4, 31000),
      ('paint_fight', 2, 31000),
      ('ping_pong', 2, 1200000),
      ('rock_paper_scissors', 4, 600000),
      ('mini_golf', 2, 1200000),
      ('slingshot', 3, 900000),
      ('archery', 4, 600000),
      ('shooting_gallery', 2, 200000),
      ('bottle_smash', 3, 600000),
    ]) {
      test('$id with $players computer players', () {
        final g = simulate(id, players: players, limitMs: limit);
        expect(g.finished, isTrue, reason: '$id should reach the end');
        // Two good bots can draw Tic-Tac-Toe / Connect Four; everything else always has points.
        if (id != 'tic_tac_toe' && id != 'connect_four')
          expect(g.scores.reduce((a, b) => a + b), greaterThan(0),
              reason: 'somebody scored');
      });
    }
  });

  test(
      'air hockey computer: scores, keeps the puck on the table, never leaves it stuck',
      () {
    final game = localGames.firstWhere((g) => g.id == 'air_hockey');
    for (var seed = 1; seed <= 3; seed++) {
      final g = AirHockeyLogic(durationMs: 120000);
      final b = BotSeat(1, Random(seed));
      var still = 0, longestStill = 0;
      for (var t = 0; t <= 120000 && !g.finished; t += 16) {
        g.update(t);
        game.bot!(g, b, t);
        final mouth = (g.puck.x - 0.5).abs() < AirHockeyLogic.goalHalf;
        expect(
            g.puck.x,
            inInclusiveRange(
                AirHockeyLogic.puckR - 1e-9, 1 - AirHockeyLogic.puckR + 1e-9),
            reason: 'seed $seed t=$t');
        if (!mouth)
          expect(
              g.puck.y,
              inInclusiveRange(AirHockeyLogic.puckR - 1e-9,
                  AirHockeyLogic.length - AirHockeyLogic.puckR + 1e-9),
              reason: 'seed $seed t=$t');
        // Only the computer's own half counts: the idle human never plays a puck on theirs.
        still = g.vel.length < 0.05 &&
                !g.paused &&
                g.puck.y < AirHockeyLogic.length / 2
            ? still + 16
            : 0;
        longestStill = max(longestStill, still);
      }
      expect(g.goals[1], greaterThan(0), reason: 'seed $seed');
      expect(longestStill, lessThan(5000),
          reason: 'seed $seed: puck sat still for ${longestStill}ms');
    }
  });

  test('bots only move on their own turn (tic-tac-toe against an idle human)',
      () {
    final g = simulate('tic_tac_toe', players: 2, seats: [1], limitMs: 20000);
    // The human (X, seat 0) never moved, and X starts: so the bot never got a turn.
    expect((g as TicTacToeLogic).cells.where((c) => c >= 0), isEmpty);
  });

  testWidgets('VS COMPUTER: you are Player 1, the computer plays the rest',
      (tester) async {
    tester.view.physicalSize = const Size(411, 914);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        home: LocalGameShell(
            game: localGames.firstWhere((g) => g.id == 'snakes_ladders'))));
    await toggleComputer(tester, 1);
    expect(find.text('CPU 1'), findsOneWidget,
        reason: 'seat 2 is the computer');
    expect(find.text('You'), findsOneWidget, reason: 'the one person is "You"');
    await tapStart(tester);
    await tester.pump(const Duration(milliseconds: 2800));
    expect(find.text('Your roll'), findsOneWidget, reason: 'seat 0 is "You"');
    await tester.tap(find.byType(RollingDice));
    await tester.pump();
    // The computer takes its own turn a moment later.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('CPU 1'), findsOneWidget,
        reason: 'the computer has its own seat in the HUD');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('VS COMPUTER: choose how many bots; people take the first seats',
      (tester) async {
    tester.view.physicalSize = const Size(411, 914);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        home: LocalGameShell(
            game: localGames.firstWhere((g) => g.id == 'snakes_ladders'))));
    await setPlayers(tester, 5);
    await toggleComputer(tester, 1);
    for (var n = 1; n <= 4; n++) {
      expect(find.text('CPU $n'), findsOneWidget,
          reason: 'switching seat 2 on makes every later seat the computer');
    }
    expect(find.byKey(const ValueKey('cpu0')), findsNothing,
        reason: 'seat 1 is always a person');
    await toggleComputer(
        tester, 2); // seat 3 back to a person: 3 people + 2 computers
    expect(find.text('CPU 2'), findsOneWidget);
    expect(find.text('CPU 3'), findsNothing);
    expect(find.text('Player 3'), findsOneWidget);
    // Fewer players keeps the bots within the seats left.
    await setPlayers(tester, 3);
    expect(find.text('You'), findsOneWidget);
    expect(find.text('CPU 2'), findsOneWidget);
    await setPlayers(tester, 4);
    await toggleComputer(tester, 2); // 3 people + 1 computer
    expect(find.text('CPU 1'), findsOneWidget);
    expect(find.text('CPU 2'), findsNothing);
    await tapStart(tester);
    await tester.pump(const Duration(milliseconds: 2800));
    expect(find.text("Player 1's roll"), findsOneWidget,
        reason: 'people are named Player 1-3, not "You"');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('games without bots (talking games) have no VS COMPUTER switch',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: LocalGameShell(
            game: localGames.firstWhere((g) => g.id == 'find_spy'))));
    expect(find.byKey(const ValueKey('cpu1')), findsNothing);
  });
}
