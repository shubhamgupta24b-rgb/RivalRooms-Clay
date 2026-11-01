# Network and latency report

## Source observations

- Cloud HTTP health endpoint: `GET /health` in `server/src/index.js` returns `{ok:true, app:'party-games'}`.
- Mobile Socket.IO uses WebSocket transport, reconnection from 500 ms up to 5 s, a 10 s initial connection timeout, and 8 s request acknowledgements.
- Server room ticking interval is 250 ms in the inspected `server/src/index.js`; this is a scheduler interval, not measured end-to-end latency. It differs from the 50 ms interval mentioned in the unavailable audit.
- LAN host binds all IPv4 interfaces and also exposes `/health`.

## Measurements

No end-to-end device measurements were obtained. Connection establishment, server wake-up, RTT, event delivery, reconnect time, payload sizes, and CPU/bandwidth were not measured. p50/p95/max are therefore **not available**. Device workload, server region, sample count, and cold-start duration are also unavailable.

No relay frequency increase was made. A health request may indicate availability but does not guarantee a Render service remains warm.

## Follow-up

On a connected Android device and known backend region, collect timestamped samples for health response, socket connect, ping RTT, event round-trip, reconnect, and serialized payload sizes; report sample count and percentiles before adjusting cadence.
