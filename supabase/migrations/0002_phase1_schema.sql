-- RideSync Phase 1 schema (free-first).
-- Conventions:
-- * PostGIS types live in extensions schema: extensions.geography
-- * users.id = auth.uid() (Supabase Auth: phone OTP / email / Google / Apple)
-- * Live positions: 1 row per vehicle upserted every 30s (last-known).
--   High-frequency 10s stream goes over Realtime Broadcast, NOT this table.
-- * History sampling stays in ride_locations (batched inserts).

-- ---------- users ----------
create table public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  phone text unique,
  email text unique,
  full_name text not null,
  profile_photo_url text,
  blood_group text,
  license_number text,
  default_vehicle_type text not null default 'bike' check (default_vehicle_type in ('bike','car')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------- emergency_contacts (1-3 per user, enforced in app + trigger below) ----------
create table public.emergency_contacts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  name text not null,
  phone text not null,
  relationship text not null,
  priority int not null default 1 check (priority between 1 and 3),
  created_at timestamptz not null default now(),
  unique (user_id, priority)
);

-- ---------- groups ----------
create table public.groups (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  invite_code text not null unique default public.generate_invite_code(),
  leader_id uuid not null references public.users(id),
  ride_type text not null default 'group' check (ride_type in ('solo','group')),
  vehicle_type text not null default 'bike' check (vehicle_type in ('bike','car','mixed')),
  max_speed_limit int,
  distance_alert_threshold int not null default 1000 check (distance_alert_threshold in (500,1000,2000,5000)),
  status text not null default 'planning'
    check (status in ('planning','ready','active','paused','completed','cancelled')),
  created_at timestamptz not null default now()
);

-- ---------- vehicles (slots: empty → invited → confirmed → ready, tracked in app + invites) ----------
create table public.vehicles (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  vehicle_type text not null check (vehicle_type in ('bike','car')),
  vehicle_number text,
  driver_id uuid references public.users(id) on delete set null,
  max_passengers int not null default 1,
  position_in_group int not null default 1,
  role text not null default 'middle' check (role in ('leader','middle','tail')),
  created_at timestamptz not null default now(),
  unique (group_id, position_in_group)
);

-- ---------- vehicle_passengers ----------
create table public.vehicle_passengers (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  user_id uuid references public.users(id) on delete set null,
  name text not null,
  phone text,
  is_app_user boolean not null default false,
  seat_position int not null default 1,
  created_at timestamptz not null default now()
);

-- ---------- invites (6-digit, 24h TTL) ----------
create table public.invites (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  vehicle_id uuid references public.vehicles(id) on delete cascade,
  invited_phone text not null,
  invited_by uuid not null references public.users(id),
  status text not null default 'pending'
    check (status in ('pending','accepted','declined','expired')),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '24 hours'
);

-- ---------- rides ----------
create table public.rides (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  planned_route jsonb,
  actual_start_time timestamptz,
  actual_end_time timestamptz,
  start_location extensions.geography(Point, 4326),
  end_location extensions.geography(Point, 4326),
  total_distance numeric,
  total_duration int,
  weather_conditions jsonb,
  status text not null default 'planned'
    check (status in ('planned','active','paused','completed','cancelled')),
  created_at timestamptz not null default now()
);

-- ---------- ride_locations (batched history + 30s last-known source) ----------
create table public.ride_locations (
  id bigint generated always as identity primary key,
  ride_id uuid not null references public.rides(id) on delete cascade,
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  location extensions.geography(Point, 4326) not null,
  speed double precision,
  heading double precision,
  altitude double precision,
  battery_level int,
  recorded_at timestamptz not null default now()
);
create index ride_locations_geo_idx on public.ride_locations using gist ((location::extensions.geometry));
create index ride_locations_ride_time_idx on public.ride_locations (ride_id, recorded_at desc);

-- ---------- live_positions (1 row per vehicle, upserted every 30s) ----------
create table public.live_positions (
  vehicle_id uuid primary key references public.vehicles(id) on delete cascade,
  ride_id uuid not null references public.rides(id) on delete cascade,
  location extensions.geography(Point, 4326) not null,
  speed double precision,
  heading double precision,
  updated_at timestamptz not null default now()
);
create index live_positions_geo_idx on public.live_positions using gist ((location::extensions.geometry));

-- ---------- ride_routes (cached OSRM result, shared to whole group) ----------
create table public.ride_routes (
  id uuid primary key default gen_random_uuid(),
  ride_id uuid not null references public.rides(id) on delete cascade,
  waypoints jsonb not null,
  encoded_polyline text,
  total_distance numeric,
  estimated_duration int,
  created_at timestamptz not null default now()
);

-- ---------- messages (Phase 1: text/image/voice/location; PTT deferred) ----------
create table public.messages (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  sender_id uuid not null references public.users(id),
  message_type text not null default 'text'
    check (message_type in ('text','image','voice','location')),
  content text not null,
  sent_at timestamptz not null default now(),
  delivered_at timestamptz,
  read_at timestamptz,
  is_offline_message boolean not null default false
);
create index messages_group_time_idx on public.messages (group_id, sent_at desc);

-- ---------- commands (leader broadcast, Phase 1 set) ----------
create table public.commands (
  id uuid primary key default gen_random_uuid(),
  ride_id uuid not null references public.rides(id) on delete cascade,
  sender_id uuid not null references public.users(id),
  command_type text not null
    check (command_type in ('stop','slow','left','right','hazard','fuel','rest','parking')),
  sent_at timestamptz not null default now(),
  acknowledged_by jsonb not null default '[]'::jsonb
);
create index commands_ride_time_idx on public.commands (ride_id, sent_at desc);

-- ---------- sos_alerts (triple-path: broadcast + FCM + SIM SMS) ----------
create table public.sos_alerts (
  id uuid primary key default gen_random_uuid(),
  ride_id uuid references public.rides(id) on delete cascade,
  user_id uuid not null references public.users(id),
  location extensions.geography(Point, 4326),
  triggered_at timestamptz not null default now(),
  resolved_at timestamptz,
  notified_contacts jsonb not null default '[]'::jsonb,
  status text not null default 'active'
    check (status in ('active','resolved','false_alarm'))
);
create index sos_alerts_geo_idx on public.sos_alerts using gist ((location::extensions.geometry));

-- ---------- saved_routes ----------
create table public.saved_routes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  name text not null,
  description text,
  waypoints jsonb not null,
  distance numeric,
  estimated_duration int,
  created_at timestamptz not null default now()
);

-- ---------- ride_statistics (basic P1 totals; eco/risk deferred) ----------
create table public.ride_statistics (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  total_rides int not null default 0,
  total_distance numeric not null default 0,
  total_duration int not null default 0,
  average_speed numeric,
  max_speed numeric,
  month int,
  year int,
  updated_at timestamptz not null default now(),
  unique (user_id, month, year)
);

-- ---------- weather_cache (Edge writes once per ride per 20 min; phones read) ----------
create table public.weather_cache (
  ride_id uuid primary key references public.rides(id) on delete cascade,
  payload jsonb not null,
  fetched_at timestamptz not null default now()
);

-- ---------- nearby helper: vehicles within radius (ST_DWithin, indexed) ----------
create or replace function public.vehicles_nearby(
  p_ride_id uuid, p_lng double precision, p_lat double precision, p_radius_m int
)
returns table (vehicle_id uuid, dist_meters double precision)
language sql stable
as $$
  select lp.vehicle_id,
         extensions.st_distance(
           lp.location,
           extensions.st_point(p_lng, p_lat)::extensions.geography
         ) as dist_meters
  from public.live_positions lp
  where lp.ride_id = p_ride_id
    and extensions.st_dwithin(
      lp.location,
      extensions.st_point(p_lng, p_lat)::extensions.geography,
      p_radius_m
    )
  order by lp.location operator(extensions.<->)
           extensions.st_point(p_lng, p_lat)::extensions.geography;
$$;
