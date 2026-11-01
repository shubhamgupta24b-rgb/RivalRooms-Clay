import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/session/game_session_manager.dart';

class PaintFightScreen extends StatefulWidget {
  const PaintFightScreen({super.key});
  @override
  State<PaintFightScreen> createState() => _PaintFightScreenState();
}

class _PaintFightScreenState extends State<PaintFightScreen> {
  Timer? timer;
  final Set<String> _sent = {};

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void _paint(
      Offset local, Size size, int w, int h, GameSessionManager session) {
    if (size.width <= 0 || size.height <= 0) return;
    final x = (local.dx / size.width * w).floor().clamp(0, w - 1);
    final y = (local.dy / size.height * h).floor().clamp(0, h - 1);
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        final cx = x + dx, cy = y + dy;
        if (cx < 0 || cy < 0 || cx >= w || cy >= h) continue;
        final key = '$cx,$cy';
        if (!_sent.add(key)) continue;
        session.action('paint_fight:paint', {'x': cx, 'y': cy});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<GameSessionManager>();
    final state = session.state!;
    final phase = state['phase'] as String;
    final end = (state['endsAt'] as num).toInt();
    final left = ((end - session.serverNowMs) <= 0
        ? 0
        : ((end - session.serverNowMs) / 1000).ceil());
    final cells = (state['yourCells'] as List).map((e) => e.toString()).toSet();
    final w = (state['width'] as num).toInt(),
        h = (state['height'] as num).toInt();
    final players = (state['players'] as List).cast<Map>();
    final playing = phase == 'playing';
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        Text(playing ? 'PAINT FIGHT' : 'TIME UP',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        Text('$left s • Your territory: ${state['yourScore']}'),
        const SizedBox(height: 8),
        const Text('Drag across the board. Your brush paints a small patch.'),
        const SizedBox(height: 8),
        Expanded(
          child: LayoutBuilder(builder: (context, box) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: playing
                  ? (d) => _paint(d.localPosition, box.biggest, w, h, session)
                  : null,
              onPanUpdate: playing
                  ? (d) => _paint(d.localPosition, box.biggest, w, h, session)
                  : null,
              child: CustomPaint(
                painter: _TerritoryPainter(
                    cells: cells,
                    w: w,
                    h: h,
                    color: Theme.of(context).colorScheme.primary),
                child: const SizedBox.expand(),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        for (final player in players)
          Row(children: [
            Expanded(child: Text(player['username'].toString())),
            Text(player['score'].toString())
          ]),
      ]),
    );
  }
}

class _TerritoryPainter extends CustomPainter {
  final Set<String> cells;
  final int w, h;
  final Color color;
  _TerritoryPainter(
      {required this.cells,
      required this.w,
      required this.h,
      required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cw = size.width / w, ch = size.height / h;
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFF1B2430));
    final fill = Paint()..color = color;
    for (final key in cells) {
      final parts = key.split(',');
      if (parts.length != 2) continue;
      final x = int.tryParse(parts[0]), y = int.tryParse(parts[1]);
      if (x == null || y == null) continue;
      canvas.drawRect(Rect.fromLTWH(x * cw, y * ch, cw - 1, ch - 1), fill);
    }
  }

  @override
  bool shouldRepaint(covariant _TerritoryPainter oldDelegate) =>
      oldDelegate.cells.length != cells.length;
}
