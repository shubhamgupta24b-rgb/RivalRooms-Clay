import 'dart:math';
import 'package:flutter/material.dart';
import '../../guess_person/models/gp_player.dart';
import '../../../core/audio/game_audio.dart';
import '../../../core/ui/components.dart';
import '../shell/game_hud.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/local_game_shell.dart' show ResultScope;
import '../party/party_widgets.dart' show GameTopBar;
import '../shell/split_screen.dart';
import '../shell/ticking_play.dart';

enum PotatoPhase { playing, boom }

/// Pass the potato before it blows up. The fuse is hidden (it hisses louder near the end).
/// The holder taps their zone to throw it to someone else at random. Whoever holds it when
/// it explodes gets burnt. After [rounds] explosions, the fewest burns wins: each player's
/// score is the rounds they survived.
class HotPotatoLogic extends LocalGameLogic {
  final int players, rounds;
  final Random _rng;
  final List<int> burns;
  int holder;
  int? passedFrom; // who threw it last, for the view
  int round = 0;
  PotatoPhase phase = PotatoPhase.playing;
  int _now = 0, fuseEnd, roundStart = 0, _boomUntil = 0;
  int passes = 0;
  int get now => _now;
  int? burnt; // who got the last explosion

  HotPotatoLogic({this.players = 2, this.rounds = 5, Random? random})
      : _rng = random ?? Random(),
        burns = List.filled(players, 0),
        holder = 0,
        fuseEnd = 0 {
    holder = _rng.nextInt(players);
    fuseEnd = _fuse(0);
  }

  int _fuse(int from) => from + 5000 + _rng.nextInt(7000);

  /// 0 just lit, 1 about to blow (for the hiss and shake).
  double get heat => phase == PotatoPhase.boom
      ? 1
      : ((_now - roundStart) / max(1, fuseEnd - roundStart)).clamp(0.0, 1.0);

  @override
  bool get finished => round >= rounds;
  @override
  List<int> get scores => [for (final b in burns) round - b];

  @override
  void update(int elapsedMs) {
    _now = elapsedMs;
    if (phase == PotatoPhase.playing && _now >= fuseEnd) {
      burns[holder]++;
      burnt = holder;
      round++;
      phase = PotatoPhase.boom;
      _boomUntil = _now + 1800;
      notifyListeners();
    } else if (phase == PotatoPhase.boom && _now >= _boomUntil && !finished) {
      phase = PotatoPhase.playing;
      passedFrom = null;
      roundStart = _now;
      fuseEnd = _fuse(_now);
      holder = _rng.nextInt(players);
      notifyListeners();
    } else if (phase == PotatoPhase.playing) {
      notifyListeners(); // the fuse burns down
    }
  }

  void pass(int player) {
    if (forward('pass', [player])) return;
    if (finished || phase != PotatoPhase.playing || player != holder) return;
    var to = _rng.nextInt(players - 1);
    if (to >= player) to++;
    passedFrom = player;
    holder = to;
    passes++;
    notifyListeners();
  }
}

final hotPotatoInfo = LocalGameInfo(
  id: 'hot_potato',
  title: 'Hot Potato',
  emoji: '🥔',
  color: const Color(0xFFE0612B),
  tagline: "Pass it on before it blows!",
  rules: const [
    'One player holds the hot potato. Holding it? Tap your zone to throw it to someone else.',
    'The fuse is secret: it hisses louder near the end. Holding it when it blows burns you.',
    'Five explosions. Fewest burns wins. 2 to 6 players.',
  ],
  scoreUnit: 'rounds survived',
  splitScreen: true,
  maxPlayers: 6,
  bot: botFor<HotPotatoLogic>((g, b, now) {
    if (g.finished || g.phase != PotatoPhase.playing || g.holder != b.seat)
      return;
    if (b.thinkFirst(g.passes, now, 250, 1100)) g.pass(b.seat);
  }),
  online: RelaySpec<HotPotatoLogic>(
    create: (n) => HotPotatoLogic(players: n),
    save: (g) => {
      'burns': g.burns,
      'holder': g.holder,
      'from': g.passedFrom,
      'round': g.round,
      'phase': g.phase.index,
      'now': g._now,
      'start': g.roundStart,
      'fuse': g.fuseEnd,
      'passes': g.passes,
      'burnt': g.burnt,
    },
    load: (g, s, me) {
      g.burns.setAll(0, ints(s['burns']));
      g.holder = asInt(s['holder']);
      g.passedFrom = nInt(s['from']);
      g.round = asInt(s['round']);
      g.phase = PotatoPhase.values[asInt(s['phase'])];
      g._now = asInt(s['now']);
      g.roundStart = asInt(s['start']);
      g.fuseEnd = asInt(s['fuse']);
      g.passes = asInt(s['passes']);
      g.burnt = nInt(s['burnt']);
    },
    apply: (g, from, name, a) {
      if (name == 'pass' && asInt(a[0]) == from) g.pass(from);
    },
    // Each phone shows its own zone, with everyone's burns along the top.
    view: (context, g, players, me) => MomentWatcher<int>(
      value: g.round,
      onChange: (fx, _, __) {
        final b = g.burnt;
        if (b == null) return;
        keyMoment(fx, 'BOOM!',
            sub: '${players[b].name} got burnt',
            sound: 'boom',
            buzz: HapticWeight.heavy,
            color: StatusColors.danger,
            shake: true);
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.s, Space.xs, Space.s, Space.s),
        child: Column(children: [
          GameTopBar(
            title: 'Hot Potato',
            subtitle: g.phase == PotatoPhase.boom
                ? 'Boom!'
                : '${players[g.holder].name} has the potato',
          ),
          const SizedBox(height: 6),
          PlayerScoreRow(
            count: players.length,
            card: (i, compact) => PlayerScoreCard(
              seat: PlayerPalette.indexOf(players[i].color) ?? i,
              color: players[i].color,
              name: players[i].name,
              score: '${g.burns[i]}',
              active: g.phase == PotatoPhase.playing && g.holder == i,
              tag: g.phase == PotatoPhase.playing && g.holder == i
                  ? 'HOT!'
                  : null,
              compact: compact,
            ),
          ),
          Expanded(child: _PotatoZone(g: g, player: players[me], index: me)),
        ]),
      ),
    ),
  ),
  play: (players, onFinished) => TickingPlay<HotPotatoLogic>(
    create: () => HotPotatoLogic(players: players.length),
    onFinished: onFinished,
    builder: (context, g) {
      ResultScope.of(context)?.subtitle =
          g.finished ? 'Fewest burns wins' : null;
      final label = 'Round ${min(g.round + 1, g.rounds)} of ${g.rounds}';
      return MomentWatcher<int>(
        value: g.round,
        onChange: (fx, _, __) {
          final b = g.burnt;
          if (b == null) return;
          keyMoment(fx, 'BOOM!',
              sub: '${players[b].name} got burnt',
              sound: 'boom',
              buzz: HapticWeight.heavy,
              color: StatusColors.danger,
              shake: true);
        },
        child: PlayerZones(
          count: players.length,
          colors: [for (final p in players) p.color],
          middle:
              ScoreMiddleBar(players: players, scores: g.scores, label: label),
          center: ZoneCenterChip(label),
          zone: (i) => _PotatoZone(g: g, player: players[i], index: i),
        ),
      );
    },
  ),
);

class _PotatoZone extends StatelessWidget {
  final HotPotatoLogic g;
  final GpPlayer player;
  final int index;
  const _PotatoZone(
      {required this.g, required this.player, required this.index});

  @override
  Widget build(BuildContext context) {
    final holding = g.holder == index && g.phase == PotatoPhase.playing;
    final boom = g.phase == PotatoPhase.boom && g.burnt == index;
    final (String big, String small) = boom
        ? ('BOOM!', 'You got burnt')
        : g.phase == PotatoPhase.boom
            ? ('Phew!', 'Safe this round')
            : holding
                ? ('PASS IT!', 'Tap to throw')
                : ('Safe', g.passedFrom == index ? 'Thrown!' : 'Watch out...');
    final bg = boom
        ? const Color(0xFF4A1410)
        : (holding
            ? Color.lerp(
                const Color(0xFF3A2410), const Color(0xFF6A1E10), g.heat)!
            : const Color(0xFF22202C));
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {
        if (!holding) return;
        g.pass(index);
        GameAudio.sfx('throw');
        haptic(HapticWeight.medium);
      },
      child: Semantics(
        button: holding,
        label: '${player.name}: $big $small. Burns ${g.burns[index]}',
        excludeSemantics: true,
        child: Container(
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: bg,
              borderRadius: Radii.rLg,
              border: Border.all(color: player.color, width: holding ? 5 : 3)),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    PlayerBadge(
                        index: PlayerPalette.indexOf(player.color) ?? index,
                        size: 22,
                        color: player.color,
                        initial: player.name),
                    const SizedBox(width: 6),
                    Text('${player.name}  burns ${g.burns[index]}',
                        style: const TextStyle(
                            fontFamily: Fonts.body,
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 15)),
                  ]),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 120,
                    height: 100,
                    child: holding || boom
                        ? CustomPaint(
                            painter: _PotatoPainter(g.heat, boom, g.now))
                        : null,
                  ),
                  Text(big,
                      style: TextStyle(
                          fontFamily: Fonts.display,
                          color: boom
                              ? StatusColors.danger
                              : (holding ? Brand.gold : Colors.white),
                          fontSize: 44,
                          height: 1.05)),
                  Text(small,
                      style: const TextStyle(
                          fontFamily: Fonts.body,
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A lumpy potato with a lit fuse that shakes harder as it heats up, or a burst when it blows.
class _PotatoPainter extends CustomPainter {
  final double heat;
  final bool boom;
  final int clock;
  _PotatoPainter(this.heat, this.boom, this.clock);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    if (boom) {
      for (var k = 0; k < 12; k++) {
        final a = k * pi / 6;
        final path = Path()
          ..moveTo(c.dx, c.dy)
          ..lineTo(c.dx + cos(a - 0.15) * 30, c.dy + sin(a - 0.15) * 30)
          ..lineTo(c.dx + cos(a) * (k.isEven ? 52 : 40),
              c.dy + sin(a) * (k.isEven ? 52 : 40))
          ..lineTo(c.dx + cos(a + 0.15) * 30, c.dy + sin(a + 0.15) * 30)
          ..close();
        canvas.drawPath(
            path,
            Paint()
              ..color =
                  k.isEven ? const Color(0xFFFFB020) : const Color(0xFFE5484D));
      }
      canvas.drawCircle(c, 20, Paint()..color = const Color(0xFFFFE08A));
      return;
    }
    final shake = heat * heat * 5;
    final t = clock / 40.0;
    final at = c +
        Offset(sin(t * 1.3) * shake, cos(t * 1.7) * shake) +
        const Offset(0, 8);
    final body = Path()
      ..addOval(Rect.fromCenter(center: at, width: 86, height: 62));
    canvas.drawOval(
        Rect.fromCenter(
            center: at + const Offset(0, 30), width: 70, height: 12),
        Paint()..color = Colors.black38);
    canvas.drawPath(
        body,
        Paint()
          ..shader =
              RadialGradient(center: const Alignment(-0.3, -0.4), colors: [
            Color.lerp(
                const Color(0xFFE2B66E), const Color(0xFFFF6A3D), heat * 0.6)!,
            const Color(0xFFB07A3A),
            const Color(0xFF7A4E22)
          ]).createShader(Rect.fromCenter(center: at, width: 86, height: 62)));
    for (final (dx, dy) in const [
      (-20.0, -8.0),
      (12.0, 10.0),
      (24.0, -12.0),
      (-6.0, 14.0)
    ]) {
      canvas.drawCircle(
          at + Offset(dx, dy), 3, Paint()..color = const Color(0xFF6A421C));
    }
    // Fuse and spark.
    final fuseTop = at + const Offset(18, -44);
    canvas.drawPath(
        Path()
          ..moveTo(at.dx + 10, at.dy - 28)
          ..quadraticBezierTo(at.dx + 24, at.dy - 38, fuseTop.dx, fuseTop.dy),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = const Color(0xFF3A3A3A));
    final spark = 6 + 4 * sin(t * 3).abs() + heat * 4;
    canvas.drawCircle(
        fuseTop, spark * 1.8, Paint()..color = const Color(0x66FFB020));
    canvas.drawCircle(fuseTop, spark, Paint()..color = const Color(0xFFFFD34D));
  }

  @override
  bool shouldRepaint(_PotatoPainter o) => true;
}
