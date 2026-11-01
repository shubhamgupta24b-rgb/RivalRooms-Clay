import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config.dart';
import '../../core/room/room_manager.dart';
import '../../core/ui/app_ui.dart' show AppBackground;
import '../../core/ui/components.dart';
import '../../games/game_catalog.dart';
import '../local_games/shell/game_art.dart';
import '../lobby/lobby_screen.dart';
import 'game_grid.dart';

/// Pick the first game and the room size, then create a room friends join with its code.
/// The host can switch games in the room between rounds.
class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});
  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  String gameId = gameCatalog.first.id;
  int players = 4;
  bool busy = false;

  GameInfo get game => gameCatalog.firstWhere((g) => g.id == gameId);

  Future<void> _create() async {
    final rm = context.read<RoomManager>();
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => busy = true);
    final err = await rm.create(gameId, players);
    if (!mounted) return;
    if (err != null) {
      setState(() => busy = false);
      messenger.hideCurrentSnackBar();
      if (mounted)
        showToast(context, friendlyError(err),
            tone: Tone.danger, duration: const Duration(seconds: 3));
      return;
    }
    nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LobbyScreen()),
        (r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final maxPlayers = AppConfig.mode == ServerMode.online ? 10 : 6;
    bool fits(GameInfo g) => players >= g.minPlayers && players <= g.maxPlayers;
    final fitting = gameCatalog.where(fits).length;
    final compact = MediaQuery.sizeOf(context).height < 700;
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: PageHeader(
                  label: 'Create a room',
                  title: compact ? null : 'One room, any game'),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: _RoomSize(
                  players: players,
                  maxPlayers: maxPlayers,
                  onPlayers: (n) => setState(() => players = n)),
            ),
            Expanded(
              child: GameGrid(
                selectedId: gameId,
                fits: fits,
                onSelect: (g) => setState(() => gameId = g.id),
                header: Text(
                    '$fitting games fit $players players · switch games between rounds',
                    style: t.styles.label),
              ),
            ),
            _BottomPanel(
                game: game, fits: fits(game), busy: busy, onCreate: _create),
          ]),
        ),
      ),
    );
  }
}

/// Room size: a - / + stepper and one badge per seat.
class _RoomSize extends StatelessWidget {
  final int players, maxPlayers;
  final ValueChanged<int> onPlayers;
  const _RoomSize({required this.players, required this.maxPlayers, required this.onPlayers});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    Widget step(
            String key, GameIcons icon, String label, VoidCallback? onTap) =>
        Semantics(
          key: ValueKey(key),
          button: true,
          enabled: onTap != null,
          label: label,
          excludeSemantics: true,
          child: Opacity(
            opacity: onTap == null ? 0.35 : 1,
            child: RoundButton(
                icon: icon, label: label, size: 40, onPressed: onTap),
          ),
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: Skin.surface(radius: Radii.lg, depth: 0.8),
      child: Row(children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ROOM SIZE',
                style: t.styles.label
                    .copyWith(color: t.flat ? FlatPalette.label : null)),
            const SizedBox(height: 4),
            ExcludeSemantics(
              child: Wrap(spacing: 4, runSpacing: 4, children: [
                for (var i = 0; i < players; i++)
                  PlayerBadge(index: i, size: 18)
              ]),
            ),
          ]),
        ),
        step('players-', GameIcons.minus, 'Fewer players',
            players > 2 ? () => onPlayers(players - 1) : null),
        Semantics(
          label: 'Room for $players players',
          liveRegion: true,
          excludeSemantics: true,
          child: SizedBox(
            width: 28,
            child: Text('$players',
                key: const ValueKey('playerCount'),
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: Fonts.display,
                    fontSize: 26,
                    color: t.flat ? FlatPalette.ink : Colors.white)),
          ),
        ),
        step('players+', GameIcons.plus, 'More players',
            players < maxPlayers ? () => onPlayers(players + 1) : null),
      ]),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  final GameInfo game;
  final bool fits;
  final bool busy;
  final VoidCallback onCreate;
  const _BottomPanel(
      {required this.game,
      required this.fits,
      required this.busy,
      required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final compact = MediaQuery.sizeOf(context).height <
        700; // small phones: leave room for the games
    final ink = t.flat ? FlatPalette.ink : Colors.white;
    return Container(
      padding:
          EdgeInsets.fromLTRB(16, compact ? 10 : 14, 16, compact ? 12 : 22),
      decoration: Skin.sheet(),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              GameThumb(
                  id: game.id,
                  color: game.color,
                  size: compact ? 40 : 48,
                  radius: 12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(game.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontFamily: Fonts.display,
                              fontSize: 19,
                              color: ink)),
                      Text(
                          fits
                              ? game.tagline
                              : 'Needs ${game.playersLabel} players: you can switch games in the room',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontFamily: Fonts.body,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: fits
                                  ? (t.flat
                                      ? FlatPalette.inkMuted
                                      : NeonPalette.textMuted)
                                  : (t.flat ? FlatPalette.close : Brand.gold))),
                    ]),
              ),
            ]),
            SizedBox(height: compact ? 8 : 14),
            GoldButton(busy ? 'Creating…' : 'Create room',
                icon: GameIcons.plus, onPressed: busy ? null : onCreate),
          ]),
    );
  }
}
