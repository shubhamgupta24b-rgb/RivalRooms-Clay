import 'dart:math';
import 'package:flutter/foundation.dart';
import '../guess_person/models/gp_player.dart';
import 'rmcs_role.dart';

enum RmcsPhase { dealing, peek, rajaReveal, guessing, reveal, finished }

/// Pass-and-play Raja Mantri Chor Sipahi for exactly 4 players on one device.
/// SHUFFLE/DEAL -> each player peeks at their card in turn -> Raja and Mantri revealed ->
/// Mantri has [guessMs] to point at the Chor -> all cards revealed and scored.
class RmcsGame extends ChangeNotifier {
  static const playerCount = 4;
  final List<GpPlayer> players;
  final int totalRounds;
  final int guessMs;
  final Random _random;
  final int Function() _now;

  RmcsPhase phase = RmcsPhase.dealing;
  int round = 1;
  late List<RmcsRole> roles; // roles[i] is player i's card
  final List<int> scores = List.filled(playerCount, 0);
  List<int> lastPoints = List.filled(playerCount, 0);
  int peekIndex = 0;
  bool peekShown = false;
  int _guessStartedAt = 0;
  int? accused;
  bool timedOut = false;

  RmcsGame(
      {List<GpPlayer>? players,
      this.totalRounds = 20,
      this.guessMs = 10000,
      Random? random,
      int Function()? now})
      : players = players ?? defaultPlayers(playerCount),
        _random = random ?? Random(),
        _now = now ?? (() => DateTime.now().millisecondsSinceEpoch) {
    assert(this.players.length == playerCount);
    _deal();
  }

  void _deal() {
    roles = [...RmcsRole.values]..shuffle(_random);
    phase = RmcsPhase.dealing;
    peekIndex = 0;
    peekShown = false;
    accused = null;
    timedOut = false;
    lastPoints = List.filled(playerCount, 0);
  }

  int holder(RmcsRole r) => roles.indexOf(r);
  int get raja => holder(RmcsRole.raja);
  int get mantri => holder(RmcsRole.mantri);
  int get chor => holder(RmcsRole.chor);

  /// The two players the Mantri chooses between, in seat order.
  List<int> get suspects => [
        for (var i = 0; i < playerCount; i++)
          if (roles[i] == RmcsRole.chor || roles[i] == RmcsRole.sipahi) i
      ];

  bool get caught => accused != null && accused == chor;
  bool get isLastRound => round >= totalRounds;

  /// Shuffle/deal animation finished.
  void dealt() {
    if (phase != RmcsPhase.dealing) return;
    phase = RmcsPhase.peek;
    notifyListeners();
  }

  /// The current peeker flips their own card.
  void showPeek() {
    if (phase != RmcsPhase.peek) return;
    peekShown = true;
    notifyListeners();
  }

  /// Hides the card and passes to the next player; after the last one, the Raja is revealed.
  void passPeek() {
    if (phase != RmcsPhase.peek || !peekShown) return;
    peekShown = false;
    peekIndex++;
    if (peekIndex >= playerCount) phase = RmcsPhase.rajaReveal;
    notifyListeners();
  }

  void startGuessing() {
    if (phase != RmcsPhase.rajaReveal) return;
    phase = RmcsPhase.guessing;
    _guessStartedAt = _now();
    notifyListeners();
  }

  int get guessMsLeft => phase == RmcsPhase.guessing
      ? max(0, guessMs - (_now() - _guessStartedAt))
      : 0;
  int get guessSecondsLeft => (guessMsLeft / 1000).ceil();

  /// The Mantri accuses [player]. Returns whether the Chor was caught, or null if not allowed.
  bool? accuse(int player) {
    if (phase != RmcsPhase.guessing || !suspects.contains(player)) return null;
    if (guessMsLeft <= 0) {
      tick();
      return null;
    }
    _resolve(player);
    return caught;
  }

  /// Call regularly while guessing; ends the round when the Mantri runs out of time.
  void tick() {
    if (phase == RmcsPhase.guessing && guessMsLeft <= 0) _resolve(null);
  }

  void _resolve(int? player) {
    accused = player;
    timedOut = player == null;
    final c = caught;
    lastPoints = [for (final r in roles) r.points(caught: c)];
    for (var i = 0; i < playerCount; i++) {
      scores[i] += lastPoints[i];
      players[i].score = scores[i];
    }
    phase = RmcsPhase.reveal;
    notifyListeners();
  }

  void nextRound() {
    if (phase != RmcsPhase.reveal) return;
    if (isLastRound) {
      phase = RmcsPhase.finished;
    } else {
      round++;
      _deal();
    }
    notifyListeners();
  }

  /// Player indexes, best score first.
  List<int> get standings => [for (var i = 0; i < playerCount; i++) i]
    ..sort((a, b) => scores[b] - scores[a]);

  void restart() {
    round = 1;
    scores.fillRange(0, playerCount, 0);
    for (final p in players) {
      p.score = 0;
    }
    _deal();
    notifyListeners();
  }
}
