import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class SocketEvent {
  final String name;
  final dynamic data;
  SocketEvent(this.name, this.data);
}

/// Thin wrapper over Socket.IO: connection state, acked requests, server events.
class SocketManager {
  io.Socket? _socket;
  final _events = StreamController<SocketEvent>.broadcast();
  final ValueNotifier<bool> connected = ValueNotifier(false);

  Stream<SocketEvent> get events => _events.stream;

  static const _serverEvents = [
    'room_state',
    'game_state',
    'game_event',
    'round_started',
    'round_finished',
    'game_finished',
    'player_disconnected',
    'player_reconnected',
    'error',
  ];

  Future<void> connect(String url, String token) async {
    disconnect();
    final done = Completer<void>();
    final s = io.io(
      url,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableForceNew() // a fresh connection each time, never a cached one for the same address
          .enableReconnection()
          .setReconnectionDelay(500)
          .setReconnectionDelayMax(5000)
          .disableAutoConnect()
          .build(),
    );
    _socket = s;
    s.onConnect((_) {
      connected.value = true;
      if (!done.isCompleted) done.complete();
    });
    s.onDisconnect((_) => connected.value = false);
    s.onConnectError((e) {
      if (!done.isCompleted)
        done.completeError(Exception('Cannot reach server'));
    });
    for (final name in _serverEvents) {
      s.on(name, (d) => _events.add(SocketEvent(name, d)));
    }
    s.connect();
    // A free cloud server can take up to a minute to wake up. Report the slow start, but keep
    // the socket: it goes on retrying and flips [connected] as soon as the server answers.
    await done.future.timeout(const Duration(seconds: 10),
        onTimeout: () => throw Exception('Connection timed out'));
  }

  /// Sends an event and waits for the server ack: {ok: true, ...} or {ok: false, error: CODE}.
  Future<Map<String, dynamic>> request(String event,
      [Map<String, dynamic>? payload]) {
    final s = _socket;
    if (s == null || !s.connected)
      return Future.value({'ok': false, 'error': 'OFFLINE'});
    final c = Completer<Map<String, dynamic>>();
    s.emitWithAck(event, payload ?? {}, ack: (d) {
      if (!c.isCompleted) c.complete(Map<String, dynamic>.from(d as Map));
    });
    return c.future.timeout(const Duration(seconds: 8),
        onTimeout: () => {'ok': false, 'error': 'TIMEOUT'});
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
    connected.value = false;
  }

  void dispose() {
    disconnect();
    _events.close();
  }
}
