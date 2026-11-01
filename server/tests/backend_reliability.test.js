const test = require('node:test');
const assert = require('node:assert/strict');
const { RoomManager } = require('../src/rooms/RoomManager');
const registry = require('../src/games/registry');
const { createRelayGame } = require('../src/games/relay');
const { attachSockets } = require('../src/sockets');
const { GameError } = require('../src/errors');

const user = userId => ({ userId, username: userId, avatar: null });
const codeIs = code => e => e instanceof GameError && e.code === code;

function lobby(t, ids = ['h', 'p'], gameType = 'reaction_tap', options) {
  const rm = new RoomManager(options);
  t.after(() => rm.close());
  const room = rm.createRoom(user(ids[0]), { gameType, maxPlayers: 6 });
  for (const id of ids.slice(1)) {
    rm.joinRoom(user(id), room.code);
    rm.setReady(id, true);
  }
  return { rm, room };
}

function clock(t) {
  const pending = new Map();
  t.mock.method(global, 'setTimeout', fn => {
    const timer = { unref() {} };
    pending.set(timer, () => { pending.delete(timer); fn(); });
    return timer;
  });
  t.mock.method(global, 'clearTimeout', timer => pending.delete(timer));
  return pending;
}

const action = (rm, uid, seq, type = 'relay:input', payload = { name: 'tap', args: [] }) =>
  rm.gameAction(uid, { seq, type, payload });

test('relay publication rejection preserves state, views, version and input queue', () => {
  const g = createRelayGame({ id: 'test', min: 2, max: 2 });
  const s = g.create({ hostId: 'h', players: [user('h'), user('p')] });
  const act = (type, payload) => g.onAction(s, 'h', { type, payload });
  act('relay:input', { name: 'tap', args: [1] });
  act('relay:state', { state: { turn: 0 }, views: [{ secret: 'h' }, { secret: 'p' }], ack: 0 });
  const before = JSON.stringify(s);
  const cyclic = {}; cyclic.self = cyclic;
  for (const payload of [
    { state: { turn: 1 }, views: [] },
    { state: { turn: 1 }, views: [{}, null] },
    { state: { turn: 1 }, views: [{}, { text: '界'.repeat(24000) }] },
    { state: { turn: 1 }, views: [{}, cyclic] },
    ...[-1, 2, 0.5, null, '1', Number.MAX_SAFE_INTEGER + 1].map(ack => ({ state: { turn: 1 }, ack })),
    { state: { text: '界'.repeat(24000) } },
    { state: cyclic },
  ]) {
    assert.throws(() => act('relay:state', payload), codeIs('INVALID_PAYLOAD'));
    assert.equal(JSON.stringify(s), before);
  }
  assert.deepEqual(g.getPublicState(s, 'p').state, { turn: 0, _seat: { secret: 'p' } });
  assert.deepEqual(g.getPublicState(s, 'p').inputs, []);
  assert.deepEqual(act('relay:state', { state: { turn: 1 }, ack: 1 }), { version: 2 });
  assert.equal(s.views, null);
  assert.equal(s.inputs.length, 0);
});

test('relay rejects oversized/non-finite inputs and unsafe or sparse scores without mutation', () => {
  const g = createRelayGame({ id: 'test', min: 2, max: 2 });
  const s = g.create({ hostId: 'h', players: [user('h'), user('p')] });
  const before = JSON.stringify(s);
  for (const args of [[Infinity], [NaN], ['界'.repeat(24000)], new Array(1)]) {
    assert.throws(() => g.onAction(s, 'p', { type: 'relay:input', payload: { name: 'tap', args } }), codeIs('INVALID_PAYLOAD'));
    assert.equal(JSON.stringify(s), before);
  }
  for (const scores of [[Number.MAX_SAFE_INTEGER + 1, 0], new Array(2)]) {
    assert.throws(() => g.onAction(s, 'h', { type: 'relay:finish', payload: { scores } }), codeIs('INVALID_PAYLOAD'));
    assert.equal(JSON.stringify(s), before);
  }
});

test('sequence validation is enforced by RoomManager; only accepted actions advance it', t => {
  const { rm, room } = lobby(t, ['__proto__', 'p']);
  rm.startGame('__proto__');
  for (const seq of [undefined, '0', -1, 0.5, NaN, Infinity, Number.MAX_SAFE_INTEGER + 1]) {
    assert.throws(() => action(rm, '__proto__', seq), codeIs('INVALID_PAYLOAD'));
  }
  assert.equal(room.game.inputSeq, 0);
  let updates = 0;
  rm.on('game_updated', () => updates++);
  assert.throws(() => action(rm, '__proto__', 100, 'relay:state', { state: {}, views: [] }), codeIs('INVALID_PAYLOAD'));
  assert.equal(room.seqs.__proto__, undefined);
  action(rm, '__proto__', 0);
  for (const seq of [0, 0]) assert.throws(() => action(rm, '__proto__', seq), codeIs('DUPLICATE_ACTION'));
  action(rm, '__proto__', 2);
  assert.throws(() => action(rm, '__proto__', 1), codeIs('DUPLICATE_ACTION'));
  assert.equal(room.game.inputSeq, 2);
  assert.equal(updates, 2);
  rm.markDisconnected('__proto__');
  rm.reconnect('__proto__');
  assert.throws(() => action(rm, '__proto__', 2), codeIs('DUPLICATE_ACTION'));
  rm.returnToLobby('__proto__');
  rm.startGame('__proto__');
  action(rm, '__proto__', 0);
  assert.equal(room.game.inputSeq, 1, 'sequence scope remains the current round');
});

test('repeated disconnects cannot leave a timer that evicts a reconnected player', t => {
  const pending = clock(t);
  const { rm, room } = lobby(t);
  rm.markDisconnected('p');
  const oldTimer = rm.timers.get('p');
  const expiredCallback = pending.get(oldTimer);
  rm.markDisconnected('p');
  assert.equal(rm.timers.get('p'), oldTimer);
  assert.equal(pending.size, 1);
  rm.reconnect('p');
  assert.equal(pending.size, 0);
  rm.markDisconnected('p');
  const newTimer = rm.timers.get('p');
  expiredCallback();
  assert.equal(rm.timers.get('p'), newTimer);
  assert.equal(rm.roomOf('p'), room);
  pending.get(newTimer)();
  assert.equal(rm.roomOf('p'), null);
  assert.equal(room.players.length, 1);
});

test('leaving cancels grace timers; stale callbacks cannot affect a new room; close clears ownership', t => {
  const pending = clock(t);
  const { rm, room } = lobby(t);
  rm.markDisconnected('p');
  const callback = pending.get(rm.timers.get('p'));
  rm.leave('p');
  assert.equal(pending.size, 0);
  const next = rm.createRoom(user('p'), { gameType: 'memory', maxPlayers: 2 });
  callback();
  assert.equal(rm.roomOf('p'), next);
  rm.markDisconnected('h');
  const last = pending.get(rm.timers.get('h'));
  last();
  assert.equal(rm.get(room.code), undefined);
  rm.markDisconnected('p');
  rm.close();
  assert.equal(pending.size, 0);
  assert.equal(rm.timers.size, 0);
  assert.equal(rm.userRoom.size, 0);
  assert.equal([...rm.store.values()].length, 0);
});

test('temporary relay-host disconnect preserves the game; permanent departure aborts without host migration', t => {
  const pending = clock(t);
  const { rm, room } = lobby(t, ['h', 'p', 'q']);
  rm.startGame('h');
  action(rm, 'h', 0, 'relay:state', { state: { turn: 1 } });
  const game = room.game;
  rm.markDisconnected('h');
  assert.equal(room.status, 'playing');
  rm.reconnect('h');
  assert.equal(room.game, game);
  assert.equal(game.host, 'h');
  let aborted = 0;
  rm.on('game_aborted', () => aborted++);
  rm.markDisconnected('h');
  pending.get(rm.timers.get('h'))();
  assert.equal(room.status, 'lobby');
  assert.equal(room.game, null);
  assert.equal(room.hostId, 'p');
  assert.equal(room.party, null);
  assert.equal(aborted, 1);
  rm.startGame('p');
  assert.equal(room.game.host, 'p');
  assert.deepEqual(room.game.players, ['p', 'q']);
});

test('permanent non-host departure also aborts fixed-roster native games', t => {
  const { rm, room } = lobby(t, ['h', 'p', 'q'], 'memory');
  rm.startGame('h');
  rm.leave('p');
  assert.equal(room.status, 'lobby');
  assert.equal(room.game, null);
  rm.startGame('h');
  assert.deepEqual(room.game.players, ['h', 'q']);
});

test('failed next round preserves completed game, readiness, party and sequence state', t => {
  const { rm, room } = lobby(t, ['h', 'p']);
  rm.startGame('h');
  action(rm, 'h', 0, 'relay:finish', { scores: [1, 0] });
  const before = JSON.stringify(room);
  assert.throws(() => rm.nextGame('h', 'raja_mantri'), codeIs('NOT_ENOUGH_PLAYERS'));
  assert.equal(JSON.stringify(room), before);
  rm.markDisconnected('p');
  const disconnected = JSON.stringify(room);
  assert.throws(() => rm.nextGame('h'), codeIs('PLAYERS_NOT_READY'));
  assert.equal(JSON.stringify(room), disconnected);
});

test('throwing plugin create leaves start and next-round transitions unchanged', t => {
  registry.register({
    id: 'test_create_failure', minPlayers: 2, maxPlayers: 6, implemented: true,
    create() { throw new GameError('INVALID_PAYLOAD'); },
    onAction() {}, getPublicState() {}, isFinished() { return false; }, getResult() {},
  });
  const { rm, room } = lobby(t, ['h', 'p'], 'test_create_failure');
  const before = JSON.stringify(room);
  assert.throws(() => rm.startGame('h'), codeIs('INVALID_PAYLOAD'));
  assert.equal(JSON.stringify(room), before);
  rm.selectGame('h', 'reaction_tap');
  rm.startGame('h');
  action(rm, 'h', 0, 'relay:finish', { scores: [1, 0] });
  const finished = JSON.stringify(room);
  assert.throws(() => rm.nextGame('h', 'test_create_failure'), codeIs('INVALID_PAYLOAD'));
  assert.equal(JSON.stringify(room), finished);
});

// Exercise the real socket handlers without opening a network listener.
function transport(rm) {
  let connection;
  const broadcasts = [];
  const io = {
    use() {},
    on(event, fn) { if (event === 'connection') connection = fn; },
    to(code) { return { emit(event, data) { broadcasts.push({ code, event, data }); } }; },
  };
  attachSockets(io, rm);
  const connect = (uid, id) => {
    const handlers = new Map(), sent = [], joined = new Set();
    const socket = {
      id, data: { user: user(uid) }, sent, joined, handlers,
      on(event, fn) { handlers.set(event, fn); },
      emit(event, data) { sent.push({ event, data }); },
      join(code) { joined.add(code); },
      leave(code) { joined.delete(code); },
      disconnect() { joined.clear(); handlers.get('disconnect')?.(); },
    };
    connection(socket);
    return socket;
  };
  const emit = (socket, event, payload) => new Promise(resolve => socket.handlers.get(event)(payload, resolve));
  return { connect, emit, broadcasts };
}

test('replacement socket owns the seat; old handlers cannot mutate or disconnect it', async t => {
  const { rm, room } = lobby(t);
  const { connect, emit } = transport(rm);
  const old = connect('h', 'old');
  const current = connect('h', 'new');
  assert.equal((await emit(old, 'leave_room')).error, 'SESSION_REPLACED');
  old.handlers.get('disconnect')();
  assert.equal(rm.roomOf('h'), room);
  assert.equal(room.players[0].connected, true);
  assert.equal(rm.timers.size, 0);
  assert.ok(current.joined.has(room.code));
  assert.ok(current.sent.some(x => x.event === 'room_state' && x.data.code === room.code));
  assert.equal((await emit(current, 'resume_session')).room.code, room.code);
});

test('reconnect sends the finished result and standings without awarding party points again', t => {
  const { rm, room } = lobby(t);
  rm.startGame('h');
  room.party = { games: ['reaction_tap', 'memory'], index: 0, totals: { h: 0, p: 0 }, lastPoints: null, done: false };
  action(rm, 'h', 0, 'relay:finish', { scores: [1, 0] });
  const totals = { ...room.party.totals };
  const { connect } = transport(rm);
  const host = connect('h', 'host');
  const player = connect('p', 'player');
  for (const socket of [host, player]) {
    assert.ok(socket.sent.some(x => x.event === 'game_state' && x.data.finished));
    const finished = socket.sent.find(x => x.event === 'game_finished').data;
    assert.deepEqual(finished.winners, ['h']);
    assert.deepEqual(finished.party.totals, totals);
  }
  assert.deepEqual(room.party.totals, totals);
});
