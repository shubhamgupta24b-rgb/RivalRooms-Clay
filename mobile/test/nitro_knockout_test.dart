import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/config.dart';
import 'package:multiplayer_game/core/audio/game_audio.dart';
import 'package:multiplayer_game/core/ui/app_ui.dart';
import 'package:multiplayer_game/features/create_room/create_room_screen.dart';
import 'package:multiplayer_game/core/auth/authentication_manager.dart';
import 'package:multiplayer_game/core/lan/lan_host.dart';
import 'package:multiplayer_game/core/network/socket_manager.dart';
import 'package:multiplayer_game/core/session/game_session_manager.dart';
import 'package:multiplayer_game/features/local_games/local_games_hub_screen.dart';
import 'package:multiplayer_game/features/local_games/nitro_knockout/nitro_game_view.dart';
import 'package:multiplayer_game/features/local_games/nitro_knockout/nitro_knockout_game.dart';
import 'package:multiplayer_game/features/local_games/nitro_knockout/nitro_online_screen.dart';
import 'package:multiplayer_game/features/local_games/nitro_knockout/nitro_transport.dart';
import 'package:multiplayer_game/features/local_games/shell/game_pause.dart';
import 'package:multiplayer_game/games/game_catalog.dart';
import 'package:multiplayer_game/games/game_module.dart';
import 'package:provider/provider.dart';

import 'webview_fake.dart';

class _RoomIdentity {
  String get myId => 'firebase-room';
}

class _SocketIdentity {
  String get userId => 'firebase-socket';
}

class _Auth extends AuthenticationManager {
  @override
  String get token => 'dev:me:Player';
}

class _Session extends GameSessionManager {
  final calls = <(String, Map<String, dynamic>)>[];
  _Session(super.socket);
  @override
  Future<Map<String, dynamic>> action(
    String type,
    Map<String, dynamic> payload,
  ) async {
    calls.add((type, payload));
    return {'ok': true};
  }

  void update(Map<String, dynamic>? value) {
    state = value;
    notifyListeners();
  }
}

Map<String, dynamic> _state({
  bool host = true,
  int version = 0,
  Object? snapshot,
  List<Map> inputs = const [],
}) => {
  'nitro': true,
  'host': host ? 'me' : 'other',
  'version': version,
  'players': [
    {'userId': 'me', 'username': 'Me'},
    {'userId': 'other', 'username': 'Other'},
  ],
  'state': snapshot,
  'inputs': inputs,
};

Future<void> _engineReady(WidgetTester tester) async {
  await tester.pump();
  FakeWebViewPlatform.engineReady = true;
  FakeWebViewPlatform.pageFinished!(
    'file:///android_asset/flutter_assets/assets/nitro/index.html',
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 150));
}

void main() {
  test(
    'Nitro has dedicated online 2–10, solo bot combat, and no phone LAN',
    () {
      final online = gameCatalog.singleWhere((g) => g.id == 'nitro_knockout');
      expect(online.playable, isTrue);
      expect(online.minPlayers, 2);
      expect(online.maxPlayers, 10);
      final local = allLocalGames.singleWhere((g) => g.id == 'nitro_knockout');
      expect(local.solo, isTrue);
      expect(local.maxPlayers, 1);
      expect(local.scoreUnit, 'KOs');
      expect(local.online, isNull);
      expect(local.play(const [], (_) {}), isA<NitroOfflineView>());
      expect(gameScreenFor('nitro_knockout'), isA<NitroOnlineScreen>());
      expect(LanHost.internetOnly, contains('nitro_knockout'));
      expect(LanHost.games.any((g) => g.id == 'nitro_knockout'), isFalse);
    },
  );

  test('boot uses exact roster and a shared online arena', () {
    expect(jsonDecode(const NitroBoot(mode: 'offline').asJson()), {
      'mode': 'offline',
      'seat': 0,
      'seats': 8,
      'names': [],
    });
    final boot = jsonDecode(
      const NitroBoot(
        mode: 'host',
        seat: 2,
        seats: 3,
        names: ['A', 'B', 'Me'],
      ).asJson(),
    );
    expect(boot['seats'], 3);
    expect(boot['seat'], 2);
    expect(boot['names'], ['A', 'B', 'Me']);
    expect(boot['arena'], 'foundry');
  });

  test('identity prefers authenticated IDs and never parses bearer tokens', () {
    expect(
      nitroIdentity(
        roomMyId: 'room',
        socketUserId: 'socket',
        devToken: 'dev:dev:Name',
      ),
      'room',
    );
    expect(
      nitroIdentity(socketUserId: 'socket', devToken: 'dev:dev:Name'),
      'socket',
    );
    expect(nitroIdentity(devToken: 'dev:dev:Name'), 'dev');
    expect(nitroIdentity(devToken: 'jwt.payload.signature'), isEmpty);
    expect(nitroIdentity(devToken: 'malformed'), isEmpty);
    expect(
      nitroIdentityFromManagers(
        room: _RoomIdentity(),
        socket: _SocketIdentity(),
        devToken: 'jwt',
      ),
      'firebase-room',
    );
    expect(
      nitroIdentityFromManagers(socket: _SocketIdentity(), devToken: 'jwt'),
      'firebase-socket',
    );
    expect(
      nitroIdentityFromManagers(
        room: Object(),
        socket: Object(),
        devToken: 'dev:fallback:Name',
      ),
      'fallback',
    );
  });

  test(
    'feed labels are plain, UTF-16 bounded and preserve surrogate pairs',
    () {
      expect(nitroLabel('<b>A&B</b>'), 'bAB/b');
      expect(nitroLabel('${'a' * 23}🏎️').length, 23);
      expect(nitroLabel('  '), 'Player');
    },
  );

  test(
    'asset entry is local classic JS; embedded WASM and explicit bridge boot',
    () {
      final html = File('assets/nitro/index.html').readAsStringSync();
      final js = File(
        'assets/nitro/assets/index-CejRMBG2.js',
      ).readAsStringSync();
      expect(html, contains('script defer'));
      expect(html, isNot(contains('type="module"')));
      expect(js, contains('window.NitroBridge?.postMessage(a)'));
      expect(js, contains('xM(RL.toByteArray("AGFzbQ'));
      expect(js, contains('function cf(){return eQ.jsx(wf,{})}'));
      expect(js, isNot(contains('(t=!0,KU(A,{mode:"offline"')));
      expect(js, contains('audioSettings:'));
    },
  );

  test(
    'transport serializes, retries terminal before finish and coalesces frames',
    () async {
      final calls = <(String, Map<String, dynamic>)>[];
      final responses = <Completer<Map<String, dynamic>>>[];
      final errors = <String>[];
      final transport = NitroTransport(
        send: (type, payload) {
          calls.add((type, payload));
          final c = Completer<Map<String, dynamic>>();
          responses.add(c);
          return c.future;
        },
        onError: errors.add,
        retryDelay: const Duration(days: 1),
      );
      addTearDown(transport.dispose);
      transport.snapshot({'time': 80000, 'over': 0}, 0);
      transport.snapshot({'time': 70000, 'over': 0}, 1);
      transport.snapshot({'time': 60000, 'over': 0}, 2);
      expect(calls.length, 1);
      responses[0].complete({'ok': true});
      await Future<void>.delayed(Duration.zero);
      expect(calls[1].$2['state']['time'], 60000);
      transport.snapshot({'time': 0, 'over': 1}, 3);
      transport.finish([4, 2]);
      responses[1].complete({'ok': true});
      await Future<void>.delayed(Duration.zero);
      expect(calls.last.$1, 'nitro:state');
      expect(calls.last.$2['state']['over'], 1);
      responses[2].complete({'ok': false, 'error': 'TIMEOUT'});
      await Future<void>.delayed(Duration.zero);
      expect(errors, ['TIMEOUT']);
      expect(calls.any((c) => c.$1 == 'nitro:finish'), isFalse);
      transport.retryNow();
      expect(calls.last.$1, 'nitro:state');
      responses[3].complete({'ok': true});
      await Future<void>.delayed(Duration.zero);
      expect(calls.last.$1, 'nitro:finish');
      expect(calls.last.$2, {
        'scores': [4, 2],
      });
      responses[4].complete({'ok': true});
      await Future<void>.delayed(Duration.zero);
    },
  );

  testWidgets('unsupported platforms need no WebView fake', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NitroGameView(
          boot: const NitroBoot(mode: 'offline'),
          controller: NitroViewController(),
          onMessage: (_) {},
        ),
      ),
    );
    expect(find.textContaining('requires Android'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant({TargetPlatform.linux}));

  testWidgets('room size reaches ten online but stops at six on LAN', (
    tester,
  ) async {
    final oldMode = AppConfig.mode;
    addTearDown(() {
      AppConfig.mode = oldMode;
      tester.view.reset();
    });
    tester.view.physicalSize = const Size(411, 914);
    tester.view.devicePixelRatio = 1;
    AppConfig.mode = ServerMode.online;
    await tester.pumpWidget(
      MaterialApp(theme: buildAppTheme(), home: const CreateRoomScreen()),
    );
    for (var i = 0; i < 8; i++) {
      await tester.tap(find.byKey(const ValueKey('players+')));
      await tester.pump();
    }
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('playerCount'))).data,
      '10',
    );
    AppConfig.mode = ServerMode.wifi;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const CreateRoomScreen(key: ValueKey('wifi')),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byKey(const ValueKey('players+')));
      await tester.pump();
    }
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('playerCount'))).data,
      '6',
    );
    await tester.pumpWidget(const SizedBox());
  });

  group('Android bridge with fake platform (not real physics)', () {
    setUp(() {
      FakeWebViewPlatform.install();
    });

    testWidgets(
      'ready cover ignores touches, pause and audio settings bridge',
      (tester) async {
        final paused = ValueNotifier(false);
        final controller = NitroViewController();
        final oldAudio = GameAudio.settings.value;
        addTearDown(() {
          paused.dispose();
          GameAudio.settings.value = oldAudio;
        });
        await tester.pumpWidget(
          MaterialApp(
            home: GamePause(
              paused: paused,
              child: NitroGameView(
                boot: const NitroBoot(mode: 'offline'),
                controller: controller,
                onMessage: (_) {},
              ),
            ),
          ),
        );
        expect(controller.ready, isFalse);
        await _engineReady(tester);
        expect(controller.ready, isTrue);
        final cover = find.byKey(const ValueKey('nitro-loading-cover'));
        expect(tester.widget<IgnorePointer>(cover).ignoring, isTrue);
        paused.value = true;
        await tester.pump();
        expect(
          FakeWebViewPlatform.scripts.any(
            (s) => s.contains('__nitroDebug.pause()'),
          ),
          isTrue,
        );
        GameAudio.settings.value = const AudioSettings(
          music: false,
          sfx: true,
          volume: .2,
        );
        await tester.pump();
        expect(
          FakeWebViewPlatform.scripts.last,
          contains('"music":false,"sfx":true,"volume":0.2'),
        );
        paused.value = false;
        await tester.pump();
        expect(
          FakeWebViewPlatform.scripts.last,
          contains('__nitroDebug.resume()'),
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump();
        expect(
          FakeWebViewPlatform.scripts.last,
          contains('__nitroDebug.pause()'),
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpWidget(const SizedBox());
      },
      variant: TargetPlatformVariant({TargetPlatform.android}),
    );

    testWidgets('boot timeout reports an error and stops polling', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NitroGameView(
            boot: const NitroBoot(mode: 'offline'),
            controller: NitroViewController(),
            onMessage: (_) {},
          ),
        ),
      );
      await tester.pump();
      FakeWebViewPlatform.pageFinished!(
        'file:///android_asset/flutter_assets/assets/nitro/index.html',
      );
      await tester.pump(const Duration(seconds: 26));
      expect(find.textContaining('could not start'), findsOneWidget);
      final count = FakeWebViewPlatform.scripts.length;
      await tester.pump(const Duration(seconds: 30));
      expect(FakeWebViewPlatform.scripts.length, count);
      await tester.pumpWidget(const SizedBox());
    }, variant: TargetPlatformVariant({TargetPlatform.android}));

    Future<(_Session, SocketManager)> online(
      WidgetTester tester,
      Map<String, dynamic> state,
    ) async {
      final socket = SocketManager();
      final session = _Session(socket)..state = state;
      addTearDown(() {
        session.dispose();
        socket.dispose();
      });
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthenticationManager>.value(value: _Auth()),
            ChangeNotifierProvider<GameSessionManager>.value(value: session),
            Provider<SocketManager>.value(value: socket),
          ],
          child: const MaterialApp(home: Scaffold(body: NitroOnlineScreen())),
        ),
      );
      await tester.pump();
      return (session, socket);
    }

    testWidgets(
      'host buffers inputs, acks only applied input, retains WebView on reconnect',
      (tester) async {
        final inputs = [
          {
            'seq': 1,
            'from': 'other',
            'args': [100, 0, 0, 0],
          },
        ];
        final (session, socket) = await online(tester, _state(inputs: inputs));
        expect(
          FakeWebViewPlatform.scripts.where(
            (s) => s.contains('__nitroNet.input'),
          ),
          isEmpty,
        );
        FakeWebViewPlatform.failInjection = true;
        await _engineReady(tester);
        FakeWebViewPlatform.message(
          jsonEncode({
            'kind': 'snapshot',
            'data': jsonEncode({'time': 89000, 'over': 0}),
          }),
        );
        await tester.pump();
        expect(session.calls.last.$2['ack'], 0);
        FakeWebViewPlatform.failInjection = false;
        session.update(_state(inputs: inputs));
        await tester.pump();
        FakeWebViewPlatform.message(
          jsonEncode({
            'kind': 'snapshot',
            'data': jsonEncode({'time': 88000, 'over': 0}),
          }),
        );
        await tester.pump();
        expect(session.calls.last.$2['ack'], 1);
        socket.connected.value = true;
        await tester.pump();
        socket.connected.value = false;
        await tester.pump();
        session.update(_state(version: 2, snapshot: {'time': 88000}));
        await tester.pump();
        expect(FakeWebViewPlatform.controllers.length, 1);
        await tester.pumpWidget(const SizedBox());
      },
      variant: TargetPlatformVariant({TargetPlatform.android}),
    );

    testWidgets(
      'guest buffers first frame until ready and never pauses online',
      (tester) async {
        final (session, _) = await online(
          tester,
          _state(host: false, version: 1, snapshot: {'time': 85000}),
        );
        expect(
          FakeWebViewPlatform.scripts.where(
            (s) => s.contains('__nitroNet.snapshot'),
          ),
          isEmpty,
        );
        await _engineReady(tester);
        expect(
          FakeWebViewPlatform.scripts.any(
            (s) => s.contains('__nitroNet.snapshot') && s.contains('85000'),
          ),
          isTrue,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump();
        expect(
          FakeWebViewPlatform.scripts.any(
            (s) => s.contains('__nitroDebug.pause()'),
          ),
          isFalse,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        session.update(
          _state(host: false, version: 2, snapshot: {'time': 84000}),
        );
        await tester.pump();
        expect(FakeWebViewPlatform.controllers.length, 1);
        await tester.pumpWidget(const SizedBox());
      },
      variant: TargetPlatformVariant({TargetPlatform.android}),
    );

    testWidgets(
      'recreated host with prior state refuses to start a fresh engine',
      (tester) async {
        await online(tester, _state(version: 4, snapshot: {'time': 50000}));
        expect(find.textContaining('host engine was lost'), findsOneWidget);
        expect(FakeWebViewPlatform.controllers, isEmpty);
        await tester.pumpWidget(const SizedBox());
      },
      variant: TargetPlatformVariant({TargetPlatform.android}),
    );
  });
}
