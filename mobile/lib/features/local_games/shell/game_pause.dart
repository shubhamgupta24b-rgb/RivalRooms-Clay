import 'package:flutter/widgets.dart';

/// Whether the one-device game below is paused (the pause menu is open). The shell provides
/// it; [TickingPlay] stops the game clock while it's true, so no time passes in the game.
class GamePause extends InheritedNotifier<ValueNotifier<bool>> {
  const GamePause(
      {super.key, required ValueNotifier<bool> paused, required super.child})
      : super(notifier: paused);

  static ValueNotifier<bool>? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GamePause>()?.notifier;
}
