# RideSync Supabase Setup Guide (Phase 1, free tier)

## 1. Create project
- Region: **Mumbai (ap-south-1)** for India latency.
- Plan: Free (upgrade to Pro $25 at >65 concurrent rides).

## 2. Enable extensions
Database → Extensions → enable **postgis** with schema `extensions`
(never `public`).

## 3. Run migrations (SQL editor, in order)
1. `supabase/migrations/0001_enable_postgis.sql`
2. `supabase/migrations/0002_phase1_schema.sql`
3. `supabase/migrations/0003_rls_policies.sql`
4. `supabase/migrations/0004_storage_buckets.sql`

Verify: `select * from extensions.spatial_ref_sys limit 1;`
must work, and `public.spatial_ref_sys` must NOT exist.

## 4. Auth providers
Auth → Providers: enable **Phone (OTP)** + **Email** + **Google** + **Apple**.
- Phone: BYO SMS via MSG91/Gupshup DLT route (Auth → Hooks → Send SMS).
  Twilio retail (~$0.04/SMS) is 6-8x costlier for India.
- Throttle: Auth → Rate limits → 60s OTP resend. Enable CAPTCHA.

## 5. Realtime
Realtime → enable for tables: `messages`, `rides`, `commands`, `live_positions`
(postgres_changes = durable path). High-frequency 10s GPS uses
**Broadcast** channels `ride:<ride_id>` (ephemeral, 0 DB writes).

Free quota: 200 concurrent connections ≈ 65 rides (3 conns/ride).

## 6. Edge Functions (Deno)
```sh
supabase functions deploy weather-cache
supabase functions deploy route-cache
supabase functions deploy poi-cache
supabase functions deploy invite-verify
# required secrets:
supabase secrets set SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=...
```
Free quota: 500k invocations/month. Phones call Edge, never
Open-Meteo/OSRM/Overpass directly.

## 7. App config
```sh
cp .env.example .env
# SUPABASE_URL=https://<ref>.supabase.co
# SUPABASE_ANON_KEY=<anon>
flutter run
```

## 8. FCM (Phase 1 push)
Firebase console → add Android (`com.ridesync.ridesync`) + iOS apps →
`google-services.json` / `GoogleService-Info.plist` → server key in
Supabase → Auth → Push (or direct FCM data messages from Edge on SOS).

## 9. GIST sanity
```sql
select indexname from pg_indexes
where schemaname='public' and indexname like '%geo%';
-- expect: ride_locations_geo_idx, live_positions_geo_idx, sos_alerts_geo_idx
```
