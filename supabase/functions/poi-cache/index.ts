// RideSync Edge: poi-cache (Overpass API / OpenStreetMap, free).
// Phones never hit Overpass directly (fair-use: max ~2 req/s). This proxy
// fans out per category and returns a trimmed list with distance in meters.
// Categories: fuel, hospital, mechanic, atm, food, parking.
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';

const CATEGORY_FILTER: Record<string, string> = {
  fuel: '["amenity"="fuel"]',
  hospital: '["amenity"="hospital"]',
  mechanic: '["shop"="car_repair"]',
  atm: '["amenity"="atm"]',
  food: '["amenity"~"restaurant|fast_food|cafe|dhaba"]',
  parking: '["amenity"="parking"]',
};

function haversine(lat1: number, lon1: number, lat2: number, lon2: number) {
  const R = 6371000;
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(Math.min(1, a)));
}

serve(async (req) => {
  try {
    const { lat, lng, radius = 5000, category = 'fuel' } = await req.json();
    if (lat == null || lng == null) {
      return Response.json({ error: 'lat, lng required' }, { status: 400 });
    }
    const filter = CATEGORY_FILTER[category] ?? CATEGORY_FILTER['fuel'];
    const ql =
      `[out:json][timeout:15];(node${filter}(around:${radius},${lat},${lng});` +
      `way${filter}(around:${radius},${lat},${lng}););out center 30;`;
    const r = await fetch('https://overpass-api.de/api/interpreter', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'User-Agent': 'RideSync/0.1 (free-cache)',
      },
      body: 'data=' + encodeURIComponent(ql),
    });
    if (!r.ok) return Response.json({ error: 'overpass upstream failed' }, { status: 502 });
    const j = await r.json();
    const items = (j.elements ?? []).map((e: Record<string, unknown>) => {
      const tags = (e['tags'] ?? {}) as Record<string, string>;
      const plat = (e['lat'] ?? (e['center'] as Record<string, number> | undefined)?.['lat']) as number;
      const plng = (e['lon'] ?? (e['center'] as Record<string, number> | undefined)?.['lon']) as number;
      return {
        name: tags['name'] ?? category,
        lat: plat,
        lng: plng,
        dist_m: plat != null ? Math.round(haversine(lat, lng, plat, plng)) : null,
        opening_hours: tags['opening_hours'] ?? null,
      };
    }).filter((x: { lat: number }) => x.lat != null)
      .sort((a: { dist_m: number }, b: { dist_m: number }) => a.dist_m - b.dist_m)
      .slice(0, 30);
    return Response.json({ category, count: items.length, items });
  } catch (e) {
    return Response.json({ error: String(e) }, { status: 500 });
  }
});
