# UX, accessibility, startup, and audio

- Ad consent/SDK initialization is launched without awaiting it before `runApp`; slow ad setup does not gate the initial screen.
- Added an Ad privacy options entry in the existing Privacy screen and corrected its disclosure to state that the app may request ads.
- Completed-match interstitial appears only when the user selects Rematch; unavailable/failing ads do not block the action.
- Existing controls and accessibility semantics were not comprehensively audited in this pass. Small-screen, orientation, cutout, screen-reader announcements, reduced-motion, audio/haptics, and touch-target testing: **NOT TESTED**.
- No broad UI redesign or audio changes were made.
