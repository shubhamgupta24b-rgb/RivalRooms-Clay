import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/auth/authentication_manager.dart';
import '../core/text/agreement.dart';
import '../core/records/records.dart';
import '../core/room/room_manager.dart';
import '../core/session/game_session_manager.dart';
import '../core/ui/app_ui.dart';
import '../core/ui/components.dart';
import '../features/local_games/shell/game_art.dart' show GameThumb;
import 'game_catalog.dart';
import 'game_module.dart';

/// Shown by the lobby while the room is playing or finished. Hosts the game screen and the shared results screen.
class GameHostScreen extends StatelessWidget {
  final Room room;
  const GameHostScreen({super.key, required this.room});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<GameSessionManager>();
    final rm = context.read<RoomManager>();
    final myId = context.read<AuthenticationManager>().token.split(':')[1];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await confirmAction(context,
            title: 'Leave game?',
            message:
                'You leave the room. Your friends can carry on without you.',
            confirm: 'Leave',
            cancel: 'Stay',
            emoji: null);
        if (leave) await rm.leave();
      },
      child: Scaffold(
        body: AppBackground(
          child: SafeArea(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _RoomBar(room: room),
                  Expanded(child: _body(context, session, rm, myId)),
                ]),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, GameSessionManager session, RoomManager rm,
      String myId) {
    final result = session.result;
    if (room.status == 'finished' && result != null) {
      return _RecordOnce(
          result: result,
          gameType: room.gameType,
          myId: myId,
          child: _Results(result: result, room: room, myId: myId));
    }
    final screen = gameScreenFor(room.gameType);
    if (screen == null) {
      return Center(
          child: Text('This game is not available in this app version.',
              textAlign: TextAlign.center,
              style: context.tk.styles.bodyStrong
                  .copyWith(color: context.tk.onBgMuted)));
    }
    if (session.state == null)
      return const Center(child: CircularProgressIndicator(color: Brand.gold));
    return screen;
  }
}

/// The game's art and name, a line in its colour, and the party progress.
class _RoomBar extends StatelessWidget {
  final Room room;
  const _RoomBar({required this.room});

  @override
  Widget build(BuildContext context) {
    final game = gameCatalog.firstWhere((g) => g.id == room.gameType,
        orElse: () => GameInfo(room.gameType, room.gameType));
    final party = room.party;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              game.color.withValues(alpha: 0.22),
              game.color.withValues(alpha: 0)
            ]),
        border: Border(
            bottom:
                BorderSide(color: game.color.withValues(alpha: 0.7), width: 2)),
      ),
      child: Row(children: [
        GameThumb(id: game.id, color: game.color, size: 36, radius: 10),
        const SizedBox(width: 10),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(game.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: Fonts.display,
                    fontSize: 20,
                    height: 1.1,
                    color: Colors.white)),
          ),
        ),
        if (party != null)
          EdgeTag('GAME ${party.index + 1}/${party.games.length}',
              color: Brand.gold),
      ]),
    );
  }
}

/// Adds this phone's player's result to My Records once, when the results first show.
class _RecordOnce extends StatefulWidget {
  final Map<String, dynamic> result;
  final String gameType;
  final String myId;
  final Widget child;
  const _RecordOnce(
      {required this.result,
      required this.gameType,
      required this.myId,
      required this.child});
  @override
  State<_RecordOnce> createState() => _RecordOnceState();
}

class _RecordOnceState extends State<_RecordOnce> {
  @override
  void initState() {
    super.initState();
    final mine = (widget.result['ranking'] as List?)
        ?.cast<Map>()
        .where((r) => r['userId'] == widget.myId)
        .firstOrNull;
    if (mine == null) return;
    final winners =
        (widget.result['winners'] as List?)?.cast<String>() ?? const [];
    final ranking = (widget.result['ranking'] as List).cast<Map>();
    // A win is a game you won outright, or together with your team (not an everyone-tied draw).
    final won =
        winners.contains(widget.myId) && winners.length < ranking.length;
    Records.add(widget.gameType,
            score: (mine['score'] as num?)?.toInt() ?? 0, won: won)
        .ignore();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The round's results, in the same style as the one-phone results: trophy, winner line,
/// ranked rows, then (in a party) the standings and the playlist.
class _Results extends StatelessWidget {
  final Map<String, dynamic> result;
  final Room room;
  final String myId;
  const _Results(
      {required this.result, required this.room, required this.myId});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final ranking = (result['ranking'] as List).cast<Map>();
    final winners = (result['winners'] as List).cast<String>();
    final isHost = room.hostId == myId;
    final party = room.party;
    final rm = context.read<RoomManager>();
    int seatOf(String id) =>
        room.players.indexWhere((p) => p.userId == id).clamp(0, 99);
    String name(String id) =>
        room.players.where((p) => p.userId == id).firstOrNull?.username ?? '?';
    Color ink(String id) => nameColor(PlayerPalette.color(seatOf(id)));

    Future<void> run(Future<String?> f) async {
      final messenger = ScaffoldMessenger.of(context);
      final err = await f;
      if (err != null) messenger.showSnackBar(SnackBar(content: Text(err)));
    }

    final partyOrder = party == null
        ? <String>[]
        : (party.totals.keys.toList()
          ..sort((a, b) => party.totals[b]!.compareTo(party.totals[a]!)));
    final partyDone = party?.done == true;
    final draw =
        !partyDone && winners.length > 1 && winners.length == ranking.length;
    final iWon = !draw && winners.contains(myId);

    final InlineSpan title;
    if (partyDone) {
      title = TextSpan(children: [
        TextSpan(
            text: name(partyOrder.first),
            style: TextStyle(color: ink(partyOrder.first))),
        TextSpan(
            text:
                ' ${winsWord(name(partyOrder.first))} the party!'),
      ]);
    } else if (draw) {
      title = const TextSpan(text: "It's a draw!");
    } else if (iWon) {
      title =
          const TextSpan(text: 'You win!', style: TextStyle(color: Brand.gold));
    } else {
      title = TextSpan(children: [
        for (var k = 0; k < winners.length; k++) ...[
          if (k > 0) const TextSpan(text: ' & '),
          TextSpan(
              text: name(winners[k]), style: TextStyle(color: ink(winners[k]))),
        ],
        TextSpan(
            text: winners.length > 1 ||
                    (winners.length == 1 && isYou(name(winners.first)))
                ? ' win!'
                : ' wins!'),
      ]);
    }
    final subtitle = party == null
        ? 'Round results'
        : (partyDone
            ? 'Party over · ${party.games.length} games played'
            : 'Game ${party.index + 1} of ${party.games.length}');

    final List<Widget> actions;
    if (!isHost) {
      actions = [
        Text(
            party != null && !party.done
                ? 'Next up: ${gameName(party.nextGame ?? '')}. Waiting for the host…'
                : 'Waiting for the host to pick the next game…',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: Fonts.body,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: t.onBgMuted)),
      ];
    } else if (party != null && !party.done) {
      actions = [
        GoldButton(
            'Next game (${party.index + 2}/${party.games.length}): ${gameName(party.nextGame!)}',
            icon: GameIcons.play,
            fontSize: 19,
            onPressed: () => run(rm.nextGame())),
        const SizedBox(height: 10),
        KitButton('End party',
            style: KitButtonStyle.outline,
            onPressed: () => run(rm.returnToLobby())),
      ];
    } else {
      actions = [
        if (party == null) ...[
          GoldButton('Play again',
              icon: GameIcons.restart, onPressed: () => run(rm.nextGame())),
          const SizedBox(height: 10),
          KitButton('Choose another game',
              style: KitButtonStyle.ghost,
              onPressed: () => run(rm.returnToLobby())),
        ] else
          GoldButton('Back to the room',
              icon: GameIcons.home, onPressed: () => run(rm.returnToLobby())),
      ];
    }

    return Stack(children: [
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                  children: [
                    Center(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.4, end: 1),
                        duration: const Duration(milliseconds: 650),
                        curve: Curves.elasticOut,
                        builder: (context, s, child) => Transform.scale(
                            scale: Motion.reduced(context) ? 1 : s,
                            child: child),
                        child: GameIcon(GameIcons.trophy,
                            size: 52,
                            color: draw ? NeonPalette.label : Brand.gold),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Semantics(
                      header: true,
                      liveRegion: true,
                      child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text.rich(title,
                              textAlign: TextAlign.center,
                              style:
                                  t.styles.h1.copyWith(color: Colors.white))),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontFamily: Fonts.body,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: NeonPalette.textMuted)),
                    const SizedBox(height: 16),
                    for (final r in ranking) ...[
                      _RankRow(
                        rank: (r['rank'] as num).toInt(),
                        seat: seatOf(r['userId'] as String),
                        name: '${r['username']}',
                        you: r['userId'] == myId,
                        score: '${r['score']}',
                        winner: !draw && winners.contains(r['userId']),
                        points: party?.lastPoints == null
                            ? null
                            : party!.lastPoints![r['userId']] ?? 0,
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (party != null) ...[
                      const SizedBox(height: 10),
                      SectionHeader(
                          'Party standings · game ${party.index + 1} of ${party.games.length}'),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration:
                            Skin.surface(radius: Radii.button, depth: 0.8),
                        child: Column(children: [
                          for (var i = 0; i < partyOrder.length; i++)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(children: [
                                SizedBox(
                                    width: 22,
                                    child: Text('${i + 1}',
                                        style: TextStyle(
                                            fontFamily: Fonts.display,
                                            fontSize: 16,
                                            color: i == 0
                                                ? Brand.gold
                                                : NeonPalette.textMuted))),
                                PlayerBadge(
                                    index: seatOf(partyOrder[i]), size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                      '${name(partyOrder[i])}${partyOrder[i] == myId ? ' (you)' : ''}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontFamily: Fonts.body,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                          color: kIdleInk)),
                                ),
                                Text('${party.totals[partyOrder[i]]} pts',
                                    style: const TextStyle(
                                        fontFamily: Fonts.display,
                                        fontSize: 18,
                                        color: Brand.gold,
                                        fontFeatures: [
                                          FontFeature.tabularFigures()
                                        ])),
                              ]),
                            ),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        for (var i = 0; i < party.games.length; i++)
                          _PlaylistChip(
                              id: party.games[i],
                              state: i < party.index
                                  ? -1
                                  : (i == party.index ? 0 : 1)),
                      ]),
                    ],
                  ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...actions,
                    const SizedBox(height: 2),
                    Center(
                      child: TextButton(
                        onPressed: rm.leave,
                        style: TextButton.styleFrom(
                            minimumSize: const Size(kTouchTarget, kTouchTarget),
                            foregroundColor: t.onBgMuted),
                        child: Text('Leave room',
                            style: TextStyle(
                                fontFamily: Fonts.body,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: t.onBgMuted)),
                      ),
                    ),
                  ]),
            ),
          ]),
        ),
      ),
      if (iWon || partyDone) const Positioned.fill(child: ConfettiBurst()),
    ]);
  }
}

/// One ranked player: medal, badge in their seat colour, name, score and party points.
class _RankRow extends StatelessWidget {
  final int rank, seat;
  final String name, score;
  final bool you, winner;
  final int? points;
  const _RankRow(
      {required this.rank,
      required this.seat,
      required this.name,
      required this.you,
      required this.score,
      required this.winner,
      this.points});

  @override
  Widget build(BuildContext context) {
    final c = PlayerPalette.color(seat);
    final ink = winner ? Colors.white : kIdleInk;
    final medal = switch (rank) {
      1 => Brand.gold,
      2 => const Color(0xFFC7CEDB),
      3 => const Color(0xFFD08A4E),
      _ => Colors.white.withValues(alpha: 0.18)
    };
    return Semantics(
      label:
          'Place $rank, $name${you ? ', you' : ''}, $score${points != null ? ', plus $points points' : ''}',
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
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: medal),
              child: Text('$rank',
                  style: TextStyle(
                      fontFamily: Fonts.display,
                      fontSize: 15,
                      height: 1,
                      color:
                          rank <= 3 ? const Color(0xFF2A1A00) : Colors.white)),
            ),
            const SizedBox(width: 10),
            PlayerBadge(index: seat, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: name),
                  if (you)
                    TextSpan(
                        text: '  YOU',
                        style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1,
                            color: PlayerPalette.tintFor(c))),
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontFamily: Fonts.body,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: ink),
              ),
            ),
            if (points != null) ...[
              EdgeTag('+$points', color: Brand.gold, score: true),
              const SizedBox(width: 10)
            ],
            Text(score,
                style: TextStyle(
                    fontFamily: Fonts.display,
                    fontSize: 26,
                    height: 1,
                    color: ink,
                    fontFeatures: const [FontFeature.tabularFigures()])),
          ]),
        ),
      ),
    );
  }
}

/// A game in the party playlist: done (dimmed, ticked), now (gold) or coming up.
class _PlaylistChip extends StatelessWidget {
  final String id;
  final int state; // -1 done, 0 now, 1 next
  const _PlaylistChip({required this.id, required this.state});

  @override
  Widget build(BuildContext context) {
    final game = gameCatalog.firstWhere((g) => g.id == id,
        orElse: () => GameInfo(id, id));
    final now = state == 0;
    return Semantics(
      label: '${game.name}, ${switch (state) {
        -1 => 'played',
        0 => 'this game',
        _ => 'coming up'
      }}',
      excludeSemantics: true,
      child: Opacity(
        opacity: state < 0 ? 0.55 : 1,
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
          decoration: Skin.surface(
              radius: 14,
              ring: now ? Brand.gold : null,
              tint: now ? Brand.gold : null,
              depth: 0.5),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            GameThumb(id: game.id, color: game.color, size: 22, radius: 7),
            const SizedBox(width: 6),
            Text(game.name,
                style: TextStyle(
                    fontFamily: Fonts.body,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: now ? const Color(0xFFFFE08A) : Colors.white)),
            if (state < 0) ...[
              const SizedBox(width: 4),
              const GameIcon(GameIcons.check,
                  size: 12, color: StatusColors.success)
            ],
          ]),
        ),
      ),
    );
  }
}
