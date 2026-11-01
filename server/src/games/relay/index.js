const { GameError } = require('../../errors');

// Games whose rules run on the host's phone (the same code as the one-device version).
// The server just relays: guests' inputs go to the host, the host's state goes to everyone.
const RELAY_GAMES = [
  { id: 'colour_clash', min: 2, max: 2 },
  { id: 'ludo', min: 2, max: 4 },
  { id: 'ludo_teams', min: 4, max: 4 },
  { id: 'snakes_ladders', min: 2, max: 6 },
  { id: 'dots_boxes', min: 2, max: 4 },
  { id: 'tic_tac_toe', min: 2, max: 2 },
  { id: 'connect_four', min: 2, max: 2 },
  { id: 'truth_dare', min: 2, max: 6 },
  { id: 'math_duel', min: 2, max: 4 },
  { id: 'reaction_tap', min: 2, max: 6 },
  { id: 'air_hockey', min: 2, max: 2 },
  { id: 'ping_pong', min: 2, max: 2 },
  { id: 'find_spy', min: 3, max: 6 },
  { id: 'undercover', min: 3, max: 6 },
  { id: 'mafia', min: 4, max: 6 },
  { id: 'charades', min: 2, max: 6 },
  { id: 'heads_up', min: 2, max: 6 },
  { id: 'draw_guess', min: 2, max: 6 },
  { id: 'most_likely', min: 3, max: 6 },
  { id: 'would_rather', min: 2, max: 6 },
  { id: 'hand_cricket', min: 2, max: 2 },
  { id: 'quiz_battle', min: 2, max: 4 },
  { id: 'basketball_hoops', min: 2, max: 4 },
  { id: 'rock_paper_scissors', min: 2, max: 6 },
  { id: 'fruit_merge_battle', min: 2, max: 4 },
  { id: 'bingo', min: 2, max: 6 },
  { id: 'battleship', min: 2, max: 2 },
  { id: 'checkers', min: 2, max: 2 },
  { id: 'mini_golf', min: 2, max: 4 },
  { id: 'slingshot', min: 2, max: 4 },
  { id: 'archery', min: 2, max: 4 },
  { id: 'shooting_gallery', min: 2, max: 4 },
  { id: 'bottle_smash', min: 2, max: 4 },
  // RivalRoom-only games: playable when a host picks them, never chosen at random (Quick Play,
  // party mode), so players on an app without them never land in one.
  { id: 'chess', min: 2, max: 2, optIn: true },
  { id: 'tug_of_war', min: 2, max: 2, optIn: true },
  { id: 'darts', min: 2, max: 4, optIn: true },
  { id: 'hot_potato', min: 2, max: 6, optIn: true },
  { id: 'knife_hit', min: 2, max: 4, optIn: true },
  { id: 'cup_pong', min: 2, max: 2, optIn: true },
  { id: 'hungry_hippos', min: 2, max: 4, optIn: true },
  { id: 'penguin_push', min: 2, max: 4, optIn: true },
  { id: 'ring_sort', min: 2, max: 4, optIn: true },
  { id: 'minesweeper', min: 1, max: 2, optIn: true },
  { id: 'color_switch', min: 1, max: 2, optIn: true },
  { id: 'fruit_cut', min: 1, max: 2, optIn: true },
  { id: 'chicken_jump', min: 1, max: 2, optIn: true },
  { id: 'carrom', min: 2, max: 2, optIn: true },
  { id: 'eight_ball', min: 2, max: 2, optIn: true },
  { id: 'bike_race', min: 1, max: 2, optIn: true },
];

const MAX_STATE_BYTES = 64 * 1024;
const MAX_QUEUE = 200;
const NAME_RE = /^[a-zA-Z][a-zA-Z0-9_]{0,23}$/;

function validateSize(value, label) {
  let json;
  try { json = JSON.stringify(value); }
  catch { throw new GameError('INVALID_PAYLOAD', `${label} must be JSON serializable`); }
  if (typeof json !== 'string' || Buffer.byteLength(json, 'utf8') > MAX_STATE_BYTES) {
    throw new GameError('INVALID_PAYLOAD', `${label} too large`);
  }
}

function createRelayGame({ id, min, max, optIn = false }) {
  return {
    id, minPlayers: min, maxPlayers: max, implemented: true, relay: true, optIn,

    create(room) {
      if (room.players.length < min || room.players.length > max) throw new GameError('NOT_ENOUGH_PLAYERS');
      const players = room.players.map(p => p.userId);
      return {
        players,
        names: Object.fromEntries(room.players.map(p => [p.userId, p.username])),
        host: players.includes(room.hostId) ? room.hostId : players[0],
        state: null, views: null, version: 0,
        inputs: [], inputSeq: 0,
        finished: false, scores: null,
      };
    },

    onAction(s, uid, { type, payload }) {
      if (!s.players.includes(uid)) throw new GameError('NOT_IN_GAME');
      if (s.finished) throw new GameError('BAD_PHASE');
      const p = payload || {};
      if (type === 'relay:state') {
        if (uid !== s.host) throw new GameError('NOT_HOST');
        if (typeof p.state !== 'object' || p.state === null || Array.isArray(p.state)) throw new GameError('INVALID_PAYLOAD');
        validateSize(p.state, 'state');
        if (p.views != null) {
          if (!Array.isArray(p.views) || p.views.length !== s.players.length) throw new GameError('INVALID_PAYLOAD');
          for (const v of p.views) {
            if (typeof v !== 'object' || v === null || Array.isArray(v)) throw new GameError('INVALID_PAYLOAD');
          }
          validateSize(p.views, 'views');
        }
        if (p.ack !== undefined && (!Number.isSafeInteger(p.ack) || p.ack < 0 || p.ack > s.inputSeq)) throw new GameError('INVALID_PAYLOAD');
        // Commit only after state, private views and acknowledgement all validate.
        s.state = p.state;
        s.views = p.views ?? null;
        s.version++;
        if (p.ack !== undefined) s.inputs = s.inputs.filter(i => i.seq > p.ack);
        return { version: s.version };
      }
      if (type === 'relay:input') {
        if (typeof p.name !== 'string' || !NAME_RE.test(p.name) || !Array.isArray(p.args) || p.args.length > 8) throw new GameError('INVALID_PAYLOAD');
        if (!Array.from(p.args).every(a => a === null || typeof a === 'string' || typeof a === 'boolean' || (typeof a === 'number' && Number.isFinite(a)))) throw new GameError('INVALID_PAYLOAD');
        validateSize(p.args, 'args');
        s.inputs.push({ seq: ++s.inputSeq, from: uid, name: p.name, args: p.args });
        if (s.inputs.length > MAX_QUEUE) s.inputs.splice(0, s.inputs.length - MAX_QUEUE);
        return { seq: s.inputSeq };
      }
      if (type === 'relay:finish') {
        if (uid !== s.host) throw new GameError('NOT_HOST');
        const scores = p.scores;
        if (!Array.isArray(scores) || scores.length !== s.players.length || !Array.from(scores).every(Number.isSafeInteger)) throw new GameError('INVALID_PAYLOAD');
        s.scores = Object.fromEntries(s.players.map((u, i) => [u, scores[i]]));
        s.finished = true;
        return {};
      }
      throw new GameError('INVALID_ACTION');
    },

    getPublicState(s, uid) {
      const seat = s.players.indexOf(uid);
      const mine = s.views && seat >= 0 ? s.views[seat] : null;
      const state = mine && s.state && typeof s.state === 'object'
        ? { ...s.state, _seat: mine }
        : s.state;
      return {
        gameType: id, relay: true, host: s.host,
        players: s.players.map(u => ({ userId: u, username: s.names[u] })),
        state, version: s.version,
        // Only the host needs the input queue.
        inputs: uid === s.host ? s.inputs : [],
        finished: s.finished,
      };
    },

    isFinished: s => s.finished,

    getResult(s) {
      const ranking = s.players.map(u => ({ userId: u, username: s.names[u], score: s.scores[u] })).sort((a, b) => b.score - a.score);
      let rank = 0;
      ranking.forEach((r, i) => { if (i === 0 || r.score < ranking[i - 1].score) rank = i + 1; r.rank = rank; });
      return { gameType: id, scores: s.scores, ranking, winners: ranking.filter(r => r.rank === 1).map(r => r.userId) };
    },
  };
}

module.exports = { RELAY_GAMES, createRelayGame, games: RELAY_GAMES.map(createRelayGame) };
