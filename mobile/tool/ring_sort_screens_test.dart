// Renders Ring Sort Race mid-game for a design review: flutter test tool/ring_sort_screens_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/features/guess_person/models/gp_player.dart';
import 'package:multiplayer_game/features/guess_person/widgets/gp_theme.dart';
import 'package:multiplayer_game/features/local_games/ring_sort/ring_sort_game.dart';
import 'render_util.dart';

Future<void> playAndSnap(WidgetTester tester, String name, int players) async {
  await tester.runAsync(loadFonts);
  phoneSize(tester);
  final key = GlobalKey();
  await tester.pumpWidget(RepaintBoundary(
    key: key,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: screenshotTheme(),
      home: withFonts(Scaffold(body: GpBackground(child: SafeArea(child: ringSortInfo.play(defaultPlayers(players), (_) {}))))),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 100));
  // Player 1 picks up the rings on their first peg.
  final pegs = find.bySemanticsLabel(RegExp(r'^Peg 1,'));
  await tester.tap(pegs.first, warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 300));
  await snap(tester, key, '${name}_play');
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 3));
}

void main() {
  testWidgets('2 players', (t) => playAndSnap(t, 'ringsort2', 2));
  testWidgets('4 players', (t) => playAndSnap(t, 'ringsort4', 4));
}
