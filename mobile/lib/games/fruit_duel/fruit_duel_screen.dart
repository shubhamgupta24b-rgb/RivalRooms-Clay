import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/ui/components.dart';
import 'package:provider/provider.dart';
import '../../core/session/game_session_manager.dart';

class FruitDuelScreen extends StatefulWidget {
  const FruitDuelScreen({super.key});
  @override
  State<FruitDuelScreen> createState() => _FruitDuelScreenState();
}

class _FruitDuelScreenState extends State<FruitDuelScreen> {
  Timer? timer;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<GameSessionManager>();
    final state = session.state!;
    final phase = state['phase'] as String;
    final end = (state['endsAt'] as num).toInt();
    final left = ((end - session.serverNowMs) <= 0
        ? 0
        : ((end - session.serverNowMs) / 1000).ceil());
    final lane = (state['fruitLane'] as num).toInt();
    final id = (state['fruitId'] as num).toInt();
    final players = (state['players'] as List).cast<Map>();
    return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Text(phase == 'playing' ? 'FRUIT DUEL' : 'TIME UP',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          Text(left.toString() +
              ' s • Your score: ' +
              state['yourScore'].toString()),
          const SizedBox(height: 16),
          const Text('SLASH THE FRUIT!'),
          const SizedBox(height: 12),
          Expanded(
              child: Row(children: [
            for (int i = 0; i < 3; i++)
              Expanded(
                  child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: FilledButton(
                        onPressed: phase == 'playing'
                            ? () => session.action(
                                'fruit_duel:slash', {'fruitId': id, 'lane': i})
                            : null,
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              i == lane
                                  ? const GameIcon(GameIcons.apple, size: 58)
                                  : const Text('•',
                                      style: TextStyle(fontSize: 30)),
                              Text('LANE ' + (i + 1).toString())
                            ]),
                      )))
          ])),
          const SizedBox(height: 12),
          for (final player in players)
            ListTile(
                dense: true,
                title: Text(player['username'].toString()),
                trailing: Text(player['score'].toString() + ' pts')),
        ]));
  }
}
