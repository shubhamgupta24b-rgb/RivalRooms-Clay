const { GameError } = require('../errors');

// Adapted from the Nitro reference archive. Rapier runs on the host phone, NOT
// on this server. These checks constrain the wire contract and result consistency;
// they cannot prove legal physics, honest scores, or that inputs were applied.
const MAX_STATE_BYTES = 32 * 1024;
const MAX_QUEUE = 200;
const MIN_SEATS = 2, MAX_SEATS = 10;
const ARENA_MM = 90000;
const MAX_TIME_MS = 90000;
const MAX_SCORE = 100000;
const int = Number.isSafeInteger;
const denseEvery = (a, check) => Array.from(a).every(check);
const bit = n => n === 0 || n === 1;
const position = (x, y, z) => Math.abs(x) <= ARENA_MM && Math.abs(z) <= ARENA_MM && y >= -10000 && y <= ARENA_MM;

// [x,y,z,yaw,hp,score,alive,weapon,ammo,shield,boost,invuln], all quantized integers.
function validKartRow(row) {
  if (!Array.isArray(row) || row.length !== 12 || !denseEvery(row, int)) return false;
  const [x, y, z, yaw, hp, score, alive, weapon, ammo, shield, boost, invuln] = row;
  // Fallen karts are disabled below y=-5 until respawn; -2 rejects real frames.
  return position(x, y, z) && Math.abs(yaw) <= 1000000 && hp >= 0 && hp <= 100
    && score >= 0 && score <= MAX_SCORE && bit(alive)
    && weapon >= 0 && weapon <= 5 && ammo >= 0 && ammo <= 99
    && [shield, boost, invuln].every(n => n >= 0 && n <= 10000);
}

function validateSnapshot(p, seats) {
  const s = p && p.state;
  if (!s || typeof s !== 'object' || Array.isArray(s)) throw new GameError('INVALID_PAYLOAD');
  let json;
  try { json = JSON.stringify(s); }
  catch { throw new GameError('INVALID_PAYLOAD', 'state must be JSON serializable'); }
  if (typeof json !== 'string' || Buffer.byteLength(json, 'utf8') > MAX_STATE_BYTES) {
    throw new GameError('INVALID_PAYLOAD', 'state too large');
  }
  const keys = ['time', 'seats', 'over', 'karts', 'shots', 'mines', 'crates', 'feed'];
  if (Object.keys(s).some(k => !keys.includes(k))) throw new GameError('INVALID_PAYLOAD', 'unknown snapshot field');
  if (!int(s.time) || s.time < 0 || s.time > MAX_TIME_MS) throw new GameError('INVALID_PAYLOAD', 'bad time');
  if (!bit(s.over) || (s.over === 1 && s.time !== 0)) throw new GameError('INVALID_PAYLOAD', 'bad over flag');
  if (!int(s.seats) || s.seats !== seats) throw new GameError('INVALID_PAYLOAD', 'seat count mismatch');
  if (!Array.isArray(s.karts) || s.karts.length !== seats || !denseEvery(s.karts, validKartRow)) {
    throw new GameError('INVALID_PAYLOAD', 'bad karts');
  }
  if (!Array.isArray(s.shots) || s.shots.length > 64 || !denseEvery(s.shots, shot =>
    Array.isArray(shot) && shot.length === 6 && denseEvery(shot, int)
    && position(shot[0], shot[1], shot[2]) && Math.abs(shot[3]) <= 100000
    && Math.abs(shot[4]) <= 100000 && bit(shot[5]))) throw new GameError('INVALID_PAYLOAD', 'bad shots');
  if (!Array.isArray(s.mines) || s.mines.length > 12 || !denseEvery(s.mines, mine =>
    Array.isArray(mine) && mine.length === 3 && denseEvery(mine, int)
    && Math.abs(mine[0]) <= ARENA_MM && Math.abs(mine[1]) <= ARENA_MM
    && mine[2] >= -1 && mine[2] < seats)) throw new GameError('INVALID_PAYLOAD', 'bad mines');
  if (!Array.isArray(s.crates) || s.crates.length > 32 || !denseEvery(s.crates, bit)) {
    throw new GameError('INVALID_PAYLOAD', 'bad crates');
  }
  if (s.feed != null && (!Array.isArray(s.feed) || s.feed.length !== 2
    || !denseEvery(s.feed, n => typeof n === 'string' && n.length <= 24))) {
    throw new GameError('INVALID_PAYLOAD', 'bad feed');
  }
  // Own the accepted data: callers cannot change a validated terminal frame later.
  return {
    time: s.time, seats: s.seats, over: s.over,
    karts: s.karts.map(r => [...r]), shots: s.shots.map(r => [...r]), mines: s.mines.map(r => [...r]),
    crates: [...s.crates], feed: s.feed == null ? null : [...s.feed],
  };
}

function validInputArgs(args) {
  if (!Array.isArray(args) || args.length !== 4 || !denseEvery(args, int)) return false;
  const [throttle, steer, drift, fire] = args;
  return throttle >= -100 && throttle <= 100 && steer >= -100 && steer <= 100
    && bit(drift) && fire >= 0 && fire <= 1000000;
}

const game = {
  id: 'nitro_knockout', minPlayers: MIN_SEATS, maxPlayers: MAX_SEATS, implemented: true, relay: true,

  create(room) {
    if (room.players.length < MIN_SEATS) throw new GameError('NOT_ENOUGH_PLAYERS');
    if (room.players.length > MAX_SEATS) throw new GameError('TOO_MANY_PLAYERS');
    const players = room.players.map(p => p.userId);
    return {
      players, names: Object.fromEntries(room.players.map(p => [p.userId, p.username])),
      host: players.includes(room.hostId) ? room.hostId : players[0], seats: players.length,
      state: null, version: 0, inputs: [], inputSeq: 0, finished: false, scores: null,
    };
  },

  onAction(s, uid, { type, payload }) {
    if (!s.players.includes(uid)) throw new GameError('NOT_IN_GAME');
    if (s.finished) throw new GameError('BAD_PHASE');
    const p = payload || {};
    if (type === 'nitro:state') {
      if (uid !== s.host) throw new GameError('NOT_HOST');
      const state = validateSnapshot(p, s.seats);
      if (p.ack !== undefined && (!int(p.ack) || p.ack < 0 || p.ack > s.inputSeq)) {
        throw new GameError('INVALID_PAYLOAD', 'bad acknowledgement');
      }
      if (s.state && (state.time > s.state.time || state.over < s.state.over
        || state.crates.length !== s.state.crates.length
        || state.karts.some((r, i) => r[5] < s.state.karts[i][5]
          || (s.state.over === 1 && r[5] !== s.state.karts[i][5])))) {
        throw new GameError('INVALID_PAYLOAD', 'snapshot resets match progress');
      }
      // Commit only after the whole publication and acknowledgement validate.
      s.state = state;
      s.version++;
      if (p.ack !== undefined) s.inputs = s.inputs.filter(i => i.seq > p.ack);
      return { version: s.version };
    }
    if (type === 'nitro:input') {
      if (s.state?.over === 1) throw new GameError('BAD_PHASE');
      if (!validInputArgs(p.args)) throw new GameError('INVALID_PAYLOAD');
      s.inputs.push({ seq: ++s.inputSeq, from: uid, args: [...p.args] });
      if (s.inputs.length > MAX_QUEUE) s.inputs.splice(0, s.inputs.length - MAX_QUEUE);
      return { seq: s.inputSeq, silent: true };
    }
    if (type === 'nitro:finish') {
      if (uid !== s.host) throw new GameError('NOT_HOST');
      const scores = p.scores;
      if (!Array.isArray(scores) || scores.length !== s.seats
        || !denseEvery(scores, n => int(n) && n >= 0 && n <= MAX_SCORE)) throw new GameError('INVALID_PAYLOAD');
      if (!s.state || s.state.over !== 1 || s.state.time !== 0
        || scores.some((n, i) => n !== s.state.karts[i][5])) {
        throw new GameError('INVALID_PAYLOAD', 'scores must match the terminal snapshot');
      }
      // Derive the result from the validated frame, not a second host score source.
      s.scores = Object.fromEntries(s.players.map((u, i) => [u, s.state.karts[i][5]]));
      s.finished = true;
      return {};
    }
    throw new GameError('INVALID_ACTION');
  },

  getPublicState(s, uid) {
    return {
      gameType: 'nitro_knockout', relay: true, nitro: true, host: s.host, seats: s.seats,
      players: s.players.map(u => ({ userId: u, username: s.names[u] })),
      state: s.state, version: s.version, inputs: uid === s.host ? s.inputs : [], finished: s.finished,
    };
  },
  isFinished: s => s.finished,
  getResult(s) {
    const ranking = s.players.map(u => ({ userId: u, username: s.names[u], score: s.scores[u] })).sort((a, b) => b.score - a.score);
    let rank = 0;
    ranking.forEach((r, i) => { if (i === 0 || r.score < ranking[i - 1].score) rank = i + 1; r.rank = rank; });
    return { gameType: 'nitro_knockout', scores: s.scores, ranking, winners: ranking.filter(r => r.rank === 1).map(r => r.userId) };
  },
};

module.exports = { game, validateSnapshot, validInputArgs };
