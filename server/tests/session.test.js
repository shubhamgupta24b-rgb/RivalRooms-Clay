const test = require('node:test');
const assert = require('node:assert');
const { io } = require('socket.io-client');
const { createServer } = require('../src/index');

/** A lobby with host h and [others], everyone ready. */
function lobby(game = 'tic_tac_toe', others = ['p'], maxPlayers = 6) {
  const srv = createServer();
  const rm = srv.rooms;
  rm.createRoom({ userId: 'h', username: 'H' }, { gameType: game, maxPlayers });
  const code = rm.roomOf('h').code;
  for (const u of others) { rm.joinRoom({ userId: u, username: u.toUpperCase() }, code); rm.setReady(u, true); }
  return { srv, rm, room: rm.roomOf('h'), close: () => { srv.io.close(); srv.httpServer.close(); } };
}
/** Ends a relay game with the given scores (players in join order). */
const registry = require('../src/games/registry');
const nitroTerminal = scores => ({
  time: 0, seats: scores.length, over: 1,
  karts: scores.map(score => [0, 0, 0, 0, 100, score, 1, 0, 0, 0, 0, 0]),
  shots: [], mines: [], crates: [], feed: null,
});
const finish = (rm, scores) => {
  const room = rm.roomOf('h');
  if (room.gameType === 'nitro_knockout') {
    rm.gameAction('h', { type: 'nitro:state', payload: { state: nitroTerminal(scores) }, seq: 0 });
    return rm.gameAction('h', { type: 'nitro:finish', payload: { scores }, seq: 1 });
  }
  if (registry.get(room.gameType).relay) return rm.gameAction('h', { type: 'relay:finish', payload: { scores }, seq: 0 });
  // Native games: end them the way the room does, with the same ranking.
  const ids = room.players.map(p => p.userId);
  const order = ids.map((u, i) => [u, scores[i]]).sort((a, b) => b[1] - a[1]);
  const ranking = order.map(([userId, score], i) => ({ userId, score, rank: order.findIndex(o => o[1] === score) + 1 }));
  room.status = 'finished';
  return { result: rm._ended(room, { ranking }) };
};

test('Session: host switches games in the lobby; guests cannot', () => {
  const { rm, room, close } = lobby();
  assert.throws(() => rm.selectGame('p', 'ludo'), e => e.code === 'NOT_HOST');
  assert.throws(() => rm.selectGame('h', 'nope'), e => e.code === 'INVALID_PAYLOAD');
  assert.throws(() => rm.selectGame('h', 'guess_person'), e => e.code === 'INVALID_PAYLOAD', 'quiz not offered');
  rm.selectGame('h', 'ludo');
  assert.strictEqual(room.gameType, 'ludo');
  assert.strictEqual(rm.publicRoom(room).gameType, 'ludo');
  assert.ok(rm.publicRoom(room).playable.includes('ludo'));
  assert.ok(!rm.publicRoom(room).playable.includes('raja_mantri'), 'needs 4 players');
  rm.startGame('h');
  assert.throws(() => rm.selectGame('h', 'tic_tac_toe'), e => e.code === 'BAD_PHASE', 'not mid-game');
  close();
});

test('Session: after a game the host starts the next one straight away, same room, players stay ready', () => {
  const { rm, room, close } = lobby();
  rm.startGame('h');
  assert.throws(() => rm.nextGame('h'), e => e.code === 'BAD_PHASE', 'game still running');
  finish(rm, [1, 0]);
  assert.strictEqual(room.status, 'finished');
  assert.throws(() => rm.nextGame('p'), e => e.code === 'NOT_HOST');
  rm.nextGame('h', 'connect_four');
  assert.strictEqual(room.status, 'playing');
  assert.strictEqual(room.gameType, 'connect_four');
  finish(rm, [0, 1]);
  rm.nextGame('h'); // play again
  assert.strictEqual(room.gameType, 'connect_four');
  finish(rm, [1, 1]);
  rm.returnToLobby('h');
  assert.ok(room.players.every(p => p.ready), 'nobody has to tap READY again');
  close();
});

test('Session: Nitro terminal result scores a party once and advances to the next game', () => {
  const { rm, room, close } = lobby('nitro_knockout');
  try {
    rm.startGame('h');
    room.party = { games: ['nitro_knockout', 'tic_tac_toe'], index: 0, totals: { h: 0, p: 0 }, lastPoints: null, done: false };
    const { result } = finish(rm, [1, 0]);
    assert.deepStrictEqual(result.party.totals, { h: 2, p: 1 });
    rm.markDisconnected('p'); rm.reconnect('p');
    assert.deepStrictEqual(room.party.totals, { h: 2, p: 1 });
    rm.nextGame('h');
    assert.strictEqual(room.gameType, 'tic_tac_toe');
    assert.strictEqual(room.party.index, 1);
  } finally { close(); }
});

test('Party: 5 random games that fit the room, points by place, running totals', () => {
  const { rm, room, close } = lobby('tic_tac_toe', ['p', 'q']);
  assert.throws(() => rm.startParty('p'), e => e.code === 'NOT_HOST');
  rm.startParty('h', 5);
  const party = room.party;
  assert.strictEqual(party.games.length, 5);
  assert.strictEqual(new Set(party.games).size, 5, 'no repeats');
  for (const g of party.games) assert.ok(rm.publicRoom(room).playable.includes(g), `${g} fits 3 players`);
  assert.ok(!party.games.includes('guess_person'));
  assert.strictEqual(room.status, 'playing');
  assert.strictEqual(room.gameType, party.games[0]);

  const results = [];
  rm.on('game_updated', (code, result) => { if (result) results.push(result); });
  for (let i = 0; i < 5; i++) {
    finish(rm, [1, 2, 0]); // p wins, h second, q last
    assert.strictEqual(party.index, i);
    if (i < 4) rm.nextGame('h', 'ignored_in_party');
  }
  assert.ok(party.done);
  assert.deepStrictEqual(party.totals, { p: 15, h: 10, q: 5 }, '3/2/1 points per game');
  assert.deepStrictEqual(party.lastPoints, { p: 3, h: 2, q: 1 });
  assert.throws(() => rm.nextGame('h'), e => e.code === 'BAD_PHASE', 'party over');
  rm.returnToLobby('h');
  assert.strictEqual(room.party, null);
  close();
});

test('Party: picking a game by hand ends the party', () => {
  const { rm, room, close } = lobby();
  rm.startParty('h', 3);
  finish(rm, [1, 0]);
  rm.returnToLobby('h');
  assert.strictEqual(room.party, null);
  rm.startParty('h', 3);
  close();
});

const connect = (port, n) => new Promise((res, rej) => {
  const s = io(`http://localhost:${port}`, { auth: { token: `dev:${n}:${n}` }, transports: ['websocket'], reconnection: false });
  s.once('connect', () => res(s)); s.once('connect_error', rej);
});
const emit = (s, ev, p) => new Promise(r => s.emit(ev, p, r));
const waitFor = (s, ev, pred = () => true) => new Promise(r => { const h = d => { if (pred(d)) { s.off(ev, h); r(d); } }; s.on(ev, h); });

test('Session over sockets: select a game, party results carry the standings, next game', async t => {
  const srv = createServer();
  await new Promise(r => srv.httpServer.listen(0, r));
  const port = srv.httpServer.address().port;
  const [h, p] = await Promise.all(['h', 'p'].map(n => connect(port, n)));
  t.after(() => { h.close(); p.close(); srv.io.close(); srv.httpServer.close(); });
  const { room } = await emit(h, 'create_room', { gameType: 'tic_tac_toe', maxPlayers: 4 });
  await emit(p, 'join_room', { code: room.code }); await emit(p, 'player_ready');

  const seen = waitFor(p, 'room_state', r => r.gameType === 'dots_boxes');
  assert.strictEqual((await emit(p, 'select_game', { gameType: 'ludo' })).error, 'NOT_HOST');
  assert.ok((await emit(h, 'select_game', { gameType: 'dots_boxes' })).ok);
  await seen;

  const started = waitFor(p, 'round_started');
  const r = await emit(h, 'start_party', { count: 2 });
  assert.ok(r.ok, JSON.stringify(r));
  assert.strictEqual(r.room.party.games.length, 2);
  await started;

  // Finish the first game (if it's a relay game the result is broadcast like a real one).
  const live = srv.rooms.roomOf('h');
  if (registry.get(live.gameType).relay) {
    const done = waitFor(p, 'game_finished');
    const isNitro = live.gameType === 'nitro_knockout';
    if (isNitro) assert.ok((await emit(h, 'game_action', { type: 'nitro:state', payload: { state: nitroTerminal([0, 1]) }, seq: 0 })).ok);
    assert.ok((await emit(h, 'game_action', { type: isNitro ? 'nitro:finish' : 'relay:finish', payload: { scores: [0, 1] }, seq: 1 })).ok);
    const res = await done;
    assert.deepStrictEqual(res.party.totals, { h: 1, p: 2 });
    assert.strictEqual(res.party.done, false);
    const next = await emit(h, 'next_game', {});
    assert.ok(next.ok, JSON.stringify(next));
    assert.strictEqual(next.room.party.index, 1);
  }
});
