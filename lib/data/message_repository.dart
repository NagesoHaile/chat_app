import 'dart:collection';

import '../config.dart';
import '../models/message.dart';
import 'message_generator.dart';

/// Single source of messages for the UI.
/// - Generated messages live in a small LRU cache (re-generated on demand).
/// - Messages the user types are kept in [_sent] (few, so memory stays flat).
/// - [loadedImages] remembers which images already finished loading.
class MessageRepository {
  int _total = kTotalMessages;
  final int firstUnreadId = kFirstUnreadId;

  final LinkedHashMap<int, Message> _cache = LinkedHashMap();
  final Map<int, Message> _sent = {};
  final Set<int> loadedImages = <int>{};

  int get total => _total;

  Message get(int id) {
    final sent = _sent[id];
    if (sent != null) return sent;

    final hit = _cache.remove(id);
    if (hit != null) {
      _cache[id] = hit; // move to most-recent position
      return hit;
    }
    final m = MessageGenerator.generate(id);
    _cache[id] = m;
    if (_cache.length > kCacheSize) {
      _cache.remove(_cache.keys.first); // evict least recently used
    }
    return m;
  }

  /// Simulates new messages arriving at the bottom.
  void addMessages(int count) => _total += count;

  /// The user sends a message. Returns its new ID.
  int send(String text) {
    final id = ++_total;
    _sent[id] = Message(
      id: id,
      text: text,
      isMine: true,
      time: DateTime.now(),
      read: false,
    );
    return id;
  }
}
