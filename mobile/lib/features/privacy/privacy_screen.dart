import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/authentication_manager.dart';
import '../../core/network/socket_manager.dart';
import '../../core/records/records.dart';
import '../../core/ui/app_ui.dart' show AppBackground;
import '../../core/ui/components.dart';
import '../login/login_screen.dart';

/// The privacy policy in short (the full text is on the server's /privacy page), and a way
/// to delete everything this app keeps on the phone (spec 4.11).
/// Keep in step with server/src/pages/privacy.js.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const _points = [
    (GameIcons.people, 'No account', 'You only type a player name. No email, phone number or Google account.'),
    (GameIcons.eye, 'Who sees what', 'Players in your room see your name and your moves. Nobody else.'),
    (GameIcons.lock, 'Kept on this phone', 'Your name, a random player ID and your records (best scores, wins).'),
    (GameIcons.globe, 'The game server', 'Passes moves between players and forgets a room when it ends.'),
    (GameIcons.shield, 'Never collected', 'Location, contacts, photos, camera, microphone, ads or tracking.'),
  ];

  Future<void> _delete(BuildContext context) async {
    final sure = await confirmAction(context,
        title: 'Delete my data?',
        message: 'This removes your name, player ID and all your records from this phone. You can start again with a new name.',
        confirm: 'Delete',
        cancel: 'Keep',
        emoji: null);
    if (!sure || !context.mounted) return;
    final auth = context.read<AuthenticationManager>();
    final socket = context.read<SocketManager>();
    final nav = Navigator.of(context);
    socket.disconnect();
    await Records.clear();
    await auth.signOut();
    nav.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final ink = t.flat ? FlatPalette.ink : Colors.white;
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 24), children: [
                const PageHeader(label: 'Your data', title: 'Privacy'),
                const SizedBox(height: 14),
                for (final (icon, title, text) in _points)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: Skin.surface(radius: Radii.lg, depth: 0.8),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: PlayerPalette.colors[0].withValues(alpha: 0.2), borderRadius: Radii.rCard),
                        child: GameIcon(icon, size: 20, color: t.flat ? fillFor(PlayerPalette.colors[0]) : PlayerPalette.tints[0]),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(title, style: TextStyle(fontFamily: Fonts.body, fontSize: 15.5, fontWeight: FontWeight.w900, color: ink)),
                          const SizedBox(height: 2),
                          Text(text, style: TextStyle(fontFamily: Fonts.body, fontSize: 15, fontWeight: FontWeight.w700, height: 1.4, color: t.flat ? FlatPalette.inkMuted : NeonPalette.textMuted)),
                        ]),
                      ),
                    ]),
                  ),
                const SizedBox(height: 6),
                Text("The full policy is on the game server's /privacy page and in the app's store listing.",
                    textAlign: TextAlign.center, style: t.styles.bodySmall.copyWith(color: t.flat ? t.onBg : NeonPalette.label)),
                const SizedBox(height: 18),
                KitButton('Delete my data on this phone', style: KitButtonStyle.danger, height: 52, onPressed: () => _delete(context)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
