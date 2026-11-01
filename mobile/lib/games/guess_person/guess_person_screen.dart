import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/authentication_manager.dart';
import '../../core/session/game_session_manager.dart';

class GuessPersonScreen extends StatefulWidget {
  const GuessPersonScreen({super.key});
  @override
  State<GuessPersonScreen> createState() => _GuessPersonScreenState();
}

class _GuessPersonScreenState extends State<GuessPersonScreen> {
  final ctrl = TextEditingController();
  Timer? _clock;
  String? feedback;
  Color feedbackColor = Colors.grey;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(milliseconds: 250),
        (_) => setState(() {})); // countdown redraw only
  }

  @override
  void dispose() {
    _clock?.cancel();
    ctrl.dispose();
    super.dispose();
  }

  int _secsLeft(GameSessionManager s, num? endsAt) {
    if (endsAt == null) return 0;
    final ms = endsAt.toInt() - s.serverNowMs;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  Future<void> _send() async {
    final text = ctrl.text.trim();
    if (text.isEmpty) return;
    ctrl.clear();
    final r = await context
        .read<GameSessionManager>()
        .action('guess_person:answer', {'text': text});
    if (!mounted) return;
    setState(() {
      if (r['ok'] != true) {
        feedback =
            _errors[r['error']] ?? 'Could not send answer (${r['error']}).';
        feedbackColor = Colors.orangeAccent;
      } else {
        final resp = Map<String, dynamic>.from(r['response'] as Map);
        if (resp['correct'] == true) {
          feedback = 'Correct! +${resp['points']} points';
          feedbackColor = Colors.greenAccent;
        } else {
          feedback = 'Not quite. ${resp['attemptsLeft']} attempt(s) left.';
          feedbackColor = Colors.redAccent;
        }
      }
    });
  }

  static const _errors = {
    'NO_ATTEMPTS': 'No attempts left this round.',
    'ALREADY_SOLVED': 'You already got it!',
    'BAD_PHASE': 'Round is over.',
  };

  @override
  Widget build(BuildContext context) {
    final session = context.watch<GameSessionManager>();
    final st = session.state!;
    final myId = context.read<AuthenticationManager>().token.split(':')[1];
    final phase = st['phase'] as String;
    final players = (st['players'] as List).cast<Map>();
    final scores = Map<String, dynamic>.from(st['scores'] as Map);
    final clues = (st['clues'] as List).cast<String>();
    final you = Map<String, dynamic>.from(st['you'] as Map);
    final solvedBy = (st['solvedBy'] as List).cast<String>();
    final inRound = phase == 'round';
    final reveal = st['reveal'] == null
        ? null
        : Map<String, dynamic>.from(st['reveal'] as Map);
    final theme = Theme.of(context);

    if (inRound == false && phase != 'reveal') return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Round ${st['round']} / ${st['totalRounds']}',
              style: theme.textTheme.titleMedium),
          Text(
              inRound
                  ? '${_secsLeft(session, st['roundEndsAt'] as num?)}s'
                  : 'Next in ${_secsLeft(session, st['revealEndsAt'] as num?)}s',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, children: [
          for (final p in players)
            Chip(
              avatar: solvedBy.contains(p['userId'])
                  ? const Icon(Icons.check_circle,
                      color: Colors.greenAccent, size: 18)
                  : null,
              label: Text(
                  '${p['username']}${p['userId'] == myId ? ' (you)' : ''}: ${scores[p['userId']]}'),
            ),
        ]),
        const SizedBox(height: 12),
        Text('WHO AM I?', style: theme.textTheme.labelLarge),
        Expanded(
          child: ListView(children: [
            for (var i = 0; i < clues.length; i++)
              Card(
                  child: ListTile(
                      leading:
                          CircleAvatar(radius: 14, child: Text('${i + 1}')),
                      title: Text(clues[i]))),
            if (inRound && st['nextClueAt'] != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                    'Next clue in ${_secsLeft(session, st['nextClueAt'] as num?)}s (fewer clues = more points)',
                    style: theme.textTheme.bodySmall),
              ),
          ]),
        ),
        if (!inRound && reveal != null) ...[
          Text('The answer: ${reveal['answer']}',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
              (reveal['gained'] as Map).containsKey(myId)
                  ? 'You earned ${(reveal['gained'] as Map)[myId]} points'
                  : 'You did not get it this time',
              textAlign: TextAlign.center),
        ] else if (you['solved'] == true)
          const Text('You got it! Waiting for the others...',
              textAlign: TextAlign.center)
        else ...[
          if (feedback != null)
            Text(feedback!,
                textAlign: TextAlign.center,
                style: TextStyle(color: feedbackColor)),
          Text('Attempts left: ${you['attemptsLeft']}',
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: ctrl,
                enabled: (you['attemptsLeft'] as int) > 0,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    hintText: 'Type your guess', border: OutlineInputBorder()),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
                onPressed: (you['attemptsLeft'] as int) > 0 ? _send : null,
                child: const Text('GUESS')),
          ]),
        ],
      ]),
    );
  }
}
