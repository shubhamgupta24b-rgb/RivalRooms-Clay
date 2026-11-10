import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/ui/components.dart';
import '../../guess_person/models/gp_player.dart';
import 'bots.dart';

/// Seats around a shared arena on a phone lying flat: player 1 at the bottom edge, player 2
/// at the top, players 3 and 4 on the left and right. Used by one-button arena games, where
/// a tap anywhere near your edge is your button.

/// The seat whose edge [p] is nearest to. With 2 players it's simply the bottom or top half.
int edgeSeat(Offset p, Size size, int players) {
  if (players <= 2) return p.dy >= size.height / 2 ? 0 : 1;
  final dx = (p.dx / size.width - 0.5) * 2,
      dy = (p.dy / size.height - 0.5) * 2; // -1..1
  if (players == 3 && dx > 0 && dx.abs() > dy.abs())
    return dy >= 0 ? 0 : 1; // no right seat
  if (dx.abs() > dy.abs()) return dx < 0 ? 2 : 3;
  return dy >= 0 ? 0 : 1;
}

/// Quarter turns that make text at [seat]'s edge read upright for them.
int edgeTurns(int seat) => const [0, 2, 1, 3][seat];

/// Quarter turns that bring [seat]'s edge to the bottom (online: each phone faces its own player).
int seatToBottom(int seat) => (4 - edgeTurns(seat)) % 4;

/// Unit direction from the arena centre toward [seat]'s edge.
Offset edgeDir(int seat) =>
    const [Offset(0, 1), Offset(0, -1), Offset(-1, 0), Offset(1, 0)][seat];

/// Name and score at a seat's edge, turned to face them.
class EdgeScore extends StatelessWidget {
  final GpPlayer player;
  final int seat;
  final String score;
  final bool dim;
  final String? tag;
  const EdgeScore(
      {super.key,
      required this.player,
      required this.seat,
      required this.score,
      this.dim = false,
      this.tag});

  @override
  Widget build(BuildContext context) {
    final chip = AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: dim ? 0.45 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: Skin.surface(
            tint: player.color,
            ring: player.color,
            radius: Radii.chip,
            depth: 0.6),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          PlayerBadge(
              index: PlayerPalette.indexOf(player.color) ?? seat,
              size: 16,
              color: player.color),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 90),
            child: Text(player.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: Fonts.body,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.white)),
          ),
          const SizedBox(width: 8),
          Text(score,
              style: const TextStyle(
                  fontFamily: Fonts.display,
                  fontSize: 20,
                  height: 1,
                  color: Colors.white,
                  fontFeatures: [FontFeature.tabularFigures()])),
          if (tag != null) ...[
            const SizedBox(width: 6),
            Text(tag!,
                style: const TextStyle(
                    fontFamily: Fonts.body,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    color: Brand.gold)),
          ],
        ]),
      ),
    );
    return Semantics(
        label: '${player.name} $score',
        excludeSemantics: true,
        child: RotatedBox(
            quarterTurns: BotScope.isBot(context, seat) ? 0 : edgeTurns(seat),
            child: chip));
  }
}

/// Lays out [arena] as big a square as fits, with each player's [EdgeScore] beside their edge.
/// [corner] (pause, timer) sits inside the arena's top-left corner, clear of every seat.
class EdgeArena extends StatelessWidget {
  final int players;
  final Widget arena;
  final Widget Function(int seat) label;
  final Widget corner;
  final void Function(int seat) onSeatTap;
  const EdgeArena(
      {super.key,
      required this.players,
      required this.arena,
      required this.label,
      required this.corner,
      required this.onSeatTap});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const band = 44.0; // room for the score chips at the top and bottom
      final side = max(
          0.0,
          min(c.maxWidth - (players > 2 ? 2 * band : 16),
              c.maxHeight - 2 * band - 8));
      final left = (c.maxWidth - side) / 2, top = (c.maxHeight - side) / 2;
      return Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) =>
            onSeatTap(edgeSeat(e.localPosition, c.biggest, players)),
        child: Stack(children: [
          Positioned(
              left: left, top: top, width: side, height: side, child: arena),
          Positioned(
              left: 0,
              right: 0,
              bottom: max(0, top - band - 2),
              height: band,
              child: Center(child: label(0))),
          Positioned(
              left: 0,
              right: 0,
              top: max(0, top - band - 2),
              height: band,
              child: Center(child: label(1))),
          if (players > 2)
            Positioned(
                left: max(0, left - band - 2),
                top: 0,
                bottom: 0,
                width: band,
                child: Center(child: label(2))),
          if (players > 3)
            Positioned(
                right: max(0, left - band - 2),
                top: 0,
                bottom: 0,
                width: band,
                child: Center(child: label(3))),
          Positioned(left: left + 4, top: top + 4, child: corner),
        ]),
      );
    });
  }
}
