import 'package:flutter/material.dart';
import '../../../core/ui/components.dart';
import '../../guess_person/models/gp_player.dart';
import '../shell/game_hud.dart' show MomentWatcher, keyMoment;
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/split_screen.dart';
import '../shell/ticking_play.dart';

enum RpsPhase { pick, reveal, done }

/// Rock Paper Scissors for 2-6. Everyone picks in secret; then all are revealed and you
/// score a point for every player your pick beats. First to [target] wins.
class RpsLogic extends LocalGameLogic {
  static const emoji = ['✊', '✋', '✌️'];
  static const names = ['ROCK', 'PAPER', 'SCISSORS'];
  final int players;
  final int target;
  final int revealMs;
  late final List<int?> picks = List.filled(players, null);
  late final List<int> score = List.filled(players, 0);
  late List<int> lastPicks = List.filled(players, -1);
  late List<int> lastPoints = List.filled(players, 0);
  RpsPhase phase = RpsPhase.pick;
  int round = 1;
  int _now = 0;
  int? _nextAt;

  RpsLogic({this.players = 2, int? target, this.revealMs = 1800})
      : target = target ?? (players == 2 ? 5 : 7);

  /// Rock (0) beats scissors (2), paper (1) beats rock, scissors beats paper.
  static bool beats(int a, int b) => (a - b + 3) % 3 == 1;

  @override
  bool get finished => phase == RpsPhase.done;
  @override
  List<int> get scores => score;

  @override
  void update(int elapsedMs) {
    _now = elapsedMs;
    final next = _nextAt;
    if (phase == RpsPhase.reveal && next != null && _now >= next) {
      _nextAt = null;
      if (score.any((s) => s >= target)) {
        phase = RpsPhase.done;
      } else {
        round++;
        picks.fillRange(0, players, null);
        phase = RpsPhase.pick;
      }
      notifyListeners();
    }
  }

  void pick(int player, int choice) {
    if (forward('pick', [player, choice])) return;
    if (phase != RpsPhase.pick ||
        player < 0 ||
        player >= players ||
        choice < 0 ||
        choice > 2 ||
        picks[player] != null) return;
    picks[player] = choice;
    if (picks.every((p) => p != null)) {
      lastPicks = [for (final p in picks) p!];
      lastPoints = [
        for (var i = 0; i < players; i++)
          [
            for (var j = 0; j < players; j++)
              if (beats(lastPicks[i], lastPicks[j])) j
          ].length
      ];
      for (var i = 0; i < players; i++) {
        score[i] += lastPoints[i];
      }
      phase = RpsPhase.reveal;
      _nextAt = _now + revealMs;
    }
    notifyListeners();
  }
}

final rpsInfo = LocalGameInfo(
  id: 'rock_paper_scissors',
  title: 'Rock Paper Scissors',
  emoji: '✊',
  color: const Color(0xFFFD7E14),
  tagline: 'Stone, paper, scissors… SHOOT!',
  rules: const [
    'Everyone secretly picks Rock, Paper or Scissors on their own side.',
    'Rock beats scissors, scissors beats paper, paper beats rock.',
    'You score a point for every player you beat. First to 5 (or 7 with more players) wins!',
  ],
  scoreUnit: 'points',
  splitScreen: true,
  maxPlayers: 6,
  bot: botFor<RpsLogic>((g, b, now) {
    if (g.phase != RpsPhase.pick || g.picks[b.seat] != null) return;
    if (!b.thinkFirst(g.round, now, 500, 1300)) return;
    // Mostly random, sometimes plays what beats your last move.
    final yours = g.lastPicks.isEmpty ? -1 : g.lastPicks[0];
    g.pick(b.seat,
        yours >= 0 && b.chance(0.3) ? (yours + 1) % 3 : b.rng.nextInt(3));
  }),
  online: RelaySpec<RpsLogic>(
    create: (n) => RpsLogic(players: n),
    save: (g) => {
      'locked': [
        for (final p in g.picks) p != null
      ], // picks stay secret until everyone has picked
      'score': g.score, 'last': g.lastPicks, 'points': g.lastPoints,
      'phase': g.phase.index, 'round': g.round,
    },
    load: (g, s, me) {
      final locked = (s['locked'] as List).cast<bool>();
      for (var i = 0; i < g.players; i++) {
        g.picks[i] = locked[i] ? (g.picks[i] ?? 0) : null;
      }
      g.score.setAll(0, ints(s['score']));
      g.lastPicks = ints(s['last']);
      g.lastPoints = ints(s['points']);
      g.phase = RpsPhase.values[asInt(s['phase'])];
      g.round = asInt(s['round']);
    },
    apply: (g, from, name, a) {
      if (name == 'pick' && asInt(a[0]) == from) g.pick(from, asInt(a[1]));
    },
    view: (context, g, players, me) => Column(children: [
      ScoreMiddleBar(
          players: players,
          scores: g.scores,
          label: 'ROUND ${g.round} · FIRST TO ${g.target}'),
      Expanded(
          child:
              _RpsZone(player: players[me], index: me, g: g, players: players)),
    ]),
  ),
  play: (players, onFinished) => TickingPlay<RpsLogic>(
    create: () => RpsLogic(players: players.length),
    onFinished: onFinished,
    builder: (context, g) => MomentWatcher<RpsPhase>(
      value: g.phase,
      onChange: (fx, _, now) {
        if (now == RpsPhase.reveal) {
          final winners = [
            for (var i = 0; i < players.length; i++)
              if (g.lastPoints[i] > 0) players[i].name
          ];
          if (winners.isEmpty) {
            fx?.pop('DRAW!', color: Colors.white);
          } else {
            keyMoment(fx, 'SHOOT!',
                sub:
                    '${winners.join(' & ')} ${winners.length == 1 ? 'scores' : 'score'}',
                sound: 'pop');
          }
        }
      },
      child: PlayerZones(
        count: players.length,
        colors: [for (final p in players) p.color],
        middle: ScoreMiddleBar(
            players: players,
            scores: g.scores,
            label: 'Round ${g.round} · first to ${g.target}'),
        center: ZoneCenterChip('Round ${g.round}'),
        zone: (i) =>
            _RpsZone(player: players[i], index: i, g: g, players: players),
      ),
    ),
  ),
);

/// The drawn hands (no emoji): rock, paper, scissors.
const _hands = [GameIcons.rock, GameIcons.paper, GameIcons.scissors];

class _RpsZone extends StatelessWidget {
  final GpPlayer player;
  final int index;
  final RpsLogic g;
  final List<GpPlayer> players;
  const _RpsZone(
      {required this.player,
      required this.index,
      required this.g,
      required this.players});

  @override
  Widget build(BuildContext context) {
    final reveal = g.phase != RpsPhase.pick;
    final picked = g.picks[index] != null;
    final seat = PlayerPalette.indexOf(player.color) ?? index;
    final won = reveal && g.lastPoints[index] > 0;
    return Padding(
      padding: const EdgeInsets.all(10),
      // Small zones (6 players on a small phone): shrink to fit rather than overflow.
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
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
              Text('${g.score[index]}',
                  style: const TextStyle(
                      fontFamily: Fonts.display,
                      color: Colors.white,
                      fontSize: 22)),
            ]),
            const SizedBox(height: 8),
            if (reveal) ...[
              TweenAnimationBuilder<double>(
                key: ValueKey('r${g.round}'),
                tween: Tween(begin: Motion.reduced(context) ? 1 : 0.3, end: 1),
                duration: const Duration(milliseconds: 450),
                curve: Curves.elasticOut,
                builder: (_, s, child) =>
                    Transform.scale(scale: s, child: child),
                child: Container(
                  width: 112,
                  height: 112,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: won
                        ? Brand.gold.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.06),
                    border: Border.all(
                        color: won
                            ? Brand.gold
                            : Colors.white.withValues(alpha: 0.18),
                        width: won ? 3 : 1.5),
                  ),
                  child: Semantics(
                      label: RpsLogic.names[g.lastPicks[index]],
                      child: GameIcon(_hands[g.lastPicks[index]],
                          size: 72, color: nameColor(player.color))),
                ),
              ),
              const SizedBox(height: 6),
              Text(won ? '+${g.lastPoints[index]}' : 'no points',
                  style: TextStyle(
                      fontFamily: Fonts.display,
                      color: won ? Brand.gold : NeonPalette.textMuted,
                      fontSize: 22)),
              if (players.length > 2)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Wrap(spacing: 8, children: [
                    for (var j = 0; j < players.length; j++)
                      if (j != index)
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          PlayerBadge(
                              index:
                                  PlayerPalette.indexOf(players[j].color) ?? j,
                              size: 14,
                              color: players[j].color),
                          const SizedBox(width: 3),
                          GameIcon(_hands[g.lastPicks[j]],
                              size: 22, color: nameColor(players[j].color)),
                        ]),
                  ]),
                ),
            ] else ...[
              Row(mainAxisSize: MainAxisSize.min, children: [
                if (picked) ...[
                  const GameIcon(GameIcons.lock, size: 18),
                  const SizedBox(width: 6)
                ],
                Text(picked ? 'Locked in' : 'Pick one!',
                    style: const TextStyle(
                        fontFamily: Fonts.display,
                        color: Colors.white,
                        fontSize: 22)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                for (var c = 0; c < 3; c++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Semantics(
                      button: true,
                      label: RpsLogic.names[c],
                      excludeSemantics: true,
                      child: GestureDetector(
                        onTap: picked
                            ? null
                            : () {
                                haptic(HapticWeight.selection);
                                g.pick(index, c);
                              },
                        child: Opacity(
                          opacity: picked ? 0.35 : 1,
                          child: Container(
                            width: 88,
                            height: 88,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                  center: const Alignment(-0.3, -0.35),
                                  colors: [
                                    Color.lerp(
                                        player.color, Colors.white, 0.25)!,
                                    fillFor(player.color)
                                  ]),
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: picked
                                  ? null
                                  : Shadows.edge(
                                      Color.lerp(
                                          player.color, Colors.black, 0.5)!,
                                      depth: 4),
                            ),
                            child: GameIcon(_hands[c], size: 52),
                          ),
                        ),
                      ),
                    ),
                  ),
              ]),
            ],
          ]),
        ),
      ),
    );
  }
}
