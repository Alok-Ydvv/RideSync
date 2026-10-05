# RideSync Phase 1 Architecture (free-first, reliable)

## System diagram

```
[Flutter App: ForegroundService 10s/30s/60s + Hive queue]
   |--(online)--> Realtime Broadcast `ride:<ride_id>` (10s, ephemeral, 0 DB writes)
   |--(every 30s)--> upsert live_positions + batch insert ride_locations
   |--(offline)--> Hive/SQLite queue --> Workmanager delta-sync on reconnect
   |
   +--> Edge weather-cache (Open-Meteo, 20-min cache) --> weather_cache
   +--> Edge route-cache (OSRM, 1 call/route) --> ride_routes
   +--> Edge poi-cache (Overpass, server-side) --> response only
   +--> Edge invite-verify (6-digit, 24h TTL)
   +--> Supabase Auth (email/Google/Apple free; OTP via MSG91 BYO, throttled)
   +--> FCM only (no OneSignal) + local notifications
   +--> SOS triple-path: Broadcast + FCM + SIM SMS (telephony, works offline)
```

## Realtime events (Phase 1)

| Channel | Event | Payload | Notes |
|---|---|---|---|
| `ride:<ride_id>` (Broadcast) | `location` | `{vehicle_id, lat, lng, speed, heading, at}` | 10s, ephemeral, no DB write |
| `ride:<ride_id>` (Broadcast) | `command` | `{command_type, sender_id, at}` | STOP/SLOW/LEFT/RIGHT/HAZARD/FUEL/REST/PARKING + fullscreen + vibration |
| `ride:<ride_id>` (Broadcast) | `sos` | `{user_id, lat, lng, at}` | + FCM + SMS in parallel |
| `group:<group_id>` (postgres_changes) | `INSERT messages` | row | Chat; offline msgs carry `is_offline_message` |
| `group:<group_id>` (postgres_changes) | `UPDATE rides` | row | Status: planning/ready/active/paused/completed |

Scale math: ~3 conns/ride. Supabase Free 200 conns ≈ 65 concurrent rides.

## Offline model (simplified, Phase 1)

Works offline: PMTiles map + cached polyline follow + Hive recording + SMS SOS.
Blocked offline: group Broadcast, chat send (queued), weather/POI (cached read-only).
Sync: last-write-wins (positions), merge + `sent_offline` tag (messages), leader-wins (settings).

## Free budgets (enforced by Edge cache)

- Open-Meteo 10k/day: 1 fetch/ride/20min → ~480 rides/day headroom.
- OSRM/Overpass/Nominatim: 1 server call per route/bbox, shared to group.
- Supabase Free: 500MB DB, 1GB Storage, 200 conns, 500k Edge calls.
- Upgrade triggers: >65 concurrent rides (Pro $25), >10k weather/day, tiles >R2 free egress.

## Android 14-16 / iOS notes

- `location`-typed foreground service (`flutter_foreground_task`), started from visible tap.
- `FOREGROUND_SERVICE_LOCATION` + fine location; `ACCESS_BACKGROUND_LOCATION` only if auto-restart after reboot is required (adds Play declaration).
- Workmanager for deferred sync only (15-min min Android, throttled iOS), never for live tracking.
