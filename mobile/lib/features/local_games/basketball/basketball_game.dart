import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../guess_person/models/gp_player.dart';
import '../../../core/ui/components.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/split_screen.dart';
import '../shell/ticking_play.dart';
import '../shell/turns_play.dart';

class Shot {
  final int points;
  final double aim; // where the ball reaches hoop height, in hoop-travel units
  final double hoopX; // where the hoop was when the ball got there
  final int atMs;
  final int number; // nth shot, used to tell shots apart
  const Shot(this.points, this.aim, this.hoopX, this.atMs, this.number);
}

/// Swipe the ball up at the hoop. Positions are in "hoop units": 0 is the middle of the
/// court and the hoop slides up to [swing] either side. The hoop stays still for the
/// first [calmMs], then starts sliding, faster each second. A ball within 0.1 of the
/// rim's centre is a swish (3 pts), within 0.25 goes in (2 pts), otherwise it misses.
class BasketballLogic extends TimedDuel {
  static const flightMs = 450;
  static const calmMs = 5000;
  static const swing = 0.6;
  static const hoopPeriodMs = 3000;
  final int cooldownMs;
  final List<int> score;
  final List<int> shots;
  final List<int> _lastShotAt;
  final List<Shot?> lastShot;

  BasketballLogic(
      {int durationMs = 30000, this.cooldownMs = 800, int players = 2})
      : score = List.filled(players, 0),
        shots = List.filled(players, 0),
        _lastShotAt = List.filled(players, -1 << 30),
        lastShot = List.filled(players, null),
        super(durationMs);

  @override
  List<int> get scores => score;

  /// Hoop position at time [t] (shared by everyone so it's fair).
  static double hoopXAt(int t) {
    if (t < calmMs) return 0;
    final ramp = min(1.0, (t - calmMs) / 10000);
    return swing * ramp * sin((t - calmMs) * 2 * pi / hoopPeriodMs);
  }

  double get hoopX => hoopXAt(elapsedMs);

  bool canShoot(int player) =>
      !finished && elapsedMs - _lastShotAt[player] >= cooldownMs;

  static int pointsFor(double miss) => miss <= 0.1
      ? 3
      : miss <= 0.25
          ? 2
          : 0;

  /// Shoots towards [aim]. The ball arrives [flightMs] later, so a moving hoop has to
  /// be led. Returns the points scored, or null if the shot isn't allowed right now.
  int? shoot(int player, double aim) {
    if (forward('shoot', [player, aim])) return null;
    if (!canShoot(player)) return null;
    aim = aim.clamp(-3.0, 3.0);
    final hoop = hoopXAt(elapsedMs + flightMs);
    final pts = pointsFor((aim - hoop).abs());
    _lastShotAt[player] = elapsedMs;
    shots[player]++;
    score[player] += pts;
    lastShot[player] = Shot(pts, aim, hoop, elapsedMs, shots[player]);
    notifyListeners();
    return pts;
  }
}

final LocalGameInfo basketballInfo = LocalGameInfo(
  id: 'basketball_hoops',
  title: 'Basketball Hoops',
  emoji: '🏀',
  color: const Color(0xFFFF9F43),
  tagline: 'Swipe up and sink the basket!',
  rules: const [
    'Swipe up on your side to throw the ball. The direction of your swipe is where it goes.',
    'Clean through the middle = 3 pts (swish), anywhere in the rim = 2 pts.',
    'After 5 seconds the hoop starts sliding, so aim where it will be. Most points wins: take turns on the whole court (1-5 minutes each) or split the screen (30s). 2 to 4 players.',
  ],
  scoreUnit: 'points',
  splitScreen: true,
  maxPlayers: 4,
  bot: botFor<BasketballLogic>((g, b, now) {
    if (!g.canShoot(b.seat) || !b.due(now)) return;
    // Aims where the hoop will be, with a shaky hand.
    final aim =
        BasketballLogic.hoopXAt(g.elapsedMs + BasketballLogic.flightMs) +
            (b.rng.nextDouble() - 0.5) * 0.45;
    g.shoot(b.seat, aim);
    b.wait(now, 900, 1700);
  }),
  online: RelaySpec<BasketballLogic>(
    create: (n) => BasketballLogic(players: n),
    save: (g) => {
      't': g.elapsedMs,
      'score': g.score,
      'shots': g.shots,
      'last': g._lastShotAt,
      'shotsAt': [
        for (final s in g.lastShot)
          s == null ? null : [s.points, s.aim, s.hoopX, s.atMs, s.number]
      ],
    },
    load: (g, s, me) {
      g.elapsedMs = asInt(s['t']);
      g.score.setAll(0, ints(s['score']));
      g.shots.setAll(0, ints(s['shots']));
      g._lastShotAt.setAll(0, ints(s['last']));
      final shots = s['shotsAt'] as List;
      for (var i = 0; i < shots.length; i++) {
        final v = shots[i] as List?;
        g.lastShot[i] = v == null
            ? null
            : Shot(asInt(v[0]), asDouble(v[1]), asDouble(v[2]), asInt(v[3]),
                asInt(v[4]));
      }
    },
    apply: (g, from, name, a) {
      if (name == 'shoot' && asInt(a[0]) == from) g.shoot(from, asDouble(a[1]));
    },
    // Online: your own court fills the screen, everyone's score along the top.
    view: (context, g, players, me) => Column(children: [
      Container(
        color: NeonPalette.overlay,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(children: [
          Expanded(
            child: Wrap(spacing: 6, runSpacing: 4, children: [
              for (var i = 0; i < players.length; i++)
                EdgeTag('${players[i].name} ${g.score[i]}',
                    color: players[i].color),
            ]),
          ),
          Text('${g.secondsLeft}s',
              style: const TextStyle(
                  fontFamily: Fonts.display,
                  color: Colors.white,
                  fontSize: 22,
                  fontFeatures: [FontFeature.tabularFigures()])),
        ]),
      ),
      Expanded(child: _HoopZone(player: players[me], index: me, g: g)),
    ]),
  ),
  // One phone: each player gets the whole court for the chosen time.
  turns: TurnsSpec(
    play: (player, ms, onDone) => TickingPlay<BasketballLogic>(
      create: () => BasketballLogic(players: 1, durationMs: ms),
      onFinished: (s) => onDone(s.first),
      builder: (context, g) => Column(children: [
        TurnBar(
            player: player, score: g.score.first, secondsLeft: g.secondsLeft),
        Expanded(
            child: _HoopZone(player: player, index: 0, g: g, chrome: false)),
      ]),
    ),
    simulate: (ms, rng) => simulateTurn(
        BasketballLogic(players: 1, durationMs: ms),
        basketballInfo.bot!,
        ms,
        rng),
  ),
  play: (players, onFinished) => TickingPlay<BasketballLogic>(
    create: () => BasketballLogic(players: players.length),
    onFinished: onFinished,
    builder: (context, g) => PlayerZones(
      count: players.length,
      colors: [for (final p in players) p.color],
      middle: DuelMiddleBar(
          players: players,
          scores: g.scores,
          secondsLeft: g.secondsLeft,
          progress: g.progress),
      center: ZoneCenterChip('${g.secondsLeft}s'),
      zone: (i) => _HoopZone(player: players[i], index: i, g: g),
    ),
  ),
);

/// Sizes for one player's court, worked out from the space it has.
class _Geo {
  final double w, h;
  late final double fenceTop = h * 0.30,
      grassTop = h * 0.52,
      courtTop = h * 0.62;
  late final double bbW = min(w * 0.5, h * 0.42),
      bbH = bbW * 0.68,
      rimW = bbW * 0.4;
  late final double bbTop = h * 0.1 + bbH * 0.28;
  late final double rimY = bbTop + bbH * 0.8;
  late final double netH = rimW * 0.62;
  late final double unit =
      max(1.0, min(rimW * 1.4, (w / 2 - bbW / 2 - 4) / BasketballLogic.swing));
  late final double startX = w / 2, startY = h * 0.84;
  late final double r0 = min(rimW * 0.62, h * 0.075), rB = rimW * 0.36;
  _Geo(this.w, this.h);

  double px(double hoopUnits) => w / 2 + hoopUnits * unit;
}

class _HoopZone extends StatefulWidget {
  final GpPlayer player;
  final int index;
  final BasketballLogic g;
  final bool
      chrome; // its own name tag and clock (the take-turns bar shows them instead)
  const _HoopZone(
      {required this.player,
      required this.index,
      required this.g,
      this.chrome = true});
  @override
  State<_HoopZone> createState() => _HoopZoneState();
}

class _HoopZoneState extends State<_HoopZone> {
  Offset? _from, _to;

  void _release(_Geo geo) {
    final from = _from, to = _to;
    _from = _to = null;
    if (from == null || to == null) return;
    final d = to - from;
    if (d.dy > -max(20.0, geo.h * 0.06)) return; // not an upward swipe
    // Carry the swipe's direction on from the ball up to the rim.
    final landing = geo.startX + d.dx / -d.dy * (geo.startY - geo.rimY);
    final pts = widget.g.shoot(widget.index, (landing - geo.w / 2) / geo.unit);
    if (pts != null)
      (pts > 0 ? HapticFeedback.lightImpact() : HapticFeedback.selectionClick())
          .ignore();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final i = widget.index;
    return LayoutBuilder(builder: (context, c) {
      final geo = _Geo(c.maxWidth, c.maxHeight);
      final shot = g.lastShot[i];
      final since = shot == null ? 1 << 30 : g.elapsedMs - shot.atMs;
      const flight = BasketballLogic.flightMs;
      final showText =
          shot != null && since >= flight - 60 && since < flight + 700;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (d) => _from = _to = d.localPosition,
        onPanUpdate: (d) => _to = d.localPosition,
        onPanEnd: (_) => _release(geo),
        onPanCancel: () => _from = _to = null,
        child: ClipRect(
          child: Stack(children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _CourtPainter(
                    geo: geo,
                    hoopX: g.hoopX,
                    score: g.score[i],
                    shot: shot,
                    since: since,
                    ready: g.canShoot(i)),
              ),
            ),
            if (widget.chrome)
              Positioned(
                left: 8,
                top: 6,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  PlayerBadge(
                      index: PlayerPalette.indexOf(widget.player.color) ?? i,
                      size: 22,
                      color: widget.player.color,
                      initial: widget.player.name),
                  const SizedBox(width: 6),
                  Text(widget.player.name,
                      style: TextStyle(
                          fontFamily: Fonts.body,
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          shadows: const [
                            Shadow(color: Color(0x99000000), blurRadius: 3)
                          ])),
                ]),
              ),
            if (widget.chrome)
              Positioned(
                right: 0,
                bottom: geo.h * 0.06,
                child: Container(
                  padding:
                      EdgeInsets.fromLTRB(geo.h * 0.05 + 6, 4, geo.h * 0.05, 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2B2D34),
                    borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(40)),
                    border: Border.all(color: Colors.black, width: 3),
                  ),
                  child: Text('${g.secondsLeft}',
                      style: TextStyle(
                          fontFamily: Fonts.display,
                          color: const Color(0xFFFF5B57),
                          fontSize: max(16.0, geo.h * 0.06),
                          fontFeatures: const [FontFeature.tabularFigures()])),
                ),
              ),
            if (showText)
              Positioned(
                left: 0,
                right: 0,
                top: geo.rimY + geo.netH + 2,
                child: Text(
                  shot.points == 3
                      ? '+3 SWISH!'
                      : shot.points == 2
                          ? '+2 NICE!'
                          : 'MISS',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: Fonts.display,
                    color: shot.points == 0
                        ? const Color(0xFFFF8E8B)
                        : (shot.points == 3 ? Brand.gold : Colors.white),
                    fontSize: max(18.0, geo.h * 0.08),
                    shadows: const [
                      Shadow(
                          color: Colors.black87,
                          blurRadius: 4,
                          offset: Offset(0, 2))
                    ],
                  ),
                ),
              ),
            if (g.shots[i] == 0 && g.canShoot(i))
              Positioned(
                left: 0,
                right: 0,
                top: geo.courtTop + (geo.h - geo.courtTop) * 0.06,
                child: Text('Swipe up to shoot',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: Fonts.display,
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: max(13.0, geo.h * 0.04))),
              ),
          ]),
        ),
      );
    });
  }
}

/// Draws the whole scene: sky, fence, grass, court, the hoop on its pole, and the ball.
class _CourtPainter extends CustomPainter {
  final _Geo geo;
  final double hoopX;
  final int score;
  final Shot? shot;
  final int since; // ms since the last shot
  final bool ready;
  _CourtPainter(
      {required this.geo,
      required this.hoopX,
      required this.score,
      required this.shot,
      required this.since,
      required this.ready});

  static const _coral = Color(0xFFFF6150);

  @override
  void paint(Canvas canvas, Size size) {
    _background(canvas);
    final hx = geo.px(hoopX);
    _stand(canvas, hx);
    _rim(canvas, hx, back: true);

    const flight = BasketballLogic.flightMs;
    final s = shot;
    if (s != null && since < flight) {
      // In the air: draw over the hoop.
      _net(canvas, hx);
      _rim(canvas, hx, back: false);
      final t = since / flight;
      final endX = geo.px(s.aim), endY = geo.rimY - geo.rB * 0.6;
      final rise = (geo.startY - endY) * 0.5;
      final x = geo.startX + (endX - geo.startX) * t;
      final y = geo.startY + (endY - geo.startY) * t - rise * 4 * t * (1 - t);
      _ball(canvas, Offset(x, y), geo.r0 + (geo.rB - geo.r0) * t);
      return;
    }
    if (s != null && since < geo2SettleMs) {
      final u = (since - flight) / (geo2SettleMs - flight);
      if (s.points > 0) {
        // Drops through the net: ball behind the net and front of the rim.
        final x = geo.px(s.aim) + (hx - geo.px(s.aim)) * u;
        _ball(
            canvas,
            Offset(x, geo.rimY - geo.rB * 0.6 + (geo.netH + geo.rB * 1.6) * u),
            geo.rB,
            opacity: 1 - u * 0.6);
        _net(canvas, hx, stretch: sin(u * pi) * 0.25);
        _rim(canvas, hx, back: false);
      } else {
        // Bounces off and falls away.
        _net(canvas, hx);
        _rim(canvas, hx, back: false);
        final dir = s.aim >= s.hoopX ? 1.0 : -1.0;
        final x = geo.px(s.aim) + dir * geo.unit * 0.9 * u;
        final y = geo.rimY -
            geo.rB * 0.6 -
            sin(u * pi) * geo.bbH * 0.3 +
            (geo.courtTop - geo.rimY) * u * u;
        _ball(canvas, Offset(x, y), geo.rB, opacity: 1 - u * 0.6);
      }
      return;
    }
    _net(canvas, hx);
    _rim(canvas, hx, back: false);
    if (ready) {
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(geo.startX, geo.startY + geo.r0 * 0.95),
              width: geo.r0 * 2.1,
              height: geo.r0 * 0.5),
          Paint()..color = Colors.black26);
      _ball(canvas, Offset(geo.startX, geo.startY), geo.r0);
    }
  }

  /// The ball has finished its after-flight animation by then (matches the cooldown).
  static const geo2SettleMs = 800;

  void _background(Canvas canvas) {
    final w = geo.w, h = geo.h;
    canvas.drawRect(
        Rect.fromLTWH(0, 0, w, geo.courtTop),
        Paint()
          ..shader = const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF8FE3FB), Color(0xFFA6ECFC)])
              .createShader(Rect.fromLTWH(0, 0, w, geo.courtTop)));
    // Cloud.
    final cloud = Paint()..color = const Color(0xFFB8F2FE);
    final cr = h * 0.05;
    for (final (dx, dy, r) in [
      (0.0, 0.0, 1.0),
      (-1.1, 0.35, 0.7),
      (1.0, 0.35, 0.75),
      (-0.2, 0.45, 0.8)
    ]) {
      canvas.drawCircle(
          Offset(w * 0.9 + dx * cr, h * 0.16 + dy * cr), cr * r, cloud);
    }
    // Grass behind the fence.
    canvas.drawRect(Rect.fromLTRB(0, geo.grassTop, w, geo.courtTop),
        Paint()..color = const Color(0xFF7ED957));
    // Chain-link fence.
    final fence = Rect.fromLTRB(0, geo.fenceTop, w, geo.courtTop);
    final wire = Paint()
      ..color = const Color(0xFF7C7F87)
      ..strokeWidth = max(2.0, h * 0.007);
    final step = max(16.0, min(w, h) / 9);
    final fh = fence.height;
    canvas.save();
    canvas.clipRect(fence);
    for (var x = -fh; x < w + fh; x += step) {
      canvas.drawLine(Offset(x, fence.top), Offset(x + fh, fence.bottom), wire);
      canvas.drawLine(Offset(x, fence.top), Offset(x - fh, fence.bottom), wire);
    }
    canvas.restore();
    final rail = Paint()
      ..color = const Color(0xFF6E7179)
      ..strokeWidth = max(3.0, h * 0.012);
    canvas.drawLine(Offset(0, fence.top), Offset(w, fence.top), rail);
    canvas.drawLine(Offset(0, fence.bottom - rail.strokeWidth / 2),
        Offset(w, fence.bottom - rail.strokeWidth / 2), rail);
    // Court.
    canvas.drawRect(Rect.fromLTRB(0, geo.courtTop, w, h),
        Paint()..color = const Color(0xFF30323A));
    final line = Paint()
      ..color = _coral
      ..strokeWidth = max(3.0, h * 0.008);
    final ch = h - geo.courtTop;
    canvas.drawLine(Offset(0, geo.courtTop + line.strokeWidth / 2),
        Offset(w, geo.courtTop + line.strokeWidth / 2), line);
    canvas.drawLine(Offset(w * 0.17, geo.courtTop),
        Offset(-w * 0.02, geo.courtTop + ch * 0.45), line);
    canvas.drawLine(Offset(w * 0.83, geo.courtTop),
        Offset(w * 1.02, geo.courtTop + ch * 0.45), line);
    canvas.drawLine(
        Offset(w * 0.09, geo.courtTop + ch * 0.2),
        Offset(w * 0.91, geo.courtTop + ch * 0.2),
        Paint()
          ..color = const Color(0xFFF6DAD5)
          ..strokeWidth = line.strokeWidth * 0.7);
  }

  void _stand(Canvas canvas, double hx) {
    final stroke = max(2.0, geo.bbW * 0.018);
    final black = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    // Pole.
    final pw = max(4.0, geo.bbW * 0.06);
    final pole = Rect.fromLTRB(hx - pw / 2, geo.bbTop + geo.bbH, hx + pw / 2,
        geo.courtTop + (geo.h - geo.courtTop) * 0.02);
    canvas.drawRect(pole, Paint()..color = const Color(0xFF45474F));
    canvas.drawRect(Rect.fromLTWH(pole.left, pole.top, pw * 0.3, pole.height),
        Paint()..color = const Color(0xFF5C5F68));
    // Backboard.
    final board = RRect.fromRectAndRadius(
        Rect.fromLTWH(hx - geo.bbW / 2, geo.bbTop, geo.bbW, geo.bbH),
        Radius.circular(geo.bbW * 0.06));
    canvas.drawRRect(board, Paint()..color = const Color(0xFFFF5B57));
    canvas.drawRRect(board, black);
    final inner = RRect.fromRectAndRadius(
        Rect.fromLTWH(hx - geo.bbW * 0.25, geo.bbTop + geo.bbH * 0.24,
            geo.bbW * 0.5, geo.bbH * 0.5),
        Radius.circular(geo.bbW * 0.03));
    canvas.drawRRect(
        inner,
        Paint()
          ..color = const Color(0xFFFF8783)
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke * 1.6);
    // Scoreboard on top.
    final sb = RRect.fromRectAndRadius(
        Rect.fromLTWH(hx - geo.bbW * 0.16, geo.bbTop - geo.bbH * 0.22,
            geo.bbW * 0.32, geo.bbH * 0.25),
        Radius.circular(geo.bbW * 0.03));
    canvas.drawRRect(sb, Paint()..color = const Color(0xFF2A2A2E));
    canvas.drawRRect(sb, black);
    final tp = TextPainter(
      text: TextSpan(
          text: '$score',
          style: TextStyle(
              fontFamily: Fonts.display,
              color: const Color(0xFFFF5B57),
              fontSize: geo.bbH * 0.17)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, sb.center - Offset(tp.width / 2, tp.height / 2));
  }

  Rect _rimRect(double hx) => Rect.fromCenter(
      center: Offset(hx, geo.rimY), width: geo.rimW, height: geo.rimW * 0.24);

  void _rim(Canvas canvas, double hx, {required bool back}) {
    final sw = max(3.0, geo.rimW * 0.08);
    final start = back ? pi : 0.0;
    canvas.drawArc(
        _rimRect(hx),
        start,
        pi,
        false,
        Paint()
          ..color = const Color(0xFF3A2A10)
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw + 2.5);
    canvas.drawArc(
        _rimRect(hx),
        start,
        pi,
        false,
        Paint()
          ..color = const Color(0xFFF5C542)
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw);
  }

  void _net(Canvas canvas, double hx, {double stretch = 0}) {
    final p = Paint()
      ..color = Colors.white
      ..strokeWidth = max(1.2, geo.rimW * 0.028);
    final top = geo.rimY, bottom = geo.rimY + geo.netH * (1 + stretch);
    final topHalf = geo.rimW * 0.46, bottomHalf = geo.rimW * 0.28;
    const strands = 6;
    Offset at(double f, double row) {
      final half = topHalf + (bottomHalf - topHalf) * row;
      return Offset(hx - half + 2 * half * f, top + (bottom - top) * row);
    }

    for (var k = 0; k <= strands; k++) {
      canvas.drawLine(at(k / strands, 0), at(k / strands, 1), p);
    }
    for (var row = 1; row <= 4; row++) {
      canvas.drawLine(at(0, row / 4), at(1, row / 4), p);
    }
  }

  void _ball(Canvas canvas, Offset c, double r, {double opacity = 1}) {
    if (opacity < 1)
      canvas.saveLayer(Rect.fromCircle(center: c, radius: r + 4),
          Paint()..color = Color.fromRGBO(0, 0, 0, opacity));
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFFFF7F1F));
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
    canvas.drawCircle(c.translate(r * 0.35, r * 0.35), r,
        Paint()..color = const Color(0xFFE5600A));
    canvas.drawCircle(c.translate(-r * 0.1, -r * 0.1), r * 0.85,
        Paint()..color = const Color(0xFFFF7F1F));
    final seam = Paint()
      ..color = const Color(0xFF8A3300)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.2, r * 0.07);
    canvas.drawLine(c.translate(0, -r), c.translate(0, r), seam);
    canvas.drawLine(c.translate(-r, 0), c.translate(r, 0), seam);
    canvas.drawCircle(c.translate(-r * 1.35, 0), r, seam);
    canvas.drawCircle(c.translate(r * 1.35, 0), r, seam);
    canvas.restore();
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1.5, r * 0.08));
    if (opacity < 1) canvas.restore();
  }

  @override
  bool shouldRepaint(_CourtPainter old) => true;
}
