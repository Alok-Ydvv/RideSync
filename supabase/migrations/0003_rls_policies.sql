-- RideSync Phase 1 RLS. Principle: users manage own rows; group members read
-- group-scoped rows. Leader writes group config. Service role bypasses for Edge Functions.
-- Enable RLS on everything (PostGIS spatial_ref_sys stays in extensions, untouched).

alter table public.users enable row level security;
alter table public.emergency_contacts enable row level security;
alter table public.groups enable row level security;
alter table public.vehicles enable row level security;
alter table public.vehicle_passengers enable row level security;
alter table public.invites enable row level security;
alter table public.rides enable row level security;
alter table public.ride_locations enable row level security;
alter table public.live_positions enable row level security;
alter table public.ride_routes enable row level security;
alter table public.messages enable row level security;
alter table public.commands enable row level security;
alter table public.sos_alerts enable row level security;
alter table public.saved_routes enable row level security;
alter table public.ride_statistics enable row level security;
alter table public.weather_cache enable row level security;

-- Helper: is the caller a member (driver/passenger/leader) of the group?
create or replace function public.is_group_member(p_group_id uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.groups g where g.id = p_group_id and g.leader_id = auth.uid()
  ) or exists (
    select 1 from public.vehicles v where v.group_id = p_group_id and v.driver_id = auth.uid()
  ) or exists (
    select 1 from public.vehicle_passengers vp
    join public.vehicles v on v.id = vp.vehicle_id
    where v.group_id = p_group_id and vp.user_id = auth.uid()
  );
$$;

-- users: read own + group-mates minimal; update own only.
create policy "users_read_own" on public.users for select to authenticated
  using (id = auth.uid());
create policy "users_update_own" on public.users for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());
create policy "users_insert_own" on public.users for insert to authenticated
  with check (id = auth.uid());

-- emergency_contacts: owner only.
create policy "contacts_owner_all" on public.emergency_contacts for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- groups: members read; leader updates; any authed user can create (becomes leader).
create policy "groups_member_read" on public.groups for select to authenticated
  using (public.is_group_member(id) or leader_id = auth.uid());
create policy "groups_create" on public.groups for insert to authenticated
  with check (leader_id = auth.uid());
create policy "groups_leader_update" on public.groups for update to authenticated
  using (leader_id = auth.uid()) with check (leader_id = auth.uid());
create policy "groups_leader_delete" on public.groups for delete to authenticated
  using (leader_id = auth.uid());

-- vehicles: members read; leader manages.
create policy "vehicles_member_read" on public.vehicles for select to authenticated
  using (public.is_group_member(group_id));
create policy "vehicles_leader_write" on public.vehicles for all to authenticated
  using (
    exists (select 1 from public.groups g where g.id = group_id and g.leader_id = auth.uid())
  ) with check (
    exists (select 1 from public.groups g where g.id = group_id and g.leader_id = auth.uid())
  );

-- vehicle_passengers: members read; driver/leader write.
create policy "passengers_member_read" on public.vehicle_passengers for select to authenticated
  using (
    exists (
      select 1 from public.vehicles v
      where v.id = vehicle_id and public.is_group_member(v.group_id)
    )
  );
create policy "passengers_write" on public.vehicle_passengers for all to authenticated
  using (
    exists (
      select 1 from public.vehicles v
      join public.groups g on g.id = v.group_id
      where v.id = vehicle_id and (g.leader_id = auth.uid() or v.driver_id = auth.uid())
    )
  ) with check (
    exists (
      select 1 from public.vehicles v
      join public.groups g on g.id = v.group_id
      where v.id = vehicle_id and (g.leader_id = auth.uid() or v.driver_id = auth.uid())
    )
  );

-- invites: inviter + invited phone owner read; inviter/leader write.
-- Note: invited non-users can't read until they sign up; leader shares code out-of-band.
create policy "invites_read" on public.invites for select to authenticated
  using (
    invited_by = auth.uid()
    or exists (select 1 from public.groups g where g.id = group_id and g.leader_id = auth.uid())
  );
create policy "invites_write" on public.invites for all to authenticated
  using (
    invited_by = auth.uid()
    or exists (select 1 from public.groups g where g.id = group_id and g.leader_id = auth.uid())
  ) with check (
    invited_by = auth.uid()
    or exists (select 1 from public.groups g where g.id = group_id and g.leader_id = auth.uid())
  );

-- rides/routes/locations/live: group members read; leader + drivers write.
create policy "rides_member_read" on public.rides for select to authenticated
  using (public.is_group_member(group_id));
create policy "rides_leader_write" on public.rides for all to authenticated
  using (
    exists (select 1 from public.groups g where g.id = group_id and g.leader_id = auth.uid())
  ) with check (
    exists (select 1 from public.groups g where g.id = group_id and g.leader_id = auth.uid())
  );

create policy "routes_member_read" on public.ride_routes for select to authenticated
  using (
    exists (select 1 from public.rides r where r.id = ride_id and public.is_group_member(r.group_id))
  );
create policy "routes_leader_write" on public.ride_routes for all to authenticated
  using (
    exists (
      select 1 from public.rides r
      join public.groups g on g.id = r.group_id
      where r.id = ride_id and g.leader_id = auth.uid()
    )
  ) with check (
    exists (
      select 1 from public.rides r
      join public.groups g on g.id = r.group_id
      where r.id = ride_id and g.leader_id = auth.uid()
    )
  );

create policy "locations_member_read" on public.ride_locations for select to authenticated
  using (
    exists (select 1 from public.rides r where r.id = ride_id and public.is_group_member(r.group_id))
  );
create policy "locations_driver_write" on public.ride_locations for insert to authenticated
  with check (
    exists (
      select 1 from public.rides r
      join public.vehicles v on v.id = vehicle_id
      where r.id = ride_id and v.group_id = r.group_id
        and (v.driver_id = auth.uid() or public.is_group_member(r.group_id))
    )
  );

create policy "live_member_read" on public.live_positions for select to authenticated
  using (
    exists (select 1 from public.rides r where r.id = ride_id and public.is_group_member(r.group_id))
  );
create policy "live_driver_write" on public.live_positions for all to authenticated
  using (
    exists (
      select 1 from public.vehicles v
      where v.id = vehicle_id and v.driver_id = auth.uid()
    )
  ) with check (
    exists (
      select 1 from public.vehicles v
      where v.id = vehicle_id and v.driver_id = auth.uid()
    )
  );

-- messages/commands: members read; members send.
create policy "messages_member_read" on public.messages for select to authenticated
  using (public.is_group_member(group_id));
create policy "messages_member_send" on public.messages for insert to authenticated
  with check (sender_id = auth.uid() and public.is_group_member(group_id));

create policy "commands_member_read" on public.commands for select to authenticated
  using (
    exists (select 1 from public.rides r where r.id = ride_id and public.is_group_member(r.group_id))
  );
create policy "commands_member_send" on public.commands for insert to authenticated
  with check (
    sender_id = auth.uid()
    and exists (select 1 from public.rides r where r.id = ride_id and public.is_group_member(r.group_id))
  );

-- sos: members read group SOS; anyone triggers own.
create policy "sos_member_read" on public.sos_alerts for select to authenticated
  using (
    user_id = auth.uid()
    or (ride_id is not null and exists (
      select 1 from public.rides r where r.id = ride_id and public.is_group_member(r.group_id)
    ))
  );
create policy "sos_trigger_own" on public.sos_alerts for insert to authenticated
  with check (user_id = auth.uid());
create policy "sos_update_own" on public.sos_alerts for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- saved_routes/stats: owner only.
create policy "saved_owner_all" on public.saved_routes for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "stats_owner_read" on public.ride_statistics for select to authenticated
  using (user_id = auth.uid());

-- weather_cache: group members read (phones never call Open-Meteo directly).
create policy "weather_member_read" on public.weather_cache for select to authenticated
  using (
    exists (select 1 from public.rides r where r.id = ride_id and public.is_group_member(r.group_id))
  );
