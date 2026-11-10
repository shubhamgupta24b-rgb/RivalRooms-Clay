import 'dart:math';
import 'package:flutter/widgets.dart';
import 'local_game_logic.dart';

/// How strong a computer opponent is. Every bot reads this from its [BotSeat]:
/// reaction time ([CpuSkill.delayScale] on [BotSeat.wait] / [BotSeat.thinkFirst]),
/// aim error ([BotSeat.aimNoise]) and decision quality ([BotSeat.slips]).
enum CpuDifficulty { easy, medium, hard }

/// Numbers behind [CpuDifficulty]. Medium keeps the old reaction timing.
class CpuSkill {
  final CpuDifficulty level;
  const CpuSkill(this.level);

  /// Multiplier on think and reaction pauses. Easy waits longer.
  double get delayScale => switch (level) {
        CpuDifficulty.easy => 1.75,
        CpuDifficulty.medium => 1,
        CpuDifficulty.hard => 0.68,
      };

  /// Fraction of a table (or of a radian, when the caller scales it) of aim error.
  double get aimError => switch (level) {
        CpuDifficulty.easy => 0.22,
        CpuDifficulty.medium => 0.07,
        CpuDifficulty.hard => 0.02,
      };

  /// Chance of ignoring the best move.
  double get mistakeRate => switch (level) {
        CpuDifficulty.easy => 0.48,
        CpuDifficulty.medium => 0.14,
        CpuDifficulty.hard => 0.03,
      };

  /// How quickly a real-time bot tracks a target, relative to its old step.
  double get tracking => switch (level) {
        CpuDifficulty.easy => 0.48,
        CpuDifficulty.medium => 0.78,
        CpuDifficulty.hard => 1.05,
      };
}

/// One computer player. Bots "think" between moves so they feel human, not instant.
class BotSeat {
  final int seat;
  final Random rng;
  int _readyAt = 0;
  final Map<String, Object?> memory =
      {}; // per-game notes (e.g. cards seen in Memory)
  /// True when only one person plays (against bots only): no need to pass the phone.
  final bool loneHuman;
  final CpuDifficulty difficulty;
  CpuSkill get skill => CpuSkill(difficulty);
  BotSeat(this.seat,
      [Random? random,
      this.loneHuman = true,
      this.difficulty = CpuDifficulty.medium])
      : rng = random ?? Random();

  bool due(int now) => now >= _readyAt;

  /// Don't act again until [minMs]-[maxMs] from now, stretched by the difficulty.
  void wait(int now, int minMs, int maxMs) {
    final scale = skill.delayScale;
    final a = max(1, (minMs * scale).round());
    final b = max(a, (maxMs * scale).round());
    _readyAt = now + a + rng.nextInt(max(1, b - a + 1));
  }

  bool chance(double p) => rng.nextDouble() < p;

  /// True when this difficulty should play a worse move instead of the best one.
  bool slips() => chance(skill.mistakeRate);

  /// Signed aim error. [scale] is the span (radians, or a fraction of the table).
  double aimNoise([double scale = 1]) =>
      (rng.nextDouble() * 2 - 1) * skill.aimError * scale;

  /// [ranked] is best-first. Easy often skips the best entry.
  T prefer<T>(List<T> ranked) {
    if (ranked.isEmpty) {
      throw StateError('prefer called with no options');
    }
    if (ranked.length == 1 || !slips()) return ranked.first;
    return ranked[1 + rng.nextInt(ranked.length - 1)];
  }

  /// "Think" before acting on a new situation: the first call for a new [situation]
  /// starts a [minMs]-[maxMs] pause and returns false; afterwards true once the pause is over.
  bool thinkFirst(Object situation, int now, int minMs, int maxMs) {
    if (memory['situation'] != situation) {
      memory['situation'] = situation;
      wait(now, minMs, maxMs);
      return false;
    }
    return due(now);
  }

  T pick<T>(List<T> items) => items[rng.nextInt(items.length)];
}

/// Called every frame for every computer seat; looks at the game and maybe makes a move.
typedef BotTurn = void Function(LocalGameLogic g, BotSeat bot, int nowMs);

/// Typed helper so each game writes its bot against its own logic class.
BotTurn botFor<T extends LocalGameLogic>(
        void Function(T g, BotSeat bot, int nowMs) turn) =>
    (g, b, n) => turn(g as T, b, n);

/// Tells a game which seats the computer plays. People sit in the first seats.
class BotScope extends InheritedWidget {
  final List<BotSeat> seats;
  final BotTurn turn;
  final int
      people; // how many people share the phone (the seats before the bots)
  const BotScope(
      {super.key,
      required this.seats,
      required this.turn,
      this.people = 1,
      required super.child});

  static BotScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BotScope>();

  /// The one person's seat when they play alone against the computer, else null
  /// (no bots, or several people passing the phone between them).
  static int? humanSeat(BuildContext context) {
    final s = maybeOf(context);
    return s != null && s.people == 1 ? 0 : null;
  }

  /// True for seats the computer plays.
  static bool isBot(BuildContext context, int seat) =>
      maybeOf(context)?.seats.any((b) => b.seat == seat) ?? false;

  @override
  bool updateShouldNotify(BotScope old) =>
      old.seats != seats || old.turn != turn || old.people != people;
}
