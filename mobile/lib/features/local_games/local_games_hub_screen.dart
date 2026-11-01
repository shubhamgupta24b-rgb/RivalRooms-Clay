import 'package:flutter/material.dart';

import '../../core/records/records.dart';
import '../../core/ui/components.dart';
import '../../games/game_catalog.dart';
import '../guess_person/screens/guess_person_menu_screen.dart';
import '../../core/ui/app_ui.dart' show AppBackground;
import '../raja_mantri/rmcs_screen.dart';
import 'archery/archery_game.dart';
import 'basketball/basketball_game.dart';
import 'bottle_smash/bottle_smash_game.dart';
import 'mini_golf/mini_golf_game.dart';
import 'shooting_gallery/shooting_gallery_game.dart';
import 'slingshot/slingshot_game.dart';
import 'memory/memory_game.dart';
import 'paint_fight/paint_fight_game.dart';
import 'air_hockey/air_hockey_game.dart';
import 'connect_four/connect_four_game.dart';
import 'math_duel/math_duel_game.dart';
import 'ping_pong/ping_pong_game.dart';
import 'reaction_tap/reaction_tap_game.dart';
import 'tic_tac_toe/tic_tac_toe_game.dart';
import 'colour_clash/colour_clash_game.dart';
import 'battleship/battleship_game.dart';
import 'bingo/bingo_game.dart';
import 'checkers/checkers_game.dart';
import 'chess/chess_game.dart';
import 'tug_of_war/tug_of_war_game.dart';
import 'darts/darts_game.dart';
import 'hot_potato/hot_potato_game.dart';
import 'knife_hit/knife_hit_game.dart';
import 'cup_pong/cup_pong_game.dart';
import 'hungry_hippos/hungry_hippos_game.dart';
import 'penguin_push/penguin_push_game.dart';
import 'dots_boxes/dots_boxes_game.dart';
import 'fruit_merge/fruit_merge_game.dart';
import 'ludo/ludo_game.dart';
import 'snakes_ladders/snakes_ladders_game.dart';
import 'truth_dare/truth_dare_game.dart';
import 'charades/charades_game.dart';
import 'draw_guess/draw_guess_game.dart';
import 'find_spy/find_spy_game.dart';
import 'hand_cricket/hand_cricket_game.dart';
import 'heads_up/heads_up_game.dart';
import 'mafia/mafia_game.dart';
import 'most_likely/most_likely_game.dart';
import 'quiz_battle/quiz_battle_game.dart';
import 'undercover/undercover_game.dart';
import 'would_rather/would_rather_game.dart';
import 'rps/rps_game.dart';
import 'ring_sort/ring_sort_game.dart';
import 'bike/bike_game.dart';
import 'nitro_knockout/nitro_knockout_game.dart';
import 'candy/candy_game.dart';
import 'carrom/carrom_game.dart';
import 'chicken_jump/chicken_jump_game.dart';
import 'eight_ball/eight_ball_game.dart';
import 'fruit_cut/fruit_cut_game.dart';
import 'solo/ball_sort.dart';
import 'solo/block_drop.dart';
import 'solo/bubble_shooter.dart';
import 'solo/color_switch.dart';
import 'solo/sky_jumper.dart';
import 'solo/space_shooter.dart';
import 'solo/brick_breaker.dart';
import 'solo/dino_run.dart';
import 'solo/hangman.dart';
import 'solo/sliding_puzzle.dart';
import 'solo/sudoku.dart';
import 'solo/flappy_jump.dart';
import 'solo/game_2048.dart';
import 'solo/minesweeper.dart';
import 'solo/piano_tiles.dart';
import 'solo/simon_says.dart';
import 'solo/stack_tower.dart';
import 'solo/whack_mole.dart';
import 'solo/word_scramble.dart';
import 'shell/local_game_info.dart';
import 'shell/game_art.dart';
import 'shell/local_game_shell.dart';

final localGames = <LocalGameInfo>[
  colourClashInfo, findSpyInfo, ludoInfo, mafiaInfo, undercoverInfo,
  charadesInfo, snakesLaddersInfo,
  drawGuessInfo, headsUpInfo, quizBattleInfo, handCricketInfo, basketballInfo,
  memoryInfo, paintFightInfo,
  ticTacToeInfo, airHockeyInfo, pingPongInfo, reactionTapInfo, mathDuelInfo,
  connectFourInfo, dotsBoxesInfo,
  mostLikelyInfo, wouldRatherInfo, truthDareInfo, rpsInfo, fruitBattleInfo,
  bingoInfo, battleshipInfo, checkersInfo,
  golfInfo,
  slingInfo,
  archeryInfo,
  galleryInfo,
  bottleInfo,
  chessInfo,
  tugOfWarInfo,
  dartsInfo,
  hotPotatoInfo,
  knifeHitInfo,
  cupPongInfo,
  hungryHipposInfo,
  penguinPushInfo,
  ringSortInfo,
  // Solo games (shown in their own section).
  fruitMergeInfo, game2048Info, flappyInfo, minesweeperInfo, brickBreakerInfo,
  whackInfo, pianoInfo, wordScrambleInfo, stackInfo, simonInfo,
  fruitCutInfo, chickenJumpInfo, carromInfo, eightBallInfo, candyCrushInfo,
  bikeRaceInfo, nitroKartsInfo,
  ballSortInfo, slidingInfo, sudokuInfo, hangmanInfo, dinoInfo,
  blockDropInfo, bubbleInfo, skyInfo, spaceInfo, colorSwitchInfo
];

/// The hub's games plus their team versions (e.g. Ludo 2 vs 2), for online rooms.
List<LocalGameInfo> get allLocalGames => [
      ...localGames,
      for (final g in localGames)
        if (g.teamVariant != null) g.teamVariant!
    ];

/// Everything in the hub: the shell games plus Guess the Person and Raja Mantri.
int get totalGameCount => localGames.where((g) => !g.remoteOnly).length + 2;

/// A game in the list: one of the shell games, or Guess the Person / Raja Mantri.
class _Entry {
  final String id, title, tagline;
  final int minPlayers, maxPlayers;
  final Color color;
  final GameCategory category;
  final WidgetBuilder open;
  const _Entry({
    required this.id,
    required this.title,
    required this.tagline,
    required this.minPlayers,
    required this.maxPlayers,
    required this.color,
    required this.category,
    required this.open,
  });
  bool get solo => maxPlayers <= 1;
}

List<_Entry> _entries() {
  GameCategory categoryOf(String id) =>
      gameCatalog.where((g) => g.id == id).firstOrNull?.category ??
      GameCategory.party;
  return [
    _Entry(
      id: 'guess_person',
      title: 'Guess the Person',
      tagline: 'Ask questions, find the secret person',
      minPlayers: 2,
      maxPlayers: 6,
      color: const Color(0xFFFFC93C),
      category: GameCategory.party,
      open: (_) => const GuessPersonMenuScreen(),
    ),
    _Entry(
      id: 'raja_mantri',
      title: 'Raja Mantri Chor Sipahi',
      tagline: 'Can the Mantri catch the Chor?',
      minPlayers: 4,
      maxPlayers: 4,
      color: const Color(0xFF8A1C3A),
      category: GameCategory.cards,
      open: (_) => const RmcsMenuScreen(),
    ),
    for (final g in localGames.where((g) => !g.remoteOnly))
      _Entry(
        id: g.id,
        title: g.title,
        tagline: g.tagline,
        minPlayers: g.solo ? 1 : g.minPlayers,
        maxPlayers: g.maxPlayers,
        color: g.color,
        category: categoryOf(g.id),
        open: (_) => LocalGameShell(game: g),
      ),
  ];
}

enum _Filter { all, party, board, cards, action, solo, favourites }

const _filterLabels = {
  _Filter.all: 'All',
  _Filter.party: 'Party',
  _Filter.board: 'Board',
  _Filter.cards: 'Cards',
  _Filter.action: 'Action',
  _Filter.solo: 'Solo',
  _Filter.favourites: 'Favourites',
};

/// Player-count filter: null = any; 5 means 5-6.
const _counts = <int?>[null, 2, 3, 4, 5];

/// Every game that runs on one device (spec 4.4, mockup app/Hub.dc.html): search, category
/// tabs, a player-count filter, recently played and favourites (the star, or long-press).
class LocalGamesHubScreen extends StatefulWidget {
  const LocalGamesHubScreen({super.key});
  @override
  State<LocalGamesHubScreen> createState() => _LocalGamesHubScreenState();
}

class _LocalGamesHubScreenState extends State<LocalGamesHubScreen> {
  final _entriesList = _entries();
  final _search = TextEditingController();
  var filter = _Filter.all;
  int? players; // null: any
  Set<String> favourites = {};
  List<String> recent = const [];

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _load();
  }

  Future<void> _load() async {
    final f = await Records.favourites(), r = await Records.recent();
    if (mounted) {
      setState(() {
        favourites = f;
        recent = r;
      });
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _open(_Entry e) async {
    await Navigator.push(context, MaterialPageRoute(builder: e.open));
    _load(); // a game may have just been played
  }

  Future<void> _toggleFavourite(_Entry e) async {
    haptic(HapticWeight.medium);
    final f = await Records.toggleFavourite(e.id);
    if (!mounted) return;
    setState(() => favourites = f);
    showToast(
        context,
        f.contains(e.id)
            ? '${e.title} added to favourites'
            : '${e.title} removed from favourites',
        tone: Tone.info,
        duration: const Duration(milliseconds: 1400));
  }

  bool _matches(_Entry e) {
    final q = _search.text.trim().toLowerCase();
    if (q.isNotEmpty &&
        !e.title.toLowerCase().contains(q) &&
        !e.tagline.toLowerCase().contains(q)) return false;
    if (players case final n?) {
      if (e.solo) return false;
      if (n >= 5 ? e.maxPlayers < 5 : (n < e.minPlayers || n > e.maxPlayers))
        return false;
    }
    return switch (filter) {
      _Filter.all => true,
      _Filter.favourites => favourites.contains(e.id),
      _Filter.solo => e.solo,
      _Filter.cards => !e.solo && e.category == GameCategory.cards,
      _Filter.board => !e.solo && e.category == GameCategory.board,
      _Filter.action => !e.solo && e.category == GameCategory.action,
      _Filter.party => !e.solo && e.category == GameCategory.party,
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final shown = _entriesList.where(_matches).toList();
    final together = shown.where((e) => !e.solo).toList(),
        solo = shown.where((e) => e.solo).toList();
    final query = _search.text.trim();
    final browsing = filter == _Filter.all && query.isEmpty && players == null;
    final recentEntries = [
      for (final id in recent) ..._entriesList.where((e) => e.id == id)
    ];
    const gutter = EdgeInsets.symmetric(horizontal: 16);

    Widget section(String text) => SliverToBoxAdapter(
        child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: SectionHeader(text)));
    Widget grid(List<_Entry> items) => SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 230,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                mainAxisExtent: 196),
            delegate: SliverChildBuilderDelegate(
              (_, i) {
                final e = items[i];
                return GameTile(
                  id: e.id,
                  title: e.title,
                  color: e.color,
                  minPlayers: e.minPlayers,
                  maxPlayers: e.maxPlayers,
                  favourite: favourites.contains(e.id),
                  onTap: () => _open(e),
                  onStar: () => _toggleFavourite(e),
                );
              },
              childCount: items.length,
            ),
          ),
        );

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: PageHeader(
                  label: 'Play on one phone',
                  title: '$totalGameCount games',
                  trailing: RoundButton(
                      icon: GameIcons.settings,
                      label: 'Settings',
                      onPressed: () => showSettingsSheet(context)),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: gutter,
                child: KitField(
                  controller: _search,
                  hint: 'Search games',
                  icon: GameIcons.search,
                  suffix: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear',
                          onPressed: _search.clear,
                          icon: GameIcon(GameIcons.close,
                              size: 16, color: t.onBgMuted)),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                child: Row(children: [
                  for (final f in _Filter.values)
                    Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: KitChip(_filterLabels[f]!,
                            selected: filter == f,
                            onTap: () => setState(() => filter = f))),
                ]),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: gutter,
                child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text('PLAYERS',
                              style: t.styles.label
                                  .copyWith(fontWeight: FontWeight.w900))),
                      for (final n in _counts)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: KitChip(
                              n == null ? 'Any' : (n >= 5 ? '5–6' : '$n'),
                              outline: true,
                              selected: players == n,
                              onTap: () => setState(() => players = n)),
                        ),
                    ]),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            if (browsing && recentEntries.isNotEmpty) ...[
              section('Recently played'),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 68,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: recentEntries.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) => _RecentTile(
                        entry: recentEntries[i],
                        onTap: () => _open(recentEntries[i])),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
            if (shown.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(children: [
                    GameIcon(
                        filter == _Filter.favourites
                            ? GameIcons.star
                            : GameIcons.search,
                        size: 44,
                        color: t.onBgMuted),
                    const SizedBox(height: 10),
                    Text(
                      filter == _Filter.favourites && query.isEmpty
                          ? 'No favourites yet. Tap the star on any game to add it here.'
                          : 'No games match "$query".',
                      textAlign: TextAlign.center,
                      style: t.styles.body.copyWith(color: t.onBgMuted),
                    ),
                    if (query.isNotEmpty || players != null) ...[
                      const SizedBox(height: 12),
                      KitButton('Clear search', style: KitButtonStyle.outline,
                          onPressed: () {
                        _search.clear();
                        setState(() => players = null);
                      }),
                    ],
                  ]),
                ),
              ),
            if (browsing) ...[
              if (together.isNotEmpty) ...[
                section('Play together'),
                grid(together)
              ],
              if (solo.isNotEmpty) ...[section('Solo games'), grid(solo)],
            ] else
              grid(shown),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ]),
        ),
      ),
    );
  }
}

/// A recently played game: its art, name and "Play again".
class _RecentTile extends StatelessWidget {
  final _Entry entry;
  final VoidCallback onTap;
  const _RecentTile({required this.entry, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Semantics(
      button: true,
      label: 'Play ${entry.title} again',
      excludeSemantics: true,
      child: Material(
        color: t.flat ? Colors.white : Colors.white.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
            borderRadius: Radii.rLg,
            side: BorderSide(
                color: t.flat
                    ? FlatPalette.stroke
                    : Colors.white.withValues(alpha: 0.12))),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 196,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(children: [
                GameThumb(
                    id: entry.id, color: entry.color, size: 52, radius: 12),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontFamily: Fonts.display,
                                fontSize: 15,
                                color:
                                    t.flat ? FlatPalette.ink : Colors.white)),
                        const SizedBox(height: 2),
                        Row(children: [
                          GameIcon(GameIcons.play,
                              size: 12,
                              color: t.flat ? FlatPalette.ink : Brand.gold),
                          const SizedBox(width: 4),
                          Flexible(
                              child: Text('Play again',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontFamily: Fonts.body,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: t.flat
                                          ? FlatPalette.ink
                                          : Brand.gold))),
                        ]),
                      ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
