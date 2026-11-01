import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/features/local_games/local_games_hub_screen.dart';
import 'package:multiplayer_game/features/local_games/shell/local_game_info.dart';
import 'package:multiplayer_game/features/local_games/shell/local_game_shell.dart';
import 'shell_helpers.dart';

Future<void> tapText(WidgetTester tester, String text) async {
  // The intro numbers its how-to-play steps 1, 2, 3…; the player picker comes after them.
  final f = find.text(text).last;
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
}

/// Games that end on their own (timer) within about 30 seconds. (Snake Duel with nobody
/// steering is a tie every round, which correctly never ends the match.)
const selfFinishing = {
  'crush_it',
  'basketball_hoops',
  'fruit_duel',
  'paint_fight'
};

/// Opens a game, optionally picks the player count, plays it for a while with taps
/// all over the screen, and checks for layout overflow (any overflow fails the test).
/// Self-finishing games are played to the result screen and restarted with Play Again.
Future<void> playThrough(
    WidgetTester tester, LocalGameInfo game, Size size, int players) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(home: LocalGameShell(game: game)));
  expect(find.text(game.title), findsOneWidget);
  if (players > 2) await setPlayers(tester, players);
  // Games with a take-turns mode: these play-throughs cover the split screen (turns have their own test).
  if (find.text('Split screen').evaluate().isNotEmpty) {
    await tapText(tester, 'Split screen');
    await tester.pump();
  }
  await tapStart(tester);
  await tester.pump(const Duration(milliseconds: 2600)); // 3-2-1-GO
  await tester.pump(const Duration(milliseconds: 300));

  // Tap around the screen: both halves, both sides.
  for (var i = 0; i < 8; i++) {
    // A solo game can end early: stop tapping before a stray tap hits ALL GAMES.
    if (atResult()) break;
    await tester.tapAt(Offset(size.width * (0.15 + 0.23 * (i % 4)),
        size.height * (i.isEven ? 0.8 : 0.2)));
    await tester.pump(const Duration(milliseconds: 400));
  }
  // A way out is always on screen (solo games may already be over: then it's the score screen).
  expect(find.byType(PauseButton).evaluate().isNotEmpty || atResult(), isTrue);

  if (!selfFinishing.contains(game.id)) {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    return;
  }
  await tester.pump(const Duration(seconds: 31)); // longer than any timed game
  await tester.pump(const Duration(seconds: 1)); // result delay
  await tester.pump(const Duration(milliseconds: 400));
  expect(hasWinnerLine(), isTrue);
  expect(find.text('Change players'), findsOneWidget);

  await tapText(tester, 'Rematch');
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 2800));
  expect(atResult(), isFalse, reason: 'new match running');

  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  const sizes = {
    'small phone': Size(320, 568),
    'phone': Size(411, 914),
    'tablet': Size(800, 1280)
  };

  testWidgets('hub lists all games with their player counts', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LocalGamesHubScreen()));
    expect(find.text('71 games'), findsOneWidget,
        reason: 'the count includes local games and the two built-in games');
    expect(find.text('Guess the Person'), findsOneWidget);
    expect(find.text('Raja Mantri Chor Sipahi'), findsOneWidget);
    expect(find.text('Smash Karts'), findsNothing);
  });
  testWidgets('player count picker only offers what a game supports',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: LocalGameShell(
            game: localGames.firstWhere((g) => g.id == 'math_duel'))));
    expect(find.text('PLAYERS'), findsOneWidget);
    await setPlayers(tester, 4);
    expect(tester.widget<Text>(find.byKey(const ValueKey('playerCount'))).data,
        '4');
    await tapFound(tester, find.byKey(const ValueKey('players+')));
    expect(tester.widget<Text>(find.byKey(const ValueKey('playerCount'))).data,
        '4',
        reason: 'Math Duel stops at 4');
    await tester.pumpWidget(MaterialApp(
        home: LocalGameShell(
            game: localGames.firstWhere((g) => g.id == 'tic_tac_toe'))));
    expect(find.byKey(const ValueKey('players+')), findsNothing,
        reason: '2 players only: no count stepper');
  });

  for (final players in [2, 4]) {
    testWidgets(
        'Basketball: swiping straight up at the still hoop is a swish ($players players)',
        (tester) async {
      tester.view.physicalSize = sizes['phone']!;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
          home: LocalGameShell(
              game: localGames.firstWhere((g) => g.id == 'basketball_hoops'))));
      if (players > 2) await setPlayers(tester, players);
      await tester.pump();
      await tapText(
          tester, 'Split screen'); // this test is about the split screen
      await tester.pump();
      await tapStart(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2800));
      expect(find.text('Swipe up to shoot'), findsNWidgets(players));

      // Player 1's zone: bottom half (2 players) or top-left, sideways (4 players).
      final ball =
          players == 2 ? const Offset(205, 840) : const Offset(35, 228);
      final up = players == 2 ? const Offset(0, -250) : const Offset(150, 0);
      final down = players == 2 ? const Offset(0, 250) : const Offset(-150, 0);
      await tester.dragFrom(ball, up);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('+3 SWISH!'), findsOneWidget);
      expect(find.text('Swipe up to shoot'), findsNWidgets(players - 1));

      // Swiping the wrong way does nothing.
      await tester.pump(const Duration(seconds: 1));
      await tester.dragFrom(ball + up / 2, down);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('MISS'), findsNothing);
      expect(find.text('+3 SWISH!'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });
  }

  for (final size in sizes.entries) {
    for (final game in localGames) {
      testWidgets('${game.title} plays through on ${size.key}',
          (tester) => playThrough(tester, game, size.value, 2));
    }
  }

  // Every player count on a small and a normal phone for the multi-player games.
  for (final game in localGames.where((g) => g.maxPlayers > 2)) {
    for (var n = max(3, game.minPlayers); n <= game.maxPlayers; n++) {
      for (final size in [sizes['small phone']!, sizes['phone']!]) {
        testWidgets(
            '${game.title} with $n players on ${size.width.toInt()}x${size.height.toInt()}',
            (tester) => playThrough(tester, game, size, n));
      }
    }
  }
}
