import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/features/local_games/local_games_hub_screen.dart';
import 'package:multiplayer_game/games/game_catalog.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpHub(WidgetTester tester,
    [Map<String, Object> prefs = const {}]) async {
  tester.view.physicalSize = const Size(411, 914);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(prefs);
  await tester.pumpWidget(const MaterialApp(home: LocalGamesHubScreen()));
  await tester.pumpAndSettle();
}

/// The sideways row of category chips.
Finder chips() => find
    .descendant(
        of: find.byType(ListView).first, matching: find.byType(Scrollable))
    .first;

void main() {
  test('Smash Karts is absent from online and local game catalogs', () {
    expect(gameCatalog.any((game) => game.id == 'smash_karts'), isFalse);
    expect(localGames.any((game) => game.id == 'smash_karts'), isFalse);
  });

  testWidgets('Smash Karts cannot be found from the local games screen',
      (tester) async {
    await pumpHub(tester);
    await tester.enterText(find.byType(TextField), 'Smash Karts');
    await tester.pump();
    expect(find.textContaining('No games match'), findsOneWidget);
  });

  testWidgets('search finds games by name or description', (tester) async {
    await pumpHub(tester);
    await tester.enterText(find.byType(TextField), 'ludo');
    await tester.pump();
    expect(find.text('Ludo'), findsOneWidget);
    expect(find.text('Bingo'), findsNothing);
    await tester.enterText(find.byType(TextField), 'Colour Clash');
    await tester.pump();
    expect(find.text('Colour Clash'), findsWidgets);
    await tester.enterText(
        find.byType(TextField), 'watermelon'); // in Fruit Merge's description
    await tester.pump();
    expect(find.text('Fruit Merge'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pump();
    expect(find.textContaining('No games match'), findsOneWidget);
  });

  testWidgets('categories: solo shows only solo games, cards only card games',
      (tester) async {
    await pumpHub(tester);
    // The chips scroll sideways: swipe to the last one.
    await tester.ensureVisible(find.text('Solo'));
    await tester.pump();
    await tester.tap(find.text('Solo'));
    await tester.pump();
    expect(find.text('PLAY TOGETHER'), findsNothing);
    expect(find.text('2048'), findsOneWidget);
    expect(find.text('Ludo'), findsNothing);
    await tester.ensureVisible(find.text('Cards'));
    await tester.pump();
    await tester.tap(find.text('Cards'));
    await tester.pump();
    expect(find.text('Raja Mantri Chor Sipahi'), findsOneWidget);
    expect(find.text('Ludo'), findsNothing);
  });

  testWidgets('long-press stars a favourite; the Favourites chip lists it',
      (tester) async {
    await pumpHub(tester);
    await tester.ensureVisible(find.text('Favourites'));
    await tester.pump();
    await tester.tap(find.text('Favourites'));
    await tester.pump();
    expect(find.textContaining('No favourites yet'), findsOneWidget);
    await tester.ensureVisible(find.text('All'));
    await tester.pump();
    await tester.tap(find.text('All'));
    await tester.pump();
    await tester.ensureVisible(find.text('Ludo'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Ludo'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Unstar Ludo'), findsOneWidget);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Favourites'));
    await tester.pump();
    await tester.tap(find.text('Favourites'));
    await tester.pump();
    expect(find.text('Ludo'), findsOneWidget);
    expect(find.text('Colour Clash'), findsNothing);
  });

  testWidgets('recently played games come first', (tester) async {
    await pumpHub(tester, {
      'recent_games': ['bingo', 'ludo']
    });
    expect(find.text('RECENTLY PLAYED'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Play .* again\$')), findsNWidgets(2));
  });
}
