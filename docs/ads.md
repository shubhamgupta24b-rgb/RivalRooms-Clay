# AdMob configuration

RivalRoom reuses Google's official `google_mobile_ads` Flutter plugin (locked to
9.2.0). Android is the only enabled platform. The existing manifest metadata
`com.google.android.gms.ads.APPLICATION_ID` uses `${googleMobileAdsAppId}`;
`mobile/android/app/build.gradle.kts` supplies its value from `ADMOB_APP_ID`,
defaulting to **`ca-app-pub-2273708482671832~3323244780`**. This App ID (`~`) is
not an ad unit ID (`/`). No Android configuration changes were needed.

| Build mode | Ad units |
| --- | --- |
| Debug / profile | Always Google's test units, even with `ADMOB_USE_TEST_ADS=false` |
| Release, flag omitted or true | Google's test units |
| Release, `ADMOB_USE_TEST_ADS=false` | Configured production units |

The production defaults remain interstitial
`ca-app-pub-2273708482671832/3168825409` and rewarded interstitial
`ca-app-pub-2273708482671832/4842753743`. There is no configured production banner
unit in the inspected integration. Banners remain disabled; no banner ID is
inferred or fabricated.

## Safe release configuration

Use the production units only for a reviewed production build. Pass these
compile-time values to the release build command:

```powershell
flutter build apk --release `
  --dart-define=SERVER_URL=https://<your-server>.onrender.com `
  --dart-define=ADMOB_APP_ID=ca-app-pub-2273708482671832~3323244780 `
  --dart-define=ADMOB_USE_TEST_ADS=false `
  --dart-define=ADMOB_INTERSTITIAL_ID=ca-app-pub-2273708482671832/3168825409 `
  --dart-define=ADMOB_REWARDED_INTERSTITIAL_ID=ca-app-pub-2273708482671832/4842753743
```

Omit `ADMOB_USE_TEST_ADS=false` to retain Google's test units. Never click ads
programmatically or create artificial production impressions. Android emulator
requests should use Google's sample ad units. The service's test units are
interstitial `ca-app-pub-3940256099942544/1033173712` and rewarded interstitial
`ca-app-pub-3940256099942544/5354046379`.

## Consent and store disclosures

The app refreshes UMP consent information at startup, shows a required consent
form before requesting ads, and exposes a privacy-options entry point when UMP
requires one. The ad manager checks `canRequestAds()` before loading, and ad or
consent failures do not gate startup or gameplay. Cached UMP authorization may
still permit ads after a consent-update error; absent authorization, no ad loads
or shows occur.

Opening privacy options suspends requests and disposes cached inventory before
the form opens. The service rechecks `canRequestAds()` even if the form fails,
keeps ads disabled if the recheck fails, and only resumes requests when UMP
permits them. Pending native loads cannot be cancelled: generation guards dispose
late results instead of caching them after a consent change. Already-visible
interstitials cannot be programmatically removed by the SDK; service completion
and reward callbacks are invalidated, not treated as proof of native dismissal.

Before release, configure the required user messages in AdMob **Privacy &
messaging**, publish a privacy policy that covers advertising and Google/SDK data
handling, and complete the Google Play **Data safety** and ads declarations to
match the SDKs and the app's actual behavior. These account-specific settings
cannot be verified from the repository.

## Existing placements and lifecycle

- `mobile/lib/main.dart` starts ad initialization after `runApp()` without
  awaiting it. Startup was inspected, not modified.
- `mobile/lib/features/local_games/shell/result_screen.dart` offers an
  interstitial at completed-match Rematch. The shared shell was not modified.
  The existing three-minute cooldown and shared full-screen lock remain.
- `mobile/lib/features/privacy/privacy_screen.dart` exposes the UMP privacy
  options button when required.
- `offerRewardedInterstitial` exists with reward disclosure and Skip/Continue,
  but no game currently calls it. No reward placement or gameplay change was
  added. Rewards come only from the SDK's earned-reward callback, once per show;
  callbacks after dismissal, failure, watchdog expiry, disposal, or consent
  invalidation are ignored.

Each format caches at most one ad and accepts one in-flight request per consent
generation. Duplicate load triggers while loading, cached, or awaiting retry are
ignored. Failed loads (including thrown/rejected SDK calls) receive at most three
automatic retries, after **2, 4, and 8 seconds**: four total attempts per failure
sequence. Success resets the retry budget; changing consent invalidates old
requests, cancels timers, and resets the inventory. Exhausted retries stay idle
until a new consent cycle. A native load that never calls back stays pending
rather than launching overlapping requests. No-ad results let gameplay proceed.
Full-screen completion is idempotent; show/disposal errors are contained, and the
existing two-minute watchdog releases the service wait if native callbacks stop.

## Focused regression validation

`mobile/test/ad_mob_service_test.dart` uses an injectable inventory loader plus
the cached official SDK's mock-channel approach; it makes no real ad requests.
It covers deduplication, bounded backoff, consent withdrawal, stale loads,
initialization/disposal races, optional reward disclosure/skip, duplicate and late
reward callbacks, watchdogs, and show/disposal errors.

Run from `mobile/`:

```text
flutter test --no-pub test/ad_mob_service_test.dart
flutter test --no-pub --dart-define=ADMOB_USE_TEST_ADS=false test/ad_mob_service_test.dart
dart analyze lib/core/ads/ad_mob_service.dart test/ad_mob_service_test.dart
```

Validation for this repair: both focused test commands passed **21 tests** each,
and targeted `dart analyze` reported **no issues**. No full suite or APK build was
run. The false-flag run asserts that actual SDK load calls still contain Google's
test unit IDs. Mock-channel tests do not verify native ad rendering, device lifecycle,
production delivery, or account-side UMP configuration. Older audit reports may
refer to earlier SDK versions or test results; they are not evidence for this
repair.

Official references:

- [Google Mobile Ads Flutter setup](https://developers.google.com/admob/flutter/quick-start)
- [UMP consent setup for Flutter](https://developers.google.com/admob/flutter/privacy)
- [Google test ads for Flutter](https://developers.google.com/admob/flutter/test-ads)
