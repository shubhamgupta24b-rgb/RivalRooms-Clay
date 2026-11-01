# Repository inventory

## Snapshot

- Branch: `clay/new-games`.
- Recent commits: `c2f0c0e` (Clay UI), `8c99c47` (base), `b0a9b41`, `e036cfb`, `9db1132`.
- The starting tree had 219 modified tracked files and numerous untracked files. These included broad UI, game, test, Android, and server work. All pre-existing changes were treated as user-owned.
- Flutter project: `mobile/` (`multiplayer_game`, version `0.1.0+8`). Node service: `server/` (Express, Socket.IO, Firebase Admin, MongoDB).
- Runtime discovered: Flutter 3.47.6 stable, Dart 3.13.5, Java 17. Node is installed. Android SDK files exist under the user profile but `adb` is not on PATH and direct sandbox access was denied.
- No repository `AGENTS.md` or audit PDF was found in the workspace. The supplied text references a 10-page PDF, but that PDF was not available for inspection.

## Main components

- Flutter navigation and state: `mobile/lib/main.dart`, `mobile/lib/features/`, `mobile/lib/core/`.
- Online game definitions: `mobile/lib/games/game_catalog.dart`; local game implementations and shared shells: `mobile/lib/features/local_games/`.
- Socket, auth, room/session and LAN protocol: `mobile/lib/core/{auth,lan,network,room,session}/`.
- Cloud server: `server/src/{sockets,rooms,games,auth,database}/` with tests in `server/tests/`.
- Android manifest and Gradle config: `mobile/android/app/src/main/AndroidManifest.xml`, `mobile/android/app/build.gradle.kts`.
- Android upload key and key properties are present locally; their contents were not read or copied into reports.

## AdMob changes

Added `google_mobile_ads` 5.3.1 (Dart 2.17 compatible), Android app ID metadata, and `mobile/lib/core/ads/ad_mob_service.dart`. Debug uses Google's test units; release selects the user-provided production units. Google UMP is used before ad requests. More details and unverified runtime behavior are in `admob_test_results.md`.

## Evidence limits

The application contains substantial changes predating this task, so there is no clean-tree baseline. Flutter commands need user-profile SDK cache access; `flutter pub get` succeeded after approval. Emulator access and real ad delivery remain to be checked. No cloud deployment, credentials, or environment secrets were inspected.
