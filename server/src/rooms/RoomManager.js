const { EventEmitter } = require('events');
const crypto = require('crypto');
const { GameError } = require('../errors');
const registry = require('../games/registry');
const { MemoryRoomStore } = require('./RoomStore');

const CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
// Games the app no longer offers in rooms; never picked for party mode.
const NOT_IN_ROOMS = new Set(['guess_person', 'crush_it', 'fruit_duel', 'snake_duel', 'penalty', 'classic_snake']);

class RoomManager extends EventEmitter {
  constructor({ store = new MemoryRoomStore(), graceMs = 60000 } = {}) {
    super();
    this.store = store;
    this.graceMs = graceMs;
    this.userRoom = new Map();   // userId -> room code
    this.timers = new Map();     // userId -> grace timer
  }

  _code() {
    for (let i = 0; i < 50; i++) {
      const b = crypto.randomBytes(6);
      const code = Array.from(b, x => CHARS[x % CHARS.length]).join('');
      if (!this.store.has(code)) return code;
    }
    throw new GameError('INTERNAL', 'could not allocate code');
  }
  get(code) { return this.store.get(code); }
  roomOf(userId) { const c = this.userRoom.get(userId); return c ? this.store.get(c) : null; }
  _mustRoom(userId) {
    const r = this.roomOf(userId);
    if (!r) throw new GameError('NOT_IN_ROOM');
    return r;
  }
  _changed(room) { this.emit('room_changed', room.code); }

  createRoom(user, { gameType, maxPlayers }) {
    if (this.userRoom.has(user.userId)) throw new GameError('ALREADY_IN_ROOM');
    const game = registry.get(gameType);
    if (!game) throw new GameError('INVALID_PAYLOAD', 'unknown gameType');
    // The room size is independent of the game: the host can switch games in the lobby.
    if (!Number.isInteger(maxPlayers) || maxPlayers < 2 || maxPlayers > 10) throw new GameError('INVALID_PAYLOAD', 'maxPlayers must be 2 to 10');
    const code = this._code();
    const room = { code, gameType, maxPlayers, hostId: user.userId, status: 'lobby', players: [], game: null, seqs: Object.create(null), party: null, createdAt: Date.now() };
    room.players.push({ ...user, ready: true, connected: true });
    this.store.set(code, room);
    this.userRoom.set(user.userId, code);
    return room;
  }

  /// Quick Play: join a random open public room (for [gameType] if given), or open a new
  /// public room that the next quick player will find. Rooms made with a code stay private.
  quickPlay(user, { gameType } = {}) {
    if (this.userRoom.has(user.userId)) throw new GameError('ALREADY_IN_ROOM');
    if (gameType !== undefined && (!registry.get(gameType) || NOT_IN_ROOMS.has(gameType))) throw new GameError('INVALID_PAYLOAD', 'unknown gameType');
    const open = [...this.store.values()].filter(r =>
      r.isPublic && r.status === 'lobby' && r.players.length < r.maxPlayers && r.players.some(p => p.connected) &&
      (gameType === undefined || r.gameType === gameType));
    if (open.length) {
      // Fullest first, so groups fill up and start sooner; random among equals.
      const most = Math.max(...open.map(r => r.players.length));
      const best = open.filter(r => r.players.length === most);
      return this.joinRoom(user, best[crypto.randomInt(best.length)].code);
    }
    const pool = registry.list().filter(g => g.implemented && !g.optIn && !NOT_IN_ROOMS.has(g.id) && g.minPlayers <= 2).map(g => g.id);
    const room = this.createRoom(user, { gameType: gameType ?? pool[crypto.randomInt(pool.length)], maxPlayers: 6 });
    room.isPublic = true;
    return room;
  }

  joinRoom(user, code) {
    if (this.userRoom.has(user.userId)) throw new GameError('ALREADY_IN_ROOM');
    const room = this.store.get(code);
    if (!room) throw new GameError('ROOM_NOT_FOUND');
    if (room.status !== 'lobby') throw new GameError('GAME_IN_PROGRESS');
    if (room.players.length >= room.maxPlayers) throw new GameError('ROOM_FULL');
    room.players.push({ ...user, ready: false, connected: true });
    this.userRoom.set(user.userId, code);
    this._changed(room);
    return room;
  }

  leave(userId) {
    this._mustRoom(userId);
    this._removePlayer(userId);
  }

  _removePlayer(userId) {
    const room = this.roomOf(userId);
    clearTimeout(this.timers.get(userId)); this.timers.delete(userId);
    this.userRoom.delete(userId);
    if (!room) return;
    room.players = room.players.filter(p => p.userId !== userId);
    delete room.seqs[userId];
    if (room.players.length === 0) { this.store.delete(room.code); this.emit('room_closed', room.code); return; }
    if (room.hostId === userId) {
      room.hostId = (room.players.find(p => p.connected) || room.players[0]).userId;
      room.players.find(p => p.userId === room.hostId).ready = true;
    }
    // Plugins keep a fixed roster and have no safe participant-removal/migration contract.
    // Nitro snapshots omit velocities, cooldowns and other Rapier state: transferring
    // its host would restart/diverge the simulation, not resume the existing match.
    if (room.status === 'playing' || (room.status === 'finished' && room.players.length < 2)) {
      this._toLobby(room);
      room.party = null;
      this.emit('game_aborted', room.code);
    }
    this._changed(room);
  }

  _toLobby(room) {
    room.status = 'lobby'; room.game = null; room.seqs = Object.create(null);
    // Players who just played stay ready, so the host can go straight into the next game.
    for (const p of room.players) p.ready = p.userId === room.hostId || (p.ready && p.connected);
  }

  /** Host picks the game for the next round. */
  selectGame(userId, gameType) {
    const room = this._mustRoom(userId);
    if (room.hostId !== userId) throw new GameError('NOT_HOST');
    if (room.status !== 'lobby') throw new GameError('BAD_PHASE');
    const game = registry.get(gameType);
    if (!game || !game.implemented || NOT_IN_ROOMS.has(gameType)) throw new GameError('INVALID_PAYLOAD', 'unknown gameType');
    room.gameType = gameType;
    room.party = null; // picking a game by hand ends a party
    this._changed(room);
    return room;
  }

  /** Games that can be played with the players currently in the room. */
  _fits(room) {
    const n = room.players.length;
    return registry.list().filter(g => g.implemented && !NOT_IN_ROOMS.has(g.id) && n >= g.minPlayers && n <= g.maxPlayers).map(g => g.id);
  }

  /** Party mode: [count] random games in a row with a running points table. */
  startParty(userId, count = 5) {
    const room = this._mustRoom(userId);
    if (room.hostId !== userId) throw new GameError('NOT_HOST');
    if (room.status !== 'lobby') throw new GameError('BAD_PHASE');
    if (!Number.isInteger(count) || count < 2 || count > 10) throw new GameError('INVALID_PAYLOAD');
    if (room.players.length < 2) throw new GameError('NOT_ENOUGH_PLAYERS');
    const pool = this._fits(room).filter(id => !registry.get(id).optIn); // opt-in games only when picked
    for (let i = pool.length - 1; i > 0; i--) { const j = crypto.randomInt(i + 1); [pool[i], pool[j]] = [pool[j], pool[i]]; }
    const games = pool.slice(0, Math.min(count, pool.length));
    const prevType = room.gameType;
    room.gameType = games[0];
    try {
      this.startGame(userId);
    } catch (e) { room.gameType = prevType; throw e; }
    room.party = { games, index: 0, totals: Object.fromEntries(room.players.map(p => [p.userId, 0])), lastPoints: null, done: false };
    this._changed(room);
    return room;
  }

  /** After a game: the next party game, or (outside a party) [gameType] / the same game again. */
  nextGame(userId, gameType) {
    const room = this._mustRoom(userId);
    if (room.hostId !== userId) throw new GameError('NOT_HOST');
    if (room.status !== 'finished') throw new GameError('BAD_PHASE');
    const party = room.party;
    let next = gameType || room.gameType;
    if (party) {
      if (party.done) throw new GameError('BAD_PHASE');
      next = party.games[party.index + 1];
    }
    const game = registry.get(next);
    if (!game || !game.implemented || NOT_IN_ROOMS.has(next)) throw new GameError('INVALID_PAYLOAD', 'unknown gameType');
    const players = room.players.map(p => ({ ...p, ready: p.connected ? true : p.ready }));
    const state = this._createGame({ ...room, status: 'lobby', gameType: next, players });
    room.players = players;
    room.gameType = next;
    room.game = state;
    room.seqs = Object.create(null);
    room.status = 'playing';
    if (party) party.index++;
    this._changed(room);
    return room;
  }

  /** A game just ended: score the party, if any. Returns the result to broadcast. */
  _ended(room, result) {
    const party = room.party;
    if (party && result && Array.isArray(result.ranking)) {
      const n = result.ranking.length;
      party.lastPoints = {};
      for (const r of result.ranking) {
        const pts = n - (r.rank || n) + 1; // 1st gets n points, last gets 1
        party.lastPoints[r.userId] = pts;
        party.totals[r.userId] = (party.totals[r.userId] || 0) + pts;
      }
      party.done = party.index >= party.games.length - 1;
      result = { ...result, party: this._publicParty(room) };
    }
    return result;
  }

  _publicParty(room) {
    const p = room.party;
    return p && { games: p.games, index: p.index, totals: p.totals, lastPoints: p.lastPoints, done: p.done };
  }

  setReady(userId, ready) {
    const room = this._mustRoom(userId);
    if (room.status !== 'lobby') throw new GameError('BAD_PHASE');
    if (userId === room.hostId) return room;           // host is always ready
    room.players.find(p => p.userId === userId).ready = !!ready;
    this._changed(room);
    return room;
  }

  startGame(userId) {
    const room = this._mustRoom(userId);
    if (room.hostId !== userId) throw new GameError('NOT_HOST');
    if (room.status !== 'lobby') throw new GameError('BAD_PHASE');
    const state = this._createGame(room);
    room.game = state;
    room.status = 'playing';
    room.seqs = Object.create(null);
    this._changed(room);
    return room;
  }

  _createGame(room) {
    const game = registry.get(room.gameType);
    if (!game || !game.implemented) throw new GameError('GAME_NOT_AVAILABLE');
    if (room.players.length < Math.max(2, game.minPlayers)) throw new GameError('NOT_ENOUGH_PLAYERS');
    if (room.players.length > game.maxPlayers) throw new GameError('TOO_MANY_PLAYERS');
    if (!room.players.every(p => p.ready && p.connected)) throw new GameError('PLAYERS_NOT_READY');
    return game.create(room);
  }

  gameAction(userId, { type, payload, seq }) {
    const room = this._mustRoom(userId);
    if (room.status !== 'playing') throw new GameError('BAD_PHASE');
    if (typeof type !== 'string' || type.length > 40 || !Number.isSafeInteger(seq) || seq < 0
      || (payload !== undefined && (typeof payload !== 'object' || payload === null || Array.isArray(payload)))) {
      throw new GameError('INVALID_PAYLOAD');
    }
    if ((room.seqs[userId] ?? -1) >= seq) throw new GameError('DUPLICATE_ACTION');
    const game = registry.get(room.gameType);
    const response = game.onAction(room.game, userId, { type, payload }, Date.now());   // throws GameError if invalid
    room.seqs[userId] = seq;
    let result = null;
    if (game.isFinished(room.game)) {
      room.status = 'finished';
      result = this._ended(room, game.getResult(room.game));
    }
    // Nitro inputs are pulled by the host on its next snapshot, without echoing
    // the full room and game to every player for each steering update.
    if (result || !response?.silent) {
      this._changed(room);
      this.emit('game_updated', room.code, result);
    }
    return { room, result, response };
  }

  // Server clock: advances timed phases (clue reveals, round ends). Called every ~250ms.
  tick(now = Date.now()) {
    for (const room of this.store.values()) {
      if (room.status !== 'playing') continue;
      const game = registry.get(room.gameType);
      try {
        if (!game.onTick || !game.onTick(room.game, now)) continue;
        let result = null;
        if (game.isFinished(room.game)) { room.status = 'finished'; result = this._ended(room, game.getResult(room.game)); this._changed(room); }
        this.emit('game_updated', room.code, result);
      } catch (e) { console.error('[tick]', room.code, e); }
    }
  }

  returnToLobby(userId) {
    const room = this._mustRoom(userId);
    if (room.hostId !== userId) throw new GameError('NOT_HOST');
    if (room.status === 'lobby') throw new GameError('BAD_PHASE');
    this._toLobby(room);
    room.party = null;
    this._changed(room);
    return room;
  }

  markDisconnected(userId) {
    const room = this.roomOf(userId);
    if (!room) return;
    const player = room.players.find(p => p.userId === userId);
    if (!player.connected) return;
    player.connected = false;
    this.emit('player_disconnected', room.code, userId);
    this._changed(room);
    const t = setTimeout(() => {
      if (this.timers.get(userId) !== t) return;
      this.timers.delete(userId);
      if (this.roomOf(userId) === room && !player.connected) this._removePlayer(userId);
    }, this.graceMs);
    t.unref();
    this.timers.set(userId, t);
  }

  reconnect(userId) {
    const room = this.roomOf(userId);
    if (!room) return null;
    clearTimeout(this.timers.get(userId)); this.timers.delete(userId);
    room.players.find(p => p.userId === userId).connected = true;
    this.emit('player_reconnected', room.code, userId);
    this._changed(room);
    return room;
  }

  close() {
    for (const timer of this.timers.values()) clearTimeout(timer);
    this.timers.clear();
    this.userRoom.clear();
    for (const room of this.store.values()) this.store.delete(room.code);
  }

  publicRoom(room) {
    return {
      code: room.code, gameType: room.gameType, maxPlayers: room.maxPlayers, hostId: room.hostId, status: room.status,
      isPublic: !!room.isPublic, party: this._publicParty(room), playable: this._fits(room),
      players: room.players.map(({ userId, username, avatar, ready, connected }) => ({ userId, username, avatar, ready, connected })),
    };
  }
}
module.exports = { RoomManager };
