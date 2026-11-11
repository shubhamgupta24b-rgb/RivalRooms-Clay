// Renders every one-device game (intro + a moment of play) to PNGs for a design review.
// Run from mobile/:  flutter test tool/screens_test.dart [--plain-name <game id>]
// Writes build/screens/<id>_intro.png and <id>_play.png at 411x914.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/core/ui/app_ui.dart';
import 'package:multiplayer_game/features/local_games/local_games_hub_screen.dart';
import 'package:multiplayer_game/features/local_games/shell/local_game_shell.dart';

Future<void> loadFonts() async {
  // The app's bundled fonts (Lilita One, Nunito) from assets/fonts.
  Future<void> bundled(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final file = File('assets/fonts/$f');
      if (file.existsSync()) loader.addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer)));
    }
    await loader.load();
  }

  await bundled('Lilita One', ['LilitaOne-Regular.ttf']);
  await bundled('Nunito', ['Nunito-SemiBold.ttf', 'Nunito-Bold.ttf', 'Nunito-ExtraBold.ttf', 'Nunito-Black.ttf']);
  final family = FontLoader('Roboto');
  for (final f in ['segoeui.ttf', 'segoeuib.ttf', 'seguibl.ttf', 'seguisb.ttf']) {
    final file = File('C:\\Windows\\Fonts\\$f');
    if (file.existsSync()) family.addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer)));
  }
  await family.load();
  final icons = File('${Platform.environment['FLUTTER_ROOT'] ?? r'C:\flutter'}\\bin\\cache\\artifacts\\material_fonts\\MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.view(icons.readAsBytesSync().buffer)))).load();
  }
  final emoji = File(r'C:\Windows\Fonts\seguiemj.ttf');
  if (emoji.existsSync()) {
    await (FontLoader('Segoe UI Emoji')..addFont(Future.value(ByteData.view(emoji.readAsBytesSync().buffer)))).load();
  }
}

Future<void> snap(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('build/screens/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  for (final game in localGames) {
    testWidgets(game.id, (tester) async {
      await tester.runAsync(loadFonts);
      tester.view.physicalSize = const Size(411, 914);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      final theme = buildAppTheme();
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme.copyWith(textTheme: theme.textTheme.apply(fontFamily: 'Roboto', fontFamilyFallback: const ['Segoe UI Emoji'])),
          home: DefaultTextStyle.merge(
            style: const TextStyle(fontFamily: 'Roboto', fontFamilyFallback: ['Segoe UI Emoji']),
            child: LocalGameShell(game: game),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      await snap(tester, key, '${game.id}_intro');
      final play = find.text('Tap to start');
      await tester.ensureVisible(play);
      await tester.pump();
      await tester.tap(play);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2600));
      // Take-turns games show a pass screen first: start the first turn.
      if (find.text('START').evaluate().isNotEmpty) {
        await tester.tap(find.text('START').last);
        await tester.pump();
      }
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
      // A few taps (dice tray, board) to get into the game.
      for (final f in const [Offset(0.85, 0.9), Offset(0.5, 0.5), Offset(0.85, 0.9), Offset(0.3, 0.6)]) {
        await tester.tapAt(Offset(411 * f.dx, 914 * f.dy));
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 120));
        }
      }
      await snap(tester, key, '${game.id}_play');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });
  }
}
