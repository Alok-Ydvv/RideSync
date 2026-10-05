import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/repositories/poi_repository.dart';

/// Nearby places: fuel, hospital, mechanic, ATM, food, parking.
/// Server-side Overpass via Edge; shows distance + navigate. Cached offline read-only.
class NearbyScreen extends StatefulWidget {
  const NearbyScreen({super.key});
  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  String _cat = 'fuel';
  bool _busy = false;
  List<Map<String, dynamic>> _items = [];

  static const cats = {
    'fuel': '⛽ Fuel',
    'hospital': '🏥 Hospital',
    'mechanic': '🔧 Mechanic',
    'atm': '🏧 ATM',
    'food': '🍽️ Food',
    'parking': '🅿️ Parking',
  };

  Future<void> _search() async {
    setState(() => _busy = true);
    try {
      final p = await Geolocator.getCurrentPosition();
      final items = await PoiRepository().nearby(
        lat: p.latitude,
        lng: p.longitude,
        category: _cat,
      );
      setState(() => _items = items);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Search failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_search);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nearby Places')),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                for (final e in cats.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(e.value),
                      selected: _cat == e.key,
                      onSelected: (_) {
                        setState(() => _cat = e.key);
                        _search();
                      },
                    ),
                  ),
              ],
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          Expanded(
            child: _items.isEmpty && !_busy
                ? const Center(
                    child: Text(
                        'No results (offline or no backend yet).\nPre-downloaded POIs show here when cached.'))
                : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (_, i) {
                      final it = _items[i];
                      return ListTile(
                        leading: const Icon(Icons.place),
                        title: Text((it['name'] ?? _cat).toString()),
                        subtitle: Text(
                            '${it['dist_m'] ?? '?'} m${it['opening_hours'] != null ? ' · ${it['opening_hours']}' : ''}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.navigation),
                          onPressed: () => launchUrl(Uri.parse(
                              'https://maps.google.com/?q=${it['lat']},${it['lng']}')),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
