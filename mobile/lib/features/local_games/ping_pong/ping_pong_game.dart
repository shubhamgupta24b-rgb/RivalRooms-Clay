import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/ui/components.dart';
import 'package:flutter/services.dart';
import '../../guess_person/models/gp_player.dart';
import '../air_hockey/air_hockey_game.dart' show V;
import '../shell/local_game_info.dart';
import '../shell/local_game_shell.dart' show PauseButton;
import '../shell/local_game_logic.dart';
import '../shell/ticking_play.dart';

/// Ping pong on a 1 x [length] table. Player 1's paddle is at the bottom, player 2's at
/// the top; each slides theirs left and right. Where the ball hits the paddle sets its
/// angle, and every hit speeds it up. First to [target] points.
class PingPongLogic extends LocalGameLogic {
  static const length = 1.6,
      ballR = 0.03,
      paddleHalf = 0.13,
      paddleY = 0.09,
      startSpeed = 0.95,
      maxSpeed = 2.4;
  final int target;
  final Random _rng;
  final List<int> points = [0, 0];
  final List<double> paddleX = [0.5, 0.5];
  V ball = const V(0.5, length / 2);
  V vel = V.zero;
  double speed = startSpeed;
  int? lastPointTo;
  int _now = 0, _last = 0;
  int? _serveAt = 900;
  int _serveTo = 0;

  PingPongLogic({this.target = 7, Random? random}) : _rng = random ?? Random() {
    _serveTo = _rng.nextInt(2);
  }

  @override
  List<int> get scores => points;
  @override
  bool get finished => points.any((p) => p >= target);
  bool get waitingToServe => _serveAt != null;

  void movePaddle(int p, double x) {
    paddleX[p] = x.clamp(paddleHalf,
        1 - paddleHalf); // online: shown straight away, host has the final say
    if (forward('paddle', [p, x])) changed();
  }

  /// Y of each player's paddle face: bottom for player 1, top for player 2.
  static double paddleLine(int p) => p == 0 ? length - paddleY : paddleY;

  @override
  void update(int elapsedMs) {
    _now = elapsedMs;
    final dt = ((_now - _last) / 1000).clamp(0.0, 0.05);
    _last = _now;
    if (finished) return;
    final serve = _serveAt;
    if (serve != null) {
      if (_now < serve) return notifyListeners();
      _serveAt = null;
      speed = startSpeed;
      final angle = (_rng.nextDouble() - 0.5) * 0.9;
      ball = const V(0.5, length / 2);
      vel = V(sin(angle), _serveTo == 0 ? cos(angle) : -cos(angle)) * speed;
    }
    for (var i = 0; i < 4; i++) {
      _step(dt / 4);
      if (_serveAt != null) break;
    }
    notifyListeners();
  }

  void _step(double dt) {
    ball = ball + vel * dt;
    if (ball.x < ballR && vel.x < 0 || ball.x > 1 - ballR && vel.x > 0)
      vel = V(-vel.x, vel.y);
    for (var p = 0; p < 2; p++) {
      final y = paddleLine(p);
      final towards = p == 0 ? vel.y > 0 : vel.y < 0;
      final reached = p == 0 ? ball.y + ballR >= y : ball.y - ballR <= y;
      final notPast = p == 0 ? ball.y < y + 0.03 : ball.y > y - 0.03;
      if (towards &&
          reached &&
          notPast &&
          (ball.x - paddleX[p]).abs() <= paddleHalf + ballR) {
        // Hit: the further from the centre, the sharper the angle.
        final offset = ((ball.x - paddleX[p]) / paddleHalf).clamp(-1.0, 1.0);
        speed = min(maxSpeed, speed * 1.07);
        final angle = offset * 1.0;
        vel = V(sin(angle), p == 0 ? -cos(angle) : cos(angle)) * speed;
        HapticFeedback.selectionClick().ignore();
      }
    }
    if (ball.y > length + ballR) return _point(1);
    if (ball.y < -ballR) return _point(0);
  }

  void _point(int to) {
    points[to]++;
    lastPointTo = to;
    vel = V.zero;
    ball = const V(0.5, length / 2);
    _serveTo = 1 - to; // serve towards the player who lost the point
    _serveAt = _now + 900;
  }
}

final pingPongInfo = LocalGameInfo(
  id: 'ping_pong',
  title: 'Ping Pong',
  emoji: '🏓',
  color: const Color(0xFFFF9F43),
  tagline: "Don't let it past you!",
  rules: const [
    'Slide your finger left and right on your half to move your paddle.',
    'Hit the ball with the edge of the paddle to angle it. It speeds up every hit.',
    'If the ball gets past your paddle, your rival scores. First to 7 wins.',
  ],
  scoreUnit: 'points',
  splitScreen: true,
  bot: botFor<PingPongLogic>((g, b, now) {
    final last = (b.memory['t'] as int?) ?? now;
    b.memory['t'] = now;
    final dt = ((now - last) / 1000).clamp(0.0, 0.05);
    // Follow the ball when it's coming, aiming a little off-centre (for angle) and a little late.
    final coming = b.seat == 1 ? g.vel.y < 0 : g.vel.y > 0;
    final aimOff = (b.memory['off'] as double?) ?? 0.0;
    if (!coming) {
      b.memory['off'] = (b.rng.nextDouble() - 0.5) * (0.08 + b.skill.aimError);
    }
    final target = coming ? g.ball.x + aimOff + b.aimNoise(0.35) : 0.5;
    final x = g.paddleX[b.seat];
    final step = 0.95 * b.skill.tracking * dt;
    g.movePaddle(b.seat, x + (target - x).clamp(-step, step));
  }),
  online: RelaySpec<PingPongLogic>(
    create: (n) => PingPongLogic(),
    save: (g) => {
      'points': g.points,
      'paddles': g.paddleX,
      'ball': [g.ball.x, g.ball.y],
      'last': g.lastPointTo,
      'serving': g.waitingToServe,
    },
    load: (g, s, me) {
      g.points.setAll(0, ints(s['points']));
      final pads = doubles(s['paddles']);
      for (var i = 0; i < 2; i++) {
        if (i != me) g.paddleX[i] = pads[i];
      }
      final b = doubles(s['ball']);
      g.ball = V(b[0], b[1]);
      g.lastPointTo = nInt(s['last']);
      g._serveAt = s['serving'] == true ? 1 << 40 : null;
    },
    apply: (g, from, name, a) {
      if (name == 'paddle' && asInt(a[0]) == from)
        g.movePaddle(from, asDouble(a[1]));
    },
    continuous: const {'paddle'},
    view: (context, g, players, me) => RotatedBox(
      quarterTurns: me == 1 ? 2 : 0,
      child: _PongFrame(players: players, g: g),
    ),
  ),
  play: (players, onFinished) => TickingPlay<PingPongLogic>(
    create: () => PingPongLogic(),
    onFinished: onFinished,
    builder: (context, g) => _PongFrame(players: players, g: g),
  ),
);

/// Scores sit beside the table. The pause button is above the play surface.
class _PongFrame extends StatelessWidget {
  final List<GpPlayer> players;
  final PingPongLogic g;
  const _PongFrame({required this.players, required this.g});

  @override
  Widget build(BuildContext context) {
    final farUpright = BotScope.isBot(context, 1);
    Widget score(GpPlayer player, int value, {bool upright = true}) {
      final chip = SizedBox(
        width: 64,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(player.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w800)),
          Text('$value',
              style: TextStyle(
                  fontFamily: Fonts.display,
                  fontSize: 32,
                  height: 1,
                  color: player.color)),
        ]),
      );
      return RotatedBox(quarterTurns: upright ? 0 : 2, child: chip);
    }

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 12, 0),
        child: Row(children: [
          const PauseButton(),
          const Spacer(),
          Text('FIRST TO ${g.target}',
              style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1)),
        ]),
      ),
      Expanded(
        child: Row(children: [
          score(players[0], g.scores[0]),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: _PongTable(players: players, g: g),
            ),
          ),
          score(players[1], g.scores[1], upright: farUpright),
        ]),
      ),
    ]);
  }
}

class _PongTable extends StatefulWidget {
  final List<GpPlayer> players;
  final PingPongLogic g;
  const _PongTable({required this.players, required this.g});
  @override
  State<_PongTable> createState() => _PongTableState();
}

class _PongTableState extends State<_PongTable> {
  final _fingers = <int, int>{};
  Rect _table = Rect.zero;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = min(c.maxWidth, c.maxHeight / PingPongLogic.length);
      final h = w * PingPongLogic.length;
      _table = Rect.fromLTWH((c.maxWidth - w) / 2, (c.maxHeight - h) / 2, w, h);
      void move(PointerEvent e) {
        final p = _fingers[e.pointer];
        if (p != null)
          widget.g
              .movePaddle(p, (e.localPosition.dx - _table.left) / _table.width);
      }

      return Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) {
          _fingers[e.pointer] = e.localPosition.dy > c.maxHeight / 2 ? 0 : 1;
          move(e);
        },
        onPointerMove: move,
        onPointerUp: (e) => _fingers.remove(e.pointer),
        onPointerCancel: (e) => _fingers.remove(e.pointer),
        child: CustomPaint(
            size: c.biggest,
            painter: _PongPainter(
                widget.g, _table, widget.players.map((p) => p.color).toList())),
      );
    });
  }
}

class _PongPainter extends CustomPainter {
  final PingPongLogic g;
  final Rect table;
  final List<Color> colors;
  final V ball;
  final List<double> paddles;
  _PongPainter(this.g, this.table, this.colors)
      : ball = g.ball,
        paddles = List.of(g.paddleX);

  // Table palette: tournament blue with white lines.
  static const _top = [Color(0xFF2361B8), Color(0xFF184A92)];
  static const _edge = Color(0xFF0E2A55);

  @override
  void paint(Canvas canvas, Size size) {
    final s = table.width;
    Offset at(double x, double y) =>
        Offset(table.left + x * s, table.top + y * s);
    final top = RRect.fromRectAndRadius(table, Radius.circular(s * 0.03));
    // Table edge and shadow give it thickness.
    canvas.drawRRect(top.shift(Offset(0, s * 0.025)), Paint()..color = _edge);
    canvas.drawRRect(
        top.shift(Offset(0, s * 0.05)), Paint()..color = Colors.black38);
    canvas.drawRRect(
        top,
        Paint()
          ..shader = const LinearGradient(
                  colors: _top,
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter)
              .createShader(table));
    final white = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(top.deflate(4), white);
    canvas.drawLine(
        at(0.5, 0),
        at(0.5, PingPongLogic.length),
        Paint()
          ..color = Colors.white60
          ..strokeWidth = 2);
    // The net across the middle, with its posts.
    final ny = PingPongLogic.length / 2;
    canvas.drawLine(
        at(0, ny) + const Offset(0, 5),
        at(1, ny) + const Offset(0, 5),
        Paint()
          ..color = Colors.black26
          ..strokeWidth = 6);
    canvas.drawLine(
        at(-0.02, ny),
        at(1.02, ny),
        Paint()
          ..color = const Color(0xFFF2F2F2)
          ..strokeWidth = 5);
    for (final x in [-0.03, 1.03]) {
      canvas.drawCircle(at(x, ny), 6, Paint()..color = const Color(0xFF222630));
    }
    // Bats: a rubber face in the player's colour with a wooden handle behind it.
    for (var p = 0; p < 2; p++) {
      final y = PingPongLogic.paddleLine(p);
      final c = at(paddles[p], y + (p == 0 ? 0.0125 : -0.0125));
      final w = PingPongLogic.paddleHalf * 2 * s, h = 0.03 * s;
      final handle = Rect.fromCenter(
          center: c + Offset(0, (p == 0 ? 1 : -1) * h * 1.3),
          width: w * 0.22,
          height: h * 1.6);
      canvas.drawRRect(
          RRect.fromRectAndRadius(handle, Radius.circular(h * 0.3)),
          Paint()..color = const Color(0xFFB07A45));
      final face = RRect.fromRectAndRadius(
          Rect.fromCenter(center: c, width: w, height: h),
          Radius.circular(h / 2));
      canvas.drawRRect(
          face.shift(const Offset(0, 3)), Paint()..color = Colors.black38);
      canvas.drawRRect(
          face,
          Paint()
            ..shader = LinearGradient(colors: [
              Color.lerp(colors[p], Colors.white, 0.3)!,
              colors[p]
            ], begin: Alignment.topCenter, end: Alignment.bottomCenter)
                .createShader(face.outerRect));
    }
    if (!g.waitingToServe || g.lastPointTo == null) {
      final b = at(ball.x, ball.y), br = PingPongLogic.ballR * s;
      canvas.drawCircle(
          b + const Offset(3, 5), br, Paint()..color = Colors.black38);
      canvas.drawCircle(
          b,
          br,
          Paint()
            ..shader = RadialGradient(
                    center: const Alignment(-0.35, -0.4),
                    colors: const [Colors.white, Color(0xFFFFE0B2)])
                .createShader(Rect.fromCircle(center: b, radius: br)));
    }
    if (g.waitingToServe) {
      final text = g.lastPointTo == null ? 'GET READY' : 'POINT!';
      final tp = TextPainter(
        text: TextSpan(
            text: text,
            style: const TextStyle(
                fontFamily: Fonts.display,
                color: Brand.gold,
                fontSize: 44,
                shadows: [
                  Shadow(
                      color: Colors.black54,
                      blurRadius: 8,
                      offset: Offset(0, 3))
                ])),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, table.center - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_PongPainter old) => true;
}
