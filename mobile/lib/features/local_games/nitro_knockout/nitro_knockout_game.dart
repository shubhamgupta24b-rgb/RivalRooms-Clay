import 'package:flutter/material.dart';

import '../shell/local_game_info.dart';
import '../shell/local_game_shell.dart' show HelpButton, PauseButton;
import 'nitro_game_view.dart';

export 'nitro_game_view.dart' show NitroBoot, NitroViewController;

/// The original WASM game runs offline exactly as shipped: 8 karts — you against
/// NOVA, BOLT, ROOK, JINX, MISO, APEX and ECHO, the seven built-in AI drivers.
/// No account, no server, no network: everything (Three.js scene, Rapier physics
/// WASM, audio) is bundled under assets/nitro/.
final LocalGameInfo nitroKartsInfo = LocalGameInfo(
  id: 'nitro_knockout',
  title: 'Nitro Knockout',
  emoji: '🏎️',
  color: const Color(0xFFFF5722),
  tagline: '3D kart combat · you vs 7 bots',
  rules: const [
    'Drive with the on-screen stick (or WASD). Drive through a ❓ crate for a weapon, then FIRE.',
    '🚀 Rocket, 💣 Mines and 💫 Shockwave hit hard · 🔫 Blaster shreds fast · 🛡️ Shield blocks one hit.',
    'Karts have 100 HP. A wrecked kart respawns invulnerable for 2s. Yellow pads boost, jump pads launch.',
    'Most knockouts in 90 seconds wins! Online rooms seat 2–10 human players.',
  ],
  scoreUnit: 'KOs',
  splitScreen: false,
  minPlayers: 1,
  maxPlayers: 1,
  play: (players, onFinished) => NitroOfflineView(onFinished: onFinished),
);

class NitroOfflineView extends StatefulWidget {
  final void Function(List<int> scores) onFinished;
  const NitroOfflineView({super.key, required this.onFinished});

  @override
  State<NitroOfflineView> createState() => _NitroOfflineViewState();
}

class _NitroOfflineViewState extends State<NitroOfflineView> {
  final NitroViewController _controller = NitroViewController();
  bool _reported = false;

  void _onMessage(Map<String, dynamic> message) {
    switch (message['kind']) {
      case 'result':
        // The match ended: hand the score to the game shell (records, result screen).
        if (_reported) return;
        _reported = true;
        final score = (message['score'] as num?)?.toInt() ?? 0;
        widget.onFinished([score]);
      case 'boot':
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Full-bleed: the WASM game owns the whole surface (canvas + HUD overlay).
    // The shell's pause/help buttons float on top (the 3D scene renders behind them).
    return Stack(
      fit: StackFit.expand,
      children: [
        NitroGameView(
          controller: _controller,
          boot: const NitroBoot(mode: 'offline'),
          onMessage: _onMessage,
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(left: 8, top: 4),
            child: Align(
              alignment: Alignment.topLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const PauseButton(dark: true),
                  const SizedBox(width: 6),
                  const HelpButton(dark: true),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
