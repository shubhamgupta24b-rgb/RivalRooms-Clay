import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/core/lan/lan_host.dart';
import 'package:multiplayer_game/core/lan/lan_rooms.dart';
import 'package:multiplayer_game/core/lan/lan_server.dart';
import 'package:multiplayer_game/core/network/socket_manager.dart';

/// The next [name] event a phone receives that passes [where].
Future<Map> next(SocketManager s, String name, [bool Function(Map d)? where]) =>
    s.events
        .where((e) =>
            e.name == name && (where == null || where(Map.from(e.data as Map))))
        .map((e) => Map.from(e.data as Map))
        .first
        .timeout(const Duration(seconds: 5));

void main() {
  late LanServer server;
  late String url;

  setUp(() async {
    server = LanServer(
        LanRooms(LanHost.games, grace: const Duration(milliseconds: 300)));
    final port = await server.start(port: 0);
    url = 'http://127.0.0.1:$port';
  });
  tearDown(() => server.stop());

  test(
      '/health says it is a Party Games server (so Same Wi-Fi search finds it)',
      () async {
    final c = HttpClient();
    final res = await (await c.getUrl(Uri.parse('$url/health'))).close();
    final body = jsonDecode(await res.transform(utf8.decoder).join()) as Map;
    c.close();
    expect(body['ok'], isTrue);
    expect(body['app'], 'party-games');
  });

  test(
      'two phones: create, join, start a relay game, state reaches the guest, results',
      () async {
    final host = SocketManager(), guest = SocketManager();
    await host.connect(url, 'dev:hostA:Asha');
    await guest.connect(url, 'dev:guestB:Ravi');

    final created = await host
        .request('create_room', {'gameType': 'tic_tac_toe', 'maxPlayers': 4});
    expect(created['ok'], isTrue, reason: '$created');
    final code = (created['room'] as Map)['code'] as String;

    final hostSeesJoin =
        next(host, 'room_state', (r) => (r['players'] as List).length == 2);
    final joined =
        await guest.request('join_room', {'code': code.toLowerCase()});
    expect(joined['ok'], isTrue, reason: '$joined');
    await hostSeesJoin;

    expect((await guest.request('player_ready'))['ok'], isTrue);
    final guestState = next(guest, 'game_state');
    final started = await host.request('start_game');
    expect(started['ok'], isTrue, reason: '$started');
    final first = await guestState;
    expect(first['host'], 'hostA');
    expect(first['relay'], isTrue);

    // The guest's move goes to the host; the host's state goes to the guest.
    final hostGetsMove =
        next(host, 'game_state', (s) => (s['inputs'] as List).isNotEmpty);
    expect(
        (await guest.request('game_action', {
          'type': 'relay:input',
          'seq': 1,
          'payload': {
            'name': 'tap',
            'args': [4]
          }
        }))['ok'],
        isTrue);
    final withMove = await hostGetsMove;
    expect(((withMove['inputs'] as List).single as Map)['args'], [4]);

    final guestGetsState = next(guest, 'game_state', (s) => s['version'] == 1);
    expect(
        (await host.request('game_action', {
          'type': 'relay:state',
          'seq': 1,
          'payload': {
            'state': {
              'board': [1, 0, 0]
            },
            'ack': 1
          }
        }))['ok'],
        isTrue);
    expect(((await guestGetsState)['state'] as Map)['board'], [1, 0, 0]);

    final result = next(guest, 'game_finished');
    expect(
        (await host.request('game_action', {
          'type': 'relay:finish',
          'seq': 2,
          'payload': {
            'scores': [1, 0]
          }
        }))['ok'],
        isTrue);
    final r = await result;
    expect(r['winners'], ['hostA']);

    host.dispose();
    guest.dispose();
  });

  test(
      'errors come back like the internet server\'s, and internet-only games are refused',
      () async {
    final s = SocketManager();
    await s.connect(url, 'dev:solo1:Mila');
    expect(await s.request('join_room', {'code': 'ZZZZZZ'}),
        containsPair('error', 'ROOM_NOT_FOUND'));
    expect(
        await s.request(
            'create_room', {'gameType': 'raja_mantri', 'maxPlayers': 4}),
        containsPair('error', 'NEEDS_INTERNET'));
    expect(
        await s.request('nonsense'), containsPair('error', 'INVALID_ACTION'));
    final q = await s.request('quick_play', {});
    expect(q['ok'], isTrue);
    expect((q['room'] as Map)['isPublic'], isTrue);
    s.dispose();
  });

  test('a phone that drops out can come back to its room', () async {
    final a = SocketManager(), b = SocketManager();
    await a.connect(url, 'dev:alpha:A');
    await b.connect(url, 'dev:beta:B');
    final code = ((await a.request(
            'create_room', {'gameType': 'bingo', 'maxPlayers': 3}))['room']
        as Map)['code'];
    await b.request('join_room', {'code': code});
    final aSeesDrop = next(a, 'player_disconnected');
    b.disconnect();
    expect((await aSeesDrop)['userId'], 'beta');
    final b2 = SocketManager();
    final aSeesBack = next(a, 'player_reconnected');
    await b2.connect(url, 'dev:beta:B');
    expect((await aSeesBack)['userId'], 'beta');
    expect(((await b2.request('resume_session'))['room'] as Map)['code'], code);
    a.dispose();
    b2.dispose();
  });

  test('bad sign-ins are turned away', () async {
    final s = SocketManager();
    await expectLater(s.connect(url, 'not-a-token'), throwsA(anything));
    s.dispose();
  });
}
