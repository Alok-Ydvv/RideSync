import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../providers/ride_provider.dart';
import '../../../data/repositories/poi_repository.dart';

/// Weather strip: one Edge-cached fetch per ride per 20 min (Open-Meteo free).
/// Alerts: rain / fog / storm / heat >40C / cold <5C.
class WeatherStrip extends ConsumerStatefulWidget {
  const WeatherStrip({super.key});
  @override
  ConsumerState<WeatherStrip> createState() => _WeatherStripState();
}

class _WeatherStripState extends ConsumerState<WeatherStrip> {
  Map<String, dynamic>? _w;
  bool _busy = false;

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final p = await Geolocator.getCurrentPosition();
      final rideId = ref.read(activeRideProvider)?.id ?? 'local';
      final w = await PoiRepository()
          .weather(rideId: rideId, lat: p.latitude, lng: p.longitude);
      setState(() => _w = w);
    } catch (_) {
      // Offline: cached row stays visible from last load.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  Widget build(BuildContext context) {
    final cur = (_w?['current'] as Map?)?.cast<String, dynamic>();
    if (cur == null) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.cloud_outlined),
          title: Text(_busy ? 'Checking weather…' : 'Weather unavailable offline'),
          trailing: IconButton(
              icon: const Icon(Icons.refresh), onPressed: _load),
        ),
      );
    }
    final t = (cur['temperature_2m'] as num?)?.toDouble() ?? 0;
    final rain = (cur['precipitation'] as num?)?.toDouble() ?? 0;
    final code = (cur['weathercode'] as num?)?.toInt() ?? 0;
    String alert = '';
    if (rain > 0) alert = '🌧️ Rain';
    if (code >= 45 && code <= 48) alert = '🌫️ Fog';
    if (t > 40) alert = '🌡️ Extreme heat';
    if (t < 5) alert = '❄️ Extreme cold';
    return Card(
      child: ListTile(
        leading: const Icon(Icons.cloud),
        title: Text('${t.round()}°C ${alert.isEmpty ? '' : '· $alert'}'),
        subtitle: Text(_w!['cached'] == true
            ? 'Cached (shared to group)'
            : 'Live (shared to group)'),
        trailing:
            IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
      ),
    );
  }
}
