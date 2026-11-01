import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/auth/authentication_manager.dart';
import '../../core/session/game_session_manager.dart';
import '../../features/guess_person/models/gp_player.dart';
import '../../features/guess_person/widgets/gp_theme.dart';
import '../../features/raja_mantri/rmcs_role.dart';
import '../../features/raja_mantri/widgets/rmcs_widgets.dart';

/// Four-phone Raja Mantri Chor Sipahi. The server deals the cards and only ever sends
/// you your own card (plus the Raja and Mantri once they are announced).
class RajaMantriScreen extends StatefulWidget {
  const RajaMantriScreen({super.key});
  @override
  State<RajaMantriScreen> createState() => _RajaMantriScreenState();
}

class _RajaMantriScreenState extends State<RajaMantriScreen> {
  Timer? _clock;
  int? _round;
  bool _dealt = false; // deal animation finished for this round
  bool _peeking = false; // my card turned over (only on my phone)
  bool _busy = false;
  String? _lastPhase;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted) setState(() {}); // countdowns
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _accuse(String targetId) async {
    if (_busy) return;
    HapticFeedback.selectionClick().ignore();
    setState(() => _busy = true);
    final r = await context
        .read<GameSessionManager>()
        .action('raja_mantri:guess', {'targetId': targetId});
    if (!mounted) return;
    setState(() => _busy = false);
    if (r['ok'] != true) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content: Text(r['error'] == 'BAD_PHASE'
                ? 'Too late: time is up!'
                : 'Could not do that (${r['error']}).')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<GameSessionManager>();
    final st = session.state!;
    final myId = context.read<AuthenticationManager>().token.split(':')[1];
    final round = (st['round'] as num).toInt();
    if (_round != round) {
      _round = round;
      _dealt = false;
      _peeking = false;
    }
    final phase = st['phase'] as String;
    if (phase != _lastPhase) {
      if (phase == 'reveal') HapticFeedback.heavyImpact().ignore();
      if (phase == 'raja') HapticFeedback.mediumImpact().ignore();
      _lastPhase = phase;
    }
    final players = (st['players'] as List).cast<Map>();
    final ids = [for (final p in players) p['userId'] as String];
    String name(String id) =>
        (players.firstWhere((p) => p['userId'] == id)['username'] ?? id)
            .toString();
    final scores = Map<String, dynamic>.from(st['scores'] as Map);
    final roles = {
      for (final e in Map<String, dynamic>.from(st['roles'] as Map).entries)
        e.key: RmcsRole.parse(e.value as String)
    };
    final myRole = st['yourRole'] == null
        ? null
        : RmcsRole.parse(st['yourRole'] as String);
    final result = st['result'] == null
        ? null
        : Map<String, dynamic>.from(st['result'] as Map);
    final endsAt = (st['phaseEndsAt'] as num?)?.toInt();
    final msLeft =
        endsAt == null ? 0 : (endsAt - session.serverNowMs).clamp(0, 1 << 30);
    final guessMs = (st['guessMs'] as num?)?.toInt() ?? 10000;
    String? holder(RmcsRole r) =>
        roles.entries.where((e) => e.value == r).map((e) => e.key).firstOrNull;
    final raja = holder(RmcsRole.raja), mantri = holder(RmcsRole.mantri);
    final suspects = [
      for (final id in ids)
        if (id != raja && id != mantri) id
    ];
    final iAmMantri = myRole == RmcsRole.mantri;
    final over = phase == 'reveal' || phase == 'finished';
    final caught = result?['caught'] == true;
    final accused = result?['guess'] as String?;

    Widget seat(String id) {
      final i = ids.indexOf(id);
      final role = roles[id];
      final me = id == myId;
      var faceUp = role != null && (!me || _peeking || phase != 'dealing');
      String? badge;
      var badgeColor = RmcsColors.gold;
      var highlight = false;
      VoidCallback? onTap;
      if (phase == 'dealing' && me) {
        faceUp = _peeking;
        highlight = true;
        badge = _peeking ? 'TAP TO HIDE' : 'TAP TO SEE YOUR CARD';
        onTap = () => setState(() => _peeking = !_peeking);
      }
      if (phase == 'raja' || phase == 'guessing')
        highlight = role == RmcsRole.raja || role == RmcsRole.mantri;
      if (phase == 'guessing' && suspects.contains(id)) {
        highlight = iAmMantri;
        if (iAmMantri) {
          badge = 'TAP TO ACCUSE';
          badgeColor = GpColors.no;
          onTap = () => _accuse(id);
        }
      }
      if (over) {
        if (id == accused) {
          badge = caught ? 'CAUGHT!' : 'ACCUSED';
          badgeColor = Colors.white;
        } else if (role == RmcsRole.chor) {
          badge = 'ESCAPED!';
          badgeColor = GpColors.no;
        }
        highlight = role == RmcsRole.chor;
      }
      final points = result == null
          ? null
          : Map<String, dynamic>.from(result['points'] as Map)[id] as num?;
      return RmcsSeat(
        name: me ? '${name(id)} (you)' : name(id),
        color: gpPlayerColors[i % gpPlayerColors.length],
        role: role,
        faceUp: faceUp,
        score: (scores[id] as num).toInt(),
        delta: over ? points?.toInt() : null,
        badge: badge,
        badgeColor: badgeColor,
        highlight: highlight,
        onTap: onTap,
      );
    }

    final Widget headline = switch (phase) {
      'dealing' => RmcsHeadline(
          title: myRole == null
              ? 'Dealing…'
              : (_peeking ? 'You are the ${myRole.title}' : 'Check your card'),
          subtitle: _peeking
              ? '${myRole!.subtitle} · ${myRole.pointsLine}'
              : "Only you can see it. Raja revealed in ${(msLeft / 1000).ceil()}s.",
        ),
      'raja' => RmcsHeadline(
          title: '${raja == null ? '?' : name(raja)} is the RAJA!',
          subtitle:
              '${mantri == null ? '?' : name(mantri)} is the Mantri and must find the Chor.',
        ),
      'guessing' => RmcsHeadline(
          title: iAmMantri
              ? 'Who is the CHOR?'
              : '${mantri == null ? 'The Mantri' : name(mantri)} is choosing…',
          subtitle: iAmMantri
              ? 'Tap ${suspects.map(name).join(' or ')}.'
              : (myRole == RmcsRole.chor
                  ? 'Act natural…'
                  : 'Who will they pick?'),
          trailing: CountdownRing(msLeft: msLeft, totalMs: guessMs, size: 52),
        ),
      _ => ResultBanner(caught: caught, timedOut: result?['timedOut'] == true),
    };

    // Clockwise round the table from my seat at the bottom left.
    final mine = ids.indexOf(myId).clamp(0, ids.length - 1);
    final order = [
      for (var k = 0; k < ids.length; k++) ids[(mine + k) % ids.length]
    ];
    final seats = ids.length == 4
        ? [order[1], order[2], order[0], order[3]].map(seat).toList()
        : ids.map(seat).toList();

    return RmcsBackground(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
        child: Column(children: [
          Text('ROUND $round / ${st['totalRounds']}',
              style: const TextStyle(
                  color: RmcsColors.gold,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: 2)),
          const SizedBox(height: 6),
          headline,
          const SizedBox(height: 8),
          Expanded(
            child: phase == 'dealing' && !_dealt
                ? ShuffleDeal(
                    key: ValueKey('deal$round'),
                    onDone: () => setState(() => _dealt = true))
                : seats.length == 4
                    ? SeatGrid(seats: seats)
                    : Row(
                        children: [for (final s in seats) Expanded(child: s)]),
          ),
          if (phase == 'reveal')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                  round >= (st['totalRounds'] as num)
                      ? 'Final scores coming up…'
                      : 'Next round in ${(msLeft / 1000).ceil()}s',
                  style: const TextStyle(
                      color: GpColors.muted, fontWeight: FontWeight.w800)),
            ),
        ]),
      ),
    );
  }
}
