import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/ads/ad_mob_service.dart';
import 'config.dart';
import 'core/audio/game_audio.dart';
import 'core/settings/app_settings.dart';
import 'core/auth/authentication_manager.dart';
import 'core/lan/lan_host.dart';
import 'core/network/socket_manager.dart';
import 'core/room/room_manager.dart';
import 'core/session/game_session_manager.dart';
import 'core/ui/app_flavor.dart';
import 'core/ui/app_ui.dart';
import 'features/splash/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Render the first frame before touching preferences, LAN sockets, or ad consent.
  // These services are useful but must never be prerequisites for opening the app.
  runApp(const App());
  unawaited(_initializeBackgroundServices());
  unawaited(AdMobService.instance.initialize());
}

Future<void> _initializeBackgroundServices() async {
  await Future.wait([
    _startupStep('configuration', AppConfig.load),
    _startupStep('audio preferences', GameAudio.init),
    _startupStep('app preferences', AppSettings.init),
  ]);

  // This phone was hosting games for the others (hotspot, no internet): start its server again.
  if (AppConfig.hosting) {
    try {
      await LanHost.start().timeout(const Duration(seconds: 3));
    } catch (error, stack) {
      debugPrint(
        '[startup] LAN host unavailable; continuing without hosting: $error',
      );
      debugPrintStack(stackTrace: stack);
      AppConfig.mode = ServerMode.online;
      AppConfig.serverUrl = AppConfig.defaultServerUrl;
      AppConfig.hosting = false;
      unawaited(
        AppConfig.useOnline().timeout(const Duration(seconds: 3)).catchError((
          Object error,
          StackTrace stack,
        ) {
          debugPrint('[startup] Could not persist online fallback: $error');
        }),
      );
    }
  }
}

Future<void> _startupStep(
  String name,
  Future<void> Function() initialize,
) async {
  try {
    await initialize().timeout(const Duration(seconds: 3));
  } catch (error, stack) {
    debugPrint('[startup] $name unavailable; using defaults: $error');
    debugPrintStack(stackTrace: stack);
  }
}

class App extends StatefulWidget {
  const App({super.key});
  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final auth = AuthenticationManager();
  final socket = SocketManager();
  late final RoomManager rooms = RoomManager(socket);
  late final GameSessionManager session = GameSessionManager(socket);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        Provider.value(value: socket),
        ChangeNotifierProvider.value(value: rooms),
        ChangeNotifierProvider.value(value: session),
      ],
      child: MaterialApp(
        title: appName,
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const SplashScreen(),
      ),
    );
  }
}
