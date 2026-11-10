import 'dart:math';
import '../../../core/text/agreement.dart';
import 'package:flutter/material.dart';
import '../../guess_person/models/gp_player.dart';
import '../../../core/audio/game_audio.dart';
import '../../../core/ui/components.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/game_hud.dart';
import '../party/party_widgets.dart' show PassCover;
import '../shell/local_game_shell.dart' show ResultScope;
import '../../../core/ui/materials/materials.dart';
import '../shell/ticking_play.dart';

/// Battleship for 2 on an 8x8 sea. Fleets are placed at random. Take turns firing at the
/// other sea: a hit lets you fire again, a miss passes the turn. Sink the whole fleet to win.
class BattleshipLogic extends LocalGameLogic {
  static const size = 8;
  static const fleet = [4, 3, 3, 2, 2];

  /// ships[player] = list of ships, each a list of cells (row * size + col).
  final List<List<List<int>>> ships;
  final List<Set<int>> shots = [
    {},
    {}
  ]; // shots[p] = cells player p fired at (on the other sea)
  int turn = 0;
  int? lastShot;
  String message = 'Fire at the enemy sea!';
  int revealedFor =
      -1; // one phone: whose view is uncovered (not part of the online state)
  bool blind = false;
  bool remoteOver = false;
  final List<Set<int>> confirmed = [{}, {}];

  BattleshipLogic({Random? random})
      : ships = [
          randomFleet(random ?? Random()),
          randomFleet(random ?? Random())
        ];

  static List<List<int>> randomFleet(Random rng) {
    final taken = <int>{};
    final out = <List<int>>[];
    for (final len in fleet) {
      while (true) {
        final across = rng.nextBool();
        final r = rng.nextInt(across ? size : size - len + 1),
            c = rng.nextInt(across ? size - len + 1 : size);
        final cells = [
          for (var i = 0; i < len; i++)
            across ? r * size + c + i : (r + i) * size + c
        ];
        // Ships don't touch, not even corner to corner (easier to read on a small board).
        final near = {
          for (final x in cells)
            for (var dr = -1; dr <= 1; dr++)
              for (var dc = -1; dc <= 1; dc++)
                if ((x ~/ size + dr) >= 0 &&
                    (x ~/ size + dr) < size &&
                    (x % size + dc) >= 0 &&
                    (x % size + dc) < size)
                  (x ~/ size + dr) * size + x % size + dc,
        };
        if (near.any(taken.contains)) continue;
        taken.addAll(cells);
        out.add(cells);
        break;
      }
    }
    return out;
  }

  int other(int p) => 1 - p;
  bool isShip(int player, int cell) => blind
      ? confirmed[other(player)].contains(cell)
      : ships[player].any((s) => s.contains(cell));
  bool sunk(int player, List<int> ship) =>
      ship.isNotEmpty && ship.every(shots[other(player)].contains);
  int shipsLeft(int player) =>
      ships[player].where((s) => !sunk(player, s)).length;

  @override
  bool get finished => remoteOver || shipsLeft(0) == 0 || shipsLeft(1) == 0;
  @override
  List<int> get scores =>
      [shipsLeft(1) == 0 ? 1 : 0, shipsLeft(0) == 0 ? 1 : 0];
  @override
  void update(int elapsedMs) {}

  /// The player whose turn it is fires at [cell] of the other sea. Returns false if not allowed.
  bool fire(int cell) {
    if (forward('fire', [cell])) return false;
    if (finished ||
        cell < 0 ||
        cell >= size * size ||
        shots[turn].contains(cell)) return false;
    shots[turn].add(cell);
    lastShot = cell;
    final target = other(turn);
    final ship = ships[target].where((s) => s.contains(cell)).firstOrNull;
    if (ship == null) {
      message = '💦 Miss!';
      turn = target;
    } else if (sunk(target, ship)) {
      message = finished
          ? '🚢 Whole fleet sunk!'
          : '💥 Sunk a ship of ${ship.length}! Fire again';
    } else {
      message = '🔥 Hit! Fire again';
    }
    notifyListeners();
    return true;
  }

  void reveal(int player) {
    revealedFor = player;
    notifyListeners();
  }
}

/// Hunt and target: finish off a damaged ship along its line, otherwise search on a
/// checkerboard (every ship covers at least one black square).
int battleshipBotPick(BattleshipLogic g, int me, Random rng) {
  final enemy = g.other(me);
  final mine = g.shots[me];
  bool open(int r, int c) =>
      r >= 0 &&
      r < BattleshipLogic.size &&
      c >= 0 &&
      c < BattleshipLogic.size &&
      !mine.contains(r * BattleshipLogic.size + c);
  // Hits on ships that aren't sunk yet.
  final hits = [
    for (final c in mine)
      if (g.isShip(enemy, c) &&
          !g.sunk(enemy, g.ships[enemy].firstWhere((s) => s.contains(c))))
        c
  ];
  final targets = <int>[];
  if (hits.length >= 2) {
    // Keep going along the line the hits make.
    final sameRow = hits.every((h) => h ~/ 8 == hits.first ~/ 8);
    final cols = hits.map((h) => h % 8).toList()..sort();
    final rows = hits.map((h) => h ~/ 8).toList()..sort();
    if (sameRow) {
      final r = hits.first ~/ 8;
      if (open(r, cols.first - 1)) targets.add(r * 8 + cols.first - 1);
      if (open(r, cols.last + 1)) targets.add(r * 8 + cols.last + 1);
    } else {
      final c = hits.first % 8;
      if (open(rows.first - 1, c)) targets.add((rows.first - 1) * 8 + c);
      if (open(rows.last + 1, c)) targets.add((rows.last + 1) * 8 + c);
    }
  }
  if (targets.isEmpty) {
    for (final h in hits) {
      final r = h ~/ 8, c = h % 8;
      for (final (dr, dc) in const [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
        if (open(r + dr, c + dc)) targets.add((r + dr) * 8 + c + dc);
      }
    }
  }
  if (targets.isNotEmpty) return targets[rng.nextInt(targets.length)];
  final hunt = [
    for (var i = 0; i < 64; i++)
      if (!mine.contains(i) && (i ~/ 8 + i % 8).isEven) i
  ];
  final any = [
    for (var i = 0; i < 64; i++)
      if (!mine.contains(i)) i
  ];
  final pool = hunt.isNotEmpty ? hunt : any;
  return pool[rng.nextInt(pool.length)];
}

final battleshipInfo = LocalGameInfo(
  id: 'battleship',
  title: 'Battleship',
  emoji: '🚢',
  color: const Color(0xFF1E88E5),
  tagline: 'Find their fleet before they find yours!',
  rules: const [
    'Each of you has a hidden fleet of 5 ships on an 8×8 sea.',
    'On your turn, tap a square of the enemy sea to fire. Hit = fire again, miss = their turn.',
    'Sink every enemy ship to win!',
    'On one phone, pass it over between turns and don\'t peek at the other fleet.',
  ],
  scoreUnit: 'wins',
  splitScreen: false,
  bot: botFor<BattleshipLogic>((g, b, now) {
    if (g.finished || g.turn != b.seat) return;
    if (!b.thinkFirst((g.shots[0].length, g.shots[1].length), now, 700, 1400))
      return;
    g.fire(battleshipBotPick(g, b.seat, b.rng));
  }),
  online: RelaySpec<BattleshipLogic>(
    create: (n) => BattleshipLogic(),
    save: (g) => {
      'ships': [
        for (final fleet in g.ships) [for (final s in fleet) ...s]
      ],
      'shots': [for (final s in g.shots) s.toList()],
      'turn': g.turn,
      'last': g.lastShot,
      'msg': g.message,
    },
    wire: (g) {
      final hits = <List<int>>[];
      for (var p = 0; p < 2; p++) {
        hits.add([
          for (final c in g.shots[p])
            if (g.ships[1 - p].any((ship) => ship.contains(c))) c
        ]);
      }
      return {
        'shots': [for (final s in g.shots) s.toList()],
        'hits': hits,
        'turn': g.turn,
        'last': g.lastShot,
        'msg': g.message,
        'over': g.finished,
      };
    },
    views: (g) {
      return [
        for (var p = 0; p < 2; p++)
          {
            'ships': [for (final ship in g.ships[p]) ...ship]
          },
      ];
    },
    load: (g, s, me) {
      if (s['ships'] != null) {
        final fleets = s['ships'] as List;
        for (var p = 0; p < 2; p++) {
          final cells = ints(fleets[p]);
          var i = 0;
          for (var k = 0; k < BattleshipLogic.fleet.length; k++) {
            g.ships[p][k] = cells.sublist(i, i + BattleshipLogic.fleet[k]);
            i += BattleshipLogic.fleet[k];
          }
        }
        g.blind = false;
      } else {
        g.blind = true;
        g.remoteOver = s['over'] == true;
        final hits = s['hits'] as List?;
        if (hits != null) {
          for (var p = 0; p < 2 && p < hits.length; p++) {
            g.confirmed[p]
              ..clear()
              ..addAll(ints(hits[p]));
          }
        }
        final seat = s['_seat'];
        if (seat is Map && me >= 0 && me < 2) {
          final cells = ints(seat['ships']);
          var i = 0;
          for (var k = 0;
              k < BattleshipLogic.fleet.length &&
                  i + BattleshipLogic.fleet[k] <= cells.length;
              k++) {
            g.ships[me][k] = cells.sublist(i, i + BattleshipLogic.fleet[k]);
            i += BattleshipLogic.fleet[k];
          }
        }
      }
      final shots = s['shots'] as List;
      for (var p = 0; p < 2; p++) {
        g.shots[p]
          ..clear()
          ..addAll(ints(shots[p]));
      }
      g.turn = asInt(s['turn']);
      g.lastShot = nInt(s['last']);
      g.message = s['msg'] as String;
    },
    apply: (g, from, name, a) {
      if (name == 'fire' && from == g.turn) g.fire(asInt(a[0]));
    },
    view: (context, g, players, me) =>
        _BattleTable(g: g, players: players, me: me),
  ),
  play: (players, onFinished) => TickingPlay<BattleshipLogic>(
    create: () => BattleshipLogic(),
    onFinished: onFinished,
    builder: (context, g) => _BattleTable(
      g: g,
      players: players,
      me: BotScope.humanSeat(context),
      bots: {
        for (var i = 0; i < 2; i++)
          if (BotScope.isBot(context, i)) i
      },
    ),
  ),
);

// Board palette: open sea, grey hulls.
class _BattleTable extends StatelessWidget {
  final BattleshipLogic g;
  final List<GpPlayer> players;
  final int? me;
  final Set<int> bots;
  const _BattleTable(
      {required this.g, required this.players, this.me, this.bots = const {}});

  @override
  Widget build(BuildContext context) {
    final passing = me == null;
    // Whose seas are shown: this phone's player, or (passing the phone) the player whose turn it is.
    final viewer = me ?? (bots.contains(g.turn) ? g.other(g.turn) : g.turn);
    final covered = passing &&
        !bots.contains(g.turn) &&
        g.revealedFor != g.turn &&
        !g.finished;
    final myTurn = viewer == g.turn && !bots.contains(g.turn) && !g.finished;
    final enemy = g.other(viewer);
    final current = players[g.turn];
    final winner = g.finished ? (g.scores[0] == 1 ? 0 : 1) : null;
    ResultScope.of(context)?.subtitle = winner == null
        ? null
        : '${g.shipsLeft(winner)} of ${BattleshipLogic.fleet.length} ships still afloat';
    final m = stripEmoji(g.message);
    final Widget banner = g.finished
        ? TurnBanner(
            text: winsBang(players[winner!].name),
            sub: 'Whole fleet sunk',
            color: players[winner].color,
            kind: TurnBannerKind.success,
            icon: GameIcons.trophy,
            compact: true)
        : g.message.contains('Miss')
            ? TurnBanner(
                text: 'Miss',
                sub: myTurn ? 'Pass the phone' : '${current.name} is aiming…',
                color: current.color,
                kind: TurnBannerKind.miss,
                compact: true)
            : (g.message.contains('Hit') || g.message.contains('Sunk'))
                ? TurnBanner(
                    text: m.split('!').first,
                    sub: 'Fire again',
                    color: current.color,
                    kind: TurnBannerKind.success,
                    icon: GameIcons.target,
                    compact: true)
                : TurnBanner(
                    text: myTurn
                        ? (passing
                            ? '${possessive(current.name)} turn: fire!'
                            : 'Your turn: fire!')
                        : '${current.name} is aiming…',
                    sub: 'Tap a square on the enemy sea',
                    color: current.color,
                    compact: true);
    return MomentWatcher<int>(
      value: g.shots[0].length + g.shots[1].length,
      onChange: (fx, before, now) {
        if (now <= before) return;
        if (g.message.contains('Sunk') || g.message.contains('Whole fleet')) {
          keyMoment(fx, 'SUNK!',
              sub: g.message.contains('Whole')
                  ? 'The whole fleet'
                  : 'A ship goes down',
              sound: 'boom',
              buzz: HapticWeight.heavy,
              shake: true);
        } else if (g.message.contains('Hit')) {
          keyMoment(fx, 'HIT!',
              sub: 'Fire again',
              sound: 'hit',
              buzz: HapticWeight.heavy,
              shake: true);
        } else {
          fx?.pop('MISS', color: Colors.white);
        }
      },
      child: Stack(children: [
        Padding(
          padding:
              const EdgeInsets.fromLTRB(Space.s, Space.xs, Space.s, Space.s),
          child: Column(children: [
            ScoreHud(
              title: 'Battleship',
              state:
                  g.finished ? 'Game over' : '${possessive(current.name)} shot',
              players: players,
              turn: g.finished ? null : g.turn,
              score: (i) => '${g.shipsLeft(i)}',
              tag: (i) => !g.finished && i == g.turn ? 'FIRING' : null,
              detail: (i, compact) => Pips(
                  filled: g.shipsLeft(i),
                  total: BattleshipLogic.fleet.length,
                  color: players[i].color,
                  size: 10),
            ),
            const SizedBox(height: 6),
            SizedBox(height: 54, child: Center(child: banner)),
            const SizedBox(height: 4),
            _SeaLabel(
                GameIcons.target,
                'Enemy sea · ${g.shipsLeft(enemy)} ships left',
                players[enemy].color),
            Expanded(
              flex: 3,
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: _Sea(
                      g: g,
                      owner: enemy,
                      showShips: g.finished,
                      onFire: myTurn && !covered ? g.fire : null),
                ),
              ),
            ),
            const SizedBox(height: Space.s),
            _SeaLabel(
                GameIcons.shield,
                'Your fleet · ${g.shipsLeft(viewer)} ships left',
                players[viewer].color),
            Expanded(
                flex: 2,
                child: Center(
                    child: AspectRatio(
                        aspectRatio: 1,
                        child: _Sea(g: g, owner: viewer, showShips: true)))),
          ]),
        ),
        if (covered)
          PassCover(
              player: current,
              holdLabel: 'Hold to see your sea',
              note: 'No peeking at the other fleet!',
              onReveal: () => g.reveal(g.turn)),
      ]),
    );
  }
}

class _SeaLabel extends StatelessWidget {
  final GameIcons icon;
  final String text;
  final Color color;
  const _SeaLabel(this.icon, this.text, this.color);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Space.xs),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          GameIcon(icon, size: 14, color: nameColor(color)),
          const SizedBox(width: 6),
          Flexible(
              child: Text(text.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.tk.styles.label
                      .copyWith(color: nameColor(color)))),
        ]),
      );
}

/// One player's sea (spec 5.1 #7): water, grey ships seen from above, hits burning with
/// smoke, misses as white splash rings, the last shot ringed gold. [onFire] makes the
/// squares tappable.
class _Sea extends StatelessWidget {
  final BattleshipLogic g;
  final int owner;
  final bool showShips;
  final bool Function(int cell)? onFire;
  const _Sea(
      {required this.g,
      required this.owner,
      required this.showShips,
      this.onFire});

  @override
  Widget build(BuildContext context) {
    final shotsHere = g.shots[g.other(owner)];
    return Container(
      decoration: BoxDecoration(
        borderRadius: Radii.rChip,
        border: Border.all(
            color: onFire != null ? Brand.gold : Colors.white24,
            width: onFire != null ? 3 : 1.5),
        boxShadow: [
          if (onFire != null)
            BoxShadow(
                color: Brand.gold.withValues(alpha: 0.35), blurRadius: 14),
          const BoxShadow(
              color: Color(0x66000000), blurRadius: 12, offset: Offset(0, 6))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(children: [
          Positioned.fill(
              child: RepaintBoundary(
                  child: CustomPaint(
                      painter: _SeaPainter(
                          g, owner, showShips, shotsHere.length, g.lastShot)))),
          GridView.count(
            crossAxisCount: BattleshipLogic.size,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (var cell = 0; cell < 64; cell++)
                Builder(builder: (context) {
                  final shot = shotsHere.contains(cell);
                  final ship = g.isShip(owner, cell);
                  final sunkShip = ship &&
                      g.sunk(owner,
                          g.ships[owner].firstWhere((s) => s.contains(cell)));
                  final visible = ship && (showShips || shot);
                  return Semantics(
                    button: onFire != null && !shot,
                    label:
                        '${String.fromCharCode(65 + cell ~/ 8)}${cell % 8 + 1}: ${shot ? (ship ? (sunkShip ? 'sunk' : 'hit') : 'miss') : (visible ? 'ship' : 'water')}',
                    excludeSemantics: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onFire == null || shot
                          ? null
                          : () {
                              haptic(HapticWeight.medium);
                              final hit = g.isShip(owner, cell);
                              onFire!(cell);
                              GameAudio.sfx(hit ? 'boom' : 'pop');
                            },
                    ),
                  );
                }),
            ],
          ),
        ]),
      ),
    );
  }
}

class _SeaPainter extends CustomPainter {
  final BattleshipLogic g;
  final int owner;
  final bool showShips;
  final int shotCount; // repaint when a shot lands
  final int? lastShot;
  _SeaPainter(
      this.g, this.owner, this.showShips, this.shotCount, this.lastShot);

  @override
  void paint(Canvas canvas, Size size) {
    const n = BattleshipLogic.size;
    final s = size.width / n;
    const WaterPainter(radius: 0).paint(canvas, size);
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    for (var i = 1; i < n; i++) {
      canvas.drawLine(Offset(i * s, 0), Offset(i * s, size.height), grid);
      canvas.drawLine(Offset(0, i * s), Offset(size.width, i * s), grid);
    }
    final shots = g.shots[g.other(owner)];
    Rect cellRect(int c) => Rect.fromLTWH((c % n) * s, (c ~/ n) * s, s, s);
    // Ships: shown when it's your fleet, at the end, or once sunk.
    for (final ship in g.ships[owner]) {
      final sunk = g.sunk(owner, ship);
      if (!showShips && !sunk) continue;
      var r = cellRect(ship.first);
      for (final c in ship) {
        r = r.expandToInclude(cellRect(c));
      }
      final across = r.width > r.height;
      final hull = r.deflate(s * 0.12);
      final rr = RRect.fromRectAndRadius(hull, Radius.circular(s * 0.38));
      canvas.drawRRect(rr.shift(Offset(s * 0.05, s * 0.08)),
          Paint()..color = const Color(0x55000000));
      canvas.drawRRect(
          rr,
          Paint()
            ..shader = LinearGradient(
              begin: across ? Alignment.topCenter : Alignment.centerLeft,
              end: across ? Alignment.bottomCenter : Alignment.centerRight,
              colors: sunk
                  ? const [Color(0xFF5A4A40), Color(0xFF3A2E28)]
                  : const [Color(0xFFC9D3DA), Color(0xFF7D8E99)],
            ).createShader(hull));
      // Deck: a centre line and small turrets.
      final deck = Paint()
        ..color = sunk ? const Color(0x55000000) : const Color(0xFF5E6E79)
        ..strokeWidth = s * 0.06
        ..strokeCap = StrokeCap.round;
      final a = across
          ? Offset(hull.left + s * 0.3, hull.center.dy)
          : Offset(hull.center.dx, hull.top + s * 0.3);
      final b = across
          ? Offset(hull.right - s * 0.3, hull.center.dy)
          : Offset(hull.center.dx, hull.bottom - s * 0.3);
      canvas.drawLine(a, b, deck);
      for (var i = 0; i < ship.length; i++) {
        final c = cellRect(ship[i]).center;
        canvas.drawCircle(
            c,
            s * 0.13,
            Paint()
              ..color =
                  sunk ? const Color(0xFF2E2420) : const Color(0xFF9AA8B2));
        canvas.drawCircle(c, s * 0.13, deck..style = PaintingStyle.stroke);
        deck.style = PaintingStyle.fill;
      }
    }
    // Shots: burning hits with smoke, splash rings for misses.
    for (final c in shots) {
      final r = cellRect(c);
      final ctr = r.center;
      if (g.isShip(owner, c)) {
        for (final (dx, dy, k) in const [
          (-0.12, -0.3, 0.2),
          (0.1, -0.42, 0.16),
          (-0.02, -0.52, 0.12)
        ]) {
          canvas.drawCircle(ctr + Offset(dx * s, dy * s), k * s,
              Paint()..color = const Color(0x8C3A3A40));
        }
        Path flame(Offset c, double k) => Path()
          ..moveTo(c.dx, c.dy - s * 0.32 * k)
          ..quadraticBezierTo(
              c.dx + s * 0.3 * k, c.dy, c.dx, c.dy + s * 0.28 * k)
          ..quadraticBezierTo(
              c.dx - s * 0.3 * k, c.dy, c.dx, c.dy - s * 0.32 * k)
          ..close();
        canvas.drawPath(
            flame(ctr, 1), Paint()..color = const Color(0xFFFF6B1A));
        canvas.drawPath(flame(ctr + Offset(0, s * 0.08), 0.55),
            Paint()..color = const Color(0xFFFFD54F));
      } else {
        final ring = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.06
          ..color = Colors.white.withValues(alpha: 0.85);
        canvas.drawCircle(ctr, s * 0.22, ring);
        canvas.drawCircle(ctr, s * 0.08,
            Paint()..color = Colors.white.withValues(alpha: 0.85));
      }
      if (c == lastShot) {
        canvas.drawRRect(
            RRect.fromRectAndRadius(r.deflate(1.5), Radius.circular(s * 0.15)),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5
              ..color = Brand.gold);
      }
    }
  }

  @override
  bool shouldRepaint(_SeaPainter o) =>
      o.shotCount != shotCount ||
      o.showShips != showShips ||
      o.lastShot != lastShot ||
      o.owner != owner;
}
