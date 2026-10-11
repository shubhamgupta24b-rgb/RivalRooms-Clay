import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config.dart';
import '../../core/auth/authentication_manager.dart';
import '../../core/network/socket_manager.dart';
import '../../core/ui/app_flavor.dart';
import '../../core/ui/app_ui.dart';
import '../home/home_screen.dart';
import '../login/login_screen.dart';

class SplashScreen extends StatefulWidget {
  /// How long the logo shows at least, so the intro animation can play.
  final Duration minShow;
  const SplashScreen({super.key, this.minShow = const Duration(milliseconds: 1400)});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..forward();
  final _slow = Future<void>.delayed(const Duration(seconds: 1));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    final auth = context.read<AuthenticationManager>();
    final socket = context.read<SocketManager>();
    final nav = Navigator.of(context);
    final results = await Future.wait([auth.restore(), Future<bool>.delayed(widget.minShow, () => true)]);
    if (!mounted) return;
    if (!results.first) {
      nav.pushReplacement(_fade(const LoginScreen()));
      return;
    }
    // Don't block on the server: 1-device games work offline, online rooms connect when they can.
    unawaited(socket.connect(AppConfig.serverUrl, auth.token).catchError((_) {}));
    nav.pushReplacement(_fade(const HomeScreen()));
  }

  static Route<void> _fade(Widget page) => PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
      );

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: _intro, curve: const Interval(0, 0.33, curve: Curves.easeOut)); // 360 ms
    final t = context.tk;
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: FadeTransition(
                opacity: fade,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const AppLogo(size: 200),
                  const SizedBox(height: 24),
                  Text(appName, textAlign: TextAlign.center, style: t.styles.h1.copyWith(color: t.onBg)),
                  const SizedBox(height: 6),
                  Text('One phone or many · play anywhere', textAlign: TextAlign.center, style: t.styles.body.copyWith(color: t.onBgMuted)),
                  const SizedBox(height: 28),
                  // A spinner only when loading takes longer than a second.
                  SizedBox(
                    height: 24,
                    child: FutureBuilder<void>(
                      future: _slow,
                      builder: (_, snap) => snap.connectionState == ConnectionState.done
                          ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Brand.gold, backgroundColor: Brand.gold.withValues(alpha: 0.18)))
                          : const SizedBox.shrink(),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
