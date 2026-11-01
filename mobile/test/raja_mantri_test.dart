import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/features/guess_person/models/gp_player.dart';
import 'package:multiplayer_game/features/local_games/local_games_hub_screen.dart';
import 'package:multiplayer_game/features/raja_mantri/rmcs_game.dart';
import 'package:multiplayer_game/features/raja_mantri/rmcs_role.dart';
import 'package:multiplayer_game/features/raja_mantri/rmcs_screen.dart';
import 'package:multiplayer_game/games/raja_mantri/raja_mantri_screen.dart';
import 'online_game_screens_test.dart'
    show FakeSession, pumpGame, disposeGame, expectCall;

/// Lets a card flip run: one frame to start it, then enough time to finish.
Future<void> flip(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1200));
}

/// Walks a game from dealing to the Mantri's turn.
void toGuessing(RmcsGame g) {
  g.dealt();
  for (var i = 0; i < 4; i++) {
    g.showPeek();
    g.passPeek();
  }
  g.startGuessing();
}

void main() {
  group('Raja Mantri rules', () {
    test('points table', () {
      expect([for (final r in RmcsRole.values) r.points(caught: true)],
          [1000, 500, 300, 0]);
      expect([for (final r in RmcsRole.values) r.points(caught: false)],
          [1000, 0, 300, 500]);
    });

    test('every deal hands out each role once; suspects are Sipahi and Chor',
        () {
      final g = RmcsGame(random: Random(1));
      final seen = <String>{};
      for (var r = 0; r < 30; r++) {
        expect(g.roles.toSet(), RmcsRole.values.toSet());
        expect(g.suspects.map((i) => g.roles[i]).toSet(),
            {RmcsRole.sipahi, RmcsRole.chor});
        seen.add(g.roles.join());
        toGuessing(g);
        g.accuse(g.chor);
        g.nextRound();
      }
      expect(seen.length, greaterThan(5), reason: 'really shuffled');
    });

    test('peeking goes round all four players before the Raja is revealed', () {
      final g = RmcsGame(random: Random(2));
      expect(g.phase, RmcsPhase.dealing);
      g.showPeek();
      expect(g.peekShown, isFalse, reason: 'not before the deal is done');
      g.dealt();
      expect(g.phase, RmcsPhase.peek);
      g.passPeek();
      expect(g.peekIndex, 0, reason: 'must look before passing');
      for (var i = 0; i < 4; i++) {
        expect(g.peekIndex, i);
        g.showPeek();
        expect(g.peekShown, isTrue);
        g.passPeek();
        expect(g.peekShown, isFalse);
      }
      expect(g.phase, RmcsPhase.rajaReveal);
    });

    test('Mantri catches the Chor: 1800 points; only suspects can be accused',
        () {
      final g = RmcsGame(random: Random(3));
      toGuessing(g);
      expect(g.accuse(g.raja), isNull);
      expect(g.accuse(g.mantri), isNull);
      expect(g.accuse(g.chor), isTrue);
      expect(g.phase, RmcsPhase.reveal);
      expect(g.lastPoints.reduce((a, b) => a + b), 1800);
      expect(g.scores[g.raja], 1000);
      expect(g.scores[g.mantri], 500);
      expect(g.scores[g.holder(RmcsRole.sipahi)], 300);
      expect(g.scores[g.chor], 0);
      expect(g.accuse(g.chor), isNull, reason: 'one guess per round');
    });

    test('wrong guess: Chor escapes with 500, Mantri gets nothing', () {
      final g = RmcsGame(random: Random(4));
      toGuessing(g);
      expect(g.accuse(g.holder(RmcsRole.sipahi)), isFalse);
      expect(g.caught, isFalse);
      expect(g.scores[g.chor], 500);
      expect(g.scores[g.mantri], 0);
      expect(g.scores[g.raja], 1000);
    });

    test('10 seconds then time is up and the Chor escapes', () {
      var clock = 0;
      final g = RmcsGame(random: Random(5), now: () => clock);
      toGuessing(g);
      expect(g.guessSecondsLeft, 10);
      clock = 9999;
      g.tick();
      expect(g.phase, RmcsPhase.guessing);
      expect(g.guessSecondsLeft, 1);
      clock = 10000;
      expect(g.accuse(g.chor), isNull, reason: 'too late');
      expect(g.phase, RmcsPhase.reveal);
      expect(g.timedOut, isTrue);
      expect(g.accused, isNull);
      expect(g.scores[g.chor], 500);
    });

    test('20 rounds add up, then finished; restart clears everything', () {
      final g = RmcsGame(random: Random(6), players: defaultPlayers(4));
      final totals = List.filled(4, 0);
      for (var r = 1; r <= 20; r++) {
        expect(g.round, r);
        toGuessing(g);
        g.accuse(r.isEven ? g.chor : g.holder(RmcsRole.sipahi));
        for (var i = 0; i < 4; i++) {
          totals[i] += g.lastPoints[i];
        }
        expect(g.isLastRound, r == 20);
        g.nextRound();
      }
      expect(g.phase, RmcsPhase.finished);
      expect(g.scores, totals);
      expect(g.scores.reduce((a, b) => a + b), 10 * 1800 + 10 * 1800);
      expect(g.players.map((p) => p.score), totals);
      expect(g.scores[g.standings.first], g.scores.reduce(max));
      g.restart();
      expect(g.round, 1);
      expect(g.scores, [0, 0, 0, 0]);
      expect(g.phase, RmcsPhase.dealing);
    });
  });

  group('Raja Mantri on one device', () {
    for (final size in const [
      Size(320, 568),
      Size(411, 914),
      Size(800, 1280)
    ]) {
      testWidgets(
          'a full round from the hub on ${size.width.toInt()}x${size.height.toInt()}',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(const MaterialApp(home: LocalGamesHubScreen()));
        expect(find.text('$totalGameCount games'), findsOneWidget);
        await tester.ensureVisible(find.text('Raja Mantri Chor Sipahi'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Raja Mantri Chor Sipahi'));
        await tester.pumpAndSettle();

        // Small phones: the name fields start below the fold.
        while (find.byType(TextField).evaluate().isEmpty) {
          await tester.drag(find.byType(ListView), const Offset(0, -200));
          await tester.pump();
        }
        await tester.enterText(find.byType(TextField).first, 'Asha');
        await tester.scrollUntilVisible(find.text('Deal the cards'), 200,
            scrollable: find.byType(Scrollable).first);
        await tester.tap(find.text('Deal the cards'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('Round 1 / 20'), findsOneWidget);
        expect(find.text('SHUFFLING…'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 2400));

        // Each player peeks in turn.
        expect(find.text('Pass the phone to Asha'), findsOneWidget);
        for (var i = 0; i < 4; i++) {
          await tester.tap(find.text('TAP TO REVEAL'));
          await flip(tester);
          expect(find.textContaining('Remember your card'), findsOneWidget);
          await tester.tap(find.textContaining('Hide card'));
          await flip(tester);
        }

        // Raja, then Mantri.
        expect(find.textContaining('is the RAJA!'), findsWidgets);
        expect(find.text('RAJA'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 1200));
        await flip(tester); // flip
        expect(find.text('MANTRI'), findsOneWidget);
        expect(find.text('CHOR'), findsNothing, reason: 'Chor still hidden');
        await tester.tap(find.text('Mantri: find the Chor (10s)'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.textContaining('who is the CHOR?'), findsOneWidget);
        expect(find.text('TAP TO ACCUSE'), findsNWidgets(2));

        await tester.tap(find.text('TAP TO ACCUSE').first);
        await tester.pump(const Duration(milliseconds: 1500));
        final caught = find.text('Chor caught!').evaluate().isNotEmpty;
        expect(
            caught ||
                find.text('Wrong guess: Chor escaped!').evaluate().isNotEmpty,
            isTrue);
        expect(find.text('CHOR'), findsOneWidget, reason: 'all cards revealed');
        expect(find.text('+1000'), findsOneWidget);
        expect(find.text('1000 pts'), findsOneWidget);
        await tester.tap(find.text('Next round (2/20)'));
        await tester.pump();
        expect(find.text('Round 2 / 20'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 3));
      });
    }

    testWidgets('players choose how many rounds', (tester) async {
      tester.view.physicalSize = const Size(411, 914);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: RmcsMenuScreen()));
      expect(find.text('4 PLAYERS · 20 ROUNDS · ONE PHONE'), findsOneWidget,
          reason: 'default');
      await tester.scrollUntilVisible(find.text('5'), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('5'));
      await tester.pump();
      expect(find.text('Quick game · about 5 minutes'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Deal the cards'), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Deal the cards'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Round 1 / 5'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('Mantri too slow: chor escapes; last round shows final results',
        (tester) async {
      var clock = 0;
      final g = RmcsGame(totalRounds: 1, random: Random(7), now: () => clock);
      await tester.pumpWidget(MaterialApp(home: RmcsGameScreen(game: g)));
      await tester.pump(const Duration(milliseconds: 2400));
      toGuessing(g);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('10'), findsOneWidget, reason: 'countdown');
      clock = 10000;
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Wrong guess: Chor escaped!'), findsOneWidget);
      expect(find.text("Time's up! The Mantri didn't choose."), findsOneWidget);
      await tester.tap(find.text('See final results'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(
          find
                  .textContaining(' wins!', findRichText: true)
                  .evaluate()
                  .isNotEmpty ||
              find.text("It's a draw!").evaluate().isNotEmpty,
          isTrue);
      expect(find.bySemanticsLabel(RegExp('^Place 1, ')), findsWidgets);
      await tester.ensureVisible(find.text('Rematch'));
      await tester.tap(find.text('Rematch'));
      await tester.pump();
      expect(g.round, 1);
      expect(find.text('SHUFFLING…'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('Raja Mantri online', () {
    final now = DateTime.now().millisecondsSinceEpoch;
    final people = [
      {'userId': 'me', 'username': 'Me'},
      {'userId': 'b', 'username': 'Bina'},
      {'userId': 'c', 'username': 'Chetan'},
      {'userId': 'd', 'username': 'Dev'},
    ];
    Map<String, dynamic> state(String phase,
            {String yourRole = 'mantri',
            Map<String, String>? roles,
            Map<String, dynamic>? result}) =>
        {
          'gameType': 'raja_mantri',
          'phase': phase,
          'round': 3,
          'totalRounds': 20,
          'players': people,
          'scores': {'me': 1500, 'b': 300, 'c': 1000, 'd': 500},
          'yourRole': yourRole,
          'roles': roles ?? {'me': yourRole},
          'phaseEndsAt': now + 8000,
          'guessMs': 10000,
          'result': result,
        };

    testWidgets('dealing: only I can turn my card over', (tester) async {
      final s = FakeSession(state('dealing', yourRole: 'sipahi'));
      await pumpGame(tester, const RajaMantriScreen(), s);
      expect(find.text('ROUND 3 / 20'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 2400)); // shuffle + deal
      expect(find.text('ME (YOU)'), findsOneWidget);
      expect(find.text('SIPAHI'), findsNothing);
      await tester.tap(find.text('TAP TO SEE YOUR CARD'));
      await flip(tester);
      expect(find.text('SIPAHI'), findsOneWidget);
      expect(find.text('You are the SIPAHI'), findsOneWidget);
      expect(find.text('1500 pts'), findsOneWidget);
      await disposeGame(tester);
    });

    testWidgets('guessing as the Mantri sends the accusation', (tester) async {
      final s =
          FakeSession(state('guessing', roles: {'me': 'mantri', 'c': 'raja'}));
      await pumpGame(tester, const RajaMantriScreen(), s);
      await flip(tester);
      expect(find.text('Who is the CHOR?'), findsOneWidget);
      expect(find.text('Tap Bina or Dev.'), findsOneWidget);
      expect(find.text('TAP TO ACCUSE'), findsNWidgets(2));
      await tester.tap(find.text('DEV'));
      await tester.pump();
      expectCall(s, 'raja_mantri:guess', {'targetId': 'd'});
      await disposeGame(tester);
    });

    testWidgets('guessing as someone else just watches', (tester) async {
      final s = FakeSession(state('guessing',
          yourRole: 'chor', roles: {'me': 'chor', 'b': 'mantri', 'c': 'raja'}));
      await pumpGame(tester, const RajaMantriScreen(), s);
      await flip(tester);
      expect(find.text('Bina is choosing…'), findsOneWidget);
      expect(find.text('Act natural…'), findsOneWidget);
      expect(find.text('TAP TO ACCUSE'), findsNothing);
      await disposeGame(tester);
    });

    testWidgets('reveal shows every card, the result and points',
        (tester) async {
      const roles = {'me': 'mantri', 'b': 'sipahi', 'c': 'raja', 'd': 'chor'};
      final s = FakeSession(state('reveal', roles: roles, result: {
        'guess': 'd',
        'chorId': 'd',
        'caught': true,
        'timedOut': false,
        'points': {'me': 500, 'b': 300, 'c': 1000, 'd': 0},
        'roles': roles,
      }));
      await pumpGame(tester, const RajaMantriScreen(), s);
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.text('Chor caught!'), findsOneWidget);
      for (final t in [
        'RAJA',
        'MANTRI',
        'SIPAHI',
        'CHOR',
        'CAUGHT!',
        '+1000',
        '+500',
        '+300',
        '+0'
      ]) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      expect(find.textContaining('Next round in'), findsOneWidget);
      await disposeGame(tester);
    });
  });
}
