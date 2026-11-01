import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/authentication_manager.dart';
import '../../core/session/game_session_manager.dart';
import '../../features/guess_person/data/person_data.dart';
import '../../features/guess_person/models/gp_question.dart';
import '../../features/guess_person/models/person.dart';
import '../../features/guess_person/widgets/gp_theme.dart';
import '../../features/guess_person/widgets/person_card.dart';
import '../../features/guess_person/widgets/person_grid.dart';
import '../../features/guess_person/widgets/question_panel.dart';

/// Two-phone Guess Who. The server holds both secrets and answers every question;
/// this screen only shows your own secret. Crossing people out is local to your phone.
class GuessWhoScreen extends StatefulWidget {
  const GuessWhoScreen({super.key});
  @override
  State<GuessWhoScreen> createState() => _GuessWhoScreenState();
}

class _GuessWhoScreenState extends State<GuessWhoScreen> {
  static final _people = {for (final p in allPeople) p.id: p};
  final Set<int> _eliminated = {};
  int? _round;
  bool _finalMode = false;
  int? _pendingGuess;
  int? _picked; // optimistic highlight while a choose is in flight
  bool _busy = false;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {}); // reveal countdown
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _send(String type, Map<String, dynamic> payload) async {
    if (_busy) return;
    setState(() => _busy = true);
    final r = await context
        .read<GameSessionManager>()
        .action('guess_who:$type', payload);
    if (!mounted) return;
    setState(() => _busy = false);
    if (r['ok'] != true) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content: Text(
                _errors[r['error']] ?? 'Could not do that (${r['error']}).')));
    }
  }

  static const _errors = {
    'NOT_YOUR_TURN': "It's not your turn.",
    'ALREADY_ASKED': 'You already asked that.',
    'BAD_PHASE': 'Not possible right now.',
    'OFFLINE': 'You are offline.',
    'TIMEOUT': 'Server did not respond.',
  };

  @override
  Widget build(BuildContext context) {
    final session = context.watch<GameSessionManager>();
    final st = session.state!;
    final myId = context.read<AuthenticationManager>().token.split(':')[1];
    final round = (st['round'] as num).toInt();
    if (_round != round) {
      // New round: clear this phone's crossings-out and selections.
      _round = round;
      _eliminated.clear();
      _finalMode = false;
      _pendingGuess = null;
      _picked = null;
    }
    final phase = st['phase'] as String;
    final players = (st['players'] as List).cast<Map>();
    final me = players.firstWhere((p) => p['userId'] == myId,
        orElse: () => players.first);
    final opp = players.firstWhere((p) => p['userId'] != myId,
        orElse: () => players.last);
    final you = Map<String, dynamic>.from(st['you'] as Map);
    final board = [
      for (final id in (st['board'] as List))
        if (_people[id] != null) _people[id]!
    ];
    final questions = [
      for (final q in (st['questions'] as List).cast<Map>())
        GpQuestion(q['id'] as String, q['label'] as String,
            q['prompt'] as String, (_) => false,
            category: q['category'] as String),
    ];
    final asked = {
      for (final h in (you['asked'] as List).cast<Map>())
        h['questionId'] as String: h['answer'] as bool
    };

    final Widget body = switch (phase) {
      'choosing' => _choosing(you, opp, board),
      'playing' => _playing(st, myId, you, opp, board, questions, asked),
      _ => _reveal(st, session, myId, me, opp),
    };
    return CoralBackground(
        child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10), child: body));
  }

  Widget _header(Map<String, dynamic> st, Map me, Map opp,
      {String? status, Color? statusColor}) {
    final scores = Map<String, dynamic>.from(st['scores'] as Map);
    // Wrap, not Row: long names drop to a second line instead of overflowing.
    return Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 6,
        runSpacing: 6,
        children: [
          _pill('ROUND ${st['round']}/${st['totalRounds']}'),
          _pill(
              '${me['username']} ${scores[me['userId']]} – ${scores[opp['userId']]} ${opp['username']}'),
          if (status != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: statusColor ?? GpCoral.panel,
                  borderRadius: BorderRadius.circular(16)),
              child: Text(status,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13)),
            ),
        ]);
  }

  Widget _pill(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: GpCoral.panel, borderRadius: BorderRadius.circular(16)),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 13)),
      );

  Widget _choosing(Map<String, dynamic> you, Map opp, List<Person> board) {
    final mine = you['secretId'] as int? ?? _picked;
    final waiting = you['secretId'] != null;
    final st = context.read<GameSessionManager>().state!;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _header(
          st,
          (st['players'] as List)
              .cast<Map>()
              .firstWhere((p) => p['userId'] != opp['userId']),
          opp,
          status: opp['chosen'] == true
              ? '${opp['username']} is ready'
              : '${opp['username']} is choosing…'),
      const SizedBox(height: 10),
      Expanded(
        child: PersonGrid(
          people: board,
          markFor: (p) => p.id == mine ? CardMark.selected : CardMark.none,
          badgeFor: (p) => p.id == mine ? 'YOU' : null,
          onTap: (p) {
            setState(() => _picked = p.id);
            _send('choose', {'personId': p.id});
          },
        ),
      ),
      const SizedBox(height: 12),
      Text(
          waiting
              ? 'Waiting for ${opp['username']}…\n(tap another card to change)'
              : 'Choose your\ncharacter!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: waiting ? 20 : 30,
            height: 1.1,
            fontWeight: FontWeight.w900,
            shadows: const [
              Shadow(
                  color: Color(0x55000000), offset: Offset(0, 2), blurRadius: 3)
            ],
          )),
      const SizedBox(height: 4),
      const Text('Your opponent will try to find them.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _playing(
      Map<String, dynamic> st,
      String myId,
      Map<String, dynamic> you,
      Map opp,
      List<Person> board,
      List<GpQuestion> questions,
      Map<String, bool> asked) {
    final myTurn = st['turn'] == myId;
    final secret = _people[you['secretId']];
    final myHistory = (you['asked'] as List).cast<Map>();
    final theirHistory = (st['opponentAsked'] as List).cast<Map>();
    final players = (st['players'] as List).cast<Map>();
    final me = players.firstWhere((p) => p['userId'] == myId);
    GpQuestion? q(String id) => questions.where((x) => x.id == id).firstOrNull;
    final last = myHistory.isEmpty ? null : myHistory.last;
    final lastQ = last == null ? null : q(last['questionId'] as String);
    final theirLast = theirHistory.isEmpty ? null : theirHistory.last;
    final theirQ =
        theirLast == null ? null : q(theirLast['questionId'] as String);
    final pending = _pendingGuess == null ? null : _people[_pendingGuess];

    return LayoutBuilder(builder: (context, box) {
      final controls = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnswerBanner(
              answer: lastQ == null
                  ? null
                  : AskedQuestion(lastQ, last!['answer'] as bool),
              emptyHint: myTurn
                  ? 'Your turn: ask a question or make your final guess.'
                  : 'Waiting for ${opp['username']} to ask…',
            ),
            if (theirQ != null) ...[
              const SizedBox(height: 6),
              Text(
                  '${opp['username']} asked: ${theirQ.prompt} ${theirLast!['answer'] == true ? 'YES' : 'NO'}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
            ],
            const SizedBox(height: 8),
            if (!_finalMode) ...[
              IgnorePointer(
                ignoring: !myTurn || _busy,
                child: Opacity(
                  opacity: myTurn ? 1 : 0.5,
                  child: CategoryPanel(
                      questions: questions,
                      answerFor: (x) => asked[x.id],
                      onAsk: (x) => _send('ask', {'questionId': x.id})),
                ),
              ),
              const SizedBox(height: 8),
              GpButton('MAKE FINAL GUESS',
                  icon: Icons.ads_click_rounded,
                  onPressed: myTurn && !_busy
                      ? () => setState(() => _finalMode = true)
                      : null),
            ] else if (pending == null)
              GpButton('CANCEL',
                  icon: Icons.close_rounded,
                  color: Colors.white,
                  onPressed: () => setState(() => _finalMode = false))
            else
              DarkPanel(
                padding: const EdgeInsets.all(10),
                child: Row(children: [
                  SizedBox(
                      width: 70,
                      height: 90,
                      child: PersonCard(person: pending)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Is ${pending.name} your final guess?',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900)),
                          const SizedBox(height: 6),
                          GpButton('YES, GUESS',
                              color: GpColors.yes,
                              textColor: Colors.white,
                              onPressed: _busy
                                  ? null
                                  : () =>
                                      _send('guess', {'personId': pending.id})),
                          const SizedBox(height: 6),
                          GpButton('CANCEL',
                              outlined: true,
                              onPressed: () =>
                                  setState(() => _pendingGuess = null)),
                        ]),
                  ),
                ]),
              ),
          ]);
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _header(st, me, opp,
            status: myTurn
                ? 'YOUR TURN'
                : "${opp['username'].toString().toUpperCase()}'S TURN",
            statusColor: myTurn ? GpColors.yes.withValues(alpha: 0.9) : null),
        const SizedBox(height: 6),
        if (secret != null)
          Text(
              'You are ${secret.name} · ${board.length - _eliminated.length} left',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800)),
        if (_finalMode)
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
                color: GpColors.accent,
                borderRadius: BorderRadius.circular(14)),
            child: const Text('WHO IS IT? Tap your final guess',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: GpColors.ink, fontWeight: FontWeight.w900)),
          ),
        const SizedBox(height: 6),
        Expanded(
          child: PersonGrid(
            people: board,
            markFor: (p) => _eliminated.contains(p.id)
                ? CardMark.eliminated
                : (p.id == _pendingGuess ? CardMark.selected : CardMark.none),
            badgeFor: (p) => p.id == _pendingGuess ? 'GUESS' : null,
            onTap: (p) => setState(() {
              if (!_finalMode) {
                if (!_eliminated.remove(p.id)) _eliminated.add(p.id);
              } else if (!_eliminated.contains(p.id)) {
                _pendingGuess = p.id;
              }
            }),
          ),
        ),
        const SizedBox(height: 8),
        box.maxHeight < 700
            ? ConstrainedBox(
                constraints: BoxConstraints(maxHeight: box.maxHeight * 0.45),
                child: SingleChildScrollView(child: controls))
            : controls,
      ]);
    });
  }

  Widget _reveal(Map<String, dynamic> st, GameSessionManager session,
      String myId, Map me, Map opp) {
    final rv = st['reveal'] == null
        ? null
        : Map<String, dynamic>.from(st['reveal'] as Map);
    if (rv == null) return const Center(child: CircularProgressIndicator());
    final secrets = Map<String, dynamic>.from(rv['secrets'] as Map);
    final iWon = rv['winner'] == myId;
    final guesser = rv['guessedBy'] == myId ? 'You' : opp['username'];
    final guessed = _people[rv['guess']];
    final why = rv['correct'] == true
        ? '$guesser guessed right!'
        : '$guesser guessed ${guessed?.name ?? '?'}, which was wrong.';
    final ends = st['revealEndsAt'] as num?;
    final left = ends == null
        ? null
        : ((ends.toInt() - session.serverNowMs) / 1000).ceil().clamp(0, 99);
    Widget who(String label, int? id) {
      final p = _people[id];
      return Expanded(
        child: Column(children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          if (p != null)
            SizedBox(width: 110, height: 140, child: PersonCard(person: p)),
        ]),
      );
    }

    return Center(
      child: SingleChildScrollView(
        child: DarkPanel(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
                iWon
                    ? 'YOU WIN THE ROUND!'
                    : '${opp['username']} wins the round',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: iWon ? GpColors.yes : GpColors.no,
                    fontSize: 24,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(why,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            Row(children: [
              who('You were', secrets[myId] as int?),
              who("${opp['username']} was", secrets[opp['userId']] as int?),
            ]),
            const SizedBox(height: 16),
            _header(st, me, opp),
            if (left != null) ...[
              const SizedBox(height: 10),
              Text(
                  st['round'] == st['totalRounds']
                      ? 'Final scores in ${left}s'
                      : 'Next round in ${left}s',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ],
          ]),
        ),
      ),
    );
  }
}
