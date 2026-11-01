import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/core/ui/app_theme_ext.dart';

/// [fg] composited over [bg] (for translucent surfaces like glass).
Color over(Color fg, Color bg) => Color.alphaBlend(fg, bg);

void main() {
  for (final (name, t) in [
    ('neon', GameTokens.neon),
    ('flat', GameTokens.flatSet)
  ]) {
    group('$name tokens', () {
      test(
          'text on the background passes 4.5:1 (top, middle, bottom of the gradient)',
          () {
        for (final bg in [t.bgTop, t.bg, t.bgBottom]) {
          expect(contrast(t.onBg, bg), greaterThanOrEqualTo(4.5),
              reason: 'onBg on $bg');
          expect(contrast(t.onBgMuted, bg), greaterThanOrEqualTo(4.5),
              reason: 'onBgMuted on $bg');
          expect(contrast(t.onBg, over(t.glass, bg)), greaterThanOrEqualTo(4.5),
              reason: 'onBg on glass');
        }
      });

      test('text on cards passes 4.5:1', () {
        final card = over(t.card, t.bg);
        expect(contrast(t.text, card), greaterThanOrEqualTo(4.5));
        expect(contrast(t.textMuted, card), greaterThanOrEqualTo(4.5));
        expect(t.cardStyles.body.color, t.text);
        expect(t.styles.body.color, t.onBg);
      });

      test('buttons: ink on gold, white on status fills', () {
        expect(contrast(t.onAccent, t.accent), greaterThanOrEqualTo(4.5));
        for (final c in [t.success, t.danger, t.info, t.warn]) {
          expect(contrast(onColor(fillFor(c)), fillFor(c)),
              greaterThanOrEqualTo(4.5),
              reason: '$c');
        }
      });

      test('scores use tabular figures', () {
        expect(t.styles.score.fontFeatures,
            contains(const FontFeature.tabularFigures()));
        expect(t.styles.scoreLarge.fontFeatures,
            contains(const FontFeature.tabularFigures()));
      });
    });
  }

  test(
      '6 player colours: all different, each with its own shape, readable name chips',
      () {
    expect(PlayerPalette.colors.toSet(), hasLength(6));
    expect(PlayerPalette.shapes.toSet(), hasLength(6));
    expect(PlayerPalette.glyphs.toSet(), hasLength(6));
    for (final c in PlayerPalette.colors) {
      expect(contrast(Colors.white, fillFor(c)), greaterThanOrEqualTo(4.5),
          reason: 'white on ${fillFor(c)}');
      // The bright colour itself stands out from the night background (pieces, strokes).
      expect(contrast(c, NeonPalette.bg), greaterThanOrEqualTo(3),
          reason: '$c on the background');
    }
  });

  test('scales', () {
    expect([Space.xs, Space.s, Space.m, Space.l, Space.xl, Space.xxl],
        [4, 8, 12, 16, 24, 32]);
    expect([Radii.sm, Radii.md, Radii.lg, Radii.xl],
        [10, 14, 18, 26]); // RivalRoom Clay: rounder, inflated shapes
    expect(
        [Motion.fast, Motion.normal, Motion.slow].map((d) => d.inMilliseconds),
        [120, 220, 360]);
  });

  testWidgets('context.tk follows the nearest TokenScope', (tester) async {
    late GameTokens outer, inner;
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(extensions: [GameTokens.neon]),
      home: Builder(builder: (context) {
        outer = context.tk;
        return TokenScope(
            flat: true,
            child: Builder(builder: (context) {
              inner = context.tk;
              return const SizedBox();
            }));
      }),
    ));
    expect(outer.flat, isFalse);
    expect(inner.flat, isTrue);
  });

  testWidgets('reduce motion: the app setting turns animations off',
      (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      ctx = context;
      return const SizedBox();
    })));
    expect(Motion.of(ctx, Motion.normal), Motion.normal);
    Motion.reduceSetting.value = true;
    expect(Motion.of(ctx, Motion.normal), Duration.zero);
    Motion.reduceSetting.value = false;
  });
}
