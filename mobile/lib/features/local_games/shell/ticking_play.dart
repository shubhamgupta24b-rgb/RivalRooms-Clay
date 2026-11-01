import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'bots.dart';
import 'game_pause.dart';
import 'local_game_logic.dart';

/// Hosts a [LocalGameLogic]: drives it from a Ticker, rebuilds on change, reports the
/// final scores exactly once, and disposes everything with the widget.
/// While the shell's pause menu is open ([GamePause]) the clock stops; the game then
/// carries on from the same moment, so pausing never costs time.
class TickingPlay<T extends LocalGameLogic> extends StatefulWidget {
  final T Function() create;
  final Widget Function(BuildContext context, T logic) builder;
  final void Function(List<int> scores) onFinished;
  const TickingPlay(
      {super.key,
      required this.create,
      required this.builder,
      required this.onFinished});

  @override
  State<TickingPlay<T>> createState() => _TickingPlayState<T>();
}

class _TickingPlayState<T extends LocalGameLogic> extends State<TickingPlay<T>>
    with SingleTickerProviderStateMixin {
  late final T logic = widget.create();
  late final Ticker _ticker;
  bool _reported = false;
  BotScope? _bots; // computer players, when playing against the computer
  ValueNotifier<bool>? _pause;
  int _base = 0,
      _last =
          0; // game time before the current run of the ticker, and the latest time

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bots = BotScope.maybeOf(context);
    final p = GamePause.maybeOf(context);
    if (!identical(p, _pause)) {
      _pause?.removeListener(_onPause);
      _pause = p?..addListener(_onPause);
      _onPause();
    }
  }

  void _onPause() {
    final paused = _pause?.value ?? false;
    if (paused && _ticker.isActive) {
      _ticker.stop();
      _base = _last;
    } else if (!paused && !_ticker.isActive && !_reported) {
      _ticker.start();
    }
  }

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final ms = _last = _base + elapsed.inMilliseconds;
      logic.update(ms);
      final bots = _bots;
      if (bots != null && !logic.finished) {
        for (final b in bots.seats) {
          bots.turn(logic, b, ms);
        }
      }
      if (logic.finished && !_reported) {
        _reported = true;
        _ticker.stop();
        // Short pause so players see the final state before the result screen.
        Future.delayed(const Duration(milliseconds: 700), () {
          if (mounted) widget.onFinished(List.of(logic.scores));
        });
      }
    })
      ..start();
  }

  @override
  void dispose() {
    _pause?.removeListener(_onPause);
    _ticker.dispose();
    logic.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
      child: ListenableBuilder(
          listenable: logic,
          builder: (context, _) => widget.builder(context, logic)));
}
