import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// RivalRoom Clay: the look of this app in one place. Soft "inflated" clay surfaces on a
/// grape-violet world: every raised thing has a lit top-left rim, a shaded bottom-right
/// rim and a soft drop shadow; pressing pushes it in. Candy-yellow primary actions,
/// raspberry heroes, Fredoka (width-matched) headings and Nunito text.
///
/// Every shared component (buttons, panels, chips, tiles, sheets, backgrounds) draws
/// through [Skin], so app pages and all game screens share one design language.
abstract final class Skin {
  static const name = 'RivalRoom Clay';
  static const display = 'Fredoka';
  static const body = 'Nunito';

  // Palette. White and muted text pass 4.5:1 on every background and raised surface;
  // player colours stand out 3:1 from bg (test/design_tokens_test.dart).
  static const bgTop = Color(0xFF5A3ADF);
  static const bg = Color(0xFF3E22B2);
  static const bgBottom = Color(0xFF2B1588);
  static const clay = Color(0xFF6A4BEB); // default raised surface
  static const clayHigh = Color(0xFF6E4FE9); // raised a level (rows on a panel)
  static const clayDeep = Color(0xFF4528BF); // sunken wells, disabled
  static const sheetColor = Color(0xFF5B3CE0);
  static const card = Color(0xFF6447E8);
  static const cardRaised = Color(0xFF7255EE);
  static const shadow = Color(0xFF1C0868); // shadow ink
  static const accent =
      Color(0xFFFFD23F); // candy yellow: primary buttons, highlights
  static const accentDeep = Color(0xFFD69200);
  static const onAccent = Color(0xFF2A0F66);
  static const accentLine = Color(0xFFFFE07A);
  static const hero = Color(
      0xFFAE206C); // raspberry hero panels, card backs (white text 4.5:1 even on the lit corner)
  static const heroDeep = Color(0xFF7E1250);
  static const mint = Color(0xFF2FD39A);
  static const sky = Color(0xFF3FB7F5);
  static const coral = Color(0xFFFF7461);
  static const textMuted = Color(0xFFF1EDFF);
  static const label = Color(0xFFDCD2FF);
  static const overlay = Color(0xE03A1EAA);
  static const stroke = Color(0x38FFFFFF);
  static const strokeStrong = Color(0x5CFFFFFF);
  static const danger = Color(0xFFFF5C6C);

  // Shape.
  static const double rPanel = 26,
      rButton = 24,
      rChip = 18,
      rTile = 26,
      rBoard = 30;

  /// Pressed things squash a little.
  static const double pressScale = 0.95;

  static const confetti = [
    accent,
    Color(0xFFFF5FA8),
    Colors.white,
    Color(0xFF2FD39A),
    Color(0xFF3FB7F5),
    Color(0xFFFF7461),
    Color(0xFFB794FF)
  ];

  /// A raised clay panel (cards, rows, list items). [tint] colours it, [ring] outlines it
  /// (selected / active), [depth] 0..1 is how puffy it is.
  static Decoration surface(
          {Color? tint,
          double? radius,
          Color? ring,
          bool pressed = false,
          double depth = 1,
          bool sunken = false}) =>
      ClayDecoration(
        color: sunken
            ? clayDeep
            : (tint == null ? clay : Color.lerp(clay, tint, 0.42)!),
        radius: radius ?? rPanel,
        ring: ring,
        pressed: pressed || sunken,
        depth: sunken ? 0 : depth,
      );

  /// The big hero panel (Home's "Ready to play?", the room code card).
  static Decoration heroPanel({double? radius}) =>
      ClayDecoration(color: hero, radius: radius ?? rBoard, gloss: true);

  /// The primary call to action (gold button).
  static Decoration primary(
          {bool enabled = true,
          bool pressed = false,
          Color? color,
          double? radius}) =>
      enabled
          ? ClayDecoration(
              color: color ?? accent,
              radius: radius ?? rButton,
              pressed: pressed,
              gloss: true)
          : ClayDecoration(
              color: clayDeep,
              radius: radius ?? rButton,
              pressed: true,
              depth: 0);

  static Color primaryInk({bool enabled = true, Color? color}) => !enabled
      ? Colors.white.withValues(alpha: 0.5)
      : (color == null
          ? onAccent
          : (_lum(color) > 0.45 ? onAccent : Colors.white));

  /// Secondary buttons.
  static Decoration secondary(SkinButton kind,
      {bool pressed = false, double? radius, bool enabled = true}) {
    final r = radius ?? rButton;
    if (!enabled)
      return ClayDecoration(
          color: clayDeep, radius: r, pressed: true, depth: 0);
    return switch (kind) {
      SkinButton.soft => ClayDecoration(
          color: clayHigh, radius: r, pressed: pressed, depth: 0.8),
      SkinButton.ghost =>
        ClayDecoration(color: clay, radius: r, pressed: pressed, depth: 0.6),
      SkinButton.outline => ClayDecoration(
          color: clay,
          radius: r,
          pressed: pressed,
          depth: 0.7,
          ring: Colors.white.withValues(alpha: 0.55)),
      SkinButton.danger =>
        ClayDecoration(color: danger, radius: r, pressed: pressed, depth: 0.8),
    };
  }

  static Color secondaryInk(SkinButton kind, {bool enabled = true}) =>
      !enabled ? Colors.white.withValues(alpha: 0.5) : Colors.white;

  /// The round icon buttons of top bars (pause, back, settings).
  static Decoration round({bool dark = false, bool pressed = false}) =>
      ClayDecoration(
          color: dark ? const Color(0xCC2A1280) : clayHigh,
          radius: 999,
          pressed: pressed,
          depth: 0.7,
          gloss: !dark);

  /// Filter / choice chips.
  static Decoration chip(
          {required bool selected, bool outline = false, Color? color}) =>
      selected
          ? ClayDecoration(
              color: color ?? accent, radius: rChip, depth: 0.55, gloss: true)
          : ClayDecoration(
              color: outline ? clayDeep : clayHigh,
              radius: rChip,
              depth: outline ? 0 : 0.45,
              pressed: outline);

  static Color chipInk({required bool selected, Color? color}) => selected
      ? (color == null || _lum(color) > 0.45 ? onAccent : Colors.white)
      : Colors.white;

  /// A game tile in a grid.
  static Decoration tile({bool selected = false, bool pressed = false}) =>
      ClayDecoration(
          color: clayHigh,
          radius: rTile,
          pressed: pressed,
          ring: selected ? accent : null,
          ringWidth: 3);

  /// Bottom sheets (top corners only) and dialogs.
  static Decoration sheet() => const ClayDecoration(
      color: sheetColor, radius: 32, topOnly: true, depth: 0.6);
  static Decoration dialog() =>
      const ClayDecoration(color: card, radius: 30, gloss: true);

  /// A small pill of info sitting on a scene (score pills, overlay chips).
  static Decoration pill({Color? color, bool glow = false}) => ClayDecoration(
      color: color ?? clay, radius: 999, depth: 0.5, gloss: glow);

  /// Text field fill and focus ring.
  static const fieldFill = Color(0xFF331A9C);
  static const fieldFocus = accent;

  /// Every page's background.
  static Widget background({required Widget child, Color? color}) =>
      _ClayWorld(color: color, child: child);

  /// Page transitions: rise up with a soft squash.
  static const pageTransitions = PageTransitionsTheme(builders: {
    TargetPlatform.android: _ClayPageTransition(),
    TargetPlatform.iOS: _ClayPageTransition(),
    TargetPlatform.windows: _ClayPageTransition(),
    TargetPlatform.linux: _ClayPageTransition(),
    TargetPlatform.macOS: _ClayPageTransition(),
  });

  static double _lum(Color c) => 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
}

enum SkinButton { soft, ghost, outline, danger }

/// Claymorphism: soft drop shadow + contact shadow, a lit gradient body, an inner
/// highlight along the top-left and an inner shade along the bottom-right. Pressed, it
/// flattens and the shading flips inward. Lerps between states for smooth presses.
class ClayDecoration extends Decoration {
  final Color color;
  final double radius;
  final double depth; // 0 flat .. 1 fully puffed
  final bool pressed;
  final bool gloss; // a soft specular spot (buttons)
  final Color? ring;
  final double ringWidth;
  final bool topOnly; // sheets: only the top corners are round
  const ClayDecoration(
      {required this.color,
      this.radius = Skin.rPanel,
      this.depth = 1,
      this.pressed = false,
      this.gloss = false,
      this.ring,
      this.ringWidth = 2.5,
      this.topOnly = false});

  BorderRadius get _br => topOnly
      ? BorderRadius.vertical(top: Radius.circular(radius))
      : BorderRadius.circular(radius);

  @override
  bool hitTest(Size size, Offset position, {TextDirection? textDirection}) =>
      _br.toRRect(Offset.zero & size).contains(position);

  @override
  Path getClipPath(Rect rect, TextDirection textDirection) =>
      Path()..addRRect(_br.toRRect(rect));

  @override
  ClayDecoration? lerpFrom(Decoration? a, double t) =>
      a is ClayDecoration ? ClayDecoration._lerp(a, this, t) : null;
  @override
  ClayDecoration? lerpTo(Decoration? b, double t) =>
      b is ClayDecoration ? ClayDecoration._lerp(this, b, t) : null;

  static ClayDecoration _lerp(ClayDecoration a, ClayDecoration b, double t) =>
      _ClayMix(a, b, t);

  /// 0 when resting, 1 when fully pressed (blends while animating).
  double get pressAmount => pressed ? 1 : 0;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _ClayPainter(this);

  @override
  bool operator ==(Object other) =>
      other is ClayDecoration &&
      other.runtimeType == runtimeType &&
      other.color == color &&
      other.radius == radius &&
      other.depth == depth &&
      other.pressed == pressed &&
      other.gloss == gloss &&
      other.ring == ring &&
      other.ringWidth == ringWidth &&
      other.topOnly == topOnly;

  @override
  int get hashCode => Object.hash(
      color, radius, depth, pressed, gloss, ring, ringWidth, topOnly);
}

/// A ClayDecoration part-way between two states (used while a press animates).
class _ClayMix extends ClayDecoration {
  final double press;
  _ClayMix(ClayDecoration a, ClayDecoration b, double t)
      : press = ui.lerpDouble(a.pressAmount, b.pressAmount, t)!,
        super(
          color: Color.lerp(a.color, b.color, t)!,
          radius: ui.lerpDouble(a.radius, b.radius, t)!,
          depth: ui.lerpDouble(a.depth, b.depth, t)!,
          gloss: t < 0.5 ? a.gloss : b.gloss,
          ring: Color.lerp(a.ring ?? a.color.withValues(alpha: 0),
              b.ring ?? b.color.withValues(alpha: 0), t),
          ringWidth: ui.lerpDouble(a.ringWidth, b.ringWidth, t)!,
          topOnly: t < 0.5 ? a.topOnly : b.topOnly,
        );
  @override
  double get pressAmount => press;
  @override
  bool get pressed => press > 0.5;
}

class _ClayPainter extends BoxPainter {
  final ClayDecoration d;
  _ClayPainter(this.d);

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null || size.isEmpty) return;
    final rect = offset & size;
    final r = math.min(d.radius, size.shortestSide / 2);
    final br = d.topOnly
        ? BorderRadius.vertical(top: Radius.circular(r))
        : BorderRadius.circular(r);
    final rr = br.toRRect(rect);
    final p = d.pressAmount.clamp(0.0, 1.0);
    final k =
        (size.shortestSide / 56).clamp(0.45, 1.6); // shading scales with size
    final lift = d.depth * (1 - p * 0.75);

    // Drop shadow and a tight contact shadow. Performance: only plain RRects are blurred
    // (the renderer draws those analytically); everything else below is blur-free, so
    // screens with dozens of clay surfaces stay at frame rate.
    if (lift > 0.02) {
      canvas.drawRRect(
          rr.shift(Offset(0, 9 * lift * k)),
          Paint()
            ..color = Skin.shadow.withValues(alpha: 0.42 * lift)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 11 * lift * k));
      canvas.drawRRect(
          rr.shift(Offset(0, 3.5 * lift * k)),
          Paint()
            ..color = Color.lerp(d.color, Skin.shadow, 0.6)!
                .withValues(alpha: 0.85 * lift));
    }

    // Body: lit from the top-left.
    final light = Color.lerp(d.color, Colors.white, 0.17 * (1 - p))!;
    final dark = Color.lerp(d.color, Skin.shadow, 0.16 + 0.1 * p)!;
    canvas.drawRRect(
        rr,
        Paint()
          ..shader = LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: p > 0.5 ? [dark, d.color] : [light, d.color, dark],
                  stops: p > 0.5 ? null : const [0, 0.55, 1])
              .createShader(rect));

    // Inner rims: soft strokes just inside the edge, fading along the diagonal from the
    // lit (or shaded) corner. A wide faint stroke under a narrow stronger one reads as
    // a blurred rim without the cost of a blur.
    void rim(Color c, double alpha, double width, {required bool fromTopLeft}) {
      if (alpha <= 0.01) return;
      for (final (w, a) in [(width * 1.9, alpha * 0.45), (width, alpha)]) {
        canvas.drawRRect(
            rr.deflate(w / 2),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = w
              ..shader = LinearGradient(
                begin: fromTopLeft ? Alignment.topLeft : Alignment.bottomRight,
                end: fromTopLeft ? Alignment.bottomRight : Alignment.topLeft,
                colors: [c.withValues(alpha: a), c.withValues(alpha: 0)],
                stops: const [0, 0.55],
              ).createShader(rect));
      }
    }

    final rest = 1 - p;
    if (rest > 0.02) {
      rim(Colors.white, 0.42 * rest, 3.2 * k + 0.5, fromTopLeft: true);
      rim(Color.lerp(d.color, Skin.shadow, 0.55)!, 0.6 * rest, 4 * k + 0.5,
          fromTopLeft: false);
    }
    if (p > 0.02) {
      rim(Skin.shadow, 0.5 * p, 4 * k + 0.5, fromTopLeft: true);
      rim(Colors.white, 0.18 * p, 2 * k + 0.5, fromTopLeft: false);
    }
    if (d.gloss && rest > 0.02) {
      final g = Rect.fromLTWH(
          rect.left + size.width * 0.1,
          rect.top + size.height * 0.12,
          math.min(size.width * 0.32, 90),
          math.min(size.height * 0.2, 14));
      canvas.drawRRect(
          RRect.fromRectAndRadius(g, Radius.circular(g.height / 2)),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.32 * rest)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.5 * k));
    }

    final ring = d.ring;
    if (ring != null && ring.a > 0.01) {
      canvas.drawRRect(
          rr.deflate(d.ringWidth / 2),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = d.ringWidth
            ..color = ring);
    }
  }
}

/// The clay world: a grape gradient with big soft clay blobs floating at the edges.
/// [color] (a game's colour) tints the world so each game feels like its own room.
class _ClayWorld extends StatelessWidget {
  final Color? color;
  final Widget child;
  const _ClayWorld({this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = color;
    // A game's room: its hue at a depth where white text still reads.
    List<Color> grad;
    if (c == null) {
      grad = const [Skin.bgTop, Skin.bg, Skin.bgBottom];
    } else {
      final h = HSLColor.fromColor(c);
      HSLColor at(double l, double s) =>
          HSLColor.fromAHSL(1, h.hue, (h.saturation * 0.85).clamp(0.35, s), l);
      grad = [
        at(0.40, 0.72).toColor(),
        at(0.30, 0.7).toColor(),
        at(0.19, 0.66).toColor()
      ];
      grad = [for (final g in grad) Color.lerp(g, Skin.bg, 0.38)!];
    }
    return DecoratedBox(
      decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: grad)),
      child: Stack(children: [
        Positioned.fill(
            child: IgnorePointer(
                child: RepaintBoundary(
                    child: CustomPaint(painter: _Blobs(c ?? Skin.hero))))),
        Positioned.fill(child: child),
      ]),
    );
  }
}

class _Blobs extends CustomPainter {
  final Color tint;
  const _Blobs(this.tint);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    void blob(Offset c, double r, Color col, double a) {
      final rect = Rect.fromCircle(center: c, radius: r);
      canvas.drawCircle(
          c,
          r,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.35, -0.4),
              colors: [
                Color.lerp(col, Colors.white, 0.35)!.withValues(alpha: a),
                col.withValues(alpha: a * 0.85),
                Color.lerp(col, Skin.shadow, 0.5)!.withValues(alpha: a * 0.7)
              ],
              stops: const [0, 0.6, 1],
            ).createShader(rect));
    }

    blob(Offset(w * 1.02, h * 0.06), w * 0.34, tint, 0.30);
    blob(Offset(-w * 0.12, h * 0.38), w * 0.26, Skin.mint, 0.20);
    blob(Offset(w * 0.92, h * 0.72), w * 0.2, Skin.accent, 0.18);
    blob(Offset(w * 0.1, h * 1.02), w * 0.38, Skin.sky, 0.22);
    // Tiny clay beads.
    for (final (x, y, r, col) in const [
      (0.2, 0.1, 5.0, Skin.accent),
      (0.78, 0.28, 4.0, Skin.mint),
      (0.12, 0.62, 3.5, Color(0xFFFF9BD0)),
      (0.66, 0.9, 4.5, Skin.accent)
    ]) {
      blob(Offset(w * x, h * y), r, col, 0.55);
    }
  }

  @override
  bool shouldRepaint(_Blobs old) => old.tint != tint;
}

class _ClayPageTransition extends PageTransitionsBuilder {
  const _ClayPageTransition();
  @override
  Widget buildTransitions<T>(
      PageRoute<T> route,
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child) {
    final rise = CurvedAnimation(
        parent: animation,
        curve: const Cubic(0.2, 1.25, 0.4, 1),
        reverseCurve: Curves.easeIn);
    return FadeTransition(
      opacity:
          CurvedAnimation(parent: animation, curve: const Interval(0, 0.6)),
      child: SlideTransition(
        position:
            Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(rise),
        child: ScaleTransition(
            scale: Tween(begin: 0.96, end: 1.0).animate(rise), child: child),
      ),
    );
  }
}
