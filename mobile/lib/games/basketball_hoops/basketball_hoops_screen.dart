import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/session/game_session_manager.dart';

class BasketballHoopsScreen extends StatefulWidget {
  const BasketballHoopsScreen({super.key});
  @override
  State<BasketballHoopsScreen> createState() => _BasketballHoopsScreenState();
}

class _BasketballHoopsScreenState extends State<BasketballHoopsScreen> {
  Timer? _clock;
  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(milliseconds: 100), (_) {
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
    final session = context.watch<GameSessionManager>();
    final state = session.state!;
    final players = (state['players'] as List).cast<Map>();
    final phase = state['phase'] as String;
    final end = (state['endsAt'] as num).toInt();
    final now = session.serverNowMs;
    final seconds = ((end - now) <= 0 ? 0 : ((end - now) / 1000).ceil());
    final target = (state['target'] as num).toDouble();
    final yourScore = (state['yourScore'] as num).toInt();
    final yourShots = (state['yourShots'] as num).toInt();
    final nextShotAt = (state['nextShotAt'] as num).toInt();
    final canShoot = phase == 'playing' && now >= nextShotAt;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Text(phase == 'playing' ? 'BASKETBALL HOOPS' : 'TIME UP',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        Text('$seconds s remaining • $yourShots shots • $yourScore points'),
        const SizedBox(height: 18),
        _TargetMeter(target: target),
        const SizedBox(height: 18),
        Text(
            canShoot
                ? 'Tap SHOOT when your marker is near the target!'
                : 'Get ready…',
            textAlign: TextAlign.center),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 180,
          child: FilledButton(
            onPressed: canShoot
                ? () {
                    final position = _currentMarkerPosition(
                        session.serverNowMs,
                        (state['startedAt'] as num).toInt(),
                        (state['targetCycleMs'] as num).toInt());
                    session.action('basketball:shoot', {'timing': position});
                  }
                : null,
            child: const Text('SHOOT!',
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
          ),
        ),
        const SizedBox(height: 18),
        Expanded(
            child: ListView(children: [
          for (final p in players)
            Card(
                child: ListTile(
              title: Text(p['username'].toString()),
              trailing: Text(p['score'].toString() + ' pts',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            )),
        ])),
      ]),
    );
  }

  double _currentMarkerPosition(int now, int startedAt, int cycleMs) {
    if (cycleMs <= 0) return 50;
    final phase = ((now - startedAt) % cycleMs) / cycleMs;
    final wave = phase <= 0.5 ? phase * 200 : (1 - phase) * 200;
    return wave.clamp(0, 100);
  }
}

class _TargetMeter extends StatelessWidget {
  final double target;
  const _TargetMeter({required this.target});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('MISS'),
        Text('2 PT'),
        Text('3 PT'),
        Text('2 PT'),
        Text('MISS')
      ]),
      const SizedBox(height: 8),
      SizedBox(
          height: 30,
          child: Stack(children: [
            Container(
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest)),
            FractionallySizedBox(
                widthFactor: (target / 100).clamp(0, 1),
                child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                        width: 4,
                        height: 30,
                        color: Theme.of(context).colorScheme.primary))),
          ])),
      const SizedBox(height: 6),
      Text('Target position: ' + target.round().toString()),
    ]);
  }
}
