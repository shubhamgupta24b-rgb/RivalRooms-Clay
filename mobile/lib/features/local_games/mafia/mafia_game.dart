import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/ui/components.dart';
import '../../guess_person/models/gp_player.dart';
import '../../../core/ui/materials/materials.dart';
import '../shell/game_hud.dart' show MomentWatcher, keyMoment;
import '../shell/local_game_shell.dart' show ResultScope;
import '../party/party_widgets.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/ticking_play.dart';

enum MafiaRole {
  mafia(
      'MAFIA',
      '🔪',
      'Each night, choose someone to eliminate. Win when the mafia are as many as everyone else.',
      Color(0xFFE53935)),
  doctor(
      'DOCTOR',
      '💉',
      'Each night, choose someone to save (you can save yourself). Win when all the mafia are out.',
      Color(0xFF2ECC71)),
  detective(
      'DETECTIVE',
      '🔍',
      'Each night, check one player to learn if they are mafia. Win when all the mafia are out.',
      Color(0xFF4D96FF)),
  villager(
      'VILLAGER',
      '🧑‍🌾',
      'Sleep at night. In the day, find the mafia and vote them out!',
      Color(0xFFE0A800));

  final String title;
  final String emoji;
  final String about;
  final Color color;
  const MafiaRole(this.title, this.emoji, this.about, this.color);
}

enum MafiaPhase { reveal, night, morning, vote, out, result, done }

/// Mafia for 4-6 players. Night: the phone goes round every living player in turn (so
/// nobody can tell who did something); the mafia picks a victim, the doctor saves
/// someone, the detective checks someone. Day: discuss and vote someone out.
/// Town wins when the mafia are gone (+1 each); mafia win when they equal the rest (+2 each).
class MafiaLogic extends LocalGameLogic {
  final int players;
  late List<MafiaRole> roles;
  MafiaPhase phase = MafiaPhase.reveal;
  final Set<int> seen = {};
  late final Set<int> alive = {for (var i = 0; i < players; i++) i};
  final Set<int> acted = {};
  int? mafiaTarget, doctorSave, detectiveCheck;
  int killed = -1; // last night's victim, -1 for nobody
  bool saved = false;
  int day = 1;
  late final List<int?> votes = List.filled(players, null);
  int lastOut = -1;
  bool mafiaWins = false;

  MafiaLogic({this.players = 4, Random? random}) {
    final r = random ?? Random();
    final mafia = players >= 6 ? 2 : 1;
    roles = [
      for (var i = 0; i < mafia; i++) MafiaRole.mafia,
      MafiaRole.doctor,
      MafiaRole.detective,
      for (var i = mafia + 2; i < players; i++) MafiaRole.villager,
    ]..shuffle(r);
  }

  bool isMafia(int p) => roles[p] == MafiaRole.mafia;
  int get mafiaAlive => alive.where(isMafia).length;
  int get townAlive => alive.length - mafiaAlive;
  int get revealTurn =>
      [
        for (var i = 0; i < players; i++)
          if (!seen.contains(i)) i
      ].firstOrNull ??
      0;
  int get nightTurn =>
      [
        for (var i = 0; i < players; i++)
          if (alive.contains(i) && !acted.contains(i)) i
      ].firstOrNull ??
      0;
  int get votesIn => [
        for (final p in alive)
          if (votes[p] != null) p
      ].length;

  @override
  bool get finished => phase == MafiaPhase.done;
  @override
  List<int> get scores => [
        for (var i = 0; i < players; i++)
          mafiaWins ? (isMafia(i) ? 2 : 0) : (isMafia(i) ? 0 : 1)
      ];
  @override
  void update(int elapsedMs) {}

  void seenCard(int p) {
    if (forward('seen', [p])) return;
    if (phase != MafiaPhase.reveal || p < 0 || p >= players) return;
    seen.add(p);
    if (seen.length == players) _night();
    notifyListeners();
  }

  void _night() {
    phase = MafiaPhase.night;
    acted.clear();
    mafiaTarget = doctorSave = detectiveCheck = null;
  }

  /// A living player's night move. Villagers pass -1 (they just "sleep").
  void act(int p, int target) {
    if (forward('act', [p, target])) return;
    if (phase != MafiaPhase.night || !alive.contains(p) || acted.contains(p))
      return;
    final ok = alive.contains(target);
    switch (roles[p]) {
      case MafiaRole.mafia:
        if (!ok || isMafia(target)) return;
        mafiaTarget = target;
      case MafiaRole.doctor:
        if (!ok) return;
        doctorSave = target;
      case MafiaRole.detective:
        if (!ok || target == p) return;
        detectiveCheck = target;
      case MafiaRole.villager:
        break;
    }
    acted.add(p);
    if (alive.every(acted.contains)) _dawn();
    notifyListeners();
  }

  void _dawn() {
    final t = mafiaTarget;
    saved = t != null && t == doctorSave;
    killed = t != null && !saved ? t : -1;
    if (killed >= 0) alive.remove(killed);
    phase = _over() ? MafiaPhase.result : MafiaPhase.morning;
  }

  bool _over() {
    if (mafiaAlive == 0) {
      mafiaWins = false;
      return true;
    }
    if (mafiaAlive >= townAlive) {
      mafiaWins = true;
      return true;
    }
    return false;
  }

  void startVote() {
    if (forward('startVote', const [])) return;
    if (phase != MafiaPhase.morning) return;
    votes.fillRange(0, players, null);
    phase = MafiaPhase.vote;
    notifyListeners();
  }

  void accuse(int target) {
    if (forward('accuse', [target])) return;
    if (phase != MafiaPhase.vote || !alive.contains(target)) return;
    _out(target);
  }

  void vote(int voter, int target) {
    if (forward('vote', [voter, target])) return;
    if (phase != MafiaPhase.vote ||
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
    phase = _over() ? MafiaPhase.result : MafiaPhase.out;
    notifyListeners();
  }

  void nextNight() {
    if (forward('next', const [])) return;
    if (phase != MafiaPhase.out) return;
    day++;
    _night();
    notifyListeners();
  }

  void finish() {
    if (forward('finish', const [])) return;
    if (phase != MafiaPhase.result) return;
    phase = MafiaPhase.done;
    notifyListeners();
  }
}

final mafiaInfo = LocalGameInfo(
  id: 'mafia',
  title: 'Mafia',
  emoji: '🔪',
  color: const Color(0xFF8E0E2B),
  tagline: 'Trust no one after dark.',
  rules: const [
    'Secret roles: Mafia, Doctor, Detective and Villagers (2 mafia with 6 players).',
    'NIGHT: pass the phone round. Mafia picks a victim, the Doctor saves someone, the Detective checks someone, villagers sleep.',
    'DAY: hear who died, argue, and vote someone out.',
    'Town wins when every mafia is out (+1 each). Mafia wins when they equal everyone else (+2 each). 4 to 6 players.',
  ],
  scoreUnit: 'points',
  splitScreen: false,
  minPlayers: 4,
  maxPlayers: 6,
  online: RelaySpec<MafiaLogic>(
    create: (n) => MafiaLogic(players: n),
    save: (g) => {
      'roles': [for (final r in g.roles) r.index], 'phase': g.phase.index,
      'seen': g.seen.toList(), 'alive': g.alive.toList(), //
      'acted': g.acted.toList(), 'mt': g.mafiaTarget, 'ds': g.doctorSave,
      'dc': g.detectiveCheck, 'killed': g.killed, 'saved': g.saved, //
      'day': g.day, 'votes': g.votes, 'out': g.lastOut,
      'mafiaWins': g.mafiaWins,
    },
    load: (g, s, me) {
      g.roles = [for (final r in ints(s['roles'])) MafiaRole.values[r]];
      g.phase = MafiaPhase.values[asInt(s['phase'])];
      void setTo(Set<int> set, Object? v) => set
        ..clear()
        ..addAll(ints(v));
      setTo(g.seen, s['seen']);
      setTo(g.alive, s['alive']);
      setTo(g.acted, s['acted']);
      g.mafiaTarget = nInt(s['mt']);
      g.doctorSave = nInt(s['ds']);
      g.detectiveCheck = nInt(s['dc']);
      g.killed = asInt(s['killed']);
      g.saved = s['saved'] == true;
      g.day = asInt(s['day']);
      g.votes.setAll(0, nInts(s['votes']));
      g.lastOut = asInt(s['out']);
      g.mafiaWins = s['mafiaWins'] == true;
    },
    apply: (g, from, name, a) {
      switch (name) {
        case 'seen' when asInt(a[0]) == from:
          g.seenCard(from);
        case 'act' when asInt(a[0]) == from:
          g.act(from, asInt(a[1]));
        case 'startVote':
          g.startVote();
        case 'vote' when asInt(a[0]) == from:
          g.vote(from, asInt(a[1]));
        case 'next':
          g.nextNight();
        case 'finish':
          g.finish();
      }
    },
    view: (context, g, players, me) =>
        _MafiaView(players: players, g: g, me: me),
  ),
  play: (players, onFinished) => TickingPlay<MafiaLogic>(
    create: () => MafiaLogic(players: players.length),
    onFinished: onFinished,
    builder: (context, g) => _MafiaView(players: players, g: g),
  ),
);

class _MafiaView extends StatefulWidget {
  final List<GpPlayer> players;
  final MafiaLogic g;
  final int? me;
  const _MafiaView({required this.players, required this.g, this.me});
  @override
  State<_MafiaView> createState() => _MafiaViewState();
}

/// Drawn role emblems (no emoji): mask, medical cross, magnifier, house.
GameIcons _roleIcon(MafiaRole r) => switch (r) {
      MafiaRole.mafia => GameIcons.mask,
      MafiaRole.doctor => GameIcons.medical,
      MafiaRole.detective => GameIcons.magnifier,
      MafiaRole.villager => GameIcons.home,
    };

/// The sky behind the night and day phases: dark navy with a moon, or a warm day.
class _Sky extends StatelessWidget {
  final bool night;
  final Widget child;
  const _Sky({required this.night, required this.child});
  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: Motion.of(context, const Duration(milliseconds: 700)),
        child: ClipRRect(
          key: ValueKey(night),
          borderRadius: Radii.rBoard,
          child: Stack(children: [
            Positioned.fill(
                child: CustomPaint(
                    painter: SkyPainter(
                        time: night ? SkyTime.night : SkyTime.day,
                        hills: true,
                        horizon: 0.86,
                        clouds: !night))),
            Positioned.fill(
                child: DecoratedBox(
                    decoration: BoxDecoration(
                        color: (night ? NeonPalette.bgBottom : Colors.black)
                            .withValues(alpha: night ? 0.35 : 0.12)))),
            Padding(padding: const EdgeInsets.all(12), child: child),
          ]),
        ),
      );
}

class _MafiaViewState extends State<_MafiaView> {
  bool _shown = false;
  int? _pick; // night choice before confirming
  int? _for; // whose choice _pick is

  MafiaLogic get g => widget.g;
  List<GpPlayer> get players => widget.players;
  Set<int> get dead => {
        for (var i = 0; i < players.length; i++)
          if (!g.alive.contains(i)) i
      };

  Widget _roleCard(int p) {
    final role = g.roles[p];
    final partners = [
      for (var i = 0; i < players.length; i++)
        if (i != p && g.isMafia(i)) players[i].name
    ];
    return PromptCard(
      header: 'You are',
      text: role.title,
      icon: _roleIcon(role),
      dark: role == MafiaRole.mafia,
      footer: role.about +
          (role == MafiaRole.mafia && partners.isNotEmpty
              ? '\nYour partner: ${partners.join(', ')}'
              : ''),
      color: role.color,
    );
  }

  /// The night move for player [p]: a target picker (or "sleep" for villagers).
  Widget _nightPanel(int p) {
    if (_for != p) {
      _for = p;
      _pick = null;
    }
    final role = g.roles[p];
    final prompt = switch (role) {
      MafiaRole.mafia => 'Who do you eliminate tonight?',
      MafiaRole.doctor => 'Who do you save tonight?',
      MafiaRole.detective => 'Who do you investigate?',
      MafiaRole.villager =>
        "You're a villager. Nothing to do tonight: just sleep.",
    };
    final disabled = {
      ...dead,
      if (role == MafiaRole.mafia) ...[
        for (var i = 0; i < players.length; i++)
          if (g.isMafia(i)) i
      ],
      if (role == MafiaRole.detective) p,
    };
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        GameIcon(_roleIcon(role), size: 28, color: nameColor(role.color)),
        const SizedBox(width: 8),
        Text(role.title,
            style: TextStyle(
                fontFamily: Fonts.display,
                color: nameColor(role.color),
                fontSize: 26)),
      ]),
      const SizedBox(height: 6),
      Text(prompt,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontFamily: Fonts.body,
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16)),
      const SizedBox(height: 14),
      if (role == MafiaRole.villager)
        const GameIcon(GameIcons.moon, size: 64, color: Color(0xFFFFF3C4)),
      if (role != MafiaRole.villager)
        PlayerPicker(
            players: players,
            disabled: disabled,
            highlight: _pick,
            onPick: (i) => setState(() => _pick = i)),
      if (role == MafiaRole.detective && _pick != null) ...[
        const SizedBox(height: 14),
        TurnBanner(
          text: g.isMafia(_pick!)
              ? '${players[_pick!].name} IS MAFIA!'
              : '${players[_pick!].name} is not mafia',
          color: role.color,
          kind:
              g.isMafia(_pick!) ? TurnBannerKind.miss : TurnBannerKind.success,
          icon: GameIcons.magnifier,
          compact: true,
        ),
      ],
    ]);
  }

  VoidCallback? _confirm(int p) {
    final needsPick = g.roles[p] != MafiaRole.villager;
    if (needsPick && _pick == null) return null;
    return () {
      final target = _pick ?? -1;
      setState(() {
        _shown = false;
        _pick = null;
      });
      g.act(p, target);
    };
  }

  @override
  Widget build(BuildContext context) {
    ResultScope.of(context)?.subtitle = g.phase.index >= MafiaPhase.result.index
        ? (g.mafiaWins ? 'The mafia took over' : 'The town is safe')
        : null;
    return MomentWatcher<MafiaPhase>(
      value: g.phase,
      onChange: (fx, _, now) {
        if (now == MafiaPhase.night)
          fx?.announce('NIGHT ${g.day}',
              sub: 'The town sleeps…', color: const Color(0xFFCFD6FF));
        if (now == MafiaPhase.morning) {
          if (g.killed >= 0) {
            keyMoment(fx, 'MORNING',
                sub: '${players[g.killed].name} was taken',
                sound: 'lose',
                color: Brand.gold);
          } else {
            keyMoment(fx, 'MORNING', sub: 'Nobody died', sound: 'coin');
          }
        }
        if (now == MafiaPhase.result) {
          if (g.mafiaWins) {
            keyMoment(fx, 'MAFIA WINS!',
                sound: 'lose', color: const Color(0xFFFF8E8B), shake: true);
          } else {
            keyMoment(fx, 'TOWN WINS!', sound: 'win', confetti: true);
          }
        }
      },
      child: _phase(context),
    );
  }

  Widget _phase(BuildContext context) {
    final me = widget.me;
    switch (g.phase) {
      case MafiaPhase.reveal:
        if (me != null) {
          final ready = g.seen.contains(me);
          return PartyFrame(
            title: 'Mafia',
            subtitle: ready
                ? 'Waiting for the others (${g.seen.length}/${players.length})'
                : 'Your role · keep it secret!',
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                      child: Center(
                          child: SingleChildScrollView(child: _roleCard(me)))),
                  GoldButton(ready ? 'Ready' : "I'm ready",
                      icon: ready ? GameIcons.check : null,
                      height: 58,
                      onPressed: ready ? null : () => g.seenCard(me)),
                ]),
          );
        }
        final p = g.revealTurn;
        return PartyFrame(
          title: 'Mafia',
          subtitle:
              '${g.seen.length} of ${players.length} have seen their role',
          child: PassAndReveal(
            player: players[p],
            revealed: _shown,
            onReveal: () => setState(() => _shown = true),
            onDone: () {
              setState(() => _shown = false);
              g.seenCard(p);
            },
            secret: _roleCard(p),
          ),
        );
      case MafiaPhase.night:
        if (me != null) {
          if (!g.alive.contains(me))
            return PartyFrame(
                title: 'Mafia',
                subtitle: 'Night ${g.day}',
                child: const _Sky(
                    night: true,
                    child: WaitingNote("You're out. The town sleeps…")));
          if (g.acted.contains(me))
            return PartyFrame(
                title: 'Mafia',
                subtitle: 'Night ${g.day}',
                child: _Sky(
                    night: true,
                    child: WaitingNote(
                        'Waiting for the night to end (${g.acted.length}/${g.alive.length})')));
          return PartyFrame(
            title: 'Mafia',
            subtitle: 'Night ${g.day} · keep your screen hidden',
            child: _Sky(
              night: true,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                        child: Center(
                            child:
                                SingleChildScrollView(child: _nightPanel(me)))),
                    GoldButton(
                        g.roles[me] == MafiaRole.villager ? 'Sleep' : 'Confirm',
                        icon: g.roles[me] == MafiaRole.villager
                            ? GameIcons.moon
                            : GameIcons.check,
                        height: 56,
                        onPressed: _confirm(me)),
                  ]),
            ),
          );
        }
        final p = g.nightTurn;
        return PartyFrame(
          title: 'Mafia',
          subtitle: 'Night ${g.day} · everyone takes a turn',
          child: _Sky(
            night: true,
            child: PassAndReveal(
              player: players[p],
              revealed: _shown,
              onReveal: () => setState(() => _shown = true),
              onDone: _confirm(p),
              doneLabel: g.roles[p] == MafiaRole.villager
                  ? 'Sleep · hide & pass'
                  : 'Confirm · hide & pass',
              secret: _nightPanel(p),
            ),
          ),
        );
      case MafiaPhase.morning:
        final victim = g.killed >= 0 ? players[g.killed] : null;
        final check = me != null &&
                g.roles[me] == MafiaRole.detective &&
                g.detectiveCheck != null
            ? '\n\n(Only you see this: ${players[g.detectiveCheck!].name} ${g.isMafia(g.detectiveCheck!) ? 'IS mafia' : 'is not mafia'})'
            : '';
        return PartyFrame(
          title: 'Mafia',
          subtitle: 'Day ${g.day}',
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: _Sky(
                night: false,
                child: Center(
                  child: SingleChildScrollView(
                    child: victim != null
                        ? PromptCard(
                            header: 'Last night',
                            text: '${victim.name} was taken in the night',
                            icon: GameIcons.mask,
                            dark: true,
                            footer:
                                'They were a ${g.roles[g.killed].title}.$check',
                            color: StatusColors.danger)
                        : PromptCard(
                            header: 'Last night',
                            text: g.saved
                                ? 'The doctor saved a life!'
                                : 'Nobody died',
                            icon: g.saved ? GameIcons.medical : GameIcons.sun,
                            footer: 'A peaceful night.$check',
                            color: StatusColors.success),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            GoldButton('Discuss, then vote',
                icon: GameIcons.speech, height: 58, onPressed: g.startVote),
          ]),
        );
      case MafiaPhase.vote:
        if (me != null) {
          final canVote = g.alive.contains(me);
          return PartyFrame(
            title: 'Who is mafia?',
            subtitle: canVote
                ? 'Your vote · ${g.votesIn}/${g.alive.length} voted'
                : "You're out: watch the vote",
            child: Center(
              child: SingleChildScrollView(
                child: PlayerPicker(
                    players: players,
                    disabled: {...dead, me},
                    highlight: g.votes[me],
                    onPick: canVote ? (i) => g.vote(me, i) : null,
                    notes: {for (final i in dead) i: 'OUT'}),
              ),
            ),
          );
        }
        return PartyFrame(
          title: 'Who is mafia?',
          subtitle: 'Agree, then tap who to vote out',
          child: Center(
              child: SingleChildScrollView(
                  child: PlayerPicker(
                      players: players,
                      disabled: dead,
                      onPick: g.accuse,
                      notes: {for (final i in dead) i: 'OUT'}))),
        );
      case MafiaPhase.out:
        return PartyFrame(
          title: 'Mafia',
          subtitle: 'The town has spoken',
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: g.lastOut < 0
                      ? const PromptCard(
                          header: 'Tie vote',
                          text: 'Nobody is out',
                          icon: GameIcons.people)
                      : PromptCard(
                          header: '${players[g.lastOut].name} is out',
                          text: 'They were ${g.roles[g.lastOut].title}',
                          icon: _roleIcon(g.roles[g.lastOut]),
                          dark: g.roles[g.lastOut] == MafiaRole.mafia,
                          color: g.roles[g.lastOut].color),
                ),
              ),
            ),
            GoldButton('Night falls…',
                icon: GameIcons.moon, height: 58, onPressed: g.nextNight),
          ]),
        );
      case MafiaPhase.result:
      case MafiaPhase.done:
        final mafia = [
          for (var i = 0; i < players.length; i++)
            if (g.isMafia(i)) players[i].name
        ];
        return PartyFrame(
          title: g.mafiaWins ? 'Mafia wins' : 'Town wins',
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(children: [
                    TurnBanner(
                      text: g.mafiaWins
                          ? 'The mafia took over'
                          : 'The town is safe',
                      sub: 'Mafia: ${mafia.join(' & ')}',
                      color: Brand.gold,
                      kind: g.mafiaWins
                          ? TurnBannerKind.miss
                          : TurnBannerKind.success,
                      icon: g.mafiaWins ? GameIcons.mask : GameIcons.home,
                    ),
                    const SizedBox(height: 12),
                    // Every role, revealed.
                    Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (var i = 0; i < players.length; i++)
                            Container(
                              width: 150,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: g.roles[i] == MafiaRole.mafia
                                    ? const Color(0xFF241B48)
                                    : Colors.white.withValues(alpha: 0.06),
                                borderRadius: Radii.rLg,
                                border: Border.all(
                                    color:
                                        g.roles[i].color.withValues(alpha: 0.7),
                                    width: 1.5),
                              ),
                              child: Row(children: [
                                GameIcon(_roleIcon(g.roles[i]),
                                    size: 26,
                                    color: nameColor(g.roles[i].color)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(players[i].name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontFamily: Fonts.body,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 13,
                                                color: Colors.white)),
                                        Text(g.roles[i].title,
                                            style: TextStyle(
                                                fontFamily: Fonts.body,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 11,
                                                letterSpacing: 1,
                                                color: nameColor(
                                                    g.roles[i].color))),
                                      ]),
                                ),
                              ]),
                            ),
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
