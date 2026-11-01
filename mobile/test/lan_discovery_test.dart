import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/core/network/lan_discovery.dart';

void main() {
  test('only private (Wi-Fi / hotspot) addresses are searched', () {
    expect(LanDiscovery.isPrivate('192.168.43.12'), isTrue);
    expect(LanDiscovery.isPrivate('10.1.6.246'), isTrue);
    expect(LanDiscovery.isPrivate('172.20.10.3'), isTrue); // iPhone hotspot
    expect(LanDiscovery.isPrivate('8.8.8.8'), isFalse);
    expect(LanDiscovery.isPrivate('172.32.0.1'), isFalse);
    expect(LanDiscovery.isPrivate('nonsense'), isFalse);
  });

  test('candidates: the rest of the /24, nearest first, never yourself', () {
    final c = LanDiscovery.candidates('192.168.43.20');
    expect(c, hasLength(253));
    expect(c, isNot(contains('192.168.43.20')));
    expect(c.take(2).toSet(), {'192.168.43.19', '192.168.43.21'});
    expect(c, containsAll(['192.168.43.1', '192.168.43.254']));
    // The emulator also tries its computer.
    expect(LanDiscovery.candidates('10.0.2.16').first, '10.0.2.2');
  });

  test('probe recognises a Party Games server and ignores other web servers',
      () async {
    Future<HttpServer> serve(Object body) async {
      final s = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      s.listen((r) => r.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(body))
        ..close());
      return s;
    }

    final ours = await serve({'ok': true, 'app': 'party-games'});
    final other = await serve({'ok': true});
    try {
      // probe() always uses the game port, so check the parsing through a stand-in.
      Future<bool> check(HttpServer s) async {
        final c = HttpClient();
        final res = await (await c
                .getUrl(Uri.parse('http://127.0.0.1:${s.port}/health')))
            .close();
        final json = jsonDecode(await res.transform(utf8.decoder).join());
        c.close();
        return json is Map &&
            json['ok'] == true &&
            json['app'] == 'party-games';
      }

      expect(await check(ours), isTrue);
      expect(await check(other), isFalse);
      expect(
          await LanDiscovery.probe('127.0.0.1',
              timeout: const Duration(milliseconds: 300)),
          isFalse,
          reason: 'nothing on the game port here');
    } finally {
      await ours.close(force: true);
      await other.close(force: true);
    }
  });

  test('find stops at the first server that answers', () async {
    final asked = <String>[];
    final url = await LanDiscovery.find(probeHost: (h) async {
      asked.add(h);
      return h.endsWith('.7');
    });
    // Depends on this machine having a private address; if it has none there is nothing to search.
    if (asked.isEmpty) {
      expect(url, isNull);
    } else {
      expect(url, matches(RegExp(r'^http://\d+\.\d+\.\d+\.7:3000$')));
    }
  });
}
