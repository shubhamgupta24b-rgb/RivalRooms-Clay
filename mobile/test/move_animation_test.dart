import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/features/guess_person/models/gp_player.dart';
import 'package:multiplayer_game/features/local_games/checkers/checkers_game.dart';
import 'package:multiplayer_game/features/local_games/ludo/ludo_game.dart';
import 'package:multiplayer_game/features/local_games/shell/local_game_logic.dart';

/// Shows a game's online view for [g] (the same board the one-phone game uses).
Future<void> showBoard(WidgetTester tester, LocalGameLogic g,
    Widget Function(BuildContext) view) async {
  tester.view.physicalSize = const Size(411, 914);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: ListenableBuilder(
              listenable: g, builder: (context, _) => view(context)))));
}

double leftOf(WidgetTester tester, Key key) =>
    tester.widget<AnimatedPositioned>(find.byKey(key)).left!;

void main() {
  final players = defaultPlayers(2);

  testWidgets('Ludo: a token walks square by square instead of jumping',
      (tester) async {
    final g = LudoLogic(players: 2);
    g.tokens[0][0] = 2;
    await showBoard(tester, g, (c) => ludoInfo.online!.view(c, g, players, 0));
    final start = leftOf(tester, const ValueKey('tok0-0'));
    g.roll(5);
    g.move(0);
    await tester.pump();
    expect(leftOf(tester, const ValueKey('tok0-0')), closeTo(start, 5),
        reason: 'not there yet (only lifted a little)');
    final seen = <double>{};
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
      seen.add(leftOf(tester, const ValueKey('tok0-0')));
    }
    expect(seen.length, greaterThanOrEqualTo(3),
        reason: 'it visits the squares in between');
    final end = leftOf(tester, const ValueKey('tok0-0'));
    await tester.pump(const Duration(seconds: 2));
    expect(leftOf(tester, const ValueKey('tok0-0')), end,
        reason: 'and stops on its square');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Ludo: a captured token stays until the attacker lands',
      (tester) async {
    final g = LudoLogic(players: 2);
    // Player 2's token sits 4 squares ahead of player 1's on the shared track.
    g.tokens[0][0] = 3;
    final cell = g.trackIndex(0, 7)!;
    g.tokens[1][0] = (cell - g.startOf(1) + 52) % 52;
    await showBoard(tester, g, (c) => ludoInfo.online!.view(c, g, players, 0));
    final victim = leftOf(tester, const ValueKey('tok1-0'));
    g.roll(4);
    g.move(0);
    expect(g.tokens[1][0], -1);
    await tester.pump(const Duration(milliseconds: 450));
    expect(leftOf(tester, const ValueKey('tok1-0')), closeTo(victim, 5),
        reason: 'still on the board while the attacker walks');
    await tester.pump(const Duration(seconds: 2));
    expect((leftOf(tester, const ValueKey('tok1-0')) - victim).abs(),
        greaterThan(20),
        reason: 'then back to base');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Checkers: the moved piece slides over, then settles',
      (tester) async {
    final g = CheckersLogic();
    await showBoard(
        tester, g, (c) => checkersInfo.online!.view(c, g, players, 0));
    expect(find.byKey(const ValueKey('mover')), findsNothing);
    final from = 5 * 8 + 0, to = 4 * 8 + 1;
    g.tap(from);
    g.tap(to);
    await tester.pump();
    expect(find.byKey(const ValueKey('mover')), findsOneWidget,
        reason: 'drawn on its way');
    expect(find.byKey(ValueKey('p$to')), findsNothing);
    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.byKey(const ValueKey('mover')), findsNothing);
    expect(find.byKey(ValueKey('p$to')), findsOneWidget,
        reason: 'now resting on its new square');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'Checkers: a double jump stops on each square and the jumped pieces fade',
      (tester) async {
    final g = CheckersLogic()..board.fillRange(0, 64, 0);
    g.board[6 * 8 + 1] = 1;
    g.board[5 * 8 + 2] = 2;
    g.board[3 * 8 + 4] = 2;
    g.board[0 * 8 + 7] = 2;
    await showBoard(
        tester, g, (c) => checkersInfo.online!.view(c, g, players, 0));
    g.tap(6 * 8 + 1);
    g.tap(2 * 8 + 5);
    await tester.pump();
    expect(find.byKey(const ValueKey('cap0')), findsOneWidget);
    expect(find.byKey(const ValueKey('cap1')), findsOneWidget);
    final positions = <double>{};
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 320));
      if (find.byKey(const ValueKey('mover')).evaluate().isNotEmpty)
        positions.add(leftOf(tester, const ValueKey('mover')));
    }
    expect(positions.length, greaterThanOrEqualTo(2), reason: 'two hops');
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('cap0')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
