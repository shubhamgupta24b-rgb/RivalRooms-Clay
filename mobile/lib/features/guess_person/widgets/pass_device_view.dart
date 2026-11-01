import 'package:flutter/material.dart';
import '../../../core/ui/components.dart';
import '../models/gp_player.dart';
import 'gp_theme.dart';

/// Privacy screen between players (spec 2.14 hand-off): who gets the phone, their badge,
/// and nothing about the secret person.
class PassDeviceView extends StatelessWidget {
  final String title;
  final GpPlayer to;
  final String message;
  final String buttonLabel;
  final VoidCallback onReady;
  final IconData
      icon; // kept for callers; the hand-off shows the player's badge
  const PassDeviceView({
    super.key,
    required this.title,
    required this.to,
    required this.onReady,
    this.message = "Don't let the other player see your selection.",
    this.buttonLabel = "I'M READY",
    this.icon = Icons.lock_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(stripEmoji(title),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: Fonts.body,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.8,
                    color: Brand.gold)),
            const SizedBox(height: 14),
            Container(
              width: 132,
              height: 132,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    to.color.withValues(alpha: 0.35),
                    to.color.withValues(alpha: 0)
                  ])),
              child: PlayerBadge(
                  index: PlayerPalette.indexOf(to.color) ?? 0,
                  size: 88,
                  color: to.color,
                  initial: to.name),
            ),
            const SizedBox(height: 8),
            const Text('PASS THE PHONE TO',
                style: TextStyle(
                    fontFamily: Fonts.body,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.76,
                    color: NeonPalette.label)),
            const SizedBox(height: 2),
            Semantics(
                liveRegion: true,
                child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(to.name,
                        style: TextStyle(
                            fontFamily: Fonts.display,
                            fontSize: 38,
                            color: nameColor(to.color))))),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: Fonts.body,
                    color: NeonPalette.textMuted,
                    fontWeight: FontWeight.w800,
                    fontSize: 15)),
            const SizedBox(height: 28),
            SizedBox(
                width: double.infinity,
                child: GpButton(buttonLabel, onPressed: onReady)),
          ]),
        ),
      ),
    );
  }
}
