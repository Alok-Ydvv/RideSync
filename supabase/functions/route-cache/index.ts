// RideSync Edge: route-cache (OSRM public demo, free).
// Leader computes once per ride; result stored in ride_routes and shared to group.
// Respects OSRM fair-use: single server-side call per route change, not per phone.
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

serve(async (req) => {
  try {
    const { ride_id, waypoints } = await req.json() as {
      ride_id: string;
      waypoints: Array<{ lat: number; lng: number }>;
    };
    if (!ride_id || !waypoints || waypoints.length < 2) {
      return Response.json({ error: 'ride_id + waypoints[>=2] required' }, { status: 400 });
    }
    const supa = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    // Reuse cached route if waypoints unchanged (compare JSON).
    const { data: existing } = await supa
      .from('ride_routes')
      .select('*')
      .eq('ride_id', ride_id)
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();
    if (existing && JSON.stringify(existing.waypoints) === JSON.stringify(waypoints)) {
      return Response.json({ ...existing, cached: true });
    }

    const coords = waypoints.map((w) => `${w.lng},${w.lat}`).join(';');
    const url = `https://router.project-osrm.org/route/v1/driving/${coords}?overview=full&geometries=polyline&steps=false`;
    const r = await fetch(url, { headers: { 'User-Agent': 'RideSync/0.1 (free-cache)' } });
    if (!r.ok) return Response.json({ error: 'routing upstream failed' }, { status: 502 });
    const j = await r.json();
    const route = j?.routes?.[0];
    if (!route) return Response.json({ error: 'no route found' }, { status: 404 });

    const row = {
      ride_id,
      waypoints,
      encoded_polyline: route.geometry,
      total_distance: route.distance, // meters
      estimated_duration: Math.round(route.duration), // seconds
    };
    const { data, error } = await supa.from('ride_routes').insert(row).select().single();
    if (error) throw error;
    return Response.json({ ...data, cached: false });
  } catch (e) {
    return Response.json({ error: String(e) }, { status: 500 });
  }
});
