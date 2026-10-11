import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/audio/game_audio.dart';
import '../../core/ui/components.dart';
import '../guess_person/models/gp_player.dart';
import '../local_games/shell/how_to_play.dart' show RuleStep;
import '../local_games/shell/local_game_info.dart';
import '../local_games/shell/result_screen.dart';
import 'rmcs_game.dart';
import 'rmcs_role.dart';
import 'widgets/role_card.dart';
import 'widgets/rmcs_widgets.dart';

/// How this game appears on the shared result screen (not a shell game: it has its own flow).
final _resultInfo = LocalGameInfo(
  id: 'raja_mantri',
  title: 'Raja Mantri',
  emoji: '',
  color: const Color(0xFF8A1C3A),
  tagline: 'Can the Mantri catch the Chor?',
  rules: const [],
  scoreUnit: 'points',
  splitScreen: false,
  minPlayers: 4,
  maxPlayers: 4,
  play: (_, __) => const SizedBox.shrink(),
);

/// Setup (spec 4.13, styled like the game intro): the four roles, the rules as icon steps,
/// four names, how many rounds, then Deal the cards.
class RmcsMenuScreen extends StatefulWidget {
  const RmcsMenuScreen({super.key});
  @override
  State<RmcsMenuScreen> createState() => _RmcsMenuScreenState();
}

class _RmcsMenuScreenState extends State<RmcsMenuScreen> {
  static const roundChoices = [5, 10, 15, 20, 30];
  final _names = [for (var i = 0; i < 4; i++) TextEditingController()];
  int _rounds = 20;

  @override
  void dispose() {
    for (final c in _names) {
      c.dispose();
    }
    super.dispose();
  }

  void _start() {
    final players = [
      for (var i = 0; i < 4; i++) GpPlayer(name: _names[i].text.trim().isEmpty ? 'Player ${i + 1}' : _names[i].text.trim(), color: gpPlayerColors[i]),
    ];
    Navigator.push(context, MaterialPageRoute(builder: (_) => RmcsGameScreen(game: RmcsGame(players: players, totalRounds: _rounds))));
  }

  @override
  Widget build(BuildContext context) {
    return TokenScope(
      flat: false,
      child: Scaffold(
        body: RmcsBackground(
          child: SafeArea(
            child: Column(children: [
              Expanded(
                child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 16), children: [
                  PageHeader(
                    label: 'Raja Mantri Chor Sipahi',
                    title: 'One phone',
                    trailing: RoundButton(icon: GameIcons.settings, label: 'Settings', onPressed: () => showSettingsSheet(context)),
                  ),
                  const SizedBox(height: 6),
                  Text('4 PLAYERS · $_rounds ROUNDS · ONE PHONE', textAlign: TextAlign.center, style: const TextStyle(fontFamily: Fonts.body, color: NeonPalette.label, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.6)),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 150,
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      for (final r in RmcsRole.values) Flexible(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: RoleCard(role: r, faceUp: true))),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  _rules(),
                  const SizedBox(height: 14),
                  const Text('PLAYERS', style: TextStyle(fontFamily: Fonts.body, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.82, color: Colors.white)),
                  const SizedBox(height: 8),
                  for (var i = 0; i < 4; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        PlayerBadge(index: i, size: 30, initial: 'P'),
                        const SizedBox(width: 10),
                        Expanded(child: KitField(controller: _names[i], hint: 'Player ${i + 1}', capitalization: TextCapitalization.words, maxLength: 12)),
                      ]),
                    ),
                  const SizedBox(height: 6),
                  _roundPicker(),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 22),
                child: GoldButton('Deal the cards', height: 58, fontSize: 24, onPressed: _start),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _roundPicker() => Container(
        padding: const EdgeInsets.all(14),
        decoration: Skin.surface(tint: RmcsColors.panel, radius: Radii.button, depth: 0.8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('ROUNDS', style: TextStyle(fontFamily: Fonts.body, color: NeonPalette.label, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.6)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final n in roundChoices) KitChip('$n', selected: n == _rounds, onTap: () => setState(() => _rounds = n)),
          ]),
          const SizedBox(height: 6),
          Text(_rounds <= 5 ? 'Quick game · about 5 minutes' : _rounds >= 30 ? 'Marathon · about 30 minutes' : 'About $_rounds minutes',
              style: const TextStyle(fontFamily: Fonts.body, color: NeonPalette.textMuted, fontWeight: FontWeight.w800, fontSize: 12)),
        ]),
      );

  Widget _rules() {
    final rules = [
      'Each round the 4 cards are shuffled and dealt. Pass the phone so everyone secretly sees their own card.',
      'The Raja is revealed (+1000 every round), then the Mantri steps forward.',
      'The Mantri has 10 seconds to point at the Chor. Right: Mantri +500. Wrong or too slow: Chor +500.',
      'The Sipahi always gets +300. Highest total after $_rounds rounds wins!',
    ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: Skin.surface(tint: RmcsColors.panel, radius: Radii.button, depth: 0.8),
      child: Column(children: [
        for (var i = 0; i < rules.length; i++) ...[if (i > 0) const SizedBox(height: 8), RuleStep(index: i, rule: rules[i])],
      ]),
    );
  }
}

/// The table: round, a headline for what's happening, four seats on the felt and the
/// action button. Results go to the shared result screen.
class RmcsGameScreen extends StatefulWidget {
  final RmcsGame game;
  const RmcsGameScreen({super.key, required this.game});
  @override
  State<RmcsGameScreen> createState() => _RmcsGameScreenState();
}

class _RmcsGameScreenState extends State<RmcsGameScreen> {
  RmcsGame get g => widget.game;
  Timer? _clock;
  Timer? _mantriTimer;
  bool _mantriShown = false;
  RmcsPhase? _lastPhase;
  final _fx = GlobalKey<GameFeedback>();

  @override
  void initState() {
    super.initState();
    g.addListener(_onChange);
    _clock = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (g.phase == RmcsPhase.guessing) {
        g.tick();
        if (mounted) setState(() {});
      }
    });
  }

  void _onChange() {
    if (g.phase != _lastPhase) {
      _lastPhase = g.phase;
      if (g.phase == RmcsPhase.rajaReveal) {
        // Raja first, then the Mantri a moment later.
        _mantriShown = false;
        _mantriTimer?.cancel();
        _mantriTimer = Timer(const Duration(milliseconds: 1100), () {
          if (mounted) setState(() => _mantriShown = true);
        });
        haptic(HapticWeight.medium);
        _fx.currentState?.announce('RAJA!', sub: '${_n(g.raja)} +1000');
      }
      if (g.phase == RmcsPhase.reveal) {
        haptic(HapticWeight.heavy);
        GameAudio.sfx(g.caught ? 'coin' : 'lose');
        if (g.caught) {
          _fx.currentState?.announce('CAUGHT!', sub: 'The Mantri found the Chor');
        } else {
          _fx.currentState?.announce('ESCAPED!', sub: 'The Chor gets away', color: const Color(0xFFB57BFF));
          _fx.currentState?.shake();
        }
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    g.removeListener(_onChange);
    _clock?.cancel();
    _mantriTimer?.cancel();
    super.dispose();
  }

  Future<void> _leave() async {
    final ok = await confirmAction(context, title: 'Leave the game?', message: 'Scores for this game will be lost.', confirm: 'Leave', cancel: 'Stay', emoji: null);
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return TokenScope(
      flat: false,
      child: PopScope(
        canPop: g.phase == RmcsPhase.finished,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _leave();
        },
        child: Scaffold(
          body: RmcsBackground(
            child: SafeArea(
              child: g.phase == RmcsPhase.finished ? _finished() : FeedbackLayer(key: _fx, child: _table()),
            ),
          ),
        ),
      ),
    );
  }

  Widget _table() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 12),
      child: Column(children: [
        Row(children: [
          RoundButton(icon: GameIcons.close, label: 'Leave game', onPressed: _leave),
          Expanded(
            child: Semantics(
              header: true,
              child: Column(children: [
                const Text('RAJA MANTRI', style: TextStyle(fontFamily: Fonts.body, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.76, color: NeonPalette.label)),
                Text('Round ${g.round} / ${g.totalRounds}', style: const TextStyle(fontFamily: Fonts.display, fontSize: 20, color: Colors.white)),
              ]),
            ),
          ),
          RoundButton(icon: GameIcons.settings, label: 'Settings', onPressed: () => showSettingsSheet(context)),
        ]),
        const SizedBox(height: 8),
        _headline(),
        const SizedBox(height: 8),
        Expanded(
          child: g.phase == RmcsPhase.dealing ? ShuffleDeal(key: ValueKey('deal${g.round}'), onDone: g.dealt) : SeatGrid(seats: [for (var i = 0; i < 4; i++) _seat(i)]),
        ),
        const SizedBox(height: 10),
        _actions(),
      ]),
    );
  }

  String _n(int i) => g.players[i].name;

  Widget _headline() {
    switch (g.phase) {
      case RmcsPhase.dealing:
        return const RmcsHeadline(title: 'Shuffling and dealing…', subtitle: 'Four cards: Raja, Mantri, Sipahi and Chor.', icon: GameIcons.restart);
      case RmcsPhase.peek:
        final who = _n(g.peekIndex);
        return RmcsHeadline(
          title: g.peekShown ? 'Remember your card, $who!' : 'Pass the phone to $who',
          subtitle: g.peekShown ? 'Then hide it and pass the phone on.' : 'Everyone else, look away! Tap your card to see it.',
          icon: g.peekShown ? GameIcons.eye : GameIcons.people,
        );
      case RmcsPhase.rajaReveal:
        return RmcsHeadline(
          title: '${_n(g.raja)} is the RAJA!',
          subtitle: _mantriShown ? '${_n(g.mantri)} is the Mantri. Find the Chor: ${_n(g.suspects[0])} or ${_n(g.suspects[1])}?' : 'Bow to the king… +1000 points!',
          icon: GameIcons.crown,
        );
      case RmcsPhase.guessing:
        return RmcsHeadline(
          title: '${_n(g.mantri)}, who is the CHOR?',
          subtitle: 'Tap ${_n(g.suspects[0])} or ${_n(g.suspects[1])}.',
          icon: GameIcons.scroll,
          trailing: CountdownRing(msLeft: g.guessMsLeft, totalMs: g.guessMs, size: 52),
        );
      case RmcsPhase.reveal:
        return ResultBanner(caught: g.caught, timedOut: g.timedOut);
      case RmcsPhase.finished:
        return const SizedBox.shrink();
    }
  }

  Widget _seat(int i) {
    final role = g.roles[i];
    final player = g.players[i];
    var faceUp = false;
    String? badge;
    var badgeColor = RmcsColors.gold;
    var highlight = false;
    VoidCallback? onTap;
    var dim = false;
    var flip = const Duration(milliseconds: 650);

    switch (g.phase) {
      case RmcsPhase.dealing:
        break;
      case RmcsPhase.peek:
        final mine = i == g.peekIndex;
        faceUp = mine && g.peekShown;
        highlight = mine;
        dim = !mine;
        if (mine && !g.peekShown) {
          badge = 'TAP TO REVEAL';
          onTap = g.showPeek;
        }
      case RmcsPhase.rajaReveal:
        faceUp = role == RmcsRole.raja || (role == RmcsRole.mantri && _mantriShown);
        highlight = faceUp;
      case RmcsPhase.guessing:
        faceUp = role == RmcsRole.raja || role == RmcsRole.mantri;
        if (!faceUp) {
          highlight = true;
          badge = 'TAP TO ACCUSE';
          badgeColor = StatusColors.danger;
          onTap = () {
            haptic(HapticWeight.selection);
            g.accuse(i);
          };
        } else {
          dim = role == RmcsRole.raja;
        }
      case RmcsPhase.reveal:
        faceUp = true;
        // The accused card turns first, the other suspect a beat later.
        if (role == RmcsRole.sipahi || role == RmcsRole.chor) flip = Duration(milliseconds: i == g.accused ? 600 : 1100);
        if (i == g.accused) {
          badge = 'ACCUSED';
          badgeColor = Colors.white;
        } else if (role == RmcsRole.chor) {
          badge = 'ESCAPED!';
          badgeColor = StatusColors.danger;
        }
        if (role == RmcsRole.chor) highlight = true;
        if (i == g.accused && g.caught) {
          badge = 'CAUGHT!';
          badgeColor = StatusColors.success;
        }
      case RmcsPhase.finished:
        faceUp = true;
    }
    return RmcsSeat(
      name: player.name,
      color: player.color,
      seat: i,
      role: role,
      faceUp: faceUp,
      score: g.scores[i],
      delta: g.phase == RmcsPhase.reveal ? g.lastPoints[i] : null,
      badge: badge,
      badgeColor: badgeColor,
      highlight: highlight,
      dim: dim,
      flipDuration: flip,
      onTap: onTap,
    );
  }

  Widget _actions() {
    switch (g.phase) {
      case RmcsPhase.dealing:
      case RmcsPhase.guessing:
        return const SizedBox(height: 58);
      case RmcsPhase.peek:
        if (!g.peekShown) return const SizedBox(height: 58);
        final last = g.peekIndex == RmcsGame.playerCount - 1;
        return GoldButton(last ? 'Hide card · reveal the Raja' : 'Hide card · pass to ${_n(g.peekIndex + 1)}', icon: GameIcons.eye, height: 58, fontSize: 19, onPressed: g.passPeek);
      case RmcsPhase.rajaReveal:
        return GoldButton(_mantriShown ? 'Mantri: find the Chor (10s)' : '…', icon: GameIcons.clock, height: 58, fontSize: 19, onPressed: _mantriShown ? g.startGuessing : null);
      case RmcsPhase.reveal:
        return GoldButton(g.isLastRound ? 'See final results' : 'Next round (${g.round + 1}/${g.totalRounds})', icon: GameIcons.forward, height: 58, fontSize: 19, onPressed: g.nextRound);
      case RmcsPhase.finished:
        return const SizedBox.shrink();
    }
  }

  /// The shared result screen: the winner, standings with each player's total.
  Widget _finished() {
    final players = [for (var i = 0; i < 4; i++) GpPlayer(name: _n(i), color: g.players[i].color, score: g.scores[i])];
    final extras = ResultExtras()
      ..subtitle = 'after ${g.totalRounds} rounds'
      ..hero = ((_) => SizedBox(
            height: 130,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (final r in RmcsRole.values) Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: RoleCard(role: r, faceUp: true)),
            ]),
          ));
    return ResultScreen(
      game: _resultInfo,
      players: players,
      extras: extras,
      onRematch: g.restart,
      onChangePlayers: () => Navigator.pop(context),
      onExit: () => Navigator.pop(context),
    );
  }
}
