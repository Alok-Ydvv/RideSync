/// Phase 1 offline queue contract.
/// Hive buffers positions/messages offline; Workmanager delta-syncs on reconnect.
/// Conflict: positions last-write-wins, messages merge (+offline tag), settings leader-wins.
abstract class SyncService {
  /// Enqueue a payload while offline. Returns queue length.
  Future<int> enqueue(Map<String, dynamic> payload);

  /// Push pending items when online. Returns count synced.
  Future<int> flush();
}

/// In-memory stub so UI compiles before Hive wiring lands.
class InMemorySyncService implements SyncService {
  final List<Map<String, dynamic>> _q = [];
  @override
  Future<int> enqueue(Map<String, dynamic> p) async {
    _q.add(p);
    return _q.length;
  }

  @override
  Future<int> flush() async {
    final n = _q.length;
    _q.clear();
    return n;
  }
}
