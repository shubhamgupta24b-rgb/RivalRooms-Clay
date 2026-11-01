import 'package:flutter/material.dart';
import '../../../core/audio/game_audio.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/ui/components.dart';
import 'how_to_play.dart';
import 'local_game_info.dart';

enum PauseAction { resume, restart, quit }

/// The pause sheet (spec 2.8, mockup app/Pause.dc.html): the game dims, "Paused" with the
/// game's state line above a bottom sheet with Resume, Restart, How to play, the Sound /
/// Vibration / Reduce motion switches (saved on the phone) and Quit game.
Future<PauseAction?> showPauseSheet(BuildContext context,
    {required LocalGameInfo game, String? state}) {
  return showGeneralDialog<PauseAction>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Resume',
    barrierColor: const Color(0x9E060820), // rgba(6,8,32,0.62)
    transitionDuration: Motion.of(context, Motion.normal),
    pageBuilder: (ctx, _, __) =>
        TokenScope(flat: false, child: PauseSheet(game: game, state: state)),
    transitionBuilder: (ctx, a, _, child) {
      final curve = CurvedAnimation(parent: a, curve: Motion.standard);
      return FadeTransition(opacity: curve, child: child);
    },
  );
}

class PauseSheet extends StatelessWidget {
  final LocalGameInfo game;
  final String? state;
  const PauseSheet({super.key, required this.game, this.state});

  @override
  Widget build(BuildContext context) {
    final a = ModalRoute.of(context)?.animation;
    final sheet = _Sheet(game: game);
    return Material(
      type: MaterialType.transparency,
      child: Stack(children: [
        Positioned(
          left: 16,
          right: 16,
          top: MediaQuery.paddingOf(context).top + 24,
          bottom: 0,
          child: Column(children: [
            Expanded(
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                      [
                        game.title,
                        if (state != null && state!.isNotEmpty) state!
                      ].join(' · ').toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontFamily: Fonts.body,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.76,
                          color: NeonPalette.textMuted)),
                  const SizedBox(height: 4),
                  Semantics(
                      header: true,
                      child: const Text('Paused',
                          style: TextStyle(
                              fontFamily: Fonts.display,
                              fontSize: 44,
                              height: 1.05,
                              color: Colors.white))),
                ]),
              ),
            ),
            const SizedBox(height: 330), // room for the sheet
          ]),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: a == null
              ? sheet
              : SlideTransition(
                  position: Tween(
                          begin: const Offset(0, 0.25), end: Offset.zero)
                      .animate(
                          CurvedAnimation(parent: a, curve: Motion.emphasized)),
                  child: sheet),
        ),
      ]),
    );
  }
}

class _Sheet extends StatelessWidget {
  final LocalGameInfo game;
  const _Sheet({required this.game});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: Skin.sheet(),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.85),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 26),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                          child: Container(
                              width: 44,
                              height: 5,
                              decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(3)))),
                      const SizedBox(height: 10),
                      GoldButton('Resume',
                          icon: GameIcons.play,
                          height: 58,
                          onPressed: () =>
                              Navigator.pop(context, PauseAction.resume)),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                            child: KitButton('Restart',
                                icon: GameIcons.restart,
                                height: 52,
                                onPressed: () => Navigator.pop(
                                    context, PauseAction.restart))),
                        const SizedBox(width: 10),
                        Expanded(
                            child: KitButton('How to play',
                                icon: GameIcons.help,
                                height: 52,
                                onPressed: () => showHowToPlay(context, game))),
                      ]),
                      const SizedBox(height: 10),
                      const PauseToggles(),
                      const SizedBox(height: 10),
                      KitButton('Quit game',
                          style: KitButtonStyle.danger,
                          height: 50,
                          onPressed: () =>
                              Navigator.pop(context, PauseAction.quit)),
                    ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sound, Vibration and Reduce motion as switch rows in one card (Pause mockup).
class PauseToggles extends StatelessWidget {
  const PauseToggles({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(
          [GameAudio.settings, AppSettings.haptics, Motion.reduceSetting]),
      builder: (context, _) {
        final s = GameAudio.settings.value;
        final sound = s.sfx || s.music;
        Widget row(GameIcons icon, String label, bool value,
                ValueChanged<bool> onChanged,
                {bool last = false}) =>
            MergeSemantics(
              child: InkWell(
                onTap: () {
                  haptic(HapticWeight.selection);
                  onChanged(!value);
                },
                child: Container(
                  height: 54,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                      border: last
                          ? null
                          : Border(
                              bottom: BorderSide(
                                  color:
                                      Colors.white.withValues(alpha: 0.08)))),
                  child: Row(children: [
                    GameIcon(icon, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(label,
                            style: const TextStyle(
                                fontFamily: Fonts.body,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: Colors.white))),
                    PillSwitch(value: value, onChanged: onChanged),
                  ]),
                ),
              ),
            );
        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: Skin.surface(radius: Radii.lg, depth: 0.7),
          child: Material(
            type: MaterialType.transparency,
            child: Column(children: [
              row(GameIcons.sound, 'Sound', sound, (v) {
                GameAudio.update(s.copyWith(sfx: v, music: v));
                if (v) GameAudio.sfx('tap');
              }),
              row(GameIcons.vibration, 'Vibration', AppSettings.haptics.value,
                  AppSettings.setHaptics),
              row(GameIcons.clock, 'Reduce motion', Motion.reduceSetting.value,
                  AppSettings.setReduceMotion,
                  last: true),
            ]),
          ),
        );
      },
    );
  }
}
