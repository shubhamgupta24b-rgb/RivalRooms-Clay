import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/audio/game_audio.dart';
import '../../../core/ui/components.dart';
import '../../../core/ui/app_flavor.dart';
import '../../guess_person/data/person_data.dart';
import '../../guess_person/models/gp_player.dart';
import '../../guess_person/models/person.dart';
import '../../../core/ui/materials/materials.dart';
import '../../guess_person/widgets/person_portrait.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/game_hud.dart';
import '../shell/local_game_shell.dart' show ResultScope;
import '../shell/ticking_play.dart';

class MemoryCard {
  final int id;
  final String symbol;
  int? matchedBy; // player index once matched
  MemoryCard(this.id, this.symbol);
  bool get matched => matchedBy != null;
}

/// Same rules as the online version: 12 pairs, a match scores and you go again,
/// a miss is shown briefly and the turn passes.
class MemoryLogic extends LocalGameLogic {
  static const symbols = [
    '🍎',
    '🍌',
    '🍇',
    '🍉',
    '🍓',
    '🥝',
    '🍒',
    '🥭',
    '🍑',
    '🍍',
    '🥥',
    '🍋'
  ];
  final int mismatchMs;
  final List<MemoryCard> cards;
  final List<int> pairs;
  final List<int> picks = [];
  int turn = 0;
  int _now = 0;
  int? _mismatchUntil;

  MemoryLogic(
      {int pairCount = 12,
      this.mismatchMs = 900,
      int players = 2,
      Random? random})
      : pairs = List.filled(players, 0),
        cards = _deal(pairCount, random ?? Random());

  static List<MemoryCard> _deal(int n, Random r) {
    final values = [...symbols.take(n), ...symbols.take(n)]..shuffle(r);
    return [for (var i = 0; i < values.length; i++) MemoryCard(i, values[i])];
  }

  @override
  List<int> get scores => pairs;
  @override
  bool get finished => cards.every((c) => c.matched);
  bool get showingMismatch => _mismatchUntil != null;
  bool isFaceUp(MemoryCard c) => c.matched || picks.contains(c.id);

  @override
  void update(int elapsedMs) {
    _now = elapsedMs;
    final until = _mismatchUntil;
    if (until != null && _now >= until) {
      picks.clear();
      _mismatchUntil = null;
      turn = (turn + 1) % pairs.length;
      notifyListeners();
    }
  }

  /// Returns true if the flip was accepted.
  bool flip(int id) {
    if (finished || showingMismatch || id < 0 || id >= cards.length)
      return false;
    final card = cards[id];
    if (card.matched || picks.contains(id)) return false;
    picks.add(id);
    if (picks.length == 2) {
      final a = cards[picks[0]], b = cards[picks[1]];
      if (a.symbol == b.symbol) {
        a.matchedBy = b.matchedBy = turn;
        pairs[turn]++;
        picks.clear(); // same player goes again
      } else {
        _mismatchUntil = _now + mismatchMs;
      }
    }
    notifyListeners();
    return true;
  }
}

final memoryInfo = LocalGameInfo(
  id: 'memory',
  title: 'Memory',
  emoji: '🧠',
  color: const Color(0xFF14B8A6),
  tagline: 'Find the pairs, remember everything!',
  rules: const [
    'Take turns flipping two cards.',
    'Find a matching pair to score a point and go again.',
    'No match? The cards flip back and it\'s the next player\'s turn.',
    'Most pairs when the board is clear wins. 2 to 6 players.',
  ],
  scoreUnit: 'pairs',
  splitScreen: false,
  maxPlayers: 6,
  bot: botFor<MemoryLogic>((g, b, now) {
    // Watch every flip (anyone's), remembering about three out of four cards.
    final seen = (b.memory['seen'] ??= <int, String>{}) as Map<int, String>;
    final judged = (b.memory['judged'] ??= <int>{}) as Set<int>;
    for (final id in g.picks) {
      if (judged.add(id * 1000 + g.pairs.reduce((a, c) => a + c)) &&
          b.chance(0.75)) seen[id] = g.cards[id].symbol;
    }
    if (g.finished ||
        g.showingMismatch ||
        g.turn != b.seat ||
        g.picks.length >= 2) return;
    if (!b.thinkFirst(
        (g.picks.length, g.pairs.reduce((a, c) => a + c), g.picks.firstOrNull),
        now,
        700,
        1300)) return;
    final open = [
      for (final c in g.cards)
        if (!c.matched && !g.picks.contains(c.id)) c.id
    ];
    seen.removeWhere((id, _) => g.cards[id].matched);
    int? partner(String symbol, int not) => seen.entries
        .where((e) => e.value == symbol && e.key != not && open.contains(e.key))
        .map((e) => e.key)
        .firstOrNull;
    int? target;
    if (g.picks.isEmpty) {
      // A pair I already know about?
      for (final e in seen.entries) {
        if (open.contains(e.key) && partner(e.value, e.key) != null) {
          target = e.key;
          break;
        }
      }
    } else {
      target = partner(g.cards[g.picks.first].symbol, g.picks.first);
    }
    final unknown = open.where((id) => !seen.containsKey(id)).toList();
    g.flip(target ?? (unknown.isNotEmpty ? b.pick(unknown) : b.pick(open)));
  }),
  play: (players, onFinished) => TickingPlay<MemoryLogic>(
    create: () => MemoryLogic(players: players.length),
    onFinished: onFinished,
    builder: (context, g) => _MemoryBoard(players: players, g: g),
  ),
);

/// The drawn fruit for each memory symbol (the logic keeps its emoji keys).
const _fruit = <String, (GameIcons, String)>{
  '🍎': (GameIcons.apple, 'apple'),
  '🍌': (GameIcons.banana, 'banana'),
  '🍇': (GameIcons.grapes, 'grapes'),
  '🍉': (GameIcons.watermelon, 'watermelon'),
  '🍓': (GameIcons.strawberry, 'strawberry'),
  '🥝': (GameIcons.kiwi, 'kiwi'),
  '🍒': (GameIcons.cherry, 'cherries'),
  '🥭': (GameIcons.mango, 'mango'),
  '🍑': (GameIcons.peach, 'peach'),
  '🍍': (GameIcons.pineapple, 'pineapple'),
  '🥥': (GameIcons.coconut, 'coconut'),
  '🍋': (GameIcons.lemon, 'lemon'),
};
GameIcons _iconOf(String s) => _fruit[s]?.$1 ?? GameIcons.star;
String _nameOf(String s) => _fruit[s]?.$2 ?? 'card';

/// The fruit a player has collected, in the order they were matched.
List<String> _collected(MemoryLogic g, int p) {
  final out = <String>[];
  for (final c in g.cards) {
    if (c.matchedBy == p && !out.contains(c.symbol)) out.add(c.symbol);
  }
  return out;
}

/// A row of small fruit (the score card's second row, and result rows).
class _FruitRow extends StatelessWidget {
  final List<String> symbols;
  final double size;
  const _FruitRow(this.symbols, {this.size = 16});
  @override
  Widget build(BuildContext context) => SizedBox(
        height: size,
        child: Semantics(
          label: symbols.isEmpty
              ? 'No pairs yet'
              : 'Collected: ${symbols.map(_nameOf).join(', ')}',
          excludeSemantics: true,
          child: ClipRect(
            child: Row(children: [
              for (final s in symbols)
                Padding(
                    padding: EdgeInsets.only(right: size * 0.3),
                    child: flatStyle
                        ? Text(_faceFor(s).name[0],
                            style: TextStyle(fontSize: size * 0.8))
                        : GameIcon(_iconOf(s), size: size)),
            ]),
          ),
        ),
      );
}

/// Memory (spec 5.1 #9, mockups memory/*): felt table, patterned card backs, paper faces
/// with drawn fruit, matched cards tinted with the owner's badge, MATCH / No match banner.
class _MemoryBoard extends StatefulWidget {
  final List<GpPlayer> players;
  final MemoryLogic g;
  const _MemoryBoard({required this.players, required this.g});
  @override
  State<_MemoryBoard> createState() => _MemoryBoardState();
}

class _MemoryBoardState extends State<_MemoryBoard> {
  late Set<int> _matched = _matchedNow;
  Set<int> _fresh = {}; // the pair just matched: glows until the next flip
  int? _matchedBy;

  MemoryLogic get g => widget.g;
  Set<int> get _matchedNow => {
        for (final c in g.cards)
          if (c.matched) c.id
      };

  void _track() {
    final now = _matchedNow;
    if (now.length > _matched.length) {
      _fresh = now.difference(_matched);
      _matchedBy = g.cards[_fresh.first].matchedBy;
      final fx = GameFeedback.of(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (g.finished) {
          keyMoment(fx, 'BOARD CLEAR!', sound: 'win', confetti: true);
        } else {
          fx?.pop('+1 PAIR');
          GameAudio.sfx('coin');
          haptic(HapticWeight.medium);
        }
      });
    } else if (g.picks.isNotEmpty || g.showingMismatch) {
      if (g.showingMismatch && _fresh.isNotEmpty) {
        GameAudio.sfx('lose');
        haptic(HapticWeight.light);
      }
      _fresh = {};
      _matchedBy = null;
    }
    _matched = now;
  }

  @override
  Widget build(BuildContext context) {
    _track();
    final players = widget.players;
    final current = players[g.turn];
    final next = players[(g.turn + 1) % players.length];
    final left = g.cards.where((c) => !c.matched).length ~/ 2;
    final justMatched = _matchedBy != null && !g.finished;
    _results(context);

    final Widget banner;
    if (g.showingMismatch) {
      banner = TweenAnimationBuilder<double>(
        key: ValueKey('miss${g.picks.join()}'),
        tween: Tween(begin: 1, end: 0),
        duration: Duration(milliseconds: g.mismatchMs),
        builder: (_, v, __) => TurnBanner(
            text: 'No match',
            sub: 'Remember them! ${next.name} is next',
            color: current.color,
            kind: TurnBannerKind.miss,
            compact: true,
            drain: v),
      );
    } else if (justMatched) {
      banner = TurnBanner(
          text: 'MATCH!',
          sub: '+1 pair · ${players[_matchedBy!].name} goes again',
          color: current.color,
          kind: TurnBannerKind.success,
          icon: GameIcons.star,
          compact: true);
    } else if (g.finished) {
      banner = TurnBanner(
          text: 'Board clear!',
          color: current.color,
          kind: TurnBannerKind.success,
          icon: GameIcons.trophy,
          compact: true);
    } else {
      banner = TurnBanner(
          text: '${possessive(current.name)} turn',
          sub: g.picks.isEmpty ? 'Flip two cards' : 'Flip one more',
          color: current.color,
          compact: true);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.s, Space.xs, Space.s, Space.m),
      child: Column(children: [
        ScoreHud(
          title: 'Memory',
          state: g.finished
              ? 'Board clear'
              : '$left ${left == 1 ? 'pair' : 'pairs'} left',
          players: players,
          turn: g.finished || g.showingMismatch ? null : g.turn,
          score: (i) => '${g.pairs[i]}',
          tag: (i) {
            if (g.finished) return null;
            if (g.showingMismatch)
              return i == g.turn
                  ? 'MISSED'
                  : (players.length > 2 && i == (g.turn + 1) % players.length
                      ? 'NEXT'
                      : null);
            if (i == g.turn) return justMatched ? 'GO AGAIN' : 'YOUR TURN';
            return null;
          },
          detail: (i, compact) => compact ? null : _FruitRow(_collected(g, i)),
        ),
        const SizedBox(height: Space.s),
        SizedBox(height: 56, child: Center(child: banner)),
        const SizedBox(height: Space.s),
        Expanded(
          child: _table(LayoutBuilder(builder: (context, c) {
            // 4 columns x 6 rows on phones; 6 x 4 when the space is wide.
            final cols = c.maxWidth > c.maxHeight ? 6 : 4;
            final rows = (g.cards.length / cols).ceil();
            const gap = 8.0;
            final cellW = (c.maxWidth - gap * (cols - 1)) / cols;
            final cellH = (c.maxHeight - gap * (rows - 1)) / rows;
            return Semantics(
              label:
                  'Card table: $left pairs left. ${possessive(current.name)} turn.',
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  crossAxisSpacing: gap,
                  mainAxisSpacing: gap,
                  childAspectRatio: (cellW / cellH).clamp(0.5, 1.5),
                ),
                itemCount: g.cards.length,
                itemBuilder: (_, i) {
                  final card = g.cards[i];
                  final owner = card.matched ? players[card.matchedBy!] : null;
                  return _FlipCard(
                    key: ValueKey(card.id),
                    index: i,
                    faceUp: g.isFaceUp(card),
                    symbol: card.symbol,
                    ownerColor: owner?.color,
                    ownerSeat: owner == null
                        ? null
                        : (PlayerPalette.indexOf(owner.color) ??
                            card.matchedBy),
                    ownerName: owner?.name,
                    glow: _fresh.contains(card.id),
                    wrong: g.showingMismatch && g.picks.contains(card.id),
                    onTap: () {
                      if (g.flip(card.id)) {
                        haptic(HapticWeight.selection);
                        GameAudio.sfx('tap');
                      }
                    },
                  );
                },
              ),
            );
          })),
        ),
      ]),
    );
  }

  /// Results: board-clear label, "6 of 12 pairs", a fan of the winner's fruit, fruit rows.
  void _results(BuildContext context) {
    final extras = ResultScope.of(context);
    if (extras == null) return;
    final players = widget.players;
    final top = g.pairs.reduce(max);
    final winner = g.pairs.indexOf(top);
    extras
      ..label = 'Board clear'
      ..subtitle =
          '$top of ${g.cards.length ~/ 2} pairs · ${players.length} players'
      ..hero = ((_) => _CardFan(
          symbols: _collected(g, winner), color: players[winner].color))
      ..detail = ((_, i) => _FruitRow(_collected(g, i), size: 18));
  }

  /// The felt card table (the flat app: the dark-blue board).
  Widget _table(Widget grid) => flatStyle
      ? Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: FlatColors.board, borderRadius: BorderRadius.circular(24)),
          child: grid)
      : DecoratedBox(
          decoration: BoxDecoration(
              borderRadius: Radii.rBoard,
              boxShadow: const [
                BoxShadow(
                    color: Color(0x80000000),
                    blurRadius: 28,
                    offset: Offset(0, 12))
              ]),
          child: CustomPaint(
              painter: const _TrayPainter(),
              child: Padding(padding: const EdgeInsets.all(12), child: grid)),
        );
}

/// Results hero: three cards fanned out with the winner's fruit, and a little confetti.
class _CardFan extends StatelessWidget {
  final List<String> symbols;
  final Color color;
  const _CardFan({required this.symbols, required this.color});
  @override
  Widget build(BuildContext context) {
    final picks = [
      for (var i = 0; i < 3; i++)
        symbols.isEmpty ? '🍎' : symbols[i % symbols.length]
    ];
    Widget card(String s, double angle, double dx, double dy) =>
        Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.rotate(
            angle: angle,
            child: SizedBox(
              width: 78,
              height: 90,
              child: PaperCard(
                  tint: color,
                  child: Center(
                      child: flatStyle
                          ? PersonPortrait(_faceFor(s))
                          : GameIcon(_iconOf(s), size: 44))),
            ),
          ),
        );
    return ExcludeSemantics(
      child: SizedBox(
        height: 140,
        child: Stack(alignment: Alignment.center, children: [
          card(picks[0], -0.24, -64, 14),
          card(picks[2], 0.24, 64, 14),
          card(picks[1], 0, 0, 0),
        ]),
      ),
    );
  }
}

/// Flat app: each memory symbol stands for one cartoon person (distinct looks, no near-twins).
const _faceIds = [11, 16, 1, 12, 5, 3, 2, 4, 9, 19, 15, 28];
Person _faceFor(String symbol) {
  final id = _faceIds[MemoryLogic.symbols.indexOf(symbol) % _faceIds.length];
  return allPeople.firstWhere((p) => p.id == id);
}

/// A card that flips around its vertical axis. Night look: [CardBack] back, paper face with
/// drawn fruit; matched cards tinted in the owner's colour with their badge; the pair just
/// matched glows gold; a wrong pair is outlined red and tilted while it shows.
class _FlipCard extends StatelessWidget {
  final int index;
  final bool faceUp;
  final String symbol;
  final Color? ownerColor;
  final int? ownerSeat;
  final String? ownerName;
  final bool glow, wrong;
  final VoidCallback onTap;
  const _FlipCard(
      {super.key,
      required this.index,
      required this.faceUp,
      required this.symbol,
      required this.ownerColor,
      this.ownerSeat,
      this.ownerName,
      this.glow = false,
      this.wrong = false,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = faceUp
        ? '${flatStyle ? _faceFor(symbol).name : _nameOf(symbol)}${ownerName != null ? ', matched by $ownerName' : ''}'
        : 'Hidden card ${index + 1}';
    return Semantics(
      button: !faceUp,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedRotation(
          turns: wrong ? (index.isEven ? -0.012 : 0.012) : 0,
          duration: Motion.of(context, Motion.fast),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: faceUp ? 1 : 0),
            duration: Motion.of(context, const Duration(milliseconds: 260)),
            builder: (_, t, __) {
              final showFace = t >= 0.5;
              final angle = t * pi;
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.002)
                  ..rotateY(showFace ? angle - pi : angle),
                child: Stack(
                    fit: StackFit.expand,
                    clipBehavior: Clip.none,
                    children: [
                      if (glow && showFace)
                        Positioned.fill(
                          child: DecoratedBox(
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                BoxShadow(
                                    color: Brand.gold.withValues(alpha: 0.8),
                                    blurRadius: 16,
                                    spreadRadius: 2)
                              ])),
                        ),
                      flatStyle
                          ? (showFace ? _flatFace() : _flatBack())
                          : (showFace
                              ? _face()
                              : const CustomPaint(painter: _BackPainter())),
                      if (showFace && (wrong || glow))
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: wrong
                                            ? const Color(0xFFFF5E5B)
                                            : Brand.gold,
                                        width: 3))),
                          ),
                        ),
                      if (showFace && ownerSeat != null)
                        Positioned(
                            right: 4,
                            top: 4,
                            child: PlayerBadge(
                                index: ownerSeat!,
                                size: 16,
                                color: ownerColor)),
                    ]),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _face() => PaperCard(
        tint: ownerColor ?? _teal,
        child: LayoutBuilder(
          builder: (_, c) => Center(
              child: GameIcon(_iconOf(symbol),
                  size: min(c.maxWidth, c.maxHeight) * 0.62)),
        ),
      );

  /// White card with a big blue "?".
  Widget _flatBack() => Container(
        decoration: flatTile(radius: 12),
        alignment: Alignment.center,
        child: const FittedBox(
          child: Padding(
            padding: EdgeInsets.all(6),
            child: Text('?',
                style: TextStyle(
                    color: FlatColors.sky,
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    height: 1)),
          ),
        ),
      );

  /// The person's face with their name on a dark strip; matched cards get the owner's colour.
  Widget _flatFace() {
    final p = _faceFor(symbol);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: ownerColor ?? Colors.white,
            width: ownerColor == null ? 2 : 4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(3, 4, 3, 0),
                  child: PersonPortrait(p))),
          Container(
            color: ownerColor ?? FlatColors.strip,
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(p.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14))),
          ),
        ]),
      ),
    );
  }
}

// Memory's own look: a teal tray and coral cards.
const _teal = Color(0xFF14B8A6);
const _tealDeep = Color(0xFF0B6F66);
const _coral = Color(0xFFFF7A59);
const _coralDeep = Color(0xFFD9483B);

/// The table: a raised teal tray with a soft dotted pattern and a lighter rim.
class _TrayPainter extends CustomPainter {
  const _TrayPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final tray = RRect.fromRectAndRadius(r, const Radius.circular(Radii.board));
    canvas.drawRRect(
        tray,
        Paint()
          ..shader = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1FCFBC), _teal, _tealDeep]).createShader(r));
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.07);
    for (var y = 10.0; y < size.height; y += 22) {
      for (var x = (y ~/ 22).isEven ? 10.0 : 21.0; x < size.width; x += 22) {
        canvas.drawCircle(Offset(x, y), 2.2, dot);
      }
    }
    canvas.drawRRect(
        tray.deflate(3),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Colors.white.withValues(alpha: 0.28));
    canvas.drawRRect(
        tray,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _tealDeep);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A card back: coral with diagonal candy stripes, a white border and a "?" medallion.
class _BackPainter extends CustomPainter {
  const _BackPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final card = RRect.fromRectAndRadius(r, const Radius.circular(10));
    canvas.drawRRect(
        card.shift(const Offset(0, 3)), Paint()..color = Colors.black26);
    canvas.drawRRect(
        card,
        Paint()
          ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_coral, _coralDeep]).createShader(r));
    canvas.save();
    canvas.clipRRect(card.deflate(5));
    final stripe = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..strokeWidth = size.width * 0.09;
    for (var x = -size.height;
        x < size.width + size.height;
        x += size.width * 0.22) {
      canvas.drawLine(
          Offset(x, size.height), Offset(x + size.height, 0), stripe);
    }
    canvas.restore();
    canvas.drawRRect(
        card.deflate(4),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = Colors.white.withValues(alpha: 0.85));
    final c = r.center, rad = min(size.width, size.height) * 0.22;
    canvas.drawCircle(c, rad, Paint()..color = Colors.white);
    canvas.drawCircle(
        c,
        rad,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _coralDeep);
    final tp = TextPainter(
      text: TextSpan(
          text: '?',
          style: TextStyle(
              fontFamily: Fonts.display,
              fontSize: rad * 1.3,
              height: 1,
              color: _coralDeep)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
