import 'package:flutter/material.dart';
import '../../core/ui/app_ui.dart' show AppBackground;
import '../../core/ui/components.dart';
import '../../games/game_catalog.dart';
import '../local_games/shell/game_art.dart';

/// Category chips plus a grid of game tiles (the hub's [GameTile]). Games outside
/// [playable] (when given) are dimmed and can't be picked; games outside [fits] are
/// dimmed but can still be picked (a hint explains the player count).
class GameGrid extends StatefulWidget {
  final String? selectedId;
  final ValueChanged<GameInfo> onSelect;
  final Set<String>? playable;
  final bool Function(GameInfo g)? fits;
  final Widget? header; // e.g. "24 games fit 4 players"
  const GameGrid(
      {super.key,
      required this.selectedId,
      required this.onSelect,
      this.playable,
      this.fits,
      this.header});
  @override
  State<GameGrid> createState() => _GameGridState();
}

class _GameGridState extends State<GameGrid> {
  GameCategory? filter; // null = all

  static String _label(GameCategory c) =>
      c.label[0] + c.label.substring(1).toLowerCase();

  @override
  Widget build(BuildContext context) {
    final shown = gameCatalog
        .where((g) => filter == null || g.category == filter)
        .toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: 48,
        child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: KitChip('All',
                      selected: filter == null,
                      onTap: () => setState(() => filter = null))),
              for (final c in GameCategory.values)
                Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: KitChip(_label(c),
                        selected: filter == c,
                        onTap: () => setState(() => filter = c))),
            ]),
      ),
      if (widget.header != null)
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
            child: widget.header!),
      Expanded(
        child: GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              mainAxisExtent: 172),
          itemCount: shown.length,
          itemBuilder: (context, i) {
            final g = shown[i];
            final pickable =
                widget.playable == null || widget.playable!.contains(g.id);
            final fits = pickable && (widget.fits?.call(g) ?? true);
            return Opacity(
              opacity: fits ? 1 : 0.45,
              child: IgnorePointer(
                ignoring: !pickable,
                child: GameTile(
                  id: g.id,
                  title: g.name,
                  color: g.color,
                  minPlayers: g.minPlayers,
                  maxPlayers: g.maxPlayers,
                  selected: g.id == widget.selectedId,
                  onTap: () => widget.onSelect(g),
                ),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

/// Full-screen picker used by the room host between games. Pops with the chosen game id.
class GamePickerScreen extends StatelessWidget {
  final String? selectedId;
  final Set<String> playable;
  final int playerCount;
  const GamePickerScreen(
      {super.key,
      required this.selectedId,
      required this.playable,
      required this.playerCount});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: AppBackground(
          child: SafeArea(
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: PageHeader(
                    label: 'Pick the next game',
                    title: '${playable.length} games fit $playerCount players'),
              ),
              Expanded(
                  child: GameGrid(
                      selectedId: selectedId,
                      playable: playable,
                      onSelect: (g) => Navigator.pop(context, g.id))),
            ]),
          ),
        ),
      );
}
