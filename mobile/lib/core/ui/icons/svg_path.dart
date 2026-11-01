import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

/// A tiny SVG path-data parser (M L H V C S Q T A Z, absolute and relative), so drawings
/// from the design mockups (docs/ui-redesign/mockups/*.dc.html) can be ported as their
/// original path strings. No package needed.
Path svgPath(String d) {
  final path = Path();
  final tokens =
      RegExp(r'[MmLlHhVvCcSsQqTtAaZz]|-?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?')
          .allMatches(d)
          .map((m) => m.group(0)!)
          .toList();
  var i = 0;
  var cmd = 'M';
  var x = 0.0, y = 0.0, sx = 0.0, sy = 0.0;
  double? lcx, lcy; // last control point (for S / T)
  bool isCmd(String s) => RegExp(r'^[A-Za-z]$').hasMatch(s);
  double n() => double.parse(tokens[i++]);
  while (i < tokens.length) {
    if (isCmd(tokens[i])) cmd = tokens[i++];
    final rel = cmd == cmd.toLowerCase();
    final ox = rel ? x : 0.0, oy = rel ? y : 0.0;
    switch (cmd.toUpperCase()) {
      case 'M':
        x = ox + n();
        y = oy + n();
        path.moveTo(x, y);
        sx = x;
        sy = y;
        cmd = rel ? 'l' : 'L'; // further pairs are line-tos
        lcx = null;
      case 'L':
        x = ox + n();
        y = oy + n();
        path.lineTo(x, y);
        lcx = null;
      case 'H':
        x = ox + n();
        path.lineTo(x, y);
        lcx = null;
      case 'V':
        y = oy + n();
        path.lineTo(x, y);
        lcx = null;
      case 'C':
        final x1 = ox + n(), y1 = oy + n(), x2 = ox + n(), y2 = oy + n();
        x = ox + n();
        y = oy + n();
        path.cubicTo(x1, y1, x2, y2, x, y);
        lcx = x2;
        lcy = y2;
      case 'S':
        final x1 = lcx == null ? x : 2 * x - lcx,
            y1 = lcx == null ? y : 2 * y - lcy!;
        final x2 = ox + n(), y2 = oy + n();
        x = ox + n();
        y = oy + n();
        path.cubicTo(x1, y1, x2, y2, x, y);
        lcx = x2;
        lcy = y2;
      case 'Q':
        final x1 = ox + n(), y1 = oy + n();
        x = ox + n();
        y = oy + n();
        path.quadraticBezierTo(x1, y1, x, y);
        lcx = x1;
        lcy = y1;
      case 'T':
        final x1 = lcx == null ? x : 2 * x - lcx,
            y1 = lcx == null ? y : 2 * y - lcy!;
        x = ox + n();
        y = oy + n();
        path.quadraticBezierTo(x1, y1, x, y);
        lcx = x1;
        lcy = y1;
      case 'A':
        final rx = n(), ry = n(), rot = n(), large = n() != 0, sweep = n() != 0;
        x = ox + n();
        y = oy + n();
        path.arcToPoint(Offset(x, y),
            radius: Radius.elliptical(rx, ry),
            rotation: rot,
            largeArc: large,
            clockwise: sweep);
        lcx = null;
      case 'Z':
        path.close();
        x = sx;
        y = sy;
        lcx = null;
      default:
        i++;
    }
  }
  return path;
}

/// Shape helpers in SVG terms.
Path svgCircle(double cx, double cy, double r) =>
    Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
Path svgEllipse(double cx, double cy, double rx, double ry) => Path()
  ..addOval(
      Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2));
Path svgRect(double x, double y, double w, double h, [double r = 0]) => Path()
  ..addRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)));
Path svgPolygon(List<double> pts) {
  final p = Path()..moveTo(pts[0], pts[1]);
  for (var k = 2; k + 1 < pts.length; k += 2) {
    p.lineTo(pts[k], pts[k + 1]);
  }
  return p..close();
}

Path svgLine(double x1, double y1, double x2, double y2) => Path()
  ..moveTo(x1, y1)
  ..lineTo(x2, y2);

/// [p] rotated by [deg] degrees around ([cx], [cy]), like SVG `rotate(deg cx cy)`.
Path svgRotate(Path p, double deg, double cx, double cy) {
  final a = deg * math.pi / 180;
  final m = Float64List.fromList([
    math.cos(a),
    math.sin(a),
    0,
    0,
    -math.sin(a),
    math.cos(a),
    0,
    0,
    0,
    0,
    1,
    0,
    cx - cx * math.cos(a) + cy * math.sin(a),
    cy - cx * math.sin(a) - cy * math.cos(a),
    0,
    1
  ]);
  return p.transform(m);
}

/// One drawing step: a path filled and/or stroked. A null colour means "the icon's colour"
/// (SVG `currentColor`).
class InkStroke {
  final double width;
  final StrokeCap cap;
  final StrokeJoin join;
  const InkStroke(this.width,
      {this.cap = StrokeCap.round, this.join = StrokeJoin.round});
}

class IconInk {
  final Path path;
  final Color? fill;
  final bool fillCurrent; // fill with the icon colour
  final Color? stroke;
  final bool strokeCurrent; // stroke with the icon colour
  final InkStroke? style;
  final double opacity;
  final Path? clip;
  const IconInk(this.path,
      {this.fill,
      this.fillCurrent = false,
      this.stroke,
      this.strokeCurrent = false,
      this.style,
      this.opacity = 1,
      this.clip});

  void paint(Canvas canvas, Color current) {
    if (clip != null) {
      canvas.save();
      canvas.clipPath(clip!);
    }
    final f = fillCurrent ? current : fill;
    if (f != null)
      canvas.drawPath(
          path, Paint()..color = f.withValues(alpha: f.a * opacity));
    final s = strokeCurrent ? current : stroke;
    if (s != null) {
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = style?.width ?? 2
            ..strokeCap = style?.cap ?? StrokeCap.round
            ..strokeJoin = style?.join ?? StrokeJoin.round
            ..color = s.withValues(alpha: s.a * opacity));
    }
    if (clip != null) canvas.restore();
  }
}
