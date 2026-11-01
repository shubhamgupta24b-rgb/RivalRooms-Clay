import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../guess_person/models/gp_player.dart';
import '../../../core/ui/components.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/split_screen.dart';
import '../shell/ticking_play.dart';

class Kick {
  final int kicker;
  final int
      shot; // 0 left, 1 centre, 2 right (absolute, as seen by player 1 at the bottom)
  final int dive;
  bool get goal => shot != dive;
  const Kick(this.kicker, this.shot, this.dive);
}

/// Penalty shootout on one screen. Players alternate kicking and keeping. Both pick a
/// side in secret on their own half; the kick resolves once both have picked.
/// 5 kicks each, then sudden death (capped, so a match always ends).
class PenaltyLogic extends LocalGameLogic {
  final int kicksEach;
  final int maxKicks;
  final int showMs;
  final List<int> goals = [0, 0];
  final List<Kick> kicks = [];
  final List<int?> picks = [
    null,
    null
  ]; // this kick's secret picks (absolute zones)
  int _now = 0;
  int? _nextAt;

  PenaltyLogic({this.kicksEach = 5, this.maxKicks = 20, this.showMs = 1600});

  int get kickNo => kicks.length;
  int get kicker => kickNo % 2;
  int get keeper => 1 - kicker;
  bool get showingResult => _nextAt != null;
  Kick? get lastKick => kicks.isEmpty ? null : kicks.last;
  int taken(int p) => kicks.where((k) => k.kicker == p).length;

  @override
  List<int> get scores => goals;

  @override
  bool get finished {
    if (showingResult) return false;
    final a = taken(0), b = taken(1);
    final leftA = a < kicksEach ? kicksEach - a : 0,
        leftB = b < kicksEach ? kicksEach - b : 0;
    if (goals[0] + leftA < goals[1] || goals[1] + leftB < goals[0])
      return true; // can't be caught
    if (a >= kicksEach && a == b && goals[0] != goals[1])
      return true; // sudden death decided
    return kickNo >= maxKicks;
  }

  @override
  void update(int elapsedMs) {
    _now = elapsedMs;
    final next = _nextAt;
    if (next != null && _now >= next) {
      _nextAt = null;
      picks[0] = picks[1] = null;
      notifyListeners();
    }
  }

  /// [zone] is absolute (0 left, 1 centre, 2 right from player 1's side). Returns true if accepted.
  bool pick(int player, int zone) {
    if (forward('pick', [player, zone])) return false;
    if (finished ||
        showingResult ||
        zone < 0 ||
        zone > 2 ||
        picks[player] != null) return false;
    picks[player] = zone;
    if (picks[0] != null && picks[1] != null) {
      final k = Kick(kicker, picks[kicker]!, picks[keeper]!);
      kicks.add(k);
      if (k.goal) goals[k.kicker]++;
      _nextAt = _now + showMs;
    }
    notifyListeners();
    return true;
  }
}

final penaltyInfo = LocalGameInfo(
  id: 'penalty',
  title: 'Penalty Shootout',
  emoji: '⚽',
  color: const Color(0xFF2FB36D),
  tagline: 'Shoot, dive, score!',
  rules: const [
    'You take turns being the kicker and the goalkeeper.',
    'Both secretly pick LEFT, MIDDLE or RIGHT on your own side.',
    'Keeper picks the same side as the shot = SAVE. Otherwise GOAL!',
    '5 kicks each, then sudden death.',
  ],
  scoreUnit: 'goals',
  splitScreen: true,
  bot: botFor<PenaltyLogic>((g, b, now) {
    if (g.finished || g.showingResult || g.picks[b.seat] != null) return;
    if (b.thinkFirst(g.kickNo, now, 700, 1600))
      g.pick(b.seat, b.rng.nextInt(3));
  }),
  online: RelaySpec<PenaltyLogic>(
    create: (n) => PenaltyLogic(),
    save: (g) => {
      'goals': g.goals,
      'kicks': [
        for (final k in g.kicks) [k.kicker, k.shot, k.dive]
      ],
      // Only whether each player has picked: the side stays secret until both have.
      'locked': [for (final p in g.picks) p != null],
      'showing': g.showingResult,
    },
    load: (g, s, me) {
      g.goals.setAll(0, ints(s['goals']));
      g.kicks
        ..clear()
        ..addAll([
          for (final k in s['kicks'] as List)
            Kick(asInt((k as List)[0]), asInt(k[1]), asInt(k[2]))
        ]);
      final locked = (s['locked'] as List).cast<bool>();
      for (var i = 0; i < 2; i++) {
        g.picks[i] = locked[i] ? (g.picks[i] ?? 1) : null;
      }
      g._nextAt = s['showing'] == true ? 1 << 40 : null;
    },
    apply: (g, from, name, a) {
      if (name == 'pick' && asInt(a[0]) == from) g.pick(from, asInt(a[1]));
    },
    view: (context, g, players, me) => Column(children: [
      ScoreMiddleBar(
          players: players,
          scores: g.scores,
          label: g.kickNo < 2 * g.kicksEach
              ? 'Kick ${g.kickNo ~/ 2 + 1} of ${g.kicksEach}'
              : 'Sudden death'),
      Expanded(child: _PenaltyHalf(player: players[me], index: me, g: g)),
    ]),
  ),
  play: (players, onFinished) => TickingPlay<PenaltyLogic>(
    create: () => PenaltyLogic(),
    onFinished: onFinished,
    builder: (context, g) => SplitScreen(
      middle: ScoreMiddleBar(
          players: players,
          scores: g.scores,
          label: g.kickNo < 2 * g.kicksEach
              ? 'Kick ${g.kickNo ~/ 2 + 1} of ${g.kicksEach}'
              : 'Sudden death'),
      half: (i) => _PenaltyHalf(player: players[i], index: i, g: g),
    ),
  ),
);

class _PenaltyHalf extends StatelessWidget {
  final GpPlayer player;
  final int index;
  final PenaltyLogic g;
  const _PenaltyHalf(
      {required this.player, required this.index, required this.g});

  // Player 2 sees the screen rotated, so their left is player 1's right.
  int toAbsolute(int shown) => index == 0 ? shown : 2 - shown;

  @override
  Widget build(BuildContext context) {
    final kick = g.lastKick;
    final kicking = g.kicker == index;
    String title;
    String sub;
    if (g.showingResult && kick != null) {
      final mine = kick.kicker == index;
      title = kick.goal
          ? (mine ? 'GOAL!' : 'They scored')
          : (mine ? 'Saved!' : 'GREAT SAVE!');
      sub = 'Shot ${_side(kick.shot)}, dive ${_side(kick.dive)}';
    } else if (g.picks[index] != null) {
      title = 'Locked in';
      sub = 'Waiting for your rival...';
    } else {
      title = kicking ? 'You shoot' : 'You save';
      sub = kicking ? 'Pick where to shoot' : 'Pick where to dive';
    }
    const labels = ['Left', 'Middle', 'Right'];
    final canPick = !g.showingResult && g.picks[index] == null && !g.finished;
    // A little pitch: striped grass, the goal with a net, three target zones inside it.
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2E9E4F), Color(0xFF1F7A3B)]),
        border:
            Border.all(color: player.color.withValues(alpha: 0.7), width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: CustomPaint(
          painter: const _GrassStripes(),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(children: [
              Row(children: [
                PlayerBadge(
                    index: PlayerPalette.indexOf(player.color) ?? index,
                    size: 22,
                    color: player.color,
                    initial: player.name),
                const SizedBox(width: 6),
                Flexible(
                    child: Text(player.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: Fonts.body,
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 15))),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                      color: Colors.black26, borderRadius: Radii.rChip),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    GameIcon(kicking ? GameIcons.football : GameIcons.glove,
                        size: 16, color: Colors.white),
                    const SizedBox(width: 5),
                    Text(kicking ? 'KICKER' : 'KEEPER',
                        style: const TextStyle(
                            fontFamily: Fonts.body,
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            letterSpacing: 1.2)),
                  ]),
                ),
              ]),
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(children: [
                      Text(title,
                          style: TextStyle(
                              fontFamily: Fonts.display,
                              color: title == 'GOAL!' || title == 'GREAT SAVE!'
                                  ? Brand.gold
                                  : Colors.white,
                              fontSize: 38,
                              shadows: const [
                                Shadow(
                                    color: Color(0x88000000),
                                    offset: Offset(0, 3),
                                    blurRadius: 3)
                              ])),
                      Text(sub,
                          style: const TextStyle(
                              fontFamily: Fonts.body,
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800)),
                    ]),
                  ),
                ),
              ),
              // The goal: posts and crossbar, a net behind three tappable zones.
              Container(
                padding: const EdgeInsets.fromLTRB(5, 5, 5, 0),
                decoration: const BoxDecoration(
                  border: Border(
                      top: BorderSide(color: Colors.white, width: 7),
                      left: BorderSide(color: Colors.white, width: 7),
                      right: BorderSide(color: Colors.white, width: 7)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black26,
                        offset: Offset(0, 3),
                        blurRadius: 4)
                  ],
                ),
                child: CustomPaint(
                  painter: const _Net(),
                  child: Row(children: [
                    for (var shown = 0; shown < 3; shown++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(3),
                          child: Material(
                            color: _zoneColor(toAbsolute(shown), kick),
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              excludeFromSemantics: true,
                              onTap: canPick
                                  ? () {
                                      if (g.pick(index, toAbsolute(shown)))
                                        HapticFeedback.selectionClick()
                                            .ignore();
                                    }
                                  : null,
                              child: Semantics(
                                button: canPick,
                                label:
                                    '${kicking ? 'Shoot' : 'Dive'} ${labels[shown].toLowerCase()}',
                                excludeSemantics: true,
                                child: SizedBox(
                                  height: 78,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            height: 30,
                                            child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  for (final ic in _zoneIcons(
                                                      toAbsolute(shown),
                                                      kick,
                                                      kicking))
                                                    GameIcon(ic,
                                                        size: 28,
                                                        color: Colors.white),
                                                ]),
                                          ),
                                          Text(labels[shown],
                                              style: const TextStyle(
                                                  fontFamily: Fonts.display,
                                                  color: Colors.white,
                                                  fontSize: 15,
                                                  shadows: [
                                                    Shadow(
                                                        color: Colors.black45,
                                                        blurRadius: 2)
                                                  ])),
                                        ]),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  /// What a zone shows: after the kick, where the ball went and where the keeper dove;
  /// before it, a target (kicker) or a glove (keeper).
  List<GameIcons> _zoneIcons(int zone, Kick? kick, bool kicking) {
    if (g.showingResult && kick != null) {
      return [
        if (zone == kick.dive) GameIcons.glove,
        if (zone == kick.shot) GameIcons.football
      ];
    }
    if (g.picks[index] == zone) return const [GameIcons.check];
    return [kicking ? GameIcons.target : GameIcons.glove];
  }

  Color _zoneColor(int zone, Kick? kick) {
    if (g.showingResult && kick != null) {
      if (zone == kick.shot && zone == kick.dive)
        return const Color(0xFFE5484D).withValues(alpha: 0.85);
      if (zone == kick.shot)
        return StatusColors.success.withValues(alpha: 0.85);
      if (zone == kick.dive) return const Color(0xCC7A7A90);
      return Colors.transparent;
    }
    return g.picks[index] == zone
        ? player.color
        : player.color.withValues(alpha: 0.3);
  }

  // Describe the zone from this player's point of view.
  String _side(int absolute) =>
      const ['left', 'middle', 'right'][index == 0 ? absolute : 2 - absolute];
}

/// Mowed-grass stripes across the pitch.
class _GrassStripes extends CustomPainter {
  const _GrassStripes();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withValues(alpha: 0.05);
    const band = 34.0;
    for (var y = 0.0; y < size.height; y += band * 2) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, band), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The goal net: a fine white mesh.
class _Net extends CustomPainter {
  const _Net();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size,
        Paint()..color = Colors.black.withValues(alpha: 0.18));
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    const step = 12.0;
    for (var x = 0.0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (var y = 0.0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
