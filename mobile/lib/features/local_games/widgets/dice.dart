import 'dart:math';
import 'package:flutter/material.dart';

/// A tappable die. Each new [rollId] plays a short tumble before settling on [value].
class RollingDice extends StatelessWidget {
  final int value; // 1-6
  final int rollId;
  final Color color;
  final double size;
  final VoidCallback? onTap;
  const RollingDice(
      {super.key,
      required this.value,
      required this.rollId,
      required this.color,
      this.size = 64,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: onTap != null ? 'Roll the dice' : 'Dice shows $value',
      child: GestureDetector(
        onTap: onTap,
        child: TweenAnimationBuilder<double>(
          key: ValueKey(rollId),
          tween: Tween(begin: rollId == 0 ? 1 : 0, end: 1),
          duration: const Duration(milliseconds: 550),
          curve: Curves.easeOut,
          builder: (context, t, _) {
            // While tumbling, flash random-looking faces; settle on the real one.
            final face =
                t < 1 ? ((rollId * 7 + (t * 12).floor() * 5) % 6) + 1 : value;
            return Transform.rotate(
              angle: (1 - t) * pi * 2.5,
              child: Transform.scale(
                  scale: 1 + sin(t * pi) * 0.15,
                  child: DiceFace(
                      value: face,
                      size: size,
                      glow: onTap != null ? color : null)),
            );
          },
        ),
      ),
    );
  }
}

class DiceFace extends StatelessWidget {
  final int value;
  final double size;
  final Color? glow;
  const DiceFace({super.key, required this.value, this.size = 64, this.glow});

  static const _pips = {
    1: [(0.5, 0.5)],
    2: [(0.27, 0.27), (0.73, 0.73)],
    3: [(0.27, 0.27), (0.5, 0.5), (0.73, 0.73)],
    4: [(0.27, 0.27), (0.73, 0.27), (0.27, 0.73), (0.73, 0.73)],
    5: [(0.27, 0.27), (0.73, 0.27), (0.5, 0.5), (0.27, 0.73), (0.73, 0.73)],
    6: [
      (0.27, 0.25),
      (0.73, 0.25),
      (0.27, 0.5),
      (0.73, 0.5),
      (0.27, 0.75),
      (0.73, 0.75)
    ],
  };

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _DiePainter(value.clamp(1, 6), glow)),
      );
}

/// A die with depth: a rounded white cube with a shaded lower edge, a soft top light and
/// sunken pips (red single pip, as on real dice).
class _DiePainter extends CustomPainter {
  final int value;
  final Color? glow;
  _DiePainter(this.value, this.glow);

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final rad = Radius.circular(size.width * 0.22);
    final body = RRect.fromRectAndRadius(r.deflate(size.width * 0.02), rad);
    if (glow != null) {
      canvas.drawRRect(
          body.inflate(2),
          Paint()
            ..color = glow!.withValues(alpha: 0.75)
            ..maskFilter =
                MaskFilter.blur(BlurStyle.normal, size.width * 0.14));
    }
    canvas.drawRRect(body.shift(Offset(0, size.width * 0.06)),
        Paint()..color = const Color(0x66000000));
    canvas.drawRRect(
        body, Paint()..color = const Color(0xFFB9BCD0)); // lower edge
    final top = RRect.fromRectAndCorners(
        Rect.fromLTRB(
            body.left, body.top, body.right, body.bottom - size.width * 0.07),
        topLeft: rad,
        topRight: rad,
        bottomLeft: rad,
        bottomRight: rad);
    canvas.drawRRect(
        top,
        Paint()
          ..shader = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Color(0xFFE6E8F2)]).createShader(r));
    canvas.drawRRect(
        top.deflate(size.width * 0.03),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.02
          ..color = Colors.white.withValues(alpha: 0.8));
    for (final (x, y) in DiceFace._pips[value]!) {
      final c = Offset(size.width * x, (size.height - size.width * 0.07) * y);
      final pr = size.width * 0.085;
      canvas.drawCircle(
          c,
          pr,
          Paint()
            ..shader = RadialGradient(
                    center: const Alignment(-0.3, -0.3),
                    colors: value == 1
                        ? const [Color(0xFFFF6B6B), Color(0xFFC62828)]
                        : const [Color(0xFF3A3560), Color(0xFF14102E)])
                .createShader(Rect.fromCircle(center: c, radius: pr)));
      canvas.drawCircle(
          c + Offset(0, pr * 0.25),
          pr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = pr * 0.25
            ..color = Colors.white.withValues(alpha: 0.35));
    }
  }

  @override
  bool shouldRepaint(_DiePainter old) => old.value != value || old.glow != glow;
}
