import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import '../../../core/audio/game_audio.dart';
import '../../../core/auth/authentication_manager.dart';
import '../../../core/network/socket_manager.dart';
import '../../../core/room/room_manager.dart';
import '../../../core/ui/components.dart';
import '../party/party_widgets.dart' show WaitingNote;
import '../../../core/session/game_session_manager.dart';
import '../../guess_person/models/gp_player.dart';
import '../../guess_person/widgets/gp_theme.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';

/// Plays a one-device game online. The room host's phone runs the real game (same code as
/// the one-device version) and publishes its state ~20 times a second; every other phone
/// draws that state and sends its taps and swipes to the host through the server.
class RelayPlay extends StatefulWidget {
  final LocalGameInfo game;
  const RelayPlay({super.key, required this.game});
  @override
  State<RelayPlay> createState() => _RelayPlayState();
}

class _RelayPlayState extends State<RelayPlay>
    with SingleTickerProviderStateMixin {
  static const _sendEvery = Duration(milliseconds: 50);

  late final GameSessionManager _session = context.read<GameSessionManager>();
  late final String _myId =
      context.read<AuthenticationManager>().token.split(':')[1];
  RelayGame get _spec => widget.game.online!;

  LocalGameLogic? _g;
  late List<String> _ids;
  late List<GpPlayer> _players;
  int _me = 0;
  bool _host = false;

  // Host.
  Ticker? _ticker;
  int _acked = 0;
  bool _dirty = true;
  DateTime _lastSent = DateTime(2000);
  Timer? _sendTimer;
  bool _finishing = false;

  // Guest.
  int _version = 0;
  final Map<String, List<Object?>> _pending = {};
  Timer? _flush;

  @override
  void initState() {
    super.initState();
    _session.addListener(_onSession);
    _onSession();
    _ready = true;
    GameAudio.music(GameAudio.musicFor(widget.game.id));
  }

  bool _ready = false; // initState finished, setState allowed

  void _setUp(Map<String, dynamic> st) {
    final players = (st['players'] as List).cast<Map>();
    _ids = [for (final p in players) p['userId'] as String];
    _players = [
      for (var i = 0; i < players.length; i++)
        GpPlayer(
            name: '${players[i]['username']}',
            color: gpPlayerColors[i % gpPlayerColors.length])
    ];
    _me = _ids.indexOf(_myId).clamp(0, _ids.length - 1);
    _host = st['host'] == _myId;
    final g = _spec.create(_ids.length);
    _g = g;
    if (_host) {
      // The host's own actions go through the same checks as everyone else's.
      g.sendToHost = (name, args) => _applyAs(_me, name, args);
      g.addListener(_markDirty);
      _ticker = createTicker((elapsed) {
        g.update(elapsed.inMilliseconds);
        _afterChange();
      })
        ..start();
      _afterChange();
    } else {
      g.sendToHost = _sendInput;
      g.isGuest = true;
    }
  }

  void _onSession() {
    final st = _session.state;
    if (st == null || st['relay'] != true) return;
    if (_g == null) {
      _setUp(st);
      if (_ready) setState(() {});
    }
    final g = _g!;
    if (_host) {
      for (final i in (st['inputs'] as List).cast<Map>()) {
        final seq = (i['seq'] as num).toInt();
        if (seq <= _acked) continue;
        _acked = seq;
        final from = _ids.indexOf(i['from'] as String);
        if (from >= 0)
          _applyAs(
              from, i['name'] as String, List<Object?>.from(i['args'] as List));
      }
    } else {
      final v = (st['version'] as num?)?.toInt() ?? 0;
      final s = st['state'];
      if (v > _version && s is Map) {
        final first = _version == 0;
        _version = v;
        _spec.load(g, Map<String, dynamic>.from(s), _me);
        g.changed();
        if (first && _ready && mounted)
          setState(() {}); // leave the waiting screen
      }
    }
  }

  void _applyAs(int from, String name, List<Object?> args) {
    final g = _g!;
    final hook = g.sendToHost;
    g.sendToHost = null; // apply for real
    try {
      _spec.apply(g, from, name, args);
    } catch (_) {
      // Malformed input from a guest: ignore it.
    } finally {
      g.sendToHost = hook;
    }
    _afterChange();
  }

  void _markDirty() => _dirty = true;

  void _afterChange() {
    final g = _g!;
    final hook = g.sendToHost;
    g.sendToHost = null; // housekeeping applies directly
    _spec.hostAuto(g);
    g.sendToHost = hook;
    _scheduleSend();
    if (g.finished && !_finishing) {
      _finishing = true;
      _ticker?.stop();
      _sendNow();
      // A moment to see the final state before the results screen.
      Future.delayed(const Duration(milliseconds: 1200), () {
        _session.action('relay:finish', {'scores': List.of(g.scores)}).ignore();
      });
    }
  }

  int _sentAck = -1;
  void _scheduleSend() {
    if (!_dirty && _sentAck == _acked) return;
    final wait = _sendEvery - DateTime.now().difference(_lastSent);
    if (wait <= Duration.zero) {
      _sendNow();
    } else {
      _sendTimer ??= Timer(wait, () {
        _sendTimer = null;
        _sendNow();
      });
    }
  }

  void _sendNow() {
    final g = _g;
    if (g == null || !mounted) return;
    _dirty = false;
    _sentAck = _acked;
    _lastSent = DateTime.now();
    final payload = <String, dynamic>{
      'state': _spec.wireState(g),
      'ack': _acked
    };
    final views = _spec.seatViews(g);
    if (views != null) payload['views'] = views;
    _session.action('relay:state', payload).ignore();
  }

  void _sendInput(String name, List<Object?> args) {
    if (_spec.continuous.contains(name)) {
      _pending[name] = args;
      _flush ??= Timer(_sendEvery, () {
        _flush = null;
        final batch = Map.of(_pending);
        _pending.clear();
        batch.forEach((n, a) =>
            _session.action('relay:input', {'name': n, 'args': a}).ignore());
      });
    } else {
      _session.action('relay:input', {'name': name, 'args': args}).ignore();
    }
  }

  @override
  void dispose() {
    _session.removeListener(_onSession);
    _ticker?.dispose();
    _sendTimer?.cancel();
    _flush?.cancel();
    _g?.dispose();
    GameAudio.stopMusic();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = _g;
    if (g == null || (!_host && _version == 0)) {
      return GpBackground(
        child: Column(children: [
          _OnlineBanners(myId: _myId),
          const Expanded(child: WaitingNote('Waiting for the host to start…')),
        ]),
      );
    }
    final me = _players[_me];
    return GpBackground(
      child: Column(children: [
        // Who you are in this game (your colour and shape), and settings.
        Container(
          width: double.infinity,
          color: fillFor(me.color),
          padding: const EdgeInsets.only(left: Space.s),
          child: Row(children: [
            Expanded(
              child: Semantics(
                label: 'You are ${me.name}${_host ? ', the host' : ''}',
                excludeSemantics: true,
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (PlayerPalette.indexOf(me.color) case final s?) ...[
                    SizedBox(
                        width: 12,
                        height: 12,
                        child: CustomPaint(
                            painter: PlayerShapePainter(
                                PlayerPalette.shape(s), Colors.white))),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                        'YOU: ${me.name.toUpperCase()}${_host ? ' · HOST' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 12.5,
                            letterSpacing: 1)),
                  ),
                ]),
              ),
            ),
            IconButton(
              tooltip: 'Sound and settings',
              constraints:
                  const BoxConstraints(minWidth: kTouchTarget, minHeight: 40),
              onPressed: () => showAppSheet<void>(context,
                  title: 'Settings',
                  builder: (_) => SettingsPanel(color: widget.game.color)),
              icon:
                  const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
            ),
          ]),
        ),
        _OnlineBanners(myId: _myId),
        Expanded(
            child: ListenableBuilder(
                listenable: g,
                builder: (context, _) =>
                    _spec.view(context, g, _players, _me))),
      ]),
    );
  }
}

/// Non-blocking connection states over an online game: our own connection, and players
/// (or the host) who dropped out. Shown as a strip; the game underneath stays usable.
class _OnlineBanners extends StatelessWidget {
  final String myId;
  const _OnlineBanners({required this.myId});

  @override
  Widget build(BuildContext context) {
    final socket = context.read<SocketManager?>();
    final room = context.watch<RoomManager?>()?.room;
    final away =
        room?.players.where((p) => !p.connected && p.userId != myId).toList() ??
            const <RoomPlayer>[];
    final hostAway = room != null && away.any((p) => p.userId == room.hostId);
    Widget banners(bool online) {
      final list = <Widget>[
        if (!online)
          const AppBanner(
              text: 'Connection lost · reconnecting…', tone: Tone.warn),
        if (online && hostAway)
          AppBanner(
              text:
                  'The host lost connection. The game continues when they are back…',
              tone: Tone.info),
        if (online && !hostAway && away.isNotEmpty)
          AppBanner(
              text:
                  '${away.map((p) => p.username).join(', ')} lost connection. Waiting for them…',
              tone: Tone.info),
      ];
      return AnimatedSize(
        duration: Motion.of(context, Motion.normal),
        child: list.isEmpty
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding:
                    const EdgeInsets.fromLTRB(Space.s, Space.s, Space.s, 0),
                child: Column(children: list)),
      );
    }

    if (socket == null) return banners(true);
    return ValueListenableBuilder<bool>(
        valueListenable: socket.connected, builder: (_, on, __) => banners(on));
  }
}
