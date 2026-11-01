// Renders the Party Games logo to PNG files.
// Run from mobile/:  flutter test tool/render_logo_test.dart
// Writes build/logo/: icon_1024.png (rounded tile), foreground_1024.png (Android adaptive
// foreground, full bleed), playstore_512.png (square; Play rounds it) and logo_full.png (icon + wordmark, a preview of the splash).
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/core/ui/party_logo.dart';

Future<void> _save(WidgetTester tester, Widget child, Size size, String name) async {
  final key = GlobalKey();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: RepaintBoundary(key: key, child: SizedBox(width: size.width, height: size.height, child: child))),
  ));
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/logo/$name')..createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('render logo', (tester) async {
    // A real bold font for the wordmark preview (tests otherwise use a box font).
    await tester.runAsync(() async {
      for (final path in [r'C:\Windows\Fonts\seguibl.ttf', r'C:\Windows\Fonts\arialbd.ttf']) {
        final f = File(path);
        if (f.existsSync()) {
          final loader = FontLoader('LogoFont')..addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
          await loader.load();
          break;
        }
      }
    });
    await _save(tester, const CustomPaint(painter: PartyLogoPainter()), const Size(1024, 1024), 'icon_1024.png');
    await _save(tester, const CustomPaint(painter: PartyLogoPainter(rounded: false, artScale: 0.70)), const Size(1024, 1024), 'foreground_1024.png');
    await _save(tester, const CustomPaint(painter: PartyLogoPainter(rounded: false)), const Size(512, 512), 'playstore_512.png');
    await _save(
      tester,
      const ColoredBox(color: Color(0xFF0E1150), child: Center(child: PartyLogoFull(width: 640, fontFamily: 'LogoFont'))),
      const Size(900, 1000),
      'logo_full.png',
    );
    tester.view.reset();
  });
}
