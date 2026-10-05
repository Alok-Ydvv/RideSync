# RideSync Phase 1 ERD

```
users (id=auth.uid(), phone!, full_name!, photo?, blood?, license?, vehicle pref)
  |--< emergency_contacts (user_id, name, phone, relationship, priority 1-3)
  |--< groups.leader_id
  |--< vehicles.driver_id
  |--< vehicle_passengers.user_id
  |--< invites.invited_by
  |--< messages.sender_id
  |--< commands.sender_id
  |--< sos_alerts.user_id
  |--< saved_routes.user_id
  |--< ride_statistics.user_id

groups (invite_code 6-digit unique, ride_type solo/group, vehicle_type bike/car/mixed,
        max_speed, distance_alert 500/1k/2k/5k, status planning/ready/active/paused/completed/cancelled)
  |--< vehicles (group_id, type bike/car, driver_id?, max_pax, position, role leader/middle/tail)
  |     |--< vehicle_passengers (name, phone, is_app_user, seat)
  |     |--< ride_locations.vehicle_id
  |     |--1 live_positions.vehicle_id (1 row/vehicle, 30s upsert)
  |--< invites (vehicle_id?, phone, by, status, expires_at +24h)
  |--< rides (planned_route JSON, start/end time, start/end GEOGRAPHY, distance, duration, weather JSON)
  |     |--< ride_locations (GEOGRAPHY Point 4326, speed/heading/alt/battery, recorded_at) [GIST]
  |     |--< ride_routes (waypoints JSON, polyline, distance, duration)
  |     |--< commands (type stop/slow/left/right/hazard/fuel/rest/parking, ack JSON)
  |     |--1 weather_cache (payload JSON, fetched_at)
  |     |--< sos_alerts (GEOGRAPHY, triggered/resolved, contacts JSON, active/resolved/false_alarm)
  |--< messages (sender, type text/image/voice/location, content, sent/delivered/read, offline flag)
```

## Key indexes

- `ride_locations` GIST on geography + `(ride_id, recorded_at desc)`
- `live_positions` GIST + PK on `vehicle_id`
- `messages (group_id, sent_at desc)`, `commands (ride_id, sent_at desc)`
- `vehicles_nearby(ride_id, lng, lat, radius_m)` RPC uses `ST_DWithin` + `<->` (index-backed)

## Apply order

1. `0001_enable_postgis.sql` (extensions schema)
2. `0002_phase1_schema.sql`
3. `0003_rls_policies.sql`

Supabase Dashboard: run in SQL editor in order, or `supabase db push` once CLI is installed.
Storage buckets to create (Phase 1 next slice): `avatars` (public read), `chat-media` (authed), `voice-notes` (authed), `pmtiles` (public read, for offline regions).
