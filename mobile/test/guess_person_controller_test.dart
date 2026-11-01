import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/features/guess_person/data/person_data.dart';
import 'package:multiplayer_game/features/guess_person/logic/gp_rules.dart';
import 'package:multiplayer_game/features/guess_person/logic/gp_settings.dart';
import 'package:multiplayer_game/features/guess_person/logic/guess_person_controller.dart';
import 'package:multiplayer_game/features/guess_person/models/person.dart';

GuessPersonController newGame(
        {GpSettings settings =
            const GpSettings(rounds: 3, timerSeconds: 30)}) =>
    GuessPersonController(settings: settings, random: Random(1))..startGame();

/// Plays up to the guessing phase with [secret] as the chosen person.
Person setupGuessing(GuessPersonController c, {Person? secret}) {
  final s = secret ?? c.people.first;
  c.beginSelection();
  c.selectSecretPerson(s.id);
  c.requestConfirm();
  c.confirmSecretPerson();
  c.switchToGuessing();
  return s;
}

void main() {
  group('dataset', () {
    test('30 people with unique ids and names', () {
      expect(allPeople, hasLength(30));
      expect(allPeople.map((p) => p.id).toSet(), hasLength(30));
      expect(allPeople.map((p) => p.name).toSet(), hasLength(30));
      expect(allPeople.where((p) => p.gender == Gender.female), hasLength(15));
    });

    test('the main yes/no traits are reasonably balanced (25%-75%)', () {
      final n = allPeople.length;
      const balanced = {'male', 'female', 'glasses', 'hat', 'long_hair'};
      final qs = buildQuestions(allPeople)
          .where((q) => balanced.contains(q.id))
          .toList();
      expect(qs, hasLength(balanced.length));
      for (final q in qs) {
        expect(allPeople.where(q.test).length / n, inInclusiveRange(0.25, 0.75),
            reason: q.id);
      }
    });

    test(
        'every question belongs to a category, and every category has questions',
        () {
      final qs = buildQuestions(allPeople);
      final ids = gpCategories.map((c) => c.id).toSet();
      for (final q in qs) {
        expect(ids, contains(q.category), reason: q.id);
      }
      for (final c in gpCategories) {
        expect(qs.where((q) => q.category == c.id), isNotEmpty, reason: c.id);
      }
    });

    test(
        'bearded people also answer YES to mustache, bald people have no hair colour',
        () {
      for (final p in allPeople.where((p) => p.hasBeard)) {
        expect(p.hasMustache, isTrue, reason: p.name);
      }
      final hairQs =
          buildQuestions(allPeople).where((q) => q.category == 'hair_color');
      for (final p in allPeople.where((p) => p.isBald)) {
        expect(hairQs.any((q) => q.test(p)), isFalse, reason: p.name);
      }
    });

    test('every pair of people can be told apart by some question', () {
      final qs = buildQuestions(allPeople);
      for (final a in allPeople) {
        for (final b in allPeople.where((b) => b.id > a.id)) {
          expect(qs.any((q) => q.test(a) != q.test(b)), isTrue,
              reason: '${a.name} vs ${b.name}');
        }
      }
    });
  });

  group('flow', () {
    test('selection is hidden after confirm and the guesser gets the device',
        () {
      final c = newGame();
      expect(c.phase, GpPhase.roundSetup);
      c.beginSelection();
      c.selectSecretPerson(c.people[3].id);
      expect(c.selectedId, c.people[3].id);
      c.requestConfirm();
      expect(c.phase, GpPhase.confirmSelection);
      c.changeSelection();
      expect(c.phase, GpPhase.selectingPerson);
      c.requestConfirm();
      c.confirmSecretPerson();
      expect(c.phase, GpPhase.passDevice);
      expect(c.selectedId, isNull);
      expect(c.selectedPerson, isNull);
      c.switchToGuessing();
      expect(c.phase, GpPhase.guessing);
      expect(c.timerRunning, isTrue);
      c.dispose();
    });

    test(
        'answers come from the secret person, and repeated questions are refused',
        () {
      final c = newGame();
      final secret = setupGuessing(c);
      for (final q in c.questions) {
        expect(c.askQuestion(q), isTrue);
        expect(c.lastAnswer!.answer, q.test(secret), reason: q.id);
        expect(c.askQuestion(q), isFalse);
      }
      expect(c.history.length, c.questions.length);
      c.dispose();
    });

    test('eliminated people cannot be the final guess', () {
      final c = newGame();
      final secret = setupGuessing(c);
      final other = c.people.firstWhere((p) => p.id != secret.id);
      c.eliminatePerson(other.id);
      expect(c.peopleLeft, c.people.length - 1);
      c.startFinalGuess();
      expect(c.chooseGuess(other.id), GuessPick.eliminated);
      expect(c.pendingGuessId, isNull);
      expect(c.phase, GpPhase.finalGuess);
      c.dispose();
    });

    test('correct guess scores +1 for the guesser and stops the timer', () {
      final c = newGame();
      final secret = setupGuessing(c);
      c.startFinalGuess();
      expect(c.chooseGuess(secret.id), GuessPick.ok);
      c.makeFinalGuess();
      expect(c.phase, GpPhase.result);
      expect(c.result!.outcome, RoundOutcome.correct);
      expect(c.players[1].score, 1);
      expect(c.players[0].score, 0);
      expect(c.timerRunning, isFalse);
      c.dispose();
    });

    test('wrong guess scores 0', () {
      final c = newGame();
      final secret = setupGuessing(c);
      c.startFinalGuess();
      c.chooseGuess(c.people.firstWhere((p) => p.id != secret.id).id);
      c.makeFinalGuess();
      expect(c.result!.outcome, RoundOutcome.wrong);
      expect(c.result!.secret.id, secret.id);
      expect(c.players.every((p) => p.score == 0), isTrue);
      c.dispose();
    });

    test('timer reaching zero ends the round with 0 points', () {
      final c =
          newGame(settings: const GpSettings(rounds: 3, timerSeconds: 15));
      setupGuessing(c);
      for (var i = 0; i < 14; i++) {
        c.tick();
      }
      expect(c.phase, GpPhase.guessing);
      expect(c.secondsLeft, 1);
      c.tick();
      expect(c.phase, GpPhase.result);
      expect(c.result!.outcome, RoundOutcome.timeUp);
      expect(c.players.every((p) => p.score == 0), isTrue);
      expect(c.timerRunning, isFalse);
      c.dispose();
    });

    test(
        'roles alternate, final score and winner come from real scores, play again resets',
        () {
      final c = newGame();
      final choosers = <int>[];
      for (var r = 1; r <= 3; r++) {
        choosers.add(c.chooserIndex);
        final secret = setupGuessing(c);
        c.startFinalGuess();
        // Only the guesser in round 2 (player 1) gets it right.
        final pick =
            r == 2 ? secret : c.people.firstWhere((p) => p.id != secret.id);
        c.chooseGuess(pick.id);
        c.makeFinalGuess();
        c.nextRound();
      }
      expect(choosers, [0, 1, 0]);
      expect(c.phase, GpPhase.gameOver);
      expect(c.players[0].score, 1);
      expect(c.isDraw, isFalse);
      expect(c.leaders.single, c.players[0]);

      c.resetGame();
      expect(c.phase, GpPhase.roundSetup);
      expect(c.round, 1);
      expect(c.players.every((p) => p.score == 0), isTrue);
      expect(c.eliminated, isEmpty);
      expect(c.history, isEmpty);
      expect(c.result, isNull);
      expect(c.secondsLeft, 30);
      c.dispose();
    });

    test('equal scores are a draw', () {
      final c = newGame();
      expect(c.isDraw, isTrue);
      c.dispose();
    });

    test('auto elimination removes everyone who does not match', () {
      final c = newGame(settings: const GpSettings(autoEliminate: true));
      final secret = setupGuessing(c);
      final q = c.questions.first;
      c.askQuestion(q);
      for (final p in c.people) {
        expect(c.eliminated.contains(p.id), q.test(p) != q.test(secret));
      }
      c.dispose();
    });

    test('no-timer mode (the default) never starts a countdown', () {
      expect(const GpSettings().hasTimer, isFalse);
      final c = newGame(settings: const GpSettings());
      setupGuessing(c);
      expect(c.timerRunning, isFalse);
      expect(c.phase, GpPhase.guessing);
      c.dispose();
    });

    test('disposing mid-round stops the timer', () {
      final c = newGame();
      setupGuessing(c);
      expect(c.timerRunning, isTrue);
      c.dispose();
      expect(c.timerRunning, isFalse);
    });

    test('invalid ids are ignored', () {
      final c = newGame();
      c.beginSelection();
      c.selectSecretPerson(9999);
      expect(c.selectedId, isNull);
      c.requestConfirm();
      expect(c.phase, GpPhase.selectingPerson);
      c.dispose();
    });
  });
}
