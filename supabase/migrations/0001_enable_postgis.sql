-- RideSync Phase 1: PostGIS in extensions schema (never public).
-- Run first. Supabase Dashboard: Database > Extensions > postgis (schema: extensions).
create extension if not exists postgis with schema extensions;

-- Helper: 6-digit invite code, valid 24h (enforced in invites.expires_at).
create or replace function public.generate_invite_code()
returns text
language plpgsql
as $$
declare
  code text;
begin
  code := lpad((floor(random() * 900000) + 100000)::int::text, 6, '0');
  return code;
end;
$$;
