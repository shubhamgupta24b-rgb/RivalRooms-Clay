import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/session/game_session_manager.dart';

class CrushItScreen extends StatefulWidget {
  const CrushItScreen({super.key});
  @override
  State<CrushItScreen> createState() => _CrushItScreenState();
}

class _CrushItScreenState extends State<CrushItScreen> {
  Timer? _clock;
  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<GameSessionManager>(), st = s.state!;
    final players = (st['players'] as List).cast<Map>();
    final phase = st['phase'] as String;
    final end = st['endsAt'] as num;
    final ms = end.toInt() - s.serverNowMs;
    final left = ms <= 0 ? 0 : (ms / 1000).ceil();
    final mine = st['yourTaps'] as int;
    return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Text(phase == 'playing' ? 'CRUSH IT!' : 'TIME UP',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          Text(phase == 'playing' ? '$left seconds remaining' : 'Final taps',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          for (final p in players)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Expanded(child: Text(p['username'].toString())),
                  Text(p['taps'].toString(),
                      style: const TextStyle(fontWeight: FontWeight.bold))
                ])),
          const Spacer(),
          Text('$mine',
              style: Theme.of(context)
                  .textTheme
                  .displayLarge
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          SizedBox(
              width: 220,
              height: 220,
              child: FilledButton(
                onPressed: phase == 'playing'
                    ? () => context
                        .read<GameSessionManager>()
                        .action('crush_it:tap', {})
                    : null,
                child: const Text('CRUSH!',
                    style:
                        TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              )),
          const SizedBox(height: 20),
        ]));
  }
}
