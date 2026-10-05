import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../datasources/supabase_client.dart';
import '../models/chat_models.dart';
import '../../core/errors/failures.dart';

/// Phase 1 chat/commands repo. Online: Supabase tables. Offline: throw
/// NetworkFailure so UI queues with `offline=true` and flushes later.
class ChatRepository {
  static const _uuid = Uuid();

  SupabaseClient get _c {
    final c = trySupabase();
    if (c == null) throw const NetworkFailure('Backend not configured.');
    return c;
  }

  Future<List<ChatMessage>> fetchMessages(String groupId, {int limit = 50}) async {
    final res = await _c
        .from('messages')
        .select()
        .eq('group_id', groupId)
        .order('sent_at', ascending: false)
        .limit(limit);
    return (res as List)
        .map((e) => ChatMessage.fromJson(e))
        .toList()
        .reversed
        .toList();
  }

  Future<void> sendMessage({
    required String groupId,
    required String senderId,
    String type = 'text',
    required String content,
    bool offline = false,
  }) async {
    await _c.from('messages').insert({
      'id': _uuid.v4(),
      'group_id': groupId,
      'sender_id': senderId,
      'message_type': type,
      'content': content,
      'is_offline_message': offline,
    });
  }

  Future<List<LeaderCommand>> fetchCommands(String rideId) async {
    final res = await _c
        .from('commands')
        .select()
        .eq('ride_id', rideId)
        .order('sent_at', ascending: false)
        .limit(30);
    return (res as List).map((e) => LeaderCommand.fromJson(e)).toList();
  }

  Future<void> sendCommand({
    required String rideId,
    required String senderId,
    required String type,
  }) async {
    await _c.from('commands').insert({
      'ride_id': rideId,
      'sender_id': senderId,
      'command_type': type,
    });
    // Live fan-out: Broadcast so receivers show fullscreen in <1s
    // (postgres_changes is the durable fallback).
    try {
      await _c.channel('ride:$rideId').sendBroadcastMessage(
        event: 'command',
        payload: {'command_type': type, 'sender_id': senderId},
      );
    } catch (_) {
      // Broadcast is best-effort; DB row still delivers via subscription.
    }
  }
}
