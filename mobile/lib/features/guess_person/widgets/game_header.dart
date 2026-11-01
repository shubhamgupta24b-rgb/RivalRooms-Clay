import 'package:flutter/material.dart';
import 'gp_theme.dart';

/// "ROUND 2 / 5" + current player and role, with an optional trailing widget (timer).
class GameHeader extends StatelessWidget {
  final int round;
  final int totalRounds;
  final String playerName;
  final Color playerColor;
  final String role;
  final Widget? trailing;
  final VoidCallback? onClose;
  const GameHeader({
    super.key,
    required this.round,
    required this.totalRounds,
    required this.playerName,
    required this.playerColor,
    required this.role,
    this.trailing,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      if (onClose != null)
        IconButton(
          tooltip: 'Leave game',
          onPressed: onClose,
          icon: const Icon(Icons.close_rounded, color: Colors.white70),
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        ),
      Expanded(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('ROUND $round / $totalRounds',
                  style: const TextStyle(
                      color: GpColors.muted,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      fontSize: 13)),
              const SizedBox(height: 4),
              PlayerTag(name: playerName, color: playerColor, role: role),
            ]),
      ),
      if (trailing != null) trailing!,
    ]);
  }
}

/// Countdown badge: calm above 10s, orange at 10s, red + pulsing at 5s and below.
class TimerBadge extends StatelessWidget {
  final int seconds;
  const TimerBadge(this.seconds, {super.key});

  @override
  Widget build(BuildContext context) {
    final urgent = seconds <= 5;
    final warn = seconds <= 10;
    final color =
        urgent ? GpColors.no : (warn ? Colors.orangeAccent : Colors.white);
    return Semantics(
      label: '$seconds seconds left',
      child: TweenAnimationBuilder<double>(
        key: ValueKey(urgent
            ? seconds
            : -1), // restart pulse each second only when urgent
        tween: Tween(begin: urgent ? 1.25 : 1.0, end: 1.0),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
        builder: (_, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: warn ? 0.22 : 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color, width: 2),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('TIME',
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.w800)),
            Text('$seconds',
                style: TextStyle(
                    color: color,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    height: 1.1)),
          ]),
        ),
      ),
    );
  }
}
