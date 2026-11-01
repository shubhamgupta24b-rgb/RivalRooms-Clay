import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/features/local_games/local_games_hub_screen.dart';
import 'package:multiplayer_game/features/local_games/shell/local_game_shell.dart';
import 'shell_helpers.dart';

Future<void> tapText(WidgetTester tester, String text) async {
  final f = find.text(text).last;
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await tester.pump();
}

void main() {
  const turnGames = {'fruit_merge_battle', 'basketball_hoops', 'ring_sort'};

  test('the score-race games offer take turns; head-to-head games do not', () {
    expect({
      for (final g in localGames)
        if (g.turns != null) g.id
    }, turnGames);
  });

  for (final id in turnGames) {
    test('$id: a computer turn is played instantly and scores', () {
      final spec = localGames.firstWhere((g) => g.id == id).turns!;
      final scores = [
        for (var seed = 0; seed < 3; seed++) spec.simulate(60000, Random(seed))
      ];
      expect(scores.any((s) => s > 0), isTrue,
          reason: 'bots score in a 1-minute turn: $scores');
    });
  }

  testWidgets(
      'take turns: full screen for each person, bots instantly, then results',
      (tester) async {
    tester.view.physicalSize = const Size(411, 914);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        home: LocalGameShell(
            game: localGames.firstWhere((g) => g.id == 'fruit_merge_battle'))));
    // 3 players: 2 people and 1 computer player, 1 minute each.
    await setPlayers(tester, 3);
    await toggleComputer(tester, 2);
    expect(find.text('CPU 1'), findsOneWidget);
    expect(find.text('Take turns'), findsOneWidget);
    expect(find.text('1 min'), findsOneWidget);
    await tapStart(tester);

    // Player 1's turn: the pass screen, then the whole box.
    expect(find.text('PLAYER 1'), findsOneWidget);
    expect(find.textContaining('1 min on the whole screen'), findsOneWidget);
    await tapText(tester, 'START');
    expect(find.text('1:00'), findsOneWidget,
        reason: 'a full-screen turn with its clock');
    for (var i = 0; i < 5; i++) {
      await tester.tapAt(const Offset(200, 500)); // drop fruit
      await tester.pump(const Duration(milliseconds: 600));
    }
    await tester.pump(const Duration(seconds: 61));
    await tester.pump(
        const Duration(seconds: 1)); // the turn shows its end for a moment
    await tester.pump();
    expect(find.text("PLAYER 1'S SCORE"), findsOneWidget);
    expect(find.text('Next up: Player 2'), findsOneWidget);

    // Player 2.
    await tapText(tester, 'NEXT PLAYER');
    expect(find.text('PLAYER 2'), findsOneWidget);
    await tapText(tester, 'START');
    await tester.pump(const Duration(seconds: 61));
    await tester.pump(
        const Duration(seconds: 1)); // the turn shows its end for a moment
    await tester.pump();
    expect(find.text("PLAYER 2'S SCORE"), findsOneWidget);

    // The computer's turn happens instantly, then the results.
    await tapText(tester, 'SEE RESULTS');
    await tester.pump(const Duration(milliseconds: 500));
    expect(hasWinnerLine(), isTrue);
    expect(find.text('CPU 1'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('choosing a time changes every turn\'s clock', (tester) async {
    tester.view.physicalSize = const Size(411, 914);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        home: LocalGameShell(
            game: localGames.firstWhere((g) => g.id == 'basketball_hoops'))));
    await tapText(tester, '3 min');
    await tapStart(tester);
    expect(find.textContaining('3 min on the whole screen'), findsOneWidget);
    await tapText(tester, 'START');
    expect(find.text('3:00'), findsOneWidget);
    expect(find.text('Swipe up to shoot'), findsOneWidget,
        reason: 'one big court, not two halves');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
