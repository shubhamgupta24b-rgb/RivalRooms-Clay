import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../guess_person/models/gp_player.dart';
import '../../../core/ui/components.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/split_screen.dart';
import '../shell/ticking_play.dart';

/// Two snakes that never stop growing (light-bike rules). Hitting a wall or any trail
/// loses the round; crashing at the same moment is a tie. Turning is relative (left or
/// right of where you're heading), so it works the same from both ends of the phone.
class SnakeDuelLogic extends LocalGameLogic {
  static const _dx = [0, 1, 0, -1]; // up, right, down, left
  static const _dy = [-1, 0, 1, 0];
  final int cols, rows, stepMs, target, pauseMs;
  final List<int> score = [0, 0];
  late List<int> owner; // -1 empty, else player
  final List<int> head = [0, 0];
  final List<int> dir = [0, 2];
  final List<int?> _queued = [null, null];
  int round = 0;
  int? roundWinner; // -1 = tie
  int _now = 0;
  int _nextStep = 700; // a moment to get ready before the first move
  int? _nextRoundAt;

  SnakeDuelLogic(
      {this.cols = 18,
      this.rows = 26,
      this.stepMs = 130,
      this.target = 3,
      this.pauseMs = 1400}) {
    _reset();
  }

  void _reset() {
    owner = List.filled(cols * rows, -1);
    head[0] =
        (rows - 3) * cols + cols ~/ 2; // player 1 starts at the bottom going up
    head[1] = 2 * cols + cols ~/ 2 - 1; // player 2 at the top going down
    dir[0] = 0;
    dir[1] = 2;
    _queued[0] = _queued[1] = null;
    owner[head[0]] = 0;
    owner[head[1]] = 1;
    roundWinner = null;
  }

  @override
  List<int> get scores => score;
  @override
  bool get finished => score.any((s) => s >= target) && _nextRoundAt == null;
  bool get betweenRounds => roundWinner != null;

  /// Turn left (-1) or right (+1) relative to the current heading; applied on the next step.
  void turn(int player, int side) {
    if (forward('turn', [player, side])) return;
    if (betweenRounds || finished) return;
    _queued[player] = (dir[player] + side + 4) % 4;
  }

  @override
  void update(int elapsedMs) {
    _now = elapsedMs;
    final next = _nextRoundAt;
    if (next != null) {
      if (_now >= next) {
        _nextRoundAt = null;
        if (!score.any((s) => s >= target)) {
          round++;
          _reset();
          _nextStep = _now + stepMs;
        }
        notifyListeners();
      }
      return;
    }
    if (finished) return;
    var changed = false;
    while (_now >= _nextStep && roundWinner == null) {
      _step();
      _nextStep += stepMs;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  void _step() {
    final crashed = [false, false];
    final next = [0, 0];
    for (var p = 0; p < 2; p++) {
      if (_queued[p] != null) dir[p] = _queued[p]!;
      _queued[p] = null;
      final x = head[p] % cols + _dx[dir[p]], y = head[p] ~/ cols + _dy[dir[p]];
      if (x < 0 || x >= cols || y < 0 || y >= rows) {
        crashed[p] = true;
        next[p] = head[p];
      } else {
        next[p] = y * cols + x;
        if (owner[next[p]] >= 0) crashed[p] = true;
      }
    }
    if (!crashed[0] && !crashed[1] && next[0] == next[1])
      crashed[0] = crashed[1] = true; // head-on
    for (var p = 0; p < 2; p++) {
      if (!crashed[p]) {
        head[p] = next[p];
        owner[next[p]] = p;
      }
    }
    if (crashed[0] || crashed[1]) {
      roundWinner = crashed[0] && crashed[1] ? -1 : (crashed[0] ? 1 : 0);
      if (roundWinner! >= 0) score[roundWinner!]++;
      _nextRoundAt = _now + pauseMs;
    }
  }
}

final snakeDuelInfo = LocalGameInfo(
  id: 'snake_duel',
  title: 'Snake Duel',
  emoji: '🐍',
  color: const Color(0xFF00B894),
  tagline: "Trap your rival, don't crash!",
  rules: const [
    'Your snake moves on its own and leaves a trail that never goes away.',
    'Tap the left or right arrow at your end to turn.',
    'Hit a wall or any trail and you lose the round. First to 3 rounds wins.',
  ],
  scoreUnit: 'rounds',
  splitScreen: true,
  bot: botFor<SnakeDuelLogic>((g, b, now) {
    if (g.finished || g.betweenRounds || !b.due(now)) return;
    b.wait(now, 60, 110);
    const dx = [0, 1, 0, -1], dy = [-1, 0, 1, 0];
    final h = g.head[b.seat];
    bool free(int x, int y) =>
        x >= 0 &&
        x < g.cols &&
        y >= 0 &&
        y < g.rows &&
        g.owner[y * g.cols + x] < 0;
    // How much room is in a direction (a few steps of look-ahead).
    int room(int dir) {
      var x = h % g.cols, y = h ~/ g.cols, n = 0;
      for (var i = 0; i < 6; i++) {
        x += dx[dir];
        y += dy[dir];
        if (!free(x, y)) break;
        n++;
      }
      return n;
    }

    final d = g.dir[b.seat];
    final ahead = room(d), left = room((d + 3) % 4), right = room((d + 1) % 4);
    if (ahead <= 1 || (b.chance(0.04) && max(left, right) > ahead)) {
      if (left == 0 && right == 0) return;
      g.turn(b.seat, left > right || (left == right && b.chance(0.5)) ? -1 : 1);
    }
  }),
  online: RelaySpec<SnakeDuelLogic>(
    create: (n) => SnakeDuelLogic(),
    save: (g) => {
      'score': g.score,
      // Trails as one short string: '.' empty, '0'/'1' owner.
      'owner': String.fromCharCodes(g.owner.map((o) => o < 0 ? 46 : 48 + o)),
      'head': g.head,
      'dir': g.dir,
      'round': g.round,
      'roundWinner': g.roundWinner,
      'between': g._nextRoundAt != null,
    },
    load: (g, s, me) {
      g.score.setAll(0, ints(s['score']));
      final o = (s['owner'] as String).codeUnits;
      g.owner = [for (final c in o) c == 46 ? -1 : c - 48];
      g.head.setAll(0, ints(s['head']));
      g.dir.setAll(0, ints(s['dir']));
      g.round = asInt(s['round']);
      g.roundWinner = nInt(s['roundWinner']);
      g._nextRoundAt = s['between'] == true ? 1 << 40 : null;
    },
    apply: (g, from, name, a) {
      final side = asInt(a[1]);
      if (name == 'turn' && asInt(a[0]) == from && (side == 1 || side == -1))
        g.turn(from, side);
    },
    view: (context, g, players, me) => Column(children: [
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: RotatedBox(
              quarterTurns: me == 1 ? 2 : 0,
              child: _Arena(players: players, g: g)),
        ),
      ),
      ScoreMiddleBar(
          players: players, scores: g.scores, label: 'First to ${g.target}'),
      _Controls(player: players[me], index: me, g: g),
    ]),
  ),
  play: (players, onFinished) => TickingPlay<SnakeDuelLogic>(
    create: () => SnakeDuelLogic(),
    onFinished: onFinished,
    builder: (context, g) => Column(children: [
      RotatedBox(
          quarterTurns: 2,
          child: _Controls(player: players[1], index: 1, g: g)),
      Expanded(
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: _Arena(players: players, g: g))),
      ScoreMiddleBar(
          players: players, scores: g.scores, label: 'First to ${g.target}'),
      _Controls(player: players[0], index: 0, g: g),
    ]),
  ),
);

class _Controls extends StatelessWidget {
  final GpPlayer player;
  final int index;
  final SnakeDuelLogic g;
  const _Controls({required this.player, required this.index, required this.g});

  @override
  Widget build(BuildContext context) {
    Widget btn(GameIcons icon, String label, int side) => Expanded(
          child: Semantics(
            button: true,
            label: '${player.name}: $label',
            excludeSemantics: true,
            child: Listener(
              onPointerDown: (_) {
                g.turn(index, side);
                HapticFeedback.selectionClick().ignore();
              },
              child: Container(
                height: 72,
                margin: const EdgeInsets.fromLTRB(6, 4, 6, 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color.lerp(player.color, Colors.white, 0.18)!,
                        player.color
                      ]),
                  borderRadius: Radii.rButton,
                  boxShadow: Shadows.edge(
                      Color.lerp(player.color, Colors.black, 0.45)!,
                      depth: 5),
                ),
                child: GameIcon(icon, size: 36, color: Colors.white),
              ),
            ),
          ),
        );
    final status = g.roundWinner == null
        ? player.name
        : g.roundWinner == -1
            ? 'Tie!'
            : (g.roundWinner == index ? 'You win the round!' : 'Crash!');
    return Column(children: [
      Text(status,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontFamily: Fonts.display,
              color:
                  g.roundWinner == index ? Brand.gold : nameColor(player.color),
              fontSize: 18)),
      Row(children: [
        btn(GameIcons.arrowLeft, 'turn left', -1),
        btn(GameIcons.arrowRight, 'turn right', 1)
      ]),
    ]);
  }
}

class _Arena extends StatelessWidget {
  final List<GpPlayer> players;
  final SnakeDuelLogic g;
  const _Arena({required this.players, required this.g});
  @override
  Widget build(BuildContext context) => Center(
        child: AspectRatio(
          aspectRatio: g.cols / g.rows,
          child: Container(
            decoration: BoxDecoration(
                color: const Color(0xFF141B30),
                borderRadius: Radii.rBoard,
                border: Border.all(color: Colors.white24, width: 2),
                boxShadow: Shadows.large),
            child: CustomPaint(
                painter: _ArenaPainter(g, players.map((p) => p.color).toList(),
                    List.of(g.owner), List.of(g.head))),
          ),
        ),
      );
}

class _ArenaPainter extends CustomPainter {
  final SnakeDuelLogic g;
  final List<Color> colors;
  final List<int> owners;
  final List<int> heads;
  _ArenaPainter(this.g, this.colors, this.owners, this.heads);

  // Arena palette: a dark checkered floor.
  static const _floorA = Color(0xFF1A2440);
  static const _floorB = Color(0xFF1F2B4C);

  @override
  void paint(Canvas canvas, Size size) {
    final cw = size.width / g.cols, ch = size.height / g.rows;
    final floor = Paint();
    for (var r = 0; r < g.rows; r++) {
      for (var c = 0; c < g.cols; c++) {
        floor.color = (r + c).isEven ? _floorA : _floorB;
        canvas.drawRect(
            Rect.fromLTWH(c * cw, r * ch, cw + 0.5, ch + 0.5), floor);
      }
    }
    for (var i = 0; i < owners.length; i++) {
      final o = owners[i];
      if (o < 0) continue;
      final rect = Rect.fromLTWH(
          (i % g.cols) * cw + 1, (i ~/ g.cols) * ch + 1, cw - 2, ch - 2);
      final isHead = heads[o] == i;
      final body = RRect.fromRectAndRadius(
          rect, Radius.circular(cw * (isHead ? 0.45 : 0.3)));
      canvas.drawRRect(
          body.shift(const Offset(0, 1.5)), Paint()..color = Colors.black38);
      canvas.drawRRect(
          body,
          Paint()
            ..shader = LinearGradient(colors: [
              Color.lerp(colors[o], Colors.white, isHead ? 0.25 : 0.12)!,
              colors[o]
            ], begin: Alignment.topLeft, end: Alignment.bottomRight)
                .createShader(rect));
      if (isHead) {
        // Two eyes, so the head reads at a glance.
        for (final dx in [-0.2, 0.2]) {
          final e = rect.center + Offset(rect.width * dx, -rect.height * 0.08);
          canvas.drawCircle(e, cw * 0.14, Paint()..color = Colors.white);
          canvas.drawCircle(e, cw * 0.07, Paint()..color = Colors.black);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_ArenaPainter old) => true;
}
