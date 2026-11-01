# AdMob test results

## Integration

- Google Mobile Ads Flutter plugin: `google_mobile_ads: ^5.3.1`; dependency resolution succeeded.
- Android app ID: configured in the application manifest.
- Standard interstitial: user-provided unit in release; Google's test interstitial unit in debug.
- Rewarded interstitial: user-provided unit in release; Google's test rewarded-interstitial unit in debug.
- UMP consent info refresh and required form run before SDK initialization/ad requests. Privacy options are exposed from the Privacy screen.
- SDK initialization is shared and asynchronous relative to first screen rendering. Ads share a single full-screen lock. Failed/unavailable ads allow the caller to continue. Standard interstitial is limited to one per three minutes and only offered at completed-match Rematch. Rewarded flow requires a disclosure/skip prompt; the callback is guarded against duplicate invocation and called only from `onUserEarnedReward`.

## Runtime test matrix

| Check | Status | Evidence |
|---|---|---|
| Dependency resolution | PASS | `flutter pub get` resolved version 5.3.1. |
| Android App ID configuration | PASS | Manifest contains the supplied app ID. |
| Separate format/unit configuration | PASS | Separate IDs and load handlers in `AdMobService`. |
| Test ad IDs in debug | PASS (source) | Google's official test units selected under `kDebugMode`. |
| SDK initialization / consent form | NOT CONFIRMED | App startup reached guest setup on Android 16; no consent or SDK callback logs captured. |
| Standard interstitial load/show/dismiss/failure | NOT TESTED | No emulator impression or callback log collected. |
| Rewarded callback integrity/deduplication | NOT TESTED | No SDK callback runtime was available. The callback is guarded in source. |
| Offline/no-fill/retry behavior | NOT TESTED | Device network scenarios not run. Errors are logged and ads are optional. |
| Frequency / overlap | PASS (source only) | Shared `_showing` lock and three-minute standard cap; runtime not exercised. |

The rewarded-interstitial display and reward claims are not represented as tested. Google's guidance requires test ad units during development and a clear reward disclosure with a skip option; implementation follows those requirements. Production impression behavior was not exercised. Flutter analyze and the full 948-test Flutter suite pass; the debug APK was rebuilt. The final rebuild's emulator install was attempted but the install command stalled, so the captured startup screenshot is from the previous successful emulator launch.
