import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'lan_rooms.dart';

/// The game server, inside the app: lets one phone host rooms for the others on its
/// hotspot (or any Wi-Fi) with no internet and no laptop.
///
/// It speaks the same protocol as the Node server (Socket.IO v4 over WebSockets, the only
/// transport the app uses) and answers /health the same way, so the rest of the app, and
/// the Same Wi-Fi search, work with it unchanged. Mirrors server/src/sockets/index.js.
class LanServer {
  static const defaultPort = 3000;
  static final _codeRe = RegExp(r'^[A-Z0-9]{6}$');
  static final _tokenRe = RegExp(r'^dev:([A-Za-z0-9_-]{1,40})(?::(.{1,20}))?$');

  final LanRooms rooms;
  HttpServer? _http;
  final Map<String, _Conn> _byUser = {};
  final _rng = Random.secure();

  LanServer(this.rooms) {
    rooms
      ..onRoomChanged = (code) {
        final r = rooms.get(code);
        if (r != null) _toRoom(r, 'room_state', rooms.publicRoom(r));
      }
      ..onPlayerDisconnected =
          ((code, uid) => _toCode(code, 'player_disconnected', {'userId': uid}))
      ..onPlayerReconnected =
          ((code, uid) => _toCode(code, 'player_reconnected', {'userId': uid}))
      ..onGameUpdated = (code, result) {
        final r = rooms.get(code);
        if (r == null) return;
        _sendGameState(r);
        if (result != null) _toRoom(r, 'game_finished', result);
      }
      ..onGameAborted =
          ((code) => _toCode(code, 'error', {'code': 'GAME_ABORTED'}));
  }

  bool get running => _http != null;
  int? get port => _http?.port;

  Future<int> start({int port = defaultPort}) async {
    if (_http != null) return _http!.port;
    final http =
        await HttpServer.bind(InternetAddress.anyIPv4, port, shared: true);
    _http = http;
    http.listen(_handle, onError: (_) {});
    return http.port;
  }

  Future<void> stop() async {
    for (final c in _byUser.values.toList()) {
      c.close();
    }
    _byUser.clear();
    rooms.dispose();
    await _http?.close(force: true);
    _http = null;
  }

  Future<void> _handle(HttpRequest req) async {
    try {
      final path = req.uri.path;
      if (path == '/health') {
        req.response
          ..headers.contentType = ContentType.json
          ..write(
              jsonEncode({'ok': true, 'app': 'party-games', 'host': 'phone'}));
        await req.response.close();
        return;
      }
      if (path.startsWith('/socket.io') &&
          WebSocketTransformer.isUpgradeRequest(req)) {
        final ws = await WebSocketTransformer.upgrade(req);
        _Conn(this, ws, _sid()).open();
        return;
      }
      req.response.statusCode = HttpStatus.notFound;
      await req.response.close();
    } catch (_) {
      // A broken request must never take the server down.
    }
  }

  String _sid() =>
      base64Url.encode(List.generate(15, (_) => _rng.nextInt(256)));

  void _toCode(String code, String event, Object? data) {
    final r = rooms.get(code);
    if (r != null) _toRoom(r, event, data);
  }

  void _toRoom(LanRoom r, String event, Object? data) {
    for (final p in r.players) {
      _byUser[p.userId]?.emit(event, data);
    }
  }

  void _sendGameState(LanRoom room, [String? only]) {
    final g = room.game;
    if (room.status == 'lobby' || g == null) return;
    for (final p in room.players) {
      if (only != null && only != p.userId) continue;
      _byUser[p.userId]?.emit('game_state', {
        ...g.publicState(p.userId),
        'serverNow': DateTime.now().millisecondsSinceEpoch
      });
    }
  }

  /// A phone signed in: remember its connection (replacing an older one) and resume its room.
  void _connected(_Conn c) {
    final uid = c.userId!;
    final old = _byUser[uid];
    _byUser[uid] = c;
    if (old != null && old != c) {
      old.emit('error', {'code': 'SESSION_REPLACED'});
      old.close();
    }
    final resumed = rooms.reconnect(uid);
    if (resumed != null) _sendGameState(resumed, uid);
  }

  void _disconnected(_Conn c) {
    final uid = c.userId;
    if (uid == null || _byUser[uid] != c)
      return; // replaced by a newer connection
    _byUser.remove(uid);
    rooms.markDisconnected(uid);
  }

  /// One request from a phone; returns the ack's body.
  Map<String, Object?> _request(_Conn c, String event, Map p) {
    final uid = c.userId!, name = c.username!;
    Map<String, Object?> room(LanRoom r) => {'room': rooms.publicRoom(r)};
    Map<String, Object?> begin(LanRoom r) {
      _toRoom(r, 'round_started', {'gameType': r.gameType});
      _sendGameState(r);
      return room(r);
    }

    switch (event) {
      case 'create_room':
        return room(rooms.createRoom(uid, name,
            gameType: '${p['gameType']}', maxPlayers: p['maxPlayers']));
      case 'quick_play':
        final g = p['gameType'];
        return room(
            rooms.quickPlay(uid, name, gameType: g == null ? null : '$g'));
      case 'join_room':
        final code = p['code'] is String
            ? (p['code'] as String).trim().toUpperCase()
            : '';
        if (!_codeRe.hasMatch(code))
          throw const LanError('INVALID_PAYLOAD', 'bad room code');
        return room(rooms.joinRoom(uid, name, code));
      case 'leave_room':
        rooms.leave(uid);
        return {};
      case 'player_ready':
        rooms.setReady(uid, true);
        return {};
      case 'player_unready':
        rooms.setReady(uid, false);
        return {};
      case 'start_game':
        begin(rooms.startGame(uid));
        return {};
      case 'game_action':
        final type = p['type'], seq = p['seq'], payload = p['payload'];
        if (type is! String ||
            type.length > 40 ||
            seq is! int ||
            seq < 0 ||
            (payload != null && payload is! Map))
          throw const LanError('INVALID_PAYLOAD');
        return {
          'response':
              rooms.gameAction(uid, type, (payload as Map?) ?? const {}, seq)
        };
      case 'return_to_lobby':
        rooms.returnToLobby(uid);
        return {};
      case 'select_game':
        return room(rooms.selectGame(uid, '${p['gameType']}'));
      case 'start_party':
        return begin(rooms.startParty(uid, p['count'] ?? 5));
      case 'next_game':
        final g = p['gameType'];
        return begin(rooms.nextGame(uid, g == null ? null : '$g'));
      case 'resume_session':
        final r = rooms.roomOf(uid);
        return {'room': r == null ? null : rooms.publicRoom(r)};
    }
    throw const LanError('INVALID_ACTION');
  }
}

/// One phone's WebSocket, speaking Engine.IO v4 / Socket.IO v5 framing:
/// "0{...}" open, "2"/"3" ping/pong, "40{auth}" connect, "42[id][event, data]" event,
/// "43id[ack]" ack, "41" disconnect.
class _Conn {
  final LanServer server;
  final WebSocket ws;
  final String sid;
  String? userId, username;
  Timer? _ping;
  bool _closed = false;
  _Conn(this.server, this.ws, this.sid);

  void open() {
    _send('0${jsonEncode({
          'sid': sid,
          'upgrades': const [],
          'pingInterval': 25000,
          'pingTimeout': 20000,
          'maxPayload': 1000000
        })}');
    _ping = Timer.periodic(const Duration(seconds: 25), (_) => _send('2'));
    ws.listen((m) => m is String ? _onMessage(m) : null,
        onDone: _gone, onError: (_) => _gone(), cancelOnError: true);
  }

  void _send(String s) {
    if (_closed) return;
    try {
      ws.add(s);
    } catch (_) {
      _gone();
    }
  }

  void emit(String event, Object? data) =>
      _send('42${jsonEncode([event, data])}');

  void close() {
    _send('41');
    _gone();
  }

  void _gone() {
    if (_closed) return;
    _closed = true;
    _ping?.cancel();
    ws.close().ignore();
    server._disconnected(this);
  }

  void _onMessage(String m) {
    if (m.isEmpty) return;
    switch (m[0]) {
      case '2':
        _send('3${m.substring(1)}'); // ping -> pong
      case '1':
        _gone();
      case '4':
        _onSocketIo(m.substring(1));
    }
  }

  void _onSocketIo(String p) {
    if (p.isEmpty) return;
    final type = p[0];
    var rest = p.substring(1);
    // Default namespace only: skip a "/,"-style namespace prefix if one is ever sent.
    if (rest.startsWith('/')) {
      final comma = rest.indexOf(',');
      rest = comma < 0 ? '' : rest.substring(comma + 1);
    }
    switch (type) {
      case '0': // CONNECT with auth {token}
        final auth = rest.isEmpty ? null : jsonDecode(rest);
        final token = auth is Map ? auth['token'] : null;
        final m = token is String ? LanServer._tokenRe.firstMatch(token) : null;
        if (m == null) {
          _send('44${jsonEncode({'message': 'UNAUTHORIZED'})}');
          return;
        }
        userId = m.group(1);
        username = m.group(2) ??
            'Guest-${userId!.substring(0, min(4, userId!.length))}';
        _send('40${jsonEncode({'sid': sid})}');
        server._connected(this);
      case '1': // DISCONNECT
        _gone();
      case '2': // EVENT [ackId][event, payload]
        if (userId == null) return;
        var i = 0;
        while (i < rest.length &&
            rest.codeUnitAt(i) >= 48 &&
            rest.codeUnitAt(i) <= 57) {
          i++;
        }
        final ackId = i > 0 ? rest.substring(0, i) : null;
        Object? body;
        try {
          body = jsonDecode(rest.substring(i));
        } catch (_) {
          return;
        }
        if (body is! List || body.isEmpty || body.first is! String) return;
        final event = body.first as String;
        final payload =
            body.length > 1 && body[1] is Map ? body[1] as Map : const {};
        Map<String, Object?> reply;
        try {
          reply = {'ok': true, ...server._request(this, event, payload)};
        } on LanError catch (e) {
          reply = {
            'ok': false,
            'error': e.code,
            'message': e.message ?? e.code
          };
        } catch (_) {
          reply = {'ok': false, 'error': 'INTERNAL'};
        }
        if (ackId != null) _send('43$ackId${jsonEncode([reply])}');
    }
  }
}
