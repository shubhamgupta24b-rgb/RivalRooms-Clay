import 'dart:async';

/// One in-flight action, with bounded latest-value buffering. In particular a
/// finish can never overtake the accepted terminal snapshot it depends on.
class NitroTransport {
  final Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)
  send;
  final void Function(String) onError;
  final Duration retryDelay;
  Map<String, dynamic>? _frame, _input, _terminal;
  List<int>? _scores;
  bool _busy = false, _disposed = false, _terminalAccepted = false;
  Timer? _retry;

  NitroTransport({
    required this.send,
    required this.onError,
    this.retryDelay = const Duration(milliseconds: 350),
  });

  void snapshot(Map<String, dynamic> state, int ack) {
    if (_disposed || _terminalAccepted || _terminal != null) return;
    final payload = <String, dynamic>{'state': state, 'ack': ack};
    if (state['over'] == 1 && state['time'] == 0) {
      _terminal = payload;
      _frame = null;
    } else {
      _frame = payload;
    }
    _pump();
  }

  void input(List<Object?> args) {
    if (_disposed || _terminalAccepted) return;
    _input = {'args': args};
    _pump();
  }

  void finish(List<int> scores) {
    if (_disposed) return;
    _scores = List.of(scores);
    _pump();
  }

  void retryNow() {
    _retry?.cancel();
    _retry = null;
    _pump();
  }

  Future<void> _pump() async {
    if (_disposed || _busy || _retry != null) return;
    final terminal = !_terminalAccepted && _terminal != null;
    final finishing = _terminalAccepted && _scores != null;
    final payload = terminal
        ? _terminal
        : finishing
        ? <String, dynamic>{'scores': _scores}
        : _frame ?? _input;
    if (payload == null) return;
    final type = terminal || identical(payload, _frame)
        ? 'nitro:state'
        : finishing
        ? 'nitro:finish'
        : 'nitro:input';
    _busy = true;
    Map<String, dynamic> response;
    try {
      response = await send(type, payload);
    } catch (_) {
      response = {'ok': false, 'error': 'TIMEOUT'};
    }
    _busy = false;
    if (_disposed) return;
    if (response['ok'] != true) {
      final error = '${response['error']}';
      onError(error);
      if (const {'OFFLINE', 'TIMEOUT', 'RATE_LIMITED'}.contains(error)) {
        _retry = Timer(retryDelay, () {
          _retry = null;
          _pump();
        });
      } else {
        // Rejected physics/protocol data must not silently become a new match.
        dispose();
      }
      return;
    }
    if (terminal) {
      _terminalAccepted = true;
      _terminal = null;
      _frame = null;
      _input = null;
    } else if (finishing) {
      _scores = null;
    } else if (identical(payload, _frame)) {
      _frame = null;
    } else if (identical(payload, _input)) {
      _input = null;
    }
    unawaited(_pump());
  }

  void dispose() {
    _disposed = true;
    _retry?.cancel();
    _frame = _input = _terminal = null;
    _scores = null;
  }
}

String nitroIdentity({
  String? roomMyId,
  String? socketUserId,
  String? devToken,
}) {
  if (roomMyId != null && roomMyId.isNotEmpty) return roomMyId;
  if (socketUserId != null && socketUserId.isNotEmpty) return socketUserId;
  // Compatibility only for this repository's current dev-auth implementation.
  // Never parse Firebase/JWT bearer tokens as colon-separated user identities.
  final parts = devToken?.split(':');
  return parts != null &&
          parts.length >= 3 &&
          parts.first == 'dev' &&
          parts[1] != 'null'
      ? parts[1]
      : '';
}

/// Shared identity getters are optional in the current branch. Keep their
/// compatibility probe here, not in auth/socket code owned by the parent.
String nitroIdentityFromManagers({
  Object? room,
  Object? socket,
  String? devToken,
}) {
  String? roomId, socketId;
  try {
    final Object? value = (room as dynamic)?.myId;
    if (value is String) roomId = value;
  } on NoSuchMethodError catch (_) {
    /* Older shared manager. */
  }
  try {
    final Object? value = (socket as dynamic)?.userId;
    if (value is String) socketId = value;
  } on NoSuchMethodError catch (_) {
    /* Older shared transport. */
  }
  return nitroIdentity(
    roomMyId: roomId,
    socketUserId: socketId,
    devToken: devToken,
  );
}

String nitroLabel(String value) {
  // Names reach innerHTML in the original HUD; render plain, bounded labels.
  var label = value.replaceAll(RegExp(r'[<>&"\x00-\x1f]'), '').trim();
  if (label.length > 24) {
    label = label.substring(0, 24);
    final last = label.codeUnitAt(label.length - 1);
    if (last >= 0xD800 && last <= 0xDBFF)
      label = label.substring(0, label.length - 1);
  }
  return label.isEmpty ? 'Player' : label;
}
