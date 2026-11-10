import 'dart:math';
import '../../../core/text/agreement.dart';
import 'package:flutter/material.dart';
import '../../guess_person/models/gp_player.dart';
import '../../../core/audio/game_audio.dart';
import '../../../core/ui/components.dart';
import '../shell/game_hud.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/local_game_shell.dart' show PauseButton, ResultScope;
import '../shell/ticking_play.dart';

/// Two players tap as fast as they can to drag the knot over their line. [rope] runs from
/// -1 (player 2's line) to 1 (player 1's line). If time runs out, whoever has the knot on
/// their side wins; dead centre is a draw.
class TugOfWarLogic extends TimedDuel {
  static const step = 0.032; // how far one tap pulls
  double rope = 0;
  final List<int> pulls = [0, 0];
  final List<int> lastPullMs = [-1000, -1000];
  int? winner;

  TugOfWarLogic({int durationMs = 30000}) : super(durationMs);

  @override
  bool get finished => winner != null || super.finished;

  @override
  List<int> get scores {
    final w = winner ?? (rope > 0.02 ? 0 : (rope < -0.02 ? 1 : null));
    return [for (var p = 0; p < 2; p++) w == p ? 1 : 0];
  }

  void pull(int player) {
    if (forward('pull', [player])) return;
    if (finished || elapsedMs - lastPullMs[player] < 90) return;
    rope = (rope + (player == 0 ? step : -step)).clamp(-1.0, 1.0);
    pulls[player]++;
    lastPullMs[player] = elapsedMs;
    if (rope >= 1) winner = 0;
    if (rope <= -1) winner = 1;
    notifyListeners();
  }
}

final tugOfWarInfo = LocalGameInfo(
  id: 'tug_of_war',
  title: 'Tug of War',
  emoji: '🪢',
  color: const Color(0xFFD9822B),
  tagline: 'Tap like crazy, pull the knot home!',
  rules: const [
    'Sit at opposite ends. Tap anywhere on your half as fast as you can.',
    'Every tap pulls the knot toward you. Drag it over your line to win.',
    'After 30 seconds, whoever has the knot on their side wins.',
  ],
  scoreUnit: 'wins',
  splitScreen: true,
  bot: botFor<TugOfWarLogic>((g, b, now) {
    if (g.finished || !b.due(now)) return;
    g.pull(b.seat);
    b.wait(now, 115, 175); // about 7 taps a second: beatable, not easy
  }),
  online: RelaySpec<TugOfWarLogic>(
    create: (n) => TugOfWarLogic(),
    save: (g) => {
      't': g.elapsedMs,
      'rope': g.rope,
      'pulls': g.pulls,
      'last': g.lastPullMs,
      'win': g.winner
    },
    load: (g, s, me) {
      g.elapsedMs = asInt(s['t']);
      g.rope = asDouble(s['rope']);
      g.pulls.setAll(0, ints(s['pulls']));
      g.lastPullMs.setAll(0, ints(s['last']));
      g.winner = nInt(s['win']);
    },
    apply: (g, from, name, a) {
      if (name == 'pull' && asInt(a[0]) == from) g.pull(from);
    },
    // Player 2 sees the field turned round, so their side is at the bottom.
    view: (context, g, players, me) => RotatedBox(
        quarterTurns: me == 1 ? 2 : 0,
        child: _TugField(g: g, players: players)),
  ),
  play: (players, onFinished) => TickingPlay<TugOfWarLogic>(
    create: () => TugOfWarLogic(),
    onFinished: onFinished,
    builder: (context, g) => _TugField(g: g, players: players),
  ),
);

class _TugField extends StatelessWidget {
  final TugOfWarLogic g;
  final List<GpPlayer> players;
  const _TugField({required this.g, required this.players});

  @override
  Widget build(BuildContext context) {
    ResultScope.of(context)?.subtitle = g.winner != null
        ? 'Pulled over the line'
        : (g.finished ? 'Time up' : null);
    return MomentWatcher<bool>(
      value: g.finished,
      onChange: (fx, _, done) {
        if (!done) return;
        final s = g.scores;
        if (s.contains(1)) {
          keyMoment(fx, g.winner != null ? 'PULLED OVER!' : 'TIME UP!',
              sub: winsPhrase(players[s.indexOf(1)].name),
              sound: 'win',
              confetti: true);
        } else {
          keyMoment(fx, 'DRAW!', sub: 'Dead level', color: Colors.white);
        }
      },
      child: Stack(children: [
        Positioned.fill(
            child: RepaintBoundary(
                child: CustomPaint(
                    painter: _RopePainter(g.rope, players[0].color,
                        players[1].color, g.lastPullMs, g.elapsedMs)))),
        Column(children: [
          Expanded(
              child: RotatedBox(
                  quarterTurns: 2,
                  child: _PullPad(g: g, players: players, index: 1))),
          _Middle(g: g),
          Expanded(child: _PullPad(g: g, players: players, index: 0)),
        ]),
      ]),
    );
  }
}

class _Middle extends StatelessWidget {
  final TugOfWarLogic g;
  const _Middle({required this.g});
  @override
  Widget build(BuildContext context) {
    final urgent = g.secondsLeft <= 5;
    return Container(
      height: 48,
      color: NeonPalette.bgBottom.withValues(alpha: 0.85),
      padding: const EdgeInsets.symmetric(horizontal: Space.m),
      child: Row(children: [
        const PauseButton(),
        const Spacer(),
        Semantics(
          label: '${g.secondsLeft} seconds left',
          excludeSemantics: true,
          child: Text('${g.secondsLeft}s',
              style: TextStyle(
                  fontFamily: Fonts.display,
                  fontSize: 24,
                  color: urgent ? StatusColors.danger : Colors.white,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ),
        const Spacer(),
        const SizedBox(width: kTouchTarget),
      ]),
    );
  }
}

/// A player's half: the whole area is their button.
class _PullPad extends StatelessWidget {
  final TugOfWarLogic g;
  final List<GpPlayer> players;
  final int index;
  const _PullPad({required this.g, required this.players, required this.index});

  @override
  Widget build(BuildContext context) {
    final p = players[index];
    final share = index == 0 ? g.rope : -g.rope; // >0: the knot is on my side
    final status = share > 0.6
        ? 'Almost there!'
        : (share > 0.05
            ? 'Winning'
            : (share < -0.6
                ? 'Hold on!'
                : (share < -0.05 ? 'Pull harder!' : 'Level')));
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {
        if (g.finished) return;
        g.pull(index);
        haptic(HapticWeight.light);
        if (g.pulls[index] % 6 == 0) GameAudio.sfx('tap');
      },
      child: Semantics(
        button: true,
        label: '${p.name}: tap to pull. $status',
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.all(Space.m),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  PlayerBadge(
                      index: PlayerPalette.indexOf(p.color) ?? index,
                      size: 22,
                      color: p.color,
                      initial: p.name),
                  const SizedBox(width: 8),
                  Text(p.name,
                      style: const TextStyle(
                          fontFamily: Fonts.body,
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16)),
                ]),
                const SizedBox(height: 4),
                Text('TAP TO PULL',
                    style: TextStyle(
                        fontFamily: Fonts.display,
                        fontSize: 30,
                        color: Color.lerp(p.color, Colors.white, 0.35))),
                Text(status,
                    style: const TextStyle(
                        fontFamily: Fonts.body,
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// The field: grass, each player's line, the rope down the middle and the knot with its flag.
/// The pullers at each end lean back for a moment after every tap.
class _RopePainter extends CustomPainter {
  final double rope;
  final Color c0, c1;
  final List<int> lastPull;
  final int now;
  _RopePainter(this.rope, this.c0, this.c1, this.lastPull, this.now);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, mid = h / 2;
    final reach = h * 0.3; // knot travel from the centre to a line
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF2E6B3A),
                Color(0xFF3E8A4A),
                Color(0xFF2E6B3A)
              ]).createShader(Offset.zero & size));
    // Mown stripes.
    for (var k = 0; k < 10; k++) {
      if (k.isOdd)
        canvas.drawRect(Rect.fromLTWH(0, h * k / 10, w, h / 10),
            Paint()..color = Colors.white.withValues(alpha: 0.04));
    }
    // Each player's line, in their colour.
    for (final (y, c) in [(mid + reach, c0), (mid - reach, c1)]) {
      canvas.drawRect(Rect.fromLTWH(0, y - 3, w, 6), Paint()..color = c);
      canvas.drawRect(
          Rect.fromLTWH(0, y - 3, w, 6),
          Paint()
            ..style = PaintingStyle.stroke
            ..color = Colors.white.withValues(alpha: 0.6));
    }
    canvas.drawLine(
        Offset(0, mid),
        Offset(w, mid),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.35)
          ..strokeWidth = 2);
    final knotY = mid + rope * reach;
    final x = w / 2;
    // The rope: a twisted cord from end to end.
    final cord = Paint()
      ..color = const Color(0xFFC9A26B)
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(x, 0), Offset(x, h), cord);
    final twist = Paint()
      ..color = const Color(0xFF8E6A3A)
      ..strokeWidth = 2.5;
    final phase = (rope * reach) % 12;
    for (var y = -12.0 + phase; y < h; y += 12) {
      canvas.drawLine(Offset(x - 5, y), Offset(x + 5, y + 6), twist);
    }
    // The pullers.
    void puller(double y, Color c, int who, bool top) {
      final lean = (1 - ((now - lastPull[who]) / 160).clamp(0.0, 1.0)) * 8;
      final cy = y + (top ? -lean : lean);
      canvas.drawOval(
          Rect.fromCenter(center: Offset(x + 3, cy + 4), width: 54, height: 40),
          Paint()..color = Colors.black26);
      canvas.drawCircle(
          Offset(x, cy),
          22,
          Paint()
            ..shader = RadialGradient(
                center: const Alignment(-0.3, -0.4),
                colors: [
                  Color.lerp(c, Colors.white, 0.4)!,
                  c,
                  Color.lerp(c, Colors.black, 0.3)!
                ]).createShader(
                Rect.fromCircle(center: Offset(x, cy), radius: 22)));
      for (final dx in [-9.0, 9.0]) {
        canvas.drawCircle(Offset(x + dx, cy + (top ? 14 : -14)), 6,
            Paint()..color = Color.lerp(c, Colors.white, 0.55)!);
      }
    }

    puller(h - 40, c0, 0, false);
    puller(40, c1, 1, true);
    // The knot and its flag, coloured toward whoever is winning.
    final flag = rope > 0.02 ? c0 : (rope < -0.02 ? c1 : Colors.white);
    canvas.drawCircle(
        Offset(x, knotY), 13, Paint()..color = const Color(0xFF7A5428));
    canvas.drawCircle(
        Offset(x, knotY),
        13,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0xFFE8C48A));
    final path = Path()
      ..moveTo(x + 10, knotY - 4)
      ..lineTo(x + 46, knotY - 14)
      ..lineTo(x + 46, knotY + 10)
      ..close();
    canvas.drawPath(path, Paint()..color = flag);
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.black38);
    // Progress glow under the knot when it's close to a line.
    if (rope.abs() > 0.6) {
      canvas.drawCircle(
          Offset(x, knotY),
          30,
          Paint()
            ..color = flag.withValues(
                alpha: 0.25 * min(1, (rope.abs() - 0.6) / 0.4)));
    }
  }

  @override
  bool shouldRepaint(_RopePainter o) =>
      o.rope != rope || o.now != now || o.c0 != c0 || o.c1 != c1;
}
