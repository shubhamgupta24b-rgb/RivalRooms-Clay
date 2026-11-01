import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/ui/components.dart';
import '../../guess_person/models/gp_player.dart';
import '../shell/local_game_info.dart';
import '../shell/split_screen.dart';
import '../shell/ticking_play.dart';
import '../shell/turns_play.dart';
import 'ring_sort_logic.dart';

export 'ring_sort_logic.dart';

// Candy colours, picked to stay easy to tell apart (same family as Ball Sort).
const _ringColors = [
  Color(0xFFFF4D6D),
  Color(0xFF3A86FF),
  Color(0xFFFFBE0B),
  Color(0xFF2EC4B6),
  Color(0xFF9B5DE5),
  Color(0xFFFF8C42),
];
const _wood = [Color(0xFFD9A56B), Color(0xFF8A5A2E)];

final LocalGameInfo ringSortInfo = LocalGameInfo(
  id: 'ring_sort',
  title: 'Ring Sort Race',
  emoji: '🍩',
  color: const Color(0xFF9B5DE5),
  tagline: 'Same puzzle for everyone. Sort the rings fastest!',
  rules: const [
    'Tap a peg to pick up its top rings, then tap another peg to drop them on the same colour or an empty peg.',
    'Get every peg down to one colour to clear the level. The next level adds a colour.',
    'Everyone gets the same puzzles. Most levels cleared when the time runs out wins! Stuck? Undo or reset the level.',
    'Take turns (the whole screen for 1-5 minutes each) or split the screen and race at once (2 minutes). 2 to 4 players.',
  ],
  scoreUnit: 'levels',
  splitScreen: true,
  maxPlayers: 4,
  bot: botFor<RingSortRace>((g, b, now) {
    final board = g.boards[b.seat];
    if (g.finished || board.clearedAt != null) return;
    // Plan the rest of the level once, then make one move per "think".
    final key = '${board.level}:${board.moves}';
    if (b.memory['plan'] is! List || b.memory['planFor'] != key) {
      b.memory['plan'] = solveRings(board.pegs) ?? const <(int, int)>[];
      b.memory['planFor'] = key;
    }
    if (!b.thinkFirst(key, now, 900, 1900)) return;
    final plan = b.memory['plan'] as List;
    if (plan.isEmpty) {
      g.reset(b.seat);
      return;
    }
    final (from, to) = plan.first as (int, int);
    b.memory['plan'] = plan.sublist(1);
    b.memory['planFor'] = '${board.level}:${board.moves + 1}';
    g.move(b.seat, from, to);
  }),
  online: RelaySpec<RingSortRace>(
    create: (n) => RingSortRace(players: n),
    save: (g) => g.save(),
    load: (g, s, me) => g.load(s),
    apply: (g, from, name, a) {
      if (asInt(a[0]) != from) return;
      switch (name) {
        case 'move':
          g.move(from, asInt(a[1]), asInt(a[2]));
        case 'undo':
          g.undo(from);
        case 'reset':
          g.reset(from);
      }
    },
    view: (context, g, players, me) =>
        _RaceOnline(g: g, players: players, me: me),
  ),
  // One phone: each player gets the whole screen for the chosen time.
  turns: TurnsSpec(
    play: (player, ms, onDone) => TickingPlay<RingSortRace>(
      create: () => RingSortRace(players: 1, durationMs: ms),
      onFinished: (s) => onDone(s.first),
      builder: (context, g) => Column(children: [
        TurnBar(
            player: player,
            score: g.boards.first.cleared,
            secondsLeft: g.secondsLeft),
        Expanded(
            child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
                child: _BoardPanel(g: g, index: 0, big: true))),
      ]),
    ),
    simulate: (ms, rng) => simulateTurn(
        RingSortRace(players: 1, durationMs: ms, random: rng),
        ringSortInfo.bot!,
        ms,
        rng),
  ),
  play: (players, onFinished) => TickingPlay<RingSortRace>(
    create: () => RingSortRace(players: players.length),
    onFinished: onFinished,
    builder: (context, g) => PlayerZones(
      count: players.length,
      middle: ScoreMiddleBar(
          players: players, scores: g.scores, label: '${g.secondsLeft}s'),
      center: ZoneCenterChip('${g.secondsLeft}s'),
      zone: (i) => _RaceZone(g: g, player: players[i], index: i),
    ),
  ),
);

/// One player's corner of a split screen: name, level and score, then their pegs.
class _RaceZone extends StatelessWidget {
  final RingSortRace g;
  final GpPlayer player;
  final int index;
  const _RaceZone({required this.g, required this.player, required this.index});

  @override
  Widget build(BuildContext context) {
    final b = g.boards[index];
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Column(children: [
        Row(children: [
          PlayerBadge(
              index: PlayerPalette.indexOf(player.color) ?? index,
              size: 22,
              color: player.color,
              initial: player.name),
          const SizedBox(width: 6),
          Expanded(
              child: Text(player.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontFamily: Fonts.body,
                      color: nameColor(player.color),
                      fontWeight: FontWeight.w900,
                      fontSize: 14))),
          Text('LV ${b.level}  ',
              style: const TextStyle(
                  fontFamily: Fonts.body,
                  color: Colors.white70,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 1)),
          Text('${b.cleared}',
              style: const TextStyle(
                  fontFamily: Fonts.display,
                  color: Colors.white,
                  fontSize: 22,
                  fontFeatures: [FontFeature.tabularFigures()])),
        ]),
        const SizedBox(height: 4),
        Expanded(child: _BoardPanel(g: g, index: index)),
      ]),
    );
  }
}

/// Online: your own pegs big, everyone's levels above them.
class _RaceOnline extends StatelessWidget {
  final RingSortRace g;
  final List<GpPlayer> players;
  final int me;
  const _RaceOnline({required this.g, required this.players, required this.me});

  @override
  Widget build(BuildContext context) => Column(children: [
        ScoreMiddleBar(
            players: players, scores: g.scores, label: '${g.secondsLeft}s'),
        Expanded(child: _RaceZone(g: g, player: players[me], index: me)),
      ]);
}

/// The pegs plus Undo / Reset, with a "cleared" flash between levels.
class _BoardPanel extends StatelessWidget {
  final RingSortRace g;
  final int index;
  final bool big;
  const _BoardPanel({required this.g, required this.index, this.big = false});

  @override
  Widget build(BuildContext context) {
    final b = g.boards[index];
    final enabled = !g.finished && b.clearedAt == null;
    return Column(children: [
      Expanded(
        child: Stack(children: [
          Positioned.fill(
              child: _PegsView(
                  board: b, enabled: enabled, onTap: (p) => g.tap(index, p))),
          if (b.clearedAt != null)
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                    color: StatusColors.success,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black38,
                          blurRadius: 8,
                          offset: Offset(0, 3))
                    ]),
                child: Text('LEVEL ${b.level} CLEARED!',
                    style: TextStyle(
                        fontFamily: Fonts.display,
                        color: Colors.white,
                        fontSize: big ? 22 : 15)),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 4),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        RoundButton(
            icon: GameIcons.undo,
            label: 'Undo',
            size: big ? 48 : 36,
            onPressed: enabled ? () => g.undo(index) : null),
        const SizedBox(width: 12),
        Text('${b.moves} moves',
            style: TextStyle(
                fontFamily: Fonts.body,
                color: Colors.white70,
                fontWeight: FontWeight.w800,
                fontSize: big ? 14 : 11)),
        const SizedBox(width: 12),
        RoundButton(
            icon: GameIcons.restart,
            label: 'Reset level',
            size: big ? 48 : 36,
            onPressed: enabled ? () => g.reset(index) : null),
      ]),
    ]);
  }
}

/// Every peg of a board, in one or two rows sized to fit; tap a peg to pick it or drop on it.
class _PegsView extends StatelessWidget {
  final RingBoard board;
  final bool enabled;
  final void Function(int peg) onTap;
  const _PegsView(
      {required this.board, required this.enabled, required this.onTap});

  static const _aspect = 1.75; // a peg's cell: height / width

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final n = board.pegs.length;
      // Pick one or two rows, whichever gives bigger pegs.
      var best = (rows: 1, perRow: n, w: 0.0);
      for (final rows in [1, 2]) {
        final perRow = (n / rows).ceil();
        final w = min(c.maxWidth / perRow, c.maxHeight / rows / _aspect);
        if (w > best.w) best = (rows: rows, perRow: perRow, w: w);
      }
      final w = min(best.w, 110.0), h = w * _aspect;
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (var r = 0; r < best.rows; r++)
            Row(mainAxisSize: MainAxisSize.min, children: [
              for (var p = r * best.perRow;
                  p < min(n, (r + 1) * best.perRow);
                  p++)
                Semantics(
                  button: true,
                  label: 'Peg ${p + 1}, ${board.pegs[p].length} rings',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: enabled
                        ? () {
                            HapticFeedback.selectionClick().ignore();
                            onTap(p);
                          }
                        : null,
                    child: CustomPaint(
                        size: Size(w, h),
                        painter: _PegPainter(board.pegs[p],
                            picked: board.selected == p)),
                  ),
                ),
            ]),
        ]),
      );
    });
  }
}

/// A wooden peg on a little base, with its rings stacked on it. The picked-up rings float above.
class _PegPainter extends CustomPainter {
  final List<int> rings;
  final bool picked;
  _PegPainter(this.rings, {required this.picked});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cx = w / 2;
    final baseH = h * 0.07, baseTop = h - baseH - h * 0.03;
    final ringH = h * 0.135, ringW = w * 0.8;
    final poleTop = baseTop - ringH * ringCapacity - ringH * 0.35;
    final done = pegDone(rings);

    // Pole: a rounded dowel with a highlight.
    final pole = RRect.fromRectAndRadius(
        Rect.fromLTRB(cx - w * 0.05, poleTop, cx + w * 0.05, baseTop + 2),
        Radius.circular(w * 0.05));
    canvas.drawRRect(
        pole,
        Paint()
          ..shader = const LinearGradient(
                  colors: [Color(0xFFF0C48E), Color(0xFFB07A44)])
              .createShader(pole.outerRect));
    // Base.
    final base = RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.06, baseTop, w * 0.88, baseH),
        Radius.circular(baseH / 2));
    canvas.drawRRect(
        base.shift(const Offset(0, 3)), Paint()..color = Colors.black26);
    canvas.drawRRect(
        base,
        Paint()
          ..shader = const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: _wood)
              .createShader(base.outerRect));
    if (done || picked) {
      canvas.drawRRect(
          base.inflate(2),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = done ? StatusColors.success : Brand.gold);
    }

    // The top run of one colour lifts above the pole when picked.
    var run = 0;
    if (picked && rings.isNotEmpty) {
      run = 1;
      while (
          run < rings.length && rings[rings.length - 1 - run] == rings.last) {
        run++;
      }
    }
    for (var i = 0; i < rings.length; i++) {
      final lifted = i >= rings.length - run;
      final y = lifted
          ? poleTop - ringH * 0.5 - (rings.length - 1 - i) * ringH * 0.92
          : baseTop - (i + 1) * ringH * 0.94;
      _ring(
          canvas,
          Rect.fromCenter(
              center: Offset(cx, y + ringH / 2), width: ringW, height: ringH),
          _ringColors[rings[i] % _ringColors.length]);
    }
  }

  void _ring(Canvas canvas, Rect r, Color col) {
    final rr = RRect.fromRectAndRadius(r, Radius.circular(r.height / 2));
    canvas.drawRRect(
        rr.shift(Offset(0, r.height * 0.12)), Paint()..color = Colors.black26);
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(col, Colors.white, 0.45)!,
            col,
            Color.lerp(col, Colors.black, 0.3)!
          ],
          stops: const [0, 0.45, 1],
        ).createShader(r),
    );
    // The hole the pole goes through, and a shine along the top.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: r.center.translate(0, -r.height * 0.06),
              width: r.width * 0.16,
              height: r.height * 0.34),
          Radius.circular(r.height)),
      Paint()..color = Color.lerp(col, Colors.black, 0.45)!,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(r.left + r.width * 0.12, r.top + r.height * 0.14,
              r.width * 0.28, r.height * 0.16),
          Radius.circular(r.height)),
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(_PegPainter old) => true;
}
