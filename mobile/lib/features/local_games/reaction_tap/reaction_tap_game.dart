import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/audio/game_audio.dart';
import '../../../core/settings/app_settings.dart';
import '../../guess_person/models/gp_player.dart';
import '../../../core/ui/components.dart';
import '../shell/game_hud.dart' show MomentWatcher;
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/split_screen.dart';
import '../shell/ticking_play.dart';

enum ReactionPhase { wait, go, result }

/// Wait for green, then tap first. Tapping too early costs you a point (never below 0)
/// and restarts the round. First to [target]. Works for 2-6 players.
class ReactionTapLogic extends LocalGameLogic {
  final int target;
  final int resultMs;
  final Random _rng;
  final List<int> score;
  ReactionPhase phase = ReactionPhase.wait;
  int _now = 0;
  int goAt;
  int _goStarted = 0;
  int _resultUntil = 0;
  int? lastTapper; // who ended the round (winner, or the one who jumped early)
  bool falseStart = false;
  int? reactionMs;

  ReactionTapLogic({
    this.target = 5,
    this.resultMs = 1300,
    int players = 2,
    Random? random,
  }) : _rng = random ?? Random(),
       score = List.filled(players, 0),
       goAt = 0 {
    goAt = _nextGo(0);
  }

  /// Green comes 1.5-4 seconds after the round starts, so it can't be predicted.
  int _nextGo(int from) => from + 1500 + _rng.nextInt(2500);

  @override
  List<int> get scores => score;
  @override
  bool get finished => score.any((s) => s >= target);

  @override
  void update(int elapsedMs) {
    _now = elapsedMs;
    if (phase == ReactionPhase.wait && _now >= goAt) {
      phase = ReactionPhase.go;
      _goStarted = goAt;
      notifyListeners();
    } else if (phase == ReactionPhase.result &&
        _now >= _resultUntil &&
        !finished) {
      phase = ReactionPhase.wait;
      goAt = _nextGo(_now);
      notifyListeners();
    }
  }

  /// Returns true if the tap counted (scored or was a false start).
  bool tap(int player) {
    if (forward('tap', [player])) return false;
    if (finished || phase == ReactionPhase.result) return false;
    lastTapper = player;
    if (phase == ReactionPhase.wait) {
      falseStart = true;
      reactionMs = null;
      if (score[player] > 0) score[player]--;
    } else {
      falseStart = false;
      reactionMs = _now - _goStarted;
      score[player]++;
    }
    phase = ReactionPhase.result;
    _resultUntil = _now + resultMs;
    notifyListeners();
    return true;
  }
}

final reactionTapInfo = LocalGameInfo(
  id: 'reaction_tap',
  title: 'Reaction Tap',
  emoji: '⚡',
  color: const Color(0xFFFFC93C),
  tagline: 'Fastest finger wins!',
  rules: const [
    'Your side turns RED: wait...',
    'When it turns GREEN, tap as fast as you can. First tap wins the point.',
    'Tap while it is still red and you LOSE a point. First to 5 wins. 2 to 6 players.',
  ],
  scoreUnit: 'points',
  splitScreen: true,
  maxPlayers: 6,
  bot: botFor<ReactionTapLogic>((g, b, now) {
    if (g.finished || g.phase != ReactionPhase.go) return;
    // Human-like reaction time: 280-650 ms after green.
    if (b.thinkFirst(g.goAt, now, 280, 650)) g.tap(b.seat);
  }),
  online: RelaySpec<ReactionTapLogic>(
    create: (n) => ReactionTapLogic(players: n),
    save: (g) => {
      'score': g.score,
      'phase': g.phase.index,
      'last': g.lastTapper,
      'false': g.falseStart,
      'ms': g.reactionMs,
    },
    load: (g, s, me) {
      g.score.setAll(0, ints(s['score']));
      g.phase = ReactionPhase.values[asInt(s['phase'])];
      g.lastTapper = nInt(s['last']);
      g.falseStart = s['false'] == true;
      g.reactionMs = nInt(s['ms']);
    },
    apply: (g, from, name, a) {
      if (name == 'tap' && asInt(a[0]) == from) g.tap(from);
    },
    view: (context, g, players, me) => Column(
      children: [
        ScoreMiddleBar(
          players: players,
          scores: g.scores,
          label: 'First to ${g.target}',
        ),
        Expanded(
          child: _ReactionHalf(player: players[me], index: me, g: g),
        ),
      ],
    ),
  ),
  play: (players, onFinished) => TickingPlay<ReactionTapLogic>(
    create: () => ReactionTapLogic(players: players.length),
    onFinished: onFinished,
    builder: (context, g) => PlayerZones(
      count: players.length,
      colors: [for (final p in players) p.color],
      middle: ScoreMiddleBar(
        players: players,
        scores: g.scores,
        label: 'First to ${g.target}',
      ),
      center: ZoneCenterChip('First to ${g.target}'),
      zone: (i) => _ReactionHalf(player: players[i], index: i, g: g),
    ),
  ),
);

class _ReactionHalf extends StatelessWidget {
  final GpPlayer player;
  final int index;
  final ReactionTapLogic g;
  const _ReactionHalf({
    required this.player,
    required this.index,
    required this.g,
  });

  @override
  Widget build(BuildContext context) {
    final result = g.phase == ReactionPhase.result;
    final jumped = result && g.falseStart && g.lastTapper == index;
    final won = result && !g.falseStart && g.lastTapper == index;
    final go = g.phase == ReactionPhase.go;
    final signal = go
        ? const Color(0xFF51F09B)
        : (won ? Brand.gold : const Color(0xFFFF747D));
    final title = !result
        ? (go ? 'GO!' : 'WAIT')
        : (jumped
              ? 'FALSE START'
              : (g.falseStart ? 'HOLD STEADY' : (won ? 'FIRST!' : 'BEATEN')));
    final detail = !result
        ? (go
              ? 'Tap anywhere in your lane'
              : 'Red means hold. Green means tap.')
        : (jumped
              ? '−1 point • score never below 0'
              : (g.falseStart
                    ? 'Another lane jumped the start'
                    : (won
                          ? '+1 point • ${g.reactionMs} ms'
                          : 'Winning reaction: ${g.reactionMs} ms')));
    final enabled = !result && !g.finished;
    void tap() => g.tap(index);

    // Observe confirmed state, so relay guests get feedback only after the host
    // accepts their tap. One lane owns each result; rebuilding cannot replay it.
    return MomentWatcher<(ReactionPhase, int?, bool)>(
      value: (g.phase, g.lastTapper, g.falseStart),
      onChange: (_, before, now) {
        if (now.$1 != ReactionPhase.result || now.$2 != index) return;
        GameAudio.sfx(now.$3 ? 'lose' : 'coin');
        if (AppSettings.haptics.value) {
          (now.$3
                  ? HapticFeedback.heavyImpact()
                  : HapticFeedback.mediumImpact())
              .ignore();
        }
      },
      child: Semantics(
        key: ValueKey('reaction-lane-$index'),
        button: true,
        enabled: enabled,
        onTap: enabled ? tap : null,
        label: '${player.name}: $title. $detail. ${g.score[index]} points.',
        excludeSemantics: true,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          // Pointer-down, not pointer-up: reaction times must not include a release.
          onPointerDown: enabled ? (_) => tap() : null,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: DecoratedBox(
              decoration: Skin.surface(tint: player.color, ring: player.color),
              child: ClipRRect(
                borderRadius: Radii.rLg,
                child: CustomPaint(
                  painter: const _StartingLanePainter(),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact =
                          constraints.maxHeight < 210 ||
                          constraints.maxWidth < 170;
                      return Padding(
                        padding: EdgeInsets.all(compact ? 8 : 14),
                        child: Column(
                          children: [
                            SizedBox(
                              height: 24,
                              child: Row(
                                children: [
                                  PlayerBadge(
                                    index:
                                        PlayerPalette.indexOf(player.color) ??
                                        index,
                                    size: 20,
                                    color: player.color,
                                    initial: player.name,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      player.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: Fonts.body,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: constraints.maxWidth < 130 ? 30 : 54,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        '${g.score[index]} / ${g.target}',
                                        style: const TextStyle(
                                          fontFamily: Fonts.display,
                                          color: Colors.white,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    flex: 2,
                                    child: Center(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: _StartingTree(
                                          phase: g.phase,
                                          falseStart: jumped,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    flex: 5,
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (!compact)
                                          const Text(
                                            'REACTION RACE',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Color(0xFFD0D4E5),
                                              fontFamily: Fonts.body,
                                              fontSize: 11,
                                              letterSpacing: 1.8,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        Flexible(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              title,
                                              style: TextStyle(
                                                fontFamily: Fonts.display,
                                                color: signal,
                                                fontSize: compact ? 32 : 48,
                                                height: 1.1,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Flexible(
                                          child: Text(
                                            detail,
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontFamily: Fonts.body,
                                              color: Colors.white,
                                              fontSize: compact ? 12 : 15,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            // The lamps and GO text switch immediately; only the pad settles.
                            AnimatedContainer(
                              duration: go
                                  ? Duration.zero
                                  : Motion.of(context, Motion.fast),
                              height: compact ? 34 : 48,
                              width: double.infinity,
                              alignment: Alignment.center,
                              decoration: Skin.surface(
                                tint: go ? signal : player.color,
                                ring: go ? signal : Colors.white24,
                                pressed: result,
                                radius: 14,
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  g.finished
                                      ? 'RACE COMPLETE'
                                      : result
                                      ? 'NEXT START SOON'
                                      : (go
                                            ? 'TAP NOW'
                                            : 'HOLD • WAIT FOR GREEN'),
                                  style: const TextStyle(
                                    fontFamily: Fonts.body,
                                    color: Colors.white,
                                    fontSize: 13,
                                    letterSpacing: 1,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// All red lamps stay lit together: this is a random start, not a countdown.
class _StartingTree extends StatelessWidget {
  final ReactionPhase phase;
  final bool falseStart;
  const _StartingTree({required this.phase, required this.falseStart});

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('starting-tree'),
    width: 76,
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: const Color(0xFF151C2B),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFF8893A6), width: 2),
      boxShadow: const [BoxShadow(color: Colors.black38, offset: Offset(0, 4))],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var row = 0; row < 4; row++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var side = 0; side < 2; side++)
                  _lamp(
                    row == 3
                        ? (phase == ReactionPhase.go
                              ? const Color(0xFF51F09B)
                              : null)
                        : (phase == ReactionPhase.wait || falseStart
                              ? const Color(0xFFFF5C6C)
                              : null),
                  ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _lamp(Color? color) => Container(
    width: 22,
    height: 22,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: Colors.black54, width: 2),
      gradient: RadialGradient(
        center: const Alignment(-0.3, -0.4),
        colors: color == null
            ? const [Color(0xFF354052), Color(0xFF202736)]
            : [Color.lerp(color, Colors.white, 0.5)!, color],
      ),
      boxShadow: color == null
          ? null
          : [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 8)],
    ),
  );
}

class _StartingLanePainter extends CustomPainter {
  const _StartingLanePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF202A3D);
    canvas.drawRect(Offset.zero & size, paint);
    paint
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 2;
    for (final x in [size.width * 0.08, size.width * 0.92]) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    const cell = 9.0;
    for (var col = 0; col * cell < size.width; col++) {
      for (var row = 0; row < 2; row++) {
        if ((row + col).isEven) {
          canvas.drawRect(
            Rect.fromLTWH(
              col * cell,
              size.height - 18 + row * cell,
              cell,
              cell,
            ),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_StartingLanePainter oldDelegate) => false;
}
