import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/room/room_manager.dart';
import '../../core/ui/app_ui.dart' show AppBackground;
import '../../core/ui/components.dart';
import '../../games/game_catalog.dart';
import '../create_room/game_grid.dart';
import '../lobby/lobby_screen.dart';

/// Quick Play: be matched into a random open room with other players, for any game or one
/// you pick. If nobody is waiting, a new open room starts and the next quick players join it.
class QuickPlayScreen extends StatefulWidget {
  const QuickPlayScreen({super.key});
  @override
  State<QuickPlayScreen> createState() => _QuickPlayScreenState();
}

class _QuickPlayScreenState extends State<QuickPlayScreen> {
  String? gameId; // null: any game
  bool busy = false;

  Future<void> _go() async {
    final rm = context.read<RoomManager>();
    final nav = Navigator.of(context);
    setState(() => busy = true);
    final err = await rm.quickPlay(gameId);
    if (!mounted) return;
    if (err != null) {
      setState(() => busy = false);
      showToast(context, friendlyError(err), tone: Tone.danger, duration: const Duration(seconds: 3));
      return;
    }
    nav.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LobbyScreen()), (r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final game = gameId == null ? null : gameCatalog.firstWhere((g) => g.id == gameId);
    final any = gameId == null;
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Padding(padding: EdgeInsets.fromLTRB(16, 14, 16, 10), child: PageHeader(label: 'Quick play', title: 'Play with anyone')),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Semantics(
                button: true,
                selected: any,
                label: 'Any game',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () {
                    haptic(HapticWeight.selection);
                    setState(() => gameId = null);
                  },
                  child: AnimatedContainer(
                    duration: Motion.of(context, Motion.fast),
                    padding: const EdgeInsets.all(16),
                    decoration: any ? Skin.primary(radius: Radii.button) : Skin.surface(radius: Radii.button),
                    child: Row(children: [
                      GameIcon(GameIcons.dice5, size: 36, color: any ? Brand.onGold : (t.flat ? FlatPalette.ink : Colors.white)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Any game', style: TextStyle(fontFamily: Fonts.display, fontSize: 22, color: any ? Brand.onGold : (t.flat ? FlatPalette.ink : Colors.white))),
                          Text("Fastest match: the room's host picks the games",
                              style: TextStyle(fontFamily: Fonts.body, fontSize: 12.5, fontWeight: FontWeight.w800, color: any ? Brand.onGold.withValues(alpha: 0.8) : (t.flat ? FlatPalette.inkMuted : NeonPalette.textMuted))),
                        ]),
                      ),
                      if (any) const GameIcon(GameIcons.check, size: 22, color: Brand.onGold),
                    ]),
                  ),
                ),
              ),
            ),
            const Padding(padding: EdgeInsets.fromLTRB(16, 6, 16, 2), child: SectionHeader('Or pick a game')),
            Expanded(child: GameGrid(selectedId: gameId, onSelect: (g) => setState(() => gameId = g.id))),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
              decoration: Skin.sheet(),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (busy)
                  const _Finding()
                else
                  Text(game == null ? 'Any game · rooms of up to 6' : '${game.name} · ${game.playersLabel} players',
                      textAlign: TextAlign.center, style: TextStyle(fontFamily: Fonts.body, fontWeight: FontWeight.w900, fontSize: 15, color: t.flat ? FlatPalette.ink : Colors.white)),
                const SizedBox(height: 10),
                GoldButton(busy ? 'Finding players…' : 'Find a room', icon: GameIcons.bolt, onPressed: busy ? null : _go),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// "Finding a room" with three bouncing dots.
class _Finding extends StatefulWidget {
  const _Finding();
  @override
  State<_Finding> createState() => _FindingState();
}

class _FindingState extends State<_Finding> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ink = context.tk.flat ? FlatPalette.ink : Colors.white;
    return Semantics(
      liveRegion: true,
      label: 'Finding a room',
      excludeSemantics: true,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('Finding a room', style: TextStyle(fontFamily: Fonts.display, fontSize: 18, color: ink)),
        const SizedBox(width: 6),
        AnimatedBuilder(
          animation: _c,
          builder: (_, __) => Row(children: [
            for (var i = 0; i < 3; i++)
              Transform.translate(
                offset: Offset(0, Motion.reduced(context) ? 0 : -4 * (1 - ((_c.value * 3 - i) % 3 - 0.5).abs() * 2).clamp(0.0, 1.0)),
                child: Container(width: 6, height: 6, margin: const EdgeInsets.symmetric(horizontal: 2), decoration: const BoxDecoration(color: Brand.gold, shape: BoxShape.circle)),
              ),
          ]),
        ),
      ]),
    );
  }
}
