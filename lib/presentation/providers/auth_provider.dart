import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/auth_repository.dart';
import '../../data/models/user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

/// Current session (null = logged out OR backend unconfigured in dev).
final sessionProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authChanges;
});

/// Current profile row. Null while logged out / not yet set up.
final profileProvider = FutureProvider<UserModel?>((ref) async {
  final repo = ref.watch(authRepositoryProvider);
  final uid = repo.session?.user.id;
  if (uid == null) return null;
  return repo.fetchProfile(uid);
});

/// Simple loading flag for auth buttons (OTP send/verify, OAuth).
final authLoadingProvider = StateProvider<bool>((ref) => false);
