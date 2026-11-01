# RivalRoom AdMob, game removal, and startup audit

Date: 2026-10-24

## Summary

- The startup path had unbounded work before the first Flutter frame and an unbounded saved-player restore before leaving the splash. Those paths could leave the app on its splash screen if platform preferences or LAN startup stalled. The app now renders immediately, runs optional startup services in the background with timeouts and diagnostics, and falls through to guest setup if saved-player restore fails or times out.
- The reported original stall was not reproduced as an exact failure: no app recording or original device log was available in the repository. On the current debug build, the emulator reached the first-run guest setup screen. The emulator then reported that Android System UI/Pixel Launcher was not responding, which prevented further runtime navigation.
- The user worktree already contained an AdMob manager, the manifest App ID, match-break placement, and Smash Karts removal when this audit began. I preserved that work and completed the configuration, timeout/privacy handling, and regression coverage described below.

## Startup cause and evidence

`mobile/lib/features/splash/splash_screen.dart` previously waited on `AuthenticationManager.restore()` with no timeout or error handler before choosing Login or Home. The restore calls `SharedPreferences.getInstance()` and reads saved values. If that platform future never completed, neither route was reached. `mobile/lib/main.dart` also awaited configuration, audio preferences, app settings, and (when hosting) LAN startup before calling `runApp()`.

This is the code-level failure mechanism consistent with the purple splash symptom; the underlying platform failure from the original incident is unverified because its recording/log was not present. The fix calls `runApp()` first, starts configuration/audio/settings/LAN work in the background, limits startup work to three seconds per task, and routes a failed/timed-out restore to guest setup after a two-second maximum. A widget regression test uses an `AuthenticationManager` whose `restore()` never completes and verifies the guest setup route appears.

Runtime evidence from the current build:

- The emulator showed the app's â€œWho's playing?â€ guest setup screen after launch; it did not remain on the purple splash.
- `adb shell am start -W` reported a timeout while Android System UI was unresponsive, but `dumpsys activity` showed `com.shubhamgupta.partygames/com.example.multiplayer_game.MainActivity` as the top resumed activity and the app process remained alive.
- App logcat showed UMP consent initialization timing out after ten seconds. The SDK also logged that no consent form is configured for App ID `ca-app-pub-2273708482671832~3323244780`. The app still rendered the guest setup screen, so this ad-consent issue did not block this launch. Configure the consent message in AdMob Privacy & messaging before production ad requests.
- Further emulator taps, game-selection navigation, and resume testing were stopped because System UI/Pixel Launcher repeatedly reported â€œisn't responding.â€ Automated Flutter tests cover startup routing and home/game navigation, but those later steps were not confirmed on the emulator.

## AdMob

- `google_mobile_ads` is set to `^9.2.0`, the latest stable release checked on 2026-10-24. The project uses Flutter 3.47.6 / Dart 3.13.5, above the plugin's documented minimum.
- Android manifest metadata contains the supplied **App ID** `ca-app-pub-2273708482671832~3323244780` (the `~` form); it is distinct from both supplied ad unit IDs. The manifest has the `INTERNET` permission. The Android debug APK built successfully with the current plugin and Gradle setup.
- Google's sample Android interstitial (`ca-app-pub-3940256099942544/1033173712`) and rewarded-interstitial (`ca-app-pub-3940256099942544/5354046379`) units are the default in every build mode. No automated ad clicking or production impression generation was used.
- Production unit IDs are compile-time configurable with `ADMOB_INTERSTITIAL_ID` and `ADMOB_REWARDED_INTERSTITIAL_ID`. A production release must explicitly pass `ADMOB_USE_TEST_ADS=false` and both production IDs; otherwise test units remain selected. See [docs/ads.md](../../docs/ads.md).
- Consent information refresh, required UMP form presentation, `canRequestAds()` gating, privacy-options visibility, and bounded SDK/consent waits live in `mobile/lib/core/ads/ad_mob_service.dart`. Consent is initialized asynchronously, and ad failure does not gate startup. Ads load in the background and are displayed only at the completed-match Rematch transition, with a three-minute frequency limit and fullscreen disposal/watchdogs.
- The rewarded-interstitial manager requires an explicit reward explanation and Skip/Continue consent and grants only in the SDK's `onUserEarnedReward` callback. No existing game has a suitable optional reward in its current flow, so no game currently invokes the rewarded format.
- Production readiness still needs AdMob Privacy & messaging consent configuration, a privacy policy consistent with the app and SDK behavior, and accurate Google Play Data safety / ads declarations. Those account and store settings cannot be verified from this repository.

## Smash Karts

The existing worktree removal was preserved: the local/online catalogs and server relay registry omit the game, its dedicated game and logic files are deleted, and no active route or menu points to it. Mobile and server tests assert the old ID/name stays out of the catalogs and UI. Active app/server source has no Smash Karts references; intentional negative assertions and historical design/audit documents still mention its former presence. No shared assets were deleted.

## Files changed in this pass

- `mobile/lib/main.dart` â€” render first; start preferences, configuration, and LAN setup asynchronously with bounded failures and diagnostics.
- `mobile/lib/features/splash/splash_screen.dart` â€” bounded restore with login fallback; cancel the delayed spinner timer when the splash is disposed; log connection failures.
- `mobile/lib/core/ads/ad_mob_service.dart` â€” use test units by default, support release IDs via `--dart-define`, bound consent/SDK work, dispose fullscreen ads once, and add display watchdogs.
- `mobile/lib/features/privacy/privacy_screen.dart` â€” render the UMP privacy-options entry point from consent state rather than starting SDK work during widget build.
- `mobile/pubspec.yaml`, `mobile/pubspec.lock` â€” upgrade the official plugin to 9.2.0 and align the Dart minimum with the plugin.
- `mobile/test/start_pages_test.dart` â€” cover an indefinitely stalled saved-player restore.
- `docs/ads.md` â€” document safe test/production configuration and outstanding consent/store setup.

The match-break placement, rewarded callback flow, and Smash Karts catalog/server removal were already present in the dirty worktree at the start of this pass; they were inspected and retained. The pre-existing worktree had extensive user modifications, and none were reverted.

## Commands and results

| Command | Result |
| --- | --- |
| `flutter pub get` (`mobile/`) | Pass; resolved `google_mobile_ads 9.2.0`. |
| `flutter analyze` (`mobile/`) | Pass; no issues found. |
| `flutter test` (`mobile/`) | Pass; 915 tests. Includes the stalled-restore and Smash Karts absence tests. |
| `flutter build apk --debug` (`mobile/`) | Pass in 54.8 seconds after the final startup change. Output: `mobile/build/app/outputs/flutter-apk/app-debug.apk` (201,288,894 bytes; SHA-256 `499BAF66939FBB4336A6F8FA3C28CE6F044C6A614A5802DA15D170F3A9304E30`). |
| `node --test` (`server/`) | Pass; 86 tests. |
| `flutter emulators --launch Medium_Phone_API_36.1` | Emulator process launched; Android initially showed System UI/Launcher not responding. ADB later reported `emulator-5554` ready. |
| `adb install` and `adb shell am start -W` | Debug APK installed. MainActivity remained top resumed and rendered guest setup, although `am start -W` timed out due to emulator system instability. No emulator game-navigation, resume, rewarded-callback, or ad-impression test completed. |

The emulator had a signature-mismatched RivalRoom package. Installing the test build required removing that package variant; this may have reset app-local data in that emulator. No repository data was deleted. No commits or pushes were made.

## Warnings and release risks

- Flutter 3.47.6 warned that Gradle 8.14.3, Android Gradle Plugin 8.11.1, and Kotlin 2.2.20 will soon fall below Flutter's supported minimums. The APK built successfully, but these versions should be upgraded before a later Flutter upgrade.
- `flutter doctor -v` reported unaccepted Android SDK licenses. The requested debug build nevertheless completed.
- AdMob/UMP could not finish consent initialization in the emulator. Logcat reported no consent form configured for the provided App ID. This must be configured and rechecked in an account-controlled test device/network before release.
- No production ad display, reward callback, offline backend recovery on a device, multiplayer session, physical device, app resume, or complete emulator navigation is claimed as tested.
- The original purple-splash incident's exact platform exception remains unverified. The implementation removes the unbounded route gates, and both the regression test and current cold-start screenshot show progress to the guest setup screen.

