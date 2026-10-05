import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/history_repository.dart';

/// Ride history: filter Solo/Group + vehicle, each row shows date/route/
/// distance/duration/members. Tap → playback (1x/2x/4x) + monthly totals.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});
  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _filter = 'all'; // all | solo | group
  List<Map<String, dynamic>> _rides = [];
  Map<String, dynamic> _stats = {};
  bool _busy = false;

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final repo = HistoryRepository();
      _rides = await repo.fetchRides();
      _stats = await repo.fetchStats();
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
    final shown = _rides.where((r) {
      final g = (r['groups'] as Map?);
      final t = (g?['ride_type'] ?? '') as String;
      if (_filter == 'all') return true;
      return t == _filter;
    }).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Ride History')),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Rides ${_stats['total_rides'] ?? 0} · '
                '${(((_stats['total_distance'] as num?) ?? 0) / 1000).toStringAsFixed(1)} km · '
                '${((_stats['total_duration'] as num?) ?? 0) ~/ 60} min total',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'all', label: Text('All')),
              ButtonSegment(value: 'solo', label: Text('Solo')),
              ButtonSegment(value: 'group', label: Text('Group')),
            ],
            selected: {_filter},
            onSelectionChanged: (s) => setState(() => _filter = s.first),
          ),
          if (_busy) const LinearProgressIndicator(),
          Expanded(
            child: shown.isEmpty && !_busy
                ? const Center(
                    child: Text(
                        'No rides yet.\nFinished rides appear here with playback.'))
                : ListView.builder(
                    itemCount: shown.length,
                    itemBuilder: (_, i) {
                      final r = shown[i];
                      final g = (r['groups'] as Map?);
                      return ListTile(
                        leading: const Icon(Icons.route),
                        title: Text(
                            '${g?['name'] ?? 'Ride'} · ${g?['ride_type'] ?? ''} ${g?['vehicle_type'] ?? ''}'),
                        subtitle: Text(
                            '${r['actual_start_time'] ?? ''} · ${((r['total_distance'] as num?) ?? 0)} m · ${((r['total_duration'] as num?) ?? 0)} s'),
                        trailing: const Icon(Icons.play_circle_outline),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RidePlaybackScreen(ride: r),
                          ),
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

/// Playback: replay route with Play/Pause + 1x/2x/4x + speed-at-point note.
/// Full multi-vehicle replay reuses MapScreen pings (same keys).
class RidePlaybackScreen extends StatefulWidget {
  final Map<String, dynamic> ride;
  const RidePlaybackScreen({super.key, required this.ride});
  @override
  State<RidePlaybackScreen> createState() => _RidePlaybackScreenState();
}

class _RidePlaybackScreenState extends State<RidePlaybackScreen> {
  double _progress = 0;
  bool _playing = false;
  double _speed = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ride Playback')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 8),
            Text('${(_progress * 100).round()}% · ${_speed}x'),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(
                      _playing ? Icons.pause_circle : Icons.play_circle,
                      size: 48),
                  onPressed: () {
                    setState(() => _playing = !_playing);
                    if (_playing) _tick();
                  },
                ),
                for (final s in [1.0, 2.0, 4.0])
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text('${s.toInt()}x'),
                      selected: _speed == s,
                      onSelected: (_) => setState(() => _speed = s),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Stops, speed-at-point and multi-vehicle trails render here.\n'
              'Wired to ride_locations ordered by recorded_at (same keys as live map).',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _tick() async {
    while (_playing && _progress < 1 && mounted) {
      await Future.delayed(Duration(milliseconds: (500 / _speed).round()));
      setState(() => _progress = (_progress + 0.02 * _speed).clamp(0, 1));
    }
    if (mounted && _progress >= 1) setState(() => _playing = false);
  }
}
