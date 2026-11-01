# Initial baseline

## What was observed

- Branch `clay/new-games`; extensive user changes were already present before edits (219 tracked files modified and multiple untracked additions).
- `flutter --version`: PASS — Flutter 3.47.6 stable, Dart 3.13.5, Java 17.
- Initial source inspection found no `google_mobile_ads` dependency or AdMob manifest metadata.
- Smash Karts was present in the mobile online catalog, featured selection, local registry, art/audio, server relay list, and tests.
- Source scan found client tokens shaped as `dev:<uid>:<name>` and a server dev-mode verifier that accepts that format without a signature. `server/src/config.js` rejects this mode only when `NODE_ENV=production` unless explicitly overridden. LAN independently accepts the same unsigned token format.
- No test run occurred before edits; no pristine baseline can be reported because the starting worktree was already heavily modified.

## Tool results

- `flutter pub get`: PASS after approval; resolved `google_mobile_ads 5.3.1` and updated `mobile/pubspec.lock`.
- Post-change `flutter analyze`: PASS, no issues found.
- Initial Flutter test run: FAIL, 21 failing tests in the pre-existing broad suite plus the newly added search absence test; that new test's query assertion was corrected and the suite is being rerun.
- Flutter Doctor: Flutter and network checks pass; Android SDK 36.1/emulator 36.3.10 detected; Android licenses are not accepted. Visual Studio components are missing (not applicable to Android build).
- Initial `npm test` could not run because PowerShell execution policy blocks `npm.ps1`; direct `node --test` initially found a stale expected count (fixed), then passed 86/86.
- Existing emulator AVDs: `Medium_Phone_API_36.1` and `Player2_API_36`; the first was launched and appeared as `emulator-5554` in `flutter devices`.
