import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/ui/components.dart';
import '../../guess_person/models/gp_player.dart';
import '../shell/game_hud.dart' show MomentWatcher, keyMoment;
import '../shell/local_game_shell.dart' show ResultScope;
import '../party/party_widgets.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/ticking_play.dart';

enum SpyPhase { reveal, discuss, vote, spyGuess, result, done }

/// Find the Spy (Spyfall-style). Everyone sees the same secret location except the spy.
/// Ask each other questions, then vote. Catch the spy and they get one guess at the
/// location: right = spy wins after all. Spy wins: +2 for the spy. Town wins: +1 each.
class FindSpyLogic extends LocalGameLogic {
  static const discussMs = 180000;
  static const places = [
    ('Beach', '🏖️'), ('School', '🏫'), ('Hospital', '🏥'), ('Airport', '✈️'),
    ('Cinema', '🎬'), ('Restaurant', '🍽️'), //
    ('Space Station', '🚀'),
    ('Cricket Stadium', '🏏'),
    ('Railway Station', '🚉'),
    ('Wedding', '💒'),
    ('Bank', '🏦'),
    ('Zoo', '🦁'), //
    ('Hostel', '🛏️'), ('Temple', '🛕'), ('Shopping Mall', '🛍️'),
    ('Police Station', '🚓'), ('Pirate Ship', '🏴‍☠️'), ('Submarine', '🌊'), //
    ('Circus', '🎪'), ('Gym', '🏋️'), ('Library', '📚'), ('Hotel', '🏨'),
    ('Vegetable Market', '🧺'), ('Office', '💼'), //
    ('Farm', '🚜'), ('Museum', '🏛️'), ('Concert', '🎤'),
    ('Hill Station', '⛰️'), ('Metro', '🚇'), ('College Canteen', '🍛'),
  ];

  final int players;
  final Random _rng;
  late int place;
  late int spy;
  late List<int> options; // places the spy may guess from
  SpyPhase phase = SpyPhase.reveal;
  final Set<int> seen = {};
  int now = 0;
  int deadline = 0;
  late final List<int?> votes = List.filled(players, null);
  int accused = -1;
  int? spyGuess;
  bool spyWins = false;

  FindSpyLogic({this.players = 3, Random? random}) : _rng = random ?? Random() {
    place = _rng.nextInt(places.length);
    spy = _rng.nextInt(players);
    final others = [
      for (var i = 0; i < places.length; i++)
        if (i != place) i
    ]..shuffle(_rng);
    options = [place, ...others.take(7)]..shuffle(_rng);
  }

  /// Next player to see their card when passing one phone round.
  int get revealTurn =>
      [
        for (var i = 0; i < players; i++)
          if (!seen.contains(i)) i
      ].firstOrNull ??
      0;
  int get msLeft => max(0, deadline - now);
  int get votesIn => votes.where((v) => v != null).length;

  @override
  bool get finished => phase == SpyPhase.done;
  @override
  List<int> get scores => [
        for (var i = 0; i < players; i++)
          spyWins ? (i == spy ? 2 : 0) : (i == spy ? 0 : 1)
      ];

  @override
  void update(int elapsedMs) {
    now = elapsedMs;
    if (phase == SpyPhase.discuss && now >= deadline) {
      phase = SpyPhase.vote;
      notifyListeners();
    }
  }

  void seenCard(int p) {
    if (forward('seen', [p])) return;
    if (phase != SpyPhase.reveal || p < 0 || p >= players) return;
    seen.add(p);
    if (seen.length == players) {
      phase = SpyPhase.discuss;
      deadline = now + discussMs;
    }
    notifyListeners();
  }

  void startVote() {
    if (forward('startVote', const [])) return;
    if (phase != SpyPhase.discuss) return;
    phase = SpyPhase.vote;
    notifyListeners();
  }

  /// One phone: the group agrees and taps the accused.
  void accuse(int target) {
    if (forward('accuse', [target])) return;
    if (phase != SpyPhase.vote || target < 0 || target >= players) return;
    _resolve(target);
  }

  /// Online: everyone votes; the most-voted player is accused (a tie accuses nobody).
  void vote(int voter, int target) {
    if (forward('vote', [voter, target])) return;
    if (phase != SpyPhase.vote ||
        voter == target ||
        target < 0 ||
        target >= players ||
        votes[voter] != null) return;
    votes[voter] = target;
    if (votesIn == players) {
      _resolve(voteWinner(votes));
    } else {
      notifyListeners();
    }
  }

  void _resolve(int target) {
    accused = target;
    if (target == spy) {
      phase = SpyPhase.spyGuess;
    } else {
      spyWins = true;
      phase = SpyPhase.result;
    }
    notifyListeners();
  }

  void guess(int placeIndex) {
    if (forward('guess', [placeIndex])) return;
    if (phase != SpyPhase.spyGuess || !options.contains(placeIndex)) return;
    spyGuess = placeIndex;
    spyWins = placeIndex == place;
    phase = SpyPhase.result;
    notifyListeners();
  }

  void finish() {
    if (forward('finish', const [])) return;
    if (phase != SpyPhase.result) return;
    phase = SpyPhase.done;
    notifyListeners();
  }
}

final findSpyInfo = LocalGameInfo(
  id: 'find_spy',
  title: 'Find the Spy',
  emoji: '🕵️‍♂️',
  color: const Color(0xFF2D3436),
  tagline: 'One of you is a spy. Who is it?',
  rules: const [
    'Everyone secretly sees the same location, except the SPY, who sees nothing.',
    'Take turns asking each other questions about the place. Be clever: the spy is listening!',
    'Vote for the spy. If you catch them, the spy can still win by guessing the location.',
    'Spy wins: +2 for the spy. Spy caught: +1 for everyone else. 3 to 6 players.',
  ],
  scoreUnit: 'points',
  splitScreen: false,
  minPlayers: 3,
  maxPlayers: 6,
  online: RelaySpec<FindSpyLogic>(
    create: (n) => FindSpyLogic(players: n),
    save: (g) => {
      'place': g.place, 'spy': g.spy, 'options': g.options,
      'phase': g.phase.index, 'seen': g.seen.toList(), //
      'left': g.msLeft, 'votes': g.votes, 'accused': g.accused,
      'guess': g.spyGuess, 'spyWins': g.spyWins,
    },
    wire: (g) {
      final open = g.phase.index >= SpyPhase.result.index;
      return {
        if (open) 'place': g.place,
        if (open) 'spy': g.spy,
        if (open) 'options': g.options,
        'phase': g.phase.index,
        'seen': g.seen.toList(),
        'left': g.msLeft,
        'votes': g.votes,
        'accused': g.accused,
        'guess': g.spyGuess,
        'spyWins': g.spyWins,
      };
    },
    views: (g) => [
      for (var i = 0; i < g.players; i++)
        i == g.spy
            ? {'spy': true, 'options': g.options}
            : {'spy': false, 'place': g.place}
    ],
    load: (g, s, me) {
      if (s['place'] != null) g.place = asInt(s['place']);
      if (s['spy'] != null) g.spy = asInt(s['spy']);
      if (s['options'] != null) g.options = ints(s['options']);
      final seat = s['_seat'];
      if (seat is Map && s['spy'] == null) {
        if (seat['spy'] == true) {
          g.spy = me;
          g.place = -1;
          if (seat['options'] != null) g.options = ints(seat['options']);
        } else {
          g.spy = -1;
          if (seat['place'] != null) g.place = asInt(seat['place']);
        }
      }
      g.phase = SpyPhase.values[asInt(s['phase'])];
      g.seen
        ..clear()
        ..addAll(ints(s['seen']));
      g.now = 0;
      g.deadline = asInt(s['left']);
      g.votes.setAll(0, nInts(s['votes']));
      g.accused = asInt(s['accused']);
      g.spyGuess = nInt(s['guess']);
      g.spyWins = s['spyWins'] == true;
    },
    apply: (g, from, name, a) {
      switch (name) {
        case 'seen' when asInt(a[0]) == from:
          g.seenCard(from);
        case 'startVote':
          g.startVote();
        case 'vote' when asInt(a[0]) == from:
          g.vote(from, asInt(a[1]));
        case 'guess' when from == g.spy:
          g.guess(asInt(a[0]));
        case 'finish':
          g.finish();
      }
    },
    view: (context, g, players, me) => _SpyView(players: players, g: g, me: me),
  ),
  play: (players, onFinished) => TickingPlay<FindSpyLogic>(
    create: () => FindSpyLogic(players: players.length),
    onFinished: onFinished,
    builder: (context, g) => _SpyView(players: players, g: g),
  ),
);

class _SpyView extends StatefulWidget {
  final List<GpPlayer> players;
  final FindSpyLogic g;
  final int? me; // online: whose phone this is
  const _SpyView({required this.players, required this.g, this.me});
  @override
  State<_SpyView> createState() => _SpyViewState();
}

/// A drawn icon for each location (the logic keeps its emoji keys).
const _placeIcons = [
  GameIcons.sun, GameIcons.pencil, GameIcons.medical, GameIcons.arrowUp,
  GameIcons.clapper, GameIcons.cherry, //
  GameIcons.rocket, GameIcons.bat, GameIcons.clock, GameIcons.heart,
  GameIcons.coin, GameIcons.rabbit, //
  GameIcons.home, GameIcons.star, GameIcons.mysteryBox, GameIcons.shield,
  GameIcons.flag, GameIcons.drop, //
  GameIcons.target, GameIcons.hammer, GameIcons.scroll, GameIcons.home,
  GameIcons.apple, GameIcons.pencil, //
  GameIcons.pig, GameIcons.crown, GameIcons.sound, GameIcons.moon,
  GameIcons.arrowRight, GameIcons.cherry,
];
GameIcons _placeIcon(int i) =>
    i < _placeIcons.length ? _placeIcons[i] : GameIcons.flag;

/// A small location card: drawn icon and name on paper.
class _PlaceChip extends StatelessWidget {
  final int place;
  final VoidCallback? onTap;
  const _PlaceChip(this.place, {this.onTap});
  @override
  Widget build(BuildContext context) {
    final name = FindSpyLogic.places[place].$1;
    return Semantics(
      button: onTap != null,
      label: name,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap == null
            ? null
            : () {
                haptic(HapticWeight.medium);
                onTap!();
              },
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFFDF6), Color(0xFFF5E9D2)]),
            borderRadius: Radii.rCard,
            boxShadow: const [
              BoxShadow(
                  color: Color(0x40000000), offset: Offset(0, 2), blurRadius: 3)
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            GameIcon(_placeIcon(place),
                size: onTap == null ? 16 : 22, color: const Color(0xFF7B4DFF)),
            const SizedBox(width: 6),
            Flexible(
                child: Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: Fonts.body,
                        fontWeight: FontWeight.w900,
                        fontSize: onTap == null ? 12.5 : 14,
                        color: Brand.onGold))),
          ]),
        ),
      ),
    );
  }
}

class _SpyViewState extends State<_SpyView> {
  bool _shown = false; // one phone: the current player's card is showing

  FindSpyLogic get g => widget.g;
  List<GpPlayer> get players => widget.players;
  int get place => g.place;
  int get spy => g.spy;
  List<int> get options => g.options;

  Widget _secret(int p) => p == spy
      ? const PromptCard(
          header: 'You are the',
          text: 'SPY',
          icon: GameIcons.magnifier,
          dark: true,
          footer:
              "You don't know the location. Listen, blend in, and work out where you are!",
          color: Color(0xFFFF5E5B))
      : PromptCard(
          header: 'Location',
          text: FindSpyLogic.places[place].$1,
          icon: _placeIcon(place),
          footer:
              'One of you is the spy. Ask questions to find them, without giving the place away!');

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    ResultScope.of(context)?.subtitle = g.phase.index >= SpyPhase.result.index
        ? (g.spyWins ? 'The spy wins' : 'The town wins')
        : null;
    final Widget view = _phase(context, me);
    return MomentWatcher<SpyPhase>(
      value: g.phase,
      onChange: (fx, _, now) {
        if (now == SpyPhase.spyGuess)
          keyMoment(fx, 'SPY CAUGHT!',
              sub: '${players[spy].name} gets one last guess', sound: 'hit');
        if (now == SpyPhase.result) {
          if (g.spyWins) {
            keyMoment(fx, 'SPY WINS!',
                sub: g.accused == spy
                    ? 'They guessed the place'
                    : 'Nobody caught them',
                sound: 'lose',
                color: const Color(0xFFFF8E8B));
          } else {
            keyMoment(fx, 'TOWN WINS!',
                sub: '${players[spy].name} was the spy',
                sound: 'win',
                confetti: true);
          }
        }
      },
      child: view,
    );
  }

  Widget _phase(BuildContext context, int? me) {
    final t = context.tk;
    switch (g.phase) {
      case SpyPhase.reveal:
        if (me != null) {
          final ready = g.seen.contains(me);
          return PartyFrame(
            title: 'Find the Spy',
            subtitle: ready
                ? 'Waiting for the others (${g.seen.length}/${players.length})'
                : 'Remember it, then tap Ready',
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                      child: Center(
                          child: SingleChildScrollView(child: _secret(me)))),
                  GoldButton(ready ? 'Ready' : "I'm ready",
                      icon: ready ? GameIcons.check : null,
                      height: 58,
                      onPressed: ready ? null : () => g.seenCard(me)),
                ]),
          );
        }
        final p = g.revealTurn;
        return PartyFrame(
          title: 'Find the Spy',
          subtitle: '${g.seen.length} of ${players.length} have looked',
          child: PassAndReveal(
            player: players[p],
            revealed: _shown,
            onReveal: () => setState(() => _shown = true),
            onDone: () {
              setState(() => _shown = false);
              g.seenCard(p);
            },
            secret: _secret(p),
          ),
        );
      case SpyPhase.discuss:
        return PartyFrame(
          title: 'Find the Spy',
          subtitle: 'Ask questions!',
          trailing: TimeChip(g.msLeft),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TurnBanner(
                text: 'Take turns asking',
                sub: 'Ask anyone a question about the place',
                color: Brand.gold,
                kind: TurnBannerKind.info,
                icon: GameIcons.speech,
                compact: true),
            const SizedBox(height: 10),
            Text('POSSIBLE LOCATIONS', style: t.styles.label),
            const SizedBox(height: 6),
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(spacing: 6, runSpacing: 6, children: [
                  for (var i = 0; i < FindSpyLogic.places.length; i++)
                    _PlaceChip(i)
                ]),
              ),
            ),
            const SizedBox(height: 10),
            GoldButton("We're ready to vote",
                icon: GameIcons.people, height: 58, onPressed: g.startVote),
          ]),
        );
      case SpyPhase.vote:
        if (me != null) {
          return PartyFrame(
            title: 'Who is the spy?',
            subtitle: 'Your vote · ${g.votesIn}/${players.length} voted',
            child: Center(
              child: SingleChildScrollView(
                child: PlayerPicker(
                    players: players,
                    disabled: {me},
                    highlight: g.votes[me],
                    onPick: (i) => g.vote(me, i)),
              ),
            ),
          );
        }
        return PartyFrame(
          title: 'Who is the spy?',
          subtitle: 'Agree, then tap who you accuse',
          child: Center(
              child: SingleChildScrollView(
                  child: PlayerPicker(players: players, onPick: g.accuse))),
        );
      case SpyPhase.spyGuess:
        final canGuess = me == null || me == spy;
        return PartyFrame(
          title: 'Spy caught: ${players[spy].name}!',
          subtitle: canGuess
              ? 'One last chance: guess the place'
              : '${players[spy].name} is guessing…',
          child: canGuess
              ? GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.6,
                  children: [
                    for (final o in options)
                      _PlaceChip(o, onTap: () => g.guess(o))
                  ],
                )
              : const WaitingNote('The spy is guessing…'),
        );
      case SpyPhase.result:
      case SpyPhase.done:
        final caught = g.accused == spy;
        final (String head, String sub) = !caught
            ? (g.accused < 0
                ? ('Tie vote', 'The spy escapes!')
                : ('Wrong!', '${players[g.accused].name} was innocent'))
            : (g.spyWins
                ? ('The spy guessed it!', 'The place was found out')
                : ('Spy caught!', 'The town wins'));
        return PartyFrame(
          title: g.spyWins ? 'Spy wins' : 'Town wins',
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(children: [
                    TurnBanner(
                        text: head,
                        sub: sub,
                        color: Brand.gold,
                        kind: g.spyWins
                            ? TurnBannerKind.miss
                            : TurnBannerKind.success,
                        icon: g.spyWins ? GameIcons.cross : GameIcons.check),
                    const SizedBox(height: 16),
                    PromptCard(
                      header: 'The spy was',
                      text: players[spy].name,
                      icon: GameIcons.magnifier,
                      dark: true,
                      footer:
                          'Location: ${FindSpyLogic.places[place].$1}${g.spyGuess != null ? '\nSpy guessed: ${FindSpyLogic.places[g.spyGuess!].$1}' : ''}',
                      color: players[spy].color,
                    ),
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
