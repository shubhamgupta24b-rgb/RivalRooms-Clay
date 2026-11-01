import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/ui/components.dart';
import '../../guess_person/models/gp_player.dart';
import '../../guess_person/widgets/gp_theme.dart';
import 'local_game_info.dart';
import 'local_game_shell.dart' show PauseButton;

/// Runs a "take turns" match: each player in order gets the whole screen for [durationMs];
/// computer players ([botSeats]) take their turn instantly. Reports everyone's scores at the end.
class TurnsPlay extends StatefulWidget {
  final TurnsSpec spec;
  final List<GpPlayer> players;
  final Set<int> botSeats;
  final int durationMs;
  final void Function(List<int> scores) onFinished;
  final Random? random;
  const TurnsPlay(
      {super.key,
      required this.spec,
      required this.players,
      required this.botSeats,
      required this.durationMs,
      required this.onFinished,
      this.random});

  @override
  State<TurnsPlay> createState() => _TurnsPlayState();
}

enum _Step { ready, playing, scored }

/// The length of each turn, for [TurnBar]'s timer ring.
class _TurnLength extends InheritedWidget {
  final int ms;
  const _TurnLength({required this.ms, required super.child});
  static int? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_TurnLength>()?.ms;
  @override
  bool updateShouldNotify(_TurnLength old) => old.ms != ms;
}

class _TurnsPlayState extends State<TurnsPlay> {
  late final List<int?> scores = List.filled(widget.players.length, null);
  late final Random rng = widget.random ?? Random();
  int index = 0;
  var step = _Step.ready;

  @override
  void initState() {
    super.initState();
    _skipBots();
  }

  /// Computer players take their turns straight away (no need to watch them).
  void _skipBots() {
    while (index < widget.players.length && widget.botSeats.contains(index)) {
      scores[index] = widget.spec.simulate(widget.durationMs, rng);
      index++;
    }
    if (index >= widget.players.length) _finish();
  }

  void _finish() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onFinished([for (final s in scores) s ?? 0]);
      });

  void _done(int score) {
    if (!mounted || step != _Step.playing) return;
    haptic(HapticWeight.medium);
    setState(() {
      scores[index] = score;
      step = _Step.scored;
    });
  }

  void _next() => setState(() {
        index++;
        step = _Step.ready;
        _skipBots();
      });

  @override
  Widget build(BuildContext context) {
    if (index >= widget.players.length) return const SizedBox.shrink();
    final p = widget.players[index];
    return AnimatedSwitcher(
      duration: Motion.of(context, Motion.normal),
      child: switch (step) {
        _Step.playing => _TurnLength(
            ms: widget.durationMs,
            child: KeyedSubtree(
                key: ValueKey('turn$index'),
                child: widget.spec.play(p, widget.durationMs, _done))),
        // The hand-off card: only who's next and the scores so far, nothing from the last turn's screen.
        _Step.ready => _Card(
            key: ValueKey('ready$index'),
            player: p,
            title: index == 0 ? '${p.whose} TURN FIRST' : 'PASS THE PHONE TO',
            big: p.name,
            line:
                '${_time(widget.durationMs)} on the whole screen. Everyone else, just watch!',
            button: 'START',
            onTap: () => setState(() => step = _Step.playing),
            scores: scores,
            players: widget.players,
            current: index,
          ),
        _Step.scored => _Card(
            key: ValueKey('scored$index'),
            player: p,
            title: '${p.whose} SCORE',
            big: '${scores[index]}',
            line: _nextLine(),
            button: _hasNextPerson() ? 'NEXT PLAYER' : 'SEE RESULTS',
            onTap: _next,
            scores: scores,
            players: widget.players,
            current: index,
            scored: true,
          ),
      },
    );
  }

  bool _hasNextPerson() => [
        for (var i = index + 1; i < widget.players.length; i++) i
      ].any((i) => !widget.botSeats.contains(i));

  String _nextLine() {
    for (var i = index + 1; i < widget.players.length; i++) {
      if (!widget.botSeats.contains(i))
        return 'Next up: ${widget.players[i].name}';
    }
    return widget.botSeats.isEmpty
        ? 'That was the last turn!'
        : 'The computer plays its turns now.';
  }

  static String _time(int ms) {
    final s = ms ~/ 1000;
    return s % 60 == 0
        ? '${s ~/ 60} min'
        : '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }
}

class _Card extends StatelessWidget {
  final GpPlayer player;
  final String title, big, line, button;
  final VoidCallback onTap;
  final List<int?> scores;
  final List<GpPlayer> players;
  final int current;
  final bool scored;
  const _Card({
    super.key,
    required this.player,
    required this.title,
    required this.big,
    required this.line,
    required this.button,
    required this.onTap,
    required this.scores,
    required this.players,
    required this.current,
    this.scored = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final c = player.color;
    return Padding(
      padding: const EdgeInsets.all(Space.m),
      child: Column(children: [
        const Align(alignment: Alignment.centerLeft, child: PauseButton()),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: AppCard(
                  tint: c,
                  padding: const EdgeInsets.fromLTRB(
                      Space.xl, Space.xl, Space.xl, Space.l),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Stack(clipBehavior: Clip.none, children: [
                      PlayerAvatar(name: player.name, color: c, size: 96),
                      Positioned(
                          right: -14,
                          bottom: -6,
                          child: ExcludeSemantics(
                              child: GameIcon(
                                  scored ? GameIcons.star : GameIcons.forward,
                                  size: 34,
                                  color: Brand.gold))),
                    ]),
                    const SizedBox(height: Space.l),
                    Text(title,
                        textAlign: TextAlign.center, style: t.styles.label),
                    const SizedBox(height: Space.xs),
                    Semantics(
                      liveRegion: true,
                      child: FittedBox(
                        child: Text(big.toUpperCase(),
                            style: (scored
                                    ? t.styles.scoreLarge
                                    : t.styles.display)
                                .copyWith(
                                    color: Color.lerp(c, Colors.white, 0.35),
                                    fontSize: scored ? 60 : 40)),
                      ),
                    ),
                    const SizedBox(height: Space.s),
                    Text(line,
                        textAlign: TextAlign.center, style: t.styles.body),
                    const SizedBox(height: Space.xl),
                    GpButton(button,
                        icon: Icons.play_arrow_rounded,
                        color: c,
                        textColor: Colors.white,
                        onPressed: onTap),
                    const SizedBox(height: Space.xl),
                    // Scores so far.
                    Wrap(
                        alignment: WrapAlignment.center,
                        spacing: Space.s,
                        runSpacing: Space.s,
                        children: [
                          for (var i = 0; i < players.length; i++)
                            PlayerChip(
                              name: players[i].name,
                              color: players[i].color,
                              score: scores[i],
                              suffix: scores[i] == null ? '—' : null,
                              active: i == current,
                            ),
                        ]),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Top bar for a player's full-screen turn: who's playing, score and a timer ring.
class TurnBar extends StatelessWidget {
  final GpPlayer player;
  final int score;
  final int secondsLeft;
  const TurnBar(
      {super.key,
      required this.player,
      required this.score,
      required this.secondsLeft});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final total = (_TurnLength.of(context) ?? 60000) / 1000;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.xs, Space.xs, Space.s, Space.xs),
      child: Row(children: [
        const PauseButton(),
        const SizedBox(width: Space.xs),
        Flexible(
            child: PlayerChip(
                name: player.name, color: player.color, active: true)),
        const Spacer(),
        Semantics(
          label: 'Score $score',
          excludeSemantics: true,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: Space.m, vertical: Space.xs),
            decoration: Skin.pill(),
            child: Text('$score', style: t.styles.score),
          ),
        ),
        const SizedBox(width: Space.s),
        TimerRing(
          fraction: secondsLeft / total,
          label: secondsLeft >= 60
              ? '${secondsLeft ~/ 60}:${(secondsLeft % 60).toString().padLeft(2, '0')}'
              : '$secondsLeft',
          urgent: secondsLeft <= 10,
          color: player.color,
          size: 46,
        ),
      ]),
    );
  }
}
