import 'package:flutter/material.dart';
import '../models/gp_player.dart';
import 'gp_theme.dart';

/// One tile per player: 2 side by side, 3+ in rows of three.
class ScoreBoard extends StatelessWidget {
  final List<GpPlayer> players;
  final bool large;
  final Set<GpPlayer> highlight;
  const ScoreBoard(
      {super.key,
      required this.players,
      this.large = false,
      this.highlight = const {}});

  @override
  Widget build(BuildContext context) {
    final perRow = players.length <= 2 ? 2 : 3;
    final big = large && players.length <= 3;
    return LayoutBuilder(builder: (context, c) {
      const gap = 10.0;
      final w = (c.maxWidth - gap * (perRow - 1)) / perRow;
      return Wrap(
          alignment: WrapAlignment.center,
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final p in players)
              Container(
                width: w,
                padding: EdgeInsets.symmetric(
                    vertical: big ? 18 : 10, horizontal: 4),
                decoration: BoxDecoration(
                  color: p.color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: highlight.contains(p) ? GpColors.accent : p.color,
                      width: highlight.contains(p) ? 3 : 2),
                ),
                child: Column(children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(p.name.toUpperCase(),
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: big ? 16 : 13)),
                  ),
                  Text('${p.score}',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: big ? 48 : 28,
                          height: 1.1)),
                  Text(p.score == 1 ? 'point' : 'points',
                      style:
                          const TextStyle(color: GpColors.muted, fontSize: 12)),
                ]),
              ),
          ]);
    });
  }
}
