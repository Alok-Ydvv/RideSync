import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/chat_models.dart';
import '../../data/repositories/chat_repository.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) => ChatRepository());

/// Local-first lists (Supabase fetch when online, seeded demo otherwise).
final messagesProvider = StateProvider<List<ChatMessage>>((ref) => []);
final commandsProvider = StateProvider<List<LeaderCommand>>((ref) => []);

/// Fullscreen command overlay (3s) + audio + vibration. Null = no alert.
final activeCommandProvider = StateProvider<String?>((ref) => null);
