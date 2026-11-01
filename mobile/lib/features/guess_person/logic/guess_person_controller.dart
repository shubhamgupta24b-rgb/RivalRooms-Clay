import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../data/person_data.dart';
import '../models/gp_player.dart';
import '../models/gp_question.dart';
import '../models/person.dart';
import 'gp_rules.dart';
import 'gp_settings.dart';

/// The single authoritative state. The UI renders whatever phase this is.
enum GpPhase {
  roundSetup,
  selectingPerson,
  confirmSelection,
  passDevice,
  guessing,
  finalGuess,
  result,
  gameOver
}

enum GpSfx {
  select,
  question,
  eliminate,
  correct,
  wrong,
  timerWarning,
  gameOver
}

enum GuessPick { ok, eliminated, invalid }

class RoundResult {
  final RoundOutcome outcome;
  final Person secret;
  final Person? guessed;
  final GpPlayer guesser;
  final int points;
  const RoundResult(
      {required this.outcome,
      required this.secret,
      required this.guessed,
      required this.guesser,
      required this.points});
}

/// Local pass-and-play Guess the Person. Everything runs on this device; the online
/// GameSessionManager is not involved because there is no server round-trip.
class GuessPersonController extends ChangeNotifier {
  final GpSettings settings;
  final List<GpPlayer> players;
  final List<Person> _cast;
  final Random _rng;
  final void Function(GpSfx)? onSfx;

  GuessPersonController(
      {GpSettings? settings,
      List<GpPlayer>? players,
      List<Person>? cast,
      Random? random,
      this.onSfx})
      : settings = settings ?? const GpSettings(),
        players = players ?? defaultPlayers(),
        _cast = List.unmodifiable(cast ?? allPeople),
        _rng = random ?? Random();

  GpPhase phase = GpPhase.roundSetup;
  int round = 1;
  List<Person> people = const [];
  List<GpQuestion> questions = const [];
  final Set<int> eliminated = {};
  final List<AskedQuestion> history = [];
  AskedQuestion? lastAnswer;
  int? selectedId; // chooser's highlighted card (before confirming)
  int? pendingGuessId; // guesser's card awaiting "Is this your final guess?"
  int secondsLeft = 0;
  RoundResult? result;

  int? _secretId; // never exposed while the round is running
  int? _lastSecretId;
  Timer? _timer;
  bool _disposed = false;

  int get totalRounds => settings.rounds;
  bool get isLastRound => round >= totalRounds;
  int get chooserIndex => (round - 1) % players.length;
  int get guesserIndex => (chooserIndex + 1) % players.length;
  GpPlayer get chooser => players[chooserIndex];
  GpPlayer get guesser => players[guesserIndex];
  int get peopleLeft => people.length - eliminated.length;
  bool get hasEnoughPeople => people.length >= 2;
  bool get timerRunning => _timer?.isActive ?? false;
  Person? get selectedPerson => _byId(selectedId);
  Person? get pendingGuess => _byId(pendingGuessId);
  bool wasAsked(GpQuestion q) => history.any((h) => h.question.id == q.id);

  /// Highest scorers; more than one means a draw.
  List<GpPlayer> get leaders {
    final top = players.map((p) => p.score).reduce(max);
    return players.where((p) => p.score == top).toList();
  }

  bool get isDraw => leaders.length > 1;

  Person? _byId(int? id) {
    if (id == null) return null;
    for (final p in people) {
      if (p.id == id) return p;
    }
    return null;
  }

  // ---- match flow ----

  void startGame() {
    _stopTimer();
    for (final p in players) {
      p.score = 0;
    }
    round = 1;
    _lastSecretId = null;
    startRound();
  }

  void resetGame() => startGame();

  void startRound() {
    _stopTimer();
    final count = settings.peopleCount.clamp(0, _cast.length);
    people = (List.of(_cast)..shuffle(_rng)).take(count).toList()
      ..shuffle(_rng);
    questions = buildQuestions(people);
    eliminated.clear();
    history.clear();
    lastAnswer = null;
    selectedId = null;
    pendingGuessId = null;
    _secretId = null;
    result = null;
    secondsLeft = settings.timerSeconds;
    phase = GpPhase.roundSetup;
    _notify();
  }

  void beginSelection() {
    if (phase != GpPhase.roundSetup || !hasEnoughPeople) return;
    phase = GpPhase.selectingPerson;
    _notify();
  }

  // ---- chooser ----

  void selectSecretPerson(int id) {
    if (phase != GpPhase.selectingPerson || _byId(id) == null) return;
    selectedId = id;
    _sfx(GpSfx.select);
    _notify();
  }

  /// Random pick that avoids repeating last round's secret when possible.
  void selectRandomPerson() {
    if (phase != GpPhase.selectingPerson || people.isEmpty) return;
    final pool = people.where((p) => p.id != _lastSecretId).toList();
    final from = pool.isEmpty ? people : pool;
    selectSecretPerson(from[_rng.nextInt(from.length)].id);
  }

  void requestConfirm() {
    if (phase != GpPhase.selectingPerson || selectedPerson == null) return;
    phase = GpPhase.confirmSelection;
    _notify();
  }

  void changeSelection() {
    if (phase != GpPhase.confirmSelection) return;
    phase = GpPhase.selectingPerson;
    _notify();
  }

  void confirmSecretPerson() {
    if (phase != GpPhase.confirmSelection || selectedPerson == null) return;
    _secretId = selectedId;
    _lastSecretId = selectedId;
    selectedId =
        null; // nothing selection-related survives into the guesser's view
    phase = GpPhase.passDevice;
    _notify();
  }

  // ---- guesser ----

  void switchToGuessing() {
    if (phase != GpPhase.passDevice) return;
    if (_byId(_secretId) == null) {
      // Should not happen, but recover by letting the chooser pick again.
      _secretId = null;
      phase = GpPhase.selectingPerson;
      _notify();
      return;
    }
    secondsLeft = settings.timerSeconds;
    phase = GpPhase.guessing;
    if (settings.hasTimer) _startTimer();
    _notify();
  }

  /// Returns false if the question was already asked or can't be asked now.
  bool askQuestion(GpQuestion q) {
    if (phase != GpPhase.guessing || wasAsked(q)) return false;
    final asked = AskedQuestion(q, answerQuestion(q));
    history.add(asked);
    lastAnswer = asked;
    if (settings.autoEliminate) {
      for (final p in people) {
        if (q.test(p) != asked.answer) eliminated.add(p.id);
      }
    }
    _sfx(GpSfx.question);
    _notify();
    return true;
  }

  /// Answers come only from the secret person's real attributes.
  bool answerQuestion(GpQuestion q) {
    final secret = _byId(_secretId);
    if (secret == null) throw StateError('No secret person this round');
    return q.test(secret);
  }

  /// Toggles elimination so a mis-tap can be undone.
  void eliminatePerson(int id) {
    if (phase != GpPhase.guessing || _byId(id) == null) return;
    if (!eliminated.remove(id)) eliminated.add(id);
    _sfx(GpSfx.eliminate);
    _notify();
  }

  void startFinalGuess() {
    if (phase != GpPhase.guessing) return;
    pendingGuessId = null;
    phase = GpPhase.finalGuess;
    _notify();
  }

  GuessPick chooseGuess(int id) {
    if (phase != GpPhase.finalGuess || _byId(id) == null)
      return GuessPick.invalid;
    if (eliminated.contains(id)) return GuessPick.eliminated;
    pendingGuessId = id;
    _sfx(GpSfx.select);
    _notify();
    return GuessPick.ok;
  }

  /// Cancel backs out one step: first the pending pick, then final-guess mode.
  void cancelFinalGuess() {
    if (phase != GpPhase.finalGuess) return;
    if (pendingGuessId != null) {
      pendingGuessId = null;
    } else {
      phase = GpPhase.guessing;
    }
    _notify();
  }

  void makeFinalGuess() {
    final guess = pendingGuess;
    if (phase != GpPhase.finalGuess ||
        guess == null ||
        eliminated.contains(guess.id)) return;
    if (guess.id == _secretId) {
      handleCorrectGuess(guess);
    } else {
      handleWrongGuess(guess);
    }
  }

  void handleCorrectGuess(Person guess) =>
      _endRound(RoundOutcome.correct, guess);
  void handleWrongGuess(Person guess) => _endRound(RoundOutcome.wrong, guess);

  void handleTimeUp() {
    if (phase != GpPhase.guessing && phase != GpPhase.finalGuess) return;
    _endRound(RoundOutcome.timeUp, null);
  }

  void _endRound(RoundOutcome outcome, Person? guessed) {
    _stopTimer();
    final secret = _byId(_secretId);
    if (secret == null) return;
    final pts = pointsFor(outcome);
    guesser.score += pts;
    result = RoundResult(
        outcome: outcome,
        secret: secret,
        guessed: guessed,
        guesser: guesser,
        points: pts);
    pendingGuessId = null;
    phase = GpPhase.result;
    _sfx(outcome == RoundOutcome.correct ? GpSfx.correct : GpSfx.wrong);
    _notify();
  }

  void nextRound() {
    if (phase != GpPhase.result) return;
    if (isLastRound) {
      endGame();
      return;
    }
    round++;
    startRound();
  }

  void endGame() {
    _stopTimer();
    phase = GpPhase.gameOver;
    _sfx(GpSfx.gameOver);
    _notify();
  }

  // ---- timer ----

  void _startTimer() {
    _stopTimer(); // never two timers at once
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @visibleForTesting
  void tick() {
    if (_disposed ||
        (phase != GpPhase.guessing && phase != GpPhase.finalGuess)) {
      _stopTimer();
      return;
    }
    secondsLeft = max(0, secondsLeft - 1);
    if (secondsLeft == 0) {
      handleTimeUp();
      return;
    }
    if (secondsLeft == 10 || secondsLeft <= 5) _sfx(GpSfx.timerWarning);
    _notify();
  }

  void _sfx(GpSfx s) {
    if (!settings.sound) return;
    try {
      onSfx?.call(s);
    } catch (_) {
      // Sound is cosmetic; never let it break the game.
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _stopTimer();
    super.dispose();
  }
}
