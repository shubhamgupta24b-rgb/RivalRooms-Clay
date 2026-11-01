const { GameError } = require('../errors');
const registry = require('../games/registry');
const { verifyToken } = require('../auth/verify');
const { upsertUser } = require('../database');

const CODE_RE = /^[A-Z0-9]{6}$/;

function allow(socket) {                       // token bucket: 60 burst, 30/sec refill
  const now = Date.now(), b = socket.data.bucket ||= { t: 60, last: now };
  b.t = Math.min(60, b.t + (now - b.last) * 0.03); b.last = now;
  if (b.t < 1) return false;
  b.t -= 1; return true;
}

function attachSockets(io, rooms) {
  const sockets = new Map(); // userId -> socket

  io.use(async (socket, next) => {
    try {
      const u = await verifyToken(socket.handshake.auth && socket.handshake.auth.token);
      socket.data.user = { userId: u.uid, username: u.name, avatar: u.picture };
      upsertUser(socket.data.user).catch(e => console.error('[db] upsert failed', e.message));
      next();
    } catch { next(new Error('UNAUTHORIZED')); }
  });

  const sendGameState = (room, only) => {
    if (room.status === 'lobby' || !room.game) return;
    const game = registry.get(room.gameType);
    for (const p of room.players) {
      if (only && only !== p.userId) continue;
      const s = sockets.get(p.userId);
      if (s) s.emit('game_state', { ...game.getPublicState(room.game, p.userId), serverNow: Date.now() });
    }
  };

  rooms.on('room_changed', code => {
    const r = rooms.get(code);
    if (r) io.to(code).emit('room_state', rooms.publicRoom(r));
  });
  rooms.on('player_disconnected', (code, userId) => io.to(code).emit('player_disconnected', { userId }));
  rooms.on('player_reconnected', (code, userId) => io.to(code).emit('player_reconnected', { userId }));
  rooms.on('game_updated', (code, result) => {
    const r = rooms.get(code);
    if (!r) return;
    sendGameState(r);
    if (result) io.to(code).emit('game_finished', result);
  });
  rooms.on('game_aborted', code => io.to(code).emit('error', { code: 'GAME_ABORTED' }));

  io.on('connection', socket => {
    const user = socket.data.user, { userId } = user;
    const old = sockets.get(userId);
    sockets.set(userId, socket);
    if (old && old.id !== socket.id) { old.emit('error', { code: 'SESSION_REPLACED' }); old.disconnect(true); }

    const resumed = rooms.reconnect(userId);
    if (resumed) {
      socket.join(resumed.code);
      socket.emit('room_state', rooms.publicRoom(resumed));
      sendGameState(resumed, userId);
      if (resumed.status === 'finished') {
        const result = registry.get(resumed.gameType).getResult(resumed.game);
        socket.emit('game_finished', resumed.party ? { ...result, party: rooms.publicRoom(resumed).party } : result);
      }
    }

    // Wraps a handler: rate limit, validate, ack {ok,...} or {ok:false,error}
    const on = (event, fn) => socket.on(event, async (payload, cb) => {
      const ack = typeof cb === 'function' ? cb : () => {};
      try {
        if (sockets.get(userId) !== socket) throw new GameError('SESSION_REPLACED');
        if (!allow(socket)) throw new GameError('RATE_LIMITED');
        ack({ ok: true, ...(await fn(payload || {})) });
      } catch (e) {
        if (e instanceof GameError) ack({ ok: false, error: e.code, message: e.message });
        else { console.error(e); ack({ ok: false, error: 'INTERNAL' }); }
      }
    });

    on('create_room', p => {
      const room = rooms.createRoom(user, { gameType: String(p.gameType), maxPlayers: p.maxPlayers });
      socket.join(room.code);
      return { room: rooms.publicRoom(room) };
    });
    on('quick_play', p => {
      const room = rooms.quickPlay(user, { gameType: p.gameType === undefined || p.gameType === null ? undefined : String(p.gameType) });
      socket.join(room.code);
      return { room: rooms.publicRoom(room) };
    });
    on('join_room', p => {
      const code = typeof p.code === 'string' ? p.code.trim().toUpperCase() : '';
      if (!CODE_RE.test(code)) throw new GameError('INVALID_PAYLOAD', 'bad room code');
      const room = rooms.joinRoom(user, code);
      socket.join(code);
      return { room: rooms.publicRoom(room) };
    });
    on('leave_room', () => {
      const room = rooms.roomOf(userId);
      rooms.leave(userId);
      if (room) socket.leave(room.code);
      return {};
    });
    on('player_ready', () => { rooms.setReady(userId, true); return {}; });
    on('player_unready', () => { rooms.setReady(userId, false); return {}; });
    on('start_game', () => {
      const room = rooms.startGame(userId);
      io.to(room.code).emit('round_started', { gameType: room.gameType });
      sendGameState(room);
      return {};
    });
    on('game_action', p => {
      if (typeof p.type !== 'string' || p.type.length > 40 || !Number.isSafeInteger(p.seq) || p.seq < 0
        || (p.payload !== undefined && (typeof p.payload !== 'object' || p.payload === null || Array.isArray(p.payload))))
        throw new GameError('INVALID_PAYLOAD');
      const { response } = rooms.gameAction(userId, p);
      return { response: response || null };
    });
    on('return_to_lobby', () => { rooms.returnToLobby(userId); return {}; });
    on('select_game', p => ({ room: rooms.publicRoom(rooms.selectGame(userId, String(p.gameType))) }));
    const begin = room => {
      io.to(room.code).emit('round_started', { gameType: room.gameType });
      sendGameState(room);
      return { room: rooms.publicRoom(room) };
    };
    on('start_party', p => begin(rooms.startParty(userId, p.count ?? 5)));
    on('next_game', p => begin(rooms.nextGame(userId, p.gameType === undefined ? undefined : String(p.gameType))));
    on('resume_session', () => {
      const room = rooms.roomOf(userId);
      return { room: room ? rooms.publicRoom(room) : null };
    });

    socket.on('disconnect', () => {
      if (sockets.get(userId) !== socket) return;   // replaced by a newer connection
      sockets.delete(userId);
      rooms.markDisconnected(userId);
    });
  });
}
module.exports = { attachSockets };
