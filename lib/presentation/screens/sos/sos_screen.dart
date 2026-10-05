import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/repositories/sos_service_impl.dart';
import '../../providers/ride_provider.dart';

/// SOS Screen: big red button always accessible. 10s cancel window,
/// then triple-path fires (Broadcast + FCM + sms: intent) + nearest hospital.
class SosScreen extends ConsumerStatefulWidget {
  const SosScreen({super.key});
  @override
  ConsumerState<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends ConsumerState<SosScreen> {
  int _countdown = 0;
  Timer? _timer;
  List<Map<String, dynamic>> _hospitals = [];
  bool _loadingHosp = false;
  final _svc = SosServiceImpl();

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _press() async {
    HapticFeedback.heavyImpact();
    setState(() => _countdown = 10);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_countdown <= 1) {
        _timer?.cancel();
        setState(() => _countdown = 0);
        await _fire();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  Future<void> _fire() async {
    try {
      final p = await Geolocator.getCurrentPosition();
      final rideId = ref.read(activeRideProvider)?.id;
      await _svc.trigger(lat: p.latitude, lng: p.longitude, rideId: rideId);
      setState(() => _loadingHosp = true);
      final h = await _svc.nearbyHospitals(p.latitude, p.longitude);
      if (mounted) {
        setState(() {
          _hospitals = h;
          _loadingHosp = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SOS sent: group + SMS contacts.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingHosp = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('SOS failed: $e')));
      }
    }
  }

  void _cancel() {
    _timer?.cancel();
    setState(() => _countdown = 0);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('SOS cancelled (false alarm).')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final arming = _countdown > 0;
    return Scaffold(
      appBar: AppBar(title: const Text('SOS Emergency')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          GestureDetector(
            onTap: arming ? null : _press,
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                color: arming ? Colors.orange : Colors.red,
                borderRadius: BorderRadius.circular(24),
              ),
              alignment: Alignment.center,
              child: Text(
                arming ? 'SENDING IN $_countdown\nTap CANCEL below' : 'SOS\nTAP FOR EMERGENCY',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (arming)
            FilledButton.tonal(
              onPressed: _cancel,
              child: const Text('CANCEL (false alarm)'),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => launchUrl(Uri.parse('tel:100')),
                  child: const Text('Call 100'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => launchUrl(Uri.parse('tel:108')),
                  child: const Text('Call 108'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Nearest hospitals',
              style: TextStyle(fontWeight: FontWeight.w700)),
          if (_loadingHosp) const LinearProgressIndicator(),
          for (final h in _hospitals)
            ListTile(
              leading: const Icon(Icons.local_hospital),
              title: Text((h['name'] ?? 'Hospital').toString()),
              subtitle: Text('${h['dist_m'] ?? '?'} m'),
              trailing: IconButton(
                icon: const Icon(Icons.navigation),
                onPressed: () {
                  final lat = h['lat'];
                  final lng = h['lng'];
                  launchUrl(
                      Uri.parse('https://maps.google.com/?q=$lat,$lng'));
                },
              ),
            ),
        ],
      ),
    );
  }
}
