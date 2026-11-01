import '../../games/game_catalog.dart';
import '../network/lan_discovery.dart';
import 'lan_rooms.dart';
import 'lan_server.dart';

/// "Host on this phone": runs the game server inside the app so friends on this phone's
/// hotspot (or the same Wi-Fi) can play with no internet and no laptop.
class LanHost {
  LanHost._();
  static LanServer? _server;

  /// Nitro's dedicated stream protocol, like Guess Who and Raja Mantri's rules,
  /// requires the internet server rather than the generic phone-hosted relay.
  static const internetOnly = {'guess_who', 'raja_mantri', 'nitro_knockout'};
  static List<LanGame> get games => [
        for (final g in gameCatalog)
          if (!internetOnly.contains(g.id))
            LanGame(g.id, g.minPlayers, g.maxPlayers),
      ];

  static bool get running => _server?.running ?? false;

  /// The address this phone's own app connects to.
  static String get selfUrl => 'http://127.0.0.1:${LanServer.defaultPort}';

  /// Starts the server (if it isn't running yet).
  static Future<void> start() async {
    if (running) return;
    final s = LanServer(LanRooms(games));
    await s.start();
    _server = s;
  }

  static Future<void> stop() async {
    await _server?.stop();
    _server = null;
  }

  /// This phone's addresses others can reach (hotspot / Wi-Fi), to show on screen.
  static Future<List<String>> addresses() async =>
      [for (final a in await LanDiscovery.localAddresses()) a.address];
}
