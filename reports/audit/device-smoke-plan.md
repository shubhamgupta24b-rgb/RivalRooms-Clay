# Native device game smoke preparation

## Status and installation gate

**Prepared, formatted and source-analyzed only. No device execution, build, install,
uninstall, data clear, or signing change was performed for this harness.**

Target supplied by the coordinator: authorized I2409, Android 16,
serial `10BF6U1LAX001TD`.

The application package **must remain `com.shubhamgupta.partygames`**. The
coordinator reports that the existing installed application and the current debug
build have different signing certificates. Do not attempt the command below yet.
The parent is comparing release signing; execution requires a certificate matching
the installed package and explicit parent permission. Do not work around the
mismatch by uninstalling, clearing data, renaming the package, changing signing,
or installing a second application ID. The integration harness produces a test
app using the existing application ID and can replace the installed application
when Android accepts the signer. In-memory preferences do not bypass Android's
installation/certificate rules or protect against an external uninstall.

## Owned changes

- `mobile/integration_test/game_device_test.dart`: native integration binding,
  per-game cases, stage logging and structured `binding.reportData`.
- `mobile/pubspec.yaml`: only add `integration_test: {sdk: flutter}` under
  `dev_dependencies`; preserve all existing dependencies and other sections.
- `reports/audit/device-smoke-plan.md`: this preparation and execution plan.

`flutter pub get` also regenerates dependency artifacts (`pubspec.lock`,
`.flutter-plugins-dependencies`, and ignored package configuration). Its six new
resolved packages are `integration_test`, `flutter_driver`,
`fuchsia_remote_debug_protocol`, `process`, `sync_http`, and `webdriver`. These
are SDK integration-test dependencies, not production dependency changes. No
Android, package, signing, or game implementation files were edited.

## Inventory and selection

The test reads the current `localGames` registry rather than freezing a title
list. Currently there are 70 registry entries, 69 visible after `!remoteOnly`:

- 68 non-Nitro shell cases scheduled by default.
- Nitro Knockout registered as a separate `nitro`-tagged case, skipped by default
  and excluded from the planned command. Parent owns its native verification.
- Colour Clash excluded because it is `remoteOnly`.
- One initial hub/gallery render and metadata case.
- Two special cases: Guess the Person and Raja Mantri Chor Sipahi.

Thus the default non-Nitro selection is **71 cases**, not 71 complete game-rule
validations. Registry changes automatically update the selection. Gallery
metadata includes every visible shell entry (including the parent-owned Nitro),
ID, title, player bounds, solo/split-screen flags, and take-turns availability.
Each executed case records actual device dimensions and pixel ratio; no
320-pixel constraint, synthetic viewport, or pixel-ratio override is applied.

## What each shell case does

1. Mount the real `LocalGameShell` with the normal app theme, directly, without
   booting login, auth restore, sockets, matchmaking, or ad initialization.
2. Check initial render exceptions; log metadata. Inspect `GameIntro.players`
   and select the game's minimum player count with the existing keyed stepper if
   necessary. Fixed-count and solo intros need no artificial stepper.
3. If take-turns mode is offered, select **Split screen** so the actual game
   renderer is exercised instead of only a `START` handoff card. This deliberately
   does not cover the take-turns alternate flow, teams, bots, or maximum players.
4. `ensureVisible` the actual **Start** control, check it is hit-testable, then
   tap it. For games showing 3-2-1, pump 3.2 seconds in bounded 50 ms frames. The
   current countdown implementation is 3 × 700 ms plus 450 ms GO, followed by
   transition time. Solo games deliberately bypass the countdown.
5. Require departure from the shell intro/countdown, accepting either the play
   subtree or a result. Do not require an actively running match: solo title,
   ready, first-tile, or tap-to-start controls can still be present.
6. Deliver one bounded tap inside the play subtree, avoiding navigation labels,
   complete round/navigation buttons, their custom gesture ancestors, and text
   input. This is input-delivery smoke, not a guaranteed legal move or proof of
   a score/running solo timer. If no guarded point is available, log
   `input-not-exercised`; if the game already ended, log that explicitly. Never
   use generic Back/Exit/Quit/Rematch input.
7. If a visible, hit-testable `PauseButton` exists, tap it, require `PauseSheet`
   and the real `GamePause` notifier to be true, then tap the **Resume** button
   inside that sheet. Require dismissal and an unpaused notifier unless a result
   arrived. Games that have ended or screens without a pause button log
   `pause-not-exercised`, not fabricated pause/resume success.
8. Observe another bounded interval, recording `result-observed` or
   `play-or-title-observed`. Dispose the entire widget/Navigator tree in a
   `finally` block, pump trailing frames, and check disposal exceptions.

`tester.takeException()` is drained and asserted empty at initial render,
start/countdown, input, pause, resume, body completion, and disposal as applicable.
There is no `pumpAndSettle` on perpetual animations and no unbounded wait loop.
Every shell case has a two-minute timeout.

## Special menus

- **Guess the Person:** render PLAY / HOW TO PLAY / SETTINGS, tap PLAY, enter
  START CHOOSING, tap RANDOM and check a selected-person label. Dispose the menu
  and pushed game route. This does not confirm a character, ask questions, play a
  full round, or validate the rules/settings/help routes.
- **Raja Mantri:** render four player fields, tap Deal the cards, observe the
  initial game/deal with four players, then dispose. No full role-peek, accusation,
  score, or match validation is claimed.
- Neither special menu is falsely treated as a shared-shell pause/resume flow.

## Data, platform, and evidence boundaries

Preferences alone are replaced with `SharedPreferences.setMockInitialValues({})`
inside the test process. This prevents result/level persistence from overwriting
existing records and avoids reading saved login state. No real preference store
is cleared or backed up/restored. This **does not test native preference
persistence or migration**. Audio/settings initialization reads that isolated
store, while Android audio/device/haptics channels remain real. No fake WebView,
mock platform view, synthetic game logic, or authentication provider is installed.
The harness rejects web/non-Android targets.

This is an offline local-widget/native-channel harness, not the full production
startup path. Existing ad/plugin manifests and platform registration are unchanged;
the harness itself does not initialize ad or login/network services. Native audio
and haptics may occur. Flutter exception checks do not establish audibility,
visual correctness, frame performance, absence of native-process crashes, WebView
WASM readiness, or correctness of every game rule.

Stages are printed as `DEVICE_SMOKE <id> <JSON>` and final per-case records as
`DEVICE_SMOKE_RESULT <JSON>`. The binding also holds gallery metadata, excluded
remote entries, and executed cases in `reportData`. Standard `flutter test`
console output is the primary evidence for the command below; do not assume a
separate reportData JSON artifact is automatically written without a driver.
A case status of `passed` means its smoke assertions passed. Review its events:
`input-not-exercised` / `pause-not-exercised` are coverage gaps, not evidence that
those actions worked. Absence of a final record is incomplete execution, not a
pass. Do not mark any game hardware-tested until the coordinator runs it and
retains the resulting output.

## Planned command — NOT RUN; parent permission and matching signer required

From `mobile`, once both gates are satisfied:

```sh
flutter test integration_test/game_device_test.dart -d 10BF6U1LAX001TD --exclude-tags nitro --reporter expanded
```

This standard command uses the project's default test build mode/signing and is
**currently blocked by the reported debug certificate mismatch**. It is not a
recommendation to retry that mismatched install. The parent must first confirm a
supported invocation/build mode using the existing matching signing configuration;
this preparation does not guess that release signing matches or change it.

Useful later selections, subject to exactly the same installation gate:

- `--tags local_shell`: only the 68 non-Nitro shell cases.
- `--tags special_menu`: only the two special menu cases.
- `--plain-name "device_smoke shell ludo"`: a specific title (use its registry ID).
- `--tags gallery`: initial hub/metadata only.

Nitro remains skipped unless `--dart-define=DEVICE_SMOKE_NITRO=true` is explicitly
supplied. Even opted in, this generic case is only shell smoke, not a native
WebView boot/readiness, driving, WASM, or result validation; the parent's dedicated
Nitro testing is separate. No Nitro execution was attempted here.

## Preparation validation

Ran on the host only:

```sh
flutter pub get
dart format integration_test/game_device_test.dart
flutter analyze --no-pub integration_test/game_device_test.dart
```

Dependency resolution succeeded. Targeted analysis reported **No issues found**.
A source-only registry count confirmed 70 entries / 69 visible / 68 non-Nitro.
No device test, host widget test, APK build, installation, uninstall, package
change, signing change, or data-clear command was run for this preparation.
