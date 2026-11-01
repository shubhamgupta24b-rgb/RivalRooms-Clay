import 'dart:math';
import 'package:flutter/material.dart';
import '../models/person.dart';

/// Flat cartoon portrait drawn from the person's attributes, so what you see always
/// matches the answers. Uses [Person.image] instead when that asset exists.
class PersonPortrait extends StatelessWidget {
  final Person person;
  const PersonPortrait(this.person, {super.key});

  @override
  Widget build(BuildContext context) {
    final drawn =
        CustomPaint(painter: _PortraitPainter(person), size: Size.infinite);
    final img = person.image;
    if (img == null) return drawn;
    return Image.asset(img,
        fit: BoxFit.cover, errorBuilder: (_, __, ___) => drawn);
  }
}

const _skin = {
  'light': Color(0xFFF7D3B5),
  'tan': Color(0xFFE0A877),
  'brown': Color(0xFFB57A4F),
  'dark': Color(0xFF7E4E31)
};
// Hair and eye colours are pushed far apart so they can be told apart on small cards.
const _hair = {
  'black': Color(0xFF1C1A1A),
  'brown': Color(0xFF8A5A2B),
  'blonde': Color(0xFFFFD43B),
  'red': Color(0xFFE8501C),
  'gray': Color(0xFFD5D9E0),
};
const _shirt = {
  'red': Color(0xFFE5484D),
  'blue': Color(0xFF3B82F6),
  'green': Color(0xFF2FB36D),
  'yellow': Color(0xFFF6C344)
};
const _hatColors = [
  Color(0xFF7C3AED),
  Color(0xFFDC2626),
  Color(0xFF2563EB),
  Color(0xFF8B5E3C),
  Color(0xFF0F766E)
];
const _eyes = {
  'brown': Color(0xFF9A5B22),
  'blue': Color(0xFF1E88FF),
  'green': Color(0xFF1FB84A)
};

/// The colour a trait is drawn in, e.g. ('hair', 'red'), for swatches on question buttons.
Color? traitColor(String kind, String value) => switch (kind) {
      'skin' => _skin[value],
      'hair' => _hair[value],
      'eyes' => _eyes[value],
      _ => null,
    };

const _gold = Color(0xFFFFB800);
const _ink = Color(0xFF26213A);

class _PortraitPainter extends CustomPainter {
  final Person p;
  _PortraitPainter(this.p);

  @override
  void paint(Canvas canvas, Size size) {
    // Close-up: fit the head (hat to collar, x 0.18-0.82, y 0.05-0.86 of the drawing) to the
    // card so faces are as big as possible; only the shirt's sides get cropped.
    const left = 0.18, right = 0.82, top = 0.05, bottom = 0.86;
    final s = min(size.width / (right - left), size.height / (bottom - top));
    final dx = size.width / 2 - 0.5 * s;
    final dy = (size.height - (bottom - top) * s) / 2 - top * s;
    Offset o(double x, double y) => Offset(dx + x * s, dy + y * s);
    Rect r(double l, double t, double rr, double b) =>
        Rect.fromPoints(o(l, t), o(rr, b));
    Rect oval(double cx, double cy, double w, double h) =>
        Rect.fromCenter(center: o(cx, cy), width: w * s, height: h * s);
    Paint fill(Color c) => Paint()..color = c;
    Paint stroke(Color c, double w) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * s
      ..strokeCap = StrokeCap.round;
    Path poly(List<List<double>> pts) {
      final path = Path()
        ..moveTo(o(pts[0][0], pts[0][1]).dx, o(pts[0][0], pts[0][1]).dy);
      for (final q in pts.skip(1)) {
        path.lineTo(o(q[0], q[1]).dx, o(q[0], q[1]).dy);
      }
      return path..close();
    }

    final skin = _skin[p.skinTone] ?? _skin['light']!;
    final skinShade = Color.lerp(skin, Colors.black, 0.18)!;
    final hair = _hair[p.hairColor] ?? Colors.grey;
    final hairShade = Color.lerp(hair, Colors.black, 0.25)!;
    final shirt = _shirt[p.shirtColor] ?? Colors.grey;
    final hatColor = _hatColors[p.id % _hatColors.length];
    final female = p.gender == Gender.female;

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    // ---- behind the head ----
    if (p.hairStyle == 'long') {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              r(0.21, 0.17, 0.79, 0.88), Radius.circular(0.2 * s)),
          fill(hair));
    }
    if (p.hairStyle == 'bun')
      canvas.drawCircle(o(0.5, 0.13), 0.1 * s, fill(hair));
    if (p.hairStyle == 'curly') {
      for (var a = pi * 0.95; a <= pi * 2.05; a += pi / 8) {
        canvas.drawCircle(o(0.5 + cos(a) * 0.27, 0.44 + sin(a) * 0.29),
            0.085 * s, fill(hair));
      }
    }

    // ---- body ----
    canvas.drawRRect(
        RRect.fromRectAndCorners(r(0.1, 0.8, 0.9, 1.12),
            topLeft: Radius.circular(0.22 * s),
            topRight: Radius.circular(0.22 * s)),
        fill(shirt));
    canvas.drawRect(r(0.41, 0.64, 0.59, 0.84), fill(skinShade));
    canvas.drawPath(
        poly([
          [0.41, 0.8],
          [0.5, 0.9],
          [0.59, 0.8]
        ]),
        fill(skinShade));

    // ---- head ----
    canvas.drawCircle(o(0.25, 0.48), 0.05 * s, fill(skin));
    canvas.drawCircle(o(0.75, 0.48), 0.05 * s, fill(skin));
    canvas.drawOval(oval(0.5, 0.46, 0.5, 0.54), fill(skin));

    // ---- hair on top ----
    switch (p.hairStyle) {
      case 'bald':
        // A little hair left at the sides.
        canvas.drawOval(oval(0.27, 0.41, 0.06, 0.13), fill(hair));
        canvas.drawOval(oval(0.73, 0.41, 0.06, 0.13), fill(hair));
      case 'curly':
        canvas.drawArc(oval(0.5, 0.38, 0.54, 0.4), pi, pi, true, fill(hair));
      default:
        canvas.drawArc(oval(0.5, 0.39, 0.54, 0.42), pi, pi, true, fill(hair));
        // Side-swept fringe.
        canvas.drawPath(
            poly([
              [0.3, 0.32],
              [0.62, 0.24],
              [0.52, 0.36]
            ]),
            fill(hair));
    }
    if (p.hairStyle == 'long') {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              r(0.24, 0.32, 0.3, 0.66), Radius.circular(0.03 * s)),
          fill(hair));
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              r(0.7, 0.32, 0.76, 0.66), Radius.circular(0.03 * s)),
          fill(hair));
    }
    if (p.hairStyle == 'spiky') {
      canvas.drawPath(
          poly([
            [0.27, 0.3],
            [0.31, 0.12],
            [0.39, 0.24],
            [0.45, 0.08],
            [0.52, 0.22],
            [0.6, 0.09],
            [0.64, 0.24],
            [0.72, 0.14],
            [0.73, 0.32]
          ]),
          fill(hair));
    }

    // ---- face ----
    final browColor = p.isBald ? skinShade : hairShade;
    canvas.drawLine(o(0.34, 0.39), o(0.45, 0.375), stroke(browColor, 0.026));
    canvas.drawLine(o(0.55, 0.375), o(0.66, 0.39), stroke(browColor, 0.026));
    // Big eyes with a large coloured iris and a small pupil, so the colour reads at card size.
    final iris = _eyes[p.eyeColor] ?? _eyes['brown']!;
    for (final x in [0.395, 0.605]) {
      canvas.drawOval(oval(x, 0.465, 0.135, 0.115), fill(Colors.white));
      canvas.drawOval(oval(x, 0.465, 0.135, 0.115),
          stroke(Color.lerp(_ink, Colors.white, 0.5)!, 0.008));
      canvas.drawCircle(o(x, 0.468), 0.046 * s, fill(iris));
      canvas.drawCircle(o(x, 0.468), 0.046 * s,
          stroke(Color.lerp(iris, Colors.black, 0.45)!, 0.008));
      canvas.drawCircle(o(x, 0.468), 0.018 * s, fill(_ink));
      canvas.drawCircle(o(x + 0.016, 0.452), 0.012 * s, fill(Colors.white));
    }
    if (female) {
      final lash = stroke(_ink, 0.014);
      canvas.drawLine(o(0.335, 0.44), o(0.31, 0.42), lash);
      canvas.drawLine(o(0.665, 0.44), o(0.69, 0.42), lash);
    }
    canvas.drawOval(oval(0.5, 0.545, 0.07, 0.05), fill(skinShade));
    canvas.drawCircle(o(0.33, 0.56), 0.03 * s, fill(const Color(0x33FF4D4D)));
    canvas.drawCircle(o(0.67, 0.56), 0.03 * s, fill(const Color(0x33FF4D4D)));

    // ---- facial hair (mouth is drawn on top) ----
    if (p.hasBeard) {
      canvas.drawArc(
          oval(0.5, 0.5, 0.51, 0.46), 0.05, pi - 0.1, true, fill(hair));
      canvas.drawRect(r(0.27, 0.5, 0.73, 0.55), fill(hair));
    }
    if (p.hasBeard || p.hasMustache) {
      canvas.drawOval(oval(0.455, 0.585, 0.11, 0.045), fill(hairShade));
      canvas.drawOval(oval(0.545, 0.585, 0.11, 0.045), fill(hairShade));
    }
    if (female) {
      canvas.drawArc(oval(0.5, 0.615, 0.13, 0.08), 0.1, pi - 0.2, true,
          fill(const Color(0xFFD94D63)));
    } else {
      canvas.drawArc(oval(0.5, 0.615, 0.13, 0.07), 0.15, pi - 0.3, true,
          fill(const Color(0xFF8A2C2C)));
      canvas.drawArc(oval(0.5, 0.615, 0.08, 0.03), 0.15, pi - 0.3, true,
          fill(Colors.white));
    }

    // ---- glasses ----
    if (p.hasGlasses) {
      // Thick frames around (not over) the eyes, so the eye colour stays visible.
      final frame = stroke(_ink, 0.022);
      for (final x in [0.395, 0.605]) {
        canvas.drawCircle(o(x, 0.467), 0.088 * s, frame);
      }
      canvas.drawLine(o(0.483, 0.462), o(0.517, 0.462), frame);
      canvas.drawLine(o(0.307, 0.455), o(0.255, 0.445), frame);
      canvas.drawLine(o(0.693, 0.455), o(0.745, 0.445), frame);
    }

    // ---- hats ----
    final light = Color.lerp(hatColor, Colors.white, 0.35)!;
    switch (p.hat) {
      case 'cap':
        canvas.drawArc(
            oval(0.5, 0.34, 0.56, 0.4), pi, pi, true, fill(hatColor));
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                r(0.42, 0.3, 0.86, 0.36), Radius.circular(0.03 * s)),
            fill(Color.lerp(hatColor, Colors.black, 0.2)!));
        canvas.drawCircle(o(0.5, 0.14), 0.022 * s, fill(light));
      case 'beanie':
        canvas.drawArc(
            oval(0.5, 0.36, 0.56, 0.46), pi, pi, true, fill(hatColor));
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                r(0.22, 0.3, 0.78, 0.39), Radius.circular(0.04 * s)),
            fill(light));
        canvas.drawCircle(o(0.5, 0.12), 0.045 * s, fill(light));
      case 'fedora':
        canvas.drawOval(oval(0.5, 0.31, 0.78, 0.1), fill(hatColor));
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                r(0.32, 0.1, 0.68, 0.31), Radius.circular(0.07 * s)),
            fill(hatColor));
        canvas.drawRect(r(0.32, 0.24, 0.68, 0.28), fill(_ink));
      case 'beret':
        canvas.save();
        canvas.translate(o(0.46, 0.22).dx, o(0.46, 0.22).dy);
        canvas.rotate(-0.15);
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset.zero, width: 0.62 * s, height: 0.2 * s),
            fill(hatColor));
        canvas.restore();
        canvas.drawCircle(o(0.5, 0.12), 0.025 * s, fill(hatColor));
    }

    // ---- accessories ----
    switch (p.accessory) {
      case 'earrings':
        canvas.drawCircle(o(0.25, 0.55), 0.024 * s, fill(_gold));
        canvas.drawCircle(o(0.75, 0.55), 0.024 * s, fill(_gold));
      case 'necklace':
        canvas.drawArc(oval(0.5, 0.79, 0.26, 0.14), 0.15, pi - 0.3, false,
            stroke(_gold, 0.018));
        canvas.drawCircle(o(0.5, 0.87), 0.025 * s, fill(_gold));
      case 'bowtie':
        canvas.drawPath(
            poly([
              [0.5, 0.86],
              [0.4, 0.81],
              [0.4, 0.91]
            ]),
            fill(_ink));
        canvas.drawPath(
            poly([
              [0.5, 0.86],
              [0.6, 0.81],
              [0.6, 0.91]
            ]),
            fill(_ink));
        canvas.drawCircle(o(0.5, 0.86), 0.022 * s, fill(_ink));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PortraitPainter old) => old.p.id != p.id;
}
