import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config.dart';
import '../../core/auth/authentication_manager.dart';
import '../../core/network/socket_manager.dart';
import '../../core/ui/app_ui.dart';
import '../../core/ui/components.dart';
import '../../core/settings/app_settings.dart';
import '../home/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final nameCtrl = TextEditingController();
  bool busy = false;

  @override
  void initState() {
    super.initState();
    nameCtrl.addListener(() => setState(() {})); // live avatar preview
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _guest() async {
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return _snack('Enter your name to start');
    final auth = context.read<AuthenticationManager>();
    final socket = context.read<SocketManager>();
    final nav = Navigator.of(context);
    setState(() => busy = true);
    try {
      await auth.signInAsGuest(name);
      // Don't wait for the server: 1-device games work offline, online rooms connect when they can.
      unawaited(socket.connect(AppConfig.serverUrl, auth.token).catchError((_) {}));
      nav.pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    } catch (e) {
      _snack('$e');
      if (mounted) setState(() => busy = false);
    }
  }

  void _snack(String m) => showToast(context, friendlyError(m), tone: Tone.warn, duration: const Duration(seconds: 3));

  @override
  Widget build(BuildContext context) {
    final name = nameCtrl.text.trim();
    final t = context.tk;
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: ValueListenableBuilder<int>(
                  valueListenable: AppSettings.playerColor,
                  builder: (context, seat, _) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const Center(child: AppLogo(size: 128)),
                    const SizedBox(height: 18),
                    Text('WELCOME!', textAlign: TextAlign.center, style: t.styles.label),
                    const SizedBox(height: 2),
                    Semantics(header: true, child: Text("Who's playing?", textAlign: TextAlign.center, style: t.styles.h1.copyWith(color: t.onBg))),
                    const SizedBox(height: 4),
                    Text('Game night for friends: on one phone or online.', textAlign: TextAlign.center, style: t.styles.body.copyWith(color: t.onBgMuted)),
                    const SizedBox(height: 22),
                    Center(
                      child: AnimatedSwitcher(
                        duration: Motion.of(context, Motion.normal),
                        child: PlayerBadge(key: ValueKey('$seat${name.isEmpty}'), index: seat, size: 64, initial: name.isEmpty ? '?' : name),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('YOUR NAME', style: t.styles.label),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameCtrl,
                      maxLength: 20,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.go,
                      onSubmitted: (_) => busy ? null : _guest(),
                      cursorColor: Brand.gold,
                      style: TextStyle(fontFamily: Fonts.body, color: t.flat ? FlatPalette.ink : Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                      decoration: InputDecoration(
                        hintText: 'Your name',
                        counterText: '',
                        hintStyle: TextStyle(fontFamily: Fonts.body, fontWeight: FontWeight.w700, color: t.flat ? FlatPalette.inkMuted : NeonPalette.label),
                        filled: true,
                        fillColor: t.flat ? Colors.white : t.surfaceStrong,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        enabledBorder: OutlineInputBorder(borderRadius: Radii.rButton, borderSide: BorderSide(color: t.flat ? FlatPalette.stroke : Colors.white.withValues(alpha: 0.14))),
                        focusedBorder: OutlineInputBorder(borderRadius: Radii.rButton, borderSide: BorderSide(color: t.flat ? FlatPalette.ink : Brand.gold, width: 2)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('YOUR COLOUR', style: t.styles.label),
                    const SizedBox(height: 6),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      for (var i = 0; i < PlayerPalette.colors.length; i++)
                        Semantics(
                          button: true,
                          selected: i == seat,
                          label: 'Colour ${i + 1}',
                          excludeSemantics: true,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              haptic(HapticWeight.selection);
                              AppSettings.setPlayerColor(i);
                            },
                            child: AnimatedContainer(
                              duration: Motion.of(context, Motion.fast),
                              width: kTouchTarget,
                              height: kTouchTarget,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i == seat ? (t.flat ? Colors.white : Colors.white.withValues(alpha: 0.12)) : Colors.transparent,
                                border: Border.all(color: i == seat ? (t.flat ? FlatPalette.ink : Brand.gold) : Colors.transparent, width: 2),
                              ),
                              child: PlayerBadge(index: i, size: 28),
                            ),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 22),
                    GoldButton(busy ? 'Getting ready…' : 'Play as guest', height: 58, icon: GameIcons.play, onPressed: busy ? null : _guest),
                    const SizedBox(height: 14),
                    Text('Google sign-in coming soon. Guest play needs no account.', textAlign: TextAlign.center, style: t.styles.bodySmall.copyWith(color: t.flat ? t.onBg : NeonPalette.label)),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
