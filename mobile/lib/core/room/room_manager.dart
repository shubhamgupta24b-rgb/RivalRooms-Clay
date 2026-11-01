import 'dart:async';
import 'package:flutter/foundation.dart';
import '../network/socket_manager.dart';

class RoomPlayer {
  final String userId, username;
  final bool ready, connected;
  RoomPlayer(this.userId, this.username, this.ready, this.connected);
  factory RoomPlayer.fromJson(Map j) => RoomPlayer(j['userId'],
      j['username'] ?? '?', j['ready'] == true, j['connected'] == true);
}

/// Party mode: a run of random games with a running points table.
class Party {
  final List<String> games;
  final int index; // game being played / just played
  final Map<String, int> totals;
  final Map<String, int>? lastPoints;
  final bool done;
  Party(this.games, this.index, this.totals, this.lastPoints, this.done);
  factory Party.fromJson(Map j) => Party(
        (j['games'] as List).cast<String>(),
        (j['index'] as num).toInt(),
        {
          for (final e in (j['totals'] as Map).entries)
            '${e.key}': (e.value as num).toInt()
        },
        j['lastPoints'] == null
            ? null
            : {
                for (final e in (j['lastPoints'] as Map).entries)
                  '${e.key}': (e.value as num).toInt()
              },
        j['done'] == true,
      );
  String? get nextGame => index + 1 < games.length ? games[index + 1] : null;
}

class Room {
  final String code, gameType, hostId, status;
  final int maxPlayers;
  final List<RoomPlayer> players;
  final Party? party;
  final Set<String>
      playable; // games that fit the players in the room right now
  final bool isPublic; // a Quick Play room: strangers can be matched into it
  Room(this.code, this.gameType, this.hostId, this.status, this.maxPlayers,
      this.players,
      {this.party, this.playable = const {}, this.isPublic = false});
  factory Room.fromJson(Map j) => Room(
        j['code'],
        j['gameType'],
        j['hostId'],
        j['status'],
        j['maxPlayers'],
        (j['players'] as List)
            .map((p) => RoomPlayer.fromJson(p as Map))
            .toList(),
        party: j['party'] == null ? null : Party.fromJson(j['party'] as Map),
        playable: {...((j['playable'] as List?) ?? const []).cast<String>()},
        isPublic: j['isPublic'] == true,
      );
  bool get allReady =>
      players.length >= 2 && players.every((p) => p.ready && p.connected);
}

const _errorText = {
  'ROOM_FULL': 'That room is full.',
  'ROOM_NOT_FOUND': 'Room not found. Check the code.',
  'ALREADY_IN_ROOM': 'You are already in a room.',
  'GAME_IN_PROGRESS': 'That game has already started.',
  'NOT_HOST': 'Only the host can do that.',
  'NOT_ENOUGH_PLAYERS': 'Not enough players for this game.',
  'TOO_MANY_PLAYERS': 'Too many players for this game. Pick another one.',
  'PLAYERS_NOT_READY': 'Everyone must be ready.',
  'GAME_NOT_AVAILABLE': 'This game is not implemented yet.',
  'NEEDS_INTERNET':
      'This game needs 🌐 Online mode (internet). Pick another game for hotspot play.',
  'INVALID_PAYLOAD': 'Invalid input.',
  'OFFLINE':
      'Not connected yet. The server may be waking up (up to a minute): try again shortly.',
  'TIMEOUT': 'Server did not respond. Check your internet and try again.',
  'BAD_PHASE': 'Not possible right now.',
  'RATE_LIMITED': 'Too many requests, slow down.',
};
String errorMessage(String? code) =>
    _errorText[code] ?? 'Something went wrong ($code).';

class RoomManager extends ChangeNotifier {
  final SocketManager _socket;
  late final StreamSubscription<SocketEvent> _sub;
  Room? room;
  String? notice; // transient server notices, e.g. SESSION_REPLACED

  RoomManager(this._socket) {
    _sub = _socket.events.listen(_onEvent);
    _socket.connected.addListener(() {
      if (_socket.connected.value) resync();
    });
  }

  void _onEvent(SocketEvent e) {
    if (e.name == 'room_state') {
      room = Room.fromJson(e.data as Map);
      notifyListeners();
    } else if (e.name == 'error' && e.data is Map) {
      notice = errorMessage((e.data as Map)['code']?.toString());
      notifyListeners();
    }
  }

  /// After every (re)connect ask the server what room we're in; null means the seat expired.
  Future<void> resync() async {
    final r = await _socket.request('resume_session');
    if (r['ok'] == true) {
      room = r['room'] == null ? null : Room.fromJson(r['room'] as Map);
      notifyListeners();
    }
  }

  Future<String?> _roomCall(String event, [Map<String, dynamic>? p]) async {
    final r = await _socket.request(event, p);
    if (r['ok'] != true) {
      // The room moved on without us noticing (e.g. a player left mid-game): catch up.
      if (r['error'] == 'BAD_PHASE') await resync();
      return errorMessage(r['error']?.toString());
    }
    if (r['room'] != null) {
      room = Room.fromJson(r['room'] as Map);
      notifyListeners();
    }
    return null;
  }

  Future<String?> create(String gameType, int maxPlayers) => _roomCall(
      'create_room', {'gameType': gameType, 'maxPlayers': maxPlayers});
  Future<String?> join(String code) =>
      _roomCall('join_room', {'code': code.trim().toUpperCase()});

  /// Quick Play: matched into a random open room (for [gameType], or any game).
  Future<String?> quickPlay([String? gameType]) =>
      _roomCall('quick_play', {if (gameType != null) 'gameType': gameType});
  Future<String?> setReady(bool ready) =>
      _roomCall(ready ? 'player_ready' : 'player_unready');
  Future<String?> start() => _roomCall('start_game');
  Future<String?> returnToLobby() => _roomCall('return_to_lobby');
  Future<String?> selectGame(String gameType) =>
      _roomCall('select_game', {'gameType': gameType});
  Future<String?> startParty([int count = 5]) =>
      _roomCall('start_party', {'count': count});

  /// After a game: the next party game, [gameType], or the same game again.
  Future<String?> nextGame([String? gameType]) =>
      _roomCall('next_game', {if (gameType != null) 'gameType': gameType});

  Future<void> leave() async {
    await _socket.request('leave_room');
    room = null;
    notifyListeners();
  }

  void clearNotice() => notice = null;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
