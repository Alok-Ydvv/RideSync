import 'package:supabase_flutter/supabase_flutter.dart';

import '../datasources/supabase_client.dart';
import '../models/user_model.dart';
import '../../core/errors/failures.dart';

/// Phase 1 auth: phone OTP (primary, India) + email/password + Google + Apple.
/// SMS cost note: OTP SMS is the only non-free step (MSG91/Gupshup DLT BYO).
/// Throttle: 60s resend enforced in UI; expiry handled server-side.
class AuthRepository {
  SupabaseClient get _c {
    final c = trySupabase();
    if (c == null) throw const NetworkFailure('Backend not configured. Add .env.');
    return c;
  }

  Session? get session => trySupabase()?.auth.currentSession;

  Stream<AuthState> get authChanges {
    final c = trySupabase();
    if (c == null) return const Stream.empty();
    return c.auth.onAuthStateChange;
  }

  /// Send 6-digit OTP to +91 phone. Caller passes digits only; we prefix +91.
  Future<void> sendPhoneOtp(String phoneDigits) async {
    final digits = phoneDigits.replaceAll(RegExp(r'\D'), '');
    final phone = digits.startsWith('+') ? digits : '+91$digits';
    await _c.auth.signInWithOtp(phone: phone);
  }

  Future<AuthResponse> verifyPhoneOtp(String phoneDigits, String otp) async {
    final digits = phoneDigits.replaceAll(RegExp(r'\D'), '');
    final phone = digits.startsWith('+') ? digits : '+91$digits';
    return _c.auth.verifyOTP(type: OtpType.sms, phone: phone, token: otp.trim());
  }

  Future<AuthResponse> signInEmail(String email, String password) =>
      _c.auth.signInWithPassword(email: email.trim(), password: password);

  Future<AuthResponse> signUpEmail(String email, String password) =>
      _c.auth.signUp(email: email.trim(), password: password);

  /// OAuth via Supabase (Google/Apple configured in dashboard). Returns true
  /// if the OS browser flow was launched.
  Future<bool> signInOAuth(OAuthProvider provider) =>
      _c.auth.signInWithOAuth(provider);

  Future<void> signOut() => _c.auth.signOut();

  /// Upsert profile row keyed by auth.uid(). Called after first login.
  Future<UserModel> upsertProfile(UserModel profile) async {
    final res = await _c.from('users').upsert(profile.toJson()).select().single();
    return UserModel.fromJson(res);
  }

  Future<UserModel?> fetchProfile(String uid) async {
    final res =
        await _c.from('users').select().eq('id', uid).maybeSingle();
    return res == null ? null : UserModel.fromJson(res);
  }

  Future<void> saveEmergencyContacts(
      List<EmergencyContactModel> contacts) async {
    if (contacts.isEmpty || contacts.length > 3) {
      throw const AuthFailure('Add 1-3 emergency contacts.');
    }
    await _c.from('emergency_contacts').upsert(
          contacts.map((e) => e.toJson()).toList(),
        );
  }

  Future<List<EmergencyContactModel>> fetchEmergencyContacts(String uid) async {
    final res = await _c
        .from('emergency_contacts')
        .select()
        .eq('user_id', uid)
        .order('priority');
    return (res as List).map((e) => EmergencyContactModel.fromJson(e)).toList();
  }
}
