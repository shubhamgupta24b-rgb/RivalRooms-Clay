import 'dart:math';
import 'package:flutter/services.dart';
import '../shell/local_game_info.dart';
import 'hex_sort.dart';
import 'solo_common.dart';

// Candy colours, picked to stay easy to tell apart.
const _ballColors = [
  Color(0xFFFF4D6D),
  Color(0xFF3A86FF),
  Color(0xFF2EC4B6),
  Color(0xFFFFBE0B),
  Color(0xFF9B5DE5),
  Color(0xFFFF8C42),
  Color(0xFF00BBF9),
  Color(0xFFF15BB5),
  Color(0xFF8D6346),
  Color(0xFF80ED99),
];

/// Ball Sort: tubes of 4 coloured balls. Tap a tube, then another, to pour its top ball(s)
/// onto a matching colour or into an empty tube. Fill every tube with one colour to clear
/// the level. Each level adds a colour. Score = levels cleared.
class BallSortLogic extends SoloLogic {
  static const capacity = 4;
  final Random rng;
  int level = 1;
  List<List<int>> tubes = [];
  final List<List<List<int>>> _history = [];
  int? selected;
  int moves = 0;
  int? clearedAt; // when the level was just cleared (for the celebration)

  BallSortLogic({Random? random}) : rng = random ?? Random() {
    _newLevel();
  }

  int get colors => min(3 + level, _ballColors.length);

  void _newLevel() {
    final n = colors;
    // Deal 4 balls of each colour across n tubes, then 2 empty tubes; avoid starting solved.
    do {
      final balls = [
        for (var c = 0; c < n; c++)
          for (var i = 0; i < capacity; i++) c
      ]..shuffle(rng);
      tubes = [
        for (var t = 0; t < n; t++)
          balls.sublist(t * capacity, (t + 1) * capacity),
        <int>[],
        <int>[]
      ];
    } while (solved);
    _history.clear();
    selected = null;
    moves = 0;
  }

  bool get solved => tubes.every((t) =>
      t.isEmpty || (t.length == capacity && t.every((b) => b == t.first)));

  /// How many balls would pour from [from] to [to] (0 if that's not allowed).
  int pourable(int from, int to) {
    if (from == to) return 0;
    final a = tubes[from], b = tubes[to];
    if (a.isEmpty || b.length >= capacity) return 0;
    if (b.isNotEmpty && b.last != a.last) return 0;
    var run = 1;
    while (run < a.length && a[a.length - 1 - run] == a.last) {
      run++;
    }
    return min(run, capacity - b.length);
  }

  void tap(int tube) {
    if (over || clearedAt != null) return;
    final s = selected;
    if (s == null) {
      if (tubes[tube].isNotEmpty) selected = tube;
    } else if (s == tube) {
      selected = null;
    } else {
      final n = pourable(s, tube);
      if (n > 0) {
        _history.add([for (final t in tubes) List.of(t)]);
        for (var i = 0; i < n; i++) {
          tubes[tube].add(tubes[s].removeLast());
        }
        moves++;
        selected = null;
        HapticFeedback.selectionClick().ignore();
        if (solved) {
          score = level;
          clearedAt = now;
          HapticFeedback.mediumImpact().ignore();
        }
      } else {
        selected = tubes[tube].isNotEmpty ? tube : null;
      }
    }
    notifyListeners();
  }

  void undo() {
    if (_history.isEmpty || clearedAt != null) return;
    tubes = _history.removeLast();
    selected = null;
    moves = max(0, moves - 1);
    notifyListeners();
  }

  void restart() {
    if (clearedAt != null) return;
    if (_history.isNotEmpty) tubes = _history.first;
    _history.clear();
    selected = null;
    moves = 0;
    notifyListeners();
  }

  void finish() => gameOver(300);

  @override
  void step(int now) {
    final at = clearedAt;
    if (at != null && now - at > 1300) {
      clearedAt = null;
      level++;
      _newLevel();
      notifyListeners();
    }
  }
}

final ballSortInfo = LocalGameInfo(
  id: 'ball_sort',
  title: 'Ball Sort',
  emoji: '🧪',
  color: const Color(0xFFFF6B8A),
  tagline: 'Sort coloured balls inside hexagonal rings!',
  rules: const [
    'Each difficulty has 50 levels. Clear one to unlock the next.',
    'Tap a ring, then another, to pour the top balls onto the same colour or into an empty ring.',
    'Undo, restart, or take a hint. Works with no internet.',
  ],
  scoreUnit: 'levels',
  splitScreen: false,
  minPlayers: 1,
  maxPlayers: 1,
  play: (players, onFinished) => HexSortScreen(onFinished: onFinished),
);
