# RivalRoom Clay — app logo

A candy-yellow clay doorway (the room) with two puffy rival pawns, blue and coral, glaring at each other under a spark, on the grape clay world. Drawn in code by `PartyLogoPainter` in `mobile/lib/core/ui/party_logo.dart` (1024 × 1024 grid), so the in-app logo and the launcher icons always match.

## Regenerating the icons

From `mobile/`:

```
flutter test tool/render_logo_test.dart        # writes build/logo/*.png
powershell -File tool/make_icons.ps1           # Android mipmaps + web icons
```

Then copy `build/logo/icon_1024.png` to `logo.png` (repo root) and the files below into `store/`.

## Files

- `store/icon_1024.png` — master icon (rounded tile)
- `store/playstore_512.png` — Play Store icon (square, Google rounds it)
- `store/adaptive_foreground_1024.png` — Android adaptive foreground (art at 70%, full bleed)
- Adaptive icon background colour: `#3E22B2` (`Skin.bg`)

`render_logo.py` and `android/` are the old Party Games controller logo, kept for reference.
