import 'dart:math';
import 'package:flutter/material.dart';

/// Sun and drifting clouds for the open sky above a side-view scene (archery, slingshot)
/// when a tall screen leaves room above it. [extra] is how much sky there is, [s] the
/// scene's scale (its width in pixels).
void drawSkyExtras(
    Canvas canvas, Size size, double s, double extra, int nowMs) {
  if (extra < 40) return;
  final sun = Offset(size.width * 0.8, min(extra * 0.35, s * 0.18));
  canvas.drawCircle(sun, s * 0.11, Paint()..color = const Color(0x33FFF59D));
  canvas.drawCircle(sun, s * 0.07, Paint()..color = const Color(0xFFFFF176));
  for (final (x, y, k) in const [
    (0.15, 0.25, 1.0),
    (0.55, 0.55, 0.8),
    (0.9, 0.8, 1.2)
  ]) {
    final drift = (x + nowMs / 90000 * k) % 1.3 - 0.15;
    final c = Offset(drift * size.width, y * extra);
    for (final (dx, dy, r) in const [
      (0.0, 0.0, 0.05),
      (0.05, -0.018, 0.042),
      (-0.05, 0.006, 0.036),
      (0.09, 0.008, 0.03)
    ]) {
      canvas.drawCircle(c + Offset(dx * s * k, dy * s * k), r * s * k,
          Paint()..color = Colors.white.withValues(alpha: 0.85));
    }
  }
}
