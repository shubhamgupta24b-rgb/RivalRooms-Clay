import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/core/auth/authentication_manager.dart';
import 'package:multiplayer_game/core/network/socket_manager.dart';
import 'package:multiplayer_game/core/room/room_manager.dart';
import 'package:multiplayer_game/core/session/game_session_manager.dart';
import 'package:multiplayer_game/core/ui/app_ui.dart';
import 'package:multiplayer_game/features/quick_play/quick_play_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'session_ui_test.dart' show RecordingSocket, expectReq, pumpLobby;

Future<RecordingSocket> pumpQuickPlay(WidgetTester tester) async {
  tester.view.physicalSize = const Size(411, 914);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'uid': 'me', 'name': 'Asha'});
  final auth = AuthenticationManager();
  await tester.runAsync(auth.restore);
  final socket = RecordingSocket();
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: auth),
      Provider<SocketManager>.value(value: socket),
      ChangeNotifierProvider(create: (_) => RoomManager(socket)),
      ChangeNotifierProvider(create: (_) => GameSessionManager(socket)),
    ],
    child: MaterialApp(theme: buildAppTheme(), home: const QuickPlayScreen()),
  ));
  await tester.pump();
  return socket;
}

void main() {
  testWidgets('Quick Play: any game by default', (tester) async {
    final socket = await pumpQuickPlay(tester);
    expect(find.text('Any game'), findsOneWidget);
    await tester.tap(find.text('Find a room'));
    await tester.pump();
    expectReq(socket, 'quick_play', {});
  });

  testWidgets('Quick Play: pick a game and only rooms for it are joined',
      (tester) async {
    final socket = await pumpQuickPlay(tester);
    await tester.tap(find.text('Ludo').first);
    await tester.pump();
    expect(find.textContaining('Ludo · 2–4 players'), findsOneWidget);
    await tester.tap(find.text('Find a room'));
    await tester.pump();
    expectReq(socket, 'quick_play', {'gameType': 'ludo'});
  });

  testWidgets('a Quick Play room says so in the lobby', (tester) async {
    final r = Room.fromJson({
      'code': 'QK2345',
      'gameType': 'ludo',
      'hostId': 'me',
      'status': 'lobby',
      'maxPlayers': 6,
      'isPublic': true,
      'players': [
        {'userId': 'me', 'username': 'Asha', 'ready': true, 'connected': true},
      ],
    });
    expect(r.isPublic, isTrue);
    await pumpLobby(tester, r);
    expect(find.text('Open to everyone'), findsOneWidget);
  });
}
