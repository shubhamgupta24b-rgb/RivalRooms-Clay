import 'dart:math';
import '../shell/local_game_logic.dart';

enum LudoPhase { roll, move, finished }

/// Ludo for 2-4 players. Each player has 4 tokens; progress per token:
/// -1 in base, 0-50 on the shared track (relative to their start), 51-55 their home column,
/// 56 home. Roll a 6 to bring a token out; a 6, a capture or reaching home earns another roll;
/// three 6s in a row lose the turn. Landing on an opponent (off the safe squares) sends it back
/// to base. The first player with all four tokens home wins.
class LudoLogic extends LocalGameLogic {
  static const tokensEach = 4;
  static const home = 56;
  static const safeCells = {0, 8, 13, 21, 26, 34, 39, 47};

  /// The 52 track squares (col, row) on the 15x15 board, clockwise from seat 0's start.
  static const track = [
    (1, 6),
    (2, 6),
    (3, 6),
    (4, 6),
    (5, 6),
    (6, 5),
    (6, 4),
    (6, 3),
    (6, 2),
    (6, 1),
    (6, 0),
    (7, 0),
    (8, 0),
    (8, 1),
    (8, 2),
    (8, 3),
    (8, 4),
    (8, 5),
    (9, 6),
    (10, 6),
    (11, 6),
    (12, 6),
    (13, 6),
    (14, 6),
    (14, 7),
    (14, 8),
    (13, 8),
    (12, 8),
    (11, 8),
    (10, 8),
    (9, 8),
    (8, 9),
    (8, 10),
    (8, 11),
    (8, 12),
    (8, 13),
    (8, 14),
    (7, 14),
    (6, 14),
    (6, 13),
    (6, 12),
    (6, 11),
    (6, 10),
    (6, 9),
    (5, 8),
    (4, 8),
    (3, 8),
    (2, 8),
    (1, 8),
    (0, 8),
    (0, 7),
    (0, 6),
  ];

  /// Home column squares for each seat (top-left, top-right, bottom-right, bottom-left).
  static const homeColumns = [
    [(1, 7), (2, 7), (3, 7), (4, 7), (5, 7)],
    [(7, 1), (7, 2), (7, 3), (7, 4), (7, 5)],
    [(13, 7), (12, 7), (11, 7), (10, 7), (9, 7)],
    [(7, 13), (7, 12), (7, 11), (7, 10), (7, 9)],
  ];

  final int players;

  /// 2 vs 2: players 1+3 against 2+4 (opposite corners). Partners never capture each other,
  /// a player whose tokens are all home moves their partner's, and a team wins together.
  final bool teams;
  final List<int> seats; // seat (board corner) of each player
  final List<List<int>> tokens;
  final Random _random;
  int turn = 0;
  LudoPhase phase = LudoPhase.roll;
  int? lastRoll;
  int rolls = 0;
  int _sixes = 0;
  int get sixesInARow => _sixes;
  set sixesInARow(int v) => _sixes = v;
  int? winner;
  String message = 'Roll a 6 to bring a token out';

  LudoLogic({this.players = 2, bool teams = false, Random? random})
      : assert(players >= 2 && players <= 4),
        teams = teams && players == 4,
        seats =
            players == 2 ? const [0, 2] : [for (var i = 0; i < players; i++) i],
        tokens = List.generate(players, (_) => List.filled(tokensEach, -1)),
        _random = random ?? Random();

  @override
  bool get finished => winner != null;
  @override
  List<int> get scores => [
        for (var i = 0; i < players; i++)
          winner != null && (winner == i || (teams && sameTeam(winner!, i)))
              ? 1
              : 0
      ];

  bool sameTeam(int a, int b) => teams && a % 2 == b % 2;
  int partnerOf(int p) => (p + 2) % 4;
  bool allHome(int p) => tokens[p].every((x) => x == home);

  /// Whose tokens move this turn: yours, or your partner's once all of yours are home.
  int get mover => teams && allHome(turn) ? partnerOf(turn) : turn;
  @override
  void update(int elapsedMs) {}

  int startOf(int player) => seats[player] * 13;

  /// Absolute track index (0-51) of a token, or null when it isn't on the shared track.
  int? trackIndex(int player, int progress) => progress >= 0 && progress <= 50
      ? (startOf(player) + progress) % 52
      : null;

  bool canMove(int player, int token) {
    final r = lastRoll;
    if (r == null || phase != LudoPhase.move || player != mover) return false;
    final p = tokens[player][token];
    if (p == -1) return r == 6;
    return p != home && p + r <= home;
  }

  List<int> get movable => [
        for (var t = 0; t < tokensEach; t++)
          if (canMove(mover, t)) t
      ];

  int? roll([int? value]) {
    if (forward('roll', const [])) return null;
    if (phase != LudoPhase.roll) return null;
    final r = value ?? _random.nextInt(6) + 1;
    lastRoll = r;
    rolls++;
    _sixes = r == 6 ? _sixes + 1 : 0;
    if (_sixes == 3) {
      message = 'Three 6s in a row! Turn lost';
      _next(extra: false);
      return r;
    }
    phase = LudoPhase.move;
    if (movable.isEmpty) {
      message = r == 6 ? 'No moves. Roll again!' : 'No moves with a $r';
      _next(extra: r == 6);
    } else {
      message = 'Tap a glowing token to move $r';
      notifyListeners();
    }
    return r;
  }

  bool move(int token) {
    if (forward('move', [token])) return false;
    final who = mover;
    if (!canMove(who, token)) return false;
    final r = lastRoll!;
    final p = tokens[who][token];
    final np = p == -1 ? 0 : p + r;
    tokens[who][token] = np;
    var captured = false;
    final cell = trackIndex(who, np);
    if (cell != null && !safeCells.contains(cell)) {
      for (var o = 0; o < players; o++) {
        if (o == who || sameTeam(o, who))
          continue; // partners share squares safely
        for (var t = 0; t < tokensEach; t++) {
          if (trackIndex(o, tokens[o][t]) == cell) {
            tokens[o][t] = -1;
            captured = true;
          }
        }
      }
    }
    final reachedHome = np == home;
    if (allHome(who) && (!teams || allHome(partnerOf(who)))) {
      winner = who;
      phase = LudoPhase.finished;
      message =
          teams ? 'Both partners home: the team wins!' : 'All tokens home!';
      notifyListeners();
      return true;
    }
    message = captured
        ? '💥 Captured! Roll again'
        : teams && reachedHome && who == turn && allHome(turn)
            ? '🏠 All home! Now you move your partner\'s tokens'
            : reachedHome
                ? '🏠 Token home! Roll again'
                : r == 6
                    ? 'Rolled a 6: roll again'
                    : '';
    _next(extra: r == 6 || captured || reachedHome);
    return true;
  }

  void _next({required bool extra}) {
    if (!extra) {
      turn = (turn + 1) % players;
      _sixes = 0;
    }
    phase = LudoPhase.roll;
    notifyListeners();
  }

  /// Board square (col, row) of a token that is on the board (not in base, not home).
  (int, int)? squareOf(int player, int progress) {
    if (progress < 0 || progress >= home) return null;
    if (progress <= 50) return track[trackIndex(player, progress)!];
    return homeColumns[seats[player]][progress - 51];
  }
}
