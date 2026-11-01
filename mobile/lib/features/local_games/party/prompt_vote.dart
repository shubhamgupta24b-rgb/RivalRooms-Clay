import 'dart:math';
import 'package:flutter/material.dart';
import '../../guess_person/models/gp_player.dart';
import '../../../core/ui/components.dart';
import '../shell/game_hud.dart' show MomentWatcher, keyMoment;
import '../shell/local_game_shell.dart' show ResultScope;
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import 'party_widgets.dart';

// Option colours (the options are also lettered A/B, so colour isn't the only clue).
const _optionA = Color(0xFF2F6FE0);
const _optionB = Color(0xFFE5484D);

enum VoteMode { mostLikely, wouldRather }

enum PromptPhase { vote, reveal, done }

/// Secret-vote party prompts.
/// Most Likely To: everyone votes for a player; the most-voted get a 👑 point.
/// Would You Rather: everyone picks A or B; everyone on the bigger side scores.
class PromptVoteLogic extends LocalGameLogic {
  final VoteMode mode;
  final int players;
  final int rounds;
  final List<String> prompts; // Would You Rather: "A|B"
  PromptPhase phase = PromptPhase.vote;
  int round = 0;
  late final List<int?> votes = List.filled(players, null);
  late final List<int> score = List.filled(players, 0);
  List<int> lastWinners =
      []; // players (most likely) or options (would rather) that won the round

  PromptVoteLogic(
      {required this.mode,
      required this.players,
      required List<String> prompts,
      this.rounds = 8,
      Random? random})
      : prompts =
            ([...prompts]..shuffle(random ?? Random())).take(rounds).toList();

  String get prompt => prompts[round % prompts.length];
  int get votesIn => votes.where((v) => v != null).length;
  int get voteTurn =>
      [
        for (var i = 0; i < players; i++)
          if (votes[i] == null) i
      ].firstOrNull ??
      0;
  List<int> tally(int options) =>
      [for (var o = 0; o < options; o++) votes.where((v) => v == o).length];

  @override
  bool get finished => phase == PromptPhase.done;
  @override
  List<int> get scores => score;
  @override
  void update(int elapsedMs) {}

  void vote(int voter, int choice) {
    if (forward('vote', [voter, choice])) return;
    if (phase != PromptPhase.vote || voter < 0 || voter >= players) return;
    final options = mode == VoteMode.mostLikely ? players : 2;
    if (choice < 0 || choice >= options) return;
    votes[voter] = choice;
    if (votesIn == players) _reveal();
    notifyListeners();
  }

  void _reveal() {
    final t = tally(mode == VoteMode.mostLikely ? players : 2);
    final best = t.reduce(max);
    if (mode == VoteMode.mostLikely) {
      lastWinners = [
        for (var i = 0; i < players; i++)
          if (t[i] == best) i
      ];
      for (final w in lastWinners) {
        score[w]++;
      }
    } else {
      lastWinners = t[0] == t[1] ? [] : [t[0] > t[1] ? 0 : 1];
      for (var i = 0; i < players; i++) {
        if (lastWinners.contains(votes[i])) score[i]++;
      }
    }
    phase = PromptPhase.reveal;
  }

  void next() {
    if (forward('next', const [])) return;
    if (phase != PromptPhase.reveal) return;
    round++;
    votes.fillRange(0, players, null);
    phase = round >= rounds ? PromptPhase.done : PromptPhase.vote;
    notifyListeners();
  }
}

RelaySpec<PromptVoteLogic> promptVoteRelay(
        PromptVoteLogic Function(int players) create,
        Widget Function(BuildContext, PromptVoteLogic, List<GpPlayer>, int)
            view) =>
    RelaySpec<PromptVoteLogic>(
      create: create,
      save: (g) => {
        'phase': g.phase.index,
        'round': g.round,
        'votes': g.votes,
        'score': g.score,
        'winners': g.lastWinners,
        'prompts': g.prompts
      },
      load: (g, s, me) {
        g.phase = PromptPhase.values[asInt(s['phase'])];
        g.round = asInt(s['round']);
        g.votes.setAll(0, nInts(s['votes']));
        g.score.setAll(0, ints(s['score']));
        g.lastWinners = ints(s['winners']);
        g.prompts
          ..clear()
          ..addAll((s['prompts'] as List).cast<String>());
      },
      apply: (g, from, name, a) {
        if (name == 'vote' && asInt(a[0]) == from) g.vote(from, asInt(a[1]));
        if (name == 'next') g.next();
      },
      view: view,
    );

class PromptVoteView extends StatefulWidget {
  final List<GpPlayer> players;
  final PromptVoteLogic g;
  final int? me;
  final String title;
  final Color color;
  const PromptVoteView(
      {super.key,
      required this.players,
      required this.g,
      this.me,
      required this.title,
      required this.color});
  @override
  State<PromptVoteView> createState() => _PromptVoteViewState();
}

class _PromptVoteViewState extends State<PromptVoteView> {
  bool _shown = false;

  PromptVoteLogic get g => widget.g;
  bool get mostLikely => g.mode == VoteMode.mostLikely;
  List<String> get options => g.prompt.split('|');

  Widget _promptCard() => PromptCard(
        header: 'Round ${g.round + 1} of ${g.rounds}',
        text: mostLikely
            ? 'Who is most likely to ${g.prompt}?'
            : 'Would you rather…',
        icon: mostLikely ? GameIcons.people : GameIcons.help,
        color: widget.color,
      );

  Widget _choices(int voter, {required VoidCallback after}) {
    final players = widget.players;
    if (mostLikely) {
      return PlayerPicker(
          players: players,
          highlight: g.votes[voter],
          onPick: (i) {
            g.vote(voter, i);
            after();
          });
    }
    return Column(children: [
      for (var o = 0; o < 2; o++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ChoiceCard(
            letter: o == 0 ? 'A' : 'B',
            text: options[o],
            color: o == 0 ? _optionA : _optionB,
            onTap: () {
              haptic(HapticWeight.selection);
              g.vote(voter, o);
              after();
            },
          ),
        ),
    ]);
  }

  int _seat(int i) => PlayerPalette.indexOf(widget.players[i].color) ?? i;

  @override
  Widget build(BuildContext context) {
    final players = widget.players;
    ResultScope.of(context)?.subtitle = '${g.rounds} questions';
    return MomentWatcher<PromptPhase>(
      value: g.phase,
      onChange: (fx, _, now) {
        if (now != PromptPhase.reveal) return;
        if (g.lastWinners.isEmpty) {
          fx?.announce('A PERFECT SPLIT!',
              sub: 'No points this time', color: Colors.white);
        } else if (mostLikely) {
          keyMoment(fx, g.lastWinners.map((w) => players[w].name).join(' & '),
              sub: 'Most likely! +1', sound: 'coin', confetti: true);
        } else {
          keyMoment(fx, 'MAJORITY: ${g.lastWinners.single == 0 ? 'A' : 'B'}',
              sub: 'They score a point', sound: 'coin');
        }
      },
      child: _phase(context),
    );
  }

  Widget _phase(BuildContext context) {
    final players = widget.players, me = widget.me;
    final title = stripEmoji(widget.title);
    switch (g.phase) {
      case PromptPhase.vote:
        if (me != null) {
          final voted = g.votes[me] != null;
          return PartyFrame(
            title: title,
            subtitle: 'Secret vote · ${g.votesIn}/${players.length} voted',
            child: SingleChildScrollView(
              child: Column(children: [
                _promptCard(),
                const SizedBox(height: 16),
                if (voted)
                  const WaitingNote('Vote in! Waiting for the others…')
                else
                  _choices(me, after: () {}),
              ]),
            ),
          );
        }
        final p = g.voteTurn;
        return PartyFrame(
          title: title,
          subtitle: 'Secret vote · ${g.votesIn}/${players.length} voted',
          child: PassAndReveal(
            player: players[p],
            revealed: _shown,
            onReveal: () => setState(() => _shown = true),
            onDone: null, // voting is the way on
            doneLabel: 'Tap your choice above',
            secret: Column(children: [
              _promptCard(),
              const SizedBox(height: 16),
              _choices(p, after: () => setState(() => _shown = false))
            ]),
          ),
        );
      case PromptPhase.reveal:
      case PromptPhase.done:
        final Widget results;
        if (mostLikely) {
          final t = g.tally(players.length);
          final order = [for (var i = 0; i < players.length; i++) i]
            ..sort((a, b) => t[b] - t[a]);
          results = Column(children: [
            for (final i in order)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _VoteRow(
                  player: players[i],
                  seat: _seat(i),
                  winner: g.lastWinners.contains(i),
                  voters: [
                    for (var v = 0; v < players.length; v++)
                      if (g.votes[v] == i) v
                  ],
                  players: players,
                  seatOf: _seat,
                ),
              ),
          ]);
        } else {
          final t = g.tally(2);
          results = _SplitBar(
            options: options,
            counts: t,
            voters: [
              for (var o = 0; o < 2; o++)
                [
                  for (var v = 0; v < players.length; v++)
                    if (g.votes[v] == o) v
                ]
            ],
            winner: g.lastWinners.isEmpty ? null : g.lastWinners.single,
            players: players,
            seatOf: _seat,
          );
        }
        return PartyFrame(
          title: title,
          subtitle: 'The votes are in!',
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
                child: SingleChildScrollView(
                    child: Column(children: [
              _promptCard(),
              const SizedBox(height: 16),
              results
            ]))),
            const SizedBox(height: 10),
            GoldButton(g.round + 1 >= g.rounds ? 'See scores' : 'Next question',
                icon: GameIcons.forward, height: 58, onPressed: g.next),
          ]),
        );
    }
  }
}

/// A big choice card (Would You Rather): the letter, the option, the side's colour.
class _ChoiceCard extends StatelessWidget {
  final String letter, text;
  final Color color;
  final VoidCallback onTap;
  const _ChoiceCard(
      {required this.letter,
      required this.text,
      required this.color,
      required this.onTap});
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: '$letter: $text',
        excludeSemantics: true,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 96),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(color, Colors.white, 0.12)!,
                    Color.lerp(color, Colors.black, 0.2)!
                  ]),
              borderRadius: Radii.rButton,
              boxShadow: Shadows.edge(Color.lerp(color, Colors.black, 0.45)!),
            ),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
                child: Text(letter,
                    style: TextStyle(
                        fontFamily: Fonts.display, fontSize: 24, color: color)),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(text,
                      style: const TextStyle(
                          fontFamily: Fonts.display,
                          fontSize: 20,
                          height: 1.15,
                          color: Colors.white))),
            ]),
          ),
        ),
      );
}

/// Most Likely To: a player's votes stack as badges on their row; the winners get a crown.
class _VoteRow extends StatelessWidget {
  final GpPlayer player;
  final int seat;
  final bool winner;
  final List<int> voters;
  final List<GpPlayer> players;
  final int Function(int) seatOf;
  const _VoteRow(
      {required this.player,
      required this.seat,
      required this.winner,
      required this.voters,
      required this.players,
      required this.seatOf});
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Semantics(
      label:
          '${player.name}: ${voters.length} ${voters.length == 1 ? 'vote' : 'votes'}${winner ? ', most likely' : ''}',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: winner
              ? Brand.gold.withValues(alpha: 0.14)
              : (t.flat ? Colors.white : t.surface),
          borderRadius: Radii.rLg,
          border: Border.all(
              color: winner
                  ? Brand.gold
                  : (t.flat ? FlatPalette.stroke : t.stroke),
              width: winner ? 2 : 1),
        ),
        child: Row(children: [
          PlayerBadge(
              index: seat, size: 28, color: player.color, initial: player.name),
          const SizedBox(width: 10),
          Expanded(
              child: Text(player.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontFamily: Fonts.body,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: t.flat ? FlatPalette.ink : Colors.white))),
          // The votes, as the voters' badges.
          Flexible(
            child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 3,
                runSpacing: 3,
                children: [
                  for (var k = 0; k < voters.length; k++)
                    TweenAnimationBuilder<double>(
                      tween:
                          Tween(begin: Motion.reduced(context) ? 1 : 0, end: 1),
                      duration: Duration(milliseconds: 300 + 120 * k),
                      curve: Curves.easeOutBack,
                      builder: (_, s, child) =>
                          Transform.scale(scale: s, child: child),
                      child: PlayerBadge(
                          index: seatOf(voters[k]),
                          size: 18,
                          color: players[voters[k]].color),
                    ),
                ]),
          ),
          if (winner) ...[
            const SizedBox(width: 8),
            const GameIcon(GameIcons.crown, size: 24, color: Brand.gold)
          ],
        ]),
      ),
    );
  }
}

/// Would You Rather: a bar split by the votes, each side's voters as badges; the majority
/// side glows gold.
class _SplitBar extends StatelessWidget {
  final List<String> options;
  final List<int> counts;
  final List<List<int>> voters;
  final int? winner;
  final List<GpPlayer> players;
  final int Function(int) seatOf;
  const _SplitBar(
      {required this.options,
      required this.counts,
      required this.voters,
      required this.winner,
      required this.players,
      required this.seatOf});
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final total = max(1, counts[0] + counts[1]);
    Widget side(int o) {
      final c = o == 0 ? _optionA : _optionB;
      final win = winner == o;
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.withValues(alpha: win ? 0.3 : 0.14),
            borderRadius: Radii.rButton,
            border: Border.all(
                color: win ? Brand.gold : c.withValues(alpha: 0.6),
                width: win ? 2.5 : 1.5),
            boxShadow: win
                ? [
                    BoxShadow(
                        color: Brand.gold.withValues(alpha: 0.4),
                        blurRadius: 16)
                  ]
                : null,
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(o == 0 ? 'A' : 'B',
                style: TextStyle(
                    fontFamily: Fonts.display,
                    fontSize: 22,
                    color: Color.lerp(c, Colors.white, 0.4))),
            Text(options[o],
                style: TextStyle(
                    fontFamily: Fonts.body,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: t.flat ? FlatPalette.ink : Colors.white)),
            const SizedBox(height: 8),
            Wrap(spacing: 3, runSpacing: 3, children: [
              for (final v in voters[o])
                PlayerBadge(index: seatOf(v), size: 20, color: players[v].color)
            ]),
          ]),
        ),
      );
    }

    return Semantics(
      label: 'A: ${counts[0]} votes, B: ${counts[1]} votes',
      excludeSemantics: true,
      child: Column(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 26,
            child: Row(children: [
              Expanded(
                  flex: max(1, counts[0] * 100 ~/ total),
                  child: Container(
                      color: _optionA,
                      alignment: Alignment.center,
                      child: Text('${counts[0]}',
                          style: const TextStyle(
                              fontFamily: Fonts.display,
                              fontSize: 16,
                              color: Colors.white)))),
              Container(width: 3, color: Colors.white),
              Expanded(
                  flex: max(1, counts[1] * 100 ~/ total),
                  child: Container(
                      color: _optionB,
                      alignment: Alignment.center,
                      child: Text('${counts[1]}',
                          style: const TextStyle(
                              fontFamily: Fonts.display,
                              fontSize: 16,
                              color: Colors.white)))),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
            child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [side(0), const SizedBox(width: 10), side(1)])),
        const SizedBox(height: 8),
        Text(
            winner == null
                ? 'A perfect split! No points.'
                : 'The majority scores a point!',
            style: t.styles.bodyStrong.copyWith(color: t.onBgMuted)),
      ]),
    );
  }
}
