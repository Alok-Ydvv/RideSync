/// Phase 1 chat + command models. Mirrors Supabase: messages, commands.
/// PTT deferred to Phase 2; voice notes are Storage URLs with type=voice.
class ChatMessage {
  final String id;
  final String groupId;
  final String senderId;
  final String type; // text | image | voice | location
  final String content;
  final DateTime sentAt;
  final bool offline;

  const ChatMessage({
    required this.id,
    required this.groupId,
    required this.senderId,
    this.type = 'text',
    required this.content,
    required this.sentAt,
    this.offline = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as String,
        groupId: j['group_id'] as String,
        senderId: j['sender_id'] as String,
        type: (j['message_type'] ?? 'text') as String,
        content: (j['content'] ?? '') as String,
        sentAt: DateTime.parse(j['sent_at'] as String),
        offline: (j['is_offline_message'] ?? false) as bool,
      );
}

class LeaderCommand {
  final String id;
  final String rideId;
  final String senderId;
  final String type; // stop|slow|left|right|hazard|fuel|rest|parking
  final DateTime sentAt;

  const LeaderCommand({
    required this.id,
    required this.rideId,
    required this.senderId,
    required this.type,
    required this.sentAt,
  });

  factory LeaderCommand.fromJson(Map<String, dynamic> j) => LeaderCommand(
        id: j['id'] as String,
        rideId: j['ride_id'] as String,
        senderId: j['sender_id'] as String,
        type: (j['command_type'] ?? 'slow') as String,
        sentAt: DateTime.parse(j['sent_at'] as String),
      );

  static const labels = {
    'stop': '🛑 STOP',
    'slow': '🐢 SLOW DOWN',
    'left': '⬅️ LEFT TURN',
    'right': '➡️ RIGHT TURN',
    'hazard': '⚠️ HAZARD',
    'fuel': '⛽ FUEL STOP',
    'rest': '☕ REST STOP',
    'parking': '🅿️ PARKING',
  };
}
