import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/authentication_manager.dart';
import '../../../core/network/socket_manager.dart';
import '../../../core/room/room_manager.dart';
import '../../../core/session/game_session_manager.dart';
import '../../../core/ui/components.dart';
import 'nitro_game_view.dart';
import 'nitro_transport.dart';

/// Fixed-roster, host-trusted arena combat. A transient socket disconnect does
/// not replace the WebView; a lost host engine cannot be restored from a frame.
class NitroOnlineScreen extends StatefulWidget {
  const NitroOnlineScreen({super.key});
  @override
  State<NitroOnlineScreen> createState() => _NitroOnlineScreenState();
}

class _NitroOnlineScreenState extends State<NitroOnlineScreen> {
  final _vc = NitroViewController();
  late final GameSessionManager _session;
  late NitroTransport _transport;
  final Map<int, Map> _inputs = {};
  List<String> _ids = [], _names = [];
  String _myId = '', _hostId = '';
  String? _fatal, _delivery;
  String? _snapshot;
  bool _host = false, _haveRoster = false, _draining = false;
  int _acked = 0, _match = 0;

  @override
  void initState() {
    super.initState();
    _session = context.read<GameSessionManager>();
    _myId = nitroIdentityFromManagers(
      room: context.read<RoomManager?>(),
      socket: context.read<SocketManager?>(),
      devToken: context.read<AuthenticationManager>().token,
    );
    _makeTransport();
    _session.addListener(_onSession);
    _onSession();
  }

  void _makeTransport() {
    _transport = NitroTransport(
      send: (type, payload) async {
        final response = await _session.action(type, payload);
        if (mounted && response['ok'] == true && _delivery != null)
          setState(() => _delivery = null);
        return response;
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          if (const {'OFFLINE', 'TIMEOUT', 'RATE_LIMITED'}.contains(error)) {
            _delivery = 'Waiting for the server · retrying…';
          } else {
            _fatal =
                'Nitro could not synchronize ($error). Return to the lobby; this match cannot restart safely.';
          }
        });
      },
    );
  }

  void _onSession() {
    final st = _session.state;
    if (st == null) {
      // round_started clears state; ordinary reconnect never does.
      if (_haveRoster) {
        _transport.dispose();
        _makeTransport();
        _inputs.clear();
        _ids = [];
        _names = [];
        _haveRoster = false;
        _hostId = '';
        _snapshot = null;
        _acked = 0;
        _fatal = _delivery = null;
        _match++;
        if (mounted) setState(() {});
      }
      return;
    }
    if (st['nitro'] != true) return;
    final players = (st['players'] as List).cast<Map>();
    final ids = [for (final p in players) '${p['userId']}'];
    final hostId = '${st['host']}';
    if (!_haveRoster) {
      _ids = ids;
      _names = [for (final p in players) nitroLabel('${p['username']}')];
      _hostId = hostId;
      _host = hostId == _myId;
      _haveRoster = true;
      if (!_ids.contains(_myId)) {
        _fatal =
            'Your authenticated seat is unavailable. Return to the lobby and rejoin.';
      } else if (_host && st['state'] != null) {
        _fatal =
            'The host engine was lost. Snapshots cannot restore its physics. Return to the lobby to start a new match.';
      }
    } else if (hostId != _hostId || ids.join('\u0000') != _ids.join('\u0000')) {
      _fatal =
          'The match roster changed. Live host migration is not supported. Return to the lobby.';
    }
    if (_fatal == null) {
      if (_host) {
        for (final input in (st['inputs'] as List? ?? const []).cast<Map>()) {
          final seq = (input['seq'] as num).toInt();
          if (seq > _acked) _inputs[seq] = input;
        }
      } else if (st['state'] != null) {
        _snapshot = jsonEncode(st['state']);
      }
      unawaited(_drainEngine());
    }
    if (mounted) setState(() {});
  }

  Future<void> _drainEngine() async {
    if (_draining || !_vc.ready || _fatal != null) return;
    _draining = true;
    final match = _match;
    try {
      while (mounted && match == _match && _fatal == null && _vc.ready) {
        if (_host) {
          if (_inputs.isEmpty) break;
          final seq = _inputs.keys.reduce((a, b) => a < b ? a : b);
          final input = _inputs[seq]!;
          final seat = _ids.indexOf('${input['from']}');
          if (seat < 0 || seat == _ids.indexOf(_myId)) break;
          final applied = await _vc.sendHostInput(
            seat,
            List<Object?>.from(input['args'] as List),
          );
          if (!mounted || match != _match || !applied) break;
          // Advance only after the ready engine actually accepted the injection.
          _acked = seq;
          _inputs.remove(seq);
        } else {
          final snapshot = _snapshot;
          if (snapshot == null) break;
          if (!await _vc.sendSnapshot(snapshot)) break;
          if (!mounted || match != _match) break;
          if (_snapshot == snapshot) _snapshot = null;
        }
      }
    } finally {
      _draining = false;
    }
  }

  void _onMessage(Map<String, dynamic> message) {
    if (_fatal != null) return;
    switch (message['kind']) {
      case 'snapshot':
        if (!_host || message['data'] is! String) return;
        try {
          final frame = jsonDecode(message['data'] as String);
          if (frame is Map<String, dynamic>) _transport.snapshot(frame, _acked);
        } on FormatException catch (_) {
          /* Not an engine snapshot. */
        }
        unawaited(_drainEngine());
      case 'input':
        if (_host || message['args'] is! List) return;
        final args = List<Object?>.from(message['args'] as List);
        if (args.length == 4) _transport.input(args);
      case 'finish':
        if (!_host || message['scores'] is! List) return;
        _transport.finish((message['scores'] as List).cast<int>());
      default:
        break;
    }
  }

  @override
  void dispose() {
    _session.removeListener(_onSession);
    _transport.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final socket = context.watch<SocketManager?>();
    final room = context.watch<RoomManager?>()?.room;
    if (_fatal != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_fatal!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  // Permanent leave explicitly aborts a live fixed-roster match.
                  await context.read<RoomManager>().leave();
                },
                child: const Text('Leave match'),
              ),
            ],
          ),
        ),
      );
    }
    if (!_haveRoster) return const Center(child: CircularProgressIndicator());
    final boot = NitroBoot(
      mode: _host ? 'host' : 'guest',
      seat: _ids.indexOf(_myId),
      seats: _ids.length,
      names: _names,
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        NitroGameView(
          key: ValueKey('nitro-$_match'),
          boot: boot,
          controller: _vc,
          onMessage: _onMessage,
          onReady: () {
            unawaited(_drainEngine());
          },
          onError: (error) {
            if (mounted) setState(() => _fatal = error);
          },
        ),
        IgnorePointer(
          child: Align(
            alignment: Alignment.topCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_delivery != null)
                  AppBanner(text: _delivery!, tone: Tone.warn),
                if (socket != null)
                  ValueListenableBuilder<bool>(
                    valueListenable: socket.connected,
                    builder: (_, connected, __) => connected
                        ? const SizedBox.shrink()
                        : const AppBanner(
                            text: 'Connection lost · reconnecting…',
                            tone: Tone.warn,
                          ),
                  ),
                if (room != null &&
                    room.players.any((p) => !p.connected && p.userId != _myId))
                  const AppBanner(
                    text:
                        'A player disconnected · waiting for reconnection. Permanent departure ends this match.',
                    tone: Tone.info,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
