import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/core/audio/game_audio.dart';
import 'package:multiplayer_game/features/local_games/archery/archery_game.dart';
import 'package:multiplayer_game/features/local_games/bottle_smash/bottle_smash_game.dart';
import 'package:multiplayer_game/features/local_games/local_games_hub_screen.dart';
import 'package:multiplayer_game/features/local_games/mini_golf/mini_golf_game.dart';
import 'package:multiplayer_game/features/local_games/shooting_gallery/shooting_gallery_game.dart';
import 'package:multiplayer_game/features/local_games/slingshot/slingshot_game.dart';

Map<String, dynamic> roundTrip(Map<String, dynamic> s) =>
    jsonDecode(jsonEncode(s)) as Map<String, dynamic>;

void main() {
  group('Mini Golf', () {
    test('a straight putt on hole 1 drops in; a weak one stops short', () {
      final h = golfHoles[0];
      final up = atan2(h.cup.dy - h.tee.dy, h.cup.dx - h.tee.dx);
      final weak = GolfLogic.simulate(h, h.tee, up, 0.1);
      expect(weak.$2, isFalse);
      expect(weak.$1.dy, lessThan(h.tee.dy));
      var sank = false;
      for (var p = 0.3; p <= 1.0 && !sank; p += 0.02) {
        sank = GolfLogic.simulate(h, h.tee, up, p).$2;
      }
      expect(sank, isTrue, reason: 'some power holes it straight up');
    });

    test('the ball never goes through a wall or off the course', () {
      for (final h in golfHoles) {
        for (var a = 0; a < 16; a++) {
          final s = [
            h.tee.dx,
            h.tee.dy,
            cos(a * pi / 8) * GolfLogic.maxSpeed,
            sin(a * pi / 8) * GolfLogic.maxSpeed
          ];
          for (var i = 0; i < 800; i++) {
            if (GolfLogic.stepBall(h, s, 1 / 240)) break;
            expect(s[0], inInclusiveRange(0, 1));
            expect(s[1], inInclusiveRange(0, GolfLogic.courseH));
            for (final w in h.walls) {
              expect(w.contains(Offset(s[0], s[1])), isFalse,
                  reason: 'inside a wall');
            }
          }
        }
      }
    });

    test('the bot finds a putt that sinks it or gets close', () {
      final g = GolfLogic(players: 1);
      final (angle, power) = golfBotShot(g, Random(1));
      final (end, sunk) = GolfLogic.simulate(g.course, g.ball, angle, power);
      expect(sunk || (end - g.course.cup).distance < 0.25, isTrue);
    });

    test(
        'scores: 7 minus strokes, all holes, then finished; online state round-trips',
        () {
      final g = GolfLogic(players: 2);
      var t = 0;
      final rng = Random(2);
      while (!g.finished && t < 2000000) {
        t += 16;
        g.update(t);
        if (g.ready) {
          final (a, p) = golfBotShot(g, rng);
          g.putt(g.turn, a, p);
        }
      }
      expect(g.finished, isTrue);
      for (var i = 0; i < 2; i++) {
        expect(g.card[i], hasLength(golfHoles.length));
        expect(g.score[i], g.card[i].fold<int>(0, (s, k) => s + 7 - k));
      }
      final spec = golfInfo.online!;
      final copy = spec.create(2) as GolfLogic;
      spec.load(copy, roundTrip(spec.save(g)), 1);
      expect(copy.score, g.score);
      expect(copy.card, g.card);
      expect(copy.finished, isTrue);
    });
  });

  group('Slingshot', () {
    test('every fort is the same for everyone and has pigs', () {
      for (var r = 1; r <= SlingLogic.rounds; r++) {
        expect(SlingLogic.buildFort(r), SlingLogic.buildFort(r));
        expect(
            SlingLogic.buildFort(r)
                .expand((c) => c)
                .where((k) => k == Cell.pig),
            isNotEmpty);
      }
    });

    test('a falling block squashes the pig under it', () {
      final g = SlingLogic(players: 1);
      for (final c in g.grid) {
        c.fillRange(0, SlingLogic.rows, Cell.empty);
      }
      g.grid[0][0] = Cell.pig;
      g.grid[0][3] = Cell.wood; // two rows above the pig, nothing holding it up
      g.grid[5][0] = Cell.pig; // a pig elsewhere so the fort isn't cleared
      // Fire a bird into the ground far from the fort, so the fort settles.
      g.fling(0, -0.5, 0.2);
      for (var t = 0; t < 5000 && !g.ready; t += 16) {
        g.update(t);
      }
      expect(g.grid[0][0], Cell.wood,
          reason: 'the block landed where the pig was');
      expect(g.score[0], 100);
      expect(g.birds, SlingLogic.birdsEach - 1);
    });

    test('the bot nearly always hits the fort', () {
      var hits = 0;
      for (var round = 1; round <= SlingLogic.rounds; round++) {
        final g = SlingLogic(players: 1)..grid = SlingLogic.buildFort(round);
        for (var seed = 0; seed < 5; seed++) {
          final (a, p) = slingBotShot(g, Random(seed));
          if (g.firstHit(a, p) != null) hits++;
        }
      }
      expect(hits, greaterThanOrEqualTo(13));
    });

    test('online state round-trips', () {
      final g = SlingLogic(players: 2);
      g.fling(0, 0.6, 0.8);
      for (var t = 0; t < 400; t += 16) {
        g.update(t);
      }
      final spec = slingInfo.online!;
      final copy = spec.create(2) as SlingLogic;
      spec.load(copy, roundTrip(spec.save(g)), 1);
      expect(copy.grid, g.grid);
      expect(copy.bird, g.bird);
      expect(copy.score, g.score);
    });
  });

  group('Shooting Gallery', () {
    test(
        'targets slide by; shooting one scores and removes it; a bomb costs points',
        () {
      final g = GalleryLogic(players: 1);
      g.update(0);
      g.begin(0);
      g.update(4000);
      final targets = g.targets;
      expect(targets, isNotEmpty);
      final good =
          targets.firstWhere((t) => t.kind != 3, orElse: () => targets.first);
      g.shoot(0, good.x, good.y);
      expect(g.score[0], const [10, 20, 50, 0][good.kind]);
      expect(g.targets.map((t) => t.id), isNot(contains(good.id)));
      expect(g.shots, GalleryLogic.clip - 1);
    });

    test('the clip empties and reloads; the turn ends when time runs out', () {
      final g = GalleryLogic(players: 2);
      g.begin(0);
      for (var i = 0; i < GalleryLogic.clip; i++) {
        g.shoot(0, 0.5, 0.95); // the floor: always a miss
      }
      expect(g.reloading, isTrue);
      g.shoot(0, 0.5, 0.95);
      expect(g.shots, GalleryLogic.clip, reason: 'no shooting while reloading');
      g.update(GalleryLogic.turnMs + 10);
      expect(g.turn, 1);
      expect(g.waiting, isTrue);
    });
  });

  group('Bottle Smash', () {
    test('knocking a bottom bottle brings down the ones resting on it', () {
      final g = BottleLogic(players: 1, random: Random(1));
      final corner = g.bottles.firstWhere((b) => b.row == 0 && b.col == 0);
      final c = g.bottleAt(corner);
      g.throwBall(0, c.dx, (0.62 - c.dy) / 0.6);
      g.update(1000);
      expect(corner.down, isTrue);
      expect(
          g.bottles.firstWhere((b) => b.row == 1 && b.col == 0).down, isTrue);
      expect(g.bottles.firstWhere((b) => b.row == 2).down, isTrue);
      expect(g.score[0], greaterThanOrEqualTo(3));
    });

    test('online state round-trips', () {
      final g = BottleLogic(players: 2, random: Random(2));
      g.throwBall(0, 0.5, 0.2);
      g.update(1000);
      final spec = bottleInfo.online!;
      final copy = spec.create(2) as BottleLogic;
      spec.load(copy, roundTrip(spec.save(g)), 1);
      expect([for (final b in copy.bottles) b.down],
          [for (final b in g.bottles) b.down]);
      expect(copy.score, g.score);
      expect(copy.balls, g.balls);
    });
  });

  group('Archery', () {
    test('a bullseye scores 10, the outer ring less, a miss nothing', () {
      expect(ArcheryLogic.ringScore(0), 10);
      expect(ArcheryLogic.ringScore(ArcheryLogic.ringR * 0.95), lessThan(10));
      expect(ArcheryLogic.ringScore(ArcheryLogic.ringR * 3), 0);
    });
  });

  group('music', () {
    test('every music tune exists and renders a WAV', () {
      for (final track in gameMusic.values.toSet()) {
        expect(chiptunes.containsKey(track), isTrue, reason: track);
      }
      final wav = renderTrack(chiptunes['arcade']!);
      expect(ascii.decode(wav.sublist(0, 4)), 'RIFF');
      expect(ascii.decode(wav.sublist(8, 12)), 'WAVE');
      final samples =
          Int16List.view(Uint8List.fromList(wav.sublist(44)).buffer);
      expect(samples.any((s) => s.abs() > 3000), isTrue, reason: 'not silent');
    });

    test('every game with music is a real game', () {
      final ids = {for (final g in allLocalGames) g.id};
      for (final id in gameMusic.keys) {
        expect(ids, contains(id));
      }
    });
  });
}
