import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Finds a Party Games server on the same Wi-Fi or hotspot: asks every address on this
/// phone's local network(s) for /health on the game port and takes the first that answers
/// as a Party Games server. Takes a few seconds; no setup on the phones.
class LanDiscovery {
  static const port = 3000;

  /// The phone's own local IPv4 addresses (Wi-Fi, hotspot, emulator).
  static Future<List<InternetAddress>> localAddresses() async {
    try {
      final ifaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4, includeLoopback: false);
      return [
        for (final i in ifaces)
          for (final a in i.addresses)
            if (isPrivate(a.address)) a,
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Home, campus and hotspot networks use these ranges; never scan the open internet.
  static bool isPrivate(String ip) {
    final p = ip.split('.').map(int.tryParse).toList();
    if (p.length != 4 || p.contains(null)) return false;
    final a = p[0]!, b = p[1]!;
    return a == 10 ||
        (a == 172 && b >= 16 && b <= 31) ||
        (a == 192 && b == 168);
  }

  /// Addresses to try for one of our own addresses: the rest of its /24 network, nearest first,
  /// plus the Android emulator's alias for the computer it runs on.
  static List<String> candidates(String own) {
    final p = own.split('.');
    final base = '${p[0]}.${p[1]}.${p[2]}.';
    final me = int.parse(p[3]);
    final hosts = [
      for (var i = 1; i <= 254; i++)
        if (i != me) i
    ]..sort((x, y) => (x - me).abs().compareTo((y - me).abs()));
    return [
      if (own.startsWith('10.0.2.')) '10.0.2.2', // emulator -> its computer
      for (final h in hosts) '$base$h',
    ];
  }

  /// True if [host] runs a Party Games server.
  static Future<bool> probe(String host,
      {Duration timeout = const Duration(milliseconds: 700)}) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final req = await client
          .getUrl(Uri.parse('http://$host:$port/health'))
          .timeout(timeout);
      final res = await req.close().timeout(timeout);
      if (res.statusCode != 200) return false;
      final body = await res.transform(utf8.decoder).join().timeout(timeout);
      final json = jsonDecode(body);
      return json is Map && json['ok'] == true && json['app'] == 'party-games';
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  /// Searches the local network(s); returns the server's URL (http://ip:3000) or null.
  /// [onProgress] gets 0..1 as the search goes.
  static Future<String?> find(
      {void Function(double)? onProgress,
      Future<bool> Function(String host)? probeHost}) async {
    final check = probeHost ?? probe;
    final own = await localAddresses();
    final hosts =
        <String>{for (final a in own) ...candidates(a.address)}.toList();
    if (hosts.isEmpty) return null;
    const batch = 48; // parallel checks at a time
    for (var i = 0; i < hosts.length; i += batch) {
      final part =
          hosts.sublist(i, i + batch > hosts.length ? hosts.length : i + batch);
      final results = await Future.wait(part.map(check));
      final hit = results.indexWhere((ok) => ok);
      onProgress?.call((i + part.length) / hosts.length);
      if (hit >= 0) return 'http://${part[hit]}:$port';
    }
    return null;
  }
}
