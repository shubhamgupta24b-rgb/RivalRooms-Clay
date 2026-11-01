import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/audio/game_audio.dart';
import '../../../core/ui/components.dart';
import '../../guess_person/models/gp_player.dart';
import '../../../core/ui/materials/materials.dart';
import '../shell/local_game_shell.dart' show ResultScope;
import '../shell/local_game_info.dart';
import '../shell/game_hud.dart';
import '../party/party_widgets.dart' show HoldToReveal;
import '../shell/ticking_play.dart';
import 'colour_clash_logic.dart';

export 'colour_clash_logic.dart';

const clashColors = {
  ClashColor.red: Color(0xFFE53935),
  ClashColor.yellow: Color(0xFFF9C80E),
  ClashColor.green: Color(0xFF2EAA4F),
  ClashColor.blue: Color(0xFF1E7BE0),
  ClashColor.wild: Color(0xFF1C1C24),
};

/// A mark per colour, printed on the cards, so colour is never the only way to tell them
/// apart: red heart, yellow star, green triangle, blue diamond (drawn, not text).
void _paintSuit(Canvas canvas, ClashColor c, Rect r, Color ink) {
  switch (c) {
    case ClashColor.red:
      paintIcon(canvas, GameIcons.heart, r, color: ink);
    case ClashColor.yellow:
      canvas.drawPath(PlayerShapePainter.pathFor(PlayerShape.star, r),
          Paint()..color = ink);
    case ClashColor.green:
      canvas.drawPath(PlayerShapePainter.pathFor(PlayerShape.triangle, r),
          Paint()..color = ink);
    case ClashColor.blue:
      canvas.drawPath(PlayerShapePainter.pathFor(PlayerShape.diamond, r),
          Paint()..color = ink);
    case ClashColor.wild:
      break;
  }
}

String _colourName(ClashColor c) => c == ClashColor.wild ? 'wild' : c.name;

final colourClashInfo = LocalGameInfo(
  id: 'colour_clash',
  title: 'Colour Clash',
  emoji: '🃏',
  color: const Color(0xFFE53935),
  tagline: 'Match colours, dodge +4s, call ONE!',
  rules: const [
    'Everyone gets 7 cards. Play a card that matches the top card by colour, number or symbol, or play a Wild.',
    "Can't play? Draw one. Skip ⊘, Reverse ⇄, +2 and Wild +4 work like the classic game.",
    'Down to two cards? Tap ONE! before you play, or pick up 2. First to empty their hand wins!',
    'Online on two phones. Your cards stay on your phone. Pass-and-play is turned off.',
  ],
  scoreUnit: 'wins',
  splitScreen: false,
  remoteOnly: true,
  minPlayers: 2,
  maxPlayers: 2,
  bot: botFor<ColourClashLogic>((g, b, now) {
    // One person against the computer never passes the phone; with several people, only
    // the bots' own turns skip the pass-the-phone screen.
    if (g.phase == ClashPhase.handoff) {
      if (b.loneHuman || g.turn == b.seat) g.reveal();
      return;
    }
    if (g.finished || g.turn != b.seat) return;
    if (!b.thinkFirst(
        (g.discard.length, g.phase, g.drewThisTurn, g.hand.length),
        now,
        700,
        1500)) return;
    final hand = g.hand;
    ClashColor favourite() {
      final counts = <ClashColor, int>{};
      for (final c in hand.where((c) => !c.isWild)) {
        counts[c.color] = (counts[c.color] ?? 0) + 1;
      }
      return counts.isEmpty
          ? b.pick(const [
              ClashColor.red,
              ClashColor.yellow,
              ClashColor.green,
              ClashColor.blue
            ])
          : (counts.entries.toList()..sort((a, c) => c.value - a.value))
              .first
              .key;
    }

    if (g.phase == ClashPhase.chooseColor) {
      g.chooseColor(favourite());
      return;
    }
    final options = g.playable.toList();
    if (options.isEmpty) {
      if (!g.drewThisTurn) g.draw();
      return;
    }
    // Remember to call ONE! (usually).
    if (hand.length == 2 && !g.calledOne && b.chance(0.9)) g.callOne();
    final nextHasFew = g.hands[g.nextPlayer()].length <= 2;
    int rank(ClashCard c) => switch (c.kind) {
          ClashKind.wildFour => nextHasFew
              ? 50
              : 1, // save the big ones unless someone is close to winning
          ClashKind.wild => 2,
          ClashKind.drawTwo => nextHasFew ? 40 : 20,
          ClashKind.skip || ClashKind.reverse => 15,
          ClashKind.number => 10 + (c.color == favourite() ? 3 : 0),
        };
    options.sort((a, c) => rank(c) - rank(a));
    final card = options.first;
    g.play(card.id, chosen: card.isWild ? favourite() : null);
  }),
  online: RelaySpec<ColourClashLogic>(
    create: (n) => ColourClashLogic(players: n),
    save: (g) => {
      'hands': [
        for (final h in g.hands) [for (final c in h) c.id]
      ],
      'counts': [for (final h in g.hands) h.length],
      'pile': g.drawPile.length,
      'top': g.top.id,
      'discard': g.discard.length,
      'color': g.color.index,
      'turn': g.turn,
      'dir': g.direction,
      'phase': g.phase.index,
      'drew': g.drewThisTurn,
      'drawn': g.drawnCard?.id,
      'one': g.calledOne,
      'winner': g.winner,
      'msg': g.message,
    },
    wire: (g) => {
      'counts': [for (final h in g.hands) h.length],
      'pile': g.drawPile.length,
      'top': g.top.id,
      'discard': g.discard.length,
      'color': g.color.index,
      'turn': g.turn,
      'dir': g.direction,
      'phase': g.phase.index,
      'drew': g.drewThisTurn,
      'one': g.calledOne,
      'winner': g.winner,
      'msg': g.message,
    },
    views: (g) => [
      for (var i = 0; i < g.hands.length; i++)
        {
          'hand': [for (final c in g.hands[i]) c.id],
          if (i == g.turn && g.drawnCard != null) 'drawn': g.drawnCard!.id,
        },
    ],
    load: (g, s, me) {
      final byId = {for (final c in ColourClashLogic.fullDeck()) c.id: c};
      if (s['hands'] != null) {
        final hands = (s['hands'] as List).map(ints).toList();
        for (var i = 0; i < g.hands.length; i++) {
          g.hands[i]
            ..clear()
            ..addAll(hands[i].map((id) => byId[id]!));
        }
      } else {
        final counts = ints(s['counts']);
        final seat = s['_seat'];
        final mine = seat is Map ? ints(seat['hand']) : const <int>[];
        final hidden = byId.values.first;
        for (var i = 0; i < g.hands.length; i++) {
          g.hands[i]
            ..clear()
            ..addAll(i == me
                ? mine.map((id) => byId[id]!)
                : List.filled(counts[i], hidden));
        }
      }
      // Guests only need to know how many cards are in the piles.
      g.drawPile
        ..clear()
        ..addAll(List.filled(asInt(s['pile']), byId[0]!));
      g.discard
        ..clear()
        ..addAll(List.filled(asInt(s['discard']) - 1, byId[0]!))
        ..add(byId[asInt(s['top'])]!);
      g.color = ClashColor.values[asInt(s['color'])];
      g.turn = asInt(s['turn']);
      g.direction = asInt(s['dir']);
      g.phase = ClashPhase.values[asInt(s['phase'])];
      g.drewThisTurn = s['drew'] == true;
      final seatDrawn =
          s['_seat'] is Map ? (s['_seat'] as Map)['drawn'] : s['drawn'];
      g.drawnCard = seatDrawn == null ? null : byId[asInt(seatDrawn)];
      g.calledOne = s['one'] == true;
      g.winner = nInt(s['winner']);
      g.message = s['msg'] as String;
    },
    apply: (g, from, name, a) {
      if (from != g.turn) return;
      switch (name) {
        case 'play':
          g.play(asInt(a[0]),
              chosen: a[1] == null ? null : ClashColor.values[asInt(a[1])]);
        case 'color':
          g.chooseColor(ClashColor.values[asInt(a[0])]);
        case 'draw':
          g.draw();
        case 'pass':
          g.pass();
        case 'one':
          g.callOne();
      }
    },
    // No passing the phone online: everyone holds their own hand.
    hostAuto: (g) {
      if (g.phase == ClashPhase.handoff) g.reveal();
    },
    view: (context, g, players, me) =>
        _ClashTable(players: players, g: g, me: me),
  ),
  play: (players, onFinished) => TickingPlay<ColourClashLogic>(
    create: () => ColourClashLogic(players: players.length),
    onFinished: onFinished,
    // One person against the computer only ever sees their own hand; with several people the
    // phone is passed and the bots' hands stay face down.
    builder: (context, g) => _ClashTable(
      players: players,
      g: g,
      me: BotScope.humanSeat(context),
      botSeats: {
        for (var i = 0; i < players.length; i++)
          if (BotScope.isBot(context, i)) i
      },
    ),
  ),
);

/// One card, face up or face down, at any size (designed at 70x105): a paper card with a
/// colour field, the number or a drawn Skip / Reverse / +2 / Wild / +4 symbol, and the
/// colour's suit mark in the corners.
class ClashCardView extends StatelessWidget {
  final ClashCard? card; // null = face down
  final double width;
  final bool highlight;
  final bool dim;
  const ClashCardView(
      {super.key,
      required this.card,
      this.width = 70,
      this.highlight = false,
      this.dim = false});

  @override
  Widget build(BuildContext context) {
    final c = card;
    return Semantics(
      label: c == null
          ? 'Face-down card'
          : '${_colourName(c.color)} ${_spoken(c)}',
      excludeSemantics: true,
      child: Opacity(
        opacity: dim ? 0.55 : 1,
        child: Container(
          width: width,
          height: width * 1.5,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(width * 0.13),
            boxShadow: [
              const BoxShadow(
                  color: Color(0x73000000),
                  blurRadius: 6,
                  offset: Offset(0, 3)),
              if (highlight)
                BoxShadow(
                    color: Brand.gold.withValues(alpha: 0.85),
                    blurRadius: 12,
                    spreadRadius: 1),
            ],
          ),
          child: c == null
              ? CardBack(radius: width * 0.13)
              : CustomPaint(painter: _CardPainter(c)),
        ),
      ),
    );
  }

  static String _spoken(ClashCard c) => switch (c.kind) {
        ClashKind.number => '${c.number}',
        ClashKind.skip => 'skip',
        ClashKind.reverse => 'reverse',
        ClashKind.drawTwo => 'draw two',
        ClashKind.wild => 'wild',
        ClashKind.wildFour => 'wild draw four',
      };
}

class _CardPainter extends CustomPainter {
  final ClashCard c;
  _CardPainter(this.c);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final outer =
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(w * 0.13));
    canvas.drawRRect(
        outer,
        Paint()
          ..shader = const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFFDF6), Color(0xFFF5E9D2)])
              .createShader(Offset.zero & size));
    final field = RRect.fromRectAndRadius(
        (Offset.zero & size).deflate(w * 0.07), Radius.circular(w * 0.09));
    final bg = clashColors[c.color]!;
    canvas.drawRRect(field, Paint()..color = bg);
    canvas.save();
    canvas.clipRRect(field);
    // The tilted oval in the middle (four colours on wilds).
    canvas.save();
    canvas.translate(w / 2, h / 2);
    canvas.rotate(-0.45);
    final oval =
        Rect.fromCenter(center: Offset.zero, width: w * 0.68, height: h * 0.72);
    if (c.isWild) {
      canvas.save();
      canvas.clipPath(Path()..addOval(oval));
      const order = [
        ClashColor.red,
        ClashColor.blue,
        ClashColor.yellow,
        ClashColor.green
      ];
      for (var i = 0; i < 4; i++) {
        canvas.drawArc(oval.inflate(w), -pi / 2 + i * pi / 2, pi / 2, true,
            Paint()..color = clashColors[order[i]]!);
      }
      canvas.restore();
    } else {
      canvas.drawOval(oval, Paint()..color = Colors.white);
    }
    canvas.restore();
    // The big centre mark.
    final centre = Offset(w / 2, h / 2);
    final ink = c.isWild ? Colors.white : bg;
    switch (c.kind) {
      case ClashKind.number || ClashKind.drawTwo || ClashKind.wildFour:
        _text(
            canvas,
            c.kind == ClashKind.number
                ? '${c.number}'
                : (c.kind == ClashKind.drawTwo ? '+2' : '+4'),
            centre,
            w * (c.kind == ClashKind.number ? 0.52 : 0.4),
            ink);
      case ClashKind.skip:
        _skip(canvas, centre, w * 0.2, ink);
      case ClashKind.reverse:
        _reverse(canvas, centre, w * 0.2, ink);
      case ClashKind.wild:
        canvas.drawPath(
            PlayerShapePainter.pathFor(PlayerShape.star,
                Rect.fromCircle(center: centre, radius: w * 0.2)),
            Paint()..color = Colors.white);
    }
    // Corners: small mark and suit, top-left and (turned) bottom-right.
    for (final flip in [false, true]) {
      canvas.save();
      if (flip) {
        canvas.translate(w, h);
        canvas.rotate(pi);
      }
      final at = Offset(w * 0.2, h * 0.14);
      switch (c.kind) {
        case ClashKind.skip:
          _skip(canvas, at, w * 0.07, Colors.white);
        case ClashKind.reverse:
          _reverse(canvas, at, w * 0.07, Colors.white);
        case ClashKind.wild:
          canvas.drawPath(
              PlayerShapePainter.pathFor(PlayerShape.star,
                  Rect.fromCircle(center: at, radius: w * 0.08)),
              Paint()..color = Colors.white);
        default:
          _text(
              canvas,
              c.kind == ClashKind.number
                  ? '${c.number}'
                  : (c.kind == ClashKind.drawTwo ? '+2' : '+4'),
              at,
              w * 0.16,
              Colors.white,
              shadow: false);
      }
      if (!c.isWild)
        _paintSuit(
            canvas,
            c.color,
            Rect.fromCenter(
                center: at + Offset(0, h * 0.1),
                width: w * 0.13,
                height: w * 0.13),
            Colors.white);
      canvas.restore();
    }
    canvas.restore();
  }

  void _text(Canvas canvas, String s, Offset c, double size, Color color,
      {bool shadow = true}) {
    final tp = TextPainter(
      text: TextSpan(
          text: s,
          style: TextStyle(
              fontFamily: Fonts.display,
              fontSize: size,
              height: 1,
              color: color,
              shadows: shadow
                  ? const [
                      Shadow(color: Color(0x80000000), offset: Offset(1.5, 2))
                    ]
                  : null)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  void _skip(Canvas canvas, Offset c, double r, Color color) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.32
      ..color = color;
    canvas.drawCircle(c, r, p);
    canvas.drawLine(c + Offset(-r * 0.7, r * 0.7),
        c + Offset(r * 0.7, -r * 0.7), p..strokeCap = StrokeCap.round);
  }

  void _reverse(Canvas canvas, Offset c, double r, Color color) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.3
      ..strokeCap = StrokeCap.round
      ..color = color;
    for (final s in [-1.0, 1.0]) {
      final y = c.dy + s * r * 0.45;
      canvas.drawLine(Offset(c.dx - r, y), Offset(c.dx + r, y), p);
      final tip = Offset(c.dx + s * r, y);
      canvas.drawLine(tip, tip + Offset(-s * r * 0.5, -s * r * 0.45), p);
    }
  }

  @override
  bool shouldRepaint(_CardPainter o) => o.c.id != c.id;
}

class _ClashTable extends StatelessWidget {
  final List<GpPlayer> players;
  final ColourClashLogic g;
  final int? me; // online: whose phone this is (only their hand is shown)
  final Set<int> botSeats; // computer players sharing a pass-the-phone game
  const _ClashTable(
      {required this.players,
      required this.g,
      this.me,
      this.botSeats = const {}});

  @override
  Widget build(BuildContext context) {
    final online = me != null;
    final holder = me ?? g.turn; // whose hand is on screen
    // People passing the phone with bots: nobody's cards show while a bot plays.
    final botTurn = !online && botSeats.contains(g.turn);
    final myTurn = holder == g.turn;
    final player = players[holder];
    final hand = g.hands[holder];
    final t = context.tk;
    ResultScope.of(context)
      ?..subtitle = g.winner == null
          ? null
          : '${players[g.winner!].name} played their last card'
      ..detail = ((_, i) => Text(
          '${g.hands[i].length} ${g.hands[i].length == 1 ? 'card' : 'cards'} left',
          style: TextStyle(
              fontFamily: Fonts.body,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: NeonPalette.textMuted)));
    return MomentWatcher<int>(
      value: g.discard.length,
      onChange: (fx, before, now) {
        if (now <= before) return;
        final top = g.top;
        switch (top.kind) {
          case ClashKind.drawTwo:
            keyMoment(fx, '+2!',
                sub: g.message.isEmpty ? 'Draw two' : stripEmoji(g.message),
                sound: 'hit',
                shake: true);
          case ClashKind.wildFour:
            keyMoment(fx, '+4!',
                sub: g.message.isEmpty ? 'Draw four' : stripEmoji(g.message),
                sound: 'boom',
                buzz: HapticWeight.heavy,
                shake: true);
          case ClashKind.skip:
            fx?.pop('SKIP!');
          case ClashKind.reverse:
            fx?.pop('REVERSE!');
          default:
            if (g.winner == null && g.hands.any((h) => h.length == 1))
              fx?.pop('ONE CARD!');
        }
        if (top.kind == ClashKind.number) GameAudio.sfx('tap');
      },
      child: Stack(children: [
        Padding(
          padding:
              const EdgeInsets.fromLTRB(Space.s, Space.xs, Space.s, Space.s),
          child: Column(children: [
            ScoreHud(
              title: 'Colour Clash',
              state: g.winner != null
                  ? '${players[g.winner!].name} wins'
                  : '${possessive(players[g.turn].name)} turn',
              players: players,
              turn: g.winner != null ? null : g.turn,
              score: (i) => '${g.hands[i].length}',
              tag: (i) => g.hands[i].length == 1
                  ? 'ONE!'
                  : (i == g.turn && g.winner == null ? 'PLAYING' : null),
            ),
            const SizedBox(height: 6),
            Expanded(
                child: _Centre(
                    g: g,
                    players: players,
                    canAct: myTurn,
                    waitingFor: myTurn ? null : players[g.turn].name)),
            if (botTurn)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Text('${players[g.turn].name} is playing…',
                    style: t.styles.h3.copyWith(color: t.onBg)),
              )
            else if (online || g.phase != ClashPhase.handoff) ...[
              Row(children: [
                PlayerBadge(
                    index: PlayerPalette.indexOf(player.color) ?? holder,
                    size: 18,
                    color: player.color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                      online
                          ? 'YOUR HAND · ${hand.length} cards'
                          : '${possessive(player.name).toUpperCase()} HAND · ${hand.length} cards',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.styles.label
                          .copyWith(color: nameColor(player.color))),
                ),
                if (myTurn && hand.length == 2 && g.phase == ClashPhase.play)
                  _OneButton(called: g.calledOne, onTap: g.callOne),
                if (myTurn && g.drewThisTurn && g.phase == ClashPhase.play) ...[
                  const SizedBox(width: 6),
                  KitButton('Pass',
                      style: KitButtonStyle.soft,
                      height: 44,
                      onPressed: g.pass),
                ],
              ]),
              const SizedBox(height: 6),
              _Hand(
                  g: g,
                  hand: hand,
                  active: myTurn && g.phase == ClashPhase.play),
            ],
          ]),
        ),
        if (g.phase == ClashPhase.chooseColor && myTurn) _ColorPicker(g: g),
        if (!online && g.phase == ClashPhase.handoff)
          _Handoff(player: player, g: g),
      ]),
    );
  }
}

/// ONE! — pulses gold when you're down to two cards and haven't called it yet.
class _OneButton extends StatefulWidget {
  final bool called;
  final VoidCallback onTap;
  const _OneButton({required this.called, required this.onTap});
  @override
  State<_OneButton> createState() => _OneButtonState();
}

class _OneButtonState extends State<_OneButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700))
    ..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.called) {
      return Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: StatusColors.success.withValues(alpha: 0.2),
            borderRadius: Radii.rChip,
            border: Border.all(color: StatusColors.success)),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          GameIcon(GameIcons.check, size: 14, color: Color(0xFFB5F0CD)),
          SizedBox(width: 4),
          Text('ONE!',
              style: TextStyle(
                  fontFamily: Fonts.display,
                  fontSize: 16,
                  color: Color(0xFFB5F0CD))),
        ]),
      );
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => Transform.scale(
          scale: Motion.reduced(context) ? 1 : 1 + _c.value * 0.08,
          child: child),
      child: SizedBox(
        width: 92,
        child: GoldButton('ONE!', height: 44, fontSize: 18, onPressed: () {
          haptic(HapticWeight.medium);
          GameAudio.sfx('coin');
          widget.onTap();
        }),
      ),
    );
  }
}

/// The felt table: draw pile, the discard with a ring in the current colour, the
/// direction of play, and the last event.
class _Centre extends StatelessWidget {
  final ColourClashLogic g;
  final List<GpPlayer> players;
  final bool canAct;
  final String? waitingFor;
  const _Centre(
      {required this.g,
      required this.players,
      this.canAct = true,
      this.waitingFor});
  @override
  Widget build(BuildContext context) {
    final col =
        g.color == ClashColor.wild ? Colors.white : clashColors[g.color]!;
    final canDraw = canAct && g.phase == ClashPhase.play && !g.drewThisTurn;
    return LayoutBuilder(builder: (context, c) {
      final w = min(c.maxWidth * 0.28, (c.maxHeight - 90) * 0.62 / 1.5)
          .clamp(36.0, 130.0);
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(borderRadius: Radii.rBoard, boxShadow: const [
          BoxShadow(
              color: Color(0x80000000), blurRadius: 24, offset: Offset(0, 10))
        ]),
        child: CustomPaint(
          painter: const FeltPainter(),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Semantics(
                  button: canDraw,
                  label: 'Draw a card, ${g.drawPile.length} left',
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: canDraw
                        ? () {
                            haptic(HapticWeight.selection);
                            GameAudio.sfx('throw');
                            g.draw();
                          }
                        : null,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Stack(children: [
                        Transform.translate(
                            offset: const Offset(4, 4),
                            child: ClashCardView(card: null, width: w * 0.85)),
                        ClashCardView(
                            card: null,
                            width: w * 0.85,
                            highlight: canDraw && g.playable.isEmpty),
                      ]),
                      const SizedBox(height: 6),
                      Text('DRAW · ${g.drawPile.length}',
                          style: const TextStyle(
                              fontFamily: Fonts.body,
                              color: Color(0xFFE9C46A),
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              letterSpacing: 1.2)),
                    ]),
                  ),
                ),
                SizedBox(width: w * 0.35),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Stack(alignment: Alignment.center, children: [
                    // The direction of play, around the pile.
                    SizedBox(
                      width: w * 1.75,
                      height: w * 1.75,
                      child: CustomPaint(
                          painter: _DirectionRing(g.direction, col)),
                    ),
                    TweenAnimationBuilder<double>(
                      key: ValueKey(g.top.id),
                      tween: Tween(
                          begin: Motion.reduced(context) ? 1 : 0.6, end: 1),
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutBack,
                      builder: (_, s, child) =>
                          Transform.scale(scale: s, child: child),
                      child: ClashCardView(card: g.top, width: w),
                    ),
                  ]),
                  Text('COLOUR: ${_colourName(g.color).toUpperCase()}',
                      style: TextStyle(
                          fontFamily: Fonts.body,
                          color: g.color == ClashColor.wild
                              ? Colors.white
                              : Color.lerp(col, Colors.white, 0.3),
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          letterSpacing: 1.2)),
                ]),
              ]),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                [
                  if (waitingFor != null) '${possessive(waitingFor!)} turn',
                  g.message.isEmpty && waitingFor == null
                      ? 'Match the colour, number or symbol'
                      : stripEmoji(g.message)
                ].where((t) => t.isNotEmpty).join(' · '),
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(
                    fontFamily: Fonts.body,
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5),
              ),
            ),
          ]),
        ),
      );
    });
  }
}

/// A ring in the current colour with arrows showing which way play goes.
class _DirectionRing extends CustomPainter {
  final int direction;
  final Color color;
  _DirectionRing(this.direction, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 4;
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = color.withValues(alpha: 0.75));
    final p = Paint()..color = color;
    for (var k = 0; k < 3; k++) {
      final a = -pi / 2 + k * 2 * pi / 3;
      final at = c + Offset(cos(a), sin(a)) * r;
      final tangent = Offset(-sin(a), cos(a)) * direction.toDouble();
      final normal = Offset(cos(a), sin(a));
      canvas.drawPath(
          Path()
            ..moveTo((at + tangent * 9).dx, (at + tangent * 9).dy)
            ..lineTo((at - tangent * 3 + normal * 7).dx,
                (at - tangent * 3 + normal * 7).dy)
            ..lineTo((at - tangent * 3 - normal * 7).dx,
                (at - tangent * 3 - normal * 7).dy)
            ..close(),
          p);
    }
  }

  @override
  bool shouldRepaint(_DirectionRing o) =>
      o.direction != direction || o.color != color;
}

/// Your hand, fanned along the bottom: playable cards lift and glow.
class _Hand extends StatelessWidget {
  final ColourClashLogic g;
  final List<ClashCard> hand;
  final bool active;
  const _Hand({required this.g, required this.hand, required this.active});
  @override
  Widget build(BuildContext context) {
    final playable =
        active ? g.playable.map((c) => c.id).toSet() : const <int>{};
    return SizedBox(
      height: 118,
      child: LayoutBuilder(builder: (context, c) {
        const cw = 62.0;
        final n = hand.length;
        // Overlap so the whole hand fits; never more spread than a small gap.
        final step = n <= 1 ? 0.0 : min(cw + 6, (c.maxWidth - cw) / (n - 1));
        final total = cw + step * (n - 1);
        final left0 = (c.maxWidth - total) / 2;
        return Stack(clipBehavior: Clip.none, children: [
          for (var i = 0; i < n; i++)
            Builder(builder: (context) {
              final card = hand[i];
              final ok = active && playable.contains(card.id);
              final mid = (n - 1) / 2;
              final angle = n <= 1 ? 0.0 : (i - mid) / max(mid, 1) * 0.12;
              return Positioned(
                left: left0 + i * step,
                top: 14 + ((i - mid).abs() / max(mid, 1)) * 6,
                child: Semantics(
                  button: ok,
                  label:
                      '${_colourName(card.color)} ${ClashCardView._spoken(card)}${ok ? ', playable' : ''}',
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: ok
                        ? () {
                            haptic(HapticWeight.light);
                            GameAudio.sfx('tap');
                            g.play(card.id);
                          }
                        : null,
                    child: AnimatedSlide(
                      duration: Motion.of(context, Motion.normal),
                      offset: Offset(0, ok ? -0.12 : 0),
                      child: Transform.rotate(
                          angle: angle,
                          child: ClashCardView(
                              card: card,
                              width: cw,
                              highlight: ok,
                              dim: active && !ok)),
                    ),
                  ),
                ),
              );
            }),
        ]);
      }),
    );
  }
}

class _ColorPicker extends StatelessWidget {
  final ColourClashLogic g;
  const _ColorPicker({required this.g});
  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: ColoredBox(
          color: const Color(0x9E060820),
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                  color: NeonPalette.sheet,
                  borderRadius: BorderRadius.circular(28),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.14)),
                  boxShadow: Shadows.large),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Pick a colour',
                    style: TextStyle(
                        fontFamily: Fonts.display,
                        color: Colors.white,
                        fontSize: 26)),
                const SizedBox(height: 14),
                Wrap(spacing: 14, runSpacing: 14, children: [
                  for (final c in [
                    ClashColor.red,
                    ClashColor.yellow,
                    ClashColor.green,
                    ClashColor.blue
                  ])
                    Semantics(
                      button: true,
                      label: c.name,
                      excludeSemantics: true,
                      child: GestureDetector(
                        onTap: () {
                          haptic(HapticWeight.selection);
                          g.chooseColor(c);
                        },
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                                color: clashColors[c],
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 3),
                                boxShadow: Shadows.edge(
                                    Color.lerp(
                                        clashColors[c]!, Colors.black, 0.4)!,
                                    depth: 4)),
                            child: CustomPaint(painter: _SuitPainter(c)),
                          ),
                          const SizedBox(height: 4),
                          Text(c.name.toUpperCase(),
                              style: const TextStyle(
                                  fontFamily: Fonts.body,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                  letterSpacing: 1)),
                        ]),
                      ),
                    ),
                ]),
              ]),
            ),
          ),
        ),
      );
}

class _SuitPainter extends CustomPainter {
  final ClashColor c;
  _SuitPainter(this.c);
  @override
  void paint(Canvas canvas, Size size) => _paintSuit(
      canvas,
      c,
      Rect.fromCenter(
          center: size.center(Offset.zero),
          width: size.width * 0.45,
          height: size.height * 0.45),
      Colors.white);
  @override
  bool shouldRepaint(_SuitPainter o) => o.c != c;
}

/// Hides the hands while the phone changes hands (the table stays visible above it).
class _Handoff extends StatelessWidget {
  final GpPlayer player;
  final ColourClashLogic g;
  const _Handoff({required this.player, required this.g});
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(Space.l, Space.l, Space.l, Space.xl),
        decoration: BoxDecoration(
          color: NeonPalette.sheet,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: player.color, width: 3)),
          boxShadow: t.shadowLg,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            PlayerBadge(
                index: PlayerPalette.indexOf(player.color) ?? 0,
                size: 40,
                color: player.color,
                initial: player.name),
            const SizedBox(width: Space.m),
            Flexible(
              child: Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'Pass to '),
                  TextSpan(
                      text: player.name,
                      style: TextStyle(color: nameColor(player.color)))
                ]),
                style: const TextStyle(
                    fontFamily: Fonts.display,
                    fontSize: 24,
                    color: Colors.white),
              ),
            ),
          ]),
          const SizedBox(height: Space.xs),
          Text('Everyone else, no peeking at the cards!',
              textAlign: TextAlign.center,
              style: t.styles.body.copyWith(color: NeonPalette.textMuted)),
          const SizedBox(height: Space.m),
          HoldToReveal(
              label: 'Hold to see my cards',
              color: player.color,
              onRevealed: g.reveal),
        ]),
      ),
    );
  }
}
