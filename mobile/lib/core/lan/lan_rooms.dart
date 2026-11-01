import 'dart:async';
import 'dart:convert';
import 'dart:math';

/// A Dart copy of the internet server's room rules (server/src/rooms/RoomManager.js and
/// server/src/games/relay/index.js), so a phone can host rooms itself on a hotspot with no
/// internet. Only "relay" games are offered: the host phone already runs those games, the
/// server just passes state and moves between phones. Keep the two in step.
class LanError implements Exception {
  final String code;
  final String? message;
  const LanError(this.code, [this.message]);
  @override
  String toString() => 'LanError($code${message == null ? '' : ': $message'})';
}

/// A game rooms can play: its id and how many players it takes.
class LanGame {
  final String id;
  final int minPlayers, maxPlayers;
  const LanGame(this.id, this.minPlayers, this.maxPlayers);
}

class LanPlayer {
  final String userId, username;
  bool ready, connected;
  LanPlayer(this.userId, this.username,
      {this.ready = false, this.connected = true});
}

/// One relay game in progress: the host phone's latest state and everyone's moves for it.
class LanRelay {
  static const maxStateBytes = 64 * 1024, maxQueue = 200;
  static final nameRe = RegExp(r'^[a-zA-Z][a-zA-Z0-9_]{0,23}$');
  final String gameType;
  final List<String> players;
  final Map<String, String> names;
  final String host;
  Object? state;
  int version = 0, inputSeq = 0;
  final List<Map<String, Object?>> inputs = [];
  bool finished = false;
  Map<String, int>? scores;
  LanRelay(this.gameType, this.players, this.names, this.host);

  Map<String, Object?>? action(String uid, String type, Map p) {
    if (!players.contains(uid)) throw const LanError('NOT_IN_GAME');
    if (finished) throw const LanError('BAD_PHASE');
    switch (type) {
      case 'relay:state':
        if (uid != host) throw const LanError('NOT_HOST');
        final s = p['state'];
        if (s is! Map) throw const LanError('INVALID_PAYLOAD');
        if (jsonEncode(s).length > maxStateBytes)
          throw const LanError('INVALID_PAYLOAD', 'state too large');
        state = s;
        version++;
        final ack = p['ack'];
        if (ack is int) inputs.removeWhere((i) => (i['seq'] as int) <= ack);
        return {'version': version};
      case 'relay:input':
        final name = p['name'], args = p['args'];
        if (name is! String ||
            !nameRe.hasMatch(name) ||
            args is! List ||
            args.length > 8) throw const LanError('INVALID_PAYLOAD');
        if (!args
            .every((a) => a == null || a is num || a is String || a is bool))
          throw const LanError('INVALID_PAYLOAD');
        inputs
            .add({'seq': ++inputSeq, 'from': uid, 'name': name, 'args': args});
        if (inputs.length > maxQueue)
          inputs.removeRange(0, inputs.length - maxQueue);
        return {'seq': inputSeq};
      case 'relay:finish':
        if (uid != host) throw const LanError('NOT_HOST');
        final sc = p['scores'];
        if (sc is! List ||
            sc.length != players.length ||
            !sc.every((x) => x is int)) throw const LanError('INVALID_PAYLOAD');
        scores = {
          for (var i = 0; i < players.length; i++) players[i]: sc[i] as int
        };
        finished = true;
        return {};
    }
    throw const LanError('INVALID_ACTION');
  }

  Map<String, Object?> publicState(String uid) => {
        'gameType': gameType,
        'relay': true,
        'host': host,
        'players': [
          for (final u in players) {'userId': u, 'username': names[u]}
        ],
        'state': state,
        'version': version,
        'inputs':
            uid == host ? inputs : const [], // only the host needs the moves
        'finished': finished,
      };

  Map<String, Object?> result() {
    final ranking = [
      for (final u in players)
        <String, Object?>{
          'userId': u,
          'username': names[u],
          'score': scores![u]
        }
    ]..sort((a, b) => (b['score'] as int) - (a['score'] as int));
    var rank = 0;
    for (var i = 0; i < ranking.length; i++) {
      if (i == 0 ||
          (ranking[i]['score'] as int) < (ranking[i - 1]['score'] as int))
        rank = i + 1;
      ranking[i]['rank'] = rank;
    }
    return {
      'gameType': gameType,
      'scores': scores,
      'ranking': ranking,
      'winners': [
        for (final r in ranking)
          if (r['rank'] == 1) r['userId']
      ],
    };
  }
}

class LanRoom {
  final String code;
  String gameType;
  final int maxPlayers;
  String hostId;
  String status = 'lobby';
  final List<LanPlayer> players = [];
  LanRelay? game;
  Map<String, int> seqs = {};
  Map<String, Object?>? party;
  bool isPublic = false;
  LanRoom(this.code, this.gameType, this.maxPlayers, this.hostId);
}

class LanRooms {
  static const _chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final Map<String, LanGame> games;
  final Duration grace;
  final Random _rng;
  final Map<String, LanRoom> rooms = {};
  final Map<String, String> _userRoom = {};
  final Map<String, Timer> _timers = {};

  // What the server tells the phones about.
  void Function(String code)? onRoomChanged;
  void Function(String code)? onRoomClosed;
  void Function(String code, String userId)? onPlayerDisconnected;
  void Function(String code, String userId)? onPlayerReconnected;
  void Function(String code, Map<String, Object?>? result)? onGameUpdated;
  void Function(String code)? onGameAborted;

  LanRooms(List<LanGame> games,
      {this.grace = const Duration(seconds: 60), Random? random})
      : games = {for (final g in games) g.id: g},
        _rng = random ?? Random.secure();

  String _code() {
    for (var i = 0; i < 50; i++) {
      final c =
          List.generate(6, (_) => _chars[_rng.nextInt(_chars.length)]).join();
      if (!rooms.containsKey(c)) return c;
    }
    throw const LanError('INTERNAL');
  }

  LanRoom? get(String code) => rooms[code];
  LanRoom? roomOf(String userId) => rooms[_userRoom[userId]];
  LanRoom _mustRoom(String userId) =>
      roomOf(userId) ?? (throw const LanError('NOT_IN_ROOM'));
  void _changed(LanRoom r) => onRoomChanged?.call(r.code);

  LanGame _game(String id) {
    final g = games[id];
    // Guess Who and Raja Mantri keep their rules on the internet server.
    if (g == null)
      throw const LanError('NEEDS_INTERNET', 'This game needs Online mode');
    return g;
  }

  LanRoom createRoom(String userId, String username,
      {required String gameType, required Object? maxPlayers}) {
    if (_userRoom.containsKey(userId)) throw const LanError('ALREADY_IN_ROOM');
    _game(gameType);
    if (maxPlayers is! int || maxPlayers < 2 || maxPlayers > 6)
      throw const LanError('INVALID_PAYLOAD', 'maxPlayers must be 2 to 6');
    final room = LanRoom(_code(), gameType, maxPlayers, userId);
    room.players.add(LanPlayer(userId, username, ready: true));
    rooms[room.code] = room;
    _userRoom[userId] = room.code;
    return room;
  }

  LanRoom quickPlay(String userId, String username, {String? gameType}) {
    if (_userRoom.containsKey(userId)) throw const LanError('ALREADY_IN_ROOM');
    if (gameType != null) _game(gameType);
    final open = rooms.values
        .where((r) =>
            r.isPublic &&
            r.status == 'lobby' &&
            r.players.length < r.maxPlayers &&
            r.players.any((p) => p.connected) &&
            (gameType == null || r.gameType == gameType))
        .toList();
    if (open.isNotEmpty) {
      final most = open.map((r) => r.players.length).reduce(max);
      final best = open.where((r) => r.players.length == most).toList();
      return joinRoom(userId, username, best[_rng.nextInt(best.length)].code);
    }
    final pool =
        games.values.where((g) => g.minPlayers <= 2).map((g) => g.id).toList();
    final room = createRoom(userId, username,
        gameType: gameType ?? pool[_rng.nextInt(pool.length)], maxPlayers: 6);
    room.isPublic = true;
    return room;
  }

  LanRoom joinRoom(String userId, String username, String code) {
    if (_userRoom.containsKey(userId)) throw const LanError('ALREADY_IN_ROOM');
    final room = rooms[code] ?? (throw const LanError('ROOM_NOT_FOUND'));
    if (room.status != 'lobby') throw const LanError('GAME_IN_PROGRESS');
    if (room.players.length >= room.maxPlayers)
      throw const LanError('ROOM_FULL');
    room.players.add(LanPlayer(userId, username));
    _userRoom[userId] = code;
    _changed(room);
    return room;
  }

  void leave(String userId) {
    _mustRoom(userId);
    _removePlayer(userId);
  }

  void _removePlayer(String userId) {
    final room = roomOf(userId);
    _timers.remove(userId)?.cancel();
    _userRoom.remove(userId);
    if (room == null) return;
    room.players.removeWhere((p) => p.userId == userId);
    room.seqs.remove(userId);
    if (room.players.isEmpty) {
      rooms.remove(room.code);
      onRoomClosed?.call(room.code);
      return;
    }
    if (room.hostId == userId) {
      final next = room.players
          .firstWhere((p) => p.connected, orElse: () => room.players.first);
      room.hostId = next.userId;
      next.ready = true;
    }
    if (room.status != 'lobby' && room.players.length < 2) {
      _toLobby(room);
      onGameAborted?.call(room.code);
    }
    _changed(room);
  }

  void _toLobby(LanRoom room) {
    room.status = 'lobby';
    room.game = null;
    room.seqs = {};
    for (final p in room.players) {
      p.ready = p.userId == room.hostId || (p.ready && p.connected);
    }
  }

  List<String> _fits(LanRoom room) {
    final n = room.players.length;
    return [
      for (final g in games.values)
        if (n >= g.minPlayers && n <= g.maxPlayers) g.id
    ];
  }

  LanRoom selectGame(String userId, String gameType) {
    final room = _mustRoom(userId);
    if (room.hostId != userId) throw const LanError('NOT_HOST');
    if (room.status != 'lobby') throw const LanError('BAD_PHASE');
    _game(gameType);
    room.gameType = gameType;
    room.party = null;
    _changed(room);
    return room;
  }

  LanRoom setReady(String userId, bool ready) {
    final room = _mustRoom(userId);
    if (room.status != 'lobby') throw const LanError('BAD_PHASE');
    if (userId == room.hostId) return room;
    room.players.firstWhere((p) => p.userId == userId).ready = ready;
    _changed(room);
    return room;
  }

  LanRoom startGame(String userId) {
    final room = _mustRoom(userId);
    if (room.hostId != userId) throw const LanError('NOT_HOST');
    if (room.status != 'lobby') throw const LanError('BAD_PHASE');
    final g = _game(room.gameType);
    if (room.players.length < max(2, g.minPlayers))
      throw const LanError('NOT_ENOUGH_PLAYERS');
    if (room.players.length > g.maxPlayers)
      throw const LanError('TOO_MANY_PLAYERS');
    if (!room.players.every((p) => p.ready && p.connected))
      throw const LanError('PLAYERS_NOT_READY');
    final ids = [for (final p in room.players) p.userId];
    room.status = 'playing';
    room.game = LanRelay(
        room.gameType,
        ids,
        {for (final p in room.players) p.userId: p.username},
        ids.contains(room.hostId) ? room.hostId : ids.first);
    room.seqs = {};
    _changed(room);
    return room;
  }

  LanRoom startParty(String userId, Object? count) {
    final room = _mustRoom(userId);
    if (room.hostId != userId) throw const LanError('NOT_HOST');
    if (room.status != 'lobby') throw const LanError('BAD_PHASE');
    if (count is! int || count < 2 || count > 10)
      throw const LanError('INVALID_PAYLOAD');
    if (room.players.length < 2) throw const LanError('NOT_ENOUGH_PLAYERS');
    final pool = _fits(room)..shuffle(_rng);
    final list = pool.take(count).toList();
    final prev = room.gameType;
    room.gameType = list.first;
    try {
      startGame(userId);
    } catch (_) {
      room.gameType = prev;
      rethrow;
    }
    room.party = {
      'games': list,
      'index': 0,
      'totals': {for (final p in room.players) p.userId: 0},
      'lastPoints': null,
      'done': false
    };
    _changed(room);
    return room;
  }

  LanRoom nextGame(String userId, String? gameType) {
    final room = _mustRoom(userId);
    if (room.hostId != userId) throw const LanError('NOT_HOST');
    if (room.status != 'finished') throw const LanError('BAD_PHASE');
    final party = room.party;
    var next = gameType ?? room.gameType;
    if (party != null) {
      if (party['done'] == true) throw const LanError('BAD_PHASE');
      next = (party['games'] as List)[(party['index'] as int) + 1] as String;
    }
    _game(next);
    _toLobby(room);
    for (final p in room.players) {
      if (p.connected) p.ready = true;
    }
    final prev = room.gameType;
    room.gameType = next;
    try {
      startGame(userId);
    } catch (_) {
      room.gameType = prev;
      _changed(room);
      rethrow;
    }
    if (party != null) party['index'] = (party['index'] as int) + 1;
    _changed(room);
    return room;
  }

  Map<String, Object?> _ended(LanRoom room, Map<String, Object?> result) {
    final party = room.party;
    if (party == null) return result;
    final ranking = (result['ranking'] as List).cast<Map>();
    final n = ranking.length;
    final last = <String, int>{};
    final totals = (party['totals'] as Map).cast<String, int>();
    for (final r in ranking) {
      final pts =
          n - ((r['rank'] as int?) ?? n) + 1; // 1st gets n points, last gets 1
      last[r['userId'] as String] = pts;
      totals[r['userId'] as String] = (totals[r['userId']] ?? 0) + pts;
    }
    party['totals'] = totals;
    party['lastPoints'] = last;
    party['done'] =
        (party['index'] as int) >= (party['games'] as List).length - 1;
    return {...result, 'party': publicParty(room)};
  }

  Map<String, Object?>? publicParty(LanRoom room) {
    final p = room.party;
    return p == null
        ? null
        : {
            'games': p['games'],
            'index': p['index'],
            'totals': p['totals'],
            'lastPoints': p['lastPoints'],
            'done': p['done']
          };
  }

  /// A move or state from a phone. Returns the game's response for the ack.
  Map<String, Object?>? gameAction(
      String userId, String type, Map payload, int seq) {
    final room = _mustRoom(userId);
    if (room.status != 'playing' || room.game == null)
      throw const LanError('BAD_PHASE');
    if ((room.seqs[userId] ?? -1) >= seq)
      throw const LanError('DUPLICATE_ACTION');
    room.seqs[userId] = seq;
    final response = room.game!.action(userId, type, payload);
    Map<String, Object?>? result;
    if (room.game!.finished) {
      room.status = 'finished';
      result = _ended(room, room.game!.result());
    }
    _changed(room);
    onGameUpdated?.call(room.code, result);
    return response;
  }

  LanRoom returnToLobby(String userId) {
    final room = _mustRoom(userId);
    if (room.hostId != userId) throw const LanError('NOT_HOST');
    if (room.status == 'lobby') throw const LanError('BAD_PHASE');
    _toLobby(room);
    room.party = null;
    _changed(room);
    return room;
  }

  void markDisconnected(String userId) {
    final room = roomOf(userId);
    if (room == null) return;
    room.players.firstWhere((p) => p.userId == userId).connected = false;
    onPlayerDisconnected?.call(room.code, userId);
    _changed(room);
    _timers.remove(userId)?.cancel();
    _timers[userId] = Timer(grace, () {
      _timers.remove(userId);
      _removePlayer(userId);
    });
  }

  LanRoom? reconnect(String userId) {
    final room = roomOf(userId);
    if (room == null) return null;
    _timers.remove(userId)?.cancel();
    room.players.firstWhere((p) => p.userId == userId).connected = true;
    onPlayerReconnected?.call(room.code, userId);
    _changed(room);
    return room;
  }

  Map<String, Object?> publicRoom(LanRoom room) => {
        'code': room.code,
        'gameType': room.gameType,
        'maxPlayers': room.maxPlayers,
        'hostId': room.hostId,
        'status': room.status,
        'isPublic': room.isPublic,
        'party': publicParty(room),
        'playable': _fits(room),
        'players': [
          for (final p in room.players)
            {
              'userId': p.userId,
              'username': p.username,
              'avatar': null,
              'ready': p.ready,
              'connected': p.connected
            },
        ],
      };

  void dispose() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
  }
}
