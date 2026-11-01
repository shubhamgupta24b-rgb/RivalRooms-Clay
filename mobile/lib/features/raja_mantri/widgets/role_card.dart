import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/ui/components.dart';
import '../../../core/ui/materials/materials.dart';
import '../rmcs_role.dart';

/// Every card is designed at this size and scaled to fit with a FittedBox.
const _cardW = 200.0, _cardH = 290.0;
const rmcsCardAspect = _cardW / _cardH;

/// A playing card that flips in 3D between its back and [role]'s face.
/// With [role] null the card can only show its back.
class RoleCard extends StatelessWidget {
  final RmcsRole? role;
  final bool faceUp;
  final bool highlight;
  final Color? highlightColor;
  final Duration duration;
  const RoleCard(
      {super.key,
      required this.role,
      required this.faceUp,
      this.highlight = false,
      this.highlightColor,
      this.duration = const Duration(milliseconds: 650)});

  @override
  Widget build(BuildContext context) {
    final up = faceUp && role != null;
    return AspectRatio(
      aspectRatio: rmcsCardAspect,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: up ? 1 : 0),
        duration: duration,
        curve: Curves.easeInOutCubic,
        builder: (context, v, _) {
          final front = v > 0.5;
          // Lift the card a little mid-flip so it feels physical.
          final lift = 1 + 0.08 * sin(v * pi);
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0015)
              ..rotateY(v * pi)
              ..scaleByDouble(lift, lift, 1, 1),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.rotationY(front ? pi : 0),
              child: _Frame(
                highlight: highlight,
                highlightColor: highlightColor ??
                    (front && role != null
                        ? role!.glow
                        : const Color(0xFFFFD34D)),
                child: FittedBox(
                    child: front && role != null
                        ? RoleCardFace(role: role!)
                        : const RoleCardBack()),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Frame extends StatelessWidget {
  final Widget child;
  final bool highlight;
  final Color highlightColor;
  const _Frame(
      {required this.child,
      required this.highlight,
      required this.highlightColor});
  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            const BoxShadow(
                color: Colors.black54, blurRadius: 10, offset: Offset(0, 6)),
            if (highlight)
              BoxShadow(
                  color: highlightColor.withValues(alpha: 0.85),
                  blurRadius: 22,
                  spreadRadius: 3),
          ],
        ),
        child: child,
      );
}

/// The drawn emblem of each role (no emoji): crown, scroll, shield, mask.
GameIcons roleIcon(RmcsRole r) => switch (r) {
      RmcsRole.raja => GameIcons.crown,
      RmcsRole.mantri => GameIcons.scroll,
      RmcsRole.sipahi => GameIcons.shield,
      RmcsRole.chor => GameIcons.mask,
    };

/// The role's ink on paper (the darkest of its colours, readable on cream).
Color roleInk(RmcsRole r) => switch (r) {
      RmcsRole.raja => const Color(0xFF8A5A00),
      RmcsRole.mantri => const Color(0xFF1A3F9A),
      RmcsRole.sipahi => const Color(0xFF2E4258),
      RmcsRole.chor => const Color(0xFF4B2A6E),
    };

/// Face-down card: the shared card back (indigo, gold lattice and medallion).
class RoleCardBack extends StatelessWidget {
  const RoleCardBack({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox(
      width: _cardW, height: _cardH, child: CardBack(radius: 18));
}

/// Face-up card for [role]: a paper card with the role's colour band, a big drawn emblem,
/// the title in Lilita, what the role does and what it scores, and corner indices.
class RoleCardFace extends StatelessWidget {
  final RmcsRole role;
  const RoleCardFace({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final ink = roleInk(role);
    final band = role.gradient[1];
    Widget corner() => Column(mainAxisSize: MainAxisSize.min, children: [
          Text(role.letter,
              style: TextStyle(
                  fontFamily: Fonts.display,
                  color: ink,
                  fontSize: 26,
                  height: 1)),
          GameIcon(roleIcon(role), size: 18, color: band),
        ]);
    return SizedBox(
      width: _cardW,
      height: _cardH,
      child: PaperCard(
        radius: 18,
        tint: band,
        child: Stack(children: [
          Positioned(left: 12, top: 10, child: corner()),
          Positioned(
              right: 12,
              bottom: 10,
              child: RotatedBox(quarterTurns: 2, child: corner())),
          Positioned.fill(
            top: 26,
            bottom: 34,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: _cardW,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 120,
                    height: 120,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        role.glow.withValues(alpha: 0.55),
                        role.glow.withValues(alpha: 0)
                      ]),
                    ),
                    child: GameIcon(roleIcon(role), size: 92, color: band),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    decoration: BoxDecoration(
                        color: band, borderRadius: BorderRadius.circular(10)),
                    child: Text(role.title,
                        style: TextStyle(
                            fontFamily: Fonts.display,
                            color: onColor(band),
                            fontSize: 30,
                            letterSpacing: 2,
                            height: 1.15)),
                  ),
                  const SizedBox(height: 8),
                  Text(role.subtitle,
                      style: TextStyle(
                          fontFamily: Fonts.body,
                          color: ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.2)),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Text(role.pointsLine,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontFamily: Fonts.body,
                            color: ink.withValues(alpha: 0.85),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6)),
                  ),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
