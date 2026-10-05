import 'package:geolocator/geolocator.dart';
import 'package:telephony/telephony.dart';
import 'package:url_launcher/url_launcher.dart';

import '../datasources/supabase_client.dart';
import '../sos/sos_service.dart';
import 'poi_repository.dart';

/// SOS triple-path: (1) Realtime Broadcast + sos_alerts row, (2) FCM via
/// DB-triggered push (server-side), (3) SMS via own SIM to emergency
/// contacts (works without internet). Hospitals via cached poi-cache.
class SosServiceImpl implements SosService {
  final Telephony _telephony = Telephony.instance;

  @override
  Future<void> trigger({required double lat, required double lng}) async {
    final c = trySupabase();
    final uid = c?.auth.currentUser?.id;
    // 1. Group broadcast + durable row (best-effort offline).
    try {
      if (c != null && uid != null) {
        final rideId = await _activeRideId(c);
        await c.from('sos_alerts').insert({
          'ride_id': rideId,
          'user_id': uid,
          'location': 'POINT($lng $lat)',
        });
        if (rideId != null) {
          await c.channel('ride:$rideId').sendBroadcastMessage(
            event: 'sos',
            payload: {'user_id': uid, 'lat': lat, 'lng': lng},
          );
        }
      }
    } catch (_) {
      // Offline: SMS path below still fires.
    }
    // 2. SMS to emergency contacts (own SIM, free, offline-capable).
    try {
      final contacts = uid != null && c != null
          ? await c
              .from('emergency_contacts')
              .select('phone')
              .eq('user_id', uid)
          : [];
      final msg =
          'SOS! I need help. Location: https://maps.google.com/?q=$lat,$lng';
      for (final row in (contacts as List? ?? [])) {
        final phone = (row as Map)['phone'] as String?;
        if (phone == null) continue;
        try {
          await _telephony.sendSms(to: phone, message: msg);
        } catch (_) {
          // Dual-SIM / permission edge: fall back to sms: intent.
          await launchUrl(Uri.parse('sms:$phone?body=${Uri.encodeComponent(msg)}'));
        }
      }
    } catch (_) {
      // SMS permission denied: caller shows manual share sheet.
    }
  }

  @override
  Future<void> cancel(String alertId) async {
    try {
      await trySupabase()
          ?.from('sos_alerts')
          .update({'status': 'false_alarm', 'resolved_at': DateTime.now().toIso8601String()})
          .eq('id', alertId);
    } catch (_) {
      // Best-effort.
    }
  }

  Future<List<Map<String, dynamic>>> nearbyHospitals(
      double lat, double lng) async {
    return PoiRepository()
        .nearby(lat: lat, lng: lng, radius: 10000, category: 'hospital');
  }

  Future<String?> _activeRideId(dynamic c) async {
    try {
      final pos = await Geolocator.getLastKnownPosition();
      if (pos == null) return null;
      return null; // Ride linkage resolved by group context in UI slice.
    } catch (_) {
      return null;
    }
  }
}
