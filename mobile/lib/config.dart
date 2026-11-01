import 'package:shared_preferences/shared_preferences.dart';

/// How rooms are played: through the internet server, or a laptop on the same Wi-Fi/hotspot.
enum ServerMode { online, wifi }

class AppConfig {
  // The internet server built into the app. Emulator default -> the computer it runs on;
  // release builds pass --dart-define=SERVER_URL=https://<name>.onrender.com
  static const defaultServerUrl = String.fromEnvironment('SERVER_URL',
      defaultValue: 'http://10.0.2.2:3000');

  static ServerMode mode = ServerMode.online;

  /// The server in use: the built-in one online, or the one found on the Wi-Fi.
  static String serverUrl = defaultServerUrl;

  /// Same Wi-Fi, with this phone running the game server for the others.
  static bool hosting = false;

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final wifiUrl = p.getString('wifi_server_url');
      // Online always uses the server this app was built with (older saved addresses are ignored).
      mode = p.getString('server_mode') == 'wifi' && wifiUrl != null
          ? ServerMode.wifi
          : ServerMode.online;
      serverUrl = mode == ServerMode.wifi ? wifiUrl! : defaultServerUrl;
      hosting = mode == ServerMode.wifi && p.getBool('hosting') == true;
    } catch (_) {
      mode = ServerMode.online;
      serverUrl = defaultServerUrl;
      hosting = false;
    }
  }

  /// Accepts "192.168.1.20:3000" or a full URL; returns the normalised URL, or null if invalid.
  static String? normalise(String input) {
    var s = input.trim();
    if (s.isEmpty) return null;
    if (!s.startsWith('http://') && !s.startsWith('https://')) s = 'http://$s';
    final uri = Uri.tryParse(s);
    if (uri == null || uri.host.isEmpty) return null;
    return s.endsWith('/') ? s.substring(0, s.length - 1) : s;
  }

  static Future<void> useOnline() async {
    mode = ServerMode.online;
    serverUrl = defaultServerUrl;
    hosting = false;
    final p = await SharedPreferences.getInstance();
    await p.setString('server_mode', 'online');
    await p.setBool('hosting', false);
  }

  /// Same Wi-Fi: remember the server's address for next time ([hosting]: it's this phone).
  static Future<void> useWifi(String url, {bool hosting = false}) async {
    mode = ServerMode.wifi;
    serverUrl = url;
    AppConfig.hosting = hosting;
    final p = await SharedPreferences.getInstance();
    await p.setString('server_mode', 'wifi');
    await p.setString('wifi_server_url', url);
    await p.setBool('hosting', hosting);
  }
}
