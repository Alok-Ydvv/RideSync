# RideSync — Group Travel Safety & Tracking (Flutter + Supabase)

Smart group travel safety and tracking for bikers, car travellers, and solo riders.
India-focused: phone OTP, offline maps, SMS SOS, Hindi + English.

> Status: repo bootstrapped. Phase 1 MVP in progress. Phase 2 (hard/R&D) deferred as update.

## Free-first stack (Phase 1 target: $0/month)

- **App:** Flutter 3.x, Riverpod, Hive + SQLite (offline queue)
- **Backend:** Supabase (Postgres + PostGIS, Realtime Broadcast, Auth, Storage, Edge Functions)
- **Maps:** `flutter_map` + OSM (dev) / PMTiles + Protomaps on Supabase Storage (prod)
- **Routing/Geocode:** OSRM + Nominatim/Photon via Edge cache (one fetch per ride, shared to group)
- **Weather:** Open-Meteo via Edge cache (1 fetch / ride / 20 min) — free = non-commercial, CC-BY
- **POI:** Overpass API via Edge cache (fuel, hospital, mechanic, ATM, food, parking)
- **Push:** FCM only (no OneSignal)
- **Voice P1:** voice notes via Storage. PTT deferred to Phase 2 (LiveKit self-host).
- **SOS:** Realtime Broadcast + FCM + SMS via own SIM (`telephony`) — works offline.

Key efficiency rule: **Broadcast for live positions (10s), DB upsert every 30s only.** No per-ping DB writes.

Location tiers: active 10s / background 30s / stationary 60s + 25m distance filter.

## Phases

### Phase 1 — MVP (build now)
Auth (email/Google/Apple, OTP UI ready) · profile + emergency contacts (1-3) ·
Solo/Group + Bike/Car/Mixed (1-20 bikes, 1-10 cars) · invites (contacts/QR/6-digit/share link) ·
live tracking + distance alerts + Leader/Middle/Tail · cached route + fuel estimate ·
leader commands (STOP/SLOW/LEFT/RIGHT/HAZARD/FUEL/REST) · chat (text/photo/pin/voice note) ·
solo share-link + ETA + Reached safely + check-in · SOS + weather proxy + nearby + history playback.

### Phase 2 — Update (deferred, hard/complex)
Voice PTT · BLE mesh + WiFi Direct relay · on-device turn-by-turn + TTS + auto-reroute ·
AI Risk Score + Eco Score · mid-ride position swap + tail-checkpoint + leadership transfer ·
multi-vehicle synced playback · elevation/tolls/GPX/scenic/hotels · session mgmt.

## Repo layout (target)

```
lib/
├── core/ (constants, themes, utils, errors, l10n EN/HI)
├── data/ (models, repositories, datasources)
├── domain/ (entities, usecases)
├── presentation/ (screens, widgets, providers)
└── services/ (location, sync, notifications, sos, weather-cache)
supabase/
├── migrations/ (PostGIS in extensions schema, GIST indexes, RLS)
└── functions/ (route-cache, weather-cache, poi-cache, invite-verify)
```

## Run (once scaffolded)

```sh
flutter pub get
cp .env.example .env   # fill SUPABASE_URL, SUPABASE_ANON_KEY
flutter run
```

## Docs roadmap

1. Architecture diagram
2. ERD (users, emergency_contacts, groups, vehicles, passengers, invites, rides, ride_locations, messages, commands, sos_alerts, saved_routes)
3. Supabase setup (RLS, Realtime Broadcast, Edge Functions, Storage buckets)
4. Setup + testing guide

## License

TBD — for portfolio demo. Add LICENSE before public launch if commercial (note Open-Meteo free = non-commercial only).
