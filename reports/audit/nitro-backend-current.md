# Nitro backend integration — current working tree

Date: 2026-10-30. Branch inspected: `clay/new-games`. No branch change, commit, archive-wide patch application, UI/catalogue change, or unrelated file replacement.

## Reference evidence actually inspected

- Local archive: `C:/Users/sg857/Downloads/Two-player-online-nitro-knockout-420626f.zip`.
  - SHA-256: `e73a823b144af84817276b10c02c537c0f8d8e95eac80cd80898f3ea68d02f84`.
  - Read `repo/server/src/games/nitro_knockout.js` and `repo/server/tests/nitro_knockout.test.js` directly from the ZIP before implementation.
  - Compared archived `repo/server/src/rooms/RoomManager.js` against the CURRENT working-tree manager using a textual diff, not against an assumed clean branch. Rejected the archive's older sequence/timer/rematch handling and its live relay-host reassignment.
  - Read archived `repo/mobile/lib/features/local_games/nitro_knockout/nitro_online_screen.dart`: migration changes the host role, rekeys the WebView and resets frontend match bookkeeping. This is not a physics-state restore.
  - Statically inspected targeted snippets in archived `repo/mobile/assets/nitro/assets/index-CejRMBG2.js` (SHA-256 `59f45677bed75c513c38a17a54cd5871e8a11b3f087da09aad9fc62072c28be9`). Its `buildSnapshot()` emits integer millimetres, centiradian yaw, integer health/scores/ammo, centisecond timers, six-column shots, three-column mines, crate flags and optional two-name feed. `endMatch()` sets `netOver`, publishes a snapshot and THEN posts `kind: "finish"`. Online kart count is clamped to 2–10, and online seat names/inputs map to the human roster rather than the offline bot grid.
- Original local source: `C:/Users/sg857/Downloads/Kimi_Agent_End-to-End WebAssembly Game/app/src/game`.
  - Read `config.ts` and relevant `game.ts` simulation, snapshot-related comparison points, elimination/respawn and end-match logic; also inspected `state.ts` in the same source read.
  - Original `game.ts` SHA-256: `3a97b69f635dc0371ad082ea160e4c35fcacd17bd2409d39c76ec2a3628cbb80`.
  - Original source is the offline eight-kart game, not the complete archive online implementation. Do not attribute the archive's online bridge to that original source.
  - Confirmed 90-second matches, 64 projectiles, 12 mines, 100 health, five weapon types, and disabled fallen karts remaining below y=-5 until respawn. The reference server's y >= -2 check rejects those legitimate fallen-kart frames; the adapted envelope permits y down to -10.
- Read `reports/audit/backend-current.md`, current registry, relay implementation, manager, socket handlers and affected tests. Inspected current `mobile/lib/core/lan/lan_rooms.dart` and the catalogue-derived registry in `lan_host.dart` before deciding not to change mobile files.

These are ordinary local ZIP/source/static-JS observations. No REA MCP tools were available; no REA Evidence, browser execution, WASM decompilation, or live Rapier behavior is claimed.

## Changes attributable to this integration

- **New `server/src/games/nitro_knockout.js`:** dedicated `nitro:state`, `nitro:input`, `nitro:finish` plugin, preserving the archive's public Nitro/relay envelope, seat order, host-private input queue and tied ranking convention. Exactly 2–10 room participants become seats; there is no backend bot-seat filling.
- **`server/src/games/registry.js`:** register the dedicated module, not a generic relay variant. Preserve pre-existing catalogue removals and registry edits.
- **`server/src/rooms/RoomManager.js`:** allow integer room capacities 2–10 independently of the selected game. Individual plugin start limits remain enforced. Honor `response.silent` so Nitro steering queues without broadcasting full room/game state; result broadcasts cannot be suppressed by a silent response. Existing generic relay inputs retain their previous broadcasting behavior. Quick Play's existing default room capacity remains six.
- **Lifecycle policy:** retain the current audited fixed-roster abort behavior. Temporary disconnect/reconnect preserves the same game object, snapshots, roster, host, queue, version and outer action sequence high-water marks. A permanent departure (host OR guest, including grace expiry) during play explicitly aborts to the lobby and clears party state. Lobby host ownership can transfer. The backend does NOT claim a live Nitro host migration. Added an explanatory comment rather than replacing the audited removal path with the archive's host-pointer reassignment.
- **New `server/tests/nitro_knockout.test.js`:** 13 tests adapted from archive cases and extended for rejection atomicity, sparse/unsafe payloads, terminal-score matching, clock/score rollback, owned accepted data, private queue/acks, silent publication, special identity keys, grace timers, explicit abort, fresh rematch and real ten-client Socket.IO operation. The real transport case reconnects both guest and host, checks preserved queue/state/sequence, then finishes and rematches.
- **Associated test adjustments:** `rooms.test.js` and `relay.test.js` reject capacity 11 instead of 7. `session.test.js` understands Nitro's dedicated terminal/finish protocol in both its direct helper and randomized Socket.IO party path, plus a deterministic Nitro party/result/next-round regression. No production generic-relay validation changes were needed.

The existing audit's atomic relay validation, timer ownership checks, replacement-socket protection, null-prototype sequences, accepted-only sequence advancement, atomic game construction, finished reconnect replay and party accounting are preserved. Most of the total Git diff in those shared files predates this integration; do not attribute or revert it wholesale.

## Validation and final-result boundary

- Validate complete dense integer snapshot arrays, fixed seat count, bounded coordinates/yaw/health/scores/weapons/ammo/timers, object counts, crate flags and feed labels. Reject unknown snapshot fields. Bound JSON by UTF-8 bytes (32 KiB) and convert serialization failures to `INVALID_PAYLOAD`.
- Validate centi-unit throttle/steer in [-100,100], drift 0/1 and bounded nonnegative fire counter. Copy accepted inputs/snapshots so the original payload object cannot mutate accepted state.
- Validate an optional ack as a nonnegative safe integer no greater than the last issued input ID. Validate everything before changing snapshot/version/queue. Repeated or older valid acks cannot resurrect consumed inputs.
- Across accepted snapshots, time cannot increase, scores cannot decrease, and crate count cannot change. A terminal frame must have `over: 1` and `time: 0`; it cannot revert to live status or change terminal scores.
- `nitro:finish` requires a previously accepted terminal frame and an exact score match for every seat. Derive stored results from that frame, not from a separate unverified score list. Finished games reject further actions, consistent with RoomManager's existing finished phase gate. Rankings, winners and party points use that result.

**This is authoritative server enforcement of the room/protocol/result-consistency boundary, NOT server-authoritative game simulation or cheat-proof scores.** A malicious host can fabricate a consistent terminal frame, accelerate the countdown, invent kills, ignore controls, acknowledge inputs without applying them, or stop publishing entirely. There is no Rapier simulation, physical transition proof, independently verified collision/kill accounting, or server-clock-enforced 90-second gameplay here. The server can establish that a result matches its accepted terminal snapshot, not that the snapshot is truthful.

## Tests actually run

From `server/`:

1. `node --test tests/nitro_knockout.test.js`, bounded to 30 seconds: **13 passed, 0 failed** on the initial focused implementation.
2. Initial `npm test`, bounded to 120 seconds: **113 passed, 1 failed**. Failure was the existing relay room-capacity test expecting seven-player rooms to be invalid; updated its capacity boundary only.
3. `node --test tests/nitro_knockout.test.js tests/backend_reliability.test.js tests/relay.test.js tests/rooms.test.js`, bounded to 30 seconds, after expanding real socket host reconnection: **43 passed, 0 failed**.
4. A subsequent full `npm test` exposed a randomized party helper selecting Nitro and incorrectly sending `relay:finish`. Corrected the associated session helper/socket test to use Nitro's terminal protocol and added deterministic coverage; did not weaken Nitro production validation.
5. Final `npm test`, bounded to 120 seconds: **115 passed, 0 failed, 0 skipped** (includes real Socket.IO tests and preserved backend reliability tests).
6. `git --no-pager diff --check -- server/src server/tests`: clean at review; Git warns that the existing relay test working copy will normalize LF to CRLF. No whitespace failure.

No Flutter/device/browser/load/production deployment validation was performed. Ten clients in a localhost Node transport test establish a backend protocol lifecycle, not ten-device render performance or a 90-second physics session.

## Parent/frontend coordination and remaining limitations

1. **Do not migrate a live host by changing `host` and rebooting a WebView.** Snapshots omit complete velocities, cooldowns, projectile ownership/lifetimes, respawn timers, RNG/world state and other simulation data needed for faithful restoration. Backend grace reconnect is safe for the retained server state; it does not restore a destroyed/reloaded host WebView. Preserve the existing host simulation across transient transport loss where feasible. If it is lost, surface an explicit abort/return-to-lobby rather than silently starting a fresh live simulation. Server rollback checks reject obvious fresh-countdown/progress resets, but cannot detect every semantically fresh world with a nonincreasing clock.
2. **Terminal ordering/reliability:** the archive JS posts the terminal snapshot before `finish`, compatible with this server. The parent action path must preserve that order and handle rejections. If terminal publication is rate-limited/lost/rejected, finish is also rejected; retrying the complete terminal publication and finish sequence needs frontend acknowledgement handling. No new server protocol/event was invented.
3. **LAN:** no mobile file was changed. `lan_rooms.dart` only implements `relay:*`, and its registry is supplied by `LanHost.games` from the catalogue; it is not a standalone hard-coded server registry. Registering Nitro there as a generic relay would advertise a broken game. The parent must exclude Nitro from phone-hosted LAN selection/Quick Play (for example, alongside the existing internet-only games) or separately implement the dedicated Nitro protocol. Raising the LAN capacity alone is NOT parity. Internet-server rooms now support 2–10; LAN remains 2–6. The parent owns frontend/LAN availability/catalogue work, outside this patch.
4. **Client limits/identity:** parent room selectors must offer up to ten online seats and start the real online boot with the exact server roster. The reference feed contract caps each label at 24 UTF-16 code units; long Firebase display names require appropriately bounded game labels or a coordinated contract change. Server auth identity must come from the authenticated session, not the archive frontend's dev-token string split when using Firebase.
5. **No automatic forfeit or seamless dropout continuation:** a permanent guest departure also aborts, preserving the audited fixed-roster policy. Finished results can retain the original match roster after a departure while remaining users return/rematch under existing rules.
6. **Protocol/delivery:** the 200-input queue drops oldest unacknowledged entries on overflow. Ack validation proves range, not application. Accepted outer sequences deduplicate within a round only. Reconnect preserves them; new rounds reset them. No round ID binds delayed packets to a match. No new exactly-once, replay-proof, host-timeout, durable recovery or multi-worker guarantee is claimed.
7. **Security/deployment:** keep the existing audit's auth, rate/abuse, TLS/origin, persistence and host-trust limitations. No production anti-cheat or penetration-test claim. Additional snapshot bounds are sanity envelopes, not a validated physics model.
