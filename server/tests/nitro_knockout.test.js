// Adapted from the reference archive tests, with terminal/result and lifecycle regressions.
const test = require('node:test');
const assert = require('node:assert/strict');
const { io } = require('socket.io-client');
const { createServer } = require('../src/index');
const { RoomManager } = require('../src/rooms/RoomManager');
const registry = require('../src/games/registry');
const { game: nitro, validateSnapshot, validInputArgs } = require('../src/games/nitro_knockout');

const user = userId => ({ userId, username: userId.toUpperCase() });
const room = (n, hostId = 'a') => ({ hostId, players: 'abcdefghijk'.slice(0, n).split('').map(user) });
const act = (s, uid, type, payload) => nitro.onAction(s, uid, { type, payload });
const codeIs = code => e => e.code === code;
const snapshot = (overrides = {}) => ({
  time: 90000, seats: 3, over: 0,
  karts: [
    [1000, 0, -2000, 157, 100, 0, 1, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 85, 2, 1, 1, 12, 0, 100, 50],
    [-30000, 500, 30000, -314, 40, 1, 0, 5, 1, 100, 0, 0],
  ],
  shots: [[5000, 500, 5000, 20000, 0, 0]], mines: [[-1000, 1000, 1]],
  crates: [1, 0, 1, 1, 0, 0], feed: null, ...overrides,
});
const terminal = scores => snapshot({ time: 0, over: 1, karts: snapshot().karts.map((r, i) => r.map((n, j) => j === 5 ? scores[i] : n)) });

function rejectUnchanged(s, uid, type, payload, code = 'INVALID_PAYLOAD') {
  const before = JSON.stringify(s);
  assert.throws(() => act(s, uid, type, payload), codeIs(code));
  assert.equal(JSON.stringify(s), before);
}

test('Nitro: dedicated registry entry and exactly 2-10 human seats', () => {
  assert.equal(registry.get('nitro_knockout'), nitro);
  assert.deepEqual([nitro.minPlayers, nitro.maxPlayers, nitro.relay], [2, 10, true]);
  assert.throws(() => nitro.create(room(1)), codeIs('NOT_ENOUGH_PLAYERS'));
  assert.throws(() => nitro.create(room(11)), codeIs('TOO_MANY_PLAYERS'));
  for (let n = 2; n <= 10; n++) {
    const s = nitro.create(room(n));
    assert.equal(s.seats, n);
    assert.equal(s.players.length, n);
    assert.equal(s.host, 'a');
  }
  assert.equal(nitro.create(room(3, 'absent')).host, 'a');
});

test('Nitro: host-only snapshots, fixed roster, dedicated action namespace', () => {
  const s = nitro.create(room(3));
  rejectUnchanged(s, 'b', 'nitro:state', { state: snapshot() }, 'NOT_HOST');
  rejectUnchanged(s, 'outsider', 'nitro:state', { state: snapshot() }, 'NOT_IN_GAME');
  rejectUnchanged(s, 'a', 'nitro:state', { state: snapshot({ seats: 4 }) });
  for (const type of ['relay:state', 'relay:finish', 'unknown']) rejectUnchanged(s, 'a', type, {}, 'INVALID_ACTION');
  assert.deepEqual(act(s, 'a', 'nitro:state', { state: snapshot() }), { version: 1 });
  const pub = nitro.getPublicState(s, 'b');
  assert.equal(pub.nitro, true);
  assert.equal(pub.state.seats, 3);
  assert.equal(pub.karts, undefined);
});

test('Nitro: snapshot shapes, dense integers, bounds and serialization are validated atomically', () => {
  const s = nitro.create(room(3));
  act(s, 'b', 'nitro:input', { args: [100, 0, 0, 0] });
  act(s, 'a', 'nitro:state', { state: snapshot() });
  const kart = (index, value) => snapshot({ karts: snapshot().karts.map((r, i) => i ? r : r.map((n, j) => j === index ? value : n)) });
  const cyclic = snapshot(); cyclic.self = cyclic;
  const invalid = [
    undefined, null, [], {}, cyclic, snapshot({ extra: '界'.repeat(12000) }), snapshot({ extra: true }),
    ...[-1, 90001, 1.5, NaN, Infinity].map(time => snapshot({ time })),
    snapshot({ over: 2 }), snapshot({ over: 1 }), snapshot({ seats: '3' }),
    snapshot({ karts: new Array(3) }), snapshot({ karts: snapshot().karts.slice(1) }),
    snapshot({ karts: [new Array(12), ...snapshot().karts.slice(1)] }),
    snapshot({ karts: [new Array(13).fill(0), ...snapshot().karts.slice(1)] }),
    kart(0, 90001), kart(1, -10001), kart(2, Infinity), kart(3, 1.5), kart(3, 1000001),
    kart(4, 101), kart(4, -1), kart(5, 1.5), kart(5, -1), kart(5, 100001), kart(6, 2),
    kart(7, 6), kart(8, 100), kart(9, -1), kart(10, 10001), kart(11, NaN),
    snapshot({ shots: new Array(65).fill([0, 0, 0, 0, 0, 0]) }), snapshot({ shots: new Array(1) }),
    snapshot({ shots: [[0, 0, 0, 0, 0, 5]] }), snapshot({ shots: [[90001, 0, 0, 0, 0, 0]] }),
    snapshot({ shots: [[0, 0, 0, 100001, 0, 0]] }), snapshot({ shots: [[0, 0, 0, 0, 0]] }),
    snapshot({ mines: new Array(13).fill([0, 0, 0]) }), snapshot({ mines: new Array(1) }),
    snapshot({ mines: [[0, 0, 3]] }), snapshot({ mines: [[0, 0, -2]] }), snapshot({ mines: [[0, 90001, 0]] }),
    snapshot({ crates: [1, 2] }), snapshot({ crates: new Array(1) }), snapshot({ crates: new Array(33).fill(0) }),
    snapshot({ feed: ['a'] }), snapshot({ feed: new Array(2) }), snapshot({ feed: ['x'.repeat(25), 'b'] }),
  ];
  for (const state of invalid) rejectUnchanged(s, 'a', 'nitro:state', { state, ack: 1 });
  const valid = kart(1, -6000); // disabled fallen kart, retained until respawn
  valid.feed = ['NOVA', 'BOLT'];
  act(s, 'a', 'nitro:state', { state: valid, ack: 1 });
  assert.equal(s.inputs.length, 0);
  assert.equal(s.version, 2);
});

test('Nitro: guest tuples are bounded, owned, silent, and host-private; queue caps at 200', () => {
  const s = nitro.create(room(3));
  for (const args of [
    [101, 0, 0, 0], [-101, 0, 0, 0], [1.5, 0, 0, 0], ['100', 0, 0, 0],
    [0, 101, 0, 0], [0, 0, 2, 0], [0, 0, 0, -1], [0, 0, 0, 1000001],
    [0, NaN, 0, 0], new Array(4), 'no', [], [1, 2, 3], [1, 2, 3, 4, 5],
  ]) rejectUnchanged(s, 'b', 'nitro:input', { args });
  rejectUnchanged(s, 'outsider', 'nitro:input', { args: [0, 0, 0, 0] }, 'NOT_IN_GAME');
  const args = [100, -40, 1, 1];
  assert.deepEqual(act(s, 'b', 'nitro:input', { args }), { seq: 1, silent: true });
  args[0] = 999;
  assert.equal(s.inputs[0].args[0], 100);
  assert.equal(s.inputs[0].from, 'b');
  assert.equal(nitro.getPublicState(s, 'a').inputs.length, 1);
  assert.deepEqual(nitro.getPublicState(s, 'b').inputs, []);
  for (let i = 0; i < 250; i++) act(s, 'c', 'nitro:input', { args: [0, 0, 0, 0] });
  assert.equal(s.inputs.length, 200);
  assert.equal(s.inputs[0].seq, 52);
  assert.equal(s.version, 0);
});

test('Nitro: invalid ack never publishes or consumes inputs; repeated/older ack cannot resurrect them', () => {
  const s = nitro.create(room(3));
  act(s, 'b', 'nitro:input', { args: [0, 0, 0, 0] });
  act(s, 'a', 'nitro:state', { state: snapshot() });
  for (const ack of [-1, 2, 0.5, null, '1', NaN, Infinity, Number.MAX_SAFE_INTEGER + 1]) {
    rejectUnchanged(s, 'a', 'nitro:state', { state: snapshot({ time: 89000 }), ack });
  }
  act(s, 'a', 'nitro:state', { state: snapshot(), ack: 1 });
  act(s, 'c', 'nitro:input', { args: [0, 0, 0, 0] });
  for (const ack of [1, 0, 1]) act(s, 'a', 'nitro:state', { state: snapshot(), ack });
  assert.deepEqual(s.inputs.map(i => i.seq), [2]);
});

test('Nitro: accepted snapshots own their data and cannot rewind time, scores or terminal status', () => {
  const s = nitro.create(room(3));
  const state = snapshot({ time: 80000 });
  act(s, 'a', 'nitro:state', { state });
  state.time = 90000; state.karts[1][5] = 99;
  assert.equal(s.state.time, 80000);
  assert.equal(s.state.karts[1][5], 2);
  rejectUnchanged(s, 'a', 'nitro:state', { state: snapshot() });
  rejectUnchanged(s, 'a', 'nitro:state', { state: snapshot({ time: 79000, crates: [] }) });
  const reset = snapshot({ time: 79000 }); reset.karts[1][5] = 1;
  rejectUnchanged(s, 'a', 'nitro:state', { state: reset });
  act(s, 'a', 'nitro:state', { state: terminal([7, 3, 3]) });
  rejectUnchanged(s, 'a', 'nitro:state', { state: terminal([8, 3, 3]) });
  rejectUnchanged(s, 'a', 'nitro:state', { state: snapshot({ time: 0 }) });
  rejectUnchanged(s, 'b', 'nitro:input', { args: [0, 0, 0, 0] }, 'BAD_PHASE');
});

test('Nitro: finish requires matching terminal snapshot; result is derived once with tied ranks', () => {
  const s = nitro.create(room(3));
  rejectUnchanged(s, 'a', 'nitro:finish', { scores: [7, 3, 3] });
  act(s, 'a', 'nitro:state', { state: snapshot() });
  rejectUnchanged(s, 'a', 'nitro:finish', { scores: [0, 2, 1] });
  act(s, 'a', 'nitro:state', { state: terminal([7, 3, 3]) });
  rejectUnchanged(s, 'b', 'nitro:finish', { scores: [7, 3, 3] }, 'NOT_HOST');
  for (const scores of [[7, 3], [7, 3.5, 3], [-1, 0, 0], [8, 3, 3], new Array(3)]) {
    rejectUnchanged(s, 'a', 'nitro:finish', { scores });
  }
  act(s, 'a', 'nitro:finish', { scores: [7, 3, 3] });
  assert.equal(nitro.isFinished(s), true);
  assert.deepEqual(s.scores, { a: 7, b: 3, c: 3 });
  assert.deepEqual(nitro.getResult(s).ranking.map(r => [r.userId, r.rank]), [['a', 1], ['b', 2], ['c', 2]]);
  assert.deepEqual(nitro.getResult(s).winners, ['a']);
  for (const type of ['nitro:input', 'nitro:state', 'nitro:finish']) rejectUnchanged(s, 'a', type, {}, 'BAD_PHASE');
  const tied = nitro.create(room(3));
  act(tied, 'a', 'nitro:state', { state: terminal([10, 10, 4]) });
  act(tied, 'a', 'nitro:finish', { scores: [10, 10, 4] });
  assert.deepEqual(nitro.getResult(tied).ranking.map(r => r.rank), [1, 1, 3]);
  assert.deepEqual(nitro.getResult(tied).winners, ['a', 'b']);
});

test('Nitro: standalone validators and special identity keys', () => {
  assert.equal(validInputArgs([100, -100, 1, 0]), true);
  assert.equal(validInputArgs([100.5, 0, 0, 0]), false);
  assert.equal(validateSnapshot({ state: snapshot() }, 3).seats, 3);
  assert.throws(() => validateSnapshot({ state: snapshot() }, 2));
  const s = nitro.create({ hostId: '__proto__', players: ['__proto__', 'constructor', 'toString'].map(user) });
  act(s, '__proto__', 'nitro:state', { state: terminal([1, 2, 2]) });
  act(s, '__proto__', 'nitro:finish', { scores: [1, 2, 2] });
  assert.deepEqual(nitro.getResult(s).winners, ['constructor', 'toString']);
});

function playing(t, n = 3) {
  const rm = new RoomManager();
  t.after(() => rm.close());
  const r = rm.createRoom(user('a'), { gameType: 'nitro_knockout', maxPlayers: 10 });
  for (const p of room(n).players.slice(1)) { rm.joinRoom(p, r.code); rm.setReady(p.userId, true); }
  rm.startGame('a');
  return { rm, r, action: (uid, seq, type, payload) => rm.gameAction(uid, { seq, type, payload }) };
}

test('Nitro: silent input consumes accepted sequence only and publishes on next host frame', t => {
  const { rm, r, action } = playing(t);
  let updates = 0, changes = 0;
  rm.on('game_updated', () => updates++); rm.on('room_changed', () => changes++);
  assert.throws(() => action('b', 100, 'nitro:input', { args: [101, 0, 0, 0] }), codeIs('INVALID_PAYLOAD'));
  action('b', 0, 'nitro:input', { args: [80, 0, 0, 0] });
  assert.throws(() => action('b', 0, 'nitro:input', { args: [80, 0, 0, 0] }), codeIs('DUPLICATE_ACTION'));
  assert.deepEqual([updates, changes, r.game.inputs.length], [0, 0, 1]);
  action('a', 0, 'nitro:state', { state: snapshot() });
  assert.deepEqual([updates, changes], [1, 1]);
});

test('Nitro: temporary host/guest disconnect preserves progress; permanent departure explicitly aborts', t => {
  const pending = new Map();
  t.mock.method(global, 'setTimeout', fn => { const timer = { unref() {} }; pending.set(timer, fn); return timer; });
  t.mock.method(global, 'clearTimeout', timer => pending.delete(timer));
  const { rm, r, action } = playing(t);
  action('a', 0, 'nitro:state', { state: snapshot({ time: 60000 }) });
  const game = r.game;
  for (const uid of ['a', 'b']) {
    rm.markDisconnected(uid); const stale = pending.get(rm.timers.get(uid));
    rm.reconnect(uid); stale();
    assert.equal(r.game, game);
    assert.equal(r.game.host, 'a');
    assert.equal(r.game.state.time, 60000);
    assert.equal(r.game.version, 1);
    assert.equal(rm.timers.size, 0);
  }
  let aborts = 0; rm.on('game_aborted', () => aborts++);
  rm.markDisconnected('a'); pending.get(rm.timers.get('a'))();
  assert.equal(r.hostId, 'b');
  assert.equal(r.status, 'lobby');
  assert.equal(r.game, null);
  assert.equal(r.party, null);
  assert.equal(aborts, 1);
  rm.startGame('b');
  assert.equal(r.game.host, 'b');
  assert.deepEqual(r.game.players, ['b', 'c']);
  assert.equal(r.game.state, null, 'new match is explicit, never disguised as migration');
  rm.leave('c');
  assert.equal(r.status, 'lobby');
  assert.equal(aborts, 2);
});

test('Nitro: completed rematch starts fresh and failed next game preserves completed result', t => {
  const { rm, r, action } = playing(t);
  action('a', 0, 'nitro:state', { state: terminal([7, 3, 3]) });
  action('a', 1, 'nitro:finish', { scores: [7, 3, 3] });
  const before = JSON.stringify(r);
  assert.throws(() => rm.nextGame('a', 'ludo_teams'), codeIs('NOT_ENOUGH_PLAYERS'));
  assert.equal(JSON.stringify(r), before);
  rm.nextGame('a');
  assert.deepEqual([r.status, r.game.version, r.game.inputSeq, r.game.state], ['playing', 0, 0, null]);
  assert.equal(Object.keys(r.seqs).length, 0);
});

test('Nitro: room capacity accepts 2-10 and other games still enforce their own seat limits', t => {
  const rm = new RoomManager(); t.after(() => rm.close());
  for (let n = 2; n <= 10; n++) {
    const r = rm.createRoom(user('a'), { gameType: 'nitro_knockout', maxPlayers: n });
    assert.equal(r.maxPlayers, n); rm.leave('a');
  }
  for (const maxPlayers of [1, 11, 7.5, '10', null, NaN]) {
    assert.throws(() => rm.createRoom(user('a'), { gameType: 'nitro_knockout', maxPlayers }), codeIs('INVALID_PAYLOAD'));
  }
  const { rm: large, r } = playing(t, 10);
  large.returnToLobby('a'); large.selectGame('a', 'memory');
  assert.throws(() => large.startGame('a'), codeIs('TOO_MANY_PLAYERS'));
  assert.equal(r.status, 'lobby');
});

// Real Socket.IO transport, not a mocked action pipeline. Bound every wait and ack.
const waitFor = (socket, event, predicate = () => true) => new Promise((resolve, reject) => {
  const timer = setTimeout(() => { socket.off(event, handler); reject(new Error(`timeout: ${event}`)); }, 4000);
  const handler = value => { if (predicate(value)) { clearTimeout(timer); socket.off(event, handler); resolve(value); } };
  socket.on(event, handler);
});

test('Nitro: ten-human online lifecycle, private queue, reconnect, terminal finish and rematch', { timeout: 20000 }, async t => {
  const srv = createServer({ graceMs: 60000 });
  const clients = [];
  t.after(() => { clients.forEach(s => s.close()); srv.io.close(); srv.httpServer.close(); });
  await new Promise(resolve => srv.httpServer.listen(0, resolve));
  const connect = async name => {
    const socket = io(`http://localhost:${srv.httpServer.address().port}`, {
      auth: { token: `dev:${name}:${name}` }, transports: ['websocket'], reconnection: false,
    });
    clients.push(socket);
    await new Promise((resolve, reject) => {
      const timer = setTimeout(() => done(new Error('timeout: connect')), 4000);
      const done = error => {
        clearTimeout(timer); socket.off('connect', ready); socket.off('connect_error', done);
        if (error) reject(error); else resolve();
      };
      const ready = () => done();
      socket.once('connect', ready); socket.once('connect_error', done);
    });
    return socket;
  };
  const emit = (socket, event, payload = {}) => socket.timeout(4000).emitWithAck(event, payload);
  const sockets = await Promise.all('abcdefghij'.split('').map(connect));
  let h = sockets[0];
  const created = await emit(h, 'create_room', { gameType: 'nitro_knockout', maxPlayers: 10 });
  assert.equal(created.ok, true, created.error);
  const code = created.room.code;
  // Serial joins make the human seat order deterministic.
  for (const s of sockets.slice(1)) assert.equal((await emit(s, 'join_room', { code })).ok, true);
  const extra = await connect('k');
  assert.equal((await emit(extra, 'join_room', { code })).error, 'ROOM_FULL');
  assert.equal((await emit(h, 'join_room', { code })).error, 'ALREADY_IN_ROOM');
  await Promise.all(sockets.slice(1).map(s => emit(s, 'player_ready')));
  assert.equal((await emit(h, 'start_game')).ok, true);
  const snap = snapshot({ seats: 10, karts: Array.from({ length: 10 }, (_, i) => [i * 1000, 0, 0, 0, 100, 0, 1, 0, 0, 0, 0, 0]) });
  const states = Promise.all(sockets.map(s => waitFor(s, 'game_state', d => d.version === 1)));
  assert.equal((await emit(h, 'game_action', { type: 'nitro:state', payload: { state: snap }, seq: 0 })).ok, true);
  for (const state of await states) { assert.equal(state.nitro, true); assert.equal(state.state.seats, 10); }
  assert.equal((await emit(sockets[1], 'game_action', { type: 'nitro:state', payload: { state: snap }, seq: 99 })).error, 'NOT_HOST');
  assert.equal((await emit(sockets[1], 'game_action', { type: 'nitro:input', payload: { args: [80, -20, 0, 1] }, seq: 0 })).ok, true);
  const next = Promise.all([waitFor(h, 'game_state', d => d.version === 2), waitFor(sockets[2], 'game_state', d => d.version === 2)]);
  await emit(h, 'game_action', { type: 'nitro:state', payload: { state: snap }, seq: 1 });
  const [hostState, guestState] = await next;
  assert.deepEqual(hostState.inputs.map(i => i.from), ['b']);
  assert.deepEqual(guestState.inputs, []);

  const disconnected = waitFor(h, 'player_disconnected', p => p.userId === 'b');
  sockets[1].disconnect(); await disconnected;
  // Reconnect events are emitted immediately after connect; subscribe first.
  const returning = io(`http://localhost:${srv.httpServer.address().port}`, {
    autoConnect: false, auth: { token: 'dev:b:b' }, transports: ['websocket'], reconnection: false,
  });
  clients.push(returning);
  const resumedState = waitFor(returning, 'game_state'); returning.connect();
  const resumed = await resumedState;
  assert.equal(resumed.version, 2);
  assert.equal(resumed.state.time, 90000);
  assert.equal((await emit(returning, 'game_action', { type: 'nitro:input', payload: { args: [0, 0, 0, 0] }, seq: 0 })).error, 'DUPLICATE_ACTION');

  const gameBeforeReconnect = srv.rooms.get(code).game;
  const hostDisconnected = waitFor(returning, 'player_disconnected', p => p.userId === 'a');
  h.disconnect(); await hostDisconnected;
  h = io(`http://localhost:${srv.httpServer.address().port}`, {
    autoConnect: false, auth: { token: 'dev:a:a' }, transports: ['websocket'], reconnection: false,
  });
  clients.push(h);
  const hostResumed = waitFor(h, 'game_state'); h.connect();
  const hostResumeState = await hostResumed;
  assert.equal(hostResumeState.version, 2);
  assert.equal(hostResumeState.host, 'a');
  assert.deepEqual(hostResumeState.inputs.map(i => i.from), ['b']);
  assert.equal(srv.rooms.get(code).game, gameBeforeReconnect);
  assert.equal((await emit(h, 'game_action', { type: 'nitro:state', payload: { state: snap }, seq: 1 })).error, 'DUPLICATE_ACTION');
  assert.equal((await emit(h, 'game_action', { type: 'nitro:finish', payload: { scores: new Array(10).fill(0) }, seq: 100 })).error, 'INVALID_PAYLOAD');
  const scores = [9, ...new Array(9).fill(0)];
  const final = { ...snap, time: 0, over: 1, karts: snap.karts.map((r, i) => r.map((n, j) => j === 5 ? scores[i] : n)) };
  assert.equal((await emit(h, 'game_action', { type: 'nitro:state', payload: { state: final, ack: 1 }, seq: 2 })).ok, true);
  const finished = waitFor(sockets[3], 'game_finished');
  assert.equal((await emit(h, 'game_action', { type: 'nitro:finish', payload: { scores }, seq: 3 })).ok, true);
  const result = await finished;
  assert.deepEqual(result.winners, ['a']); assert.equal(result.ranking.length, 10);
  assert.equal((await emit(h, 'next_game')).ok, true);
  assert.equal(srv.rooms.get(code).game.version, 0);
  assert.equal((await emit(h, 'return_to_lobby')).ok, true);
  assert.equal((await emit(h, 'start_game')).ok, true);
});
