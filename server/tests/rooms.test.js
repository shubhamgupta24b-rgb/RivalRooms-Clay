const test = require('node:test');
const assert = require('node:assert');
const { io } = require('socket.io-client');
const { createServer } = require('../src/index');
const registry = require('../src/games/registry');
const { GameError } = require('../src/errors');

// Minimal game used only to exercise the plugin contract and generic action pipeline.
registry.register({
  id: 'test_counter', minPlayers: 2, maxPlayers: 4, implemented: true,
  create: room => ({ scores: Object.fromEntries(room.players.map(p => [p.userId, 0])), done: false }),
  onAction(s, uid, a) {
    if (a.type !== 'test:inc') throw new GameError('INVALID_ACTION');
    s.scores[uid]++; if (s.scores[uid] >= 2) s.done = true;
  },
  getPublicState: s => ({ scores: s.scores }),
  isFinished: s => s.done,
  getResult: s => ({ scores: s.scores }),
});
// Registered but not playable yet.
registry.register({ id: 'test_unimplemented', minPlayers: 2, maxPlayers: 4, implemented: false });

const connect = (port, name) => new Promise((res, rej) => {
  const s = io(`http://localhost:${port}`, { auth: { token: `dev:${name}:${name}` }, transports: ['websocket'], reconnection: false });
  s.once('connect', () => res(s)); s.once('connect_error', rej);
});
const emit = (s, ev, p) => new Promise(r => s.emit(ev, p, r));
const waitFor = (s, ev, pred = () => true) => new Promise(r => {
  const h = d => { if (pred(d)) { s.off(ev, h); r(d); } }; s.on(ev, h);
});

async function setup(t, graceMs = 60000) {
  const srv = createServer({ graceMs });
  await new Promise(r => srv.httpServer.listen(0, r));
  const port = srv.httpServer.address().port;
  const clients = [];
  t.after(() => { clients.forEach(c => c.close()); srv.io.close(); srv.httpServer.close(); });
  const mk = async n => { const c = await connect(port, n); clients.push(c); return c; };
  return { port, mk, connect: n => connect(port, n), clients };
}

test('rejects unauthenticated sockets', async t => {
  const { port } = await setup(t);
  await assert.rejects(new Promise((res, rej) => {
    const s = io(`http://localhost:${port}`, { transports: ['websocket'], reconnection: false });
    s.once('connect', res); s.once('connect_error', rej); t.after(() => s.close());
  }));
});

test('room capacity (2/3/4) enforced by server', async t => {
  const { mk } = await setup(t);
  for (const max of [2, 3, 4]) {
    const host = await mk(`host${max}`);
    const r = await emit(host, 'create_room', { gameType: 'memory', maxPlayers: max });
    assert.ok(r.ok); assert.match(r.room.code, /^[A-Z2-9]{6}$/);
    for (let i = 1; i < max; i++) {
      const p = await mk(`p${max}_${i}`);
      assert.ok((await emit(p, 'join_room', { code: r.room.code })).ok);
    }
    const extra = await mk(`extra${max}`);
    assert.strictEqual((await emit(extra, 'join_room', { code: r.room.code })).error, 'ROOM_FULL');
  }
});

test('payload validation', async t => {
  const { mk } = await setup(t);
  const a = await mk('a');
  assert.strictEqual((await emit(a, 'create_room', { gameType: 'memory', maxPlayers: 11 })).error, 'INVALID_PAYLOAD');
  assert.strictEqual((await emit(a, 'create_room', { gameType: 'memory', maxPlayers: 1 })).error, 'INVALID_PAYLOAD');
  assert.strictEqual((await emit(a, 'create_room', { gameType: 'nope', maxPlayers: 2 })).error, 'INVALID_PAYLOAD');
  assert.strictEqual((await emit(a, 'join_room', { code: 'zz' })).error, 'INVALID_PAYLOAD');
  assert.strictEqual((await emit(a, 'join_room', { code: 'ABCDEF' })).error, 'ROOM_NOT_FOUND');
  assert.strictEqual((await emit(a, 'game_action', { type: 'x', seq: 0 })).error, 'NOT_IN_ROOM');
  await emit(a, 'create_room', { gameType: 'memory', maxPlayers: 2 });
  assert.strictEqual((await emit(a, 'create_room', { gameType: 'memory', maxPlayers: 2 })).error, 'ALREADY_IN_ROOM');
});

test('ready/start rules; unimplemented games cannot start', async t => {
  const { mk } = await setup(t);
  const h = await mk('h'), p = await mk('p');
  const { room } = await emit(h, 'create_room', { gameType: 'test_counter', maxPlayers: 3 });
  assert.strictEqual((await emit(h, 'start_game')).error, 'NOT_ENOUGH_PLAYERS');
  await emit(p, 'join_room', { code: room.code });
  assert.strictEqual((await emit(p, 'start_game')).error, 'NOT_HOST');
  assert.strictEqual((await emit(h, 'start_game')).error, 'PLAYERS_NOT_READY');
  await emit(p, 'player_ready');
  assert.ok((await emit(h, 'start_game')).ok);

  const h2 = await mk('h2'), p2 = await mk('p2');
  const r2 = await emit(h2, 'create_room', { gameType: 'test_unimplemented', maxPlayers: 2 });
  await emit(p2, 'join_room', { code: r2.room.code }); await emit(p2, 'player_ready');
  assert.strictEqual((await emit(h2, 'start_game')).error, 'GAME_NOT_AVAILABLE');
});

test('host transfer and room cleanup on leave', async t => {
  const { mk } = await setup(t);
  const h = await mk('h'), p = await mk('p');
  const { room } = await emit(h, 'create_room', { gameType: 'memory', maxPlayers: 2 });
  await emit(p, 'join_room', { code: room.code });
  const changed = waitFor(p, 'room_state', s => s.hostId === 'p');
  await emit(h, 'leave_room');
  const s = await changed;
  assert.strictEqual(s.players.length, 1);
  await emit(p, 'leave_room');
  const q = await mk('q');
  assert.strictEqual((await emit(q, 'join_room', { code: room.code })).error, 'ROOM_NOT_FOUND');
});

test('game action pipeline: anti-cheat, finish, return to lobby', async t => {
  const { mk } = await setup(t);
  const h = await mk('h'), p = await mk('p'), out = await mk('out');
  const { room } = await emit(h, 'create_room', { gameType: 'test_counter', maxPlayers: 2 });
  await emit(p, 'join_room', { code: room.code }); await emit(p, 'player_ready');
  await emit(h, 'start_game');
  assert.strictEqual((await emit(out, 'game_action', { type: 'test:inc', seq: 0 })).error, 'NOT_IN_ROOM');
  assert.strictEqual((await emit(h, 'game_action', { type: 'bogus', seq: 0 })).error, 'INVALID_ACTION');
  assert.ok((await emit(h, 'game_action', { type: 'test:inc', seq: 0 })).ok, 'rejected action does not consume the sequence');
  assert.strictEqual((await emit(h, 'game_action', { type: 'test:inc', seq: 0 })).error, 'DUPLICATE_ACTION');
  assert.strictEqual((await emit(h, 'game_action', { type: 'test:inc', seq: 'x' })).error, 'INVALID_PAYLOAD');
  const fin = waitFor(h, 'game_finished');
  assert.ok((await emit(h, 'game_action', { type: 'test:inc', seq: 1 })).ok);
  assert.strictEqual((await emit(h, 'game_action', { type: 'test:inc', seq: 2 })).error, 'BAD_PHASE');
  assert.deepStrictEqual((await fin).scores, { h: 2, p: 0 });
  assert.strictEqual((await emit(p, 'game_action', { type: 'test:inc', seq: 0 })).error, 'BAD_PHASE');
  assert.strictEqual((await emit(p, 'return_to_lobby')).error, 'NOT_HOST');
  assert.ok((await emit(h, 'return_to_lobby')).ok);
  assert.strictEqual((await emit(h, 'resume_session')).room.status, 'lobby');
});

test('reconnect within grace keeps seat; expires after grace', async t => {
  const { mk, connect } = await setup(t, 300);
  const h = await mk('h'), p = await mk('p');
  const { room } = await emit(h, 'create_room', { gameType: 'memory', maxPlayers: 2 });
  await emit(p, 'join_room', { code: room.code });
  const dc = waitFor(h, 'player_disconnected');
  p.disconnect();
  assert.strictEqual((await dc).userId, 'p');
  const p2 = await connect('p'); t.after(() => p2.close());
  const r = await emit(p2, 'resume_session');
  assert.strictEqual(r.room.code, room.code);
  assert.ok(r.room.players.find(x => x.userId === 'p').connected);

  p2.disconnect();
  await new Promise(r => setTimeout(r, 500));
  const p3 = await connect('p'); t.after(() => p3.close());
  assert.strictEqual((await emit(p3, 'resume_session')).room, null);
});
