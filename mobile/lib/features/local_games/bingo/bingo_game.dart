import 'dart:math';
import 'package:flutter/material.dart';
import '../../guess_person/models/gp_player.dart';
import '../../../core/audio/game_audio.dart';
import '../../../core/ui/components.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/game_hud.dart';
import '../party/party_widgets.dart' show PassCover;
import '../shell/local_game_shell.dart' show ResultScope;
import '../shell/ticking_play.dart';

/// Bingo: everyone has a 5x5 card with 1-25 in a different order. Players take turns
/// calling a number; it's crossed off on every card. Each full row, column or diagonal
/// lights a letter of B-I-N-G-O. Five lines first wins (everyone who gets there on the
/// same call wins together).
class BingoLogic extends LocalGameLogic {
  static const size = 5;
  static const word = 'BINGO';
  static final List<List<int>> lines = [
    for (var r = 0; r < size; r++)
      [for (var c = 0; c < size; c++) r * size + c],
    for (var c = 0; c < size; c++)
      [for (var r = 0; r < size; r++) r * size + c],
    [for (var i = 0; i < size; i++) i * size + i],
    [for (var i = 0; i < size; i++) i * size + size - 1 - i],
  ];

  final int players;
  final List<List<int>> cards; // per player: the 25 numbers, cell by cell
  final List<int> called = [];
  int turn = 0;
  Set<int> winners = {};
  int revealedFor =
      -1; // one phone: whose card is uncovered (not part of the online state)

  BingoLogic({this.players = 2, Random? random})
      : cards = [
          for (var p = 0; p < players; p++)
            [for (var n = 1; n <= size * size; n++) n]
              ..shuffle(random ?? Random()),
        ];

  @override
  bool get finished => winners.isNotEmpty;
  @override
  List<int> get scores =>
      [for (var p = 0; p < players; p++) winners.contains(p) ? 1 : 0];
  @override
  void update(int elapsedMs) {}

  bool isCalled(int n) => called.contains(n);
  bool marked(int player, int cell) => called.contains(cards[player][cell]);

  /// Lines completed on a player's card (5 = BINGO).
  int lineCount(int player) =>
      lines.where((l) => l.every((cell) => marked(player, cell))).length;
  List<List<int>> doneLines(int player) =>
      lines.where((l) => l.every((cell) => marked(player, cell))).toList();

  /// The player whose turn it is calls [number]. Returns false if it can't be called.
  bool call(int number) {
    if (forward('call', [number])) return false;
    if (finished || number < 1 || number > size * size || isCalled(number))
      return false;
    called.add(number);
    winners = {
      for (var p = 0; p < players; p++)
        if (lineCount(p) >= size) p
    };
    if (!finished) turn = (turn + 1) % players;
    notifyListeners();
    return true;
  }

  void reveal(int player) {
    revealedFor = player;
    notifyListeners();
  }
}

/// The computer calls the number that helps its own lines most (and, a little, avoids
/// numbers that would finish someone else's line).
int bingoBotPick(BingoLogic g, int me, Random rng) {
  var best = -1;
  var bestScore = -1e9;
  for (var n = 1; n <= BingoLogic.size * BingoLogic.size; n++) {
    if (g.isCalled(n)) continue;
    double score = rng.nextDouble();
    for (var p = 0; p < g.players; p++) {
      final cell = g.cards[p].indexOf(n);
      for (final l in BingoLogic.lines.where((l) => l.contains(cell))) {
        final have = l.where((c) => g.marked(p, c)).length;
        final gain = (have + 1) * (have + 1).toDouble();
        score += p == me ? gain : -gain * 0.3;
      }
    }
    if (score > bestScore) {
      bestScore = score;
      best = n;
    }
  }
  return best;
}

final bingoInfo = LocalGameInfo(
  id: 'bingo',
  title: 'Bingo',
  emoji: '🔢',
  color: const Color(0xFFFF6B35),
  tagline: 'Call numbers, complete lines, shout BINGO!',
  rules: const [
    'Everyone has a 5×5 card with the numbers 1-25 in a different order.',
    'On your turn, tap a number on your card to call it. It gets crossed off on every card.',
    'Every full row, column or diagonal lights a letter of B-I-N-G-O.',
    'Light all five letters first to win! 2 to 6 players.',
  ],
  scoreUnit: 'wins',
  splitScreen: false,
  maxPlayers: 6,
  bot: botFor<BingoLogic>((g, b, now) {
    if (g.finished || g.turn != b.seat) return;
    if (!b.thinkFirst(g.called.length, now, 800, 1600)) return;
    g.call(bingoBotPick(g, b.seat, b.rng));
  }),
  online: RelaySpec<BingoLogic>(
    create: (n) => BingoLogic(players: n),
    save: (g) => {
      'cards': [for (final c in g.cards) ...c],
      'called': g.called,
      'turn': g.turn,
      'win': g.winners.toList()
    },
    load: (g, s, me) {
      final cards = ints(s['cards']);
      for (var p = 0; p < g.players; p++) {
        g.cards[p].setAll(0, cards.sublist(p * 25, p * 25 + 25));
      }
      g.called
        ..clear()
        ..addAll(ints(s['called']));
      g.turn = asInt(s['turn']);
      g.winners = ints(s['win']).toSet();
    },
    apply: (g, from, name, a) {
      if (name == 'call' && from == g.turn) g.call(asInt(a[0]));
    },
    view: (context, g, players, me) =>
        _BingoTable(g: g, players: players, me: me),
  ),
  play: (players, onFinished) => TickingPlay<BingoLogic>(
    create: () => BingoLogic(players: players.length),
    onFinished: onFinished,
    builder: (context, g) {
      final bots = {
        for (var i = 0; i < players.length; i++)
          if (BotScope.isBot(context, i)) i
      };
      return _BingoTable(
          g: g, players: players, me: BotScope.humanSeat(context), bots: bots);
    },
  ),
);

// Board palette: a paper bingo ticket and ink dabbers.
const _ticketInk = Color(0xFF1E1B3A);

/// Who called each number: turns go round one by one, so call k was made by seat k % players.
int _callerOf(BingoLogic g, int number) => g.called.indexOf(number) % g.players;

class _BingoTable extends StatelessWidget {
  final BingoLogic g;
  final List<GpPlayer> players;
  final int? me; // whose card this phone shows (online, or one person vs bots)
  final Set<int> bots;
  const _BingoTable(
      {required this.g, required this.players, this.me, this.bots = const {}});

  String _letters(int i) => g.lineCount(i) == 0
      ? '–'
      : BingoLogic.word.substring(0, min(g.lineCount(i), 5));

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    // One phone, several people: the card on screen is the caller's, after the phone is passed.
    final passing = me == null;
    final holder = me ?? (bots.contains(g.turn) ? _lastPerson() : g.turn);
    final covered = passing &&
        !bots.contains(g.turn) &&
        g.revealedFor != g.turn &&
        !g.finished;
    final myTurn = holder == g.turn && !bots.contains(g.turn);
    final current = players[g.turn];
    ResultScope.of(context)
      ?..subtitle = g.finished ? '${g.called.length} numbers called' : null
      ..detail = ((_, i) => Text(_letters(i),
          style: TextStyle(
              fontFamily: Fonts.display,
              fontSize: 18,
              letterSpacing: 2,
              color: nameColor(players[i].color))));
    final banner = g.finished
        ? TurnBanner(
            text: 'BINGO!',
            sub:
                '${g.winners.map((w) => players[w].name).join(' & ')} ${g.winners.length > 1 ? 'win' : 'wins'}',
            color: current.color,
            kind: TurnBannerKind.success,
            icon: GameIcons.star,
            compact: true)
        : TurnBanner(
            text: myTurn
                ? (passing ? '${possessive(current.name)} turn' : 'Your turn')
                : '${current.name} is calling…',
            sub: myTurn
                ? 'Tap a number on your card to call it'
                : 'Watch your card',
            color: current.color,
            compact: true,
          );
    return MomentWatcher<(int, int)>(
      value: (g.called.length, g.lineCount(holder)),
      onChange: (fx, before, now) {
        if (g.finished) {
          keyMoment(fx, 'BINGO!',
              sub: g.winners.map((w) => players[w].name).join(' & '),
              sound: 'win',
              confetti: true);
        } else if (now.$2 > before.$2) {
          keyMoment(fx, 'LINE!',
              sub: BingoLogic.word.substring(0, min(now.$2, 5)), sound: 'coin');
        }
      },
      child: Stack(children: [
        Padding(
          padding:
              const EdgeInsets.fromLTRB(Space.s, Space.xs, Space.s, Space.m),
          child: Column(children: [
            ScoreHud(
              title: 'Bingo',
              state: g.finished ? 'Bingo!' : '${g.called.length} of 25 called',
              players: players,
              turn: g.finished ? null : g.turn,
              score: _letters,
              tag: (i) => !g.finished && i == g.turn
                  ? 'CALLING'
                  : (g.winners.contains(i) ? 'BINGO' : null),
            ),
            const SizedBox(height: Space.s),
            _Letters(lines: g.lineCount(holder)),
            const SizedBox(height: 4),
            SizedBox(height: 54, child: Center(child: banner)),
            Expanded(
                child: Center(
                    child: AspectRatio(
                        aspectRatio: 1,
                        child: _Card(
                            g: g,
                            player: holder,
                            players: players,
                            canCall: myTurn && !covered)))),
            const SizedBox(height: Space.s),
            SizedBox(
              height: 40,
              child: g.called.isEmpty
                  ? const SizedBox.shrink()
                  : Row(children: [
                      Text('CALLED', style: t.styles.label),
                      const SizedBox(width: Space.s),
                      Expanded(
                        child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              for (final n in g.called.reversed.take(12))
                                Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  width: 36,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: n == g.called.last
                                        ? Brand.gold
                                        : players[_callerOf(g, n)]
                                            .color
                                            .withValues(alpha: 0.25),
                                    border: Border.all(
                                        color: n == g.called.last
                                            ? Brand.gold
                                            : players[_callerOf(g, n)].color,
                                        width: 1.5),
                                  ),
                                  child: Text('$n',
                                      style: TextStyle(
                                          fontFamily: Fonts.display,
                                          fontSize: 16,
                                          color: n == g.called.last
                                              ? Brand.onGold
                                              : t.onBg,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures()
                                          ])),
                                ),
                            ]),
                      ),
                    ]),
            ),
          ]),
        ),
        if (covered)
          PassCover(
              player: current,
              holdLabel: 'Hold to see your card',
              onReveal: () => g.reveal(g.turn)),
      ]),
    );
  }

  int _lastPerson() {
    for (var i = g.turn - 1; i >= -players.length; i--) {
      final p = i % players.length;
      if (!bots.contains(p)) return p;
    }
    return 0;
  }
}

/// B-I-N-G-O as five big tiles that light up gold, one per completed line.
class _Letters extends StatelessWidget {
  final int lines;
  const _Letters({required this.lines});
  @override
  Widget build(BuildContext context) => Semantics(
        label: lines == 0
            ? 'No lines yet'
            : '${BingoLogic.word.substring(0, min(lines, 5))}: $lines lines',
        excludeSemantics: true,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < BingoLogic.word.length; i++)
            AnimatedContainer(
              duration: Motion.of(context, Motion.slow),
              curve: Motion.emphasized,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: i < lines ? Brand.gold : context.tk.surface,
                borderRadius: Radii.rCard,
                border: Border.all(
                    color: i < lines ? Brand.gold : context.tk.stroke,
                    width: 2),
                boxShadow: i < lines
                    ? [
                        ...Shadows.edge(Brand.goldDeep, depth: 3),
                        BoxShadow(
                            color: Brand.gold.withValues(alpha: 0.5),
                            blurRadius: 12)
                      ]
                    : null,
              ),
              child: Text(BingoLogic.word[i],
                  style: TextStyle(
                      fontFamily: Fonts.display,
                      color: i < lines ? Brand.onGold : context.tk.onBgMuted,
                      fontSize: 26,
                      height: 1)),
            ),
        ]),
      );
}

/// A paper 5×5 card: Lilita numbers, called numbers stamped with an ink dauber in the
/// caller's colour, completed lines struck through with a marker in the holder's colour.
class _Card extends StatelessWidget {
  final BingoLogic g;
  final int player;
  final List<GpPlayer> players;
  final bool canCall;
  const _Card(
      {required this.g,
      required this.player,
      required this.players,
      required this.canCall});

  static const _gap = 6.0, _pad = 10.0;

  @override
  Widget build(BuildContext context) {
    final color = players[player].color;
    final last = g.called.isEmpty ? null : g.called.last;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFDF6), Color(0xFFF5E9D2)]),
        borderRadius: Radii.rBoard,
        border: Border.all(color: fillFor(color), width: 3),
        boxShadow: const [
          BoxShadow(
              color: Color(0x80000000), blurRadius: 20, offset: Offset(0, 10))
        ],
      ),
      padding: const EdgeInsets.all(_pad),
      child: Stack(children: [
        GridView.count(
          crossAxisCount: BingoLogic.size,
          mainAxisSpacing: _gap,
          crossAxisSpacing: _gap,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (var cell = 0; cell < 25; cell++)
              Builder(builder: (context) {
                final n = g.cards[player][cell];
                final isMarked = g.isCalled(n);
                final ink = isMarked ? players[_callerOf(g, n)].color : null;
                return Semantics(
                  button: canCall && !isMarked,
                  label: isMarked ? '$n, crossed off' : '$n',
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: canCall && !isMarked
                        ? () {
                            haptic(HapticWeight.selection);
                            GameAudio.sfx('pop');
                            g.call(n);
                          }
                        : null,
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.7),
                        borderRadius: Radii.rTile,
                        border: Border.all(
                            color: n == last
                                ? _ticketInk
                                : const Color(0x22704A20),
                            width: n == last ? 2.5 : 1),
                      ),
                      child: Stack(alignment: Alignment.center, children: [
                        if (ink != null)
                          TweenAnimationBuilder<double>(
                            tween: Tween(
                                begin: Motion.reduced(context) ? 1 : 0.4,
                                end: 1),
                            duration: Motion.of(context, Motion.normal),
                            curve: Curves.easeOutBack,
                            builder: (_, s, child) =>
                                Transform.scale(scale: s, child: child),
                            child: FractionallySizedBox(
                                widthFactor: 0.86,
                                heightFactor: 0.86,
                                child:
                                    CustomPaint(painter: _DabPainter(ink, n))),
                          ),
                        FittedBox(
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Text('$n',
                                style: TextStyle(
                                    fontFamily: Fonts.display,
                                    color: _ticketInk.withValues(
                                        alpha: isMarked ? 0.85 : 1),
                                    fontSize: 28,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ])),
                          ),
                        ),
                      ]),
                    ),
                  ),
                );
              }),
          ],
        ),
        Positioned.fill(
            child: IgnorePointer(
                child: CustomPaint(
                    painter:
                        _LinesPainter(g.doneLines(player), fillFor(color))))),
      ]),
    );
  }
}

/// An ink dauber blot: a soft, slightly uneven circle.
class _DabPainter extends CustomPainter {
  final Color color;
  final int seed;
  _DabPainter(this.color, this.seed);
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final rng = Random(seed);
    final p = Path();
    for (var i = 0; i <= 16; i++) {
      final a = i / 16 * 2 * pi;
      final k = r * (0.92 + rng.nextDouble() * 0.08);
      final pt = c + Offset(cos(a) * k, sin(a) * k);
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(p..close(), Paint()..color = color.withValues(alpha: 0.5));
    canvas.drawCircle(
        c, r * 0.55, Paint()..color = color.withValues(alpha: 0.2));
  }

  @override
  bool shouldRepaint(_DabPainter o) => o.color != color || o.seed != seed;
}

/// Marker strokes through completed lines.
class _LinesPainter extends CustomPainter {
  final List<List<int>> lines;
  final Color color;
  _LinesPainter(this.lines, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    const n = BingoLogic.size, gap = _Card._gap;
    final cell = (size.width - gap * (n - 1)) / n;
    Offset at(int i) => Offset(
        (i % n) * (cell + gap) + cell / 2, (i ~/ n) * (cell + gap) + cell / 2);
    final paint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..strokeWidth = cell * 0.22
      ..strokeCap = StrokeCap.round;
    for (final l in lines) {
      canvas.drawLine(at(l.first), at(l.last), paint);
    }
  }

  @override
  bool shouldRepaint(_LinesPainter o) =>
      o.lines.length != lines.length || o.color != color;
}
