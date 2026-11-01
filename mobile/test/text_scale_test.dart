import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/core/ui/app_ui.dart';
import 'package:multiplayer_game/features/local_games/local_games_hub_screen.dart';
import 'package:multiplayer_game/features/local_games/shell/local_game_info.dart';
import 'package:multiplayer_game/features/local_games/shell/local_game_shell.dart';

/// Large text (accessibility setting) on a 360dp phone: nothing may overflow.
/// Any RenderFlex overflow is reported as a test failure by the framework.
Widget scaled(Widget home) => MaterialApp(
      theme: buildAppTheme(),
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!),
      home: home,
    );

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 740);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> openAndPlay(WidgetTester tester, LocalGameInfo game) async {
  phone(tester);
  await tester.pumpWidget(scaled(LocalGameShell(game: game)));
  await tester.pump(const Duration(milliseconds: 400));
  final play = find.text('Start');
  await tester.ensureVisible(play);
  await tester.pump();
  await tester.tap(play);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 2600));
  if (find.text('START').evaluate().isNotEmpty) {
    await tester.ensureVisible(find.text('START').last);
    await tester.tap(find.text('START').last);
    await tester.pump();
  }
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 3));
}

void main() {
  for (final game in localGames) {
    testWidgets('${game.title}: intro and play at 1.3x text',
        (tester) => openAndPlay(tester, game));
  }

  testWidgets('pause menu at 1.3x text', (tester) async {
    phone(tester);
    await tester.pumpWidget(scaled(LocalGameShell(
        game: localGames.firstWhere((g) => g.id == 'tic_tac_toe'))));
    await tester.ensureVisible(find.text('Start'));
    await tester.pump();
    await tester.tap(find.text('Start'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2600));
    await tester.tap(find.byType(PauseButton).first);
    await tester.pumpAndSettle();
    expect(find.text('Resume'), findsOneWidget);
    await tester.tap(find.text('Resume'));
    await tester.pump(const Duration(
        milliseconds: 600)); // the game runs again: never settles
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('games list at 1.3x text', (tester) async {
    phone(tester);
    await tester.pumpWidget(scaled(const LocalGamesHubScreen()));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
    await tester.pump(const Duration(milliseconds: 300));
  });
}
