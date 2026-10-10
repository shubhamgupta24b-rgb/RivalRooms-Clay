// Screenshots of every screen, with the real fonts, for design review.
// Run: flutter test test_capture/capture_test.dart --dart-define=OUT=<folder> [--dart-define=W=320 --dart-define=H=568]
// Not part of the normal test suite (it lives outside test/).
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/core/auth/authentication_manager.dart';
import 'package:multiplayer_game/core/network/socket_manager.dart';
import 'package:multiplayer_game/core/room/room_manager.dart';
import 'package:multiplayer_game/core/session/game_session_manager.dart';
import 'package:multiplayer_game/core/ui/app_ui.dart';
import 'package:multiplayer_game/features/create_room/create_room_screen.dart';
import 'package:multiplayer_game/features/home/home_screen.dart';
import 'package:multiplayer_game/features/join_room/join_room_screen.dart';
import 'package:multiplayer_game/features/local_games/local_games_hub_screen.dart';
import 'package:multiplayer_game/features/local_games/shell/local_game_shell.dart';
import 'package:multiplayer_game/features/lobby/lobby_screen.dart';
import 'package:multiplayer_game/features/login/login_screen.dart';
import 'package:multiplayer_game/features/privacy/privacy_screen.dart';
import 'package:multiplayer_game/features/quick_play/quick_play_screen.dart';
import 'package:multiplayer_game/features/raja_mantri/rmcs_screen.dart';
import 'package:multiplayer_game/features/records/records_screen.dart';
import 'package:multiplayer_game/features/splash/splash_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const out = String.fromEnvironment('OUT');
const w = int.fromEnvironment('W', defaultValue: 411);
const h = int.fromEnvironment('H', defaultValue: 914);
const only = String.fromEnvironment('ONLY'); // comma-separated game ids, or 'pages'
const dpr = 2.0;

class QuietSocket extends SocketManager {
  QuietSocket({bool online = false}) {
    connected.value = online;
  }
  @override
  Future<void> connect(String url, String token) async {}
  @override
  Future<Map<String, dynamic>> request(String event, [Map<String, dynamic>? payload]) async => {'ok': true};
}

final _shot = GlobalKey();

Future<void> loadFonts() async {
  Future<void> family(String name, List<String> files) async {
    final l = FontLoader(name);
    for (final f in files) {
      l.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
    }
    await l.load();
  }

  await family('Nunito', [for (final wt in ['SemiBold', 'Bold', 'ExtraBold', 'Black']) 'assets/fonts/Nunito-$wt.ttf']);
  await family('Lilita One', ['assets/fonts/LilitaOne-Regular.ttf']);
  final mf = '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';
  if (Directory(mf).existsSync()) {
    await family('MaterialIcons', ['$mf/materialicons-regular.otf']);
    await family('Roboto', ['$mf/roboto-regular.ttf', '$mf/roboto-bold.ttf', '$mf/roboto-black.ttf']);
  }
}

Future<void> setUpView(WidgetTester tester) async {
  tester.view.physicalSize = Size(w * dpr, h * dpr);
  tester.view.devicePixelRatio = dpr;
  addTearDown(tester.view.reset);
}

Future<void> pumpPage(WidgetTester tester, Widget home, {Room? room, Map<String, dynamic>? result, String uid = 'me'}) async {
  await setUpView(tester);
  SharedPreferences.setMockInitialValues({'uid': uid, 'name': uid == 'me' ? 'Asha' : 'Ravi'});
  final auth = AuthenticationManager();
  await tester.runAsync(auth.restore);
  final socket = QuietSocket(online: room != null);
  final rm = RoomManager(socket)..room = room;
  final session = GameSessionManager(socket)..result = result;
  await tester.pumpWidget(RepaintBoundary(
    key: _shot,
    child: MultiProvider(
      key: UniqueKey(), // a fresh navigator: nothing left open from the last page
      providers: [
        ChangeNotifierProvider.value(value: auth),
        Provider<SocketManager>.value(value: socket),
        ChangeNotifierProvider.value(value: rm),
        ChangeNotifierProvider.value(value: session),
      ],
      child: MaterialApp(debugShowCheckedModeBanner: false, theme: buildAppTheme(), home: home),
    ),
  ));
}

Future<void> snap(WidgetTester tester, String name) async {
  await tester.pump();
  final boundary = _shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final img = await boundary.toImage(pixelRatio: dpr);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    final f = File('$out/${w}x$h/$name.png');
    f.parent.createSync(recursive: true);
    f.writeAsBytesSync(png!.buffer.asUint8List());
  });
}

/// Pumps frames without waiting to settle (games and backgrounds animate forever).
Future<void> run(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 100) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Scrolls the biggest vertical list on screen down by [dy].
Future<void> scrollBy(WidgetTester tester, double dy) async {
  final lists = tester.stateList<ScrollableState>(find.byType(Scrollable)).where((s) => s.axisDirection == AxisDirection.down && s.position.hasContentDimensions).toList();
  if (lists.isEmpty) return;
  lists.sort((a, b) => b.position.viewportDimension.compareTo(a.position.viewportDimension));
  final p = lists.first.position;
  p.jumpTo((p.pixels + dy).clamp(p.minScrollExtent, p.maxScrollExtent));
  await run(tester, 600);
}

Room room({String status = 'lobby', String game = 'ludo', bool guestReady = false, Map? party}) => Room.fromJson({
      'code': 'K7QX2M', 'gameType': game, 'hostId': 'me', 'status': status, 'maxPlayers': 4,
      'players': [
        {'userId': 'me', 'username': 'Asha', 'ready': true, 'connected': true},
        {'userId': 'op', 'username': 'Ravi', 'ready': guestReady, 'connected': true},
        {'userId': 'p3', 'username': 'Meera', 'ready': true, 'connected': true},
      ],
      'party': party, 'playable': ['tic_tac_toe', 'ludo', 'colour_clash', 'find_spy', 'air_hockey'],
    });

Map<String, dynamic> roundResult() => {
      'ranking': [
        {'userId': 'op', 'username': 'Ravi', 'score': 7, 'rank': 1},
        {'userId': 'me', 'username': 'Asha', 'score': 4, 'rank': 2},
        {'userId': 'p3', 'username': 'Meera', 'score': 2, 'rank': 3},
      ],
      'winners': ['op'],
    };

void main() {
  setUpAll(loadFonts);
  final pages = only.isEmpty || only.split(',').contains('pages');
  final ids = only.isEmpty ? null : only.split(',').toSet();

  if (pages) {
    testWidgets('pages', (tester) async {
      await pumpPage(tester, const SplashScreen(minShow: Duration(days: 1)));
      await run(tester, 900);
      await snap(tester, 'p01_splash');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(days: 2));

      await pumpPage(tester, const LoginScreen());
      await run(tester, 900);
      await snap(tester, 'p02_login');

      await pumpPage(tester, const HomeScreen());
      await run(tester, 900);
      await snap(tester, 'p03_home_a');
      await scrollBy(tester, h * 0.7);
      await snap(tester, 'p03_home_b');
      await scrollBy(tester, h * 0.7);
      await snap(tester, 'p03_home_c');

      await pumpPage(tester, const HomeScreen());
      await run(tester, 600);
      await tester.tap(find.text('Play online'));
      await run(tester, 800);
      await snap(tester, 'p04_home_online_sheet');

      await pumpPage(tester, const LocalGamesHubScreen());
      await run(tester, 900);
      for (final k in ['a', 'b', 'c', 'd', 'e']) {
        await snap(tester, 'p05_hub_$k');
        await scrollBy(tester, h * 0.75);
      }

      await pumpPage(tester, const CreateRoomScreen());
      await run(tester, 900);
      await snap(tester, 'p06_create_room');

      await pumpPage(tester, const JoinRoomScreen());
      await run(tester, 900);
      await snap(tester, 'p07_join_room');

      await pumpPage(tester, const QuickPlayScreen());
      await run(tester, 900);
      await snap(tester, 'p08_quick_play');

      await pumpPage(tester, const RecordsScreen());
      await run(tester, 900);
      await snap(tester, 'p09_records');

      await pumpPage(tester, const PrivacyScreen());
      await run(tester, 900);
      await snap(tester, 'p10_privacy');

      await pumpPage(tester, const RmcsMenuScreen());
      await run(tester, 900);
      await snap(tester, 'p11_rmcs_menu');

      await pumpPage(tester, const LobbyScreen(), room: room());
      await run(tester, 900);
      await snap(tester, 'p12_lobby_host');
      await scrollBy(tester, h * 0.6);
      await snap(tester, 'p12_lobby_host_b');

      await pumpPage(tester, const LobbyScreen(), room: room(), uid: 'op');
      await run(tester, 900);
      await snap(tester, 'p13_lobby_guest');

      await pumpPage(tester, const LobbyScreen(), room: room(status: 'finished'), result: roundResult());
      await run(tester, 900);
      await snap(tester, 'p14_room_result');

      final party = {
        'games': ['tic_tac_toe', 'ludo', 'colour_clash', 'find_spy', 'air_hockey'], 'index': 1,
        'totals': {'me': 5, 'op': 6, 'p3': 2}, 'lastPoints': {'me': 2, 'op': 3, 'p3': 1}, 'done': false,
      };
      await pumpPage(tester, const LobbyScreen(), room: room(status: 'finished', party: party), result: roundResult());
      await run(tester, 900);
      await snap(tester, 'p15_party_result');
      await scrollBy(tester, h * 0.6);
      await snap(tester, 'p15_party_result_b');

      await tester.pumpWidget(const SizedBox());
      await run(tester, 3000);
    });
  }

  for (final g in localGames) {
    if (ids != null && !ids.contains(g.id)) continue;
    testWidgets('game ${g.id}', (tester) async {
      await pumpPage(tester, LocalGameShell(game: g));
      await run(tester, 900);
      await snap(tester, 'g_${g.id}_1intro');
      final start = find.text('Start');
      if (start.evaluate().isEmpty) return;
      await tester.ensureVisible(start);
      await tester.pump();
      await tester.tap(start);
      await run(tester, 3200);
      if (find.text('START').evaluate().isNotEmpty) {
        await tester.tap(find.text('START').last, warnIfMissed: false);
        await run(tester, 300);
      }
      await run(tester, 1500);
      await snap(tester, 'g_${g.id}_2play');
      final pause = find.byType(PauseButton);
      if (pause.evaluate().isNotEmpty) {
        await tester.tap(pause.first, warnIfMissed: false);
        await run(tester, 700);
        await snap(tester, 'g_${g.id}_3pause');
      }
      await tester.pumpWidget(const SizedBox());
      await run(tester, 3000);
    });
  }
}
