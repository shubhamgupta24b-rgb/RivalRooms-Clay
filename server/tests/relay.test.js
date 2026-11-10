const test = require('node:test');
const assert = require('node:assert');
const { io } = require('socket.io-client');
const { createServer } = require('../src/index');
const registry = require('../src/games/registry');
const { RELAY_GAMES, createRelayGame } = require('../src/games/relay');

const room = (n, hostId = 'a') => ({ hostId, players: ['a', 'b', 'c', 'd', 'e', 'f'].slice(0, n).map(u => ({ userId: u, username: u.toUpperCase() })) });
const act = (g, s, u, type, payload) => g.onAction(s, u, { type, payload });

test('Relay: every relay game is registered with its player limits', () => {
  assert.strictEqual(RELAY_GAMES.length, 51);
  assert.strictEqual(new Set(RELAY_GAMES.map(g => g.id)).size, 51, 'no duplicates');
  for (const { id, min, max } of RELAY_GAMES) {
    const g = registry.get(id);
    assert.ok(g && g.relay, id);
    assert.deepStrictEqual([g.minPlayers, g.maxPlayers], [min, max], id);
  }
});

test('Smash Karts is no longer exposed by the relay registry', () => {
  assert.strictEqual(registry.has('smash_karts'), false);
  assert.strictEqual(RELAY_GAMES.some(g => g.id === 'smash_karts'), false);
});

test('Relay: player count limits and host choice', () => {
  const g = createRelayGame({ id: 'x', min: 2, max: 4 });
  assert.throws(() => g.create(room(1)), e => e.code === 'NOT_ENOUGH_PLAYERS');
  assert.throws(() => g.create(room(5)), e => e.code === 'NOT_ENOUGH_PLAYERS');
  assert.strictEqual(g.create(room(3, 'b')).host, 'b');
  assert.strictEqual(g.create(room(3, 'zz')).host, 'a', 'host not in game: first player');
});

test('Relay: only the host publishes state; guests send inputs only the host sees', () => {
  const g = createRelayGame({ id: 'x', min: 2, max: 4 });
  const s = g.create(room(3));
  assert.throws(() => act(g, s, 'b', 'relay:state', { state: { hack: 1 } }), e => e.code === 'NOT_HOST');
  assert.throws(() => act(g, s, 'zz', 'relay:input', { name: 'tap', args: [] }), e => e.code === 'NOT_IN_GAME');
  assert.deepStrictEqual(act(g, s, 'a', 'relay:state', { state: { turn: 0 } }), { version: 1 });

  act(g, s, 'b', 'relay:input', { name: 'play', args: [3] });
  act(g, s, 'c', 'relay:input', { name: 'move', args: [0.5, 1.2, true, null, 'x'] });
  const host = g.getPublicState(s, 'a'), guest = g.getPublicState(s, 'b');
  assert.deepStrictEqual(host.inputs.map(i => [i.seq, i.from, i.name]), [[1, 'b', 'play'], [2, 'c', 'move']]);
  assert.deepStrictEqual(guest.inputs, [], 'guests never see the queue');
  assert.deepStrictEqual(guest.state, { turn: 0 });
  assert.strictEqual(guest.host, 'a');

  // Acknowledged inputs are dropped.
  act(g, s, 'a', 'relay:state', { state: { turn: 1 }, ack: 1 });
  assert.deepStrictEqual(g.getPublicState(s, 'a').inputs.map(i => i.seq), [2]);
  assert.strictEqual(g.getPublicState(s, 'c').version, 2);
});

test('Relay: inputs and states are validated', () => {
  const g = createRelayGame({ id: 'x', min: 2, max: 2 });
  const s = g.create(room(2));
  for (const bad of [{ name: '', args: [] }, { name: '1abc', args: [] }, { name: 'ok', args: 'no' }, { name: 'ok', args: [{}] }, { name: 'ok', args: new Array(9).fill(0) }]) {
    assert.throws(() => act(g, s, 'b', 'relay:input', bad), e => e.code === 'INVALID_PAYLOAD', JSON.stringify(bad));
  }
  for (const bad of [null, [], 'x', { big: 'x'.repeat(70000) }]) {
    assert.throws(() => act(g, s, 'a', 'relay:state', { state: bad }), e => e.code === 'INVALID_PAYLOAD');
  }
  assert.throws(() => act(g, s, 'a', 'nope', {}), e => e.code === 'INVALID_ACTION');
  // The queue is capped.
  for (let i = 0; i < 250; i++) act(g, s, 'b', 'relay:input', { name: 'move', args: [i] });
  assert.strictEqual(g.getPublicState(s, 'a').inputs.length, 200);
  assert.strictEqual(g.getPublicState(s, 'a').inputs.at(-1).args[0], 249, 'newest kept');
});

test('Relay: rejected publications are atomic, including private views and acknowledgements', () => {
  const g = createRelayGame({ id: 'x', min: 2, max: 2 });
  const s = g.create(room(2));
  act(g, s, 'b', 'relay:input', { name: 'tap', args: [1] });
  act(g, s, 'a', 'relay:state', { state: { turn: 0 }, views: [{ secret: 'a' }, { secret: 'b' }] });
  const before = JSON.stringify(s);
  const cyclic = {}; cyclic.self = cyclic;
  for (const payload of [
    { state: { turn: 1 }, views: [], ack: 1 },
    { state: { turn: 1 }, views: [{}, null], ack: 1 },
    { state: { turn: 1 }, views: [{}, { text: '界'.repeat(24000) }], ack: 1 },
    { state: { turn: 1 }, views: [{}, cyclic], ack: 1 },
    { state: cyclic },
    ...[-1, 2, 0.5, null, '1', Infinity, Number.MAX_SAFE_INTEGER + 1].map(ack => ({ state: { turn: 1 }, ack })),
  ]) {
    assert.throws(() => act(g, s, 'a', 'relay:state', payload), e => e.code === 'INVALID_PAYLOAD');
    assert.strictEqual(JSON.stringify(s), before, 'rejection cannot change state, views, version or the queue');
  }
  assert.deepStrictEqual(g.getPublicState(s, 'b').state, { turn: 0, _seat: { secret: 'b' } });
  assert.deepStrictEqual(act(g, s, 'a', 'relay:state', { state: { turn: 1 }, ack: 1 }), { version: 2 });
  assert.strictEqual(s.views, null, 'omitting views clears the previous private views');
  assert.deepStrictEqual(s.inputs, []);
  // Repeated/older acknowledgements cannot restore already consumed input.
  act(g, s, 'b', 'relay:input', { name: 'tap', args: [2] });
  act(g, s, 'a', 'relay:state', { state: {}, ack: 1 });
  act(g, s, 'a', 'relay:state', { state: {}, ack: 0 });
  assert.deepStrictEqual(s.inputs.map(i => i.seq), [2]);
});

test('Relay: limits measure UTF-8 bytes and accept the exact state-size boundary', () => {
  const g = createRelayGame({ id: 'x', min: 2, max: 2 });
  const s = g.create(room(2));
  const limit = 64 * 1024;
  const overhead = Buffer.byteLength(JSON.stringify({ text: '' }), 'utf8');
  const state = { text: 'x'.repeat(limit - overhead) };
  assert.strictEqual(Buffer.byteLength(JSON.stringify(state), 'utf8'), limit);
  act(g, s, 'a', 'relay:state', { state });
  const before = JSON.stringify(s);
  for (const oversized of [{ text: state.text + 'x' }, { text: '界'.repeat(24000) }, { text: '😀'.repeat(17000) }]) {
    assert.throws(() => act(g, s, 'a', 'relay:state', { state: oversized }), e => e.code === 'INVALID_PAYLOAD');
    assert.strictEqual(JSON.stringify(s), before);
  }
});

test('Relay: malformed inputs and scores do not consume queue IDs or finish the game', () => {
  const g = createRelayGame({ id: 'x', min: 2, max: 2 });
  const s = g.create(room(2));
  const before = JSON.stringify(s);
  for (const args of [[NaN], [Infinity], [-Infinity], ['界'.repeat(24000)], new Array(1)]) {
    assert.throws(() => act(g, s, 'b', 'relay:input', { name: 'tap', args }), e => e.code === 'INVALID_PAYLOAD');
    assert.strictEqual(JSON.stringify(s), before);
  }
  for (const scores of [[Number.MAX_SAFE_INTEGER + 1, 0], [NaN, 0], new Array(2)]) {
    assert.throws(() => act(g, s, 'a', 'relay:finish', { scores }), e => e.code === 'INVALID_PAYLOAD');
    assert.strictEqual(JSON.stringify(s), before);
  }
  assert.deepStrictEqual(act(g, s, 'b', 'relay:input', { name: 'tap', args: [0, true, null, 'ok'] }), { seq: 1 });
});

test('Relay: the host finishes the game with scores in player order', () => {
  const g = createRelayGame({ id: 'x', min: 2, max: 4 });
  const s = g.create(room(3));
  assert.throws(() => act(g, s, 'b', 'relay:finish', { scores: [1, 0, 0] }), e => e.code === 'NOT_HOST');
  assert.throws(() => act(g, s, 'a', 'relay:finish', { scores: [1, 0] }), e => e.code === 'INVALID_PAYLOAD');
  act(g, s, 'a', 'relay:finish', { scores: [3, 7, 3] });
  assert.ok(g.isFinished(s));
  const r = g.getResult(s);
  assert.deepStrictEqual(r.ranking.map(x => [x.userId, x.score, x.rank]), [['b', 7, 1], ['a', 3, 2], ['c', 3, 2]]);
  assert.deepStrictEqual(r.winners, ['b']);
  assert.throws(() => act(g, s, 'b', 'relay:input', { name: 'late', args: [] }), e => e.code === 'BAD_PHASE');
});

test('Rooms: up to 10 players; a game only starts if it supports everyone in the room', () => {
  const srv = createServer();
  const rm = srv.rooms;
  rm.createRoom({ userId: 'h', username: 'H' }, { gameType: 'ludo', maxPlayers: 6 });
  assert.throws(() => rm.createRoom({ userId: 'j', username: 'J' }, { gameType: 'colour_clash', maxPlayers: 11 }), e => e.code === 'INVALID_PAYLOAD');
  const code = rm.roomOf('h').code;
  for (const u of ['a', 'b', 'c', 'd']) { rm.joinRoom({ userId: u, username: u }, code); rm.setReady(u, true); }
  assert.throws(() => rm.startGame('h'), e => e.code === 'TOO_MANY_PLAYERS', 'Ludo is 2-4');
  rm.selectGame('h', 'reaction_tap');
  assert.strictEqual(rm.startGame('h').status, 'playing');
  srv.io.close(); srv.httpServer.close();
});

const connect = (port, n) => new Promise((res, rej) => {
  const s = io(`http://localhost:${port}`, { auth: { token: `dev:${n}:${n}` }, transports: ['websocket'], reconnection: false });
  s.once('connect', () => res(s)); s.once('connect_error', rej);
});
const emit = (s, ev, p) => new Promise(r => s.emit(ev, p, r));
const waitFor = (s, ev, pred = () => true) => new Promise(r => { const h = d => { if (pred(d)) { s.off(ev, h); r(d); } }; s.on(ev, h); });
let seq = 0;
const relay = (s, type, payload) => emit(s, 'game_action', { type: `relay:${type}`, payload, seq: ++seq });

test('Relay over sockets: guest input reaches the host, host state reaches everyone, results at the end', async t => {
  const srv = createServer();
  await new Promise(r => srv.httpServer.listen(0, r));
  const port = srv.httpServer.address().port;
  const [h, p, q] = await Promise.all(['h', 'p', 'q'].map(n => connect(port, n)));
  t.after(() => { [h, p, q].forEach(s => s.close()); srv.io.close(); srv.httpServer.close(); });

  const { room: r } = await emit(h, 'create_room', { gameType: 'reaction_tap', maxPlayers: 3 });
  for (const s of [p, q]) { await emit(s, 'join_room', { code: r.code }); await emit(s, 'player_ready'); }
  const first = waitFor(p, 'game_state');
  assert.ok((await emit(h, 'start_game')).ok);
  const st = await first;
  assert.strictEqual(st.relay, true); assert.strictEqual(st.host, 'h'); assert.strictEqual(st.state, null);

  const hostSees = waitFor(h, 'game_state', s => s.inputs.length === 1);
  assert.ok((await relay(p, 'input', { name: 'play', args: [42] })).ok);
  const hs = await hostSees;
  assert.deepStrictEqual(hs.inputs[0], { seq: 1, from: 'p', name: 'play', args: [42] });

  const guestSees = waitFor(q, 'game_state', s => s.version === 1);
  assert.ok((await relay(h, 'state', { state: { top: 'red 5' }, ack: 1 })).ok);
  assert.deepStrictEqual((await guestSees).state, { top: 'red 5' });

  const done = waitFor(q, 'game_finished');
  assert.ok((await relay(h, 'finish', { scores: [0, 1, 0] })).ok);
  const res = await done;
  assert.deepStrictEqual(res.winners, ['p']);
});

test('Relay over sockets: duplicates and rejected publications cannot corrupt the queue or snapshot', { timeout: 10000 }, async t => {
  const srv = createServer();
  const clients = [];
  t.after(() => { clients.forEach(s => s.close()); srv.io.close(); srv.httpServer.close(); });
  await new Promise(r => srv.httpServer.listen(0, r));
  const port = srv.httpServer.address().port;
  const h = await connect(port, 'atomic_h'); clients.push(h);
  const p = await connect(port, 'atomic_p'); clients.push(p);
  const created = await emit(h, 'create_room', { gameType: 'tic_tac_toe', maxPlayers: 2 });
  assert.ok(created.ok);
  assert.ok((await emit(p, 'join_room', { code: created.room.code })).ok);
  assert.ok((await emit(p, 'player_ready')).ok);
  assert.ok((await emit(h, 'start_game')).ok);
  const live = srv.rooms.get(created.room.code);
  const input = { type: 'relay:input', seq: 0, payload: { name: 'play', args: [1] } };
  assert.ok((await emit(p, 'game_action', input)).ok);
  assert.strictEqual((await emit(p, 'game_action', input)).error, 'DUPLICATE_ACTION');
  assert.strictEqual(live.game.inputSeq, 1);
  assert.strictEqual(live.game.inputs.length, 1);
  assert.ok((await emit(h, 'game_action', { type: 'relay:state', seq: 0, payload: { state: { turn: 0 }, ack: 0 } })).ok);
  const before = JSON.stringify(live.game);
  const rejected = { type: 'relay:state', seq: 100, payload: { state: { turn: 99 }, views: [], ack: 1 } };
  assert.strictEqual((await emit(h, 'game_action', rejected)).error, 'INVALID_PAYLOAD');
  assert.strictEqual(JSON.stringify(live.game), before);
  const accepted = { type: 'relay:state', seq: 1, payload: { state: { turn: 1 }, ack: 1 } };
  assert.ok((await emit(h, 'game_action', accepted)).ok, 'rejected high sequence does not block a valid lower one');
  const after = JSON.stringify(live.game);
  assert.strictEqual((await emit(h, 'game_action', accepted)).error, 'DUPLICATE_ACTION');
  assert.strictEqual(JSON.stringify(live.game), after);
  assert.strictEqual(live.game.version, 2);
  assert.deepStrictEqual(live.game.inputs, []);
  for (const seq of [-1, 0.5, Number.MAX_SAFE_INTEGER + 1, '2']) {
    assert.strictEqual((await emit(p, 'game_action', { ...input, seq })).error, 'INVALID_PAYLOAD');
    assert.strictEqual(JSON.stringify(live.game), after);
  }
});
