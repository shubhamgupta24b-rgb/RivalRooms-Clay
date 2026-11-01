import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Taps a widget after scrolling it into view.
Future<void> tapFound(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await tester.pump();
}

/// Sets the player count on a game intro with the - / + stepper.
Future<void> setPlayers(WidgetTester tester, int n) async {
  for (var k = 0; k < 8; k++) {
    final cur = int.parse(
        tester.widget<Text>(find.byKey(const ValueKey('playerCount'))).data!);
    if (cur == n) return;
    await tapFound(
        tester, find.byKey(ValueKey(cur < n ? 'players+' : 'players-')));
  }
  fail('could not set $n players');
}

/// Flips seat [seat]'s Person / Computer switch on a game intro.
Future<void> toggleComputer(WidgetTester tester, int seat) =>
    tapFound(tester, find.byKey(ValueKey('cpu$seat')));

/// Starts the game from its intro.
Future<void> tapStart(WidgetTester tester) =>
    tapFound(tester, find.text('Start'));

/// True on the result screen (Rematch for matches, Play again for solo games).
bool atResult() =>
    find.text('Rematch').evaluate().isNotEmpty ||
    find.text('Play again').evaluate().isNotEmpty;

/// True when the result screen names a winner or a draw.
bool hasWinnerLine() =>
    find.textContaining(' wins!', findRichText: true).evaluate().isNotEmpty ||
    find.textContaining(' win!', findRichText: true).evaluate().isNotEmpty ||
    find.text("It's a draw!").evaluate().isNotEmpty;
