import 'dart:math' show max;
import 'package:flutter/material.dart';
import '../../../core/ui/components.dart';
import '../../guess_person/models/gp_player.dart';
import '../shell/game_hud.dart' show MomentWatcher, keyMoment;
import '../shell/local_game_shell.dart' show PauseButton;
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/split_screen.dart';
import '../shell/ticking_play.dart';

class Ball {
  final int bat, bowl;
  const Ball(this.bat, this.bowl);
  bool get out => bat == bowl;
}

/// Hand cricket (odd-even style): both players secretly show 1-6. The batter scores
/// their number unless the numbers match: OUT! One wicket each, [maxBalls] balls per
/// innings. Player 1 bats first; player 2 chases.
class HandCricketLogic extends LocalGameLogic {
  static const maxBalls = 24;
  final int showMs;
  final List<int> runs = [0, 0];
  final List<int?> picks = [null, null];
  final List<List<Ball>> balls = [[], []];
  int innings = 0;
  int _now = 0;
  int? _nextAt;
  bool over = false;

  HandCricketLogic({this.showMs = 1300});

  int get batter => innings;
  int get bowler => 1 - innings;
  bool get showingBall => _nextAt != null;
  Ball? get lastBall => balls[innings].isEmpty ? null : balls[innings].last;
  int? get target => innings == 1 ? runs[0] + 1 : null;

  @override
  bool get finished => over && !showingBall;
  @override
  List<int> get scores => runs;

  @override
  void update(int elapsedMs) {
    _now = elapsedMs;
    final next = _nextAt;
    if (next != null && _now >= next) {
      _nextAt = null;
      picks[0] = picks[1] = null;
      final b = balls[innings];
      final inningsOver = b.isNotEmpty && (b.last.out || b.length >= maxBalls);
      if (innings == 1 && (runs[1] > runs[0] || inningsOver)) {
        over = true;
      } else if (inningsOver) {
        innings = 1;
      }
      notifyListeners();
    }
  }

  void pick(int player, int n) {
    if (forward('pick', [player, n])) return;
    if (over || showingBall || n < 1 || n > 6 || picks[player] != null) return;
    picks[player] = n;
    if (picks[0] != null && picks[1] != null) {
      final ball = Ball(picks[batter]!, picks[bowler]!);
      balls[innings].add(ball);
      if (!ball.out) runs[batter] += ball.bat;
      _nextAt = _now + showMs;
    }
    notifyListeners();
  }
}

final handCricketInfo = LocalGameInfo(
  id: 'hand_cricket',
  title: 'Hand Cricket',
  emoji: '🏏',
  color: const Color(0xFF16A085),
  tagline: 'Same number? You\'re OUT!',
  rules: const [
    'Player 1 bats first. Both secretly pick a number from 1 to 6 on their own side.',
    'Different numbers: the batter scores their number. Same number: OUT!',
    'Then swap: player 2 chases the target. One wicket and 24 balls each. Most runs wins!',
  ],
  scoreUnit: 'runs',
  splitScreen: true,
  bot: botFor<HandCricketLogic>((g, b, now) {
    if (g.over || g.showingBall || g.picks[b.seat] != null) return;
    if (b.thinkFirst((g.innings, g.balls[g.innings].length), now, 600, 1400))
      g.pick(b.seat, 1 + b.rng.nextInt(6));
  }),
  online: RelaySpec<HandCricketLogic>(
    create: (n) => HandCricketLogic(),
    save: (g) => {
      'runs': g.runs,
      'locked': [for (final p in g.picks) p != null],
      'balls': [
        for (final inn in g.balls) [for (final b in inn) b.bat * 10 + b.bowl]
      ],
      'innings': g.innings,
      'showing': g.showingBall,
      'over': g.over,
    },
    load: (g, s, me) {
      g.runs.setAll(0, ints(s['runs']));
      final locked = (s['locked'] as List).cast<bool>();
      for (var i = 0; i < 2; i++) {
        g.picks[i] = locked[i]
            ? (g.picks[i] ?? 1)
            : null; // the number itself stays secret
      }
      final balls = s['balls'] as List;
      for (var i = 0; i < 2; i++) {
        g.balls[i]
          ..clear()
          ..addAll([for (final v in ints(balls[i])) Ball(v ~/ 10, v % 10)]);
      }
      g.innings = asInt(s['innings']);
      g._nextAt = s['showing'] == true ? 1 << 40 : null;
      g.over = s['over'] == true;
    },
    apply: (g, from, name, a) {
      if (name == 'pick' && asInt(a[0]) == from) g.pick(from, asInt(a[1]));
    },
    view: (context, g, players, me) => Column(children: [
      _Scoreboard(players: players, g: g),
      Expanded(
          child: _CricketHalf(
              player: players[me], index: me, g: g, players: players)),
    ]),
  ),
  play: (players, onFinished) => TickingPlay<HandCricketLogic>(
    create: () => HandCricketLogic(),
    onFinished: onFinished,
    builder: (context, g) => MomentWatcher<(int, int)>(
      value: (g.balls[0].length + g.balls[1].length, g.innings),
      onChange: (fx, before, now) {
        if (now.$2 > before.$2)
          keyMoment(fx, 'INNINGS 2',
              sub: '${players[1].name} needs ${g.target}',
              sound: 'pop',
              color: Colors.white);
        final b = g.lastBall;
        if (now.$1 > before.$1 && b != null) {
          if (b.out) {
            keyMoment(fx, 'OUT!',
                sub: '${players[g.bowler].name} takes the wicket',
                sound: 'boom',
                buzz: HapticWeight.heavy,
                color: const Color(0xFFFF5E5B),
                shake: true);
          } else if (b.bat == 6) {
            fx?.pop('SIX!');
          } else if (b.bat == 4) {
            fx?.pop('FOUR!');
          }
        }
      },
      child: SplitScreen(
        colors: [for (final p in players) p.color],
        middle: _Scoreboard(players: players, g: g),
        half: (i) =>
            _CricketHalf(player: players[i], index: i, g: g, players: players),
      ),
    ),
  ),
);

/// The stadium scoreboard (spec 5.2 #23): LED-style digits for both scores, the ball and
/// the target, with the pause button. Player 2's side reads upside down for them.
class _Scoreboard extends StatelessWidget {
  final List<GpPlayer> players;
  final HandCricketLogic g;
  const _Scoreboard({required this.players, required this.g});

  Widget _led(String text,
          {double size = 26, Color color = const Color(0xFFFFC93C)}) =>
      Text(
        text,
        style: TextStyle(
            fontFamily: Fonts.display,
            fontSize: size,
            height: 1,
            color: color,
            fontFeatures: const [
              FontFeature.tabularFigures()
            ],
            shadows: [
              Shadow(color: color.withValues(alpha: 0.8), blurRadius: 10)
            ]),
      );

  Widget _side(int i) => Row(mainAxisSize: MainAxisSize.min, children: [
        PlayerBadge(
            index: PlayerPalette.indexOf(players[i].color) ?? i,
            size: 18,
            color: players[i].color),
        const SizedBox(width: 6),
        _led('${g.runs[i]}',
            color: i == g.batter
                ? const Color(0xFFFFC93C)
                : const Color(0xFFFFE7A0)),
      ]);

  @override
  Widget build(BuildContext context) {
    final ball = g.balls[g.innings].length + (g.showingBall ? 0 : 1);
    return Semantics(
      label:
          '${players[0].name} ${g.runs[0]}, ${players[1].name} ${g.runs[1]}. Innings ${g.innings + 1}, ball $ball${g.target != null ? ', target ${g.target}' : ''}',
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0C14),
          border: Border.symmetric(
              horizontal: BorderSide(
                  color: Colors.white.withValues(alpha: 0.2), width: 2)),
          boxShadow: const [
            BoxShadow(color: Color(0x80000000), blurRadius: 12)
          ],
        ),
        child: Row(children: [
          RotatedBox(quarterTurns: 2, child: _side(1)),
          Expanded(
            child: ExcludeSemantics(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(g.innings == 0 ? 'INNINGS 1' : 'TARGET ${g.target}',
                        style: const TextStyle(
                            fontFamily: Fonts.body,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.6,
                            color: Color(0xFF9FD8FF))),
                    const SizedBox(height: 2),
                    _led('BALL $ball',
                        size: 16, color: const Color(0xFF7CF0A8)),
                  ]),
            ),
          ),
          const PauseButton(),
          const SizedBox(width: 4),
          _side(0),
        ]),
      ),
    );
  }
}

/// A hand showing [n] fingers (6 is a thumbs-up), in the player's colour.
class _HandPainter extends CustomPainter {
  final int n;
  final Color color;
  _HandPainter(this.n, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final skin = Paint()..color = color;
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.05
      ..color = Colors.white;
    final palm = RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.2, h * 0.45, w * 0.6, h * 0.48),
        Radius.circular(w * 0.18));
    final fingers = <RRect>[];
    final fw = w * 0.13;
    if (n == 6) {
      // Thumbs up: a fist with the thumb raised.
      fingers.add(RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.2, h * 0.12, fw * 1.1, h * 0.42),
          Radius.circular(fw)));
    } else {
      final up = n.clamp(0, 5);
      for (var k = 0; k < 4; k++) {
        final x = w * 0.22 + k * (w * 0.56 / 4) + (w * 0.56 / 4 - fw) / 2;
        final raised = k < up || (up == 5);
        fingers.add(RRect.fromRectAndRadius(
            Rect.fromLTWH(x, raised ? h * 0.08 : h * 0.36, fw,
                raised ? h * 0.45 : h * 0.16),
            Radius.circular(fw / 2)));
      }
      if (up == 5)
        fingers.add(RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.04, h * 0.42, w * 0.26, fw),
            Radius.circular(fw / 2)));
    }
    for (final f in fingers) {
      canvas.drawRRect(f, skin);
      canvas.drawRRect(f, edge);
    }
    canvas.drawRRect(palm, skin);
    canvas.drawRRect(palm, edge);
  }

  @override
  bool shouldRepaint(_HandPainter o) => o.n != n || o.color != color;
}

class _CricketHalf extends StatelessWidget {
  final GpPlayer player;
  final int index;
  final HandCricketLogic g;
  final List<GpPlayer> players;
  const _CricketHalf(
      {required this.player,
      required this.index,
      required this.g,
      required this.players});

  @override
  Widget build(BuildContext context) {
    final batting = g.batter == index;
    final ball = g.lastBall;
    final picked = g.picks[index] != null;
    final seat = PlayerPalette.indexOf(player.color) ?? index;
    final String title, sub;
    var stamp = false;
    if (g.showingBall && ball != null) {
      stamp = ball.out;
      title = ball.out
          ? (batting ? 'OUT!' : 'WICKET!')
          : (batting ? '+${ball.bat} runs' : '${ball.bat} runs scored');
      sub = 'Bat ${ball.bat} · Ball ${ball.bowl}';
    } else if (g.over) {
      title = g.runs[0] == g.runs[1]
          ? 'Tie!'
          : (g.runs[index] > g.runs[1 - index] ? 'You win!' : 'You lose');
      sub = '${g.runs[index]} runs';
    } else if (picked) {
      title = 'Locked in';
      sub = 'Waiting for ${players[1 - index].name}…';
    } else {
      title = batting ? 'You bat' : 'You bowl';
      sub = batting
          ? 'Pick a number. Avoid theirs!'
          : 'Match their number to get them out';
    }
    final locked = picked || g.showingBall || g.over;
    // Short halves (small phones): scale the whole half down instead of overflowing.
    return LayoutBuilder(
      builder: (context, c) => Padding(
        padding: const EdgeInsets.all(12),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: max(0.0, c.maxWidth - 24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  PlayerBadge(
                      index: seat,
                      size: 22,
                      color: player.color,
                      initial: player.name),
                  const SizedBox(width: 6),
                  Text(player.name,
                      style: TextStyle(
                          fontFamily: Fonts.body,
                          color: nameColor(player.color),
                          fontWeight: FontWeight.w900,
                          fontSize: 15)),
                  const SizedBox(width: 8),
                  GameIcon(batting ? GameIcons.bat : GameIcons.cricketBall,
                      size: 20, color: Colors.white),
                ]),
                const SizedBox(height: 4),
                if (g.showingBall && ball != null)
                  // Both hands, side by side.
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    for (final (who, n) in [
                      (index, index == g.batter ? ball.bat : ball.bowl),
                      (1 - index, 1 - index == g.batter ? ball.bat : ball.bowl)
                    ]) ...[
                      if (who != index) const SizedBox(width: 12),
                      Column(mainAxisSize: MainAxisSize.min, children: [
                        SizedBox(
                            width: 54,
                            height: 54,
                            child: CustomPaint(
                                painter: _HandPainter(
                                    n, fillFor(players[who].color)))),
                        Text('$n',
                            style: const TextStyle(
                                fontFamily: Fonts.display,
                                fontSize: 18,
                                color: Colors.white)),
                      ]),
                    ],
                  ]),
                Stack(alignment: Alignment.center, children: [
                  FittedBox(
                      child: Text(title,
                          style: TextStyle(
                              fontFamily: Fonts.display,
                              color: stamp
                                  ? const Color(0xFFFF8E8B)
                                  : Colors.white,
                              fontSize: 30))),
                  if (stamp)
                    Transform.rotate(
                      angle: -0.18,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 2),
                        decoration: BoxDecoration(
                            border: Border.all(
                                color: const Color(0xFFFF5E5B), width: 3),
                            borderRadius: BorderRadius.circular(8)),
                        child: const Text('OUT!',
                            style: TextStyle(
                                fontFamily: Fonts.display,
                                fontSize: 30,
                                color: Color(0xFFFF5E5B))),
                      ),
                    ),
                ]),
                Text(sub,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontFamily: Fonts.body,
                        color: NeonPalette.textMuted,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var n = 1; n <= 6; n++)
                        Semantics(
                          button: !locked,
                          label: '$n',
                          excludeSemantics: true,
                          child: GestureDetector(
                            onTap: locked
                                ? null
                                : () {
                                    haptic(HapticWeight.selection);
                                    g.pick(index, n);
                                  },
                            child: Opacity(
                              opacity: locked ? 0.4 : 1,
                              child: Container(
                                width: 58,
                                height: 66,
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: Radii.rChip,
                                  border: Border.all(
                                      color:
                                          player.color.withValues(alpha: 0.7),
                                      width: 1.5),
                                ),
                                child: Column(children: [
                                  Expanded(
                                      child: CustomPaint(
                                          painter: _HandPainter(
                                              n, fillFor(player.color)),
                                          size: Size.infinite)),
                                  Text('$n',
                                      style: const TextStyle(
                                          fontFamily: Fonts.display,
                                          fontSize: 14,
                                          height: 1,
                                          color: Colors.white)),
                                ]),
                              ),
                            ),
                          ),
                        ),
                    ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
