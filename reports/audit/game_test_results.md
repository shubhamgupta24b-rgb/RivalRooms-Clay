# Game test results

## Scope

The online game catalog had 54 entries before Smash Karts removal and has 53 now. The one-device hub changed from 70 shell entries to 69 (71 total including Guess the Person and Raja Mantri). Backend relay list count changed from 50 to 49. Full per-game real-device and multiplayer scenario coverage was not completed.

| Area | Status | Evidence |
|---|---|---|
| Smash Karts absent from mobile online catalog | PASS (regression added) | `games_hub_test.dart` checks catalog. |
| Smash Karts absent from one-device catalog/search | PASS (regression added) | `games_hub_test.dart` checks local registry and search. |
| Smash Karts rejected by online server registry | PASS (regression added) | `server/tests/relay.test.js` asserts registry/list absence. |
| Remaining games, all setup boundaries and full matches | PARTIAL | Full Flutter suite passes 948 tests; no per-game emulator run or paired-device run. |
| Multiplayer host/guest, reconnect and invalid message scenarios | NOT TESTED | No paired-device run. Existing unit suites are present. |
| Server test suite | PASS | `node --test --test-reporter=spec tests/*.test.js`: 86 passed, 0 failed after correcting the stale 50-game count. |

An old `smash_karts` request can no longer resolve through the relay registry; room selection/start validation should reject it as an unknown game. The direct registry regression passes. A dedicated socket protocol test for that old client request has not yet been run.
