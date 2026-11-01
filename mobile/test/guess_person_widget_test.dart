import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/features/guess_person/logic/gp_settings.dart';
import 'package:multiplayer_game/features/guess_person/screens/guess_person_game_screen.dart';
import 'package:multiplayer_game/features/guess_person/screens/guess_person_menu_screen.dart';
import 'package:multiplayer_game/features/guess_person/widgets/game_header.dart';

/// Scrolls the target into view first, like a player would on a small screen.
Future<void> tapText(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
}

/// Plays a round at phone and tablet sizes to catch layout overflows.
void main() {
  const sizes = {
    'small phone': Size(320, 568),
    'phone': Size(411, 914),
    'tablet': Size(800, 1280)
  };

  for (final e in sizes.entries) {
    testWidgets('full round renders without overflow on ${e.key}',
        (tester) async {
      tester.view.physicalSize = e.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: GuessPersonMenuScreen()));
      await tapText(tester, find.text('PLAY'));
      await tester.pumpAndSettle();

      await tapText(tester, find.text('START CHOOSING'));
      await tester.pumpAndSettle();
      expect(find.text('Choose your\ncharacter!'), findsOneWidget);

      await tapText(tester, find.text('RANDOM'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Selected: '), findsOneWidget,
          reason: 'named even if the card is scrolled away');
      await tapText(tester, find.text('CONFIRM'));
      await tester.pumpAndSettle();
      await tapText(tester, find.text('CONFIRM PERSON'));
      await tester.pumpAndSettle();

      expect(find.text('PERSON SELECTED'), findsOneWidget);
      expect(find.text('SELECTED'), findsNothing);
      await tapText(tester, find.text("I'M READY"));
      await tester.pumpAndSettle();

      expect(find.text('MAKE FINAL GUESS'), findsOneWidget);
      expect(find.text('SELECTED'), findsNothing);
      // Questions live inside category tiles.
      expect(find.text('Choose your\ncharacter!'), findsNothing);
      for (final cat in [
        'GENDER',
        'EYE COLOR',
        'HAIR',
        'HAIR COLOR',
        'SKIN TONE',
        'ACCESSORIES',
        'FACIAL HAIR'
      ]) {
        expect(find.text(cat), findsOneWidget, reason: cat);
      }
      await tapText(tester, find.text('ACCESSORIES'));
      await tester.pumpAndSettle();
      await tapText(tester, find.text('GLASSES'));
      await tester.pumpAndSettle();
      expect(
          find.textContaining('Does the person wear glasses?'), findsOneWidget);
      expect(find.text('ACCESSORIES'), findsOneWidget,
          reason: 'back on the category tiles');
      expect(find.text('1'), findsOneWidget,
          reason: 'asked-count badge on the tile');

      // Default is no timer: waiting a long time must not end the round.
      expect(find.byType(TimerBadge), findsNothing);
      await tester.pump(const Duration(minutes: 2));
      await tester.pumpAndSettle();
      expect(find.text('MAKE FINAL GUESS'), findsOneWidget);

      // Leave via the result screen's back handling is blocked mid-match; dispose by replacing the tree.
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('press and hold a face to see it up close with its traits',
      (tester) async {
    tester.view.physicalSize = const Size(411, 914);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(
        home: GuessPersonGameScreen(settings: GpSettings(rounds: 3))));
    await tapText(tester, find.text('START CHOOSING'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Tom'));
    await tester.pumpAndSettle();
    expect(
        find.text('Male · Brown eyes · Bald · Light skin · Glasses · Mustache'),
        findsOneWidget);
    await tester.tap(find.text('Tap anywhere to close'));
    await tester.pumpAndSettle();
    expect(find.text('Tap anywhere to close'), findsNothing);
    expect(find.text('Choose your\ncharacter!'), findsOneWidget,
        reason: 'zooming does not select anyone');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('game screen opens on the round 1 intro', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: GuessPersonGameScreen(settings: GpSettings(rounds: 3))));
    await tester.pumpAndSettle();
    expect(find.text('ROUND 1'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
