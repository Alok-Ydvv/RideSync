import 'package:supabase_flutter/supabase_flutter.dart';

/// Safe Supabase access. Returns null when backend isn't configured
/// (offline UI dev mode: `.env` missing). Callers must handle null by
/// showing cached UI / queued writes instead of crashing.
SupabaseClient? trySupabase() {
  try {
    return Supabase.instance.client;
  } catch (_) {
    return null;
  }
}

bool get hasBackend => trySupabase() != null;
