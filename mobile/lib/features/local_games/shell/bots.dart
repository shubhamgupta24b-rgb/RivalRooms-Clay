import 'dart:math';
import 'package:flutter/widgets.dart';
import 'local_game_logic.dart';

/// One computer player. Bots "think" between moves so they feel human, not instant.
class BotSeat {
  final int seat;
  final Random rng;
  int _readyAt = 0;
  final Map<String, Object?> memory =
      {}; // per-game notes (e.g. cards seen in Memory)
  /// True when only one person plays (against bots only): no need to pass the phone.
  final bool loneHuman;
  BotSeat(this.seat, [Random? random, this.loneHuman = true])
      : rng = random ?? Random();

  bool due(int now) => now >= _readyAt;

  /// Don't act again until [minMs]-[maxMs] from now.
  void wait(int now, int minMs, int maxMs) =>
      _readyAt = now + minMs + rng.nextInt(max(1, maxMs - minMs + 1));

  bool chance(double p) => rng.nextDouble() < p;

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
