import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/core/ui/icons/game_icons.dart';
import 'package:multiplayer_game/core/ui/materials/materials.dart';

void main() {
  group('svgPath', () {
    test('absolute and relative lines, curves and close', () {
      final p = svgPath('M2 2 L10 2 l0 8 H2 z');
      expect(p.getBounds(), const Rect.fromLTRB(2, 2, 10, 10));
      final q =
          svgPath('M0 0 Q10 0 10 10 T20 20 C25 20 30 25 30 30 s5 5 10 10');
      expect(q.getBounds().right, closeTo(40, 0.01));
      expect(q.getBounds().bottom, closeTo(40, 0.01));
    });

    test('arcs (watermelon half disc) and implicit line-tos after a move', () {
      final arc = svgPath('M5 16 A15 15 0 0 0 35 16 Z');
      final b = arc.getBounds();
      expect(b.left, closeTo(5, 0.01));
      expect(b.right, closeTo(35, 0.01));
      expect(b.bottom, closeTo(31, 0.2),
          reason: 'a half circle of radius 15 below y=16');
      final poly = svgPath('M0 0 10 0 10 10');
      expect(poly.getBounds(), const Rect.fromLTRB(0, 0, 10, 10));
    });

    test('numbers glued together the SVG way (-.5, 1.2.3)', () {
      final p = svgPath('M7.6 7.6a2.5 2.5 0 1 1 3.4 2.3c-.6.3-1 .8-1 1.5v.4');
      expect(p.getBounds().isEmpty, isFalse);
    });
  });

  test('every icon builds and paints, in any colour', () {
    for (final icon in GameIcons.values) {
      final rec = ui.PictureRecorder();
      paintIcon(Canvas(rec), icon, const Rect.fromLTWH(0, 0, 48, 48),
          color: const Color(0xFF2E8BFF));
      expect(rec.endRecording(), isNotNull, reason: icon.name);
    }
  });

  test('15 fruit illustrations, all different', () {
    expect(fruitIcons, hasLength(15));
    expect(fruitIcons.toSet(), hasLength(15));
  });

  test('every material paints', () {
    final painters = <CustomPainter>[
      const FeltPainter(),
      const WoodPainter(),
      const PaperCardPainter(),
      const PaperCardPainter(tint: Color(0xFFFF8A1F)),
      const CardBackPainter(),
      for (final t in SkyTime.values)
        SkyPainter(time: t, hills: true, trees: true),
      const GrassPainter(),
      const AsphaltPainter(),
      const WaterPainter(),
      const CourtPainter(),
    ];
    for (final p in painters) {
      final rec = ui.PictureRecorder();
      p.paint(Canvas(rec), const Size(200, 120));
      expect(rec.endRecording(), isNotNull, reason: '$p');
    }
  });

  testWidgets('GameIcon has a semantics label only when given one',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Row(children: [
      GameIcon(GameIcons.heart, semanticLabel: 'Lives'),
      GameIcon(GameIcons.star)
    ])));
    expect(find.bySemanticsLabel('Lives'), findsOneWidget);
  });
}
