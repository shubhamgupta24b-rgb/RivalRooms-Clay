import 'package:flutter/material.dart';
import '../../../core/ui/components.dart';
import '../../guess_person/models/gp_player.dart';
import 'local_game_shell.dart' show PauseButton;

/// A player's zone (spec 2.12): a 10-24 % wash of their colour and a 2 px edge in it on
/// the side that faces the middle of the table.
class _ZoneTint extends StatelessWidget {
  final Color color;
  final double strength;
  final Widget child;
  const _ZoneTint({required this.color, required this.strength, required this.child});

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: strength),
          border: Border(top: BorderSide(color: color, width: 2)),
        ),
        child: child,
      );
}

/// Phone lies flat between two players: player 1 (index 0) plays the bottom half,
/// player 2 (index 1) the top half, rotated to face them. [middle] sits between the
/// halves and never overlaps either player's touch area. With [colors] each half gets
/// its player's tint.
class SplitScreen extends StatelessWidget {
  final Widget Function(int playerIndex) half;
  final Widget middle;
  final List<Color>? colors;
  final double tint;
  const SplitScreen({super.key, required this.half, required this.middle, this.colors, this.tint = 0.10});

  Widget _half(int i) {
    final h = RepaintBoundary(child: half(i));
    return colors == null ? h : _ZoneTint(color: colors![i], strength: tint, child: h);
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(child: RotatedBox(quarterTurns: 2, child: _half(1))),
      middle,
      Expanded(child: _half(0)),
    ]);
  }
}

/// One zone per player on a phone lying flat.
/// - 2 players: top (rotated) and bottom halves with [middle] between them.
/// - 3-6 players: two columns along the long sides. Left zones face the left edge, right
///   zones the right edge, so everyone reads their zone upright; [center] floats in the middle.
class PlayerZones extends StatelessWidget {
  final int count;
  final Widget Function(int playerIndex) zone;
  final Widget middle;
  final Widget center;
  final List<Color>? colors;
  final double tint;
  const PlayerZones({super.key, required this.count, required this.zone, required this.middle, required this.center, this.colors, this.tint = 0.10});

  /// Players 1..ceil(n/2) sit on the left side (top to bottom), the rest on the right.
  static int leftCount(int n) => (n + 1) ~/ 2;

  @override
  Widget build(BuildContext context) {
    if (count <= 2) return SplitScreen(half: zone, middle: middle, colors: colors, tint: tint);
    final left = leftCount(count);
    Widget one(int i) {
      final z = RepaintBoundary(child: zone(i));
      if (colors == null) return z;
      return ClipRRect(borderRadius: Radii.rLg, child: _ZoneTint(color: colors![i], strength: tint, child: z));
    }

    Widget column(Iterable<int> ids, int turns) => Column(children: [
          for (final i in ids) Expanded(child: Padding(padding: const EdgeInsets.all(3), child: RotatedBox(quarterTurns: turns, child: one(i)))),
        ]);
    return Stack(children: [
      Row(children: [
        Expanded(child: column(Iterable.generate(left), 1)),
        Expanded(child: column(Iterable.generate(count - left, (i) => left + i), 3)),
      ]),
      Center(child: center),
    ]);
  }
}

/// A player's controls along their edge of the phone (spec 2.12): 96-120 px, in their
/// colour. [top] turns it 180° for the far player.
class ControlStrip extends StatelessWidget {
  final GpPlayer player;
  final List<Widget> children;
  final bool top;
  final double height;
  const ControlStrip({super.key, required this.player, required this.children, this.top = false, this.height = 108});

  @override
  Widget build(BuildContext context) {
    final c = player.color;
    final strip = Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [c.withValues(alpha: 0.10), c.withValues(alpha: 0.24)]),
        border: Border(top: BorderSide(color: c, width: 2)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.center, children: children),
    );
    return top ? RotatedBox(quarterTurns: 2, child: strip) : strip;
  }
}

/// Time left on a shared phone, running along the side edge (rotated 90°) so neither end of
/// the table reads it upside down (spec 2.12).
class SideTimer extends StatelessWidget {
  final int secondsLeft;
  final double fraction; // 1 = full time left
  final bool right;
  const SideTimer({super.key, required this.secondsLeft, required this.fraction, this.right = true});

  @override
  Widget build(BuildContext context) {
    final urgent = secondsLeft <= 5;
    final c = urgent ? StatusColors.danger : Brand.gold;
    final text = secondsLeft >= 60 ? '${secondsLeft ~/ 60}:${(secondsLeft % 60).toString().padLeft(2, '0')}' : '$secondsLeft';
    return Semantics(
      label: '$secondsLeft seconds left',
      excludeSemantics: true,
      child: RotatedBox(
        quarterTurns: right ? 1 : 3,
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: Skin.pill(color: NeonPalette.overlay),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            GameIcon(GameIcons.clock, size: 14, color: c),
            const SizedBox(width: 6),
            Text(text, style: TextStyle(fontFamily: Fonts.display, fontSize: 17, color: urgent ? c : Colors.white, fontFeatures: const [FontFeature.tabularFigures()])),
            const SizedBox(width: 8),
            SizedBox(
              width: 70,
              child: ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: fraction.clamp(0, 1), minHeight: 5, color: c, backgroundColor: Colors.white.withValues(alpha: 0.16))),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Small floating pill for the middle of a 3-6 player layout: status text + pause.
class ZoneCenterChip extends StatelessWidget {
  final String text;
  const ZoneCenterChip(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 14, right: 2),
      decoration: Skin.pill(color: NeonPalette.sheet),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Semantics(
          liveRegion: true,
          child: Text(stripEmoji(text), style: const TextStyle(fontFamily: Fonts.display, fontSize: 17, color: Colors.white, fontFeatures: [FontFeature.tabularFigures()])),
        ),
        const SizedBox(width: 4),
        const PauseButton(),
      ]),
    );
  }
}

/// A player's name on their colour, with their shape.
class PlayerTagSmall extends StatelessWidget {
  final GpPlayer player;
  const PlayerTagSmall({super.key, required this.player});
  @override
  Widget build(BuildContext context) {
    final seat = PlayerPalette.indexOf(player.color);
    final fill = fillFor(player.color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.s, vertical: Space.xs),
      decoration: Skin.pill(color: fill),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (seat != null) ...[SizedBox(width: 12, height: 12, child: CustomPaint(painter: PlayerShapePainter(PlayerPalette.shape(seat), onColor(fill)))), const SizedBox(width: 5)],
        Flexible(
          child: Text(player.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: Fonts.body, color: onColor(fill), fontWeight: FontWeight.w900, fontSize: 13)),
        ),
      ]),
    );
  }
}

/// A player's score in the middle bar: their badge and the number in Lilita (never colour alone).
class _ScoreBadge extends StatelessWidget {
  final GpPlayer player;
  final int score;
  const _ScoreBadge(this.player, this.score);
  @override
  Widget build(BuildContext context) {
    final seat = PlayerPalette.indexOf(player.color) ?? 0;
    return Semantics(
      label: '${player.name} $score',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minWidth: 58),
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: Skin.surface(tint: player.color, ring: player.color, radius: Radii.chip, depth: 0.6),
        child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
          PlayerBadge(index: seat, size: 16, color: player.color),
          const SizedBox(width: 6),
          Text('$score', style: const TextStyle(fontFamily: Fonts.display, fontSize: 22, height: 1, color: Colors.white, fontFeatures: [FontFeature.tabularFigures()])),
        ]),
      ),
    );
  }
}

BoxDecoration _barDecoration() => BoxDecoration(
      color: NeonPalette.bgBottom,
      border: Border.symmetric(horizontal: BorderSide(color: Colors.white.withValues(alpha: 0.14))),
      boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 12)],
    );

/// Centre strip for "first to N" games: both scores (player 2's upside down) and the target.
class ScoreMiddleBar extends StatelessWidget {
  final List<GpPlayer> players;
  final List<int> scores;
  final String label; // e.g. "FIRST TO 5"
  const ScoreMiddleBar({super.key, required this.players, required this.scores, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: _barDecoration(),
      padding: const EdgeInsets.symmetric(horizontal: Space.m),
      child: Row(children: [
        RotatedBox(quarterTurns: 2, child: _ScoreBadge(players[1], scores[1])),
        Expanded(
          child: Text(stripEmoji(label).toUpperCase(),
              textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: Fonts.body, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.6, color: NeonPalette.label)),
        ),
        const PauseButton(),
        const SizedBox(width: Space.xs),
        _ScoreBadge(players[0], scores[0]),
      ]),
    );
  }
}

/// Centre strip: seconds left plus a tug-of-war bar showing who is ahead.
class DuelMiddleBar extends StatelessWidget {
  final List<GpPlayer> players;
  final List<int> scores;
  final int secondsLeft;
  final double progress;
  const DuelMiddleBar({super.key, required this.players, required this.scores, required this.secondsLeft, required this.progress});

  @override
  Widget build(BuildContext context) {
    final total = scores[0] + scores[1];
    final share = total == 0 ? 0.5 : scores[0] / total; // player 1's share
    final urgent = secondsLeft <= 3;
    return Container(
      height: 56,
      decoration: _barDecoration(),
      padding: const EdgeInsets.symmetric(horizontal: Space.m),
      child: Row(children: [
        // Player 2's score is upside down so they can read it from their side.
        RotatedBox(quarterTurns: 2, child: _ScoreBadge(players[1], scores[1])),
        const SizedBox(width: Space.s),
        Expanded(
          child: ExcludeSemantics(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 10,
                  child: Row(children: [
                    Expanded(flex: (share * 1000).round().clamp(1, 999), child: Container(color: players[0].color)),
                    Container(width: 2, color: Colors.white),
                    Expanded(flex: ((1 - share) * 1000).round().clamp(1, 999), child: Container(color: players[1].color)),
                  ]),
                ),
              ),
              const SizedBox(height: Space.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(value: 1 - progress, minHeight: 4, color: urgent ? StatusColors.danger : Brand.gold, backgroundColor: Colors.white.withValues(alpha: 0.14)),
              ),
            ]),
          ),
        ),
        const SizedBox(width: Space.xs),
        const PauseButton(),
        Semantics(
          label: '$secondsLeft seconds left',
          excludeSemantics: true,
          child: Text('${secondsLeft}s', style: TextStyle(fontFamily: Fonts.display, fontSize: 20, color: urgent ? StatusColors.danger : Colors.white, fontFeatures: const [FontFeature.tabularFigures()])),
        ),
        const SizedBox(width: Space.s),
        _ScoreBadge(players[0], scores[0]),
      ]),
    );
  }
}
