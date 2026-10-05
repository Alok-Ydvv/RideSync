// RideSync Edge: weather-cache (Open-Meteo, free 10k/day, no key).
// Phones NEVER call Open-Meteo directly. Leader app calls this once per
// ride per 20 min; result is stored in weather_cache and broadcast to group.
// Free non-commercial only (CC-BY). Commercial launch: switch to customer-api.open-meteo.com.
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const CACHE_MIN = 20;

serve(async (req) => {
  try {
    const { ride_id, lat, lng } = await req.json();
    if (!ride_id || lat == null || lng == null) {
      return Response.json({ error: 'ride_id, lat, lng required' }, { status: 400 });
    }
    const supa = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    // 1. Serve cache if fresh.
    const { data: cached } = await supa
      .from('weather_cache')
      .select('payload, fetched_at')
      .eq('ride_id', ride_id)
      .maybeSingle();
    if (cached) {
      const ageMin = (Date.now() - new Date(cached.fetched_at).getTime()) / 60000;
      if (ageMin < CACHE_MIN) return Response.json({ ...cached.payload, cached: true });
    }

    // 2. Fetch Open-Meteo (current + next hours: rain/fog/storm/heat/cold for alerts).
    const url =
      `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lng}` +
      `&current=temperature_2m,relative_humidity_2m,precipitation,weathercode,wind_speed_10m,visibility` +
      `&hourly=precipitation_probability,visibility,temperature_2m` +
      `&forecast_days=1&timezone=auto`;
    const r = await fetch(url, { headers: { 'User-Agent': 'RideSync/0.1 (free-cache)' } });
    if (!r.ok) {
      if (cached) return Response.json({ ...cached.payload, cached: true, stale: true });
      return Response.json({ error: 'weather upstream failed' }, { status: 502 });
    }
    const payload = await r.json();

    // 3. Upsert cache (service role bypasses RLS; phones read via policy).
    await supa.from('weather_cache').upsert(
      { ride_id, payload, fetched_at: new Date().toISOString() },
      { onConflict: 'ride_id' },
    );
    return Response.json({ ...payload, cached: false });
  } catch (e) {
    return Response.json({ error: String(e) }, { status: 500 });
  }
});
