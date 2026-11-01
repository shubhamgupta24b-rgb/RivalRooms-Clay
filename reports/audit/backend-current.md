# Current backend audit

Date: 2026-10-30. Scope: existing `server/src` and `server/tests`; source review plus local Node tests, not a production penetration test.

## Architecture reviewed

Before edits, reviewed every source and test file in those directories: Express/Socket.IO startup, configuration, token verification, optional Mongo profiles, room store/manager, socket handlers, registry, relay, native/legacy game modules and data, and privacy endpoint. Rooms, game state, user-to-room ownership, reconnect timers and socket ownership are process-local. Mongo stores optional profiles, not recoverable rooms or match state. Native plugins validate their own moves; most registered games use a host-phone relay. Registry/catalogue changes already in the working tree are not attributed to this audit.

## Confirmed fixes

- **Atomic relay publication:** validate shared state, all private views and input acknowledgement before changing state, views, version or queue. Invalid views previously left the new shared state installed despite rejecting the action.
- **Bounded relay payloads:** count UTF-8 bytes, not UTF-16 string length, against the existing 64 KiB state/views limits. Convert serialization errors to `INVALID_PAYLOAD`; bound input arguments too. Reject non-finite input numbers and unsafe/sparse score arrays before mutation.
- **Acknowledgements:** supplied acknowledgements must be nonnegative safe integers no greater than the last issued input ID. Invalid values cannot discard queued inputs. Repeated/older valid acknowledgements never resurrect consumed inputs; they do not prove the host actually applied those inputs.
- **Action sequences (earlier phase):** validate safe nonnegative integers in both socket ingress and RoomManager; update the high-water mark only after plugin acceptance. Rejected high-sequence actions no longer block valid lower sequences. Accepted duplicates/older sequences remain `DUPLICATE_ACTION`, without replaying effects. Sequence maps do not inherit object-prototype keys.
- **Room lifecycle (earlier phase):** disconnect is idempotent; callbacks verify timer ownership and room/player identity. Reconnect/leave cancels grace timers; server shutdown clears room ownership and timers. Start/next-round construction failures preserve the prior state.
- **Fixed-roster cleanup (earlier phase):** temporary disconnect retains the game for reconnection. Permanent departure during play aborts to the lobby and clears the party, rather than leaving a missing turn-holder or relay host inside plugin state. Lobby host ownership transfers, but live relay-host migration is not claimed.
- **Session handling (earlier phase):** stale replacement-socket handlers cannot mutate the new session. Reconnection sends room/game snapshots and finished results, including existing party standings without awarding points again.

Existing event names, acknowledgement envelopes, relay action types, player-order scores, game IDs, catalogue/player limits and bounded-queue behavior are preserved by the audit changes. Stricter rejection of malformed/oversized payloads and abort-on-permanent-departure are intentional behavior changes.

## Coordination boundary

The resumed relay-focused phase did not edit the registry, RoomManager, sockets, catalogue limits or Nitro. Earlier edits in this same audit already affected `server/src/index.js`, `server/src/rooms/{RoomManager,RoomStore}.js`, `server/src/sockets/index.js`, and room/session tests; retain/reconcile those with the parent integration, especially fixed-roster aborts versus any dedicated engine's participant-removal policy. No Nitro implementation or correctness claim is included here.

New relay-specific regressions live in `server/tests/relay.test.js`. Earlier room/session/relay regressions live in `server/tests/backend_reliability.test.js`. The resumed phase also corrected that file's timer double to remove a fired timer from its pending set, matching real timer behavior.

## Validation actually performed

- Initial bounded `npm test`: 96 passed, 1 failed. The failure was the audit's timer test double retaining a fired timer; corrected the double, not production cleanup.
- `node --test tests/relay.test.js` (30-second bound): **12 passed, 0 failed**.
- Final `npm test` (120-second bound): **101 passed, 0 failed**, including Socket.IO integration tests.
- `git diff --check -- server/src server/tests`: no whitespace errors; Git reported LF-to-CRLF normalization warnings for the relay test file.

Relay regressions cover rejection atomicity, private-view preservation, serialization failures, exact UTF-8 size boundaries, malformed arguments/scores/acks, repeated acknowledgements, duplicate socket actions, rejected high sequences and unchanged queue/snapshot/version on rejection.

## Remaining limitations / follow-up

1. **Host-trusted, not server-authoritative:** the relay server does not implement game rules, prove legal transitions, simulate physics, verify scores or independently validate host outcomes. The host receives guest inputs and can ignore/fabricate results; per-seat views protect guests from each other's views only when the host publishes secrets correctly. Common state is sent to every participant.
2. **Not exactly-once delivery:** duplicate accepted outer sequences return an error, not a cached success response. Identical actions under new sequences are new inputs. No round ID binds packets, and sequences reset each round; delayed previous-round actions can therefore be accepted in another round. Full cross-round protection requires coordinated client/server protocol changes. Relay `onAction` itself relies on RoomManager for outer-action deduplication.
3. **Queue overflow remains lossy:** the existing 200-input queue discards oldest unacknowledged entries when full. There is no retransmission, backpressure or host processing guarantee. Each argument list is now bounded, but aggregate per-room memory, connection counts and room counts still need deployment-level limits.
4. **No durable/distributed room recovery:** restarting the process loses rooms; replacing the store with Redis alone cannot coordinate game mutations, local membership, timers and sockets across workers. No seamless host migration or participant forfeits are provided by the generic plugin contract.
5. **Deployment security:** dev auth permits identity claims; retain the production guard and do not use `ALLOW_DEV_AUTH=true` for real players. Firebase credentials/revocation policy, TLS, origin policy (currently wildcard), proxy limits, per-identity/IP abuse controls and dependency advisories require separate deployment verification. Some native plugins also use plain-object user-keyed maps; special identity keys deserve a separate targeted review.
6. **Untested here:** physical-device behavior, prolonged packet loss/reordering, reconnect storms, load/soak limits, production Firebase/Mongo configuration, multi-worker deployment and the concurrent Nitro integration. Local passing tests do not establish those guarantees.
