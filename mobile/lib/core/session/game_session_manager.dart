import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../network/socket_manager.dart';

/// Holds the latest server-sent game state/result and sends game actions.
/// The client never computes scores or timers; it only renders what the server sends.
class GameSessionManager extends ChangeNotifier {
  final SocketManager _socket;
  late final StreamSubscription<SocketEvent> _sub;
  Map<String, dynamic>? state;
  Map<String, dynamic>? result;
  int _offsetMs =
      0; // serverTime - localTime, to render server countdowns accurately
  int _seq = 0;

  GameSessionManager(this._socket) {
    _sub = _socket.events.listen(_onEvent);
  }

  int get serverNowMs => DateTime.now().millisecondsSinceEpoch + _offsetMs;

  void _onEvent(SocketEvent e) {
    switch (e.name) {
      case 'round_started':
        state = null;
        result = null;
        notifyListeners();
      case 'game_state':
        state = Map<String, dynamic>.from(e.data as Map);
        final sn = state!['serverNow'];
        if (sn is num)
          _offsetMs = sn.toInt() - DateTime.now().millisecondsSinceEpoch;
        notifyListeners();
      case 'game_finished':
        result = Map<String, dynamic>.from(e.data as Map);
        notifyListeners();
    }
  }

  /// Returns the server ack: {ok, response?} or {ok:false, error}.
  Future<Map<String, dynamic>> action(
      String type, Map<String, dynamic> payload) {
    // Time-based, strictly increasing: stays valid even if the app restarts mid-game.
    _seq = max(_seq + 1, DateTime.now().millisecondsSinceEpoch);
    return _socket.request(
        'game_action', {'type': type, 'payload': payload, 'seq': _seq});
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
