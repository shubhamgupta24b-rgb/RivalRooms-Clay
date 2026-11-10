import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:multiplayer_game/features/guess_person/data/person_data.dart';
import 'package:multiplayer_game/games/guess_who/guess_who_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/core/auth/authentication_manager.dart';
import 'package:multiplayer_game/core/network/socket_manager.dart';
import 'package:multiplayer_game/core/session/game_session_manager.dart';
import 'package:multiplayer_game/games/basketball_hoops/basketball_hoops_screen.dart';
import 'package:multiplayer_game/games/crush_it/crush_it_screen.dart';
import 'package:multiplayer_game/games/fruit_duel/fruit_duel_screen.dart';
import 'package:multiplayer_game/games/game_catalog.dart';
import 'package:multiplayer_game/games/game_module.dart';
import 'package:multiplayer_game/games/guess_person/guess_person_screen.dart';
import 'package:multiplayer_game/games/memory/memory_screen.dart';
import 'package:multiplayer_game/games/paint_fight/paint_fight_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stands in for the server: holds a fixed game_state and records every action sent.
class FakeSession extends GameSessionManager {
  FakeSession(Map<String, dynamic> s) : super(SocketManager()) {
    state = s;
  }
  final calls = <(String, Map<String, dynamic>)>[];
  Map<String, dynamic> reply = {'ok': true};

  @override
  Future<Map<String, dynamic>> action(
      String type, Map<String, dynamic> payload) async {
    calls.add((type, payload));
    return reply;
  }

  void push(Map<String, dynamic> s) {
    state = s;
    notifyListeners();
  }
}

/// Exactly one action was sent, with this type and payload (maps compared by content).
void expectCall(FakeSession s, String type, Map<String, dynamic> payload) {
  expect(s.calls, hasLength(1));
  expect(s.calls.single.$1, type);
  expect(s.calls.single.$2, equals(payload));
}

int get now => DateTime.now().millisecondsSinceEpoch;
final players = [
  {'userId': 'me', 'username': 'Me'},
  {'userId': 'op', 'username': 'Opponent'},
];

Future<void> pumpGame(
    WidgetTester tester, Widget screen, FakeSession session) async {
  SharedPreferences.setMockInitialValues({'uid': 'me', 'name': 'Me'});
  final auth = AuthenticationManager();
  await tester.runAsync(auth.restore);
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<GameSessionManager>.value(value: session),
      ChangeNotifierProvider.value(value: auth),
    ],
    child: MaterialApp(home: Scaffold(body: screen)),
  ));
  await tester.pump();
}

/// Screens run periodic redraw timers; removing them must cancel those timers.
Future<void> disposeGame(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  group('game catalog and routing', () {
    test('every catalog game is playable and has a screen', () {
      expect(gameCatalog.map((g) => g.id).toSet(), {
        'colour_clash', 'raja_mantri', 'ludo', 'snakes_ladders', 'dots_boxes',
        'connect_four', 'tic_tac_toe', 'memory', 'guess_who', //
        'air_hockey', 'ping_pong', 'basketball_hoops', 'paint_fight',
        'reaction_tap', 'math_duel', //
        'truth_dare',
        'hand_cricket',
        'quiz_battle',
        'find_spy',
        'mafia',
        'undercover',
        'charades',
        'heads_up',
        'draw_guess',
        'most_likely',
        'would_rather',
        'rock_paper_scissors',
        'fruit_merge_battle',
        'ludo_teams',
        'bingo',
        'battleship',
        'checkers',
        'mini_golf', 'slingshot', 'archery', 'shooting_gallery',
        'bottle_smash', //
        'chess', 'tug_of_war', 'darts', 'hot_potato', 'knife_hit', 'cup_pong',
        'hungry_hippos', 'penguin_push', 'ring_sort', //
        'minesweeper', 'color_switch', 'fruit_cut', 'chicken_jump', 'carrom',
        'eight_ball', 'bike_race', 'tank_battle', 'sumo_push',
        'nitro_knockout',
      });
      expect(gameCatalog.map((g) => g.id), isNot(contains('guess_person')),
          reason: 'quiz removed from rooms');
      expect(
          gameCatalog.map((g) => g.id),
          isNot(containsAll([
            'snake_duel',
            'penalty',
            'crush_it',
            'fruit_duel',
            'classic_snake'
          ])));
      expect(gameCatalog.length, 56);
      for (final g in gameCatalog) {
        expect(g.playable, isTrue, reason: g.id);
        expect(gameScreenFor(g.id), isNotNull, reason: g.id);
        expect(
                    g.minPlayers <= g.maxPlayers &&
                        g.maxPlayers <= (g.id == 'nitro_knockout' ? 10 : 6),
                    isTrue,
            reason: g.id);
      }
      expect(gameScreenFor('pool'), isNull);
      expect(gameScreenFor('memory'), isA<MemoryScreen>());
      expect(gameScreenFor('paint_fight'), isA<PaintFightScreen>());
    });

    test('gameName falls back to the id for unknown games', () {
      expect(gameName('fruit_cut'), 'Fruit Cut');
      expect(gameName('mystery'), 'mystery');
    });
  });

  group('Crush It screen', () {
    Map<String, dynamic> st(String phase, int taps) => {
          'phase': phase,
          'endsAt': now + 5000,
          'yourTaps': taps,
          'players': [
            {...players[0], 'taps': taps},
            {...players[1], 'taps': 2},
          ],
        };

    testWidgets('shows taps and sends a tap action', (tester) async {
      final s = FakeSession(st('playing', 7));
      await pumpGame(tester, const CrushItScreen(), s);
      expect(find.text('CRUSH IT!'), findsOneWidget);
      expect(find.textContaining('seconds remaining'), findsOneWidget);
      expect(find.text('7'), findsWidgets);
      await tester.tap(find.text('CRUSH!'));
      expectCall(s, 'crush_it:tap', {});
      await disposeGame(tester);
    });

    testWidgets('finished game disables the button', (tester) async {
      final s = FakeSession(st('finished', 3));
      await pumpGame(tester, const CrushItScreen(), s);
      expect(find.text('TIME UP'), findsOneWidget);
      expect(find.text('Final taps'), findsOneWidget);
      await tester.tap(find.text('CRUSH!'));
      expect(s.calls, isEmpty);
      await disposeGame(tester);
    });
  });

  group('Basketball Hoops screen', () {
    Map<String, dynamic> st({String phase = 'playing', int? nextShotAt}) => {
          'phase': phase,
          'startedAt': now - 1000,
          'endsAt': now + 20000,
          'targetCycleMs': 1200,
          'target': 60,
          'yourScore': 5,
          'yourShots': 3,
          'nextShotAt': nextShotAt ?? now - 1,
          'players': [
            {...players[0], 'score': 5},
            {...players[1], 'score': 2},
          ],
        };

    testWidgets(
        'shows target and score; SHOOT sends a timing between 0 and 100',
        (tester) async {
      final s = FakeSession(st());
      await pumpGame(tester, const BasketballHoopsScreen(), s);
      expect(find.text('BASKETBALL HOOPS'), findsOneWidget);
      expect(find.text('Target position: 60'), findsOneWidget);
      expect(find.text('5 pts'), findsOneWidget);
      await tester.tap(find.text('SHOOT!'));
      final (type, payload) = s.calls.single;
      expect(type, 'basketball:shoot');
      expect(payload['timing'], inInclusiveRange(0, 100));
      await disposeGame(tester);
    });

    testWidgets('cannot shoot during cooldown or after time', (tester) async {
      final s = FakeSession(st(nextShotAt: now + 60000));
      await pumpGame(tester, const BasketballHoopsScreen(), s);
      await tester.tap(find.text('SHOOT!'));
      expect(s.calls, isEmpty);
      s.push(st(phase: 'finished'));
      await tester.pump();
      expect(find.text('TIME UP'), findsOneWidget);
      await tester.tap(find.text('SHOOT!'));
      expect(s.calls, isEmpty);
      await disposeGame(tester);
    });
  });

  group('Fruit Duel screen', () {
    Map<String, dynamic> st(String phase) => {
          'phase': phase,
          'endsAt': now + 9000,
          'fruitId': 7,
          'fruitLane': 2,
          'yourScore': 4,
          'players': [
            {...players[0], 'score': 4},
            {...players[1], 'score': 1},
          ],
        };

    testWidgets('slashing a lane sends the current fruit id and lane',
        (tester) async {
      final s = FakeSession(st('playing'));
      await pumpGame(tester, const FruitDuelScreen(), s);
      expect(find.text('FRUIT DUEL'), findsOneWidget);
      for (final l in ['LANE 1', 'LANE 2', 'LANE 3']) {
        expect(find.text(l), findsOneWidget);
      }
      await tester.tap(find.text('LANE 2'));
      expectCall(s, 'fruit_duel:slash', {'fruitId': 7, 'lane': 1});
      await disposeGame(tester);
    });

    testWidgets('no slashing once the game is over', (tester) async {
      final s = FakeSession(st('finished'));
      await pumpGame(tester, const FruitDuelScreen(), s);
      expect(find.text('TIME UP'), findsOneWidget);
      await tester.tap(find.text('LANE 1'));
      expect(s.calls, isEmpty);
      await disposeGame(tester);
    });
  });

  group('Paint Fight screen', () {
    Map<String, dynamic> st(String phase) => {
          'phase': phase,
          'endsAt': now + 9000,
          'width': 3,
          'height': 2,
          'yourCells': ['1,0', '2,1'],
          'yourScore': 2,
          'players': [
            {...players[0], 'score': 2},
            {...players[1], 'score': 1},
          ],
        };
    Finder board() => find.ancestor(
        of: find.byType(CustomPaint).last,
        matching: find.byType(GestureDetector)).first;

    testWidgets('renders the board with owned cells and paints by x,y',
        (tester) async {
      final s = FakeSession(st('playing'));
      await pumpGame(tester, const PaintFightScreen(), s);
      expect(find.text('PAINT FIGHT'), findsOneWidget);
      await tester.drag(board(), const Offset(80, 40));
      expect(s.calls, isNotEmpty);
      expect(s.calls.first.$1, 'paint_fight:paint');
      await disposeGame(tester);
    });

    testWidgets('no painting once the game is over', (tester) async {
      final s = FakeSession(st('finished'));
      await pumpGame(tester, const PaintFightScreen(), s);
      expect(find.text('TIME UP'), findsOneWidget);
      await tester.drag(board(), const Offset(80, 40));
      expect(s.calls, isEmpty);
      await disposeGame(tester);
    });
  });

  group('Memory screen', () {
    Map<String, dynamic> st({String turn = 'me', String phase = 'turn'}) => {
          'phase': phase,
          'turn': turn,
          'mismatchEndsAt': phase == 'mismatch' ? now + 1000 : null,
          'scores': {'me': 1, 'op': 0},
          'players': players,
          'cards': [
            {'id': 0, 'matched': true, 'value': '🍎'},
            {'id': 1, 'matched': true, 'value': '🍎'},
            {'id': 2, 'matched': false, 'value': null},
            {'id': 3, 'matched': false, 'value': null},
          ],
        };

    testWidgets('your turn: hidden cards flip, matched cards do nothing',
        (tester) async {
      final s = FakeSession(st());
      await pumpGame(tester, const MemoryScreen(), s);
      expect(find.text('Your turn'), findsOneWidget);
      expect(find.text('?'), findsNWidgets(2));
      expect(find.text('🍎'), findsNWidgets(2));
      await tester.tap(find.text('🍎').first);
      expect(s.calls, isEmpty);
      await tester.tap(find.text('?').last);
      expectCall(s, 'memory:flip', {'id': 3});
      await disposeGame(tester);
    });

    testWidgets("opponent's turn and mismatch pause block flips",
        (tester) async {
      final s = FakeSession(st(turn: 'op'));
      await pumpGame(tester, const MemoryScreen(), s);
      expect(find.text("Opponent's turn"), findsOneWidget);
      await tester.tap(find.text('?').first);
      expect(s.calls, isEmpty);
      s.push(st(phase: 'mismatch'));
      await tester.pump();
      expect(find.textContaining('Pair shown'), findsOneWidget);
      await tester.tap(find.text('?').first);
      expect(s.calls, isEmpty);
      await disposeGame(tester);
    });
  });

  group('Guess Who (2 phones) screen', () {
    test('the app and the server have exactly the same 30 people', () {
      final json = jsonDecode(File('../server/src/games/guess_who/people.json')
          .readAsStringSync()) as List;
      expect(json, hasLength(allPeople.length));
      for (final p in allPeople) {
        final s = json.cast<Map>().firstWhere((x) => x['id'] == p.id);
        expect(
          [
            s['name'],
            s['gender'],
            s['skinTone'],
            s['eyeColor'],
            s['hairColor'],
            s['hairStyle'],
            s['hat'],
            s['hasGlasses'],
            s['facialHair'],
            s['shirtColor'],
            s['accessory']
          ],
          [
            p.name,
            p.gender.name,
            p.skinTone,
            p.eyeColor,
            p.hairColor,
            p.hairStyle,
            p.hat,
            p.hasGlasses,
            p.facialHair,
            p.shirtColor,
            p.accessory
          ],
          reason: p.name,
        );
      }
    });

    test('Guess Who only allows 2 players', () {
      expect(gameCatalog.firstWhere((g) => g.id == 'guess_who').maxPlayers, 2);
    });

    Map<String, dynamic> st({
      String phase = 'choosing',
      int? mySecret,
      bool oppChosen = false,
      String? turn,
      List<Map<String, dynamic>> asked = const [],
      List<Map<String, dynamic>> oppAsked = const [],
      Map<String, dynamic>? reveal,
    }) =>
        {
          'phase': phase,
          'round': 1,
          'totalRounds': 3,
          'board': [for (var i = 1; i <= 30; i++) i],
          'questions': [
            {
              'id': 'female',
              'label': 'FEMALE',
              'prompt': 'Is the person female?',
              'category': 'gender'
            },
            {
              'id': 'glasses',
              'label': 'GLASSES',
              'prompt': 'Does the person wear glasses?',
              'category': 'accessories'
            },
          ],
          'players': [
            {'userId': 'me', 'username': 'Me', 'chosen': mySecret != null},
            {'userId': 'op', 'username': 'Opponent', 'chosen': oppChosen},
          ],
          'scores': {'me': 0, 'op': 0},
          'turn': turn,
          'you': {'secretId': mySecret, 'asked': asked},
          'opponentAsked': oppAsked,
          'reveal': reveal,
          'revealEndsAt': reveal == null ? null : now + 5000,
        };

    testWidgets('choosing: shows the 30-card board and sends the pick',
        (tester) async {
      tester.view.physicalSize = const Size(411, 914);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final s = FakeSession(st());
      await pumpGame(tester, const GuessWhoScreen(), s);
      expect(find.text('Choose your\ncharacter!'), findsOneWidget);
      expect(find.text('Opponent is choosing…'), findsOneWidget);
      await tester.tap(find.text('Lucy'));
      await tester.pump();
      expectCall(s, 'guess_who:choose', {'personId': 1});
      s.push(st(mySecret: 1, oppChosen: true));
      await tester.pump();
      expect(find.textContaining('Waiting for Opponent'), findsOneWidget);
      expect(find.text('YOU'), findsOneWidget, reason: 'your pick is marked');
      await disposeGame(tester);
    });

    testWidgets(
        "playing: ask on your turn; questions are locked on the opponent's turn",
        (tester) async {
      tester.view.physicalSize = const Size(411, 914);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final s = FakeSession(
          st(phase: 'playing', mySecret: 2, oppChosen: true, turn: 'me'));
      await pumpGame(tester, const GuessWhoScreen(), s);
      expect(find.text('YOUR TURN'), findsOneWidget);
      expect(find.textContaining('You are Tom'), findsOneWidget);
      await tester.tap(find.text('GENDER'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('FEMALE'));
      await tester.pump();
      expectCall(s, 'guess_who:ask', {'questionId': 'female'});

      s.calls.clear();
      s.push(st(
          phase: 'playing',
          mySecret: 2,
          oppChosen: true,
          turn: 'op',
          asked: [
            {'questionId': 'female', 'answer': true},
          ],
          oppAsked: [
            {'questionId': 'glasses', 'answer': true},
          ]));
      await tester.pumpAndSettle();
      expect(find.text("OPPONENT'S TURN"), findsOneWidget);
      expect(find.textContaining('Is the person female?'), findsOneWidget);
      expect(find.text('Opponent asked: Does the person wear glasses? YES'),
          findsOneWidget);
      await tester.tap(find.text('ACCESSORIES'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('GLASSES'), findsNothing,
          reason: 'categories do not open on their turn');
      expect(s.calls, isEmpty);
      await disposeGame(tester);
    });

    testWidgets(
        'final guess: crossed-out people cannot be picked; confirm sends the guess',
        (tester) async {
      tester.view.physicalSize = const Size(411, 914);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final s = FakeSession(
          st(phase: 'playing', mySecret: 2, oppChosen: true, turn: 'me'));
      await pumpGame(tester, const GuessWhoScreen(), s);
      await tester.tap(find.text('Sara')); // cross out
      await tester.pump();
      await tester.tap(find.text('MAKE FINAL GUESS'));
      await tester.pump();
      await tester.tap(find.text('Sara'));
      await tester.pump();
      expect(find.text('GUESS'), findsNothing, reason: 'Sara is crossed out');
      await tester.tap(find.text('Lucy'));
      await tester.pump();
      expect(find.text('Is Lucy your final guess?'), findsOneWidget);
      await tester.tap(find.text('YES, GUESS'));
      await tester.pump();
      expectCall(s, 'guess_who:guess', {'personId': 1});
      await disposeGame(tester);
    });

    testWidgets('reveal shows both secrets and the round winner',
        (tester) async {
      tester.view.physicalSize = const Size(411, 914);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final s = FakeSession(st(
        phase: 'reveal',
        mySecret: 2,
        oppChosen: true,
        reveal: {
          'secrets': {'me': 2, 'op': 1},
          'winner': 'me',
          'guessedBy': 'me',
          'guess': 1,
          'correct': true
        },
      ));
      await pumpGame(tester, const GuessWhoScreen(), s);
      expect(find.text('YOU WIN THE ROUND!'), findsOneWidget);
      expect(find.text('You guessed right!'), findsOneWidget);
      expect(find.text('Tom'), findsOneWidget);
      expect(find.text('Lucy'), findsOneWidget);
      expect(find.textContaining('Next round in'), findsOneWidget);
      await disposeGame(tester);
    });
  });

  group('Guess the Person (online) screen', () {
    Map<String, dynamic> st(
            {String phase = 'round',
            int attemptsLeft = 3,
            bool solved = false,
            Map<String, dynamic>? reveal}) =>
        {
          'phase': phase,
          'round': 1,
          'totalRounds': 5,
          'roundEndsAt': now + 20000,
          'revealEndsAt': phase == 'reveal' ? now + 5000 : null,
          'nextClueAt': phase == 'round' ? now + 4000 : null,
          'clues': ['Born in London', 'Wrote the first program'],
          'players': players,
          'scores': {'me': 0, 'op': 0},
          'solvedBy': solved ? ['me'] : <String>[],
          'you': {'attemptsLeft': attemptsLeft, 'solved': solved},
          'reveal': reveal,
        };

    testWidgets('shows clues and sends the typed guess', (tester) async {
      final s = FakeSession(st())
        ..reply = {
          'ok': true,
          'response': {'correct': true, 'points': 80}
        };
      await pumpGame(tester, const GuessPersonScreen(), s);
      expect(find.text('Round 1 / 5'), findsOneWidget);
      expect(find.text('Born in London'), findsOneWidget);
      expect(find.text('Attempts left: 3'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '  Ada Lovelace ');
      await tester.tap(find.text('GUESS'));
      await tester.pump();
      expectCall(s, 'guess_person:answer', {'text': 'Ada Lovelace'});
      expect(find.text('Correct! +80 points'), findsOneWidget);
      await disposeGame(tester);
    });

    testWidgets(
        'empty guesses are not sent; wrong and error replies are explained',
        (tester) async {
      final s = FakeSession(st())
        ..reply = {
          'ok': true,
          'response': {'correct': false, 'attemptsLeft': 1}
        };
      await pumpGame(tester, const GuessPersonScreen(), s);
      await tester.tap(find.text('GUESS'));
      expect(s.calls, isEmpty);
      await tester.enterText(find.byType(TextField), 'Babbage');
      await tester.tap(find.text('GUESS'));
      await tester.pump();
      expect(find.text('Not quite. 1 attempt(s) left.'), findsOneWidget);
      s.reply = {'ok': false, 'error': 'NO_ATTEMPTS'};
      await tester.enterText(find.byType(TextField), 'Hopper');
      await tester.tap(find.text('GUESS'));
      await tester.pump();
      expect(find.text('No attempts left this round.'), findsOneWidget);
      await disposeGame(tester);
    });

    testWidgets('no attempts left disables guessing; reveal shows the answer',
        (tester) async {
      final s = FakeSession(st(attemptsLeft: 0));
      await pumpGame(tester, const GuessPersonScreen(), s);
      await tester.tap(find.text('GUESS'));
      expect(s.calls, isEmpty);
      s.push(st(phase: 'reveal', reveal: {
        'answer': 'Ada Lovelace',
        'gained': {'me': 80}
      }));
      await tester.pump();
      expect(find.text('The answer: Ada Lovelace'), findsOneWidget);
      expect(find.text('You earned 80 points'), findsOneWidget);
      await disposeGame(tester);
    });

    testWidgets('solved players wait for the others', (tester) async {
      final s = FakeSession(st(solved: true));
      await pumpGame(tester, const GuessPersonScreen(), s);
      expect(
          find.text('You got it! Waiting for the others...'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await disposeGame(tester);
    });
  });
}
