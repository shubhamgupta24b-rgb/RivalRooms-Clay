import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/authentication_manager.dart';
import '../../core/session/game_session_manager.dart';

class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key});
  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
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
    final session = context.watch<GameSessionManager>();
    final st = session.state!;
    final myId = context.read<AuthenticationManager>().token.split(':')[1];
    final cards = (st['cards'] as List).cast<Map>();
    final players = (st['players'] as List).cast<Map>();
    final scores = Map<String, dynamic>.from(st['scores'] as Map);
    final turn = st['turn'] as String, phase = st['phase'] as String;
    final canPlay = phase == 'turn' && turn == myId;
    int left() {
      final e = st['mismatchEndsAt'];
      if (e is! num) return 0;
      final ms = e.toInt() - session.serverNowMs;
      return ms <= 0 ? 0 : (ms / 1000).ceil();
    }

    final turnName = players.firstWhere((p) => p['userId'] == turn)['username'];
    return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Wrap(spacing: 8, children: [
            for (final p in players)
              Chip(
                  label: Text(p['username'].toString() +
                      ' : ' +
                      scores[p['userId']].toString()))
          ]),
          const SizedBox(height: 6),
          Text(
              phase == 'mismatch'
                  ? 'Pair shown — next turn in ' + left().toString() + 's'
                  : canPlay
                      ? 'Your turn'
                      : turnName.toString() + "'s turn",
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Expanded(
              child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8),
                  itemCount: cards.length,
                  itemBuilder: (_, i) {
                    final c = cards[i];
                    final value = c['value'];
                    final visible = value != null;
                    return InkWell(
                        onTap: canPlay && !visible && c['matched'] != true
                            ? () => context
                                .read<GameSessionManager>()
                                .action('memory:flip', {'id': c['id']})
                            : null,
                        child: Card(
                            child: Center(
                                child: Text(visible ? value.toString() : '?',
                                    style: TextStyle(
                                        fontSize: visible ? 32 : 26,
                                        fontWeight: FontWeight.bold)))));
                  })),
        ]));
  }
}
