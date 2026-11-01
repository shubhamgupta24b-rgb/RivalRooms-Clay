// Single-process, mutable in-memory rooms. A shared store alone is not enough to scale out:
// membership, timers, sockets and atomic game transitions also need coordination.
class MemoryRoomStore {
  constructor() { this.rooms = new Map(); }
  get(code) { return this.rooms.get(code); }
  set(code, room) { this.rooms.set(code, room); }
  delete(code) { this.rooms.delete(code); }
  values() { return this.rooms.values(); }
  has(code) { return this.rooms.has(code); }
}
module.exports = { MemoryRoomStore };
