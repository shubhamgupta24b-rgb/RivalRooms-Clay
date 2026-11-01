import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/ui/components.dart';
import '../logic/gp_rules.dart';
import '../logic/guess_person_controller.dart';
import '../models/gp_player.dart';
import 'gp_theme.dart';
import 'person_card.dart';
import 'score_board.dart';

/// Round result: outcome, the revealed secret person, points, and the scoreboard.
class ResultView extends StatelessWidget {
  final RoundResult result;
  final List<GpPlayer> players;
  final bool lastRound;
  final VoidCallback onNext;
  const ResultView(
      {super.key,
      required this.result,
      required this.players,
      required this.lastRound,
      required this.onNext});

  @override
  Widget build(BuildContext context) {
    final (icon, title, sub, color) = switch (result.outcome) {
      RoundOutcome.correct => (
          GameIcons.check,
          'CORRECT!',
          'YOU FOUND THE PERSON!',
          GpColors.yes
        ),
      RoundOutcome.wrong => (
          GameIcons.cross,
          'WRONG GUESS',
          'The correct person was:',
          GpColors.no
        ),
      RoundOutcome.timeUp => (
          GameIcons.lock,
          'TIME UP!',
          'The correct person was:',
          Colors.orangeAccent
        ),
    };
    final found = result.outcome == RoundOutcome.correct;
    final secretCard = SizedBox(
      width: 130,
      height: 165,
      child: PersonCard(
          person: result.secret,
          mark: found ? CardMark.correct : CardMark.wrong),
    );

    return Stack(children: [
      Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: DarkPanel(
              padding: const EdgeInsets.all(20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                GameIcon(icon, size: 40, color: color),
                const SizedBox(height: 4),
                Text(title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: Fonts.display, color: color, fontSize: 34)),
                const SizedBox(height: 6),
                Text(sub,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                found ? _Pop(child: secretCard) : _Shake(child: secretCard),
                if (result.outcome == RoundOutcome.wrong &&
                    result.guessed != null) ...[
                  const SizedBox(height: 8),
                  Text('You guessed ${result.guessed!.name}',
                      style: const TextStyle(color: Colors.white70)),
                ],
                const SizedBox(height: 12),
                Text(
                    result.points == 1
                        ? '+1 POINT'
                        : '+${result.points} POINTS',
                    style: TextStyle(
                        color: found ? GpColors.accent : Colors.white54,
                        fontSize: 24,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 24),
                const Text('ROUND COMPLETE',
                    style: TextStyle(
                        color: GpColors.muted,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5)),
                const SizedBox(height: 6),
                Text(
                    found
                        ? '${result.guesser.name} found the person!'
                        : "${result.guesser.name} didn't find the person.",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                ScoreBoard(players: players),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: GpButton(lastRound ? 'SEE FINAL SCORE' : 'NEXT ROUND',
                      onPressed: onNext,
                      icon: lastRound
                          ? Icons.emoji_events_rounded
                          : Icons.arrow_forward_rounded),
                ),
              ]),
            ),
          ),
        ),
      ),
      if (found) const Positioned.fill(child: IgnorePointer(child: Confetti())),
    ]);
  }
}

class _Pop extends StatelessWidget {
  final Widget child;
  const _Pop({required this.child});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.6, end: 1.0),
        duration: const Duration(milliseconds: 500),
        curve: Curves.elasticOut,
        builder: (_, v, c) => Transform.scale(scale: v, child: c),
        child: child,
      );
}

class _Shake extends StatelessWidget {
  final Widget child;
  const _Shake({required this.child});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 500),
        builder: (_, t, c) => Transform.translate(
            offset: Offset(sin(t * pi * 6) * 12 * (1 - t), 0), child: c),
        child: child,
      );
}

/// Short one-shot confetti burst (~1.6s), no packages.
class Confetti extends StatefulWidget {
  const Confetti({super.key});
  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600))
    ..forward();
  final _rng = Random();
  late final List<_Bit> _bits = List.generate(
    50,
    (_) => _Bit(
      x: _rng.nextDouble(),
      speed: 0.6 + _rng.nextDouble() * 0.7,
      drift: (_rng.nextDouble() - 0.5) * 0.3,
      spin: _rng.nextDouble() * 6,
      color: [
        GpColors.accent,
        GpColors.yes,
        GpColors.no,
        const Color(0xFF4D96FF),
        Colors.white
      ][_rng.nextInt(5)],
    ),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: _c,
      builder: (_, __) =>
          CustomPaint(painter: _ConfettiPainter(_bits, _c.value)));
}

class _Bit {
  final double x, speed, drift, spin;
  final Color color;
  _Bit(
      {required this.x,
      required this.speed,
      required this.drift,
      required this.spin,
      required this.color});
}

class _ConfettiPainter extends CustomPainter {
  final List<_Bit> bits;
  final double t;
  _ConfettiPainter(this.bits, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    if (t >= 1) return;
    final fade = t > 0.75 ? (1 - t) / 0.25 : 1.0;
    for (final b in bits) {
      final y = -0.1 + t * b.speed * 1.2;
      final x = b.x + b.drift * t;
      canvas.save();
      canvas.translate(x * size.width, y * size.height);
      canvas.rotate(b.spin * t * pi);
      canvas.drawRect(const Rect.fromLTWH(-4, -7, 8, 14),
          Paint()..color = b.color.withValues(alpha: fade));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
