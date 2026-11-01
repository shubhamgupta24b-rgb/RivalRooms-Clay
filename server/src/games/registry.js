// Game plugin contract:
// { id, minPlayers, maxPlayers, implemented,
//   create(room) -> state, onAction(state, userId, {type,payload}), getPublicState(state, userId),
//   isFinished(state), getResult(state) }
const games = new Map();
const REQUIRED = ['create', 'onAction', 'getPublicState', 'isFinished', 'getResult'];
function register(mod) {
  if (mod.implemented) for (const f of REQUIRED) if (typeof mod[f] !== 'function') throw new Error(`game ${mod.id} missing ${f}`);
  games.set(mod.id, mod);
}
const get=id=>games.get(id), has=id=>games.has(id), list=()=>[...games.values()];
register(require('./guess_person').game);
register(require('./memory').game);
// basketball_hoops is played through the relay now (the swipe-to-shoot version).
// crush_it and fruit_duel were removed from the catalog; their modules stay for unit tests.
register(require('./paint_fight').game);
register(require('./guess_who').game);
register(require('./raja_mantri').game);
register(require('./nitro_knockout').game);
for (const g of require('./relay').games) register(g);
module.exports={register,get,has,list};