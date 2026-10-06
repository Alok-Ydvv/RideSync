import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Direct free-API clients. Used as fallback when the Edge cache isn't
/// deployed (or offline-misconfigured). Open-Meteo / OSRM / Overpass are
/// free; each app instance calling them directly is fine for dev/small use —
/// the Edge cache remains the production optimization (shared to the group).
LatLng? parseLatLng(dynamic v) => v == null
    ? null
    : (v is String ? null : LatLng((v['lat'] as num).toDouble(), (v['lng'] as num).toDouble()));

/// Overpass mirror used by [nearbyDirect]. category → OSM filter.
const _poiFilters = <String, String>{
  'fuel': '["amenity"="fuel"]',
  'hospital': '["amenity"="hospital"]',
  'mechanic': '["shop"="car_repair"]',
  'atm': '["amenity"="atm"]',
  'food': '["amenity"~"restaurant|fast_food|cafe"]',
  'parking': '["amenity"="parking"]',
};

Future<List<Map<String, dynamic>>> nearbyDirect({
  required double lat,
  required double lng,
  int radius = 5000,
  String category = 'fuel',
}) async {
  final filter = _poiFilters[category] ?? _poiFilters['fuel']!;
  final ql =
      '[out:json][timeout:20];(node$filter(around:$radius,$lat,$lng);way$filter(around:$radius,$lat,$lng););out center 30;';
  try {
    final r = await http
        .post(
          Uri.parse('https://overpass-api.de/api/interpreter'),
          headers: const {'User-Agent': 'RideSync/0.1'},
          body: 'data=${Uri.encodeComponent(ql)}',
        )
        .timeout(const Duration(seconds: 25));
    if (r.statusCode != 200) return [];
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    return (j['elements'] as List? ?? [])
        .map<Map<String, dynamic>>((e) {
          final t = (e['tags'] as Map?)?.cast<String, dynamic>() ?? {};
          final nodeLat = e['lat'] ?? (e['center']?['lat']);
          final nodeLng = e['lon'] ?? (e['center']?['lon']);
          return <String, dynamic>{
            'name': t['name'] ?? category,
            'lat': (nodeLat as num?)?.toDouble(),
            'lng': (nodeLng as num?)?.toDouble(),
            'opening_hours': t['opening_hours'],
          };
        })
        .where((m) => m['lat'] != null && m['lng'] != null)
        .toList();
  } catch (_) {
    return [];
  }
}

Future<Map<String, dynamic>?> weatherDirect(double lat, double lng) async {
  try {
    final r = await http
        .get(Uri.parse(
            'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lng&current=temperature_2m,relative_humidity_2m,precipitation,weathercode,wind_speed_10m,visibility&hourly=precipitation_probability,visibility,temperature_2m&forecast_days=1&timezone=auto'))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode != 200) return null;
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    j['cached'] = true; // label for the UI chip
    return j;
  } catch (_) {
    return null;
  }
}

/// OpenStreetMap Route via public OSRM demo. `pref` selects among returned
/// alternatives; 'notoll' excludes motorways (most Indian toll roads).
Future<Map<String, dynamic>?> routeDirect({
  required List<List<double>> waypoints,
  String pref = 'fastest',
}) async {
  final coords = waypoints.map((w) => '${w[1]},${w[0]}').join(';');
  final exclude = pref == 'notoll' ? '&exclude=motorway' : '';
  final url =
      'https://router.project-osrm.org/route/v1/driving/$coords?overview=full&geometries=polyline&steps=false&alternatives=3$exclude';
  try {
    final r = await http
        .get(Uri.parse(url), headers: const {'User-Agent': 'RideSync/0.1'})
        .timeout(const Duration(seconds: 20));
    if (r.statusCode != 200) return null;
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    final list = (j['routes'] as List? ?? []);
    if (list.isEmpty) return null;
    int pick = 0;
    if (pref == 'shortest') {
      pick = list
          .asMap()
          .entries
          .reduce((a, b) =>
              (a.value['distance'] as num) <= (b.value['distance'] as num)
                  ? a
                  : b)
          .key;
    } else {
      pick = list
          .asMap()
          .entries
          .reduce((a, b) =>
              (a.value['duration'] as num) <= (b.value['duration'] as num)
                  ? a
                  : b)
          .key;
    }
    final route = list[pick] as Map<String, dynamic>;
    return {
      'encoded_polyline': route['geometry'],
      'total_distance': route['distance'],
      'estimated_duration': (route['duration'] as num).round(),
      'estimated': false,
    };
  } catch (_) {
    return null;
  }
}

/// Google-encoded polyline (precision 5) → coordinate list.
List<LatLng> decodePolyline(String encoded) {
  final points = <LatLng>[];
  var index = 0, lat = 0, lng = 0;
  while (index < encoded.length) {
    var result = 0, shift = 0, byte = 0;
    do {
      byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1F) << shift;
      shift += 5;
    } while (byte >= 0x20);
    final dLat = (result & 1) != 0 ? ~(result >> 1) : result >> 1;
    lat += dLat;
    result = 0;
    shift = 0;
    do {
      byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1F) << shift;
      shift += 5;
    } while (byte >= 0x20);
    final dLng = (result & 1) != 0 ? ~(result >> 1) : result >> 1;
    lng += dLng;
    points.add(LatLng(lat / 1e5, lng / 1e5));
  }
  return points;
}
