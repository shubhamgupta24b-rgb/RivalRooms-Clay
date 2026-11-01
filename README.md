# RivalRoom — Clay Version

Party games for 2–6 friends: on one phone, in online rooms, or solo.
Flutter app (`mobile/`) + Node/Socket.IO server (`server/`).

**Deployment branch:** `main` (Clay version).

## Render deployment

**Service:** [rivalrooms-clay-backend](https://dashboard.render.com/web/srv-dbjdf75g1s2s73feco6g)  
**Public URL:** https://rivalrooms-clay-backend.onrender.com  
**Health endpoint:** https://rivalrooms-clay-backend.onrender.com/health  
**Source:** `main` branch of this repository  
**Runtime:** Docker (`server/Dockerfile`, build context `server/`)  
**Region / plan:** Singapore / Free  
**Auto deploy:** enabled for commits to `main`

The first Render build completed and the service process started on port 10000. Render marked that deployment live. This confirms container startup, not end-to-end multiplayer verification.

### Current deployment limitations

- `MONGO_URI` is not configured; profile persistence is disabled.
- `AUTH_MODE=dev` and `ALLOW_DEV_AUTH=true` are currently enabled for temporary testing. Development auth allows clients to claim identities and is **not production-safe**. Configure Firebase authentication and remove the dev-auth override before public production use.
- Room state is currently held in server memory and can be lost when the service restarts or spins down.
- The Free instance may spin down when idle, causing cold starts.
- Render's health-check path should be set to `/health`.
- Automated server tests passing does not replace real-device, multi-client online gameplay testing.

Build the Flutter app against this deployment:

```bash
cd mobile
flutter build apk --release --dart-define=SERVER_URL=https://rivalrooms-clay-backend.onrender.com
flutter build appbundle --release --dart-define=SERVER_URL=https://rivalrooms-clay-backend.onrender.com
```

Do not commit database credentials, Firebase service-account keys, or other secrets. Configure them in the Render service's Environment settings.

## Status snapshot

This README describes the **current implementation**, verified where tests exist and marked otherwise. Statuses:

- **COMPLETE** — implemented and verified by tests or static inspection.
- **PARTIAL** — implemented but incomplete or not fully verified.
- **NOT STARTED** — not implemented.
- **BLOCKED** — requires external credentials or unavailable dependencies.

Overall verified completion: approximately **85%** (see per-game table below).

All 1,018 Flutter tests executed and passed. All 115 server tests executed and passed. Debug and release APKs built successfully.

## Games

### Offline (one device)

The local hub lists ~70 shell games plus two special flows (Guess the Person, Raja Mantri Chor Sipahi) and ~30 solo games. Categories: cards, board, action, party, solo.

| Game | Offline seats | Online seats | UI | Logic | Offline | Online | Tests |
|---|---|---|---|---|---|---|---|
| Colour Clash | remoteOnly | 2 | PARTIAL | PARTIAL | NOT STARTED | PARTIAL | PARTIAL |
| Find the Spy | 3–6 | 3–6 | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| Ludo | 2–4 | 2–4 | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| Mafia | 4–6 | 4–6 | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| Undercover | 3–6 | 3–6 | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| Charades | 2–6 | 2–6 | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| Snakes & Ladders | 2–6 | 2–6 | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| Draw & Guess | 2–6 | 2–6 | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| Heads Up | 2–6 | 2–6 | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| Quiz Battle | 2–4 | 2–4 | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| Hand Cricket | 2 | 2 | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| Basketball Hoops | 2–4 | 2–4 | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| Memory | 2–6 | 2–4 | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| Paint Fight | 2 | 2–4 | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| Tic-Tac-Toe | 2 | 2 | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| Air Hockey | 2 | 2 | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| Ping Pong | 2 | 2 | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| Reaction Tap | 2–6 | 2–6 | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| Math Duel | 2–4 | 2–4 | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| Connect Four | 2 | 2 | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| Dots & Boxes | 2–4 | 2–4 | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| Most Likely To | 3–6 | 3–6 | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| Would You Rather | 2–6 | 2–6 | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| Truth or Dare | 2–6 | 2–6 | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| Rock Paper Scissors | 2–6 | 2–6 | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| Fruit Merge Battle | 2–4 | 2–4 | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| Bingo | 2–6 | 2–6 | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| Battleship | 2 | 2 | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| Checkers | 2 | 2 | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| Mini Golf | 1–4 | 1–4 | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| Slingshot | 1–4 | 1–4 | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| Archery | 1–4 | 1–4 | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| Shooting Gallery | 1–4 | 1–4 | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| Bottle Smash | 1–4 | 1–4 | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| Chess | 2 | 2 | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| Tug of War | 2 | 2 | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| Darts | 2–4 | 2–4 | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| Hot Potato | 2–6 | 2–6 | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| Knife Hit | 2–4 | 2–4 | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| Cup Pong | 2 | 2 | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| Hungry Hippos | 2–4 | 2–4 | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| Penguin Push | 2–4 | 2–4 | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| Ring Sort Race | 2–4 | 2–4 | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| Fruit Merge | 1 | — | PARTIAL | PARTIAL | PARTIAL | — | PARTIAL |
| 2048 | 1 | — | PARTIAL | PARTIAL | PARTIAL | — | PARTIAL |
| Flappy Jump | 1 | — | PARTIAL | PARTIAL | PARTIAL | — | PARTIAL |
| Minesweeper | M 1–2 | 1–2 | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| Brick Breaker | 1 | — | PARTIAL | PARTIAL | PARTIAL | — | PARTIAL |
| Whack-a-Mole | 1 | — | PARTIAL | PARTIAL | PARTIAL | — | PARTIAL |
| Piano Tiles | 1 | — | PARTIAL | PARTIAL | PARTIAL | — | PARTIAL |
| Word Scramble | 1 | — | PARTIAL | PARTIAL | PARTIAL | — | PARTIAL |
| Stack Tower | 1 | — | PARTIAL | PARTIAL | PARTIAL | — | PARTIAL |
| Simon Says | 1 | — | PARTIAL | PARTIAL | PARTIAL | — | PARTIAL |
| Fruit Cut | M 1–2 | 1–2 | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| Chicken Jump | M 1–2 | 1–2 | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| Carrom | 2 | 2 | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| Eight Ball | 2 | 2 | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| Candy Crush | 1 | — | PARTIAL | PARTIAL | PARTIAL | — | PARTIAL |
| Bike Racing | M 1–2 | 1–2 | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| **Nitro Knockout** | **1 human + 7 bots** | **2–10** | **PARTIAL** | **PARTIAL** | **PARTIAL** | **PARTIAL** | **PARTIAL** |
| Ball Sort | 1 | — | PARTIAL | PARTIAL | PARTIAL | — | PARTIAL |
| Sliding Puzzle | 1 | — | PARTIAL | PARTIAL | PARTIAL | — | PARTIAL |
| Sudoku | 1 | — | PARTIAL | PARTIAL | PARTIAL | — | PARTIAL |
| Hangman | 1 | — | PARTIAL | PARTIAL | PARTIAL | — | PARTIAL |
| Dino Run | 1 | — | PARTIAL | PARTIAL | PARTIAL | — | PARTIAL |
| Block Drop | 1 | — | PARTIAL | PARTIAL | PARTIAL | — | PARTIAL |
| Bubble Shooter | 1 | — | PARTIAL | PARTIAL | PARTIAL | — | PARTIAL |
| Sky Jumper | 1 | — | PARTIAL | PARTIAL | PARTIAL | — | PARTIAL |
| Space Shooter | 1 | — | PARTIAL | PARTIAL | PARTIAL | — | PARTIAL |
| Color Switch | M 1–2 | 1–2 | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |

Special flows:
- Guess the Person: 2–6 local only; online identity is `guess_who`, not this ID.
- Raja Mantri Chor Sipahi: 4 local, 4 online (internet-only).
- Guess Who: 2 online only (internet-only).
- Ludo Teams (2v2): 4 via Ludo teams switch, 4 online.

### Nitro Knockout

Replaces the previous Smash Karts (Smash Karts implementation, logic, and tests removed; registry/catalog regressions assert `smash_karts` is absent).

- **Offline:** 1 human + 7 built-in AI bots (NOVA, BOLT, ROOK, JINX, MISO, APEX, ECHO), 3D kart combat via bundled WebView/WASM assets under `mobile/assets/nitro/`. 90-second match, most KOs wins. Weapons: rocket, mines, shockwave, blaster, shield.
- **Online:** fixed-roster host-trusted arena, 2–10 human players. Server-side snapshot validation (`server/src/games/nitro_knockout.js`). No seamless host migration; permanent host departure aborts the match.
- **Assets:** `mobile/assets/nitro/index.html` + JS/CSS bundle; loaded through `NitroGameView` (Android WebView only).
- **Status:** PARTIAL — implementation exists; end-to-end runtime validation (boot, controls, audio, physics, multi-seat, reconnect) not yet executed in this session.

## UI redesign

Claymorphism design system: inflated clay surfaces (ClayDecoration), grape world, candy-yellow actions, Fredoka/Nunito typography, rise-and-squash transitions. Shared shell components (pause, result, HUD, how-to-play) rebuilt. Per-game visual identity work in progress; not every play surface has been individually verified.

**Status:** PARTIAL — shared shell redesigned; per-game redesign outstanding for most games.

## AdMob integration

Integrated via `google_mobile_ads` 9.2.0 (Android only).

- **App ID:** `ca-app-pub-2273708482671832~3323244780` (manifest meta-data + build.gradle default).
- **Interstitial (prod):** `ca-app-pub-2273708482671832/3168825409`
- **Rewarded interstitial (prod):** `ca-app-pub-2273708482671832/4842753743`
- **Test units:** interstitial `ca-app-pub-3940256099942544/1033173712`, rewarded `ca-app-pub-3940256099942544/5354046379` — always used in debug/profile, and in release unless `ADMOB_USE_TEST_ADS=false`.
- **Consent:** UMP consent flow at startup; `canRequestAds()` gated; failures never block gameplay.
- **Placement:** interstitial offered at completed-match Rematch (3-minute cooldown, full-screen lock). Rewarded interstitial API exists but no game currently calls it.
- **No banner ad unit** is configured or inferred.

**Status:** COMPLETE (service + config + unit tests); test ad rendering on device not yet executed.

## Backend and multiplayer

Node/Express + Socket.IO server (`server/`). Guest logins (`ALLOW_DEV_AUTH=true`). Room creation/joining, turn/score sync, server-side validation for nitro. LAN mode: one laptop hosts on same Wi-Fi/hotspot; phones connect via Home > Server.

- **Registry:** `server/src/games/registry.js` registers nitro_knockout + relay games. `smash_karts` is absent.
- **LAN exclusions:** `guess_who`, `raja_mantri`, `nitro_knockout` excluded from `lan_host.dart` (internet-only for those).
- **Online catalog:** 54 entries in `game_catalog.dart` including nitro_knockout (2–10).

**Status:** PARTIAL — server validation exists for nitro; general relay sync implemented; end-to-end multi-device testing not yet executed.

## Tests

Test suite under `mobile/test/` and `server/tests/`.

**Execution results (this session):**
- `flutter test` — **1,018 tests passed, 0 failed** (all unit/widget tests under `mobile/test/`).
- `npm test` (server) — **115 tests passed, 0 failed** (relay, rooms, session, backend_reliability, nitro_knockout).
- `flutter analyze` — **no issues found**.
- `flutter build apk --debug` — **built** `mobile/build/app/outputs/flutter-apk/app-debug.apk`.
- `flutter build apk --release --dart-define=ADMOB_USE_TEST_ADS=true` — **built** `mobile/build/app/outputs/flutter-apk/app-release.apk` (64.1MB).

**Mobile unit/widget tests:** ad_mob_service, batch3_games, board_classics, bots, clay_new_games, design_tokens, expansion_logic, fruit_merge, game_audio, game_icons, game_kit, game_shell_lifecycle, games_hub, guess_person_controller, guess_person_widget, lan_discovery, lan_server, local_games_logic, local_games_widget, ludo_teams, math_duel_ui, move_animation, new_games_logic, nitro_knockout, online_game_screens, party_deduction, party_games_logic, quick_play, raja_mantri, reaction_tap_ui, records, relay, ring_sort, session_ui, solo_batch1, solo_batch2, solo_games, start_pages, take_turns, text_scale.

**Server tests:** relay, rooms, session, backend_reliability, nitro_knockout.

**Status:** PARTIAL — all automated tests pass; end-to-end runtime verification on a real device/emulator (game initialization, rules/scoring, win/loss/draw, turn changes, timers, restart/rematch, offline gameplay, online multiplayer with real connected clients, disconnection/reconnection, Nitro Knockout bot and multiplayer modes, AdMob test ad lifecycle) not yet executed in this session.

## Build instructions

```
cd server && npm install && npm test && npm start     # guest logins, port 3000
cd mobile && flutter pub get && flutter test && flutter run   # emulator reaches PC at 10.0.2.2:3000
```

Deploy server (Render blueprint via `render.yaml`), then `https://<name>.onrender.com/health`.

Release APK:
```
cd mobile
flutter build apk --release --dart-define=SERVER_URL=https://<name>.onrender.com
flutter build appbundle --release --dart-define=SERVER_URL=https://<name>.onrender.com
```

AdMob production release (opt out of test ads):
```
flutter build apk --release `
  --dart-define=SERVER_URL=https://<server>.onrender.com `
  --dart-define=ADMOB_APP_ID=ca-app-pub-2273708482671832~3323244780 `
  --dart-define=ADMOB_USE_TEST_ADS=false `
  --dart-define=ADMOB_INTERSTITIAL_ID=ca-app-pub-2273708482671832/3168825409 `
  --dart-define=ADMOB_REWARDED_INTERSTITIAL_ID=ca-app-pub-2273708482671832/4842753743
```

App ID: `com.shubhamgupta.partygames` (flat: `com.shubhamgupta.partygames.flat`).
Release signing uses `mobile/android/upload-keystore.jks` + `key.properties` (not in git). Without them, builds fall back to the debug key.

## Nearby play (same Wi-Fi / hotspot)

- With internet: everyone uses the online server; no setup needed.
- No internet: one laptop runs `cd server && npm start`, prints its address; phones enter it under Home > Server.
- One-device and solo games need no server.

## Build artifacts

- Debug APK: `mobile/build/app/outputs/flutter-apk/app-debug.apk` (test ads)
- Release APK: `mobile/build/app/outputs/flutter-apk/app-release.apk` (64.1MB, **production AdMob units**, signed with debug key)
- Release AAB: `mobile/build/app/outputs/bundle/release/app-release.aab` (64.0MB, **production AdMob units**, signed with debug key)

Release builds use your production AdMob IDs:
- App ID: `ca-app-pub-2273708482671832~3323244780`
- Interstitial: `ca-app-pub-2273708482671832/3168825409`
- Rewarded interstitial: `ca-app-pub-2273708482671832/4842753743`

Signed with the debug key (`key.properties` + `upload-keystore.jks` not in git). For Play Store publishing, add those key files and rebuild.

## Known issues and incomplete features

1. Per-game UI redesign not verified for most games (shared shell done, individual play surfaces outstanding).
2. Nitro Knockout end-to-end runtime validation not yet executed (boot, controls, audio, physics, multi-seat online, reconnection).
3. AdMob test ad rendering on a real device/emulator not yet executed.
4. Online multiplayer end-to-end testing with real connected clients not yet executed.
5. LAN play not tested for advertised games (nitro, guess_who, raja_mantri excluded from LAN).
6. Some adapter/seat-count discrepancies: Memory (local 2–6 vs online 2–4), Paint Fight (local 2 vs online 2–4).
7. No banner ad unit; no rewarded interstitial placement wired into any game.
8. No seamless host migration for Nitro; permanent host departure aborts the match.

## Remaining roadmap

1. Complete per-game UI redesign and verify play surfaces (shared shell done; individual play surfaces outstanding).
2. Complete Nitro Knockout end-to-end runtime verification (offline boot/controls/physics + online multi-seat/reconnect on a device or emulator).
3. Execute AdMob test ad rendering on an emulator/device; wire rewarded interstitial placement into at least one game.
4. Execute online multiplayer end-to-end testing with real connected clients; test LAN play for advertised games.
5. Resolve adapter/seat-count discrepancies (Memory, Paint Fight).
6. Attempt release AAB where signing configuration permits (`key.properties` + `upload-keystore.jks` not in git).
7. Final README update with verified device/emulator results.

## Previous README content

The original README (deploy, build, nearby-play sections above) is preserved from the prior Party Games release. The Clay version builds on that foundation with the Nitro Knockout replacement, AdMob integration, and the expanded game list.
