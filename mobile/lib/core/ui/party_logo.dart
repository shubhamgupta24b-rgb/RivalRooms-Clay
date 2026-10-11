import 'dart:math';
import 'package:flutter/material.dart';
import 'skin.dart';

/// The Party Games app icon, drawn in code so it is sharp at any size: a split game
/// controller (the blue and orange halves are players 1 and 2, the buttons are the player
/// shapes) with a gold lightning bolt, confetti and sparkles on a deep indigo tile.
/// Ported from docs/app-logo/render_logo.py (same 1024 x 1024 grid).
class PartyLogoPainter extends CustomPainter {
  /// Rounded tile (app icon) or full-bleed square (Android adaptive foreground).
  final bool rounded;

  /// How much of the tile the artwork fills; adaptive icons need it smaller.
  final double artScale;
  const PartyLogoPainter({this.rounded = true, this.artScale = 1});

  static const _ink = Color(0xFF120C3A);

  static Path _body() => Path()
    ..moveTo(330, 430)
    ..lineTo(694, 430)
    ..cubicTo(790, 430, 842, 474, 864, 562)
    ..lineTo(902, 716)
    ..cubicTo(918, 790, 858, 834, 802, 802)
    ..cubicTo(758, 778, 730, 724, 690, 694)
    ..lineTo(334, 694)
    ..cubicTo(294, 724, 266, 778, 222, 802)
    ..cubicTo(166, 834, 106, 790, 122, 716)
    ..lineTo(160, 562)
    ..cubicTo(182, 474, 234, 430, 330, 430)
    ..close();

  static Path _poly(List<double> xy) {
    final p = Path()..moveTo(xy[0], xy[1]);
    for (var i = 2; i + 1 < xy.length; i += 2) {
      p.lineTo(xy[i], xy[i + 1]);
    }
    return p..close();
  }

  static Path _star4(double cx, double cy, double r, double ri) {
    final p = Path();
    for (var i = 0; i < 8; i++) {
      final a = -pi / 2 + i * pi / 4;
      final rr = i.isEven ? r : ri;
      final pt = Offset(cx + rr * cos(a), cy + rr * sin(a));
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    return p..close();
  }

  static Paint _vertical(List<Color> colors, List<double> stops, double y0, double y1) =>
      Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors, stops: stops).createShader(Rect.fromLTRB(0, y0, 1024, y1));

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.save();
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    canvas.scale(s / 1024);
    const tile = Rect.fromLTWH(0, 0, 1024, 1024);
    final shape = rounded ? RRect.fromRectAndRadius(tile, const Radius.circular(225)) : RRect.fromRectXY(tile, 0, 0);
    canvas.clipRRect(shape);
    _background(canvas);
    canvas.save();
    canvas.translate(512, 512);
    canvas.scale(artScale);
    canvas.translate(-512, -512);
    _art(canvas);
    canvas.restore();
    if (rounded) {
      canvas.drawRRect(shape.deflate(3), Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = Colors.white.withValues(alpha: 40 / 255));
    }
    canvas.restore();
  }

  void _background(Canvas canvas) {
    const tile = Rect.fromLTWH(0, 0, 1024, 1024);
    // Diagonal indigo gradient (50 degrees, top-left to bottom-right).
    canvas.drawRect(
        tile,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment(-0.64, -0.77),
            end: Alignment(0.64, 0.77),
            colors: [Color(0xFF4A35C2), Color(0xFF241A7A), Color(0xFF0B0E2E)],
            stops: [0, 0.45, 1],
          ).createShader(tile));
    // Soft glows: pink behind the controller, blue bottom-left, gold top-right.
    void glow(double cx, double cy, double r, Color c, double a) {
      final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
      canvas.drawCircle(
          Offset(cx, cy),
          r,
          Paint()
            ..shader = RadialGradient(
              colors: [c.withValues(alpha: a), c.withValues(alpha: a * 0.42), c.withValues(alpha: a * 0.08), c.withValues(alpha: 0)],
              stops: const [0, 0.35, 0.75, 1],
            ).createShader(rect));
    }

    glow(512, 560, 470, const Color(0xFFFF4FA3), 0.30);
    glow(110, 980, 520, const Color(0xFF2E8BFF), 0.35);
    glow(960, 40, 420, const Color(0xFFFFC93C), 0.20);
    // Sunburst: 16 faint rays from the centre.
    final ray = Paint()..color = Colors.white.withValues(alpha: 12 / 255);
    const c = Offset(512, 560);
    for (var i = 0; i < 16; i++) {
      final a0 = i * 2 * pi / 16, a1 = a0 + pi / 16;
      canvas.drawPath(_poly([c.dx, c.dy, c.dx + 900 * cos(a0), c.dy + 900 * sin(a0), c.dx + 900 * cos(a1), c.dy + 900 * sin(a1)]), ray);
    }
  }

  void _art(Canvas canvas) {
    // Confetti.
    const conf = [
      (false, 236.0, 286.0, 34.0, 16.0, -28.0, Color(0xFFFFC93C)),
      (false, 792.0, 270.0, 30.0, 15.0, 24.0, Color(0xFFFF5C8A)),
      (true, 872.0, 420.0, 13.0, 0.0, 0.0, Color(0xFF2ECC71)),
      (true, 150.0, 420.0, 11.0, 0.0, 0.0, Color(0xFFFFFFFF)),
      (false, 376.0, 214.0, 26.0, 13.0, 40.0, Color(0xFF2E8BFF)),
      (false, 660.0, 210.0, 24.0, 12.0, -36.0, Color(0xFFB07CFF)),
      (true, 512.0, 208.0, 9.0, 0.0, 0.0, Color(0xFFFFC93C)),
      (false, 150.0, 740.0, 28.0, 14.0, 30.0, Color(0xFFFF8A1F)),
      (false, 868.0, 746.0, 28.0, 14.0, -30.0, Color(0xFF2E8BFF)),
    ];
    for (final (round, x, y, w, h, rot, col) in conf) {
      final paint = Paint()..color = col;
      if (round) {
        canvas.drawCircle(Offset(x, y), w, paint);
      } else {
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(rot * pi / 180);
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: w, height: h), paint);
        canvas.restore();
      }
    }

    // Controller: drop shadow, ink outline, blue/orange halves, top highlight.
    final body = _body();
    canvas.drawPath(body.shift(const Offset(0, 26)), Paint()
      ..color = const Color(0x96050419)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));
    canvas.drawPath(body, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 40
      ..strokeJoin = StrokeJoin.round
      ..color = _ink);
    canvas.save();
    canvas.clipRect(const Rect.fromLTRB(0, 0, 512, 1024));
    canvas.drawPath(body, _vertical(const [Color(0xFF6CB4FF), Color(0xFF2E8BFF), Color(0xFF1659C9)], const [0, 0.45, 1], 430, 834));
    canvas.restore();
    canvas.save();
    canvas.clipRect(const Rect.fromLTRB(512, 0, 1024, 1024));
    canvas.drawPath(body, _vertical(const [Color(0xFFFFB866), Color(0xFFFF8A1F), Color(0xFFD9600A)], const [0, 0.45, 1], 430, 834));
    canvas.restore();
    final band = Path()
      ..moveTo(300, 452)
      ..lineTo(724, 452)
      ..cubicTo(790, 452, 826, 480, 840, 530)
      ..lineTo(184, 530)
      ..cubicTo(198, 480, 234, 452, 300, 452)
      ..close();
    canvas.save();
    canvas.clipPath(body);
    canvas.drawPath(band, Paint()..color = Colors.white.withValues(alpha: 34 / 255));
    canvas.restore();

    // D-pad (left), with its shadow.
    Path plus(double cx, double cy, double arm, double w) => _poly([
          cx - w, cy - arm, cx + w, cy - arm, cx + w, cy - w, cx + arm, cy - w, cx + arm, cy + w, cx + w, cy + w, //
          cx + w, cy + arm, cx - w, cy + arm, cx - w, cy + w, cx - arm, cy + w, cx - arm, cy - w, cx - w, cy - w,
        ]);
    canvas.drawPath(plus(330, 570, 66, 24), Paint()..color = const Color(0xFF0E3C8A));
    canvas.drawPath(plus(330, 562, 66, 24), Paint()..color = Colors.white);

    // Buttons (right): the player shapes, each with a shadow.
    final buttons = [
      Path()..addOval(Rect.fromCircle(center: const Offset(694, 500), radius: 23)),
      _poly([756, 534, 784, 562, 756, 590, 728, 562]),
      _poly([694, 598, 721, 642, 667, 642]),
      _poly([611, 541, 653, 541, 653, 583, 611, 583]),
    ];
    for (final b in buttons) {
      canvas.drawPath(b.shift(const Offset(0, 8)), Paint()..color = const Color(0xFF9A4100));
      canvas.drawPath(b, Paint()..color = Colors.white);
    }

    // Lightning bolt over the seam: ink outline, gold gradient, a shine.
    final bolt = _poly([520, 360, 596, 360, 540, 526, 604, 526, 474, 806, 506, 596, 436, 596]);
    canvas.drawPath(bolt, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 32
      ..strokeJoin = StrokeJoin.round
      ..color = _ink);
    canvas.drawPath(bolt, _vertical(const [Color(0xFFFFE58A), Color(0xFFFFC93C), Color(0xFFF0A500)], const [0, 0.5, 1], 360, 806));
    canvas.drawPath(_poly([530, 376, 566, 376, 520, 512, 504, 512]), Paint()..color = const Color(0xAAFFF6C8));

    // Sparkles.
    canvas.drawPath(_star4(842, 330, 40, 9), Paint()..color = const Color(0xFFFFF4C2));
    canvas.drawPath(_star4(196, 610, 22, 5), Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(PartyLogoPainter old) => old.rounded != rounded || old.artScale != artScale;
}

/// Just the icon tile.
class PartyLogoIcon extends StatelessWidget {
  final double size;
  const PartyLogoIcon({super.key, this.size = 120});
  @override
  Widget build(BuildContext context) => Semantics(
        image: true,
        label: Skin.name,
        child: SizedBox(width: size, height: size, child: const CustomPaint(painter: PartyLogoPainter())),
      );
}

/// Icon plus the PARTY GAMES wordmark, for the splash and login screens.
class PartyLogoFull extends StatelessWidget {
  final double width;
  final String? fontFamily; // only for rendering previews outside the app
  const PartyLogoFull({super.key, this.width = 260, this.fontFamily});

  @override
  Widget build(BuildContext context) => Semantics(
        label: Skin.name,
        child: ExcludeSemantics(
          child: SizedBox(
            width: width,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              PartyLogoIcon(size: width * 0.62),
              SizedBox(height: 10 * width / 260),
              PartyWordmark(width: width, fontFamily: fontFamily),
            ]),
          ),
        ),
      );
}

/// "PARTY GAMES" in chunky outlined letters with the players pill underneath.
class PartyWordmark extends StatelessWidget {
  final double width;
  final String? fontFamily;
  const PartyWordmark({super.key, this.width = 260, this.fontFamily});

  @override
  Widget build(BuildContext context) {
    final f = width / 260;
    TextStyle word(Color fill) => TextStyle(fontFamily: fontFamily, fontSize: 46 * f, height: 1, fontWeight: FontWeight.w900, letterSpacing: 1.5 * f, color: fill, shadows: [Shadow(color: const Color(0xFFE8335C), offset: Offset(0, 4 * f))]);
    TextStyle stroke() => TextStyle(
        fontFamily: fontFamily,
        fontSize: 46 * f,
        height: 1,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5 * f,
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7 * f
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFF2A0B3D));
    Widget outlined(String t, Color fill) => Stack(children: [Text(t, style: stroke()), Text(t, style: word(fill))]);
    return Semantics(
      label: Skin.name,
      child: ExcludeSemantics(
        child: SizedBox(
          width: width,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            FittedBox(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                outlined('RIVAL', Colors.white),
                SizedBox(width: 8 * f),
                outlined('ROOM', Skin.accent),
              ]),
            ),
            SizedBox(height: 10 * f),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14 * f, vertical: 5 * f),
              decoration: Skin.pill(color: Skin.hero),
              child: Text('2–6 PLAYERS', style: TextStyle(fontFamily: fontFamily, color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13 * f, letterSpacing: 2 * f)),
            ),
          ]),
        ),
      ),
    );
  }
}
