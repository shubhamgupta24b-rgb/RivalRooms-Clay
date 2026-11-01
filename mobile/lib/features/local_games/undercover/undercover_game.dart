import 'dart:math';
import 'package:flutter/material.dart';
import '../../guess_person/models/gp_player.dart';
import '../../../core/ui/components.dart';
import '../shell/game_hud.dart' show MomentWatcher, keyMoment;
import '../shell/local_game_shell.dart' show ResultScope;
import '../party/party_widgets.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/ticking_play.dart';

enum UcPhase { reveal, describe, vote, out, result, done }

/// Undercover: everyone gets the same secret word except one player, who gets a similar
/// one (and doesn't know it). Each round everyone gives a clue, then the group votes
/// someone out. Catch the undercover: +1 for everyone else. Undercover survives to the
/// final two: +3 for them.
class UndercoverLogic extends LocalGameLogic {
  static const pairs = [
    ('Coffee', 'Tea'), ('Cricket', 'Football'), ('Samosa', 'Kachori'),
    ('Pizza', 'Burger'), ('Cat', 'Dog'), ('Train', 'Bus'), //
    ('Mango', 'Banana'), ('Doctor', 'Nurse'), ('Instagram', 'Snapchat'),
    ('Netflix', 'YouTube'), ('Beach', 'Swimming Pool'), ('Lion', 'Tiger'), //
    ('Diwali', 'Holi'), ('Biryani', 'Pulao'), ('Guitar', 'Violin'),
    ('Teacher', 'Principal'), ('Rain', 'Snow'), ('Shirt', 'T-shirt'), //
    ('Pen', 'Pencil'), ('Moon', 'Sun'), ('Hotel', 'Hostel'),
    ('Phone', 'Tablet'), ('Chess', 'Ludo'), ('Ice cream', 'Kulfi'), //
    ('Bike', 'Scooter'),
    ('Doctor Strange', 'Iron Man'),
    ('Shah Rukh Khan', 'Salman Khan'),
    ('Exam', 'Quiz'),
    ('Wedding', 'Birthday party'),
    ('Mountain', 'Hill'), //
    ('Chai', 'Coffee'), ('Laptop', 'Computer'), ('Rose', 'Sunflower'),
    ('Airport', 'Railway station'), ('Gold', 'Silver'), ('Paneer', 'Tofu'), //
    ('Whatsapp', 'Telegram'), ('Library', 'Bookshop'), ('Elephant', 'Rhino'),
    ('Pani puri', 'Bhel puri'),
  ];

  final int players;
  final Random _rng;
  late int pair;
  late int undercover;
  late bool swapped; // which word of the pair the town gets
  UcPhase phase = UcPhase.reveal;
  final Set<int> seen = {};
  late final Set<int> alive = {for (var i = 0; i < players; i++) i};
  late final List<int?> votes = List.filled(players, null);
  int round = 1;
  int lastOut = -1; // -1 after a tie
  bool undercoverWins = false;

  UndercoverLogic({this.players = 3, Random? random})
      : _rng = random ?? Random() {
    pair = _rng.nextInt(pairs.length);
    undercover = _rng.nextInt(players);
    swapped = _rng.nextBool();
  }

  String get townWord => swapped ? pairs[pair].$2 : pairs[pair].$1;
  String get undercoverWord => swapped ? pairs[pair].$1 : pairs[pair].$2;
  final List<String?> seatWords = [];
  String? publicOutWord;
  String wordFor(int p) {
    if (publicOutWord != null && p == lastOut) return publicOutWord!;
    if (p >= 0 && p < seatWords.length && seatWords[p] != null)
      return seatWords[p]!;
    return p == undercover ? undercoverWord : townWord;
  }

  int get revealTurn =>
      [
        for (var i = 0; i < players; i++)
          if (!seen.contains(i)) i
      ].firstOrNull ??
      0;
  int get votesIn => [
        for (final p in alive)
          if (votes[p] != null) p
      ].length;

  @override
  bool get finished => phase == UcPhase.done;
  @override
  List<int> get scores => [
        for (var i = 0; i < players; i++)
          undercoverWins ? (i == undercover ? 3 : 0) : (i == undercover ? 0 : 1)
      ];
  @override
  void update(int elapsedMs) {}

  void seenCard(int p) {
    if (forward('seen', [p])) return;
    if (phase != UcPhase.reveal || p < 0 || p >= players) return;
    seen.add(p);
    if (seen.length == players) phase = UcPhase.describe;
    notifyListeners();
  }

  void startVote() {
    if (forward('startVote', const [])) return;
    if (phase != UcPhase.describe) return;
    votes.fillRange(0, players, null);
    phase = UcPhase.vote;
    notifyListeners();
  }

  void accuse(int target) {
    if (forward('accuse', [target])) return;
    if (phase != UcPhase.vote || !alive.contains(target)) return;
    _out(target);
  }

  void vote(int voter, int target) {
    if (forward('vote', [voter, target])) return;
    if (phase != UcPhase.vote ||
        voter == target ||
        !alive.contains(voter) ||
        !alive.contains(target)) return;
    votes[voter] = target;
    if (votesIn == alive.length) {
      _out(voteWinner([for (final p in alive) votes[p]]));
    } else {
      notifyListeners();
    }
  }

  void _out(int target) {
    lastOut = target;
    if (target >= 0) alive.remove(target);
    if (target == undercover) {
      undercoverWins = false;
      phase = UcPhase.result;
    } else if (alive.length <= 2) {
      undercoverWins = true;
      phase = UcPhase.result;
    } else {
      phase = UcPhase.out;
    }
    notifyListeners();
  }

  void nextRound() {
    if (forward('next', const [])) return;
    if (phase != UcPhase.out) return;
    round++;
    phase = UcPhase.describe;
    notifyListeners();
  }

  void finish() {
    if (forward('finish', const [])) return;
    if (phase != UcPhase.result) return;
    phase = UcPhase.done;
    notifyListeners();
  }
}

final undercoverInfo = LocalGameInfo(
  id: 'undercover',
  title: 'Undercover',
  emoji: '🎭',
  color: const Color(0xFF6C5CE7),
  tagline: 'Same word for all… except one.',
  rules: const [
    'Everyone secretly gets a word. One player (the undercover) gets a slightly different word, and nobody knows who.',
    'Each round, everyone says ONE word or short clue about their word. Not too obvious!',
    'Then vote someone out. Catch the undercover: +1 each. Undercover reaches the final two: +3.',
  ],
  scoreUnit: 'points',
  splitScreen: false,
  minPlayers: 3,
  maxPlayers: 6,
  online: RelaySpec<UndercoverLogic>(
    create: (n) => UndercoverLogic(players: n),
    save: (g) => {
      'pair': g.pair, 'uc': g.undercover, 'swapped': g.swapped,
      'phase': g.phase.index, 'seen': g.seen.toList(), //
      'alive': g.alive.toList(), 'votes': g.votes, 'round': g.round,
      'out': g.lastOut, 'ucWins': g.undercoverWins,
    },
    wire: (g) {
      final open = g.phase.index >= UcPhase.result.index;
      return {
        if (open) 'pair': g.pair,
        if (open) 'uc': g.undercover,
        if (open) 'swapped': g.swapped,
        if (g.phase == UcPhase.out && g.lastOut >= 0)
          'outWord': g.wordFor(g.lastOut),
        'phase': g.phase.index,
        'seen': g.seen.toList(),
        'alive': g.alive.toList(),
        'votes': g.votes,
        'round': g.round,
        'out': g.lastOut,
        'ucWins': g.undercoverWins,
      };
    },
    views: (g) => [
      for (var i = 0; i < g.players; i++)
        {'word': g.wordFor(i), 'uc': i == g.undercover}
    ],
    load: (g, s, me) {
      if (s['pair'] != null) g.pair = asInt(s['pair']);
      if (s['uc'] != null) g.undercover = asInt(s['uc']);
      if (s['swapped'] != null) g.swapped = s['swapped'] == true;
      final seat = s['_seat'];
      if (seat is Map && s['uc'] == null) {
        while (g.seatWords.length < g.players) {
          g.seatWords.add(null);
        }
        if (me >= 0 && me < g.players)
          g.seatWords[me] = seat['word'] as String?;
        g.undercover = seat['uc'] == true ? me : -1;
      }
      g.publicOutWord = s['outWord'] as String?;
      g.phase = UcPhase.values[asInt(s['phase'])];
      g.seen
        ..clear()
        ..addAll(ints(s['seen']));
      g.alive
        ..clear()
        ..addAll(ints(s['alive']));
      g.votes.setAll(0, nInts(s['votes']));
      g.round = asInt(s['round']);
      g.lastOut = asInt(s['out']);
      g.undercoverWins = s['ucWins'] == true;
    },
    apply: (g, from, name, a) {
      switch (name) {
        case 'seen' when asInt(a[0]) == from:
          g.seenCard(from);
        case 'startVote':
          g.startVote();
        case 'vote' when asInt(a[0]) == from:
          g.vote(from, asInt(a[1]));
        case 'next':
          g.nextRound();
        case 'finish':
          g.finish();
      }
    },
    view: (context, g, players, me) => _UcView(players: players, g: g, me: me),
  ),
  play: (players, onFinished) => TickingPlay<UndercoverLogic>(
    create: () => UndercoverLogic(players: players.length),
    onFinished: onFinished,
    builder: (context, g) => _UcView(players: players, g: g),
  ),
);

class _UcView extends StatefulWidget {
  final List<GpPlayer> players;
  final UndercoverLogic g;
  final int? me;
  const _UcView({required this.players, required this.g, this.me});
  @override
  State<_UcView> createState() => _UcViewState();
}

class _UcViewState extends State<_UcView> {
  bool _shown = false;

  @override
  Widget build(BuildContext context) {
    final g = widget.g, players = widget.players;
    ResultScope.of(context)?.subtitle = g.phase.index >= UcPhase.result.index
        ? (g.undercoverWins ? 'The undercover wins' : 'The town wins')
        : null;
    return MomentWatcher<UcPhase>(
      value: g.phase,
      onChange: (fx, _, now) {
        if (now == UcPhase.out && g.lastOut >= 0)
          keyMoment(fx, 'VOTED OUT',
              sub: '${players[g.lastOut].name} was not undercover',
              sound: 'lose',
              color: Colors.white);
        if (now == UcPhase.result) {
          if (g.undercoverWins) {
            keyMoment(fx, 'UNDERCOVER WINS!',
                sub: '${players[g.undercover].name} survived',
                sound: 'lose',
                color: const Color(0xFFFF8E8B));
          } else {
            keyMoment(fx, 'CAUGHT!',
                sub: '${players[g.undercover].name} was undercover',
                sound: 'win',
                confetti: true);
          }
        }
      },
      child: _phase(context),
    );
  }

  Widget _phase(BuildContext context) {
    final g = widget.g, players = widget.players, me = widget.me;
    final t = context.tk;
    final out = {
      for (var i = 0; i < players.length; i++)
        if (!g.alive.contains(i)) i
    };
    Widget secret(int p) => PromptCard(
        header: 'Your secret word',
        text: g.wordFor(p),
        icon: GameIcons.lock,
        footer: 'Someone has a slightly different word. It might be you!');

    switch (g.phase) {
      case UcPhase.reveal:
        if (me != null) {
          final ready = g.seen.contains(me);
          return PartyFrame(
            title: 'Undercover',
            subtitle: ready
                ? 'Waiting for the others (${g.seen.length}/${players.length})'
                : 'Remember it, then tap Ready',
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                      child: Center(
                          child: SingleChildScrollView(child: secret(me)))),
                  GoldButton(ready ? 'Ready' : "I'm ready",
                      icon: ready ? GameIcons.check : null,
                      height: 58,
                      onPressed: ready ? null : () => g.seenCard(me)),
                ]),
          );
        }
        final p = g.revealTurn;
        return PartyFrame(
          title: 'Undercover',
          subtitle: '${g.seen.length} of ${players.length} have looked',
          child: PassAndReveal(
            player: players[p],
            revealed: _shown,
            onReveal: () => setState(() => _shown = true),
            onDone: () {
              setState(() => _shown = false);
              g.seenCard(p);
            },
            secret: secret(p),
          ),
        );
      case UcPhase.describe:
        final order = [
          for (var i = 0; i < players.length; i++)
            if (g.alive.contains(i)) i
        ];
        return PartyFrame(
          title: 'Undercover',
          subtitle: 'Round ${g.round}: give a clue',
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TurnBanner(
                text: 'One word each',
                sub: 'In order, say one word about your secret word',
                color: Brand.gold,
                kind: TurnBannerKind.info,
                icon: GameIcons.speech,
                compact: true),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(children: [
                for (var k = 0; k < order.length; k++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ClueRow(
                        order: k + 1,
                        player: players[order[k]],
                        seat: PlayerPalette.indexOf(players[order[k]].color) ??
                            order[k]),
                  ),
                for (final i in out)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Opacity(
                          opacity: 0.45,
                          child: _ClueRow(
                              order: 0,
                              player: players[i],
                              seat: PlayerPalette.indexOf(players[i].color) ??
                                  i))),
              ]),
            ),
            if (me != null)
              Text('Your word: ${g.wordFor(me)}',
                  textAlign: TextAlign.center,
                  style: t.styles.bodyStrong.copyWith(color: t.onBgMuted)),
            const SizedBox(height: 8),
            GoldButton('Everyone gave a clue: vote',
                icon: GameIcons.people,
                height: 58,
                fontSize: 19,
                onPressed: g.startVote),
          ]),
        );
      case UcPhase.vote:
        if (me != null) {
          final canVote = g.alive.contains(me);
          return PartyFrame(
            title: 'Who is undercover?',
            subtitle: canVote
                ? 'Your vote · ${g.votesIn}/${g.alive.length} voted'
                : "You're out: watch the others vote",
            child: Center(
              child: SingleChildScrollView(
                child: PlayerPicker(
                    players: players,
                    disabled: {...out, me},
                    highlight: g.votes[me],
                    onPick: canVote ? (i) => g.vote(me, i) : null),
              ),
            ),
          );
        }
        return PartyFrame(
          title: 'Who is undercover?',
          subtitle: 'Agree, then tap who to vote out',
          child: Center(
              child: SingleChildScrollView(
                  child: PlayerPicker(
                      players: players,
                      disabled: out,
                      onPick: g.accuse,
                      notes: {for (final i in out) i: 'OUT'}))),
        );
      case UcPhase.out:
        return PartyFrame(
          title: 'Voted out',
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: g.lastOut < 0
                      ? const PromptCard(
                          header: 'Tie vote',
                          text: 'Nobody is out',
                          icon: GameIcons.people,
                          footer: 'Give another clue and vote again.')
                      : _FlipReveal(
                          front: PromptCard(
                              header: '${players[g.lastOut].name} is out',
                              text: '…',
                              icon: GameIcons.mask,
                              color: players[g.lastOut].color),
                          back: PromptCard(
                              header: '${players[g.lastOut].name} is out',
                              text: g.wordFor(g.lastOut),
                              icon: GameIcons.check,
                              footer:
                                  'Not undercover! The undercover is still among you…',
                              color: players[g.lastOut].color),
                        ),
                ),
              ),
            ),
            GoldButton('Next round',
                icon: GameIcons.forward, height: 58, onPressed: g.nextRound),
          ]),
        );
      case UcPhase.result:
      case UcPhase.done:
        final uc = players[g.undercover];
        return PartyFrame(
          title: g.undercoverWins ? 'Undercover wins' : 'Town wins',
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(children: [
                    TurnBanner(
                      text: g.undercoverWins
                          ? '${uc.name} survived!'
                          : '${uc.name} was caught!',
                      sub: g.undercoverWins
                          ? 'The undercover made it to the end'
                          : 'The town found the undercover',
                      color: uc.color,
                      kind: g.undercoverWins
                          ? TurnBannerKind.miss
                          : TurnBannerKind.success,
                      icon: GameIcons.mask,
                    ),
                    const SizedBox(height: 14),
                    // The two words side by side.
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              child: PromptCard(
                                  header: 'Undercover',
                                  text: g.undercoverWord,
                                  icon: GameIcons.mask,
                                  color: uc.color,
                                  dark: true)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: PromptCard(
                                  header: 'Everyone else',
                                  text: g.townWord,
                                  icon: GameIcons.people)),
                        ]),
                  ]),
                ),
              ),
            ),
            GoldButton('See scores',
                icon: GameIcons.trophy, height: 58, onPressed: g.finish),
          ]),
        );
    }
  }
}

/// A player's turn to give a clue: order number, badge, name and a speech bubble.
class _ClueRow extends StatelessWidget {
  final int order; // 0: out
  final GpPlayer player;
  final int seat;
  const _ClueRow(
      {required this.order, required this.player, required this.seat});
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
          color: t.flat ? Colors.white : t.surface,
          borderRadius: Radii.rLg,
          border: Border.all(color: t.flat ? FlatPalette.stroke : t.stroke)),
      child: Row(children: [
        SizedBox(
            width: 22,
            child: Text(order == 0 ? '' : '$order',
                style: TextStyle(
                    fontFamily: Fonts.display,
                    fontSize: 18,
                    color: t.flat ? FlatPalette.ink : Brand.gold))),
        PlayerBadge(
            index: seat, size: 24, color: player.color, initial: player.name),
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
        if (order == 0)
          Text('OUT', style: t.styles.label)
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: player.color.withValues(alpha: 0.2),
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(3))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              GameIcon(GameIcons.speech,
                  size: 14,
                  color:
                      t.flat ? fillFor(player.color) : nameColor(player.color)),
              const SizedBox(width: 4),
              Text('one word',
                  style: TextStyle(
                      fontFamily: Fonts.body,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: t.flat ? FlatPalette.ink : kIdleInk)),
            ]),
          ),
      ]),
    );
  }
}

/// A card that flips once from [front] to [back] when it appears.
class _FlipReveal extends StatelessWidget {
  final Widget front, back;
  const _FlipReveal({required this.front, required this.back});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: Motion.reduced(context) ? 1 : 0, end: 1),
        duration: const Duration(milliseconds: 900),
        curve: const Interval(0.35, 1, curve: Curves.easeInOutCubic),
        builder: (_, v, __) {
          final showBack = v >= 0.5;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0015)
              ..rotateY((showBack ? v - 1 : v) * pi),
            child: showBack ? back : front,
          );
        },
      );
}
