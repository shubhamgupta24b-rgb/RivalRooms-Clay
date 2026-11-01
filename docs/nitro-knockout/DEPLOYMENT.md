# Nitro Knockout: deployment, provenance, and validation

This describes the **current `clay/new-games` checkout**, inspected on 2026-10-30.
It supersedes the deployment guide inside the supplied ZIP. In particular, this
checkout does **not** use an HTTPS Android asset server, migrate a live simulation
host, or contain the complete TypeScript source of the supplied online bundle.

Nitro remains the original 3D **arena kart-combat** game: weapons, 100 HP,
knockouts, respawning, and a 90-second match clock. It is not lap racing.

## What runs where

| Component | Checkout location | Responsibility |
| --- | --- | --- |
| Bundled game | `mobile/assets/nitro/index.html`, `assets/index-CejRMBG2.js`, `assets/index-CiJwpIAO.css` beneath that directory | React shell, Three.js rendering, synthesized WebAudio, and Rapier physics; WASM is base64-inlined in JS |
| Flutter integration | `mobile/lib/features/local_games/nitro_knockout/` | Android WebView, explicit boot, bridge, offline results, online roster/input/state delivery |
| Dedicated game protocol | `server/src/games/nitro_knockout.js` | Snapshot/input validation, host publication, terminal-score consistency, results |
| Shared lifecycle | `server/src/rooms/RoomManager.js` and existing mobile room/session/shell code | Ready/start, roster, grace reconnect, permanent-leave abort, results/rematch |

`mobile/pubspec.yaml` explicitly bundles both asset directories. The game view
uses `loadFlutterAsset('assets/nitro/index.html')`; the Android file location is
`file:///android_asset/flutter_assets/assets/nitro/index.html`, **not**
`https://appassets.androidplatform.net/...`. Top-level navigation is restricted
to the Nitro asset path. No local HTTP server or new manifest change is needed
for the assets. The self-contained JS has no module imports or `import.meta`;
loading it as a **deferred classic script** avoids file-origin ES-module CORS
restrictions. The CSS has no external resource URLs. The game assets themselves
need no CDN/WASM download; this does not promise the rest of the app is network-free.

The frontend is deliberately **Android only**, requiring a functioning Chromium
WebView with WebGL 2 and WebAssembly. Other platforms show an explicit fallback
without constructing a WebView, so ordinary widget suites do not need a global
WebView fake. Desktop Chrome below is a test harness, not a shipped desktop/web port.

## Offline and online restrictions

### Offline

Open Nitro from the local-games hub. The roster is **one human plus seven named
bots**: NOVA, BOLT, ROOK, JINX, MISO, APEX, ECHO. Offline arena selection retains
Foundry, Cove, and Lunar. No game server or game account is required for this
mode. The bridge reports the human's KO score to the existing Flutter shell.

The Flutter `GamePause.maybeOf(context)` notifier and app visibility pause/resume
only offline simulation. The existing `__nitroDebug` API is used for that bridge.
Shared `GameAudio.settings` controls music, music volume, and SFX independently;
engine sound follows the SFX switch. The game's own mute remains an additional
mute. These integrations do not replace shared shell/audio code.

### Internet rooms

- Use the dedicated `nitro_knockout` game, not generic `RelayPlay`/`relay:*`.
- Exactly **2–10 room participants** become human-controlled seats in server
  roster order. There is no AI filling to eight or ten. Offline bots do not
  become online participants.
- All online clients boot **Foundry**, overriding independently saved offline
  arena preferences. There is no synchronized online arena selector.
- The host starts combat with the engine's PLAY control. Its WebView simulates
  all seats; guest engines predict locally and render received host snapshots.
- Room creation permits capacity ten in online mode, six in Wi-Fi/LAN mode.
  Individual games still enforce their own start limits. Nitro is in
  `LanHost.internetOnly`: **phone-hosted LAN does not implement its protocol**.
- Game labels are sanitized for the original HUD and bounded to 24 UTF-16 code
  units. Identity prefers optional shared `room.myId`, then `socket.userId`;
  older managers use an explicitly checked `dev:` token fallback. JWT/Firebase
  bearer tokens are not split into guessed user IDs.

The shared mobile `AuthenticationManager` in this checkout is still dev guest
auth. The server can verify Firebase tokens, but this is **not** an end-to-end
production Firebase-auth implementation. Nitro's identity adapter does not
complete that shared authentication work.

### Ordering, reconnect, and trust

`NitroTransport` allows one action request in flight. It coalesces pending live
frames/inputs, retains terminal publication, and retries `OFFLINE`, `TIMEOUT`,
and `RATE_LIMITED` responses with a 350 ms delay. Finish waits for acknowledgement
of a terminal snapshot with `time: 0`, `over: 1`; finish scores must match every
seat in that accepted frame. Engine-bound inputs/snapshots wait for readiness.
The host acknowledges a queued input only after the JS input API reports that
it accepted the injection. This is delivery handling, **not an exactly-once or
cheat-proof simulation protocol**.

A transient transport disconnect preserves the existing WebView. Server grace
is configured by `RECONNECT_GRACE_MS` (default 60,000 ms). **There is no seamless
host restoration or live host migration.** Snapshots omit sufficient velocity,
RNG, cooldown, ownership, and other world state for faithful restoration. If a
host screen is recreated with prior accepted state, it refuses to start a fresh
simulation; engine/context loss is surfaced instead of silently resetting the
match. Start a new match after leaving/returning to the lobby. Permanent departure
of **any** participant, including grace expiry, aborts active fixed-roster play.

The backend is authoritative about protocol/room/result consistency, **not
secure host physics**. A modified host can fabricate a mutually consistent clock,
world, and scores or ignore inputs. Validation does not prove collisions, legal
movement, honest KOs, real elapsed time, input application, or competitive fairness.
See [the backend audit](../../reports/audit/nitro-backend-current.md) for limits,
including queue bounds, outer action sequences, and lack of a round-bound replay ID.

## Provenance and asset identity

Two distinct supplied references were inspected, without modifying either:

1. `C:/Users/sg857/Downloads/Two-player-online-nitro-knockout-420626f.zip`:
   source of the integrated **online-capable compiled JS**, HTML/CSS, and three
   initial Dart files. Its filename suffix is not a verified source commit ID.
   No archive-wide patch was applied to the edited checkout.
2. `C:/Users/sg857/Downloads/Kimi_Agent_End-to-End WebAssembly Game/app`:
   original **offline** source and credits. It establishes original mechanics
   and attribution, **not the archive's online implementation source**.

SHA-256 identities (raw file/member bytes):

| Item | SHA-256 |
| --- | --- |
| Supplied online ZIP | `e73a823b144af84817276b10c02c537c0f8d8e95eac80cd80898f3ea68d02f84` |
| ZIP `repo/mobile/assets/nitro/index.html` | `dda3ce5c94c03e710ed67fea088d8f1c2ee1c89c14918617e2a6f013a86ea08f` |
| ZIP `repo/mobile/assets/nitro/assets/index-CejRMBG2.js` | `59f45677bed75c513c38a17a54cd5871e8a11b3f087da09aad9fc62072c28be9` |
| ZIP `repo/mobile/assets/nitro/assets/index-CiJwpIAO.css` | `4bd0e39387d5e6a6b7975180fb1e8d5f08d7d57a61f41703c0aad84e25333b78` |
| Adapted checkout `index.html` | `e495743bc40815e7956d3d0d1c6e306f102e1152a9a0d2e9044e68ad65bf83d9` |
| Adapted checkout `assets/index-CejRMBG2.js` | `d9b75578f95029a517a3379c388d95c8ec5030332da7e96c280a2b205d85314a` |
| Checkout CSS (unchanged) | `4bd0e39387d5e6a6b7975180fb1e8d5f08d7d57a61f41703c0aad84e25333b78` |
| Offline source `src/game/game.ts` | `3a97b69f635dc0371ad082ea160e4c35fcacd17bd2409d39c76ec2a3628cbb80` |
| Offline source `CREDITS.md` and verbatim copy here | `034e83dbc05d74ef4b05e885696ca550afb794fa6b939a8ac240a5faf7d135c0` |

Hashed JS/CSS filenames were retained from the supplier; **the JS filename is not
an updated content hash after adaptation**. Use the SHA-256 table/recipe, not its
filename, to identify the adapted build.

### Complete modifications to supplied JS

[The executable recipe](reproduce_assets.py) records exact before/after strings
and enforces exactly one match per change. It reproduces the entire adapted JS,
not just selected snippets:

| Recipe ID | Modification |
| --- | --- |
| J1 | Use Flutter `NitroBridge.postMessage`, not `post`, and supply the channel offline too so results reach Flutter |
| J2 | Remove automatic offline initialization and four-second fallback boot; wait for Dart's explicit boot options |
| J3 | Render the game component directly instead of matching only route `/`, which excluded Android's asset file path |
| J4 | Extend existing `__nitroDebug` with `audioSettings` and `dispose`; retain original debug controls |
| J5 | Add `appMusic`, `appSfx`, and `appVolume` audio defaults |
| J6 | Gate synthesized effects on app SFX preference |
| J7 | Gate synthesized engine sound on app SFX preference |
| J8 | Gate music independently on app music preference |
| J9 | Apply app music volume to its gain, preserving the positive floor required by exponential gain ramps |
| J10 | Return true only after a valid remote-seat input enters the live host engine's input map; reject wrong mode, disposed engine, invalid/local seat, or invalid arguments with false |

HTML changes: H1 switches the external module script to `defer` classic JS and
removes its `crossorigin`; H2 removes CSS `crossorigin`; H3 adds forwarding for
page errors, unhandled rejections, and WebGL context loss. The Windows edits also
converted JS and HTML line endings to **CRLF**. CSS is byte-for-byte unchanged.
No simulation constants, weapon definitions, physics implementation, WASM bytes,
bot AI, or game geometry were deliberately replaced. The complete recipe and
output hashes constrain that statement; the archive already contained online
simulation and synchronization code.

### Reproduce without overwriting anything

Python 3 standard library only. From the repository root, verification is read-only:

```text
python docs/nitro-knockout/reproduce_assets.py C:/Users/sg857/Downloads/Two-player-online-nitro-knockout-420626f.zip
```

To generate the three adapted assets separately, pass `--output` with a **new,
not-yet-existing directory**. The recipe refuses an existing destination, checks
the ZIP and member hashes before writing, and never extracts other archive paths:

```text
python docs/nitro-knockout/reproduce_assets.py C:/Users/sg857/Downloads/Two-player-online-nitro-knockout-420626f.zip --output C:/Users/sg857/Downloads/nitro-reproduced
```

The example output directory must not already exist. Review generated bytes
before any deliberate promotion into an edited checkout. The recipe emits the
current Windows CRLF identity consistently on all hosts; a checkout normalized
to LF will not match these **raw-byte** hashes. Do not silently bless different
assets by changing hashes without reviewing the differences. Verification/new
output/no-overwrite checks are recorded in
[the reproduction log](../../reports/audit/logs/current-nitro-assets.log).

**Do not run `npm run build` in the offline source and claim it rebuilds this
online bundle.** That source lacks the supplied online implementation. Rebuilding
it produces an offline build, not a substitute for the patched online artifact.
Obtain/maintain the matching online source before attempting a real source
rebuild; otherwise use the pinned artifact plus reviewed recipe. Do not copy an
entire archive or generated offline `dist/` over the existing project.

## Credits and redistribution

[ORIGINAL_CREDITS.md](ORIGINAL_CREDITS.md) is copied **verbatim** from the supplied
offline source; its SHA-256 is recorded above. It attributes procedural kart
models, arenas, UI, effects, and synthesized audio to Nitro's original content,
and names these libraries/licenses:

- **Three.js** — MIT; WebGL rendering.
- **Rapier** / `@dimforge/rapier3d-compat` — Apache-2.0; WASM rigid-body physics.
- **React** — MIT; application shell.
- **Vite** — MIT; build tooling, not a required deployed game server.

The supplier says this is an original game inspired by kart-combat mechanics,
not Smash Karts assets/source. That attribution is preserved, not independently
certified as an ownership/legal finding. Neither the supplied credits nor the
inspected `package.json` grants a license to the **original game content/code**;
do not infer that it is MIT-licensed merely because dependencies are. Confirm
redistribution rights before public distribution.

The online artifact also contains React Router code; the supplied credits are
not a complete dependency/notice inventory. The three supplied asset files do
not include a complete set of upstream license texts/copyright notices. Before
distribution, identify exact online-build dependency versions and include their
required notices and license texts (MIT, Apache-2.0 and any other applicable
terms) in the distribution's notices mechanism. Offline `package-lock.json` is
not proof of the online artifact's complete dependency versions. Copying credits
here preserves attribution; it is **not** a completed license-compliance audit
or a new license grant. License text references:
[MIT](https://spdx.org/licenses/MIT.html),
[Apache-2.0](https://spdx.org/licenses/Apache-2.0.html).

## Deploy and validate this checkout

Nitro adds no API key, CDN, Rapier service, or separate game server. Use the
existing Node server with the dedicated module registered in its game registry.
From the repository root, the existing scripts are:

```text
npm --prefix server ci
npm --prefix server test
npm --prefix server start
```

`start` runs indefinitely and is a deployment step, not part of the browser probe.
Read `server/src/config.js` and `server/src/auth/verify.js`: `PORT` defaults to
3000, `AUTH_MODE` defaults to dev, `MONGO_URI` is optional configuration, and
Firebase verification uses `firebase-admin`. Keep Firebase/admin credentials
server-side. Production rejects dev auth unless explicitly overridden with
`ALLOW_DEV_AUTH=true`; that escape hatch is for temporary test deployments,
**not secure production identity**. Use an appropriately secured server/auth
configuration and TLS endpoint for real internet play.

The mobile internet endpoint is `SERVER_URL` at build time; its current fallback
`http://10.0.2.2:3000` targets an Android emulator's development host and is not a
physical-device production address. The parent owns final APK configuration,
ads, signing, README links, and builds. No APK/build result is claimed by this
validation pass. Do not regenerate or overwrite the existing edited Android
project just to add Nitro.

### Actual browser execution

From `mobile/`, using an existing desktop Chrome executable (no npm/browser
download required):

```text
node test/nitro_asset_smoke.cjs "C:/Program Files/Google/Chrome/Application/chrome.exe"
```

The probe uses Node's standard library and Chrome's DevTools pipe, launches an
isolated temporary profile with headless/SwiftShader flags, reads the existing
bundle's engine fields without modifying it, and loads the actual assets from
**file URLs**. It closes pages between cases. It uses **one host page and one
guest page per roster size**, relaying selected real engine messages through
CDP; it does not instantiate N independently connected clients.

The completed run is captured in
[`current-nitro-browser.log`](../../reports/audit/logs/current-nitro-browser.log).
It exited **0** on 2026-10-30 with Node **v22.20.0**, Windows x64, and Chrome
**156.0.8078.48**. The log records runtime versions, asset hashes, movement,
checked frame counts, and final scores:

| Roster | Guest seat tested (zero-based) | Backend-valid live frames checked | Final host/guest terminal scores |
| --- | --- | --- | --- |
| 2 humans | 1 | 16 | `[0,1]` |
| 4 humans | 3 | 15 | `[0,1,0,0]` |
| 8 humans | 7 | 15 | `[0,1,0,0,0,0,0,0]` |
| 10 humans | 9 | 17 | `[0,1,0,0,0,0,0,0,0,0]` |

For **each** online roster it asserts:

1. Host and guest modes/seats, exact participant names/order, and exactly N
   karts, with no additional bot filling. `isPlayer` is only the engine's
   local-control flag, not a claim that other online seats are bots.
2. A keyboard event in the guest produces a real input bridge message; replaying
   that input to the host is accepted, stored for the correct seat, and produces
   more than 0.25 m of host-simulated planar movement. Local-host and out-of-range
   seat injections are rejected.
3. The match clock advances and live frames pass the current backend's
   `validateSnapshot` envelope validator.
4. Eliminating a kart through the existing debug API awards a knockout.
5. A validated terminal `time: 0`, `over: 1` snapshot immediately precedes the
   single finish message, whose scores exactly match all terminal kart rows.
   Applying that terminal frame ends the guest match and gives the same score
   vector and guest result score.

The same run checks offline's one-human/seven-named-bot roster, eight-kart engine,
start/pause/resume, audio-settings bridge invocation, and result delivery.
The original engine is executed, but elimination and early match completion are
**debug-driven**; these are not natural weapon-hit or full 90-second endurance
runs. Frame counts and movement are correctness observations, **not performance
benchmarks**. This probe also bypasses Flutter's native bridge/transport: it does
not test Android touch input, audio audibility, WebView configuration, Socket.IO,
TLS, reconnect timing, packet loss, or real internet/mobile-device gameplay.

### Other evidence and remaining work

- Earlier focused Flutter validation passed **13 Nitro tests** and targeted
  analysis. This browser/doc-only pass does not rerun or modify Flutter code,
  pubspec, or shared tests.
- Parent-owned full Flutter results show **1018 passed** in
  [`current-flutter-test-final.log`](../../reports/audit/logs/current-flutter-test-final.log);
  parent analysis reports no issues in
  [`current-analyze-final.log`](../../reports/audit/logs/current-analyze-final.log).
  Those are separate existing results, not browser-probe results or new runs here.
- Existing backend validation records **115 passing tests**, including real
  ten-client Socket.IO coverage; see
  [`current-server-test.log`](../../reports/audit/logs/current-server-test.log)
  and [the Nitro backend audit](../../reports/audit/nitro-backend-current.md).
  That transport test does not become a ten-device renderer test.
- The reproduction checks passed read-only verification, generation into a new
  temporary directory, refusal to overwrite an existing output directory, bad
  ZIP rejection before extraction, and unchanged source/current asset hashes.
  Credits were verified byte-for-byte against the supplied original.

**Native/runtime unknowns for this pass:** Android WebView file loading and
WebGL/WASM compatibility on the connected phone, on-screen controls, audio focus
and audibility, process death/context loss on hardware, real-device multiplayer
and reconnect behavior, background host scheduling, thermals, ten-device render
performance, and long-duration stability. The parent owns native validation and
final builds; a connected phone alone is not a recorded test result. Licensing
and production authentication also remain release considerations above.

This validation/documentation pass changed the browser probe and added these
Nitro docs/credits/reproduction records only. It did not change Flutter source,
pubspec, the deployed game assets, or the downloaded originals, and did not run
device commands or make an APK/native-gameplay claim.
