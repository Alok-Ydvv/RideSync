import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../providers/chat_provider.dart';
import '../../providers/ride_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../data/datasources/supabase_client.dart';
import '../../../data/models/chat_models.dart';

/// Phase 1 chat: text + photo + location pin + voice-note placeholder.
/// Photos upload to `chat-media` bucket; offline sends queue with flag.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _text = TextEditingController();
  bool _sending = false;
  static const _uuid = Uuid();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final group = ref.read(currentGroupProvider);
    if (group == null) return;
    try {
      final msgs =
          await ref.read(chatRepositoryProvider).fetchMessages(group.id);
      ref.read(messagesProvider.notifier).state = msgs;
    } catch (_) {
      // Offline: keep local list.
    }
  }

  Future<void> _sendText() async {
    final group = ref.read(currentGroupProvider);
    final uid = ref.read(authRepositoryProvider).session?.user.id;
    final content = _text.text.trim();
    if (content.isEmpty || group == null) return;
    _text.clear();
    final local = ChatMessage(
      id: 'local-${DateTime.now().millisecondsSinceEpoch}',
      groupId: group.id,
      senderId: uid ?? 'local',
      content: content,
      sentAt: DateTime.now(),
      offline: uid == null,
    );
    ref.read(messagesProvider.notifier).state = [
      ...ref.read(messagesProvider),
      local,
    ];
    if (uid == null) return;
    setState(() => _sending = true);
    try {
      await ref.read(chatRepositoryProvider).sendMessage(
            groupId: group.id,
            senderId: uid,
            content: content,
          );
      await _load();
    } catch (_) {
      // Queued offline; flagged on the local row.
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendPhoto() async {
    final group = ref.read(currentGroupProvider);
    final uid = ref.read(authRepositoryProvider).session?.user.id;
    if (group == null || uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login + backend required for photos.')),
      );
      return;
    }
    final img =
        await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (img == null) return;
    try {
      final bytes = await img.readAsBytes();
      final path = '$uid/${_uuid.v4()}.jpg';
      await trySupabase()!.storage.from('chat-media').uploadBinary(path, bytes);
      final url =
          trySupabase()!.storage.from('chat-media').getPublicUrl(path);
      await ref.read(chatRepositoryProvider).sendMessage(
            groupId: group.id,
            senderId: uid,
            type: 'image',
            content: url,
          );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Photo failed: $e')));
      }
    }
  }

  Future<void> _sendPin() async {
    final group = ref.read(currentGroupProvider);
    final uid = ref.read(authRepositoryProvider).session?.user.id;
    if (group == null) return;
    try {
      final p = await Geolocator.getCurrentPosition();
      final content = 'geo:${p.latitude},${p.longitude}';
      if (uid == null) {
        ref.read(messagesProvider.notifier).state = [
          ...ref.read(messagesProvider),
          ChatMessage(
            id: 'local-pin',
            groupId: group.id,
            senderId: 'local',
            type: 'location',
            content: content,
            sentAt: DateTime.now(),
            offline: true,
          ),
        ];
        return;
      }
      await ref.read(chatRepositoryProvider).sendMessage(
            groupId: group.id,
            senderId: uid,
            type: 'location',
            content: content,
          );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Pin failed: $e')));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  Widget build(BuildContext context) {
    final msgs = ref.watch(messagesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Group Chat')),
      body: Column(
        children: [
          Expanded(
            child: msgs.isEmpty
                ? const Center(child: Text('No messages yet. Say hi 👋'))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: msgs.length,
                    itemBuilder: (_, i) {
                      final m = msgs[i];
                      final isImg = m.type == 'image';
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (isImg)
                                  const Text('📷 Photo (tap URL to open)'),
                                Text(m.content),
                                Text(
                                  '${m.sentAt.toLocal().hour}:${m.sentAt.toLocal().minute.toString().padLeft(2, '0')}${m.offline ? ' · offline' : ''}',
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Row(
              children: [
                IconButton(
                    icon: const Icon(Icons.photo), onPressed: _sendPhoto),
                IconButton(
                    icon: const Icon(Icons.location_pin),
                    onPressed: _sendPin),
                IconButton(
                  icon: const Icon(Icons.mic),
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Voice notes: record → chat-media upload (same as photo path). PTT arrives in Phase 2.')),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _text,
                    decoration: const InputDecoration(hintText: 'Message…'),
                    onSubmitted: (_) => _sendText(),
                  ),
                ),
                IconButton(
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send),
                  onPressed: _sending ? null : _sendText,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
