// RideSync Edge: invite-verify (6-digit code, 24h TTL).
// Input: { code }. Output: group + open vehicle slots, or expired/invalid.
// Keeps invite logic server-side so clients never bypass expiry.
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

serve(async (req) => {
  try {
    const { code } = await req.json();
    if (!code || String(code).length !== 6) {
      return Response.json({ error: '6-digit code required' }, { status: 400 });
    }
    const supa = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );
    const { data: group } = await supa
      .from('groups')
      .select('id, name, ride_type, vehicle_type, status, leader_id')
      .eq('invite_code', String(code))
      .maybeSingle();
    if (!group) return Response.json({ error: 'invalid code' }, { status: 404 });

    const { data: vehicles } = await supa
      .from('vehicles')
      .select('id, vehicle_type, position_in_group, role, driver_id, max_passengers')
      .eq('group_id', group.id)
      .order('position_in_group');
    const open = (vehicles ?? []).filter((v) => !v.driver_id);
    return Response.json({ group, open_slots: open, vehicle_count: (vehicles ?? []).length });
  } catch (e) {
    return Response.json({ error: String(e) }, { status: 500 });
  }
});
