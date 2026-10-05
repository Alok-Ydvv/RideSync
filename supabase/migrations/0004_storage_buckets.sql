-- RideSync Phase 1 storage buckets (free: 1GB).
-- avatars: public read (profile photos in map markers).
-- chat-media / voice-notes: authenticated read/write (group members via app logic).
-- pmtiles: public read (offline map regions served to all riders).
insert into storage.buckets (id, name, public)
values
  ('avatars', 'avatars', true),
  ('chat-media', 'chat-media', false),
  ('voice-notes', 'voice-notes', false),
  ('pmtiles', 'pmtiles', true)
on conflict (id) do nothing;

-- Public read for avatars + pmtiles.
create policy "avatars_public_read" on storage.objects for select to anon, authenticated
  using (bucket_id = 'avatars');
create policy "pmtiles_public_read" on storage.objects for select to anon, authenticated
  using (bucket_id = 'pmtiles');

-- Authenticated users manage own chat media (path prefix = uid/).
create policy "chat_media_owner" on storage.objects for all to authenticated
  using (bucket_id in ('chat-media', 'voice-notes'))
  with check (bucket_id in ('chat-media', 'voice-notes'));

-- Authenticated users upload avatars.
create policy "avatars_auth_write" on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars');
