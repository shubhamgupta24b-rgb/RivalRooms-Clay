import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/core/auth/authentication_manager.dart';
import 'package:multiplayer_game/core/network/socket_manager.dart';
import 'package:multiplayer_game/core/room/room_manager.dart';
import 'package:multiplayer_game/core/session/game_session_manager.dart';
import 'package:multiplayer_game/core/ui/app_ui.dart';
import 'package:multiplayer_game/features/create_room/game_grid.dart';
import 'package:multiplayer_game/features/lobby/lobby_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records every request and answers ok, like a friendly server.
class RecordingSocket extends SocketManager {
  final requests = <(String, Map<String, dynamic>?)>[];
  @override
  Future<Map<String, dynamic>> request(String event, [Map<String, dynamic>? payload]) async {
    requests.add((event, payload));
    return {'ok': true};
  }

  @override
  Future<void> connect(String url, String token) async {}
}

/// The last request sent, compared by content.
void expectReq(RecordingSocket s, String event, Map<String, dynamic> payload) {
  expect(s.requests.last.$1, event);
  expect(s.requests.last.$2, equals(payload));
}

Room room({String status = 'lobby', String game = 'tic_tac_toe', bool guestReady = true, Map? party, List<String> playable = const ['tic_tac_toe', 'ludo', 'colour_clash']}) => Room.fromJson({
      'code': 'ABC234', 'gameType': game, 'hostId': 'me', 'status': status, 'maxPlayers': 4,
      'players': [
        {'userId': 'me', 'username': 'Asha', 'ready': true, 'connected': true},
        {'userId': 'op', 'username': 'Ravi', 'ready': guestReady, 'connected': true},
      ],
      'party': party, 'playable': playable,
    });

Future<(RoomManager, RecordingSocket, GameSessionManager)> pumpLobby(WidgetTester tester, Room r, {String uid = 'me'}) async {
  tester.view.physicalSize = const Size(411, 914);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'uid': uid, 'name': uid == 'me' ? 'Asha' : 'Ravi'});
  final auth = AuthenticationManager();
  await tester.runAsync(auth.restore);
  final socket = RecordingSocket();
  final rm = RoomManager(socket)..room = r;
  final session = GameSessionManager(socket);
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: auth),
      Provider<SocketManager>.value(value: socket),
      ChangeNotifierProvider.value(value: rm),
      ChangeNotifierProvider.value(value: session),
    ],
    child: MaterialApp(theme: buildAppTheme(), home: const LobbyScreen()),
  ));
  await tester.pump();
  return (rm, socket, session);
}

void main() {
  testWidgets('host lobby: code, next game card, change game, start and party mode', (tester) async {
    final (rm, socket, _) = await pumpLobby(tester, room());
    expect(find.bySemanticsLabel('Room code A B C 2 3 4'), findsOneWidget);
    expect(find.text('Tic-Tac-Toe'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Asha, you, host')), findsOneWidget);
    expect(find.text('Start Tic-Tac-Toe'), findsOneWidget);

    await tester.tap(find.text('Party mode · 5 random games'));
    await tester.pump();
    expectReq(socket, 'start_party', {'count': 5});

    await tester.tap(find.text('Start Tic-Tac-Toe'));
    await tester.pump();
    expect(socket.requests.last.$1, 'start_game');

    // Change the game: the picker only lets you pick games that fit.
    await tester.ensureVisible(find.text('Change'));
    await tester.pump(); await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Change'));
    await tester.pump(); await tester.pump(const Duration(seconds: 1));
    expect(find.byType(GamePickerScreen), findsOneWidget);
    expect(find.text('3 games fit 2 players'), findsOneWidget);
    await tester.tap(find.text('Connect Four'));
    await tester.pump(); await tester.pump(const Duration(seconds: 1));
    expect(find.byType(GamePickerScreen), findsOneWidget, reason: "doesn't fit: can't pick it");
    await tester.tap(find.text('Ludo'));
    await tester.pump(); await tester.pump(const Duration(seconds: 1));
    expect(find.byType(GamePickerScreen), findsNothing);
    expectReq(socket, 'select_game', {'gameType': 'ludo'});
    rm.room = room(game: 'ludo');
    rm.notifyListeners();
    await tester.pump();
    expect(find.text('Start Ludo'), findsOneWidget);
  });

  testWidgets('host cannot start until everyone is ready, or if the game does not fit', (tester) async {
    final (rm, socket, _) = await pumpLobby(tester, room(guestReady: false));
    expect(find.textContaining('to tap Ready'), findsOneWidget);
    await tester.tap(find.text('Start Tic-Tac-Toe'));
    await tester.pump();
    expect(socket.requests.where((r) => r.$1 == 'start_game'), isEmpty);
    rm.room = room(game: 'raja_mantri');
    rm.notifyListeners();
    await tester.pump();
    expect(find.text('Needs 4 players · you have 2'), findsOneWidget);
  });

  testWidgets('guest lobby: no game controls, just READY', (tester) async {
    final (_, socket, _) = await pumpLobby(tester, room(guestReady: false), uid: 'op');
    expect(find.text('Change'), findsNothing);
    expect(find.textContaining('Party mode'), findsNothing);
    expect(find.text('Tap Ready when you are set'), findsOneWidget);
    await tester.tap(find.text('Ready'));
    await tester.pump();
    expect(socket.requests.last.$1, 'player_ready');
  });

  Map<String, dynamic> result() => {
        'ranking': [
          {'userId': 'op', 'username': 'Ravi', 'score': 1, 'rank': 1},
          {'userId': 'me', 'username': 'Asha', 'score': 0, 'rank': 2},
        ],
        'winners': ['op'],
      };

  testWidgets('results (no party): host plays again or chooses another game', (tester) async {
    final (_, socket, session) = await pumpLobby(tester, room(status: 'finished'));
    session.result = result();
    session.notifyListeners();
    await tester.pump();
    expect(find.text('Ravi wins!', findRichText: true), findsOneWidget);
    expect(find.text('1'), findsWidgets); // rank medal
    await tester.tap(find.text('Play again'));
    await tester.pump();
    expectReq(socket, 'next_game', {});
    await tester.tap(find.text('Choose another game'));
    await tester.pump();
    expect(socket.requests.last.$1, 'return_to_lobby');
  });

  testWidgets('results in a party: points, standings and the next game', (tester) async {
    final party = {
      'games': ['tic_tac_toe', 'ludo', 'colour_clash'], 'index': 0,
      'totals': {'me': 1, 'op': 2}, 'lastPoints': {'me': 1, 'op': 2}, 'done': false,
    };
    final (rm, socket, session) = await pumpLobby(tester, room(status: 'finished', party: party));
    session.result = result();
    session.notifyListeners();
    await tester.pump();
    expect(find.text('PARTY STANDINGS · GAME 1 OF 3'), findsOneWidget);
    expect(find.text('+2'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Next game (2/3): Ludo'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Next game (2/3): Ludo'));
    await tester.pump();
    expectReq(socket, 'next_game', {});

    // Last game done: the party winner is announced.
    rm.room = room(status: 'finished', party: {...party, 'index': 2, 'done': true, 'totals': {'me': 6, 'op': 3}});
    rm.notifyListeners();
    await tester.pump();
    expect(find.text('Asha wins the party!', findRichText: true), findsOneWidget);
    expect(find.textContaining('Next game'), findsNothing);
  });
}
