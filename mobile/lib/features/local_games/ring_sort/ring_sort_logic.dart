import 'dart:math';
import '../shell/local_game_logic.dart';

/// Rings stacked on pegs. A peg holds [capacity] rings; the last item of a peg's list is its top ring.
typedef Pegs = List<List<int>>;

const ringCapacity = 4;

/// Colours on level [level] (1-based): 3, then one more each level, up to 6.
int ringColorsFor(int level) => min(2 + level, 6);

bool pegsSolved(Pegs pegs) => pegs.every((p) =>
    p.isEmpty || (p.length == ringCapacity && p.every((r) => r == p.first)));

bool pegDone(List<int> p) =>
    p.length == ringCapacity && p.every((r) => r == p.first);

/// How many rings would move from [from] to [to]: the top run of one colour, as many as fit
/// (0 if the move isn't allowed: onto a different colour, or a full peg).
int ringsMovable(Pegs pegs, int from, int to) {
  if (from == to) return 0;
  final a = pegs[from], b = pegs[to];
  if (a.isEmpty || b.length >= ringCapacity) return 0;
  if (b.isNotEmpty && b.last != a.last) return 0;
  var run = 1;
  while (run < a.length && a[a.length - 1 - run] == a.last) {
    run++;
  }
  return min(run, ringCapacity - b.length);
}

Pegs copyPegs(Pegs pegs) => [for (final p in pegs) List.of(p)];

/// A list of (from, to) moves that sorts [start], or null if none was found within [limit] positions.
/// Depth-first, trying the most useful moves first; good enough for up to 6 colours and 2 spare pegs.
List<(int, int)>? solveRings(Pegs start, {int limit = 40000}) {
  final seen = <String>{};
  final path = <(int, int)>[];
  var visited = 0;
  String key(Pegs p) => ([for (final x in p) x.join(',')]..sort()).join('|');

  bool dfs(Pegs pegs) {
    if (pegsSolved(pegs)) return true;
    if (++visited > limit) return false;
    if (!seen.add(key(pegs))) return false;
    final moves = <(int, int, int)>[]; // from, to, priority
    for (var f = 0; f < pegs.length; f++) {
      final a = pegs[f];
      if (a.isEmpty || pegDone(a)) continue;
      final uniform = a.every((r) => r == a.first);
      var triedEmpty = false;
      for (var t = 0; t < pegs.length; t++) {
        final n = ringsMovable(pegs, f, t);
        if (n == 0) continue;
        final b = pegs[t];
        if (b.isEmpty) {
          // Moving a one-colour peg to an empty one changes nothing; one empty target is enough.
          if (uniform || triedEmpty) continue;
          triedEmpty = true;
          moves.add((f, t, 0));
        } else {
          // Onto a matching colour: best when it empties the run's source or tops up a one-colour peg.
          final onUniform = b.every((r) => r == b.first);
          moves.add((f, t, (onUniform ? 2 : 1) + (n == a.length ? 1 : 0)));
        }
      }
    }
    moves.sort((x, y) => y.$3.compareTo(x.$3));
    for (final (f, t, _) in moves) {
      final next = copyPegs(pegs);
      final n = ringsMovable(next, f, t);
      for (var i = 0; i < n; i++) {
        next[t].add(next[f].removeLast());
      }
      path.add((f, t));
      if (dfs(next)) return true;
      path.removeLast();
    }
    return false;
  }

  return dfs(copyPegs(start)) ? path : null;
}

/// The puzzle for [level] of a match: the same for every player (it only depends on [seed]),
/// never already sorted and always solvable.
Pegs ringLevel(int seed, int level) {
  final rng = Random(seed * 7919 + level);
  final n = ringColorsFor(level);
  while (true) {
    final rings = [
      for (var c = 0; c < n; c++)
        for (var i = 0; i < ringCapacity; i++) c
    ]..shuffle(rng);
    final pegs = <List<int>>[
      for (var p = 0; p < n; p++)
        rings.sublist(p * ringCapacity, (p + 1) * ringCapacity),
      [],
      []
    ];
    if (!pegsSolved(pegs) && solveRings(pegs) != null) return pegs;
  }
}

/// One player's board in the race.
class RingBoard {
  int level = 1;
  int cleared = 0; // levels finished = score
  Pegs pegs;
  int moves = 0;
  int?
      clearedAt; // game time the current level was solved (shown briefly, then the next one)
  int?
      selected; // the peg this player picked up from (kept on their own phone online)
  final List<Pegs> history = [];
  RingBoard(this.pegs);
}

/// Ring Sort Race: everyone gets the same puzzles in the same order. Tap a peg, then another,
/// to move its top rings onto the same colour or an empty peg. Each sorted board scores a level
/// and deals the next, harder one. Most levels when the time runs out wins.
class RingSortRace extends TimedDuel {
  static const celebrateMs = 900;
  final int seed;
  final List<RingBoard> boards;
  final Map<int, Pegs> _levels = {};

  RingSortRace({int players = 2, int durationMs = 120000, Random? random})
      : this._(players, durationMs, (random ?? Random()).nextInt(1 << 30));

  RingSortRace._(int players, int durationMs, this.seed)
      : boards = [
          for (var i = 0; i < players; i++) RingBoard(ringLevel(seed, 1))
        ],
        super(durationMs);

  @override
  List<int> get scores => [for (final b in boards) b.cleared];

  Pegs _puzzle(int level) =>
      copyPegs(_levels.putIfAbsent(level, () => ringLevel(seed, level)));

  @override
  void onUpdate() {
    for (final b in boards) {
      final at = b.clearedAt;
      if (at != null && elapsedMs - at >= celebrateMs && !isGuest) {
        b.clearedAt = null;
        b.level++;
        b.pegs = _puzzle(b.level);
        b.history.clear();
        b.moves = 0;
        b.selected = null;
      }
    }
  }

  bool _canPlay(int player) =>
      !finished &&
      player >= 0 &&
      player < boards.length &&
      boards[player].clearedAt == null;

  /// A tap on [peg]: pick it up, put the held rings down there, or change the pick.
  /// Picking is local (each phone shows its own); only a real move goes to the host.
  void tap(int player, int peg) {
    if (!_canPlay(player)) return;
    final b = boards[player];
    if (peg < 0 || peg >= b.pegs.length) return;
    final s = b.selected;
    if (s == null || s == peg) {
      b.selected = s == null && b.pegs[peg].isNotEmpty ? peg : null;
    } else if (ringsMovable(b.pegs, s, peg) > 0) {
      b.selected = null;
      move(player, s, peg);
      return;
    } else {
      b.selected = b.pegs[peg].isNotEmpty ? peg : null;
    }
    notifyListeners();
  }

  void move(int player, int from, int to) {
    if (forward('move', [player, from, to])) return;
    if (!_canPlay(player)) return;
    final b = boards[player];
    if (from < 0 || to < 0 || from >= b.pegs.length || to >= b.pegs.length)
      return;
    final n = ringsMovable(b.pegs, from, to);
    if (n == 0) return;
    b.history.add(copyPegs(b.pegs));
    for (var i = 0; i < n; i++) {
      b.pegs[to].add(b.pegs[from].removeLast());
    }
    b.moves++;
    b.selected = null;
    if (pegsSolved(b.pegs)) {
      b.cleared++;
      b.clearedAt = elapsedMs;
    }
    notifyListeners();
  }

  void undo(int player) {
    if (forward('undo', [player])) return;
    if (!_canPlay(player)) return;
    final b = boards[player];
    if (b.history.isEmpty) return;
    b.pegs = b.history.removeLast();
    b.moves = max(0, b.moves - 1);
    b.selected = null;
    notifyListeners();
  }

  void reset(int player) {
    if (forward('reset', [player])) return;
    if (!_canPlay(player)) return;
    final b = boards[player];
    if (b.history.isEmpty) return;
    b.pegs = b.history.first;
    b.history.clear();
    b.moves = 0;
    b.selected = null;
    notifyListeners();
  }

  Map<String, dynamic> save() => {
        't': elapsedMs,
        'b': [
          for (final b in boards)
            {
              'l': b.level,
              'c': b.cleared,
              'p': b.pegs,
              'm': b.moves,
              'at': b.clearedAt
            },
        ],
      };

  void load(Map<String, dynamic> s) {
    elapsedMs = (s['t'] as num).toInt();
    final list = s['b'] as List;
    for (var i = 0; i < boards.length && i < list.length; i++) {
      final m = list[i] as Map;
      final b = boards[i];
      final level = (m['l'] as num).toInt();
      if (level != b.level) b.selected = null;
      b.level = level;
      b.cleared = (m['c'] as num).toInt();
      b.pegs = [
        for (final p in m['p'] as List)
          [for (final r in p as List) (r as num).toInt()]
      ];
      b.moves = (m['m'] as num).toInt();
      b.clearedAt = (m['at'] as num?)?.toInt();
      final sel = b.selected;
      if (sel != null && (sel >= b.pegs.length || b.pegs[sel].isEmpty))
        b.selected = null;
    }
  }
}
