import 'dart:math';
import 'package:flutter/material.dart';

/// A disc on a table. Positions are in table units (width [TableSim.w]).
class Puck {
  final int id;
  double x, y, vx, vy, r;
  final double mass;
  bool pocketed = false;
  Puck(this.id, this.x, this.y,
      {this.r = 0.028, this.vx = 0, this.vy = 0, this.mass = 1});

  double get speed => sqrt(vx * vx + vy * vy);
}

/// Deterministic 2D discs: friction, wall bounces, circle collisions, corner pockets.
/// Fixed substeps so two phones running the same shot land on the same spots.
class TableSim {
  final double w, h;
  final List<Puck> pucks;
  final List<Offset> pockets;
  final double pocketR;
  final double friction;
  final double restitution;
  TableSim({
    required this.w,
    required this.h,
    required this.pucks,
    required this.pockets,
    this.pocketR = 0.05,
    this.friction = 1.35,
    this.restitution = 0.86,
  });

  bool get resting => pucks.every((p) => p.pocketed || p.speed < 0.04);

  Puck byId(int id) => pucks.firstWhere((p) => p.id == id);

  /// Advances [dt] seconds in fixed slices.
  void step(double dt) {
    const slice = 1 / 180;
    var left = dt;
    while (left > 0) {
      _once(min(slice, left));
      left -= slice;
    }
  }

  void _once(double dt) {
    for (final p in pucks) {
      if (p.pocketed) continue;
      final damp = max(0.0, 1 - friction * dt);
      p.vx *= damp;
      p.vy *= damp;
      if (p.speed < 0.04) {
        p.vx = 0;
        p.vy = 0;
      }
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      final nearPocket =
          pockets.any((c) => (Offset(p.x, p.y) - c).distance < pocketR * 1.35);
      if (!nearPocket) {
        if (p.x < p.r) {
          p.x = p.r;
          p.vx = p.vx.abs() * restitution;
        } else if (p.x > w - p.r) {
          p.x = w - p.r;
          p.vx = -p.vx.abs() * restitution;
        }
        if (p.y < p.r) {
          p.y = p.r;
          p.vy = p.vy.abs() * restitution;
        } else if (p.y > h - p.r) {
          p.y = h - p.r;
          p.vy = -p.vy.abs() * restitution;
        }
      }
      for (final c in pockets) {
        if ((Offset(p.x, p.y) - c).distance < pocketR) {
          p.pocketed = true;
          p.vx = 0;
          p.vy = 0;
          p.x = c.dx;
          p.y = c.dy;
          break;
        }
      }
    }
    for (var i = 0; i < pucks.length; i++) {
      for (var j = i + 1; j < pucks.length; j++) {
        final a = pucks[i], b = pucks[j];
        if (a.pocketed || b.pocketed) continue;
        final dx = b.x - a.x, dy = b.y - a.y;
        final dist = sqrt(dx * dx + dy * dy);
        final minD = a.r + b.r;
        if (dist >= minD || dist < 1e-8) continue;
        final nx = dx / dist, ny = dy / dist;
        final overlap = minD - dist;
        final share = b.mass / (a.mass + b.mass);
        a.x -= nx * overlap * share;
        a.y -= ny * overlap * share;
        b.x += nx * overlap * (1 - share);
        b.y += ny * overlap * (1 - share);
        final rel = (a.vx - b.vx) * nx + (a.vy - b.vy) * ny;
        if (rel > 0) {
          final impulse = rel * (1 + restitution) / (1 / a.mass + 1 / b.mass);
          a.vx -= impulse * nx / a.mass;
          a.vy -= impulse * ny / a.mass;
          b.vx += impulse * nx / b.mass;
          b.vy += impulse * ny / b.mass;
        }
      }
    }
  }
}
