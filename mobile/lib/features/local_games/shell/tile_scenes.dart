import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/ui/components.dart';

/// Small drawn gameplay scenes for each game's tile art (hub, rooms, records, intro):
/// a glimpse of the game itself (the board, the pieces, the moment) instead of one icon.
/// Painted over the game's ground by GameArtPainter. Returns false for games without one.
bool paintTileScene(Canvas canvas, Size size, String id, Color color) {
  final scene = _scenes[id] ?? (id.startsWith('ludo') ? _scenes['ludo'] : null);
  if (scene == null) return false;
  // The scene's box: 1.3 wide for every 1 tall, centred, with a margin.
  final bw = min(size.width * 0.9, size.height * 0.84 * 1.3);
  final b = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.52),
      width: bw,
      height: bw / 1.3);
  scene(_Kit(canvas, b, color));
  return true;
}

// Shared colours.
const _red = Color(0xFFFF4D6D),
    _blue = Color(0xFF3A86FF),
    _yellow = Color(0xFFFFC21A),
    _green = Color(0xFF2ECC71);
const _orange = Color(0xFFFF8C42),
    _purple = Color(0xFF9B5DE5),
    _teal = Color(0xFF2EC4B6),
    _ink = Color(0xFF2B2440);
const _cream = Color(0xFFFFF4DE),
    _woodLight = Color(0xFFE2B47A),
    _woodDark = Color(0xFF9A6434);

/// Drawing helpers in scene units: x 0..1.3 and y 0..1 across the box ([p]); sizes in box heights ([u]).
class _Kit {
  final Canvas c;
  final Rect b;
  final Color color;
  _Kit(this.c, this.b, this.color);

  double get u => b.height;
  Offset p(double x, double y) => b.topLeft + Offset(x * u, y * u);
  Rect r(double x, double y, double w, double h) =>
      Rect.fromLTWH(b.left + x * u, b.top + y * u, w * u, h * u);
  Rect rc(double x, double y, double w, double h) =>
      Rect.fromCenter(center: p(x, y), width: w * u, height: h * u);

  Color light(Color c, [double t = 0.4]) => Color.lerp(c, Colors.white, t)!;
  Color dark(Color c, [double t = 0.3]) => Color.lerp(c, Colors.black, t)!;

  /// A soft drop shadow under [rect].
  void shadow(RRect rect,
          {double dy = 0.04, double alpha = 0.32, double blur = 3}) =>
      c.drawRRect(
          rect.shift(Offset(0, dy * u)),
          Paint()
            ..color = Colors.black.withValues(alpha: alpha)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur));

  /// A clay block: shadow, body with a top-lit gradient, and a highlight rim.
  void block(Rect rect, Color fill, {double radius = 0.06, bool shade = true}) {
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(radius * u));
    if (shade) shadow(rr, dy: 0.03, alpha: 0.28);
    c.drawRRect(
        rr,
        Paint()
          ..shader = LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [light(fill, 0.22), fill, dark(fill, 0.18)])
              .createShader(rect));
    c.drawRRect(
        rr.deflate(0.006 * u),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.012 * u
          ..color = Colors.white.withValues(alpha: 0.28));
  }

  /// A shiny ball.
  void ball(Offset at, double radius, Color fill, {bool shade = true}) {
    final rad = radius * u;
    if (shade)
      c.drawOval(
          Rect.fromCenter(
              center: at + Offset(0, rad * 0.95),
              width: rad * 1.7,
              height: rad * 0.45),
          Paint()
            ..color = Colors.black.withValues(alpha: 0.25)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    c.drawCircle(
        at,
        rad,
        Paint()
          ..shader = RadialGradient(
                  center: const Alignment(-0.35, -0.45),
                  colors: [light(fill, 0.55), fill, dark(fill, 0.3)],
                  stops: const [0, 0.55, 1])
              .createShader(Rect.fromCircle(center: at, radius: rad)));
    c.drawCircle(at + Offset(-rad * 0.35, -rad * 0.4), rad * 0.2,
        Paint()..color = Colors.white.withValues(alpha: 0.6));
  }

  /// A flat game piece seen from above (checkers, discs).
  void disc(Offset at, double radius, Color fill) {
    final rad = radius * u;
    c.drawCircle(
        at + Offset(0, rad * 0.18), rad, Paint()..color = dark(fill, 0.45));
    c.drawCircle(
        at,
        rad,
        Paint()
          ..shader = RadialGradient(
                  center: const Alignment(-0.3, -0.4),
                  colors: [light(fill, 0.35), fill])
              .createShader(Rect.fromCircle(center: at, radius: rad)));
    c.drawCircle(
        at,
        rad * 0.68,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = rad * 0.1
          ..color = dark(fill, 0.15));
  }

  void line(Offset a, Offset z, Color col, double width,
          {StrokeCap cap = StrokeCap.round}) =>
      c.drawLine(
          a,
          z,
          Paint()
            ..color = col
            ..strokeWidth = width * u
            ..strokeCap = cap);

  void stroke(Path path, Color col, double width) => c.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = col
        ..strokeWidth = width * u
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round);

  void fill(Path path, Color col) => c.drawPath(path, Paint()..color = col);

  void icon(GameIcons i, Offset at, double s, {Color col = Colors.white}) =>
      paintIcon(c, i, Rect.fromCenter(center: at, width: s * u, height: s * u),
          color: col);

  /// Bold text centred at [at] (numbers on tiles, letters).
  void text(String s, Offset at, double size, Color col,
      {String family = Fonts.display}) {
    final tp = TextPainter(
        text: TextSpan(
            text: s,
            style: TextStyle(
                fontFamily: family,
                fontSize: size * u,
                color: col,
                height: 1,
                fontWeight: FontWeight.w900)),
        textDirection: TextDirection.ltr)
      ..layout();
    tp.paint(c, at - Offset(tp.width / 2, tp.height / 2));
    tp.dispose();
  }

  /// A card turned by [turn] radians around its centre, drawn by [face] in card-local units.
  void card(Offset at, double w, double h, double turn, Color fill,
      [void Function(Rect inner)? face]) {
    c.save();
    c.translate(at.dx, at.dy);
    c.rotate(turn);
    final rect =
        Rect.fromCenter(center: Offset.zero, width: w * u, height: h * u);
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(w * u * 0.13));
    shadow(rr, dy: 0.035);
    c.drawRRect(rr, Paint()..color = Colors.white);
    final inner = rect.deflate(w * u * 0.08);
    c.drawRRect(
        RRect.fromRectAndRadius(inner, Radius.circular(w * u * 0.08)),
        Paint()
          ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [light(fill, 0.15), fill]).createShader(inner));
    face?.call(inner);
    c.restore();
  }

  /// An n x m board of alternating squares.
  void checker(Rect rect, int cols, int rows, Color a, Color z,
      {double radius = 0.05}) {
    final rr = RRect.fromRectAndRadius(
        rect.inflate(0.025 * u), Radius.circular(radius * u));
    shadow(rr);
    c.drawRRect(rr, Paint()..color = dark(z, 0.35));
    final cw = rect.width / cols, ch = rect.height / rows;
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        c.drawRect(
            Rect.fromLTWH(
                rect.left + x * cw, rect.top + y * ch, cw + 0.5, ch + 0.5),
            Paint()..color = (x + y).isEven ? a : z);
      }
    }
  }

  /// A white rounded panel (paper, a phone screen, a card) with a shadow.
  void panel(Rect rect, {Color fill = _cream, double radius = 0.06}) {
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(radius * u));
    shadow(rr);
    c.drawRRect(rr, Paint()..color = fill);
  }
}

/// A pawn-like playing piece standing at [at] (its base), [h] tall.
void _pawn(_Kit k, Offset at, double h, Color col) {
  final u = k.u * h;
  final body = Path()
    ..moveTo(at.dx - u * 0.36, at.dy)
    ..quadraticBezierTo(
        at.dx - u * 0.3, at.dy - u * 0.25, at.dx - u * 0.12, at.dy - u * 0.55)
    ..lineTo(at.dx + u * 0.12, at.dy - u * 0.55)
    ..quadraticBezierTo(
        at.dx + u * 0.3, at.dy - u * 0.25, at.dx + u * 0.36, at.dy)
    ..close();
  k.c.drawOval(Rect.fromCenter(center: at, width: u * 0.9, height: u * 0.18),
      Paint()..color = Colors.black.withValues(alpha: 0.3));
  k.c.drawPath(
      body,
      Paint()
        ..shader =
            LinearGradient(colors: [k.light(col, 0.35), col, k.dark(col, 0.25)])
                .createShader(body.getBounds()));
  final head = at - Offset(0, u * 0.7);
  k.c.drawCircle(
      head,
      u * 0.2,
      Paint()
        ..shader = RadialGradient(
                center: const Alignment(-0.4, -0.4),
                colors: [k.light(col, 0.5), col])
            .createShader(Rect.fromCircle(center: head, radius: u * 0.2)));
}

/// A grid of lines over [rect].
void _grid(_Kit k, Rect rect, int cols, int rows, Color col, double width) {
  for (var i = 0; i <= cols; i++) {
    final x = rect.left + rect.width * i / cols;
    k.c.drawLine(
        Offset(x, rect.top),
        Offset(x, rect.bottom),
        Paint()
          ..color = col
          ..strokeWidth = width * k.u);
  }
  for (var j = 0; j <= rows; j++) {
    final y = rect.top + rect.height * j / rows;
    k.c.drawLine(
        Offset(rect.left, y),
        Offset(rect.right, y),
        Paint()
          ..color = col
          ..strokeWidth = width * k.u);
  }
}

/// A role card for the party games: coloured face, a big icon, and a label bar.
void _roleCard(_Kit k, Offset at, double turn, Color fill, GameIcons icon) {
  k.card(at, 0.42, 0.6, turn, fill, (inner) {
    paintIcon(
        k.c,
        icon,
        Rect.fromCenter(
            center: inner.center - Offset(0, inner.height * 0.08),
            width: inner.width * 0.7,
            height: inner.width * 0.7),
        color: Colors.white);
    k.c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(
                inner.left + inner.width * 0.18,
                inner.bottom - inner.height * 0.2,
                inner.width * 0.64,
                inner.height * 0.08),
            Radius.circular(inner.height)),
        Paint()..color = Colors.white.withValues(alpha: 0.75));
  });
}

final Map<String, void Function(_Kit k)> _scenes = {
  // ---------- Board games ----------
  'chess': (k) {
    k.checker(k.rc(0.65, 0.5, 0.88, 0.88), 4, 4, const Color(0xFFF3DDB3),
        const Color(0xFFA8703F));
    _pawn(k, k.p(0.43, 0.6), 0.4, const Color(0xFFFDF7EC));
    _pawn(k, k.p(0.87, 0.82), 0.4, const Color(0xFF3A2E3F));
    // A king: a pawn with a crown.
    _pawn(k, k.p(0.65, 0.42), 0.5, const Color(0xFF3A2E3F));
    k.icon(GameIcons.crown, k.p(0.65, 0.03), 0.2, col: _yellow);
  },
  'checkers': (k) {
    k.checker(k.rc(0.65, 0.5, 0.88, 0.88), 4, 4, const Color(0xFFF2E2C4),
        const Color(0xFF3B2E3A));
    final cell = 0.22;
    for (final (x, y, red) in [
      (1, 0, true),
      (3, 0, true),
      (0, 1, true),
      (2, 3, false),
      (0, 3, false),
      (3, 2, false)
    ]) {
      k.disc(k.p(0.21 + cell * (x + 0.5), 0.06 + cell * (y + 0.5)), 0.085,
          red ? _red : const Color(0xFFF7F2E8));
    }
    k.icon(GameIcons.crownKing,
        k.p(0.21 + cell * 3.5, 0.06 + cell * 2.5) - Offset(0, 0.015 * k.u), 0.1,
        col: _yellow);
  },
  'connect_four': (k) {
    final frame = k.rc(0.65, 0.58, 0.95, 0.74);
    k.block(frame, const Color(0xFF2F6BFF), radius: 0.07);
    const cols = 5, rows = 4;
    final cw = frame.width / cols, ch = frame.height / rows;
    final placed = {
      (0, 3): _red,
      (1, 3): _yellow,
      (2, 3): _red,
      (1, 2): _red,
      (2, 2): _yellow,
      (3, 3): _yellow,
      (2, 1): _red,
      (3, 2): _yellow
    };
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        final at =
            Offset(frame.left + cw * (x + 0.5), frame.top + ch * (y + 0.5));
        final col = placed[(x, y)];
        if (col == null) {
          k.c.drawCircle(
              at, ch * 0.36, Paint()..color = const Color(0xFF173A99));
        } else {
          k.disc(at, ch * 0.36 / k.u, col);
        }
      }
    }
    k.disc(k.p(0.65 + cw / k.u * 1, 0.1), ch * 0.36 / k.u, _red); // dropping in
  },
  'tic_tac_toe': (k) {
    k.panel(k.rc(0.65, 0.5, 0.92, 0.92), radius: 0.07);
    final g = k.rc(0.65, 0.5, 0.75, 0.75);
    final s = g.width / 3;
    for (var i = 1; i < 3; i++) {
      k.line(Offset(g.left + s * i, g.top), Offset(g.left + s * i, g.bottom),
          const Color(0xFF8C7A9E), 0.025);
      k.line(Offset(g.left, g.top + s * i), Offset(g.right, g.top + s * i),
          const Color(0xFF8C7A9E), 0.025);
    }
    Offset cell(int x, int y) =>
        Offset(g.left + s * (x + 0.5), g.top + s * (y + 0.5));
    void x(int cx, int cy) {
      final at = cell(cx, cy), d = s * 0.28;
      k.line(at - Offset(d, d), at + Offset(d, d), _red, 0.05);
      k.line(at + Offset(-d, d), at + Offset(d, -d), _red, 0.05);
    }

    void o(int cx, int cy) => k.c.drawCircle(
        cell(cx, cy),
        s * 0.3,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.05 * k.u
          ..color = _blue);
    x(0, 0);
    x(1, 1);
    o(2, 0);
    o(0, 2);
    x(2, 2);
    k.line(
        cell(0, 0) - Offset(s * 0.35, s * 0.35),
        cell(2, 2) + Offset(s * 0.35, s * 0.35),
        _yellow.withValues(alpha: 0.9),
        0.04);
  },
  'dots_boxes': (k) {
    k.panel(k.rc(0.65, 0.5, 0.95, 0.92), radius: 0.07);
    final g = k.rc(0.65, 0.5, 0.72, 0.72);
    final s = g.width / 3;
    Offset d(int x, int y) => Offset(g.left + s * x, g.top + s * y);
    k.c.drawRect(Rect.fromPoints(d(0, 0), d(1, 1)),
        Paint()..color = _red.withValues(alpha: 0.35));
    k.c.drawRect(Rect.fromPoints(d(1, 1), d(2, 2)),
        Paint()..color = _blue.withValues(alpha: 0.35));
    k.c.drawRect(Rect.fromPoints(d(2, 0), d(3, 1)),
        Paint()..color = _blue.withValues(alpha: 0.35));
    for (final (a, z, col) in [
      ((0, 0), (1, 0), _red),
      ((0, 0), (0, 1), _red),
      ((1, 0), (1, 1), _blue),
      ((0, 1), (1, 1), _red),
      ((1, 1), (2, 1), _blue),
      ((1, 1), (1, 2), _blue), //
      ((2, 1), (2, 2), _red),
      ((1, 2), (2, 2), _blue),
      ((2, 0), (3, 0), _blue),
      ((3, 0), (3, 1), _red),
      ((2, 0), (2, 1), _blue),
      ((2, 1), (3, 1), _blue),
      ((0, 2), (0, 3), _red),
    ]) {
      k.line(d(a.$1, a.$2), d(z.$1, z.$2), col, 0.03);
    }
    for (var y = 0; y <= 3; y++) {
      for (var x = 0; x <= 3; x++) {
        k.c.drawCircle(d(x, y), 0.026 * k.u, Paint()..color = _ink);
      }
    }
  },
  'ludo': (k) {
    final board = k.rc(0.62, 0.5, 0.9, 0.9);
    k.panel(board, fill: Colors.white, radius: 0.05);
    final q = board.width / 2;
    final cols = [_red, _green, _blue, _yellow];
    for (var i = 0; i < 4; i++) {
      final home = Rect.fromLTWH(board.left + (i % 2) * q * 1.2,
          board.top + (i ~/ 2) * q * 1.2, q * 0.8, q * 0.8);
      k.c.drawRRect(RRect.fromRectAndRadius(home, Radius.circular(0.04 * k.u)),
          Paint()..color = cols[i]);
      k.c.drawRRect(
          RRect.fromRectAndRadius(
              home.deflate(q * 0.14), Radius.circular(0.03 * k.u)),
          Paint()..color = Colors.white);
      for (final o in [const Offset(-1, -1), const Offset(1, 1)]) {
        k.disc(home.center + o * q * 0.13, 0.04, cols[i]);
      }
    }
    // The centre triangles.
    final cc = board.center, h = q * 0.2;
    for (var i = 0; i < 4; i++) {
      final a = i * pi / 2;
      final path = Path()
        ..moveTo(cc.dx, cc.dy)
        ..lineTo(cc.dx + cos(a - pi / 4) * h * 1.41,
            cc.dy + sin(a - pi / 4) * h * 1.41)
        ..lineTo(cc.dx + cos(a + pi / 4) * h * 1.41,
            cc.dy + sin(a + pi / 4) * h * 1.41)
        ..close();
      k.fill(path, [_green, _yellow, _blue, _red][i]);
    }
    // A die rolling out.
    k.block(k.rc(1.14, 0.72, 0.24, 0.24), Colors.white, radius: 0.05);
    k.icon(GameIcons.dice5, k.p(1.14, 0.72), 0.22);
  },
  'snakes_ladders': (k) {
    final board = k.rc(0.65, 0.5, 0.9, 0.9);
    k.checker(board, 5, 5, const Color(0xFFFFE7A8), const Color(0xFF8EE0A8),
        radius: 0.05);
    // Ladder.
    final a = k.p(0.32, 0.86), z = k.p(0.62, 0.16);
    final side = Offset(0.05 * k.u, 0.02 * k.u);
    k.line(a - side, z - side, const Color(0xFF9A5B2A), 0.035);
    k.line(a + side, z + side, const Color(0xFF9A5B2A), 0.035);
    for (var i = 1; i < 5; i++) {
      final t = Offset.lerp(a, z, i / 5)!;
      k.line(t - side, t + side, const Color(0xFFC4824A), 0.025);
    }
    // Snake.
    final snake = Path()
      ..moveTo(k.p(0.95, 0.12).dx, k.p(0.95, 0.12).dy)
      ..cubicTo(k.p(0.7, 0.3).dx, k.p(0.7, 0.3).dy, k.p(1.1, 0.5).dx,
          k.p(1.1, 0.5).dy, k.p(0.85, 0.85).dx, k.p(0.85, 0.85).dy);
    k.stroke(snake, const Color(0xFF1E8C3A), 0.085);
    k.stroke(snake, const Color(0xFF39C35C), 0.055);
    k.c.drawCircle(
        k.p(0.95, 0.12), 0.06 * k.u, Paint()..color = const Color(0xFF1E8C3A));
    k.c.drawCircle(k.p(0.97, 0.1), 0.014 * k.u, Paint()..color = Colors.white);
  },
  'bingo': (k) {
    final card = k.rc(0.65, 0.53, 0.88, 0.86);
    k.panel(card, radius: 0.06);
    k.c.drawRRect(
        RRect.fromRectAndCorners(
            Rect.fromLTWH(card.left, card.top, card.width, card.height * 0.2),
            topLeft: Radius.circular(0.06 * k.u),
            topRight: Radius.circular(0.06 * k.u)),
        Paint()..color = k.color);
    k.text('BINGO', Offset(card.center.dx, card.top + card.height * 0.1), 0.13,
        Colors.white);
    final g = Rect.fromLTRB(
        card.left + 0.04 * k.u,
        card.top + card.height * 0.24,
        card.right - 0.04 * k.u,
        card.bottom - 0.04 * k.u);
    final cw = g.width / 4, ch = g.height / 3;
    final nums = [7, 23, 41, 58, 12, 30, 44, 66, 3, 19, 52, 71];
    const dabbed = {0, 5, 10, 3, 6};
    for (var i = 0; i < 12; i++) {
      final at =
          Offset(g.left + cw * (i % 4 + 0.5), g.top + ch * (i ~/ 4 + 0.5));
      if (dabbed.contains(i))
        k.c.drawCircle(
            at, ch * 0.42, Paint()..color = _red.withValues(alpha: 0.75));
      k.text('${nums[i]}', at, 0.1, dabbed.contains(i) ? Colors.white : _ink);
    }
  },
  'battleship': (k) {
    final g = k.rc(0.65, 0.5, 0.95, 0.9);
    _grid(k, g, 5, 4, Colors.white.withValues(alpha: 0.35), 0.008);
    final cw = g.width / 5, ch = g.height / 4;
    Rect cells(int x, int y, int w) => Rect.fromLTWH(
        g.left + cw * x + 3, g.top + ch * y + 3, cw * w - 6, ch - 6);
    k.block(cells(1, 1, 3), const Color(0xFF7D8BA0), radius: 0.08);
    k.block(cells(3, 3, 2), const Color(0xFF7D8BA0), radius: 0.08);
    for (final (x, y) in [(2, 1), (3, 1)]) {
      final at = Offset(g.left + cw * (x + 0.5), g.top + ch * (y + 0.5));
      k.c.drawCircle(at, ch * 0.3, Paint()..color = _orange);
      k.c.drawCircle(at, ch * 0.16, Paint()..color = _yellow);
    }
    for (final (x, y) in [(0, 0), (4, 1), (1, 3), (0, 2)]) {
      k.c.drawCircle(Offset(g.left + cw * (x + 0.5), g.top + ch * (y + 0.5)),
          ch * 0.14, Paint()..color = Colors.white.withValues(alpha: 0.85));
    }
  },
  'memory': (k) {
    const w = 0.26, h = 0.36;
    final faces = {
      1: GameIcons.cherry,
      4: GameIcons.cherry,
      2: GameIcons.grapes
    };
    for (var i = 0; i < 6; i++) {
      final at = k.p(0.3 + (i % 3) * 0.35, 0.28 + (i ~/ 3) * 0.44);
      final face = faces[i];
      k.card(at, w, h, (i.isEven ? -1 : 1) * 0.05,
          face == null ? k.color : const Color(0xFFFFF4DE), (inner) {
        if (face != null) {
          paintIcon(k.c, face, inner.deflate(inner.width * 0.12));
        } else {
          k.c.drawCircle(
              inner.center,
              inner.width * 0.26,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = inner.width * 0.08
                ..color = Colors.white.withValues(alpha: 0.5));
        }
      });
    }
  },
  'guess_who': (k) => _faces(k, GameIcons.magnifier),
  'guess_person': (k) => _faces(k, GameIcons.help),
  'raja_mantri': (k) {
    final icons = [
      GameIcons.crown,
      GameIcons.scroll,
      GameIcons.mask,
      GameIcons.shield
    ];
    final cols = [_yellow, _blue, _ink, _red];
    for (var i = 0; i < 4; i++) {
      _roleCard(k, k.p(0.26 + i * 0.26, 0.5 + (i == 0 ? -0.04 : 0)),
          (i - 1.5) * 0.14, cols[i], icons[i]);
    }
  },
  'colour_clash': (k) {
    final cols = [_blue, _green, _red];
    for (var i = 0; i < 3; i++) {
      k.card(k.p(0.4 + i * 0.25, 0.52 + (i == 1 ? -0.04 : 0)), 0.4, 0.6,
          (i - 1) * 0.26, cols[i], (inner) {
        k.c.save();
        k.c.translate(inner.center.dx, inner.center.dy);
        k.c.rotate(-0.5);
        k.c.drawOval(
            Rect.fromCenter(
                center: Offset.zero,
                width: inner.width * 0.85,
                height: inner.height * 0.62),
            Paint()..color = Colors.white);
        k.c.restore();
        k.text(['7', '+2', '3'][i], inner.center, 0.17, cols[i]);
      });
    }
  },

  // ---------- Action games ----------
  'air_hockey': (k) {
    final table = k.rc(0.65, 0.5, 1.2, 0.86);
    k.block(table, const Color(0xFFEAF6FF), radius: 0.1);
    k.line(
        Offset(table.center.dx, table.top),
        Offset(table.center.dx, table.bottom),
        _red.withValues(alpha: 0.5),
        0.015);
    k.c.drawCircle(
        table.center,
        0.18 * k.u,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.012 * k.u
          ..color = _blue.withValues(alpha: 0.45));
    k.line(k.p(0.48, 0.42), k.p(0.3, 0.42), _ink.withValues(alpha: 0.25), 0.02);
    k.line(k.p(0.5, 0.5), k.p(0.28, 0.52), _ink.withValues(alpha: 0.25), 0.02);
    k.disc(k.p(0.6, 0.47), 0.07, _ink);
    k.ball(k.p(0.25, 0.5), 0.13, _red);
    k.c.drawCircle(
        k.p(0.25, 0.5), 0.05 * k.u, Paint()..color = k.dark(_red, 0.25));
    k.ball(k.p(1.08, 0.38), 0.13, _blue);
    k.c.drawCircle(
        k.p(1.08, 0.38), 0.05 * k.u, Paint()..color = k.dark(_blue, 0.25));
  },
  'ping_pong': (k) {
    final table = Path()
      ..moveTo(k.p(0.25, 0.3).dx, k.p(0.25, 0.3).dy)
      ..lineTo(k.p(1.05, 0.3).dx, k.p(1.05, 0.3).dy)
      ..lineTo(k.p(1.25, 0.85).dx, k.p(1.25, 0.85).dy)
      ..lineTo(k.p(0.05, 0.85).dx, k.p(0.05, 0.85).dy)
      ..close();
    k.c.drawPath(
        table.shift(Offset(0, 0.04 * k.u)), Paint()..color = Colors.black26);
    k.fill(table, const Color(0xFF1F7A5A));
    k.stroke(table, Colors.white, 0.015);
    k.line(k.p(0.65, 0.3), k.p(0.65, 0.85), Colors.white, 0.01);
    k.block(k.r(0.12, 0.52, 1.06, 0.08), const Color(0xFFEDEDF5), radius: 0.01);
    // Paddles.
    void paddle(Offset at, Color col, double turn) {
      k.c.save();
      k.c.translate(at.dx, at.dy);
      k.c.rotate(turn);
      k.c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(-0.025 * k.u, 0.08 * k.u, 0.05 * k.u, 0.14 * k.u),
              Radius.circular(0.02 * k.u)),
          Paint()..color = _woodDark);
      k.c.drawCircle(Offset.zero, 0.12 * k.u, Paint()..color = col);
      k.c.drawCircle(
          Offset.zero,
          0.12 * k.u,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.015 * k.u
            ..color = k.dark(col));
      k.c.restore();
    }

    paddle(k.p(0.12, 0.3), _red, -0.5);
    paddle(k.p(1.18, 0.62), _ink, 0.6);
    k.ball(k.p(0.82, 0.18), 0.045, Colors.white);
  },
  'snake_duel': (k) => _snakes(k, two: true),
  'classic_snake': (k) => _snakes(k, two: false),
  'penalty': (k) {
    final goal = k.r(0.15, 0.08, 1.0, 0.56);
    _grid(k, goal, 10, 6, Colors.white.withValues(alpha: 0.45), 0.005);
    final post = Paint()
      ..color = Colors.white
      ..strokeWidth = 0.035 * k.u
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    k.c.drawPath(
        Path()
          ..moveTo(goal.left, goal.bottom)
          ..lineTo(goal.left, goal.top)
          ..lineTo(goal.right, goal.top)
          ..lineTo(goal.right, goal.bottom),
        post);
    k.icon(GameIcons.glove, k.p(0.45, 0.32), 0.2);
    k.icon(GameIcons.glove, k.p(0.7, 0.32), 0.2);
    k.ball(k.p(1.0, 0.24), 0.08, Colors.white);
    k.icon(GameIcons.football, k.p(1.0, 0.24), 0.17);
    k.c.drawOval(k.rc(0.65, 0.88, 0.2, 0.05),
        Paint()..color = Colors.white.withValues(alpha: 0.85));
  },
  'basketball_hoops': (k) {
    final board = k.rc(0.65, 0.3, 0.62, 0.42);
    k.block(board, Colors.white, radius: 0.04);
    k.c.drawRect(
        k.rc(0.65, 0.36, 0.24, 0.18),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.018 * k.u
          ..color = _red);
    // Net.
    final rim = k.rc(0.65, 0.48, 0.3, 0.06);
    for (var i = 0; i <= 4; i++) {
      final x = rim.left + rim.width * i / 4;
      k.line(
          Offset(x, rim.center.dy),
          Offset(rim.center.dx + (x - rim.center.dx) * 0.55,
              rim.center.dy + 0.2 * k.u),
          Colors.white,
          0.01);
    }
    k.c.drawOval(
        rim,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.025 * k.u
          ..color = _orange);
    // The shot's arc.
    final arc = Path()
      ..moveTo(k.p(0.1, 0.95).dx, k.p(0.1, 0.95).dy)
      ..quadraticBezierTo(k.p(0.25, 0.1).dx, k.p(0.25, 0.1).dy,
          k.p(0.48, 0.32).dx, k.p(0.48, 0.32).dy);
    for (final m in arc.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 0.06 * k.u) {
        k.c.drawCircle(m.getTangentForOffset(d)!.position, 0.012 * k.u,
            Paint()..color = Colors.white.withValues(alpha: 0.7));
      }
    }
    k.ball(k.p(0.48, 0.32), 0.1, _orange);
    k.icon(GameIcons.ball, k.p(0.48, 0.32), 0.2);
  },
  'crush_it': (k) {
    for (final (x, col) in [(0.35, _red), (0.65, _teal), (0.95, _yellow)]) {
      k.block(k.rc(x, 0.72, 0.24, 0.3), col, radius: 0.05);
    }
    // A cracked block under the hammer.
    k.stroke(
        Path()
          ..moveTo(k.p(0.6, 0.58).dx, k.p(0.6, 0.58).dy)
          ..lineTo(k.p(0.66, 0.7).dx, k.p(0.66, 0.7).dy)
          ..lineTo(k.p(0.62, 0.78).dx, k.p(0.62, 0.78).dy)
          ..lineTo(k.p(0.7, 0.86).dx, k.p(0.7, 0.86).dy),
        Colors.white,
        0.018);
    k.icon(GameIcons.hammer, k.p(0.78, 0.3), 0.46);
    for (var i = 0; i < 5; i++) {
      final a = -pi / 2 + (i - 2) * 0.45;
      k.line(k.p(0.65, 0.5) + Offset(cos(a), sin(a)) * 0.12 * k.u,
          k.p(0.65, 0.5) + Offset(cos(a), sin(a)) * 0.2 * k.u, _yellow, 0.02);
    }
  },
  'fruit_duel': (k) {
    k.icon(GameIcons.watermelon, k.p(0.45, 0.55), 0.55);
    k.icon(GameIcons.orange, k.p(0.95, 0.35), 0.32);
    k.icon(GameIcons.apple, k.p(1.0, 0.75), 0.28);
    // The swipe.
    final swipe = Path()
      ..moveTo(k.p(0.05, 0.9).dx, k.p(0.05, 0.9).dy)
      ..quadraticBezierTo(k.p(0.5, 0.45).dx, k.p(0.5, 0.45).dy,
          k.p(1.2, 0.15).dx, k.p(1.2, 0.15).dy);
    k.stroke(swipe, Colors.white.withValues(alpha: 0.4), 0.06);
    k.stroke(swipe, Colors.white, 0.02);
  },
  'paint_fight': (k) {
    final rnd = Random(4);
    void splat(Offset at, double r, Color col) {
      k.c.drawCircle(at, r * k.u, Paint()..color = col);
      for (var i = 0; i < 7; i++) {
        final a = rnd.nextDouble() * pi * 2,
            d = r * (0.9 + rnd.nextDouble() * 0.5);
        k.c.drawCircle(at + Offset(cos(a), sin(a)) * d * k.u,
            r * (0.18 + rnd.nextDouble() * 0.2) * k.u, Paint()..color = col);
      }
    }

    splat(k.p(0.35, 0.4), 0.2, _red);
    splat(k.p(0.92, 0.62), 0.22, _blue);
    splat(k.p(0.7, 0.25), 0.1, _yellow);
    splat(k.p(0.4, 0.8), 0.09, _blue);
    k.icon(GameIcons.paintBrush, k.p(1.05, 0.25), 0.3);
  },
  'reaction_tap': (k) {
    final c = k.p(0.65, 0.5);
    for (var i = 3; i > 0; i--) {
      k.c.drawCircle(c, (0.22 + i * 0.08) * k.u,
          Paint()..color = _green.withValues(alpha: 0.12 * (4 - i)));
    }
    k.ball(c, 0.26, _green);
    k.icon(GameIcons.bolt, c, 0.3);
    k.text('TAP!', k.p(0.65, 0.9), 0.12, Colors.white);
  },
  'math_duel': (k) {
    final board = k.rc(0.65, 0.4, 1.05, 0.5);
    k.block(board, const Color(0xFF2E4A3E), radius: 0.05);
    k.text('7 + 5 = ?', board.center, 0.2, Colors.white);
    for (var i = 0; i < 3; i++) {
      final col = i == 1 ? _green : const Color(0xFFFFF4DE);
      final r = k.rc(0.3 + i * 0.35, 0.84, 0.28, 0.2);
      k.block(r, col, radius: 0.05);
      k.text(
          ['11', '12', '13'][i], r.center, 0.12, i == 1 ? Colors.white : _ink);
    }
  },
  'hand_cricket': (k) {
    // Stumps and bails.
    for (var i = 0; i < 3; i++) {
      k.block(k.r(0.86 + i * 0.09, 0.3, 0.045, 0.56), const Color(0xFFF5DEB0),
          radius: 0.02);
    }
    k.block(k.r(0.84, 0.27, 0.27, 0.035), _woodDark, radius: 0.015);
    k.icon(GameIcons.bat, k.p(0.45, 0.48), 0.6);
    k.ball(k.p(0.7, 0.32), 0.07, const Color(0xFFD32F2F));
  },
  'quiz_battle': (k) {
    k.block(k.rc(0.65, 0.24, 1.05, 0.34), Colors.white, radius: 0.05);
    k.text('?', k.p(0.65, 0.24), 0.26, k.color);
    final cols = [_red, _blue, _yellow, _green];
    for (var i = 0; i < 4; i++) {
      final r = k.rc(0.37 + (i % 2) * 0.56, 0.6 + (i ~/ 2) * 0.26, 0.5, 0.2);
      k.block(r, cols[i], radius: 0.05);
      k.text(['A', 'B', 'C', 'D'][i], r.center, 0.12, Colors.white);
    }
  },
  'fruit_merge': (k) => _fruitJar(k),
  'fruit_merge_battle': (k) => _fruitJar(k),
  'mini_golf': (k) {
    final green = Path()..addOval(k.rc(0.65, 0.58, 1.2, 0.66));
    k.c.drawPath(
        green.shift(Offset(0, 0.03 * k.u)), Paint()..color = Colors.black26);
    k.fill(green, const Color(0xFF6BD36B));
    k.c.drawOval(k.rc(0.98, 0.6, 0.12, 0.05), Paint()..color = _ink);
    k.line(k.p(0.98, 0.6), k.p(0.98, 0.12), Colors.white, 0.018);
    k.fill(
        Path()
          ..moveTo(k.p(0.98, 0.12).dx, k.p(0.98, 0.12).dy)
          ..lineTo(k.p(1.2, 0.2).dx, k.p(1.2, 0.2).dy)
          ..lineTo(k.p(0.98, 0.28).dx, k.p(0.98, 0.28).dy)
          ..close(),
        _red);
    final path = Path()
      ..moveTo(k.p(0.25, 0.7).dx, k.p(0.25, 0.7).dy)
      ..quadraticBezierTo(k.p(0.6, 0.85).dx, k.p(0.6, 0.85).dy,
          k.p(0.93, 0.62).dx, k.p(0.93, 0.62).dy);
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 0.05 * k.u) {
        k.c.drawCircle(m.getTangentForOffset(d)!.position, 0.01 * k.u,
            Paint()..color = Colors.white.withValues(alpha: 0.8));
      }
    }
    k.ball(k.p(0.25, 0.68), 0.05, Colors.white);
  },
  'slingshot': (k) {
    // Slingshot.
    k.line(k.p(0.25, 0.92), k.p(0.25, 0.6), _woodDark, 0.05);
    k.line(k.p(0.25, 0.62), k.p(0.16, 0.4), _woodDark, 0.045);
    k.line(k.p(0.25, 0.62), k.p(0.34, 0.4), _woodDark, 0.045);
    k.line(k.p(0.16, 0.42), k.p(0.08, 0.5), const Color(0xFF5A2E1A), 0.015);
    k.line(k.p(0.34, 0.42), k.p(0.08, 0.5), const Color(0xFF5A2E1A), 0.015);
    k.ball(k.p(0.08, 0.5), 0.05, _red);
    // A crate tower with a pig.
    for (final (x, y) in [(0.85, 0.82), (1.07, 0.82), (0.96, 0.6)]) {
      k.block(k.rc(x, y, 0.2, 0.2), _woodLight, radius: 0.02);
    }
    k.icon(GameIcons.pig, k.p(0.96, 0.36), 0.26);
  },
  'archery': (k) {
    k.line(k.p(0.78, 0.5), k.p(0.66, 0.95), _woodDark, 0.035);
    k.line(k.p(0.78, 0.5), k.p(0.9, 0.95), _woodDark, 0.035);
    final c = k.p(0.78, 0.42);
    for (final (r, col) in [
      (0.36, Colors.white),
      (0.29, _ink),
      (0.22, _blue),
      (0.15, _red),
      (0.07, _yellow)
    ]) {
      k.c.drawCircle(c, r * k.u, Paint()..color = col);
    }
    // An arrow in the gold.
    k.line(c + Offset(0.02 * k.u, 0), c - Offset(0.55 * k.u, 0.12 * k.u),
        _woodDark, 0.02);
    final tail = c - Offset(0.55 * k.u, 0.12 * k.u);
    k.fill(
        Path()
          ..moveTo(tail.dx, tail.dy)
          ..lineTo(tail.dx + 0.1 * k.u, tail.dy - 0.03 * k.u)
          ..lineTo(tail.dx + 0.08 * k.u, tail.dy + 0.04 * k.u)
          ..close(),
        _red);
  },
  'shooting_gallery': (k) {
    for (var i = 0; i < 3; i++) {
      k.icon(GameIcons.duck, k.p(0.3 + i * 0.36, 0.5), 0.3);
    }
    // Waves.
    final wave = Path()..moveTo(k.b.left, k.p(0, 0.72).dy);
    for (var x = 0.0; x <= 1.3; x += 0.1) {
      wave.quadraticBezierTo(k.p(x + 0.05, 0.64).dx, k.p(x + 0.05, 0.64).dy,
          k.p(x + 0.1, 0.72).dx, k.p(x + 0.1, 0.72).dy);
    }
    wave
      ..lineTo(k.b.right, k.b.bottom)
      ..lineTo(k.b.left, k.b.bottom)
      ..close();
    k.fill(wave, const Color(0xFF2E86DE));
    // Crosshair on the middle duck.
    final c = k.p(0.66, 0.48);
    final cross = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.02 * k.u
      ..color = _red;
    k.c.drawCircle(c, 0.16 * k.u, cross);
    k.line(c - Offset(0.22 * k.u, 0), c - Offset(0.08 * k.u, 0), _red, 0.02);
    k.line(c + Offset(0.08 * k.u, 0), c + Offset(0.22 * k.u, 0), _red, 0.02);
    k.line(c - Offset(0, 0.22 * k.u), c - Offset(0, 0.08 * k.u), _red, 0.02);
  },
  'bottle_smash': (k) {
    k.block(k.r(0.1, 0.72, 1.1, 0.07), _woodDark, radius: 0.015);
    for (var i = 0; i < 4; i++) {
      if (i == 2) continue;
      k.icon(GameIcons.bottle, k.p(0.25 + i * 0.27, 0.5), 0.42);
    }
    // The broken one: flying shards.
    final rnd = Random(2);
    for (var i = 0; i < 7; i++) {
      final at = k.p(0.79 + (rnd.nextDouble() - 0.5) * 0.35,
          0.35 + rnd.nextDouble() * 0.35);
      k.fill(
          Path()
            ..moveTo(at.dx, at.dy)
            ..lineTo(at.dx + 0.04 * k.u, at.dy + 0.015 * k.u)
            ..lineTo(at.dx + 0.01 * k.u, at.dy + 0.05 * k.u)
            ..close(),
          const Color(0xFF7BD389));
    }
    k.ball(k.p(0.79, 0.45), 0.07, _red);
  },
  'tug_of_war': (k) {
    k.line(k.p(0.05, 0.55), k.p(1.25, 0.55), const Color(0xFFC9A26A), 0.05);
    for (var x = 0.08; x < 1.25; x += 0.06) {
      k.line(k.p(x, 0.53), k.p(x + 0.03, 0.57), const Color(0xFF9C7840), 0.012);
    }
    k.line(k.p(0.75, 0.55), k.p(0.75, 0.3), Colors.white, 0.015);
    k.fill(
        Path()
          ..moveTo(k.p(0.75, 0.3).dx, k.p(0.75, 0.3).dy)
          ..lineTo(k.p(0.92, 0.37).dx, k.p(0.92, 0.37).dy)
          ..lineTo(k.p(0.75, 0.44).dx, k.p(0.75, 0.44).dy)
          ..close(),
        _red);
    k.line(k.p(0.65, 0.2), k.p(0.65, 0.95), Colors.white.withValues(alpha: 0.7),
        0.012);
    k.ball(k.p(0.12, 0.55), 0.1, _blue);
    k.ball(k.p(1.18, 0.55), 0.1, _red);
  },
  'darts': (k) {
    final c = k.p(0.62, 0.5);
    k.c.drawCircle(
        c + Offset(0, 0.03 * k.u), 0.45 * k.u, Paint()..color = Colors.black38);
    k.c.drawCircle(c, 0.45 * k.u, Paint()..color = _ink);
    for (var i = 0; i < 20; i++) {
      final a0 = i * pi / 10 - pi / 20;
      final col = i.isEven ? const Color(0xFFF5E6C8) : const Color(0xFF1E1A26);
      final ring = i.isEven ? _red : _green;
      for (final (r1, r2, cc) in [
        (0.38, 0.35, ring),
        (0.35, 0.22, col),
        (0.22, 0.19, ring),
        (0.19, 0.06, col)
      ]) {
        final path = Path()
          ..addArc(Rect.fromCircle(center: c, radius: r1 * k.u), a0, pi / 10)
          ..arcTo(Rect.fromCircle(center: c, radius: r2 * k.u), a0 + pi / 10,
              -pi / 10, false)
          ..close();
        k.fill(path, cc);
      }
    }
    k.c.drawCircle(c, 0.06 * k.u, Paint()..color = _green);
    k.c.drawCircle(c, 0.03 * k.u, Paint()..color = _red);
    // A dart.
    final tip = c + Offset(0.08 * k.u, -0.06 * k.u);
    k.line(tip, tip + Offset(0.32 * k.u, -0.2 * k.u), const Color(0xFFB0B8C8),
        0.025);
    k.fill(
        Path()
          ..moveTo((tip + Offset(0.3 * k.u, -0.19 * k.u)).dx,
              (tip + Offset(0.3 * k.u, -0.19 * k.u)).dy)
          ..lineTo((tip + Offset(0.42 * k.u, -0.32 * k.u)).dx,
              (tip + Offset(0.42 * k.u, -0.32 * k.u)).dy)
          ..lineTo((tip + Offset(0.44 * k.u, -0.18 * k.u)).dx,
              (tip + Offset(0.44 * k.u, -0.18 * k.u)).dy)
          ..close(),
        _yellow);
  },
  'hot_potato': (k) {
    final c = k.p(0.62, 0.56);
    final potato = Path()
      ..addOval(
          Rect.fromCenter(center: c, width: 0.62 * k.u, height: 0.46 * k.u));
    k.c.drawPath(
        potato.shift(Offset(0, 0.04 * k.u)), Paint()..color = Colors.black26);
    k.c.drawPath(
        potato,
        Paint()
          ..shader = RadialGradient(
                  center: const Alignment(-0.3, -0.4),
                  colors: [const Color(0xFFE9B872), const Color(0xFFB0773A)])
              .createShader(potato.getBounds()));
    for (final o in [
      const Offset(-0.12, -0.05),
      const Offset(0.1, 0.06),
      const Offset(0.02, -0.1)
    ]) {
      k.c.drawCircle(
          c + o * k.u, 0.018 * k.u, Paint()..color = const Color(0xFF8A5A2A));
    }
    // Heat lines and a fuse spark.
    for (var i = 0; i < 3; i++) {
      final x = 0.45 + i * 0.17;
      k.stroke(
          Path()
            ..moveTo(k.p(x, 0.28).dx, k.p(x, 0.28).dy)
            ..quadraticBezierTo(k.p(x - 0.05, 0.18).dx, k.p(x - 0.05, 0.18).dy,
                k.p(x, 0.08).dx, k.p(x, 0.08).dy),
          _orange,
          0.025);
    }
    k.icon(GameIcons.clock, k.p(1.1, 0.25), 0.24);
  },
  'knife_hit': (k) {
    final c = k.p(0.65, 0.42);
    for (var i = 0; i < 5; i++) {
      final a = pi / 2 + (i - 2) * 0.6 + (i == 2 ? 0 : 0.2);
      k.c.save();
      k.c.translate(c.dx, c.dy);
      k.c.rotate(a - pi / 2);
      k.c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(-0.025 * k.u, 0.3 * k.u, 0.05 * k.u, 0.18 * k.u),
              Radius.circular(0.02 * k.u)),
          Paint()..color = const Color(0xFFD9DDE6));
      k.c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(-0.03 * k.u, 0.46 * k.u, 0.06 * k.u, 0.12 * k.u),
              Radius.circular(0.02 * k.u)),
          Paint()..color = _ink);
      k.c.restore();
    }
    k.c.drawCircle(
        c + Offset(0, 0.04 * k.u), 0.32 * k.u, Paint()..color = Colors.black26);
    k.c.drawCircle(c, 0.32 * k.u, Paint()..color = const Color(0xFFC88A4E));
    for (final r in [0.24, 0.16, 0.08]) {
      k.c.drawCircle(
          c,
          r * k.u,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.012 * k.u
            ..color = const Color(0xFF8E5A2C));
    }
  },
  'cup_pong': (k) {
    void cup(Offset at) {
      final w = 0.17 * k.u, h = 0.2 * k.u;
      final body = Path()
        ..moveTo(at.dx - w / 2, at.dy - h / 2)
        ..lineTo(at.dx + w / 2, at.dy - h / 2)
        ..lineTo(at.dx + w * 0.36, at.dy + h / 2)
        ..lineTo(at.dx - w * 0.36, at.dy + h / 2)
        ..close();
      k.c.drawPath(
          body,
          Paint()
            ..shader = LinearGradient(
                    colors: [k.light(_red, 0.2), _red, k.dark(_red, 0.25)])
                .createShader(body.getBounds()));
      k.c.drawOval(
          Rect.fromCenter(
              center: at - Offset(0, h / 2), width: w, height: w * 0.32),
          Paint()..color = Colors.white);
      k.c.drawOval(
          Rect.fromCenter(
              center: at - Offset(0, h / 2), width: w * 0.82, height: w * 0.22),
          Paint()..color = k.dark(_red, 0.4));
    }

    for (final (x, y) in [
      (0.46, 0.5),
      (0.65, 0.5),
      (0.84, 0.5),
      (0.555, 0.68),
      (0.745, 0.68),
      (0.65, 0.86)
    ]) {
      cup(k.p(x, y));
    }
    final arc = Path()
      ..moveTo(k.p(0.05, 0.9).dx, k.p(0.05, 0.9).dy)
      ..quadraticBezierTo(k.p(0.3, -0.05).dx, k.p(0.3, -0.05).dy,
          k.p(0.6, 0.18).dx, k.p(0.6, 0.18).dy);
    for (final m in arc.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 0.06 * k.u) {
        k.c.drawCircle(m.getTangentForOffset(d)!.position, 0.01 * k.u,
            Paint()..color = Colors.white.withValues(alpha: 0.7));
      }
    }
    k.ball(k.p(0.6, 0.18), 0.05, Colors.white);
  },
  'hungry_hippos': (k) {
    final rnd = Random(6);
    for (var i = 0; i < 9; i++) {
      k.ball(k.p(0.45 + rnd.nextDouble() * 0.4, 0.3 + rnd.nextDouble() * 0.4),
          0.04, Colors.white);
    }
    void hippo(Offset at, Color col, double turn) {
      k.c.save();
      k.c.translate(at.dx, at.dy);
      k.c.rotate(turn);
      final u = k.u;
      k.c.drawOval(
          Rect.fromCenter(
              center: Offset.zero, width: 0.36 * u, height: 0.3 * u),
          Paint()..color = col);
      k.c.drawOval(
          Rect.fromCenter(
              center: Offset(0.14 * u, 0), width: 0.24 * u, height: 0.22 * u),
          Paint()..color = k.dark(col, 0.45));
      k.c.drawCircle(
          Offset(-0.06 * u, -0.1 * u), 0.04 * u, Paint()..color = Colors.white);
      k.c.drawCircle(
          Offset(-0.05 * u, -0.1 * u), 0.02 * u, Paint()..color = _ink);
      k.c.restore();
    }

    hippo(k.p(0.2, 0.3), _purple, 0.3);
    hippo(k.p(1.12, 0.72), _orange, pi + 0.3);
    hippo(k.p(0.25, 0.8), _green, -0.4);
  },
  'penguin_push': (k) {
    final floe = k.rc(0.65, 0.6, 1.15, 0.6);
    k.c.drawOval(floe.shift(Offset(0, 0.05 * k.u)),
        Paint()..color = const Color(0xFF1E5E9A));
    k.c.drawOval(floe, Paint()..color = const Color(0xFFF2FAFF));
    k.c.drawOval(
        floe.deflate(0.05 * k.u), Paint()..color = const Color(0xFFDDEEF8));
    void penguin(Offset at, Color scarf) {
      final u = k.u;
      k.c.drawOval(
          Rect.fromCenter(center: at, width: 0.2 * u, height: 0.28 * u),
          Paint()..color = _ink);
      k.c.drawOval(
          Rect.fromCenter(
              center: at + Offset(0, 0.03 * u),
              width: 0.13 * u,
              height: 0.2 * u),
          Paint()..color = Colors.white);
      k.c.drawCircle(
          at + Offset(-0.03 * u, -0.07 * u), 0.016 * u, Paint()..color = _ink);
      k.c.drawCircle(
          at + Offset(0.03 * u, -0.07 * u), 0.016 * u, Paint()..color = _ink);
      k.c.drawPath(
          Path()
            ..moveTo(at.dx - 0.025 * u, at.dy - 0.04 * u)
            ..lineTo(at.dx + 0.025 * u, at.dy - 0.04 * u)
            ..lineTo(at.dx, at.dy - 0.01 * u)
            ..close(),
          Paint()..color = _orange);
      k.c.drawRect(
          Rect.fromCenter(
              center: at + Offset(0, 0.015 * u),
              width: 0.17 * u,
              height: 0.03 * u),
          Paint()..color = scarf);
    }

    penguin(k.p(0.4, 0.5), _red);
    penguin(k.p(0.88, 0.48), _blue);
    penguin(k.p(0.65, 0.68), _yellow);
  },
  'rock_paper_scissors': (k) {
    for (final (i, ic, col) in [
      (0, GameIcons.rock, _orange),
      (1, GameIcons.paper, _blue),
      (2, GameIcons.scissors, _red)
    ]) {
      final at = k.p(0.24 + i * 0.41, 0.5 + (i == 1 ? -0.1 : 0.06));
      k.ball(at, 0.19, col);
      k.icon(ic, at, 0.26);
    }
  },
  'ring_sort': (k) {
    final cols = [
      [_red, _blue, _red],
      [_blue, _yellow, _yellow, _blue],
      [_yellow, _red]
    ];
    for (var p = 0; p < 3; p++) {
      final x = 0.27 + p * 0.38;
      k.block(k.rc(x, 0.9, 0.34, 0.07), _woodDark, radius: 0.03);
      k.block(k.rc(x, 0.53, 0.045, 0.7), _woodLight, radius: 0.02);
      for (var i = 0; i < cols[p].length; i++) {
        k.block(k.rc(x, 0.8 - i * 0.13, 0.3, 0.12), cols[p][i], radius: 0.06);
      }
    }
  },
  'ball_sort': (k) {
    final rings = [
      [_red, _blue, _red],
      [_blue, _green, _green],
      [_yellow, _orange],
      <Color>[],
    ];
    for (var t = 0; t < 4; t++) {
      final c = k.p(0.28 + (t % 2) * 0.74, 0.28 + (t ~/ 2) * 0.48);
      final path = Path();
      for (var i = 0; i < 6; i++) {
        final a = -pi / 2 + i * pi / 3;
        final p = c + Offset(cos(a), sin(a)) * 0.2 * k.u;
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      k.c.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.018 * k.u
            ..color = Colors.white);
      for (var i = 0; i < rings[t].length; i++) {
        k.ball(c + Offset(0, (i - 1) * 0.06 * k.u), 0.05, rings[t][i],
            shade: false);
      }
    }
  },
  'fruit_cut': (k) {
    k.icon(GameIcons.watermelon, k.p(0.35, 0.35), 0.36);
    k.icon(GameIcons.apple, k.p(0.85, 0.55), 0.28);
    k.icon(GameIcons.bomb, k.p(0.6, 0.78), 0.26);
    k.line(k.p(0.15, 0.7), k.p(1.1, 0.2), Colors.white, 0.012);
  },
  'chicken_jump': (k) {
    k.block(k.rc(0.35, 0.82, 0.4, 0.08), _woodLight, radius: 0.02);
    k.block(k.rc(0.85, 0.55, 0.4, 0.08), _woodDark, radius: 0.02);
    k.block(k.rc(0.45, 0.28, 0.36, 0.08), _green, radius: 0.02);
    k.icon(GameIcons.bird, k.p(0.55, 0.62), 0.28);
  },
  'carrom': (k) {
    final board = k.rc(0.65, 0.5, 1.15, 0.95);
    k.block(board, const Color(0xFFF3E2C4), radius: 0.04);
    for (final corner in [
      board.topLeft,
      board.topRight,
      board.bottomLeft,
      board.bottomRight
    ]) {
      k.c.drawCircle(corner, 0.05 * k.u, Paint()..color = _ink);
    }
    k.ball(k.p(0.55, 0.42), 0.06, _cream, shade: false);
    k.ball(k.p(0.75, 0.5), 0.06, _ink, shade: false);
    k.ball(k.p(0.65, 0.58), 0.055, _red, shade: false);
    k.line(k.p(0.3, 0.85), k.p(0.62, 0.55), _woodDark, 0.01);
  },
  'eight_ball': (k) {
    final table = k.rc(0.65, 0.5, 1.2, 0.72);
    k.block(table, const Color(0xFF1F7A4D), radius: 0.06);
    for (final corner in [
      table.topLeft,
      table.topRight,
      table.bottomLeft,
      table.bottomRight,
      table.topCenter,
      table.bottomCenter
    ]) {
      k.c.drawCircle(corner, 0.045 * k.u, Paint()..color = _ink);
    }
    k.ball(k.p(0.4, 0.5), 0.055, _cream, shade: false);
    k.ball(k.p(0.85, 0.42), 0.055, _yellow, shade: false);
    k.ball(k.p(0.95, 0.55), 0.055, _red, shade: false);
    k.ball(k.p(1.05, 0.45), 0.055, _ink, shade: false);
  },
  'candy_crush': (k) {
    final cols = [_red, _yellow, _blue, _green, _orange, _purple];
    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 4; c++) {
        k.ball(k.p(0.28 + c * 0.24, 0.22 + r * 0.2), 0.07,
            cols[(r * 3 + c) % cols.length],
            shade: false);
      }
    }
  },
  'bike_race': (k) {
    k.block(k.rc(0.65, 0.72, 1.2, 0.18), const Color(0xFF3A3A3A), radius: 0.02);
    k.block(k.rc(0.4, 0.55, 0.18, 0.16), _red, radius: 0.02);
    k.c.drawCircle(k.p(0.32, 0.7), 0.07 * k.u, Paint()..color = _ink);
    k.c.drawCircle(k.p(0.52, 0.7), 0.07 * k.u, Paint()..color = _ink);
    k.icon(GameIcons.flag, k.p(1.05, 0.35), 0.28);
  },
  'truth_dare': (k) {
    k.text('TRUTH', k.p(0.65, 0.1), 0.12, Colors.white);
    k.text('DARE', k.p(0.65, 0.92), 0.12, _yellow);
    k.c.save();
    final c = k.p(0.65, 0.52);
    k.c.translate(c.dx, c.dy);
    k.c.rotate(0.9);
    k.c.translate(-c.dx, -c.dy);
    k.icon(GameIcons.bottle, c, 0.62);
    k.c.restore();
    for (var i = 0; i < 3; i++) {
      k.c.drawArc(
          Rect.fromCircle(center: c, radius: (0.36 + i * 0.04) * k.u),
          -0.6 + i * 0.1,
          1.0,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.012 * k.u
            ..color = Colors.white.withValues(alpha: 0.5 - i * 0.12));
    }
  },

  // ---------- Party games ----------
  'charades': (k) {
    k.icon(GameIcons.clapper, k.p(0.4, 0.55), 0.62);
    _roleCard(k, k.p(0.95, 0.5), 0.15, k.color, GameIcons.people);
  },
  'heads_up': (k) {
    final phone = k.rc(0.65, 0.5, 0.95, 0.6);
    k.block(phone, _ink, radius: 0.09);
    final screen = phone.deflate(0.05 * k.u);
    k.c.drawRRect(RRect.fromRectAndRadius(screen, Radius.circular(0.05 * k.u)),
        Paint()..color = k.color);
    k.text('ELEPHANT', screen.center, 0.14, Colors.white);
    k.icon(GameIcons.check, k.p(0.13, 0.15), 0.18, col: _green);
    k.icon(GameIcons.skip, k.p(1.17, 0.85), 0.18, col: _orange);
  },
  'draw_guess': (k) {
    final canvas = k.rc(0.6, 0.5, 0.95, 0.82);
    k.panel(canvas, fill: Colors.white, radius: 0.04);
    // A doodled house and sun.
    k.stroke(
        Path()
          ..moveTo(k.p(0.36, 0.75).dx, k.p(0.36, 0.75).dy)
          ..lineTo(k.p(0.36, 0.5).dx, k.p(0.36, 0.5).dy)
          ..lineTo(k.p(0.53, 0.32).dx, k.p(0.53, 0.32).dy)
          ..lineTo(k.p(0.7, 0.5).dx, k.p(0.7, 0.5).dy)
          ..lineTo(k.p(0.7, 0.75).dx, k.p(0.7, 0.75).dy)
          ..close(),
        _blue,
        0.03);
    k.c.drawCircle(
        k.p(0.86, 0.3),
        0.07 * k.u,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.03 * k.u
          ..color = _orange);
    k.icon(GameIcons.pencil, k.p(1.08, 0.72), 0.32);
    k.block(k.rc(0.25, 0.14, 0.22, 0.16), _yellow, radius: 0.08);
    k.text('?', k.p(0.25, 0.14), 0.13, _ink);
  },
  'most_likely': (k) {
    for (var i = 0; i < 3; i++) {
      final at = k.p(0.28 + i * 0.37, 0.58);
      k.ball(at, 0.15, [_red, _blue, _yellow][i]);
      k.c.drawCircle(at + Offset(-0.04 * k.u, -0.02 * k.u), 0.018 * k.u,
          Paint()..color = _ink);
      k.c.drawCircle(at + Offset(0.04 * k.u, -0.02 * k.u), 0.018 * k.u,
          Paint()..color = _ink);
    }
    // Everyone points at the middle one.
    k.icon(GameIcons.arrowDown, k.p(0.65, 0.18), 0.24, col: _yellow);
    k.icon(GameIcons.crown, k.p(0.65, 0.38), 0.18, col: _yellow);
    k.text('2 votes', k.p(0.65, 0.92), 0.1, Colors.white);
  },
  'would_rather': (k) {
    k.block(k.rc(0.36, 0.5, 0.52, 0.72), _red, radius: 0.07);
    k.block(k.rc(0.94, 0.5, 0.52, 0.72), _blue, radius: 0.07);
    k.text('A', k.p(0.36, 0.46), 0.3, Colors.white);
    k.text('B', k.p(0.94, 0.46), 0.3, Colors.white);
    k.ball(k.p(0.65, 0.5), 0.12, Colors.white);
    k.text('OR', k.p(0.65, 0.5), 0.09, _ink);
  },
  'find_spy': (k) {
    _roleCard(k, k.p(0.35, 0.52), -0.18, _blue, GameIcons.people);
    _roleCard(k, k.p(0.95, 0.52), 0.18, _blue, GameIcons.people);
    _roleCard(k, k.p(0.65, 0.46), 0, _ink, GameIcons.eye);
  },
  'undercover': (k) {
    _roleCard(k, k.p(0.38, 0.5), -0.15, _teal, GameIcons.speech);
    _roleCard(k, k.p(0.88, 0.5), 0.15, _ink, GameIcons.mask);
  },
  'mafia': (k) {
    k.icon(GameIcons.moon, k.p(1.1, 0.14), 0.24, col: _yellow);
    _roleCard(k, k.p(0.3, 0.55), -0.2, _blue, GameIcons.shield);
    _roleCard(k, k.p(0.65, 0.5), 0, const Color(0xFF8A1C3A), GameIcons.mask);
    _roleCard(k, k.p(1.0, 0.55), 0.2, _green, GameIcons.medical);
  },

  // ---------- Solo games ----------
  'game_2048': (k) {
    final g = k.rc(0.65, 0.5, 0.92, 0.92);
    k.block(g, const Color(0xFFBBA58F), radius: 0.06);
    final vals = [2, 4, 8, 0, 16, 32, 4, 2, 0, 64, 128, 8, 2, 0, 2048, 4];
    const cols = {
      2: Color(0xFFF3E9DC),
      4: Color(0xFFEFDFC4),
      8: Color(0xFFF5A66B),
      16: Color(0xFFF68C5A),
      32: Color(0xFFF46F55),
      64: Color(0xFFF24E35),
      128: Color(0xFFEFCF6B),
      2048: Color(0xFFEDC22E),
    };
    final s = (g.width - 0.05 * k.u) / 4;
    for (var i = 0; i < 16; i++) {
      final r = Rect.fromLTWH(g.left + 0.025 * k.u + s * (i % 4) + 2,
          g.top + 0.025 * k.u + s * (i ~/ 4) + 2, s - 4, s - 4);
      final v = vals[i];
      k.c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(0.03 * k.u)),
          Paint()..color = v == 0 ? const Color(0xFFCDC1B4) : cols[v]!);
      if (v > 0)
        k.text('$v', r.center, v >= 1000 ? 0.07 : 0.11,
            v <= 4 ? const Color(0xFF776E65) : Colors.white);
    }
  },
  'sliding_puzzle': (k) {
    final g = k.rc(0.65, 0.5, 0.92, 0.92);
    k.block(g, _woodDark, radius: 0.06);
    final s = (g.width - 0.05 * k.u) / 3;
    final order = [1, 2, 3, 4, 5, 6, 7, 0, 8];
    for (var i = 0; i < 9; i++) {
      if (order[i] == 0) continue;
      final r = Rect.fromLTWH(g.left + 0.025 * k.u + s * (i % 3) + 2,
          g.top + 0.025 * k.u + s * (i ~/ 3) + 2, s - 4, s - 4);
      k.block(r, _woodLight, radius: 0.04, shade: false);
      k.text('${order[i]}', r.center, 0.15, const Color(0xFF6B4220));
    }
    k.icon(GameIcons.arrowLeft, k.p(0.65 + s / k.u * 0.5, 0.5 + s / k.u), 0.14,
        col: Colors.white);
  },
  'sudoku': (k) {
    final g = k.rc(0.65, 0.5, 0.9, 0.9);
    k.panel(g, fill: Colors.white, radius: 0.03);
    _grid(k, g, 6, 6, const Color(0xFFCFC6DD), 0.006);
    _grid(k, g, 2, 2, _ink, 0.016);
    final s = g.width / 6;
    final digits = {
      0: '5',
      2: '3',
      7: '7',
      9: '1',
      13: '9',
      16: '8',
      20: '6',
      22: '2',
      27: '4',
      30: '3',
      33: '6',
      35: '1'
    };
    digits.forEach((i, d) => k.text(
        d,
        Offset(g.left + s * (i % 6 + 0.5), g.top + s * (i ~/ 6 + 0.5)),
        0.1,
        i == 13 || i == 22 ? _blue : _ink));
    k.c.drawRect(Rect.fromLTWH(g.left + s * 3, g.top + s * 4, s, s),
        Paint()..color = _yellow.withValues(alpha: 0.4));
  },
  'minesweeper': (k) {
    final g = k.rc(0.65, 0.5, 1.1, 0.88);
    const cols = 5, rows = 4;
    final cw = g.width / cols, ch = g.height / rows;
    final open = {
      (0, 0): '1',
      (1, 0): '1',
      (0, 1): '',
      (1, 1): '2',
      (0, 2): '1',
      (2, 2): '3',
      (1, 2): '2',
      (0, 3): '',
      (1, 3): '1'
    };
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        final r = Rect.fromLTWH(
            g.left + cw * x + 1.5, g.top + ch * y + 1.5, cw - 3, ch - 3);
        final o = open[(x, y)];
        if (o == null) {
          k.block(r, const Color(0xFF7CCB5A), radius: 0.03, shade: false);
        } else {
          k.c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(0.03 * k.u)),
              Paint()..color = const Color(0xFFE8D6B4));
          if (o.isNotEmpty)
            k.text(o, r.center, 0.12,
                o == '1' ? _blue : (o == '2' ? _green : _red));
        }
      }
    }
    k.icon(GameIcons.flag, Offset(g.left + cw * 3.5, g.top + ch * 1.5), 0.14);
    k.icon(GameIcons.mine, Offset(g.left + cw * 3.5, g.top + ch * 3.5), 0.16);
  },
  'hangman': (k) {
    k.block(k.rc(0.65, 0.5, 1.2, 0.95), const Color(0xFF2E4A3E), radius: 0.05);
    final chalk = Colors.white.withValues(alpha: 0.9);
    k.line(k.p(0.2, 0.78), k.p(0.55, 0.78), chalk, 0.02);
    k.line(k.p(0.3, 0.78), k.p(0.3, 0.12), chalk, 0.02);
    k.line(k.p(0.3, 0.12), k.p(0.62, 0.12), chalk, 0.02);
    k.line(k.p(0.62, 0.12), k.p(0.62, 0.24), chalk, 0.015);
    k.c.drawCircle(
        k.p(0.62, 0.3),
        0.06 * k.u,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.018 * k.u
          ..color = chalk);
    k.line(k.p(0.62, 0.36), k.p(0.62, 0.55), chalk, 0.018);
    k.line(k.p(0.62, 0.42), k.p(0.54, 0.5), chalk, 0.018);
    k.line(k.p(0.62, 0.42), k.p(0.7, 0.5), chalk, 0.018);
    for (var i = 0; i < 4; i++) {
      final x = 0.78 + i * 0.12;
      k.line(k.p(x, 0.7), k.p(x + 0.08, 0.7), chalk, 0.015);
      if (i != 2)
        k.text(['C', 'A', '', 'E'][i], k.p(x + 0.04, 0.62), 0.11, _yellow);
    }
  },
  'word_scramble': (k) {
    final letters = ['W', 'O', 'R', 'D'];
    final turns = [-0.15, 0.1, -0.08, 0.18];
    for (var i = 0; i < 4; i++) {
      final at = k.p(0.24 + i * 0.27, 0.5 + (i.isEven ? -0.06 : 0.08));
      k.c.save();
      k.c.translate(at.dx, at.dy);
      k.c.rotate(turns[i]);
      k.block(
          Rect.fromCenter(
              center: Offset.zero, width: 0.24 * k.u, height: 0.26 * k.u),
          const Color(0xFFF7E3B5),
          radius: 0.04);
      k.text(letters[i], Offset.zero, 0.17, const Color(0xFF6B4220));
      k.c.restore();
    }
  },
  'block_drop': (k) {
    final s = 0.17;
    void piece(List<(int, int)> cells, Color col, double ox, double oy) {
      for (final (x, y) in cells) {
        k.block(k.r(ox + x * s, oy + y * s, s - 0.01, s - 0.01), col,
            radius: 0.025, shade: false);
      }
    }

    piece([(0, 0), (1, 0), (2, 0), (1, 1)], _purple, 0.45, 0.02); // falling T
    piece([(0, 4), (1, 4), (2, 4), (3, 4), (4, 4)], _blue, 0.22, 0.12);
    piece([(0, 3), (0, 2), (1, 3)], _orange, 0.22, 0.12);
    piece([(3, 3), (4, 3), (4, 2), (5, 4)], _green, 0.22, 0.12);
    piece([(5, 3), (5, 2)], _red, 0.22, 0.12);
  },
  'brick_breaker': (k) {
    final cols = [_red, _orange, _yellow, _green];
    for (var y = 0; y < 3; y++) {
      for (var x = 0; x < 5; x++) {
        if (y == 2 && (x == 1 || x == 2)) continue;
        k.block(
            k.r(0.1 + x * 0.225, 0.08 + y * 0.12, 0.21, 0.1), cols[(x + y) % 4],
            radius: 0.02, shade: false);
      }
    }
    k.block(k.rc(0.55, 0.9, 0.36, 0.06), Colors.white, radius: 0.03);
    k.line(k.p(0.55, 0.85), k.p(0.48, 0.6),
        Colors.white.withValues(alpha: 0.35), 0.02);
    k.ball(k.p(0.46, 0.55), 0.04, Colors.white, shade: false);
  },
  'bubble_shooter': (k) {
    final cols = [_red, _blue, _yellow, _green, _purple];
    final rnd = Random(3);
    for (var y = 0; y < 3; y++) {
      for (var x = 0; x < 6 - (y % 2); x++) {
        k.ball(k.p(0.2 + x * 0.18 + (y % 2) * 0.09, 0.1 + y * 0.155), 0.085,
            cols[rnd.nextInt(5)],
            shade: false);
      }
    }
    for (var d = 0.0; d < 1; d += 0.12) {
      k.c.drawCircle(Offset.lerp(k.p(0.65, 0.85), k.p(0.9, 0.45), d)!,
          0.012 * k.u, Paint()..color = Colors.white.withValues(alpha: 0.7));
    }
    k.ball(k.p(0.65, 0.88), 0.09, _blue);
  },
  'color_switch': (k) {
    final c = k.p(0.65, 0.42);
    final cols = [_teal, _purple, _red, _yellow];
    for (var i = 0; i < 4; i++) {
      k.c.drawArc(
          Rect.fromCircle(center: c, radius: 0.3 * k.u),
          i * pi / 2 + 0.3,
          pi / 2,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.08 * k.u
            ..color = cols[i]);
    }
    k.ball(k.p(0.65, 0.88), 0.07, _purple, shade: false);
    k.icon(GameIcons.star, c, 0.18, col: Colors.white);
  },
  'dino_run': (k) {
    k.line(k.p(0, 0.86), k.p(1.3, 0.86), const Color(0xFF8A6A3A), 0.02);
    k.icon(GameIcons.cactus, k.p(1.0, 0.68), 0.36);
    // A blocky dino mid-jump.
    final u = k.u;
    final at = k.p(0.4, 0.42);
    final g = Paint()..color = const Color(0xFF4CAF50);
    k.c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(
                at.dx - 0.12 * u, at.dy - 0.05 * u, 0.24 * u, 0.2 * u),
            Radius.circular(0.04 * u)),
        g);
    k.c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(
                at.dx + 0.04 * u, at.dy - 0.2 * u, 0.18 * u, 0.14 * u),
            Radius.circular(0.04 * u)),
        g);
    k.c.drawRect(
        Rect.fromLTWH(at.dx - 0.08 * u, at.dy + 0.14 * u, 0.05 * u, 0.08 * u),
        g);
    k.c.drawRect(
        Rect.fromLTWH(at.dx + 0.04 * u, at.dy + 0.14 * u, 0.05 * u, 0.06 * u),
        g);
    k.c.drawPath(
        Path()
          ..moveTo(at.dx - 0.12 * u, at.dy)
          ..lineTo(at.dx - 0.26 * u, at.dy + 0.08 * u)
          ..lineTo(at.dx - 0.12 * u, at.dy + 0.12 * u)
          ..close(),
        g);
    k.c.drawCircle(at + Offset(0.15 * u, -0.15 * u), 0.022 * u,
        Paint()..color = Colors.white);
    k.c.drawCircle(
        at + Offset(0.16 * u, -0.15 * u), 0.011 * u, Paint()..color = _ink);
  },
  'flappy_jump': (k) {
    for (final (x, gap) in [(0.25, 0.42), (0.95, 0.6)]) {
      k.block(k.r(x, -0.1, 0.18, gap - 0.12 + 0.1), _green, radius: 0.02);
      k.block(k.r(x, gap + 0.24, 0.18, 1.1 - gap - 0.24), _green, radius: 0.02);
      k.block(k.r(x - 0.02, gap - 0.16, 0.22, 0.06), k.dark(_green, 0.1),
          radius: 0.02);
      k.block(k.r(x - 0.02, gap + 0.22, 0.22, 0.06), k.dark(_green, 0.1),
          radius: 0.02);
    }
    k.icon(GameIcons.bird, k.p(0.65, 0.5), 0.3);
  },
  'sky_jumper': (k) {
    for (final (x, y) in [
      (0.3, 0.88),
      (0.9, 0.66),
      (0.42, 0.42),
      (1.0, 0.18)
    ]) {
      k.block(k.rc(x, y, 0.32, 0.06), _green, radius: 0.03);
    }
    final at = k.p(0.62, 0.5);
    k.ball(at, 0.09, _orange);
    k.c.drawCircle(at + Offset(0.03 * k.u, -0.02 * k.u), 0.015 * k.u,
        Paint()..color = _ink);
    k.icon(GameIcons.arrowUp, k.p(0.62, 0.24), 0.16);
  },
  'space_shooter': (k) {
    final ship = Path()
      ..moveTo(k.p(0.65, 0.58).dx, k.p(0.65, 0.58).dy)
      ..lineTo(k.p(0.78, 0.92).dx, k.p(0.78, 0.92).dy)
      ..lineTo(k.p(0.65, 0.84).dx, k.p(0.65, 0.84).dy)
      ..lineTo(k.p(0.52, 0.92).dx, k.p(0.52, 0.92).dy)
      ..close();
    k.fill(ship, const Color(0xFFDDE4F0));
    k.c.drawCircle(k.p(0.65, 0.74), 0.03 * k.u, Paint()..color = _blue);
    for (final y in [0.45, 0.3]) {
      k.line(k.p(0.65, y), k.p(0.65, y + 0.07), _yellow, 0.02);
    }
    k.icon(GameIcons.ufo, k.p(0.45, 0.16), 0.3);
    k.icon(GameIcons.alien, k.p(0.95, 0.22), 0.24);
  },
  'stack_tower': (k) {
    final cols = [_blue, _teal, _green, _yellow, _orange];
    var x = 0.65;
    for (var i = 0; i < 5; i++) {
      final w = 0.78 - i * 0.07;
      x += (i.isEven ? 1 : -1) * 0.03;
      k.block(k.rc(x, 0.88 - i * 0.15, w, 0.13), cols[i], radius: 0.02);
    }
    k.block(k.rc(1.0, 0.13, 0.5, 0.13), _red, radius: 0.02); // the moving slab
  },
  'piano_tiles': (k) {
    final board = k.rc(0.65, 0.5, 0.92, 1.0);
    k.c.drawRect(board, Paint()..color = Colors.white);
    for (var i = 1; i < 4; i++) {
      k.line(
          Offset(board.left + board.width * i / 4, board.top),
          Offset(board.left + board.width * i / 4, board.bottom),
          const Color(0xFFD0D4E0),
          0.008);
    }
    final w = board.width / 4;
    for (final (col, y, h) in [
      (0, 0.0, 0.3),
      (2, 0.25, 0.3),
      (1, 0.6, 0.32),
      (3, 0.82, 0.3)
    ]) {
      k.c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(board.left + w * col + 1, board.top + y * k.u,
                  w - 2, h * k.u),
              const Radius.circular(3)),
          Paint()..color = col == 1 ? _blue : _ink);
    }
  },
  'simon_says': (k) {
    final c = k.p(0.65, 0.5);
    final cols = [_green, _red, _yellow, _blue];
    k.c.drawCircle(
        c + Offset(0, 0.04 * k.u), 0.46 * k.u, Paint()..color = Colors.black38);
    k.c.drawCircle(c, 0.46 * k.u, Paint()..color = _ink);
    for (var i = 0; i < 4; i++) {
      final on = i == 1;
      final path = Path()
        ..addArc(Rect.fromCircle(center: c, radius: 0.42 * k.u),
            i * pi / 2 + pi + 0.06, pi / 2 - 0.12)
        ..arcTo(Rect.fromCircle(center: c, radius: 0.16 * k.u),
            (i + 1) * pi / 2 + pi - 0.12, -(pi / 2 - 0.24), false)
        ..close();
      k.fill(path, on ? k.light(cols[i], 0.35) : k.dark(cols[i], 0.1));
    }
    k.c.drawCircle(c, 0.13 * k.u, Paint()..color = const Color(0xFF3A3150));
  },
  'whack_mole': (k) {
    for (final x in [0.25, 0.65, 1.05]) {
      k.c.drawOval(
          k.rc(x, 0.78, 0.32, 0.12), Paint()..color = const Color(0xFF4A2E1A));
    }
    k.icon(GameIcons.mole, k.p(0.65, 0.6), 0.36);
    k.c.drawOval(
        k.rc(0.65, 0.8, 0.34, 0.08), Paint()..color = const Color(0xFF6B4A2A));
    k.icon(GameIcons.hammer, k.p(0.95, 0.3), 0.4);
  },
  'tank_battle': (k) {
    final yard = k.rc(0.65, 0.52, 1.15, 0.9);
    k.block(yard, const Color(0xFFE7C48A), radius: 0.08);
    k.block(k.rc(0.45, 0.55, 0.28, 0.12), const Color(0xFF6B4423), radius: 0.03);
    k.block(k.rc(0.9, 0.4, 0.26, 0.12), const Color(0xFF8D6A3A), radius: 0.03);
    k.ball(k.p(0.4, 0.78), 0.08, _blue, shade: false);
    k.ball(k.p(0.95, 0.28), 0.08, _orange, shade: false);
  },
  'sumo_push': (k) {
    final c = k.p(0.65, 0.52);
    k.c.drawCircle(c, 0.42 * k.u, Paint()..color = const Color(0xFF8A5A2B));
    k.c.drawCircle(c, 0.34 * k.u, Paint()..color = const Color(0xFFFFF1D2));
    k.ball(k.p(0.65, 0.66), 0.1, _blue, shade: false);
    k.ball(k.p(0.65, 0.38), 0.1, _orange, shade: false);
  },
};

/// Guess Who style: a row of character cards, one being checked.
void _faces(_Kit k, GameIcons tool) {
  final skins = [
    const Color(0xFFF2C29B),
    const Color(0xFF9C6B4A),
    const Color(0xFFE8B48A),
    const Color(0xFF6E4A33)
  ];
  final hair = [_ink, _orange, _yellow, const Color(0xFF4A3020)];
  for (var i = 0; i < 4; i++) {
    final at = k.p(0.22 + i * 0.29, 0.5);
    k.card(at, 0.26, 0.38, 0, i == 2 ? _yellow : const Color(0xFFB9D8FF),
        (inner) {
      final f = inner.center + Offset(0, inner.height * 0.08);
      final r = inner.width * 0.3;
      k.c.drawCircle(
          f - Offset(0, r * 0.35), r * 1.05, Paint()..color = hair[i]);
      k.c.drawCircle(f, r, Paint()..color = skins[i]);
      k.c.drawCircle(
          f + Offset(-r * 0.35, -r * 0.1), r * 0.12, Paint()..color = _ink);
      k.c.drawCircle(
          f + Offset(r * 0.35, -r * 0.1), r * 0.12, Paint()..color = _ink);
      k.c.drawArc(
          Rect.fromCircle(center: f + Offset(0, r * 0.2), radius: r * 0.4),
          0.3,
          pi - 0.6,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.12
            ..color = _ink);
    });
  }
  k.icon(tool, k.p(0.95, 0.82), 0.3);
}

/// One or two snakes on a grid with an apple.
void _snakes(_Kit k, {required bool two}) {
  final g = k.rc(0.65, 0.5, 1.2, 0.9);
  k.block(g.inflate(0.02 * k.u), const Color(0xFF1C3B2A), radius: 0.05);
  _grid(k, g, 12, 9, Colors.white.withValues(alpha: 0.08), 0.004);
  final s = g.width / 12;
  void snake(List<(int, int)> cells, Color col) {
    for (var i = 0; i < cells.length; i++) {
      final (x, y) = cells[i];
      final r =
          Rect.fromLTWH(g.left + s * x + 1, g.top + s * y + 1, s - 2, s - 2);
      k.c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(s * 0.3)),
          Paint()..color = i == 0 ? k.dark(col, 0.15) : col);
      if (i == 0) {
        k.c.drawCircle(r.center + Offset(-s * 0.18, -s * 0.15), s * 0.12,
            Paint()..color = Colors.white);
        k.c.drawCircle(r.center + Offset(s * 0.18, -s * 0.15), s * 0.12,
            Paint()..color = Colors.white);
      }
    }
  }

  snake(
      [(6, 2), (5, 2), (4, 2), (3, 2), (3, 3), (3, 4), (3, 5), (4, 5), (5, 5)],
      const Color(0xFF39C35C));
  if (two) snake([(8, 6), (9, 6), (10, 6), (10, 5), (10, 4), (10, 3)], _orange);
  k.icon(GameIcons.apple, Offset(g.left + s * 8.5, g.top + s * 2.5),
      s * 1.3 / k.u);
}

/// A glass jar of fruit, biggest at the bottom.
void _fruitJar(_Kit k) {
  final jar = k.rc(0.65, 0.52, 0.86, 0.92);
  final rr = RRect.fromRectAndCorners(jar,
      bottomLeft: Radius.circular(0.12 * k.u),
      bottomRight: Radius.circular(0.12 * k.u));
  k.c.drawRRect(rr, Paint()..color = Colors.white.withValues(alpha: 0.22));
  for (final (ic, x, y, s) in [
    (GameIcons.watermelon, 0.5, 0.74, 0.42),
    (GameIcons.pineapple, 0.84, 0.72, 0.34),
    (GameIcons.orange, 0.42, 0.42, 0.26), //
    (GameIcons.apple, 0.68, 0.46, 0.24), (GameIcons.grapes, 0.9, 0.42, 0.2),
    (GameIcons.cherry, 0.65, 0.12, 0.18),
  ]) {
    k.icon(ic, k.p(x, y), s);
  }
  k.c.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.02 * k.u
        ..color = Colors.white.withValues(alpha: 0.8));
  k.line(k.p(0.25, 0.22), k.p(1.05, 0.22), _red.withValues(alpha: 0.7), 0.012);
}
