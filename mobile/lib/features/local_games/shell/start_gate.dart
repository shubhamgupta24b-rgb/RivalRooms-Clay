import 'package:flutter/material.dart';
import '../../../core/ui/components.dart';
import 'local_game_shell.dart' show PauseButton;

/// Ready, then 3-2-1, then [child]. The child is not built until GO, so a game
/// clock does not start while the player is still reading the level menu.
class StartGate extends StatefulWidget {
  final Color color;
  final WidgetBuilder child;
  final String ready;
  const StartGate(
      {super.key,
      required this.color,
      required this.child,
      this.ready = 'Tap to start'});

  @override
  State<StartGate> createState() => _StartGateState();
}

enum _Gate { ready, count, play }

class _StartGateState extends State<StartGate> {
  var _phase = _Gate.ready;

  @override
  Widget build(BuildContext context) {
    final body = switch (_phase) {
      _Gate.play => widget.child(context),
      _Gate.count => CountdownOverlay(
          color: widget.color,
          onDone: () {
            if (mounted) setState(() => _phase = _Gate.play);
          },
        ),
      _Gate.ready => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Tap to start',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: Fonts.display,
                        color: Colors.white,
                        fontSize: 40)),
                const SizedBox(height: 8),
                const Text('A short countdown, then you play.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: Fonts.body,
                        color: Colors.white70,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 20),
                GoldButton(widget.ready,
                    height: 58,
                    fontSize: 24,
                    onPressed: () => setState(() => _phase = _Gate.count)),
              ]),
        ),
    };
    if (_phase == _Gate.play) return body;
    return Stack(children: [
      body,
      const Positioned(left: 8, top: 8, child: PauseButton()),
    ]);
  }
}
