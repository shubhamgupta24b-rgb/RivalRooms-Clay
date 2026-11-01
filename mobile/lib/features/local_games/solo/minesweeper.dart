import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/ui/components.dart';
import 'package:flutter/services.dart';
import '../../../core/records/level_progress.dart';
import '../../guess_person/models/gp_player.dart';
import '../shell/game_hud.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/local_game_shell.dart' show PauseButton;
import '../shell/ticking_play.dart';
import 'solo_common.dart';

/// Minesweeper on 9x9 with 10 mines. Your first tap is always safe (the mines are placed
/// after it). Numbers count neighbouring mines. Score: safe cells opened, plus a time
/// bonus for clearing the board.
class MinesweeperLogic extends SoloLogic {
  static const size = 9, mineCount = 10;
  static const levelSpecs = [(9, 10), (12, 22), (16, 40)];
  final int level;
  final int board;
  final int budget;
  final Random _rng;
  final Set<int> mines = {};
  final Set<int> open = {};
  final Set<int> flags = {};
  List<int>? remoteCounts;
  bool placed = false;
  bool won = false;
  int? exploded;
  int _startedAt = 0;

  MinesweeperLogic({this.level = 1, Random? random, Set<int>? fixedMines})
      : board =
            fixedMines != null ? size : levelSpecs[(level.clamp(1, 3)) - 1].$1,
        budget = fixedMines != null
            ? fixedMines.length
            : levelSpecs[(level.clamp(1, 3)) - 1].$2,
        _rng = random ?? Random() {
    if (fixedMines != null) {
      mines.addAll(fixedMines);
      placed = true;
    }
  }

  static List<int> neighbours(int i, [int n = size]) {
    final r = i ~/ n, c = i % n;
    return [
      for (var dr = -1; dr <= 1; dr++)
        for (var dc = -1; dc <= 1; dc++)
          if ((dr != 0 || dc != 0) &&
              r + dr >= 0 &&
              r + dr < n &&
              c + dc >= 0 &&
              c + dc < n)
            (r + dr) * n + c + dc,
    ];
  }

  int count(int i) {
    final remote = remoteCounts;
    if (remote != null && i < remote.length) return remote[i];
    return neighbours(i, board).where(mines.contains).length;
  }

  int get seconds => placed ? ((now - _startedAt) / 1000).floor() : 0;
  int get minesLeft => (placed ? mines.length : budget) - flags.length;

  void _place(int safe) {
    final keepClear = {safe, ...neighbours(safe, board)};
    final cells = [
      for (var i = 0; i < board * board; i++)
        if (!keepClear.contains(i)) i
    ]..shuffle(_rng);
    mines.addAll(cells.take(budget));
    placed = true;
    _startedAt = now;
  }

  void reveal(int i) {
    if (over || open.contains(i) || flags.contains(i)) return;
    if (!placed) _place(i);
    if (mines.contains(i)) {
      exploded = i;
      HapticFeedback.heavyImpact().ignore();
      gameOver(1800);
      return;
    }
    // Flood-fill the empty area.
    final todo = [i];
    while (todo.isNotEmpty) {
      final k = todo.removeLast();
      if (!open.add(k)) continue;
      flags.remove(k);
      if (count(k) == 0)
        todo.addAll(neighbours(k, board)
            .where((x) => !open.contains(x) && !mines.contains(x)));
    }
    score = open.length;
    if (open.length == board * board - mines.length) {
      won = true;
      score = open.length + 100 + max(0, 300 - seconds);
      LevelProgress.unlock('minesweeper', min(3, level + 1));
      HapticFeedback.mediumImpact().ignore();
      gameOver(1800);
    }
    notifyListeners();
  }

  void toggleFlag(int i) {
    if (over || open.contains(i)) return;
    flags.contains(i) ? flags.remove(i) : flags.add(i);
    HapticFeedback.selectionClick().ignore();
    notifyListeners();
  }

  @override
  void step(int now) {
    if (placed) notifyListeners(); // the clock
  }
}

/// Same minefield for every player (one seed). First correct clear wins. Mines stay on the host.
class MinesRace extends LocalGameLogic {
  final int level;
  final int seed;
  final List<MinesweeperLogic> boards;
  int elapsed = 0;
  int? winner;
  MinesRace({this.level = 1, int players = 2, int? seed})
      : seed = seed ?? 11,
        boards = [
          for (var i = 0; i < players; i++)
            MinesweeperLogic(
                level: level,
                fixedMines: minesFor(seed ?? 11, level),
                random: Random(seed ?? 11)),
        ];

  @override
  bool get finished => winner != null || elapsed >= 180000;
  @override
  List<int> get scores => [
        for (var i = 0; i < boards.length; i++)
          winner == i ? 1000000 - elapsed : boards[i].open.length
      ];

  void reveal(int player, int cell) {
    if (forward('reveal', [player, cell])) return;
    if (elapsed < 3000 ||
        winner != null ||
        player < 0 ||
        player >= boards.length ||
        boards[player].over) return;
    boards[player].reveal(cell);
    if (boards[player].won && winner == null) winner = player;
    notifyListeners();
  }

  void flag(int player, int cell) {
    if (forward('flag', [player, cell])) return;
    if (elapsed < 3000 || winner != null || boards[player].over) return;
    boards[player].toggleFlag(cell);
    notifyListeners();
  }

  @override
  void update(int ms) {
    elapsed = ms;
    for (final b in boards) {
      b.update(ms);
    }
    notifyListeners();
  }

  Map<String, dynamic> save() => {
        't': elapsed,
        'w': winner,
        'level': level,
        'boards': [
          for (final b in boards)
            {
              'open': b.open.toList(),
              'counts': [
                for (final i in b.open)
                  b.remoteCounts == null ? b.count(i) : b.remoteCounts![i]
              ],
              'flags': b.flags.toList(),
              'boom': b.exploded,
              'won': b.won,
            },
        ],
      };

  void load(Map<String, dynamic> s) {
    elapsed = asInt(s['t']);
    winner = nInt(s['w']);
    final list = s['boards'] as List;
    for (var i = 0; i < boards.length && i < list.length; i++) {
      final m = list[i] as Map;
      final b = boards[i];
      b.open
        ..clear()
        ..addAll(ints(m['open']));
      b.flags
        ..clear()
        ..addAll(ints(m['flags']));
      final opened = ints(m['open']);
      final counts = ints(m['counts']);
      b.remoteCounts = List.filled(b.board * b.board, 0);
      for (var k = 0; k < opened.length && k < counts.length; k++) {
        b.remoteCounts![opened[k]] = counts[k];
      }
      b.exploded = nInt(m['boom']);
      b.won = m['won'] == true;
      b.placed = b.open.isNotEmpty;
      b.mines.clear();
    }
  }
}

Set<int> minesFor(int seed, int level) {
  final spec = MinesweeperLogic.levelSpecs[(level.clamp(1, 3)) - 1];
  final n = spec.$1;
  final center = (n ~/ 2) * n + n ~/ 2;
  final safe = {center, ...MinesweeperLogic.neighbours(center, n)};
  final cells = [
    for (var i = 0; i < n * n; i++)
      if (!safe.contains(i)) i
  ]..shuffle(Random(seed));
  return cells.take(spec.$2).toSet();
}

final minesRaceSpec = RelaySpec<MinesRace>(
  create: (n) => MinesRace(players: n, seed: 11),
  save: (g) => g.save(),
  load: (g, s, me) => g.load(s),
  apply: (g, from, name, a) {
    if (a.isEmpty || asInt(a[0]) != from) return;
    if (name == 'reveal') g.reveal(from, asInt(a[1]));
    if (name == 'flag') g.flag(from, asInt(a[1]));
  },
  view: (context, g, players, me) => _RaceView(g: g, players: players, me: me),
);

final minesweeperInfo = LocalGameInfo(
  id: 'minesweeper',
  title: 'Minesweeper',
  emoji: '💣',
  color: const Color(0xFF607D8B),
  tagline: 'Clear the field, dodge the mines!',
  rules: const [
    'Three levels. Easy is 9×9, then the field and the mine count grow.',
    'Tap a square to dig. Your first tap is always safe.',
    'Clear every safe square to unlock the next level. Online, the first clean board wins.',
  ],
  scoreUnit: 'points',
  splitScreen: false,
  minPlayers: 1,
  maxPlayers: 2,
  online: minesRaceSpec,
  play: (players, onFinished) => players.length < 2
      ? _MinesMenu(onFinished: onFinished)
      : TickingPlay<MinesRace>(
          create: () => MinesRace(players: players.length),
          onFinished: onFinished,
          builder: (context, g) => _RaceView(g: g, me: 0, players: players)),
);

class _MinesView extends StatefulWidget {
  final MinesweeperLogic g;
  final void Function(int cell)? onReveal;
  final void Function(int cell)? onFlag;
  const _MinesView({required this.g, this.onReveal, this.onFlag});
  @override
  State<_MinesView> createState() => _MinesViewState();
}

class _MinesViewState extends State<_MinesView> {
  bool _flagMode = false;
  static const _numColors = [
    Colors.transparent,
    Color(0xFF1E88E5),
    Color(0xFF43A047),
    Color(0xFFE53935),
    Color(0xFF3949AB),
    Color(0xFF8E24AA),
    Color(0xFF00897B),
    Color(0xFF212121),
    Color(0xFF757575)
  ];

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final n = g.board;
    return SoloFrame(
      title:
          g.won ? 'Cleared!' : (g.exploded != null ? 'Boom!' : 'Minesweeper'),
      score: g.score,
      extra: '${g.minesLeft} flags left · ${g.seconds}s',
      child: Column(children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A752C),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black45,
                        blurRadius: 14,
                        offset: Offset(0, 6))
                  ],
                ),
                child: GridView.count(
                  crossAxisCount: n,
                  mainAxisSpacing: 3,
                  crossAxisSpacing: 3,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (var i = 0; i < n * n; i++) _cell(g, i),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Dig / Flag mode pill.
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
              color: NeonPalette.overlay,
              borderRadius: Radii.rChip,
              border: Border.all(color: Colors.white24)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            for (final flag in [false, true])
              Semantics(
                button: true,
                selected: _flagMode == flag,
                label: flag ? 'Flag mode' : 'Dig mode',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () => setState(() => _flagMode = flag),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                        color:
                            _flagMode == flag ? Brand.gold : Colors.transparent,
                        borderRadius: Radii.rChip),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      GameIcon(flag ? GameIcons.flag : GameIcons.hammer,
                          size: 20,
                          color:
                              _flagMode == flag ? Brand.onGold : Colors.white),
                      const SizedBox(width: 6),
                      Text(flag ? 'Flag' : 'Dig',
                          style: TextStyle(
                              fontFamily: Fonts.display,
                              fontSize: 18,
                              color: _flagMode == flag
                                  ? Brand.onGold
                                  : Colors.white)),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
      ]),
    );
  }

  Widget _cell(MinesweeperLogic g, int i) {
    final isOpen = g.open.contains(i);
    final showMine = g.mines.contains(i) && g.over;
    final flagged = g.flags.contains(i);
    final c = isOpen ? g.count(i) : 0;
    return GestureDetector(
      onTap: () => _flagMode
          ? (widget.onFlag ?? g.toggleFlag)(i)
          : (widget.onReveal ?? g.reveal)(i),
      onLongPress: () => (widget.onFlag ?? g.toggleFlag)(i),
      child: Container(
        alignment: Alignment.center,
        // Grass you dig into; sand once opened (checkered like a lawn).
        decoration: BoxDecoration(
          color: i == g.exploded
              ? Colors.redAccent
              : isOpen
                  ? ((i ~/ g.board + i) % 2 == 0
                      ? const Color(0xFFE5C29F)
                      : const Color(0xFFD7B899))
                  : ((i ~/ g.board + i) % 2 == 0
                      ? const Color(0xFFA2D149)
                      : const Color(0xFF8ECC39)),
          borderRadius: BorderRadius.circular(4),
          boxShadow: isOpen
              ? null
              : const [
                  BoxShadow(color: Color(0x33000000), offset: Offset(0, 2))
                ],
        ),
        child: FittedBox(
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: showMine
                ? const GameIcon(GameIcons.bomb, size: 22)
                : flagged
                    ? const GameIcon(GameIcons.flag,
                        size: 22, color: Color(0xFFE53935))
                    : Text(isOpen && c > 0 ? '$c' : '',
                        style: TextStyle(
                            fontFamily: Fonts.display,
                            color: _numColors[c.clamp(0, 8)],
                            fontSize: 22)),
          ),
        ),
      ),
    );
  }
}

class _MinesMenu extends StatefulWidget {
  final void Function(List<int>) onFinished;
  const _MinesMenu({required this.onFinished});
  @override
  State<_MinesMenu> createState() => _MinesMenuState();
}

class _MinesMenuState extends State<_MinesMenu> {
  int unlocked = 1;
  int? level;
  @override
  void initState() {
    super.initState();
    LevelProgress.unlocked('minesweeper').then((n) {
      if (mounted) setState(() => unlocked = n.clamp(1, 3));
    });
  }

  @override
  Widget build(BuildContext context) {
    if (level == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Align(alignment: Alignment.centerLeft, child: PauseButton()),
          const SizedBox(height: 12),
          for (final (i, name) in [
            (1, 'Easy 9×9'),
            (2, 'Medium 12×12'),
            (3, 'Hard 16×16')
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GoldButton(
                  i <= unlocked ? 'Level $i · $name' : 'Level $i locked',
                  height: 56,
                  onPressed:
                      i <= unlocked ? () => setState(() => level = i) : null),
            ),
        ]),
      );
    }
    return TickingPlay<MinesweeperLogic>(
      create: () => MinesweeperLogic(level: level!),
      onFinished: widget.onFinished,
      builder: (context, g) => _MinesView(g: g),
    );
  }
}

class _RaceView extends StatefulWidget {
  final MinesRace g;
  final List<GpPlayer> players;
  final int me;
  const _RaceView({required this.g, required this.players, required this.me});
  @override
  State<_RaceView> createState() => _RaceViewState();
}

class _RaceViewState extends State<_RaceView> {
  bool flags = false;
  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final b = g.boards[widget.me];
    final wait = g.elapsed < 3000;
    return Column(children: [
      GameHud(
        players: widget.players,
        scores: [for (final x in g.boards) x.open.length],
        trailing: Text(
            wait
                ? '${(3 - g.elapsed / 1000).ceil()}'
                : (g.winner == null ? 'Race' : 'Done'),
            style: const TextStyle(
                fontFamily: Fonts.display, color: Colors.white, fontSize: 18)),
      ),
      Expanded(
          child: _MinesView(
              g: b,
              onReveal: (c) => g.reveal(widget.me, c),
              onFlag: (c) => g.flag(widget.me, c))),
    ]);
  }
}
