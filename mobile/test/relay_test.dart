import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:multiplayer_game/features/guess_person/models/gp_player.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/features/local_games/air_hockey/air_hockey_game.dart';
import 'package:multiplayer_game/features/local_games/colour_clash/colour_clash_game.dart';
import 'package:multiplayer_game/features/local_games/dots_boxes/dots_boxes_game.dart';
import 'package:multiplayer_game/features/local_games/local_games_hub_screen.dart';
import 'package:multiplayer_game/features/local_games/ludo/ludo_game.dart';
import 'package:multiplayer_game/features/local_games/online/relay_play.dart';
import 'package:multiplayer_game/features/local_games/shell/local_game_info.dart';
import 'package:multiplayer_game/features/local_games/shell/local_game_logic.dart';
import 'package:multiplayer_game/features/local_games/tic_tac_toe/tic_tac_toe_game.dart';
import 'package:multiplayer_game/features/local_games/truth_dare/truth_dare_game.dart';
import 'online_game_screens_test.dart' show FakeSession, pumpGame, disposeGame;

const relayIds = [
  'colour_clash', 'ludo', 'snakes_ladders', 'dots_boxes', 'tic_tac_toe',
  'connect_four', 'truth_dare', //
  'math_duel', 'reaction_tap', 'air_hockey', 'ping_pong', //
  'find_spy', 'undercover', 'mafia', 'charades', 'heads_up', 'draw_guess',
  'most_likely', 'would_rather', 'hand_cricket', 'quiz_battle', //
  'basketball_hoops', 'rock_paper_scissors', 'fruit_merge_battle', 'ludo_teams',
  'bingo', 'battleship', 'checkers', //
  'mini_golf', 'slingshot', 'archery', 'shooting_gallery', 'bottle_smash', //
  'chess', 'tug_of_war', 'darts', 'hot_potato', 'knife_hit', 'cup_pong',
  'hungry_hippos', 'penguin_push', 'ring_sort', //
  'minesweeper', 'color_switch', 'fruit_cut', 'chicken_jump', 'carrom',
  'eight_ball', 'bike_race',
];

/// Applies an action the way the host does: with forwarding switched off.
void hostApply(RelayGame spec, LocalGameLogic g, int from, String name,
    List<Object?> args) {
  final hook = g.sendToHost;
  g.sendToHost = null;
  spec.apply(g, from, name, args);
  g.sendToHost = hook;
}

void phone(WidgetTester tester, [Size size = const Size(411, 914)]) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Map<String, dynamic> roundTrip(Map<String, dynamic> s) =>
    jsonDecode(jsonEncode(s)) as Map<String, dynamic>;

void main() {
  test('the relay games all have an online version, matching the server list',
      () {
    final online = [
      for (final g in allLocalGames)
        if (g.online != null) g.id
    ];
    expect(online.toSet(), relayIds.toSet());
  });

  group('state survives the trip host -> JSON -> guest', () {
    for (final id in relayIds) {
      test(id, () {
        final game = allLocalGames.firstWhere((g) => g.id == id);
        final spec = game.online!;
        final n = game.maxPlayers;
        final host = spec.create(n);
        // Play a little so the state isn't just the starting position.
        for (var t = 0; t < 3000; t += 40) {
          host.update(t);
          hostApply(
              spec,
              host,
              0,
              switch (id) {
                'colour_clash' => 'draw',
                'ludo' || 'snakes_ladders' => 'roll',
                'dots_boxes' => 'line',
                'tic_tac_toe' => 'play',
                'connect_four' => 'drop',
                'truth_dare' => 'spin',
                'math_duel' => 'answer',
                'reaction_tap' => 'tap',
                'air_hockey' => 'mallet',
                'ping_pong' => 'paddle',
                'snake_duel' => 'turn',
                'find_spy' || 'undercover' || 'mafia' => 'seen',
                'charades' || 'heads_up' || 'draw_guess' => 'start',
                'most_likely' || 'would_rather' => 'vote',
                'quiz_battle' => 'answer',
                'basketball_hoops' || 'archery' => 'shoot',
                'mini_golf' => 'putt',
                'slingshot' => 'fling',
                'shooting_gallery' => 'begin',
                'bottle_smash' ||
                'darts' ||
                'knife_hit' ||
                'cup_pong' =>
                  'throw',
                'chess' => 'tap',
                'tug_of_war' => 'pull',
                'hot_potato' => 'pass',
                'hungry_hippos' => 'chomp',
                'penguin_push' => 'dash',
                'ring_sort' => 'move',
                _ => 'pick', // penalty, hand cricket, rock paper scissors
              },
              switch (id) {
                'dots_boxes' => [true, 0, t ~/ 40 % 5],
                'tic_tac_toe' || 'connect_four' => [t ~/ 40 % 7],
                'math_duel' => [0, 5],
                'reaction_tap' => [0],
                'air_hockey' => [0, 0.4, 1.3],
                'ping_pong' => [0, 0.3],
                'snake_duel' => [0, 1],
                'penalty' => [0, 2],
                'hand_cricket' || 'rock_paper_scissors' => [0, 2],
                'find_spy' || 'undercover' || 'mafia' => [0],
                'most_likely' || 'would_rather' => [0, 1],
                'quiz_battle' => [0, 'nope'],
                'basketball_hoops' => [0, 0.0],
                'archery' => [0, 0.3, 0.8],
                'mini_golf' => [0, -1.5, 0.6],
                'slingshot' => [0, 0.4, 0.8],
                'shooting_gallery' => [0],
                'bottle_smash' => [0, 0.5, 0.2],
                'chess' => [t ~/ 40 % 2 == 0 ? 52 : 36],
                'tug_of_war' ||
                'darts' ||
                'hot_potato' ||
                'knife_hit' ||
                'hungry_hippos' ||
                'penguin_push' =>
                  [0],
                'cup_pong' => [0, 0.5, 0.25],
                'ring_sort' => [0, t ~/ 40 % 5, (t ~/ 40 + 1) % 5],
                _ => <Object?>[],
              });
        }
        final saved = roundTrip(spec.save(host));
        final guest = spec.create(n);
        spec.load(guest, saved, -1);
        expect(roundTrip(spec.save(guest)), saved);
        expect(guest.scores, host.scores);
      });
    }
  });

  group('the host only accepts moves from the right player', () {
    test('turn-based: Tic-Tac-Toe and Ludo', () {
      final spec = localGames.firstWhere((g) => g.id == 'tic_tac_toe').online!;
      final g = spec.create(2) as TicTacToeLogic;
      hostApply(spec, g, 1, 'play', [4]);
      expect(g.cells[4], -1, reason: "not player 2's turn");
      hostApply(spec, g, 0, 'play', [4]);
      expect(g.cells[4], 0);
      hostApply(spec, g, 0, 'play', [5]);
      expect(g.cells[5], -1, reason: 'player 1 just moved');

      final ludo = localGames.firstWhere((g) => g.id == 'ludo').online!;
      final l = ludo.create(4) as LudoLogic;
      hostApply(ludo, l, 2, 'roll', []);
      expect(l.rolls, 0);
      hostApply(ludo, l, 0, 'roll', []);
      expect(l.rolls, 1);
    });

    test('real-time: you can only move your own mallet', () {
      final spec = localGames.firstWhere((g) => g.id == 'air_hockey').online!;
      final g = spec.create(2) as AirHockeyLogic;
      final before = g.mallet[0];
      hostApply(spec, g, 1, 'mallet', [0, 0.2, 1.4]);
      expect(g.mallet[0], before);
      hostApply(spec, g, 0, 'mallet', [0, 0.2, 1.4]);
      expect(g.mallet[0].x, closeTo(0.2, 1e-9));
    });

    test(
        'Colour Clash skips pass-the-phone online; only the current player acts',
        () {
      final spec = colourClashInfo.online!;
      final g = spec.create(3) as ColourClashLogic;
      final hook = g.sendToHost;
      spec.hostAuto(g);
      g.sendToHost = hook;
      expect(g.phase, ClashPhase.play);
      final before = g.hands[1].length;
      hostApply(spec, g, 1, 'draw', []);
      expect(g.hands[1].length, before, reason: "not player 2's turn");
      hostApply(spec, g, 0, 'draw', []);
      expect(g.drewThisTurn || g.turn != 0, isTrue);
    });

    test('Truth or Dare: anyone spins, only the chosen player answers', () {
      final spec = truthDareInfo.online!;
      final g = spec.create(3) as TruthDareLogic;
      hostApply(spec, g, 2, 'spin', []);
      hostApply(spec, g, 1, 'landed', []);
      final chosen = g.chosen!;
      final other = (chosen + 1) % 3;
      hostApply(spec, g, other, 'choose', [true]);
      expect(g.phase, TodPhase.choose);
      hostApply(spec, g, chosen, 'choose', [false]);
      expect(g.phase, TodPhase.prompt);
      hostApply(spec, g, chosen, 'complete', [true]);
      expect(g.points[chosen], 1);
    });

    test('Dots & Boxes with junk input is ignored', () {
      final spec = dotsBoxesInfo.online!;
      final g = spec.create(2);
      expect(() => hostApply(spec, g, 0, 'line', ['x']), throwsA(anything),
          reason: 'RelayPlay catches these');
    });
  });

  group('RelayPlay screen', () {
    Map<String, dynamic> st(
            {required String host,
            Map<String, dynamic>? state,
            int version = 0,
            List<Map<String, dynamic>> inputs = const []}) =>
        {
          'gameType': 'tic_tac_toe',
          'relay': true,
          'host': host,
          'players': [
            {'userId': 'me', 'username': 'Me'},
            {'userId': 'op', 'username': 'Opponent'}
          ],
          'state': state,
          'version': version,
          'inputs': inputs,
          'finished': false,
        };

    testWidgets('host runs the game, applies guest inputs and publishes state',
        (tester) async {
      phone(tester);
      final s = FakeSession(st(host: 'me'));
      await pumpGame(tester, RelayPlay(game: ticTacToeInfo), s);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('YOU: ME · HOST'), findsOneWidget);
      expect(s.calls.where((c) => c.$1 == 'relay:state'), isNotEmpty,
          reason: 'publishes the start position');

      // My own tap goes through the same checks: it's my turn (X), so it counts.
      await tester.tap(find.bySemanticsLabel(RegExp(r': empty$')).first);
      await tester.pump(const Duration(milliseconds: 100));
      var last = s.calls.lastWhere((c) => c.$1 == 'relay:state').$2;
      expect((last['state'] as Map)['cells'][0], 0);

      // The guest's move arrives as an input.
      s.push(st(host: 'me', version: 2, inputs: [
        {
          'seq': 1,
          'from': 'op',
          'name': 'play',
          'args': [4]
        },
      ]));
      await tester.pump(const Duration(milliseconds: 100));
      last = s.calls.lastWhere((c) => c.$1 == 'relay:state').$2;
      expect((last['state'] as Map)['cells'][4], 1);
      expect(last['ack'], 1);

      // The same input again (already acknowledged) is not applied twice.
      final sent = s.calls.length;
      s.push(st(host: 'me', version: 3, inputs: [
        {
          'seq': 1,
          'from': 'op',
          'name': 'play',
          'args': [4]
        },
      ]));
      await tester.pump(const Duration(milliseconds: 100));
      expect(s.calls.length, sent);
      await disposeGame(tester);
    });

    testWidgets(
        'guest waits for the host, mirrors its state and sends taps as inputs',
        (tester) async {
      phone(tester);
      final s = FakeSession(st(host: 'op'));
      await pumpGame(tester, RelayPlay(game: ticTacToeInfo), s);
      expect(find.text('Waiting for the host to start…'), findsOneWidget);

      s.push(st(host: 'op', version: 1, state: {
        'cells': [1, -1, -1, -1, -1, -1, -1, -1, -1],
        'turn': 1,
        'winLine': null,
        'winner': null
      }));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('YOU: ME'), findsOneWidget);
      expect(find.text('O'), findsWidgets, reason: "the host's O is shown");

      await tester.tap(find.bySemanticsLabel(RegExp(r': empty$')).first);
      await tester.pump();
      expect(s.calls.single.$1, 'relay:input');
      expect(s.calls.single.$2, {
        'name': 'play',
        'args': [1]
      });
      // Nothing changes until the host says so.
      expect(find.bySemanticsLabel(RegExp(r': empty$')), findsNWidgets(8));
      await disposeGame(tester);
    });

    testWidgets('host reports the final scores when the game ends',
        (tester) async {
      phone(tester);
      final s = FakeSession(st(host: 'me'));
      await pumpGame(tester, RelayPlay(game: ticTacToeInfo), s);
      for (final (from, cell) in [
        ('me', 0),
        ('op', 3),
        ('me', 1),
        ('op', 4),
        ('me', 2)
      ]) {
        if (from == 'me') {
          await tester.tap(find
              .bySemanticsLabel(RegExp(r': empty$'))
              .at(cell == 0 ? 0 : (cell == 1 ? 0 : 0)));
        } else {
          s.push(st(host: 'me', inputs: [
            {
              'seq': cell,
              'from': 'op',
              'name': 'play',
              'args': [cell]
            },
          ]));
        }
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pump(const Duration(milliseconds: 1500));
      final finish = s.calls.where((c) => c.$1 == 'relay:finish').toList();
      expect(finish, hasLength(1));
      expect(finish.single.$2, {
        'scores': [1, 0]
      });
      await disposeGame(tester);
    });
  });
  group('every online view fits a small phone, for every player count', () {
    for (final id in relayIds) {
      testWidgets(id, (tester) async {
        phone(tester, const Size(320, 568));
        final game = allLocalGames.firstWhere((g) => g.id == id);
        final spec = game.online!;
        for (var n = game.minPlayers; n <= game.maxPlayers; n++) {
          final g = spec.create(n);
          final players = defaultPlayers(n);
          for (var me = 0; me < n; me++) {
            await tester.pumpWidget(MaterialApp(
              home: Scaffold(
                body: Column(children: [
                  const SizedBox(height: 22), // the YOU bar
                  Expanded(
                      child: Builder(
                          builder: (context) =>
                              spec.view(context, g, players, me))),
                ]),
              ),
            ));
            await tester.pump(const Duration(milliseconds: 100));
          }
          g.dispose();
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 3));
      });
    }
  });
}
