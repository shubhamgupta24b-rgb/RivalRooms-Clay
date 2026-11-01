import 'dart:math';
import '../shell/local_game_logic.dart';
import '../solo/solo_common.dart';

/// The fruits from smallest to biggest. Two of the same merge into the next one.
const fruitEmoji = [
  '🍒',
  '🍓',
  '🍇',
  '🍊',
  '🍋',
  '🍎',
  '🍐',
  '🍑',
  '🍍',
  '🍈',
  '🍉'
];
const fruitRadius = [
  0.045,
  0.058,
  0.072,
  0.088,
  0.105,
  0.124,
  0.146,
  0.17,
  0.196,
  0.226,
  0.26
];

/// Points for making a fruit of each size (two watermelons vanish for a bonus).
const mergePoints = [0, 1, 3, 6, 10, 15, 21, 28, 36, 45, 55];
const watermelonBonus = 100;

/// Fruits you can be handed to drop (the five smallest).
const dropLevels = 5;

class Fruit {
  double x, y, vx = 0, vy = 0;
  final int level;
  final int bornMs;
  Fruit(this.x, this.y, this.level, this.bornMs);
  double get r => fruitRadius[level];
}

/// One player's box of fruit: a little physics world 1 wide and [height] tall
/// (y grows downwards). Fruits fall, bounce, roll, stack and merge.
class FruitBox {
  static const height = 1.5;
  static const dangerY =
      0.3; // the red line: fruit resting above it for too long ends the game
  static const spawnY = 0.13;
  static const dropCooldownMs = 450;
  static const graceMs =
      1500; // a freshly dropped fruit may pass the line on its way down
  static const dangerMs = 2600;
  static const _gravity = 3.2;
  static const _dt = 1 / 120;

  final Random rng;
  final List<Fruit> fruits = [];
  int score = 0;
  int next; // the fruit you hold
  int after; // the one after it
  double aimX =
      0.5; // where the held fruit hangs (not part of the online state)
  bool over = false;
  int? dangerSince;
  int biggest = 0; // biggest fruit made so far
  int lastDropMs = -dropCooldownMs;
  int nowMs = 0;
  double _acc = 0;
  int _lastMs = 0;
  final List<(double x, double y, int level, int ms)> pops =
      []; // recent merges, for effects

  FruitBox(this.rng)
      : next = rng.nextInt(3),
        after = rng.nextInt(3);

  bool get canDrop => !over && nowMs - lastDropMs >= dropCooldownMs;
  bool get inDanger => dangerSince != null;

  int _randomDrop() {
    // Small fruits more often than big ones.
    final r = rng.nextDouble();
    return r < 0.32
        ? 0
        : r < 0.6
            ? 1
            : r < 0.8
                ? 2
                : r < 0.93
                    ? 3
                    : 4;
  }

  /// Drops the held fruit at [x] (0..1 across the box). Returns false if it can't yet.
  bool drop(double x) {
    if (!canDrop) return false;
    final r = fruitRadius[next];
    fruits.add(Fruit(x.clamp(r, 1 - r), spawnY, next, nowMs));
    next = after;
    after = _randomDrop();
    lastDropMs = nowMs;
    aimX = x;
    return true;
  }

  /// Runs the physics up to [ms] in fixed small steps.
  void advance(int ms) {
    nowMs = ms;
    if (over) return;
    _acc += ((ms - _lastMs) / 1000).clamp(0.0, 0.1);
    _lastMs = ms;
    var steps = 0;
    while (_acc >= _dt && steps < 12) {
      _step();
      _acc -= _dt;
      steps++;
    }
    pops.removeWhere((p) => ms - p.$4 > 600);
    _checkDanger();
  }

  void _step() {
    for (final f in fruits) {
      f.vy += _gravity * _dt;
      f.vx *= 0.998;
      f.vy *= 0.998;
      f.x += f.vx * _dt;
      f.y += f.vy * _dt;
    }
    for (var it = 0; it < 4; it++) {
      _collide();
      _walls();
    }
    _merge();
  }

  void _walls() {
    for (final f in fruits) {
      final r = f.r;
      if (f.x < r) {
        f.x = r;
        if (f.vx < 0) f.vx = -f.vx * 0.2;
      } else if (f.x > 1 - r) {
        f.x = 1 - r;
        if (f.vx > 0) f.vx = -f.vx * 0.2;
      }
      if (f.y > height - r) {
        f.y = height - r;
        if (f.vy > 0) f.vy = -f.vy * 0.15;
        f.vx *= 0.96; // floor friction: things settle
      }
    }
  }

  void _collide() {
    final n = fruits.length;
    for (var i = 0; i < n; i++) {
      final a = fruits[i];
      for (var j = i + 1; j < n; j++) {
        final b = fruits[j];
        final dx = b.x - a.x, dy = b.y - a.y;
        final minD = a.r + b.r;
        final d2 = dx * dx + dy * dy;
        if (d2 >= minD * minD) continue;
        final d = sqrt(d2);
        final nx = d > 1e-9 ? dx / d : 0.0, ny = d > 1e-9 ? dy / d : 1.0;
        // Push apart, the lighter fruit moving more.
        final ma = a.r * a.r, mb = b.r * b.r, total = ma + mb;
        final overlap = minD - d;
        a.x -= nx * overlap * mb / total;
        a.y -= ny * overlap * mb / total;
        b.x += nx * overlap * ma / total;
        b.y += ny * overlap * ma / total;
        // Soak up the speed they meet with (only a little bounce).
        final rel = (b.vx - a.vx) * nx + (b.vy - a.vy) * ny;
        if (rel < 0) {
          final imp = -(1 + 0.1) * rel / total;
          a.vx -= imp * mb * nx;
          a.vy -= imp * mb * ny;
          b.vx += imp * ma * nx;
          b.vy += imp * ma * ny;
          // Rolling friction along the contact.
          final tx = -ny, ty = nx;
          final slide = (b.vx - a.vx) * tx + (b.vy - a.vy) * ty;
          a.vx += tx * slide * 0.05;
          a.vy += ty * slide * 0.05;
          b.vx -= tx * slide * 0.05;
          b.vy -= ty * slide * 0.05;
        }
      }
    }
  }

  void _merge() {
    final gone = <Fruit>{};
    final born = <Fruit>[];
    for (var i = 0; i < fruits.length; i++) {
      final a = fruits[i];
      if (gone.contains(a)) continue;
      for (var j = i + 1; j < fruits.length; j++) {
        final b = fruits[j];
        if (gone.contains(b) || b.level != a.level) continue;
        final dx = b.x - a.x, dy = b.y - a.y, touch = (a.r + b.r) * 1.02;
        if (dx * dx + dy * dy > touch * touch) continue;
        gone
          ..add(a)
          ..add(b);
        final mx = (a.x + b.x) / 2, my = (a.y + b.y) / 2;
        if (a.level == fruitEmoji.length - 1) {
          score += watermelonBonus; // two watermelons: both vanish
        } else {
          final up = a.level + 1;
          final f = Fruit(mx, my, up,
              nowMs - graceMs) // a merged fruit is never "freshly dropped"
            ..vx = (a.vx + b.vx) / 2
            ..vy = min(0, (a.vy + b.vy) / 2) - 0.25; // a little pop upwards
          born.add(f);
          score += mergePoints[up];
          biggest = max(biggest, up);
        }
        pops.add((mx, my, min(a.level + 1, fruitEmoji.length - 1), nowMs));
        break;
      }
    }
    if (gone.isEmpty) return;
    fruits
      ..removeWhere(gone.contains)
      ..addAll(born);
  }

  void _checkDanger() {
    final above =
        fruits.any((f) => nowMs - f.bornMs > graceMs && f.y - f.r < dangerY);
    if (!above) {
      dangerSince = null;
    } else {
      dangerSince ??= nowMs;
      if (nowMs - dangerSince! >= dangerMs) over = true;
    }
  }

  /// Online state: every fruit as x, y (thousandths) and size, plus score and the next fruits.
  Map<String, dynamic> save() => {
        'f': [
          for (final f in fruits) ...[
            (f.x * 1000).round(),
            (f.y * 1000).round(),
            f.level
          ]
        ],
        's': score,
        'n': next,
        'a': after,
        'o': over,
        'd': dangerSince != null,
        'b': biggest,
        'p': [
          for (final p in pops) ...[
            (p.$1 * 1000).round(),
            (p.$2 * 1000).round(),
            p.$3
          ]
        ],
      };

  void load(Map<String, dynamic> s, int nowMs) {
    final f = (s['f'] as List).cast<num>();
    fruits
      ..clear()
      ..addAll([
        for (var i = 0; i + 2 < f.length; i += 3)
          Fruit(f[i] / 1000, f[i + 1] / 1000, f[i + 2].toInt(), -100000)
      ]);
    score = (s['s'] as num).toInt();
    next = (s['n'] as num).toInt();
    after = (s['a'] as num).toInt();
    over = s['o'] == true;
    dangerSince = s['d'] == true ? (dangerSince ?? nowMs) : null;
    biggest = (s['b'] as num).toInt();
    final p = (s['p'] as List).cast<num>();
    pops
      ..clear()
      ..addAll([
        for (var i = 0; i + 2 < p.length; i += 3)
          (p[i] / 1000, p[i + 1] / 1000, p[i + 2].toInt(), nowMs)
      ]);
    this.nowMs = nowMs;
  }
}

/// Fruit Merge on your own: keep merging until the box overflows.
class FruitMergeSolo extends SoloLogic {
  final FruitBox box;
  FruitMergeSolo({Random? random}) : box = FruitBox(random ?? Random());

  @override
  void step(int now) {
    box.advance(now);
    score = box.score;
    if (box.over) gameOver(1600);
    notifyListeners();
  }

  void drop(double x) {
    if (box.drop(x)) notifyListeners();
  }

  void aim(double x) {
    box.aimX = x;
    notifyListeners();
  }
}

/// Fruit Merge Battle: everyone fills their own box at the same time. Highest score when
/// the time runs out wins; a box that overflows stops scoring.
class FruitMergeBattle extends TimedDuel {
  final List<FruitBox> boxes;
  FruitMergeBattle({int players = 2, int durationMs = 120000, Random? random})
      : boxes = List.generate(players, (_) => FruitBox(random ?? Random())),
        super(durationMs);

  @override
  bool get finished => super.finished || boxes.every((b) => b.over);
  @override
  List<int> get scores => [for (final b in boxes) b.score];

  @override
  void onUpdate() {
    for (final b in boxes) {
      b.advance(elapsedMs);
    }
  }

  void drop(int player, double x) {
    if (forward('drop', [player, x])) return;
    if (finished || player < 0 || player >= boxes.length) return;
    if (boxes[player].drop(x)) notifyListeners();
  }

  /// Moving the held fruit is only shown on your own screen; it isn't sent anywhere.
  void aim(int player, double x) {
    boxes[player].aimX = x;
    notifyListeners();
  }
}
