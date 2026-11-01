import 'package:flutter/material.dart';
import 'components.dart';
import 'materials/materials.dart';

/// Debug-only: every material and icon on one scrolling page, to check them on a device.
/// Opened from Settings in debug builds only (see showSettingsSheet).
class DebugGalleryScreen extends StatelessWidget {
  const DebugGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget label(String s) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
        child: Text(s.toUpperCase(), style: t.styles.label));
    Widget swatch(String name, CustomPainter p, {double h = 120}) =>
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              height: h,
              width: double.infinity,
              child: ClipRRect(
                  borderRadius: Radii.rCard, child: CustomPaint(painter: p))),
          Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 10),
              child: Text(name, style: t.styles.bodySmall)),
        ]);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
          title: Text('Design gallery', style: t.styles.h3),
          backgroundColor: t.bgTop),
      body: ListView(padding: Space.screen, children: [
        label('Materials'),
        swatch('FeltPainter', const FeltPainter()),
        swatch('WoodPainter', const WoodPainter()),
        Row(children: [
          const SizedBox(width: 78, height: 90, child: PaperCard()),
          const SizedBox(width: 12),
          const SizedBox(
              width: 78, height: 90, child: PaperCard(tint: Color(0xFF2E8BFF))),
          const SizedBox(width: 12),
          const SizedBox(width: 78, height: 90, child: CardBack()),
        ]),
        const SizedBox(height: 4),
        Text('PaperCard · tinted · CardBack', style: t.styles.bodySmall),
        const SizedBox(height: 10),
        swatch('SkyPainter day + hills',
            const SkyPainter(hills: true, trees: true)),
        swatch('SkyPainter sunset',
            const SkyPainter(time: SkyTime.sunset, hills: true)),
        swatch('SkyPainter night',
            const SkyPainter(time: SkyTime.night, sun: false)),
        swatch('GrassPainter', const GrassPainter()),
        swatch('AsphaltPainter', const AsphaltPainter()),
        swatch('WaterPainter', const WaterPainter()),
        swatch('CourtPainter', const CourtPainter()),
        label('Player badges'),
        Wrap(spacing: 10, children: [
          for (var i = 0; i < 6; i++)
            PlayerBadge(index: i, size: 34, initial: 'ABCDEF'[i])
        ]),
        label('Icons'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final i
              in GameIcons.values.where((i) => !fruitIcons.contains(i)))
            Tooltip(
              message: i.name,
              child: Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: Radii.rCard,
                    border: Border.all(color: t.stroke)),
                child: GameIcon(i, size: 30),
              ),
            ),
        ]),
        label('Fruit'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final f in fruitIcons)
            SizedBox(
                width: 64,
                height: 76,
                child: PaperCard(child: Center(child: GameIcon(f, size: 44)))),
        ]),
        const SizedBox(height: 40),
      ]),
    );
  }
}
