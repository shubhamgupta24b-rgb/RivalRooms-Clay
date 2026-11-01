import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Reusable game surfaces (UI_SPEC 1.6) so every game draws the same realistic materials.
/// Colours come from the spec and the mockups in docs/ui-redesign/mockups/ (felt, card back
/// and paper cards from memory/Main; sky and grass from archery/Main; sunset sky and asphalt
/// from the original kart racing prototype. Each painter is pure and repaints only when its inputs change.

/// Card-table felt: a radial green (#136457 → #0D4A41 → #08332D), an optional 3 px wood rim
/// (#6B4423), a thin gold inner line and a soft inner shadow.
class FeltPainter extends CustomPainter {
  final bool rim;
  final double radius;
  const FeltPainter({this.rim = true, this.radius = 24});

  static const centre = Color(0xFF136457),
      mid = Color(0xFF0D4A41),
      edge = Color(0xFF08332D);
  static const rimWood = Color(0xFF6B4423), goldLine = Color(0x59E9C46A);

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(r, Radius.circular(radius));
    canvas.drawRRect(
        rr,
        Paint()
          ..shader = const RadialGradient(
              center: Alignment(0, -0.2),
              radius: 0.85,
              colors: [centre, mid, edge],
              stops: [0, 0.6, 1]).createShader(r));
    // Faint felt fibres.
    final fibre = Paint()..color = Colors.white.withValues(alpha: 0.025);
    final rng = math.Random(7);
    for (var i = 0; i < 90; i++) {
      final p =
          Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height);
      canvas.drawLine(
          p,
          p + Offset(rng.nextDouble() * 6 - 3, rng.nextDouble() * 6 - 3),
          fibre..strokeWidth = 1);
    }
    // Inner shadow at the top edge.
    canvas.save();
    canvas.clipRRect(rr);
    canvas.drawRRect(
        rr.shift(const Offset(0, -8)).inflate(10),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 20
          ..color = Colors.black.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 11));
    canvas.restore();
    if (rim) {
      canvas.drawRRect(
          rr.deflate(1.5),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = rimWood);
      canvas.drawRRect(
          rr.deflate(4),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = goldLine);
    }
  }

  @override
  bool shouldRepaint(FeltPainter old) => old.rim != rim || old.radius != radius;
}

/// A warm wooden board with subtle grain lines (Ludo, Checkers, Snakes & Ladders,
/// Tic-Tac-Toe and Connect Four frames).
class WoodPainter extends CustomPainter {
  final Color light, dark;
  final double radius;
  final int seed;
  const WoodPainter(
      {this.light = const Color(0xFFA06A35),
      this.dark = const Color(0xFF6B4220),
      this.radius = 24,
      this.seed = 3});

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(r, Radius.circular(radius));
    canvas.drawRRect(
        rr,
        Paint()
          ..shader = LinearGradient(
                  colors: [light, dark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight)
              .createShader(r));
    canvas.save();
    canvas.clipRRect(rr);
    final rng = math.Random(seed);
    final grain = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    for (var y = 4.0; y < size.height; y += 6 + rng.nextDouble() * 7) {
      grain.color =
          Colors.black.withValues(alpha: 0.06 + rng.nextDouble() * 0.08);
      final wobble = 2 + rng.nextDouble() * 5;
      final path = Path()..moveTo(0, y);
      for (var x = 0.0; x <= size.width; x += size.width / 6) {
        path.quadraticBezierTo(x + size.width / 12,
            y + (rng.nextBool() ? wobble : -wobble), x + size.width / 6, y);
      }
      canvas.drawPath(path, grain);
    }
    // A knot or two.
    for (var k = 0; k < 2; k++) {
      final c =
          Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height);
      canvas.drawOval(
          Rect.fromCenter(center: c, width: 14, height: 6),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = Colors.black.withValues(alpha: 0.12));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(WoodPainter old) =>
      old.light != light || old.dark != dark || old.radius != radius;
}

/// A face-up paper card: cream face (#FFFDF6 → #F5E9D2), inner hairline (#E2D3B5), drop
/// shadow. [tint] washes the face in a player's colour (e.g. a matched card) and draws a
/// 2.5 px border in it.
class PaperCard extends StatelessWidget {
  final Widget? child;
  final double radius;
  final Color? tint;
  final double elevation;
  const PaperCard(
      {super.key, this.child, this.radius = 10, this.tint, this.elevation = 4});

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter:
            PaperCardPainter(radius: radius, tint: tint, elevation: elevation),
        child: child,
      );
}

class PaperCardPainter extends CustomPainter {
  final double radius;
  final Color? tint;
  final double elevation;
  const PaperCardPainter({this.radius = 10, this.tint, this.elevation = 4});

  static const top = Color(0xFFFFFDF6),
      bottom = Color(0xFFF5E9D2),
      hairline = Color(0xFFE2D3B5);

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(r, Radius.circular(radius));
    if (elevation > 0)
      canvas.drawRRect(
          rr.shift(Offset(1, elevation)),
          Paint()
            ..color =
                Colors.black.withValues(alpha: tint == null ? 0.35 : 0.25));
    canvas.drawRRect(
        rr,
        Paint()
          ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [top, bottom]).createShader(r));
    if (tint != null) {
      canvas.drawRRect(rr, Paint()..color = tint!.withValues(alpha: 0.16));
      canvas.drawRRect(
          rr.deflate(1.25),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = tint!);
    } else {
      final inset = size.width * 0.05;
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              r.deflate(inset), Radius.circular(radius * 0.7)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = hairline);
    }
  }

  @override
  bool shouldRepaint(PaperCardPainter old) =>
      old.radius != radius || old.tint != tint || old.elevation != elevation;
}

/// The face-down card back used by every card game: cream border, indigo field
/// (#3B2D9A → #1F1666), gold lattice at 28 %, gold inner border, centre emblem.
/// Ported from the `<g id="back">` group in mockups/memory/Main.dc.html (77.5 × 90 card).
class CardBack extends StatelessWidget {
  final double radius;
  const CardBack({super.key, this.radius = 10});
  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: CardBackPainter(radius: radius));
}

class CardBackPainter extends CustomPainter {
  final double radius;
  const CardBackPainter({this.radius = 10});

  static const border = Color(0xFFFFF8EC),
      indigoTop = Color(0xFF3B2D9A),
      indigoBottom = Color(0xFF1F1666),
      gold = Color(0xFFE9C46A),
      emblem = Color(0xFF22186B);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final k = w / 77.5; // the mockup card is 77.5 wide
    final outer =
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    canvas.drawRRect(outer.shift(Offset(1 * k, 4 * k)),
        Paint()..color = Colors.black.withValues(alpha: 0.35));
    canvas.drawRRect(outer, Paint()..color = border);
    final field = Rect.fromLTWH(4 * k, 4 * k, w - 8 * k, h - 8 * k);
    final fieldR =
        RRect.fromRectAndRadius(field, Radius.circular(radius * 0.7));
    canvas.drawRRect(
        fieldR,
        Paint()
          ..shader = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [indigoTop, indigoBottom]).createShader(field));
    // Lattice.
    canvas.save();
    canvas.clipRRect(fieldR);
    final lattice = Paint()
      ..color = gold.withValues(alpha: 0.28)
      ..strokeWidth = 0.8 * k;
    final step = 12 * k;
    for (var x = -h; x < w + h; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x + h, h), lattice);
      canvas.drawLine(Offset(x, 0), Offset(x - h, h), lattice);
    }
    canvas.restore();
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(8.5 * k, 8.5 * k, w - 17 * k, h - 17 * k),
            Radius.circular(radius * 0.5)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1 * k
          ..color = gold.withValues(alpha: 0.85));
    // Emblem: a diamond with a ring and a dot.
    final c = Offset(w / 2, h / 2);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(math.pi / 4);
    final d =
        Rect.fromCenter(center: Offset.zero, width: 22 * k, height: 22 * k);
    canvas.drawRect(d, Paint()..color = emblem);
    canvas.drawRect(
        d,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 * k
          ..color = gold);
    canvas.restore();
    canvas.drawCircle(
        c,
        5 * k,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 * k
          ..color = gold);
    canvas.drawCircle(c, 1.6 * k, Paint()..color = gold);
  }

  @override
  bool shouldRepaint(CardBackPainter old) => old.radius != radius;
}

enum SkyTime { day, sunset, night }

/// Skies (spec 1.6): day (#21458A → #5B94D4 → #BFD7EC → #F2D49B), sunset (#1D1646 →
/// #5E2C6E → #E0556A → #FFB45E), night (#0B0E2E → #151A4A with stars). [horizon] is
/// the fraction of the height where the sky meets the ground (for sun/hills helpers).
class SkyPainter extends CustomPainter {
  final SkyTime time;
  final bool sun, clouds, hills, trees;
  final double horizon;
  final double drift; // 0..1, moves the clouds
  const SkyPainter(
      {this.time = SkyTime.day,
      this.sun = true,
      this.clouds = true,
      this.hills = false,
      this.trees = false,
      this.horizon = 0.78,
      this.drift = 0});

  static const day = [
    Color(0xFF21458A),
    Color(0xFF5B94D4),
    Color(0xFFBFD7EC),
    Color(0xFFF2D49B)
  ];
  static const sunset = [
    Color(0xFF1D1646),
    Color(0xFF5E2C6E),
    Color(0xFFE0556A),
    Color(0xFFFFB45E)
  ];
  static const night = [Color(0xFF0B0E2E), Color(0xFF151A4A)];

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final colors = switch (time) {
      SkyTime.day => day,
      SkyTime.sunset => sunset,
      SkyTime.night => night
    };
    canvas.drawRect(
        r,
        Paint()
          ..shader = LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: colors)
              .createShader(
                  Rect.fromLTWH(0, 0, size.width, size.height * horizon)));
    if (time == SkyTime.night) drawStars(canvas, size);
    if (sun)
      drawSun(canvas, Offset(size.width * 0.76, size.height * horizon * 0.7),
          size.width * 0.06, time);
    if (clouds && time != SkyTime.night) drawClouds(canvas, size, drift);
    if (hills) drawHills(canvas, size, size.height * horizon, time);
    if (trees) drawTreeLine(canvas, size, size.height * horizon);
  }

  static void drawStars(Canvas canvas, Size size) {
    final rng = math.Random(11);
    for (var i = 0; i < 50; i++) {
      final p = Offset(
          rng.nextDouble() * size.width, rng.nextDouble() * size.height * 0.7);
      canvas.drawCircle(
          p,
          rng.nextDouble() * 1.3 + 0.4,
          Paint()
            ..color =
                Colors.white.withValues(alpha: 0.3 + rng.nextDouble() * 0.6));
    }
  }

  static void drawSun(Canvas canvas, Offset c, double r, SkyTime time) {
    final core = time == SkyTime.sunset
        ? const Color(0xFFFFD27A)
        : const Color(0xFFFFF3C4);
    canvas.drawCircle(
        c,
        r * 2.4,
        Paint()
          ..shader = RadialGradient(colors: [
            core.withValues(alpha: 0.45),
            core.withValues(alpha: 0)
          ]).createShader(Rect.fromCircle(center: c, radius: r * 2.4)));
    canvas.drawCircle(c, r, Paint()..color = core);
  }

  static void drawClouds(Canvas canvas, Size size, double drift) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.85);
    for (final (x, y, k) in const [
      (0.15, 0.16, 1.0),
      (0.58, 0.1, 0.8),
      (0.86, 0.26, 1.15)
    ]) {
      final cx = ((x + drift * k) % 1.25 - 0.1) * size.width,
          cy = y * size.height,
          s = size.width * 0.05 * k;
      for (final (dx, dy, rr) in const [
        (0.0, 0.0, 1.0),
        (1.0, -0.36, 0.84),
        (-1.0, 0.1, 0.72),
        (1.8, 0.16, 0.6)
      ]) {
        canvas.drawCircle(Offset(cx + dx * s, cy + dy * s), rr * s, paint);
      }
    }
  }

  /// Far hills as a wavy silhouette ending at [groundY].
  static void drawHills(
      Canvas canvas, Size size, double groundY, SkyTime time) {
    final path = Path()..moveTo(0, groundY);
    for (var x = 0.0; x <= size.width; x += size.width / 18) {
      path.lineTo(
          x,
          groundY -
              size.height * 0.05 -
              math.sin(x / size.width * 7) * size.height * 0.03);
    }
    path
      ..lineTo(size.width, groundY)
      ..close();
    canvas.drawPath(
        path,
        Paint()
          ..color = time == SkyTime.sunset
              ? const Color(0xFF3B2347)
              : const Color(0xFF2E5634));
  }

  /// A row of rounded tree tops on the horizon (as in the archery mockups).
  static void drawTreeLine(Canvas canvas, Size size, double groundY) {
    final path = Path()..moveTo(0, groundY);
    final bump = size.width / 18;
    for (var x = 0.0; x < size.width; x += bump) {
      path.quadraticBezierTo(
          x + bump / 2,
          groundY - bump * 1.1 - (x / bump % 2) * bump * 0.25,
          x + bump,
          groundY - bump * 0.3);
    }
    path
      ..lineTo(size.width, groundY)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFF2E5634));
  }

  @override
  bool shouldRepaint(SkyPainter old) =>
      old.time != time ||
      old.sun != sun ||
      old.clouds != clouds ||
      old.hills != hills ||
      old.trees != trees ||
      old.horizon != horizon ||
      old.drift != drift;
}

/// Grass (#7FBD50 → #4A8A30) with soft horizontal mowing stripes.
class GrassPainter extends CustomPainter {
  final int stripes;
  const GrassPainter({this.stripes = 10});
  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.drawRect(
        r,
        Paint()
          ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF7FBD50), Color(0xFF4A8A30)]).createShader(r));
    final band = Paint()..color = Colors.white.withValues(alpha: 0.06);
    final h = size.height / stripes;
    for (var i = 0; i < stripes; i += 2) {
      canvas.drawRect(Rect.fromLTWH(0, i * h, size.width, h), band);
    }
  }

  @override
  bool shouldRepaint(GrassPainter old) => old.stripes != stripes;
}

/// Asphalt (#565A66 → #30333B) with skid marks and an optional red/white kerb along the
/// top and bottom edges.
class AsphaltPainter extends CustomPainter {
  final bool kerbs;
  const AsphaltPainter({this.kerbs = true});
  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.drawRect(
        r,
        Paint()
          ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF565A66), Color(0xFF30333B)]).createShader(r));
    final rng = math.Random(5);
    final skid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = Colors.black.withValues(alpha: 0.25);
    for (var i = 0; i < 6; i++) {
      final a =
          Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height);
      canvas.drawPath(
          Path()
            ..moveTo(a.dx, a.dy)
            ..quadraticBezierTo(a.dx + 30, a.dy - 20, a.dx + 70, a.dy - 6),
          skid);
    }
    if (kerbs) {
      final w = size.width / 14;
      for (var i = 0; i < 14; i++) {
        final color = i.isEven ? const Color(0xFFE5383B) : Colors.white;
        canvas.drawRect(Rect.fromLTWH(i * w, 0, w, 7), Paint()..color = color);
        canvas.drawRect(Rect.fromLTWH(i * w, size.height - 7, w, 7),
            Paint()..color = color);
      }
    }
  }

  @override
  bool shouldRepaint(AsphaltPainter old) => old.kerbs != kerbs;
}

/// Sea (#1B6CA8 → #0E3F6B) with light wave lines (Battleship).
class WaterPainter extends CustomPainter {
  final double phase; // 0..1, moves the waves
  final double radius;
  const WaterPainter({this.phase = 0, this.radius = 12});
  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(r, Radius.circular(radius));
    canvas.drawRRect(
        rr,
        Paint()
          ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1B6CA8), Color(0xFF0E3F6B)]).createShader(r));
    canvas.save();
    canvas.clipRRect(rr);
    final wave = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = Colors.white.withValues(alpha: 0.12);
    final step = size.height / 8;
    for (var y = step / 2; y < size.height; y += step) {
      final path = Path()..moveTo(-20, y);
      for (var x = -20.0; x <= size.width + 20; x += 20) {
        path.quadraticBezierTo(x + 10 + phase * 20, y - 4, x + 20, y);
      }
      canvas.drawPath(path, wave);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(WaterPainter old) =>
      old.phase != phase || old.radius != radius;
}

/// A polished wooden court or table top (Basketball, Ping Pong, Air Hockey surrounds):
/// planks with alternating tones and a varnish sheen.
class CourtPainter extends CustomPainter {
  final int planks;
  final double radius;
  const CourtPainter({this.planks = 9, this.radius = 0});
  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(r, Radius.circular(radius));
    canvas.save();
    canvas.clipRRect(rr);
    final w = size.width / planks;
    for (var i = 0; i < planks; i++) {
      canvas.drawRect(
          Rect.fromLTWH(i * w, 0, w + 0.5, size.height),
          Paint()
            ..color =
                i.isEven ? const Color(0xFFD9A066) : const Color(0xFFCF9358));
      canvas.drawLine(
          Offset(i * w, 0),
          Offset(i * w, size.height),
          Paint()
            ..color = const Color(0x33000000)
            ..strokeWidth = 1);
    }
    canvas.drawRect(
        r,
        Paint()
          ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.18),
                Colors.white.withValues(alpha: 0),
                Colors.black.withValues(alpha: 0.12)
              ]).createShader(r));
    canvas.restore();
  }

  @override
  bool shouldRepaint(CourtPainter old) =>
      old.planks != planks || old.radius != radius;
}
