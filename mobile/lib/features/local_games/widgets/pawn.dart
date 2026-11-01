import 'package:flutter/material.dart';
import '../../../core/ui/components.dart';

/// A glossy dome token (Ludo, Snakes & Ladders): the seat colour with a dark rim, a soft
/// shadow and the player's shape on top, so tokens never differ by colour alone.
/// [glow] adds a gold ring (this token can move).
class PawnPainter extends CustomPainter {
  final Color color;
  final int seat;
  final bool glow;
  PawnPainter(this.color, this.seat, {this.glow = false});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    if (glow) {
      canvas.drawCircle(
          c,
          r * 1.05,
          Paint()
            ..color = Brand.gold.withValues(alpha: 0.9)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.35));
    }
    canvas.drawOval(
        Rect.fromCenter(
            center: c + Offset(0, r * 0.28), width: r * 1.9, height: r * 1.2),
        Paint()..color = const Color(0x73000000));
    canvas.drawCircle(
        c, r * 0.95, Paint()..color = Color.lerp(color, Colors.black, 0.35)!);
    final dome = c - Offset(0, r * 0.08);
    canvas.drawCircle(
        dome,
        r * 0.82,
        Paint()
          ..shader =
              RadialGradient(center: const Alignment(-0.35, -0.45), colors: [
            Color.lerp(color, Colors.white, 0.55)!,
            color,
            Color.lerp(color, Colors.black, 0.25)!
          ], stops: const [
            0,
            0.55,
            1
          ]).createShader(Rect.fromCircle(center: c, radius: r)));
    canvas.drawCircle(
        dome,
        r * 0.82,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = glow ? r * 0.16 : r * 0.1
          ..color = glow ? Brand.gold : Colors.white);
    final mark = r * 0.78;
    canvas.save();
    canvas.translate(dome.dx - mark / 2, dome.dy - mark / 2);
    PlayerShapePainter(
            PlayerPalette.shape(seat), Colors.white.withValues(alpha: 0.92))
        .paint(canvas, Size(mark, mark));
    canvas.restore();
  }

  @override
  bool shouldRepaint(PawnPainter old) =>
      old.color != color || old.glow != glow || old.seat != seat;
}
