import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/ui/components.dart';
import '../../guess_person/models/gp_player.dart';
import '../../../core/audio/game_audio.dart';
import '../../../core/ui/materials/materials.dart';
import '../shell/game_hud.dart' show possessive;
import '../shell/local_game_shell.dart' show ResultScope;
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import 'party_widgets.dart';

enum TurnPhase { ready, playing, turnEnd, done }

/// Timed word turns (Dumb Charades, Heads Up): each player in turn gets [turnMs] to get
/// through as many words as possible. GOT IT scores a point for that player; SKIP moves on.
class WordTurnsLogic extends LocalGameLogic {
  final int players;
  final int turnsEach;
  final int turnMs;
  final List<String> deck;
  TurnPhase phase = TurnPhase.ready;
  int turn = 0; // how many turns have been played
  int word = 0; // position in the deck
  int now = 0, deadline = 0;
  late final List<int> score = List.filled(players, 0);
  int gotThisTurn = 0;

  WordTurnsLogic(
      {required this.players,
      required List<String> words,
      this.turnsEach = 2,
      this.turnMs = 60000,
      Random? random})
      : deck = [...words]..shuffle(random ?? Random());

  int get performer => turn % players;
  int get totalTurns => players * turnsEach;
  String get current => deck[word % deck.length];
  int get msLeft => max(0, deadline - now);

  @override
  bool get finished => phase == TurnPhase.done;
  @override
  List<int> get scores => score;

  @override
  void update(int elapsedMs) {
    now = elapsedMs;
    if (phase == TurnPhase.playing) {
      if (now >= deadline) phase = TurnPhase.turnEnd;
      notifyListeners(); // the clock
    }
  }

  void start() {
    if (forward('start', const [])) return;
    if (phase != TurnPhase.ready) return;
    phase = TurnPhase.playing;
    deadline = now + turnMs;
    gotThisTurn = 0;
    notifyListeners();
  }

  void gotIt() {
    if (forward('got', const [])) return;
    if (phase != TurnPhase.playing) return;
    score[performer]++;
    gotThisTurn++;
    word++;
    notifyListeners();
  }

  void skip() {
    if (forward('skip', const [])) return;
    if (phase != TurnPhase.playing) return;
    word++;
    notifyListeners();
  }

  void next() {
    if (forward('next', const [])) return;
    if (phase != TurnPhase.turnEnd) return;
    turn++;
    word++;
    phase = turn >= totalTurns ? TurnPhase.done : TurnPhase.ready;
    notifyListeners();
  }
}

/// Online support shared by the word-turn games: only the performer runs their turn.
RelaySpec<WordTurnsLogic> wordTurnsRelay({
  required WordTurnsLogic Function(int players) create,
  required Widget Function(BuildContext, WordTurnsLogic, List<GpPlayer>, int me)
      view,
  bool actorOnly = false,
  bool hideFromActor = false,
}) =>
    RelaySpec<WordTurnsLogic>(
      create: create,
      save: (g) => {
        'phase': g.phase.index,
        'turn': g.turn,
        'word': g.word,
        'left': g.msLeft,
        'score': g.score,
        'got': g.gotThisTurn,
        'deck': g.deck
      },
      wire: (g) => {
        'phase': g.phase.index,
        'turn': g.turn,
        'word': g.word,
        'left': g.msLeft,
        'score': g.score,
        'got': g.gotThisTurn
      },
      views: (g) => [
        for (var i = 0; i < g.players; i++)
          (actorOnly
                  ? i == g.performer
                  : hideFromActor
                      ? i != g.performer
                      : true)
              ? {'word': g.current}
              : <String, dynamic>{},
      ],
      load: (g, s, me) {
        g.phase = TurnPhase.values[asInt(s['phase'])];
        g.turn = asInt(s['turn']);
        g.word = asInt(s['word']);
        g.now = 0;
        g.deadline = asInt(s['left']);
        g.score.setAll(0, ints(s['score']));
        g.gotThisTurn = asInt(s['got']);
        if (s['deck'] is List) {
          g.deck
            ..clear()
            ..addAll((s['deck'] as List).cast<String>());
        } else {
          final seat = s['_seat'];
          final secret = seat is Map ? seat['word'] as String? : null;
          g.deck
            ..clear()
            ..add(secret ?? '');
          g.word = 0;
        }
      },
      apply: (g, from, name, a) {
        if (name == 'next') return g.next();
        if (from != g.performer) return;
        switch (name) {
          case 'start':
            g.start();
          case 'got':
            g.gotIt();
          case 'skip':
            g.skip();
        }
      },
      view: view,
    );

/// Screen for a word-turn game (spec 5.2 #16, #17). [performerSeesWord] decides who sees
/// the word: in Charades only the actor (on a clapperboard card they hold to read); in
/// Heads Up everyone except the guesser (a huge word on a paper card, GOT IT / SKIP as
/// side zones). Everyone else watches a big ring timer.
class WordTurnsView extends StatelessWidget {
  final List<GpPlayer> players;
  final WordTurnsLogic g;
  final int? me;
  final String title;
  final String readyText; // what the performer does
  final String watchText; // what everyone else does
  final bool performerSeesWord;
  final Color color;
  const WordTurnsView({
    super.key,
    required this.players,
    required this.g,
    this.me,
    required this.title,
    required this.readyText,
    required this.watchText,
    required this.performerSeesWord,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final p = players[g.performer];
    final seat = PlayerPalette.indexOf(p.color) ?? g.performer;
    final isPerformer = me == null || me == g.performer;
    final turnLabel =
        'Turn ${min(g.turn + 1, g.totalTurns)} of ${g.totalTurns}';
    final t = context.tk;
    ResultScope.of(context)?.subtitle =
        '${g.totalTurns} turns of ${g.turnMs ~/ 1000} seconds';
    void got() {
      haptic(HapticWeight.medium);
      GameAudio.sfx('coin');
      final fx = GameFeedback.of(context);
      fx?.flash(StatusColors.success);
      fx?.pop('+1');
      g.gotIt();
    }

    void skip() {
      haptic(HapticWeight.light);
      GameFeedback.of(context)?.flash(const Color(0xFFFF8A1F));
      g.skip();
    }

    switch (g.phase) {
      case TurnPhase.ready:
        return PartyFrame(
          title: title,
          subtitle: turnLabel,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(children: [
                    PlayerBadge(
                        index: seat, size: 72, color: p.color, initial: p.name),
                    const SizedBox(height: 10),
                    Text('${possessive(p.name)} turn',
                        textAlign: TextAlign.center,
                        style: t.styles.h1.copyWith(
                            color: t.flat
                                ? fillFor(p.color)
                                : nameColor(p.color))),
                    const SizedBox(height: 14),
                    PromptCard(
                        header: isPerformer
                            ? (performerSeesWord ? 'You act' : 'You guess')
                            : 'Everyone else',
                        text: isPerformer ? readyText : watchText,
                        footer:
                            '${g.turnMs ~/ 1000} seconds. Get as many as you can!',
                        color: p.color),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (isPerformer)
              GoldButton('Start turn',
                  icon: GameIcons.play, height: 58, onPressed: g.start)
            else
              WaitingNote('Waiting for ${p.name} to start…'),
          ]),
        );
      case TurnPhase.playing:
        final showWord = me == null || (me == g.performer) == performerSeesWord;
        final ring =
            _BigTimer(msLeft: g.msLeft, totalMs: g.turnMs, got: g.gotThisTurn);
        final Widget middle;
        if (!showWord) {
          middle = Column(mainAxisSize: MainAxisSize.min, children: [
            ring,
            const SizedBox(height: 14),
            Text(isPerformer ? 'Listen to the clues and guess!' : watchText,
                textAlign: TextAlign.center,
                style: t.styles.h3.copyWith(color: t.onBg)),
          ]);
        } else if (performerSeesWord) {
          middle = Column(mainAxisSize: MainAxisSize.min, children: [
            _Clapperboard(word: g.current),
            const SizedBox(height: 12),
            SizedBox(height: 92, child: FittedBox(child: ring)),
          ]);
        } else {
          middle = _WordCard(word: g.current, color: color);
        }
        final buttons = Row(children: [
          Expanded(
              child: KitButton('Skip',
                  icon: GameIcons.skip,
                  style: KitButtonStyle.soft,
                  height: 58,
                  onPressed: skip)),
          const SizedBox(width: 12),
          Expanded(
              flex: 2,
              child: GoldButton('Got it',
                  icon: GameIcons.check, height: 58, onPressed: got)),
        ]);
        return PartyFrame(
          title: '${p.name} · ${g.gotThisTurn} got',
          subtitle: turnLabel,
          trailing: TimeChip(g.msLeft),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              // Heads Up: tap the left side to skip, the right side when they got it.
              child: !performerSeesWord && showWord
                  ? Row(children: [
                      _SideZone(
                          label: 'Skip',
                          color: const Color(0xFFFF8A1F),
                          icon: GameIcons.skip,
                          onTap: isPerformer ? skip : null),
                      Expanded(child: middle),
                      _SideZone(
                          label: 'Got it',
                          color: StatusColors.success,
                          icon: GameIcons.check,
                          onTap: isPerformer ? got : null),
                    ])
                  : Center(child: SingleChildScrollView(child: middle)),
            ),
            const SizedBox(height: 10),
            if (isPerformer) buttons,
          ]),
        );
      case TurnPhase.turnEnd:
      case TurnPhase.done:
        return PartyFrame(
          title: 'Time\'s up!',
          subtitle: turnLabel,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(children: [
                    PromptCard(
                        header: p.name,
                        text: '${g.gotThisTurn} correct!',
                        footer: g.gotThisTurn >= 5 ? 'On fire!' : 'Nice one!',
                        color: p.color),
                    const SizedBox(height: 14),
                    PlayerScoreRow(
                      count: players.length,
                      card: (i, compact) => PlayerScoreCard(
                        seat: PlayerPalette.indexOf(players[i].color) ?? i,
                        color: players[i].color,
                        name: players[i].name,
                        score: '${g.score[i]}',
                        active: i == g.performer,
                        compact: compact,
                      ),
                    ),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 10),
            GoldButton(
                g.turn + 1 >= g.totalTurns ? 'See scores' : 'Next player',
                icon: GameIcons.forward,
                height: 58,
                onPressed: g.next),
          ]),
        );
    }
  }
}

/// A big ring timer with the seconds and the count got so far.
class _BigTimer extends StatelessWidget {
  final int msLeft, totalMs, got;
  const _BigTimer(
      {required this.msLeft, required this.totalMs, required this.got});
  @override
  Widget build(BuildContext context) {
    final s = (msLeft / 1000).ceil();
    final urgent = s <= 10;
    return Semantics(
      label: '$s seconds left, $got got',
      excludeSemantics: true,
      child: SizedBox(
        width: 170,
        height: 170,
        child: CustomPaint(
          painter: _RingPainter(
              msLeft / totalMs, urgent ? StatusColors.danger : Brand.gold),
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('$s',
                  style: TextStyle(
                      fontFamily: Fonts.display,
                      fontSize: 64,
                      height: 1,
                      color: urgent ? StatusColors.danger : context.tk.onBg,
                      fontFeatures: const [FontFeature.tabularFigures()])),
              Text('$got GOT',
                  style: TextStyle(
                      fontFamily: Fonts.body,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                      color: context.tk.flat
                          ? FlatPalette.label
                          : NeonPalette.label)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double f;
  final Color color;
  _RingPainter(this.f, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final r = (Offset.zero & size).deflate(8);
    canvas.drawArc(
        r,
        0,
        2 * pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12
          ..color = Colors.white.withValues(alpha: 0.14));
    canvas.drawArc(
        r,
        -pi / 2,
        2 * pi * f.clamp(0, 1),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12
          ..strokeCap = StrokeCap.round
          ..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.f != f || o.color != color;
}

/// Charades: the movie on a clapperboard. The actor holds the card to read it, so nobody
/// glimpses it over their shoulder.
class _Clapperboard extends StatefulWidget {
  final String word;
  const _Clapperboard({required this.word});
  @override
  State<_Clapperboard> createState() => _ClapperboardState();
}

class _ClapperboardState extends State<_Clapperboard> {
  bool _peek = false;
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: _peek ? 'The movie: ${widget.word}' : 'Hold to see the movie',
      onTap: () => setState(() => _peek = !_peek),
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _peek = true),
        onTapUp: (_) => setState(() => _peek = false),
        onTapCancel: () => setState(() => _peek = false),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            decoration: BoxDecoration(
                color: const Color(0xFF22212B),
                borderRadius: Radii.rButton,
                boxShadow: Shadows.large),
            clipBehavior: Clip.antiAlias,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                  height: 34,
                  child: CustomPaint(
                      painter: _ClapStripes(),
                      size: const Size(double.infinity, 34))),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
                child: Column(children: [
                  const Text('THE MOVIE',
                      style: TextStyle(
                          fontFamily: Fonts.body,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.8,
                          color: Color(0xFFE9C46A))),
                  const SizedBox(height: 8),
                  AnimatedSwitcher(
                    duration: Motion.of(context, Motion.fast),
                    child: _peek
                        ? Text(widget.word,
                            key: const ValueKey('w'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontFamily: Fonts.display,
                                fontSize: 34,
                                height: 1.1,
                                color: Colors.white))
                        : const Row(
                            key: ValueKey('h'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                                GameIcon(GameIcons.eye, size: 22),
                                SizedBox(width: 8),
                                Text('Hold to see',
                                    style: TextStyle(
                                        fontFamily: Fonts.display,
                                        fontSize: 26,
                                        color: Colors.white)),
                              ]),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _ClapStripes extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFF2E2C38));
    final white = Paint()..color = Colors.white;
    for (var x = -size.height; x < size.width + size.height; x += 44) {
      canvas.drawPath(
          Path()
            ..moveTo(x, size.height)
            ..lineTo(x + 22, size.height)
            ..lineTo(x + 22 + size.height, 0)
            ..lineTo(x + size.height, 0)
            ..close(),
          white);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Heads Up: the word in huge Lilita on a paper card.
class _WordCard extends StatelessWidget {
  final String word;
  final Color color;
  const _WordCard({required this.word, required this.color});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: PaperCard(
          radius: 22,
          tint: color,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(word,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontFamily: Fonts.display,
                        fontSize: 56,
                        height: 1.05,
                        color: Brand.onGold)),
              ),
            ),
          ),
        ),
      );
}

/// A full-height side zone (Heads Up): tap it for Skip (left) or Got it (right).
class _SideZone extends StatelessWidget {
  final String label;
  final Color color;
  final GameIcons icon;
  final VoidCallback? onTap;
  const _SideZone(
      {required this.label,
      required this.color,
      required this.icon,
      this.onTap});
  @override
  Widget build(BuildContext context) => Semantics(
        button: onTap != null,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            width: 52,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: Radii.rChip,
                border: Border.all(
                    color: color.withValues(alpha: 0.7), width: 1.5)),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              GameIcon(icon, size: 22, color: color),
              const SizedBox(height: 8),
              RotatedBox(
                  quarterTurns: 3,
                  child: Text(label.toUpperCase(),
                      style: TextStyle(
                          fontFamily: Fonts.body,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.6,
                          color: color))),
            ]),
          ),
        ),
      );
}
