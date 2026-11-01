import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/ui/components.dart';
import '../../../core/ui/materials/materials.dart';
import '../rmcs_role.dart';
import 'role_card.dart';

class RmcsColors {
  static const top = NeonPalette.bgTop;
  static const bottom = NeonPalette.bgBottom;
  static const gold = Brand.gold;
  static const panel = Color(0x0FFFFFFF);
}

/// The night background with a soft royal-gold glow at the top.
class RmcsBackground extends StatelessWidget {
  final Widget child;
  const RmcsBackground({super.key, required this.child});
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [
                0,
                0.45,
                1
              ],
              colors: [
                NeonPalette.bgTop,
                NeonPalette.bg,
                NeonPalette.bgBottom
              ]),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
                center: const Alignment(0, -1.1),
                radius: 0.9,
                colors: [
                  Brand.gold.withValues(alpha: 0.14),
                  Colors.transparent
                ]),
          ),
          child: child,
        ),
      );
}

/// One player at the table: badge and name, their card, and the running score.
class RmcsSeat extends StatelessWidget {
  final String name;
  final Color color;
  final RmcsRole? role;
  final bool faceUp;
  final bool highlight;
  final Color? highlightColor;
  final int score;
  final int? delta; // points just won, shown after the reveal
  final String? badge; // e.g. "TAP TO REVEAL", "ACCUSED"
  final Color badgeColor;
  final bool dim;
  final Duration flipDuration;
  final VoidCallback? onTap;
  final int seat;
  const RmcsSeat({
    super.key,
    required this.name,
    required this.color,
    required this.role,
    required this.faceUp,
    required this.score,
    this.highlight = false,
    this.highlightColor,
    this.delta,
    this.badge,
    this.badgeColor = RmcsColors.gold,
    this.dim = false,
    this.flipDuration = const Duration(milliseconds: 650),
    this.onTap,
    this.seat = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label:
          '$name${faceUp && role != null ? ', ${role!.title}' : ''}, $score points${badge != null ? ', ${badge!.toLowerCase()}' : ''}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: dim ? 0.45 : 1,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                PlayerBadge(index: seat, size: 18, color: color),
                const SizedBox(width: 6),
                Flexible(
                    child: Text(name.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: Fonts.body,
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            letterSpacing: 0.6))),
              ]),
              const SizedBox(height: 4),
              Expanded(
                child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Center(
                          child: RoleCard(
                              role: role,
                              faceUp: faceUp,
                              highlight: highlight,
                              highlightColor: highlightColor,
                              duration: flipDuration)),
                      if (badge != null)
                        Positioned(
                          bottom: 6,
                          child: _Pulse(
                            enabled: onTap != null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                  color: badgeColor,
                                  borderRadius: BorderRadius.circular(9),
                                  boxShadow: const [
                                    BoxShadow(
                                        color: Color(0x80000000), blurRadius: 4)
                                  ]),
                              child: Text(badge!,
                                  style: TextStyle(
                                      fontFamily: Fonts.body,
                                      color: onColor(badgeColor),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 10,
                                      letterSpacing: 1)),
                            ),
                          ),
                        ),
                      if (delta != null)
                        Positioned(
                          top: -2,
                          right: 0,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.elasticOut,
                            builder: (_, t, child) =>
                                Transform.scale(scale: t, child: child),
                            child: EdgeTag(delta! > 0 ? '+$delta' : '+0',
                                color: delta! > 0 ? Brand.gold : Colors.white24,
                                score: delta! > 0),
                          ),
                        ),
                    ]),
              ),
              const SizedBox(height: 3),
              TweenAnimationBuilder<double>(
                tween: Tween(end: score.toDouble()),
                duration: const Duration(milliseconds: 900),
                builder: (_, v, __) => Text('${v.round()} pts',
                    style: const TextStyle(
                        fontFamily: Fonts.display,
                        color: RmcsColors.gold,
                        fontSize: 16,
                        fontFeatures: [FontFeature.tabularFigures()])),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Pulse extends StatefulWidget {
  final Widget child;
  final bool enabled;
  const _Pulse({required this.child, required this.enabled});
  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700));

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_Pulse old) {
    super.didUpdateWidget(old);
    if (widget.enabled && !_c.isAnimating) _c.repeat(reverse: true);
    if (!widget.enabled) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
      scale: Tween(begin: 1.0, end: 1.12).animate(_c), child: widget.child);
}

/// Four seats around the table, 2 by 2. [seats] must have 4 entries.
class SeatGrid extends StatelessWidget {
  final List<Widget> seats;
  const SeatGrid({super.key, required this.seats});
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(borderRadius: Radii.rBoard, boxShadow: const [
          BoxShadow(
              color: Color(0x80000000), blurRadius: 24, offset: Offset(0, 10))
        ]),
        child: CustomPaint(
          painter: const FeltPainter(),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(children: [
              for (var r = 0; r < 2; r++)
                Expanded(
                    child: Row(children: [
                  for (var c = 0; c < 2; c++) Expanded(child: seats[r * 2 + c])
                ])),
            ]),
          ),
        ),
      );
}

/// Shuffles a small deck in the middle of the table, then deals one card to each seat.
/// Calls [onDone] once (about 2.2 seconds).
class ShuffleDeal extends StatefulWidget {
  final VoidCallback onDone;
  const ShuffleDeal({super.key, required this.onDone});
  @override
  State<ShuffleDeal> createState() => _ShuffleDealState();
}

class _ShuffleDealState extends State<ShuffleDeal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2200))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    })
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final cardH =
          min(box.maxHeight * 0.32, box.maxWidth * 0.36 / rmcsCardAspect);
      final cardW = cardH * rmcsCardAspect;
      // Seat centres, matching SeatGrid.
      final targets = [
        for (var r = 0; r < 2; r++)
          for (var c = 0; c < 2; c++)
            Offset(box.maxWidth * (0.25 + 0.5 * c),
                box.maxHeight * (0.25 + 0.5 * r))
      ];
      final centre = Offset(box.maxWidth / 2, box.maxHeight / 2);
      return AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          final shuffle = (t / 0.55).clamp(0.0, 1.0);
          return Stack(children: [
            Positioned(
              left: 0,
              right: 0,
              top: centre.dy - cardH / 2 - 34,
              child: Opacity(
                opacity: (1 - (t - 0.5) * 4).clamp(0.0, 1.0),
                child: const Text('SHUFFLING…',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: Fonts.display,
                        color: RmcsColors.gold,
                        letterSpacing: 3,
                        fontSize: 20)),
              ),
            ),
            for (var i = 0; i < 4; i++)
              ...() {
                // Riffle: alternate cards slide left/right and swap depth.
                final side = i.isEven ? -1.0 : 1.0;
                final riffle = sin(shuffle * pi * 4 + i) *
                    cardW *
                    0.55 *
                    side *
                    (1 - shuffle * 0.3);
                final deal = Curves.easeOutCubic
                    .transform(((t - 0.55 - i * 0.08) / 0.3).clamp(0.0, 1.0));
                final from = centre + Offset(t < 0.55 ? riffle : 0, -i * 2.0);
                final pos = Offset.lerp(from, targets[i], deal)!;
                final angle = (1 - deal) *
                        (t < 0.55 ? side * 0.12 * sin(shuffle * pi * 4) : 0) +
                    deal * (i.isEven ? -0.05 : 0.05) +
                    deal * (1 - deal) * 6;
                return [
                  Positioned(
                    left: pos.dx - cardW / 2,
                    top: pos.dy - cardH / 2,
                    width: cardW,
                    height: cardH,
                    child: Transform.rotate(
                        angle: angle,
                        child: const FittedBox(child: RoleCardBack())),
                  ),
                ];
              }(),
          ]);
        },
      );
    });
  }
}

/// Circular 10-second countdown.
class CountdownRing extends StatelessWidget {
  final int msLeft;
  final int totalMs;
  final double size;
  const CountdownRing(
      {super.key, required this.msLeft, required this.totalMs, this.size = 64});
  @override
  Widget build(BuildContext context) {
    final f = (msLeft / totalMs).clamp(0.0, 1.0);
    final urgent = msLeft <= 3000;
    final color = urgent ? StatusColors.danger : RmcsColors.gold;
    return Semantics(
      label: '${(msLeft / 1000).ceil()} seconds left',
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(fit: StackFit.expand, children: [
          CircularProgressIndicator(
              value: f,
              strokeWidth: 6,
              color: color,
              backgroundColor: Colors.white12),
          Center(
              child: Text('${(msLeft / 1000).ceil()}',
                  style: TextStyle(
                      fontFamily: Fonts.display,
                      color: color,
                      fontSize: size * 0.42))),
        ]),
      ),
    );
  }
}

/// "Chor caught!" or "Chor escaped!" as a success or miss banner.
class ResultBanner extends StatelessWidget {
  final bool caught;
  final bool timedOut;
  const ResultBanner({super.key, required this.caught, required this.timedOut});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: Motion.reduced(context) ? 1 : 0.7, end: 1),
        duration: const Duration(milliseconds: 600),
        curve: Curves.elasticOut,
        builder: (_, s, child) => Transform.scale(scale: s, child: child),
        child: SizedBox(
          width: double.infinity,
          child: TurnBanner(
            text: caught ? 'Chor caught!' : 'Wrong guess: Chor escaped!',
            sub: timedOut
                ? "Time's up! The Mantri didn't choose."
                : (caught ? 'Mantri +500' : 'Chor +500'),
            color: Brand.gold,
            kind: caught ? TurnBannerKind.success : TurnBannerKind.miss,
            icon: caught ? GameIcons.check : GameIcons.cross,
          ),
        ),
      );
}

/// Phase headline with a smooth swap between messages, and an optional [icon] or
/// [trailing] widget (the countdown).
class RmcsHeadline extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final GameIcons? icon;
  const RmcsHeadline(
      {super.key,
      required this.title,
      this.subtitle,
      this.trailing,
      this.icon});
  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Container(
          key: ValueKey(title + (subtitle ?? '')),
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
              color: RmcsColors.panel,
              borderRadius: Radii.rButton,
              border: Border.all(
                  color: RmcsColors.gold.withValues(alpha: 0.45), width: 1.5)),
          child: Semantics(
            liveRegion: true,
            child: Row(children: [
              if (icon != null) ...[
                GameIcon(icon!, size: 30, color: RmcsColors.gold),
                const SizedBox(width: 10)
              ],
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontFamily: Fonts.display,
                              color: Colors.white,
                              fontSize: 20,
                              height: 1.15)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!,
                            style: const TextStyle(
                                fontFamily: Fonts.body,
                                color: NeonPalette.textMuted,
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5)),
                      ],
                    ]),
              ),
              if (trailing != null) ...[const SizedBox(width: 10), trailing!],
            ]),
          ),
        ),
      );
}
