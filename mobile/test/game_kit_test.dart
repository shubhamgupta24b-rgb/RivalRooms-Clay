import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/core/ui/components.dart';
import 'package:multiplayer_game/features/guess_person/models/gp_player.dart';
import 'package:multiplayer_game/features/local_games/local_games_hub_screen.dart';
import 'package:multiplayer_game/features/local_games/shell/game_art.dart';
import 'package:multiplayer_game/features/local_games/shell/result_screen.dart';

Widget app(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  test('emoji become icons or disappear from game text', () {
    expect(stripEmoji('🎯 Hit the target!'), 'Hit the target!');
    expect(stripEmoji('The wind (🌬️ at the top)'), 'The wind ( at the top)');
    expect(leadingRuleIcon('🌬️ wind'), GameIcons.wind);
    expect(leadingRuleIcon('no emoji here'), isNull);
  });

  test('every game has a drawn icon', () {
    for (final g in localGames) {
      expect(gameIcons.containsKey(g.id) || gameIconFor(g.id) != GameIcons.star,
          isTrue,
          reason: g.id);
    }
  });

  testWidgets(
      'PlayerScoreCard shows name, score and tag; out players are announced',
      (tester) async {
    await tester.pumpWidget(app(const Padding(
      padding: EdgeInsets.all(20),
      child: Row(children: [
        Expanded(
            child: PlayerScoreCard(
                seat: 0,
                name: 'Aarav',
                score: '16',
                active: true,
                tag: 'AIMING')),
        Expanded(
            child: PlayerScoreCard(
                seat: 1, name: 'Meera', score: '17', out: true)),
      ]),
    )));
    expect(find.text('AIMING'), findsOneWidget);
    expect(find.text('16'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Meera, 17.*out')), findsOneWidget);
  });

  testWidgets('PlayerScoreRow lays out 2, 4 and 6 players without overflow',
      (tester) async {
    for (final n in [2, 4, 6]) {
      await tester.pumpWidget(app(PlayerScoreRow(
          count: n,
          card: (i, compact) => PlayerScoreCard(
              seat: i,
              name: 'Player ${i + 1}',
              score: '$i',
              compact: compact))));
      expect(find.byType(PlayerScoreCard), findsNWidgets(n));
    }
  });

  testWidgets('countdown runs 3 2 1 GO, then starts the game', (tester) async {
    var done = false;
    await tester.pumpWidget(
        app(CountdownOverlay(onDone: () => done = true, color: Colors.blue)));
    expect(find.text('3'), findsOneWidget);
    await tester.pump(CountdownOverlay.step);
    expect(find.text('2'), findsOneWidget);
    await tester.pump(CountdownOverlay.step * 2);
    expect(find.text('GO'), findsOneWidget);
    await tester.pump(CountdownOverlay.go + const Duration(milliseconds: 50));
    expect(done, isTrue);
  });

  testWidgets('FeedbackLayer pops a score and clears it', (tester) async {
    await tester.pumpWidget(app(FeedbackLayer(
        child: Builder(
            builder: (context) => TextButton(
                onPressed: () => GameFeedback.of(context)!.pop('+10'),
                child: const Text('hit'))))));
    await tester.tap(find.text('hit'));
    await tester.pump();
    expect(find.text('+10'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('+10'), findsNothing);
  });

  testWidgets('result screen: winner line, ranked rows and the three buttons',
      (tester) async {
    final game = localGames.firstWhere((g) => g.id == 'archery');
    final players = [
      GpPlayer(name: 'Aarav', color: gpPlayerColors[0], score: 40),
      GpPlayer(name: 'Meera', color: gpPlayerColors[1], score: 46)
    ];
    final extras = ResultExtras()..subtitle = '46 – 40 · 5 arrows each';
    await tester.pumpWidget(app(ResultScreen(
        game: game,
        players: players,
        extras: extras,
        onRematch: () {},
        onChangePlayers: () {},
        onExit: () {})));
    await tester.pump(const Duration(seconds: 3));
    expect(
        find.textContaining('Meera wins!', findRichText: true), findsWidgets);
    expect(find.text('46 – 40 · 5 arrows each'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Place 1, Meera')), findsOneWidget);
    for (final b in ['Rematch', 'Change players', 'Home']) {
      expect(find.text(b), findsOneWidget);
    }
  });
}
