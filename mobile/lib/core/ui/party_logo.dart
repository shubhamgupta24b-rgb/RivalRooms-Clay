import 'dart:math';
import 'package:flutter/material.dart';
import 'skin.dart';

/// The RivalRoom Clay app icon, drawn in code so it is sharp at any size: a candy-yellow
/// clay doorway (the room) with two puffy rival pawns, blue and coral, glaring at each
/// other under a spark, on the grape clay world. All shapes sit on a 1024 x 1024 grid.
class PartyLogoPainter extends CustomPainter {
  /// Rounded tile (app icon) or full-bleed square (Android adaptive foreground).
  final bool rounded;

  /// How much of the tile the artwork fills; adaptive icons need it smaller.
  final double artScale;
  const PartyLogoPainter({this.rounded = true, this.artScale = 1});

  static const _ink = Color(0xFF240C5E);
  static const _blue = Color(0xFF3FA9F5);
  static const _coral = Color(0xFFFF6F5E);

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

  /// A door arch: straight legs from [bottom] up to a half circle centred at [cy].
  static Path _arch(double left, double right, double cy, double bottom) {
    final r = (right - left) / 2;
    return Path()
      ..moveTo(left, bottom)
      ..lineTo(left, cy)
      ..arcTo(Rect.fromCircle(center: Offset(left + r, cy), radius: r), pi, pi,
          false)
      ..lineTo(right, bottom)
      ..close();
  }

  /// A chunky pawn standing on y = [base], centred on [x].
  static Path _pawnBody(double x, double base) => Path()
    ..moveTo(x - 78, base)
    ..cubicTo(x - 80, base - 60, x - 52, base - 120, x - 30, base - 150)
    ..lineTo(x + 30, base - 150)
    ..cubicTo(x + 52, base - 120, x + 80, base - 60, x + 78, base)
    ..close();

  /// Fills [path] as a piece of clay: drop shadow, a body lit from the top-left, a soft
  /// highlight rim top-left, a shaded rim bottom-right and a gloss spot.
  static void _clay(Canvas canvas, Path path, Color c,
      {double lift = 1, bool gloss = true}) {
    final b = path.getBounds();
    if (lift > 0) {
      canvas.drawPath(
          path.shift(Offset(0, 24 * lift)),
          Paint()
            ..color = Skin.shadow.withValues(alpha: 0.5)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 18 * lift));
    }
    canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(c, Colors.white, 0.3)!,
              c,
              Color.lerp(c, Skin.shadow, 0.3)!
            ],
            stops: const [0, 0.5, 1],
          ).createShader(b));
    canvas.save();
    canvas.clipPath(path);
    void rim(Color col, Alignment from) => canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 30
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9)
          ..shader = LinearGradient(
              begin: from,
              end: -from,
              colors: [col, col.withValues(alpha: 0)],
              stops: const [0, 0.6]).createShader(b));
    rim(Colors.white.withValues(alpha: 0.6), Alignment.topLeft);
    rim(Color.lerp(c, Skin.shadow, 0.6)!.withValues(alpha: 0.75),
        Alignment.bottomRight);
    if (gloss) {
      final g = Rect.fromLTWH(b.left + b.width * 0.16, b.top + b.height * 0.07,
          min(b.width * 0.3, 120), min(b.height * 0.12, 34));
      canvas.drawOval(
          g,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.55)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    }
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.save();
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    canvas.scale(s / 1024);
    const tile = Rect.fromLTWH(0, 0, 1024, 1024);
    final shape = rounded
        ? RRect.fromRectAndRadius(tile, const Radius.circular(225))
        : RRect.fromRectXY(tile, 0, 0);
    canvas.clipRRect(shape);
    _background(canvas);
    canvas.save();
    canvas.translate(512, 512);
    canvas.scale(artScale);
    canvas.translate(-512, -512);
    _art(canvas);
    canvas.restore();
    if (rounded) {
      canvas.drawRRect(
          shape.deflate(3),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6
            ..color = Colors.white.withValues(alpha: 50 / 255));
    }
    canvas.restore();
  }

  void _background(Canvas canvas) {
    const tile = Rect.fromLTWH(0, 0, 1024, 1024);
    canvas.drawRect(
        tile,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF6A48F0), Skin.bg, Skin.bgBottom],
            stops: [0, 0.5, 1],
          ).createShader(tile));
    // Big soft clay blobs at the edges, like the app's world.
    void blob(double cx, double cy, double r, Color col, double a) {
      final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
      canvas.drawCircle(
          Offset(cx, cy),
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

    blob(1010, 70, 330, Skin.hero, 0.45);
    blob(-40, 1000, 360, Skin.sky, 0.3);
    blob(-30, 330, 170, Skin.mint, 0.25);
  }

  void _art(Canvas canvas) {
    // Doorstep slab, then the arch frame.
    final step = Path()
      ..addRRect(
          RRect.fromLTRBR(220, 800, 804, 868, const Radius.circular(34)));
    _clay(canvas, step, Skin.hero, lift: 0.8, gloss: false);
    final frame = _arch(256, 768, 500, 816);
    _clay(canvas, frame, Skin.accent);

    // The room inside: a sunken grape doorway with a lit floor.
    final inside = _arch(330, 694, 500, 816);
    const ib = Rect.fromLTRB(330, 318, 694, 816);
    canvas.drawPath(
        inside,
        Paint()
          ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF2A1290), Color(0xFF3C20B0), Color(0xFF5636D8)],
              stops: [0, 0.6, 1]).createShader(ib));
    canvas.save();
    canvas.clipPath(inside);
    // Inner shadow from the frame's lip.
    canvas.drawPath(
        inside.shift(const Offset(0, 22)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 40
          ..color = Skin.shadow.withValues(alpha: 0.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16));
    // Warm light spilling from the spark.
    canvas.drawCircle(
        const Offset(512, 470),
        230,
        Paint()
          ..shader = RadialGradient(colors: [
            Skin.accent.withValues(alpha: 0.35),
            Skin.accent.withValues(alpha: 0)
          ]).createShader(
              Rect.fromCircle(center: const Offset(512, 470), radius: 230)));
    canvas.drawOval(const Rect.fromLTRB(300, 760, 724, 880),
        Paint()..color = const Color(0xFF6F52F0).withValues(alpha: 0.7));
    canvas.restore();

    // The rivals.
    _pawn(canvas, 422, _blue, facingRight: true);
    _pawn(canvas, 602, _coral, facingRight: false);

    // The spark between them.
    canvas.drawPath(
        _star4(512, 452, 74, 20).shift(const Offset(0, 10)),
        Paint()
          ..color = Skin.shadow.withValues(alpha: 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    canvas.drawPath(
        _star4(512, 452, 74, 20),
        Paint()
          ..shader = const RadialGradient(
                  colors: [Colors.white, Color(0xFFFFE58A), Skin.accent],
                  stops: [0, 0.35, 1])
              .createShader(
                  Rect.fromCircle(center: const Offset(512, 452), radius: 74)));
    // Little zaps either side.
    final zap = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFFFE58A);
    canvas.drawLine(const Offset(436, 432), const Offset(410, 416), zap);
    canvas.drawLine(const Offset(588, 432), const Offset(614, 416), zap);

    // Sparkles and clay beads around the door.
    canvas.drawPath(
        _star4(176, 250, 44, 10), Paint()..color = const Color(0xFFFFF4C2));
    canvas.drawPath(_star4(858, 300, 26, 6), Paint()..color = Colors.white);
    for (final (x, y, r, col) in const [
      (180, 560, 16.0, Skin.mint),
      (850, 560, 14.0, Color(0xFFFF9BD0)),
      (300, 170, 11.0, Colors.white)
    ]) {
      _clay(
          canvas,
          Path()
            ..addOval(Rect.fromCircle(
                center: Offset(x.toDouble(), y.toDouble()), radius: r)),
          col,
          lift: 0.3,
          gloss: false);
    }
  }

  void _pawn(Canvas canvas, double x, Color c, {required bool facingRight}) {
    const base = 792.0, headY = 594.0;
    _clay(canvas, _pawnBody(x, base), c);
    _clay(
        canvas,
        Path()..addOval(Rect.fromCircle(center: Offset(x, headY), radius: 58)),
        c,
        lift: 0.7);

    // Eyes looking at the rival, under angry brows.
    final dir = facingRight ? 1.0 : -1.0;
    for (final ex in [x - 20, x + 20]) {
      canvas.drawOval(
          Rect.fromCenter(center: Offset(ex, headY + 4), width: 26, height: 32),
          Paint()..color = Colors.white);
      canvas.drawCircle(
          Offset(ex + 6 * dir, headY + 8), 8.5, Paint()..color = _ink);
    }
    final brow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = _ink;
    // Each brow slopes down toward the nose.
    canvas.drawLine(
        Offset(x - 34, headY - 24), Offset(x - 10, headY - 14), brow);
    canvas.drawLine(
        Offset(x + 34, headY - 24), Offset(x + 10, headY - 14), brow);
  }

  @override
  bool shouldRepaint(PartyLogoPainter old) =>
      old.rounded != rounded || old.artScale != artScale;
}

/// Just the icon tile.
class PartyLogoIcon extends StatelessWidget {
  final double size;
  const PartyLogoIcon({super.key, this.size = 120});
  @override
  Widget build(BuildContext context) => Semantics(
        image: true,
        label: Skin.name,
        child: SizedBox(
            width: size,
            height: size,
            child: const CustomPaint(painter: PartyLogoPainter())),
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
    TextStyle word(Color fill) => TextStyle(
            fontFamily: fontFamily,
            fontSize: 46 * f,
            height: 1,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5 * f,
            color: fill,
            shadows: [
              Shadow(color: const Color(0xFFE8335C), offset: Offset(0, 4 * f))
            ]);
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
    Widget outlined(String t, Color fill) =>
        Stack(children: [Text(t, style: stroke()), Text(t, style: word(fill))]);
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
              padding:
                  EdgeInsets.symmetric(horizontal: 14 * f, vertical: 5 * f),
              decoration: Skin.pill(color: Skin.hero),
              child: Text('2–6 PLAYERS',
                  style: TextStyle(
                      fontFamily: fontFamily,
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13 * f,
                      letterSpacing: 2 * f)),
            ),
          ]),
        ),
      ),
    );
  }
}
