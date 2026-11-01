# Security findings

The referenced 10-page audit PDF was not present in the workspace, so this is a source inspection against the pasted requirements, not a page-by-page verification of that PDF.

## Confirmed

- **Unsigned development identity accepted by LAN:** `AuthenticationManager.token` creates `dev:<uid>:<name>`. `LanServer` verifies only the token's shape with a regular expression. Any LAN peer can claim an arbitrary UID/name and can replace that UID's active connection. This is a confirmed impersonation/session replacement risk.
- **Cloud dev auth is permissive when enabled:** `server/src/auth/verify.js` accepts the same unsigned development token when `AUTH_MODE=dev`. `server/src/config.js` prevents this only when `NODE_ENV=production` and `ALLOW_DEV_AUTH` is not true. Deployment environment values were not inspected; production exposure is therefore unverified.
- **Relay game state trusts the host:** the relay forwards host state, so a modified host can report arbitrary game results for relay games. Server-defined game modules validate actions but do not make phone-hosted relay outcomes authoritative.
- **Room codes are short invitations:** room codes are six characters; no independent room secret is evident in the inspected room protocol. Authorization relies on connection identity and room membership checks.

## Inferred / unverified risks

- LAN server binds `InternetAddress.anyIPv4`; access is available to reachable peers while it is running. Whether the host lifecycle is restricted to active hosting needs full flow validation.
- `server/src/index.js` configures Socket.IO CORS with wildcard origin. Mobile clients are expected; browser-origin policy is not authorization.
- Android manifest has Internet permission and no explicit backup policy. SharedPreferences contains player identity/name; backup behavior was not fully verified.
- Android release key files exist locally. Contents and key strength were not inspected. Release config falls back to debug signing when no `key.properties` is loaded; current actual signing identity needs APK inspection.
- Socket reconnect is enabled and listeners are attached once per new socket, but complete reconnection, session theft, and stale-event abuse were not adversarially tested.
- The audit PDF and live Render/Firebase/MongoDB configuration were unavailable, preventing full deployment verification.

No identity/session/security redesign was attempted because safe server-issued guest sessions require coordinated LAN/cloud protocol migration and deployment configuration, which cannot be safely validated from this source snapshot alone. The risks remain open.
