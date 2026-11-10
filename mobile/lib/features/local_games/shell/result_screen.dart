import 'package:flutter/material.dart';
import '../../../core/ads/ad_mob_service.dart';
import '../../../core/text/agreement.dart';
import '../../../core/ui/components.dart';
import '../../guess_person/models/gp_player.dart';
import 'game_art.dart';
import 'local_game_info.dart';

/// Extra results a game can hand the shell before it finishes (spec 2.10): the real score
/// line, a hero illustration and a detail per player row. Only stats the game tracks.
/// Games reach it with `ResultScope.of(context)` and fill it in as they play.
class ResultExtras {
  /// Under the winner line, e.g. "46 – 40 · 5 arrows each".
  String? subtitle;

  /// Replaces the drawn trophy, e.g. a fan of cards or a podium of karts.
  WidgetBuilder? hero;

  /// The middle of a player's row: per-round boxes, collected items, a bar.
  Widget Function(BuildContext context, int seat)? detail;

  /// The small caps after the game name in the top bar ("RESULTS", "BOARD CLEAR").
  String? label;
}

class ResultScope extends InheritedWidget {
  final ResultExtras extras;
  const ResultScope({super.key, required this.extras, required super.child});
  static ResultExtras? of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ResultScope>()?.extras;
  @override
  bool updateShouldNotify(ResultScope old) => !identical(old.extras, extras);
}

/// The end of a match (spec 2.10, mockups */Results.dc.html): winner line, hero, ranked
/// rows, then Rematch, Change players and All games. Solo games show the score, NEW BEST
/// and the best so far instead.
class ResultScreen extends StatelessWidget {
  final LocalGameInfo game;
  final List<GpPlayer> players;
  final List<int> wins;
  final bool teams;
  final ResultExtras? extras;
  final int? best; // solo
  final bool newBest; // solo
  final VoidCallback onRematch;
  final VoidCallback? onChangePlayers;
  final VoidCallback onExit;
  const ResultScreen(
      {super.key,
      required this.game,
      required this.players,
      this.wins = const [],
      this.teams = false,
      this.extras,
      this.best,
      this.newBest = false,
      required this.onRematch,
      this.onChangePlayers,
      required this.onExit});

  @override
  Widget build(BuildContext context) {
    return TokenScope(
      flat: false,
      child: Builder(
          builder: (context) => game.solo ? _solo(context) : _match(context)),
    );
  }

  Widget _topBar(BuildContext context, String label) => Row(children: [
        RoundButton(icon: GameIcons.close, label: 'Close', onPressed: onExit),
        Expanded(
          child: Text('${game.title} · $label'.toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.tk.styles.label),
        ),
        const SizedBox(width: kTouchTarget),
      ]);

  Widget _frame(BuildContext context,
      {required String label,
      required List<Widget> body,
      required List<Widget> buttons,
      bool confetti = false}) {
    return Stack(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(children: [
              _topBar(context, label),
              const SizedBox(height: 14),
              Expanded(
                  child: SingleChildScrollView(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: body))),
              const SizedBox(height: 14),
              ...buttons,
            ]),
          ),
        ),
      ),
      if (confetti) const Positioned.fill(child: ConfettiBurst()),
    ]);
  }

  Widget _trophy({bool dim = false}) => Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.4, end: 1),
          duration: const Duration(milliseconds: 650),
          curve: Curves.elasticOut,
          builder: (context, s, child) => Transform.scale(
              scale: Motion.reduced(context) ? 1 : s, child: child),
          child: GameIcon(GameIcons.trophy,
              size: 52, color: dim ? NeonPalette.label : Brand.gold),
        ),
      );

  Widget _match(BuildContext context) {
    final t = context.tk;
    final top = players.map((p) => p.score).reduce((a, b) => a > b ? a : b);
    final leaders = [
      for (var i = 0; i < players.length; i++)
        if (players[i].score == top) i
    ];
    final teamWin = teams && leaders.length == 2;
    final draw = leaders.length > 1 && !teamWin;
    // Standard competition ranking (1, 2, 2, 4), best first.
    final order = [for (var i = 0; i < players.length; i++) i]
      ..sort((a, b) => players[b].score.compareTo(players[a].score));
    int rankOf(int i) =>
        1 + players.where((p) => p.score > players[i].score).length;
    final scoresLine = order.length <= 3
        ? '${[
            for (final i in order) players[i].score
          ].join(' – ')} · ${game.scoreUnit}'
        : '${players.length} players · ${game.scoreUnit}';
    final titleStyle = t.styles.h1;
    final InlineSpan title = draw
        ? const TextSpan(text: "It's a draw!")
        : TextSpan(children: [
            for (var k = 0; k < (teamWin ? 2 : 1); k++) ...[
              if (k > 0) const TextSpan(text: ' & '),
              TextSpan(
                  text: players[leaders[k]].name,
                  style:
                      TextStyle(color: nameColor(players[leaders[k]].color))),
            ],
            TextSpan(
                text: teamWin ||
                        leaders.length == 1 && isYou(players[leaders[0]].name)
                    ? ' win!'
                    : ' wins!'),
          ]);
    final hero = extras?.hero;
    return _frame(
      context,
      label: extras?.label ?? 'Results',
      confetti: !draw,
      body: [
        if (hero != null) ...[
          hero(context),
          const SizedBox(height: 14)
        ] else ...[
          _trophy(dim: draw),
          const SizedBox(height: 4)
        ],
        Semantics(
          header: true,
          liveRegion: true,
          child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text.rich(title,
                  textAlign: TextAlign.center, style: titleStyle)),
        ),
        const SizedBox(height: 4),
        Text(extras?.subtitle ?? scoresLine,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: Fonts.body,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: NeonPalette.textMuted,
                fontFeatures: [FontFeature.tabularFigures()])),
        const SizedBox(height: 14),
        for (final i in order) ...[
          _Row(
            seat: i,
            player: players[i],
            rank: rankOf(i),
            winner: !draw && leaders.contains(i),
            wins: i < wins.length ? wins[i] : 0,
            detail: extras?.detail?.call(context, i),
          ),
          const SizedBox(height: 8),
        ],
      ],
      buttons: [
        GoldButton(
          'Rematch',
          icon: GameIcons.restart,
          onPressed: () async {
            await AdMobService.instance.showInterstitialAtMatchBreak();
            onRematch();
          },
        ),
        const SizedBox(height: 10),
        Row(children: [
          if (onChangePlayers != null) ...[
            Expanded(
                child: KitButton('Change players',
                    style: KitButtonStyle.outline, onPressed: onChangePlayers)),
            const SizedBox(width: 10),
          ],
          Expanded(
              child: KitButton('All games',
                  style: KitButtonStyle.ghost, onPressed: onExit)),
        ]),
      ],
    );
  }

  Widget _solo(BuildContext context) {
    final t = context.tk;
    final score = players.single.score;
    final hero = extras?.hero;
    return _frame(
      context,
      label: extras?.label ?? 'Game over',
      confetti: newBest,
      body: [
        if (hero != null)
          hero(context)
        else if (newBest)
          _trophy()
        else
          Center(
              child: GameIcon(gameIconFor(game.id),
                  size: 52, color: nameColor(game.color))),
        const SizedBox(height: 4),
        Semantics(
            header: true,
            child: Text(newBest ? 'New best!' : 'Game over',
                textAlign: TextAlign.center,
                style: t.styles.h1
                    .copyWith(color: newBest ? Brand.gold : Colors.white))),
        if (extras?.subtitle != null) ...[
          const SizedBox(height: 4),
          Text(extras!.subtitle!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: Fonts.body,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: NeonPalette.textMuted)),
        ],
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          decoration: Skin.surface(
              radius: 22,
              tint: newBest ? Brand.gold : null,
              ring: newBest ? Brand.gold : null),
          child: Column(children: [
            Text(game.scoreUnit.toUpperCase(), style: t.styles.label),
            const SizedBox(height: 6),
            _CountUp(
                value: score,
                style: t.styles.scoreLarge
                    .copyWith(color: newBest ? Brand.gold : Colors.white)),
            const SizedBox(height: 10),
            if (newBest)
              const EdgeTag('NEW BEST', color: Brand.gold)
            else if (best != null)
              Text('Best so far: $best',
                  style: const TextStyle(
                      fontFamily: Fonts.body,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: NeonPalette.textMuted,
                      fontFeatures: [FontFeature.tabularFigures()])),
          ]),
        ),
      ],
      buttons: [
        GoldButton('Play again', icon: GameIcons.restart, onPressed: onRematch),
        const SizedBox(height: 10),
        KitButton('All games', style: KitButtonStyle.ghost, onPressed: onExit),
      ],
    );
  }
}

/// One ranked row: rank (gold for 1st), badge, name, the game's detail, matches won, total.
class _Row extends StatelessWidget {
  final int seat;
  final GpPlayer player;
  final int rank;
  final bool winner;
  final int wins;
  final Widget? detail;
  const _Row(
      {required this.seat,
      required this.player,
      required this.rank,
      required this.winner,
      required this.wins,
      this.detail});

  @override
  Widget build(BuildContext context) {
    final c = player.color;
    final ink = winner ? Colors.white : kIdleInk;
    final shape = PlayerPalette.indexOf(c) ?? seat;
    return Semantics(
      label:
          'Place $rank, ${player.name}, ${player.score}${wins > 0 ? ', $wins ${wins == 1 ? 'match' : 'matches'} won' : ''}',
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: Motion.reduced(context) ? 1 : 0, end: 1),
        duration: Motion.of(context, Duration(milliseconds: 260 + 90 * rank)),
        curve: Motion.emphasized,
        builder: (_, v, child) => Opacity(
            opacity: v,
            child: Transform.translate(
                offset: Offset(0, (1 - v) * 16), child: child)),
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: Skin.surface(
              radius: Radii.button,
              tint: winner ? c : null,
              ring: winner ? nameColor(c) : null,
              depth: winner ? 1 : 0.7),
          child: Row(children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: rank == 1
                      ? Brand.gold
                      : Colors.white.withValues(alpha: 0.18)),
              child: Text('$rank',
                  style: TextStyle(
                      fontFamily: Fonts.display,
                      fontSize: 14,
                      height: 1,
                      color:
                          rank == 1 ? const Color(0xFF2A1A00) : Colors.white)),
            ),
            const SizedBox(width: 10),
            PlayerBadge(index: shape, size: 16, color: c),
            const SizedBox(width: 8),
            if (detail != null) ...[
              SizedBox(
                  width: 66,
                  child: Text(player.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: Fonts.body,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: ink))),
              const SizedBox(width: 6),
              Expanded(child: detail!),
            ] else
              Expanded(
                  child: Text(player.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: Fonts.body,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: ink))),
            if (wins > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const GameIcon(GameIcons.crown, size: 12, color: Brand.gold),
                  const SizedBox(width: 3),
                  Text('$wins',
                      style: const TextStyle(
                          fontFamily: Fonts.body,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: kIdleInk)),
                ]),
              ),
            ],
            const SizedBox(width: 8),
            SizedBox(
              width: 44,
              child: Text('${player.score}',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontFamily: Fonts.display,
                      fontSize: 26,
                      height: 1,
                      color: ink,
                      fontFeatures: const [FontFeature.tabularFigures()])),
            ),
          ]),
        ),
      ),
    );
  }
}

/// A number that counts up to [value] (instantly with reduce motion).
class _CountUp extends StatelessWidget {
  final int value;
  final TextStyle style;
  const _CountUp({required this.value, required this.style});
  @override
  Widget build(BuildContext context) => Semantics(
        label: '$value',
        excludeSemantics: true,
        child: TweenAnimationBuilder<double>(
          tween: Tween(
              begin: Motion.reduced(context) ? value.toDouble() : 0,
              end: value.toDouble()),
          duration: Motion.of(context, const Duration(milliseconds: 700)),
          curve: Motion.standard,
          builder: (_, v, __) =>
              Text('${v.round()}', textAlign: TextAlign.center, style: style),
        ),
      );
}
