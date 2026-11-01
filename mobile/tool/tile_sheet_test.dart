import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show FontLoader;
// Renders every game's hub tile on one sheet: flutter test tool/tile_sheet_test.dart --dart-define=NAME=tiles
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/core/ui/app_ui.dart';
import 'package:multiplayer_game/features/local_games/local_games_hub_screen.dart';
import 'package:multiplayer_game/features/local_games/shell/game_art.dart';
import 'render_util.dart';

void main() {
  testWidgets('sheet', (tester) async {
    const name = String.fromEnvironment('NAME', defaultValue: 'tiles');
    await tester.runAsync(loadFonts);
    // The app's own fonts, so numbers and letters in the art render as on a phone.
    await tester.runAsync(() async {
      for (final (family, files) in [('Fredoka', ['Fredoka-Bold.ttf']), ('Nunito', Directory('assets/fonts').listSync().map((f) => f.uri.pathSegments.last).where((n) => n.startsWith('Nunito')).toList()), ('Lilita One', ['LilitaOne-Regular.ttf'])]) {
        final loader = FontLoader(family);
        for (final f in files) {
          loader.addFont(Future.value(ByteData.view(File('assets/fonts/$f').readAsBytesSync().buffer)));
        }
        await loader.load();
      }
    });
    final games = localGames;
    const cols = 6, w = 180.0, h = 196.0;
    final rows = (games.length / cols).ceil();
    phoneSize(tester, Size(cols * (w + 10) + 10, rows * (h + 10) + 10));
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: screenshotTheme(),
        home: withFonts(Scaffold(
          body: AppBackground(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Wrap(spacing: 10, runSpacing: 10, children: [
                for (final g in games)
                  SizedBox(
                    width: w,
                    height: h,
                    child: GameTile(id: g.id, title: g.title, color: g.color, minPlayers: g.minPlayers, maxPlayers: g.maxPlayers, favourite: false, onTap: () {}, onStar: () {}),
                  ),
              ]),
            ),
          ),
        )),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 200));
    await snap(tester, key, name);
  });
}
