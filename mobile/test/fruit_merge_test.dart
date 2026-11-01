import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/features/local_games/fruit_merge/fruit_merge_game.dart';
import 'package:multiplayer_game/features/local_games/shell/bots.dart';

/// Runs a box for [ms] of game time from [from], in 16 ms frames.
int run(FruitBox box, int from, int ms) {
  for (var t = from; t <= from + ms; t += 16) {
    box.advance(t);
  }
  return from + ms;
}

void main() {
  test('dropped fruit falls, stays inside the box and comes to rest', () {
    final box = FruitBox(Random(1));
    box.drop(0.5);
    run(box, 0, 3000);
    final f = box.fruits.single;
    expect(f.y, closeTo(FruitBox.height - f.r, 0.01),
        reason: 'resting on the floor');
    expect(f.vy.abs(), lessThan(0.05));
    expect(f.x, inInclusiveRange(f.r, 1 - f.r));
  });

  test('a pile of fruit never leaves the box or goes NaN', () {
    final rng = Random(7);
    final box = FruitBox(rng);
    var t = 0;
    for (var i = 0; i < 40 && !box.over; i++) {
      box.drop(rng.nextDouble());
      t = run(box, t, 500);
    }
    for (final f in box.fruits) {
      expect(f.x.isFinite && f.y.isFinite, isTrue);
      expect(f.x, inInclusiveRange(f.r - 0.01, 1 - f.r + 0.01));
      expect(f.y, lessThanOrEqualTo(FruitBox.height - f.r + 0.01));
    }
  });

  test('two of the same fruit merge into the next one and score', () {
    final box = FruitBox(Random(1))..next = 2;
    box.drop(0.5);
    var t = run(box, 0, 1500);
    box.next = 2;
    box.drop(0.5);
    run(box, t, 2000);
    expect(box.fruits.length, 1);
    expect(box.fruits.single.level, 3);
    expect(box.score, mergePoints[3]);
    expect(box.biggest, 3);
  });

  test(
      'merges chain: three cherries settle into a strawberry + cherry, not lost',
      () {
    final box = FruitBox(Random(2));
    var t = 0;
    for (var i = 0; i < 3; i++) {
      box.next = 0;
      box.drop(0.5);
      t = run(box, t, 1200);
    }
    final levels = box.fruits.map((f) => f.level).toList()..sort();
    expect(levels, [0, 1]);
  });

  test('two watermelons vanish for the bonus', () {
    final box = FruitBox(Random(3));
    final last = fruitEmoji.length - 1;
    box.fruits
        .addAll([Fruit(0.3, 1.2, last, -9999), Fruit(0.75, 1.2, last, -9999)]);
    run(box, 0, 2000);
    expect(box.fruits, isEmpty);
    expect(box.score, watermelonBonus);
  });

  test('can only drop again after a short wait', () {
    final box = FruitBox(Random(1));
    expect(box.drop(0.3), isTrue);
    expect(box.drop(0.3), isFalse);
    run(box, 0, FruitBox.dropCooldownMs + 20);
    expect(box.drop(0.7), isTrue);
  });

  test('fruit stuck above the red line ends the game, a quick pass does not',
      () {
    final box = FruitBox(Random(1));
    // A fresh drop passes the line on its way down: no game over.
    box.drop(0.5);
    run(box, 0, 3000);
    expect(box.over, isFalse);
    // Keep dropping into one column until the pile reaches the line.
    var t = 3000;
    int? firstDanger;
    while (!box.over && t < 10 * 60 * 1000) {
      box.drop(0.5);
      for (var k = 0; k < 30 && !box.over; k++) {
        t += 16;
        box.advance(t);
        if (box.inDanger) firstDanger ??= t;
        if (!box.inDanger) firstDanger = null;
      }
    }
    expect(box.over, isTrue);
    expect(t - firstDanger!, greaterThanOrEqualTo(FruitBox.dangerMs - 32),
        reason: 'it must stay over the line for a while first');
  });

  test('solo game ends when the box overflows', () {
    final g = FruitMergeSolo(random: Random(5));
    var t = 0;
    while (!g.finished && t < 20 * 60 * 1000) {
      g.drop(0.5); // everything in one column: it will overflow
      for (var k = 0; k < 30; k++) {
        t += 16;
        g.update(t);
      }
    }
    expect(g.finished, isTrue);
    expect(g.score, g.box.score);
  });

  test('battle: time limit, scores per player, and only your own drops count',
      () {
    final g = FruitMergeBattle(players: 3, durationMs: 4000, random: Random(9));
    g.drop(0, 0.4);
    g.drop(2, 0.6);
    for (var t = 0; t <= 4000; t += 16) {
      g.update(t);
    }
    expect(g.finished, isTrue);
    expect(g.boxes[0].fruits.length, 1);
    expect(g.boxes[1].fruits, isEmpty);
    expect(g.boxes[2].fruits.length, 1);
    expect(g.scores.length, 3);
  });

  test('computer players drop fruit and score over a battle', () {
    final g =
        FruitMergeBattle(players: 2, durationMs: 60000, random: Random(4));
    final bots = [BotSeat(0, Random(1)), BotSeat(1, Random(2))];
    final turn = fruitBattleInfo.bot!;
    for (var t = 0; t <= 60000 && !g.finished; t += 16) {
      g.update(t);
      for (final b in bots) {
        turn(g, b, t);
      }
    }
    expect(g.boxes.every((b) => b.fruits.isNotEmpty || b.score > 0), isTrue);
    expect(g.scores.reduce(max), greaterThan(0),
        reason: 'bots aim at matching fruit');
  });

  test('online: the host state loads into a guest copy', () {
    final host = FruitMergeBattle(players: 2, random: Random(3));
    host.drop(0, 0.3);
    host.drop(1, 0.8);
    for (var t = 0; t < 1500; t += 16) {
      host.update(t);
    }
    final spec = fruitBattleInfo.online!;
    final guest = spec.create(2) as FruitMergeBattle;
    spec.load(guest, spec.save(host), 1);
    expect(guest.elapsedMs, host.elapsedMs);
    for (var i = 0; i < 2; i++) {
      expect(guest.boxes[i].fruits.length, host.boxes[i].fruits.length);
      expect(guest.boxes[i].fruits.first.x,
          closeTo(host.boxes[i].fruits.first.x, 0.001));
      expect(guest.boxes[i].next, host.boxes[i].next);
      expect(guest.boxes[i].score, host.boxes[i].score);
    }
    // A guest's drop is sent to the host, not applied locally.
    final sent = <(String, List<Object?>)>[];
    guest.sendToHost = (n, a) => sent.add((n, a));
    guest.drop(1, 0.5);
    expect(sent.single.$1, 'drop');
    expect(guest.boxes[1].fruits.length, host.boxes[1].fruits.length);
    // The host applies it only for the player who sent it.
    spec.apply(host, 0, 'drop', [1, 0.5]);
    expect(host.boxes[1].fruits.length, 1,
        reason: 'player 0 cannot drop in player 1\'s box');
  });

  test('the online state stays small', () {
    final g = FruitMergeBattle(players: 4, random: Random(1));
    final rng = Random(2);
    var t = 0;
    for (var i = 0; i < 25; i++) {
      for (var p = 0; p < 4; p++) {
        g.drop(p, rng.nextDouble());
      }
      for (var k = 0; k < 40; k++) {
        t += 16;
        g.update(t);
      }
    }
    final json = fruitBattleInfo.online!.save(g).toString();
    expect(json.length, lessThan(20000),
        reason: 'the server caps relay state at 64 KB');
  });
}
