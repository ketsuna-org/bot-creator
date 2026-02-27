/// Registry for active interaction listeners (button clicks and modal submits).
/// Listeners are stored in-memory and pruned when expired.
library;

class ListenerEntry {
  final String botId;
  final String workflowName;
  final DateTime expiresAt;
  final bool oneShot;
  final String type; // 'button' | 'modal'
  final String? guildId;
  final String? channelId;
  final String? userId; // if userId is set, only respond to that user

  const ListenerEntry({
    required this.botId,
    required this.workflowName,
    required this.expiresAt,
    required this.type,
    this.oneShot = true,
    this.guildId,
    this.channelId,
    this.userId,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class InteractionListenerRegistry {
  InteractionListenerRegistry._();
  static final instance = InteractionListenerRegistry._();

  final Map<String, ListenerEntry> _listeners = {};

  /// Register a listener for a specific [customId].
  void register(String customId, ListenerEntry entry) {
    _listeners[customId] = entry;
  }

  /// Retrieve a non-expired listener for [customId], or null.
  ListenerEntry? get(String customId) {
    final entry = _listeners[customId];
    if (entry == null) return null;
    if (entry.isExpired) {
      _listeners.remove(customId);
      return null;
    }
    return entry;
  }

  /// Remove a listener by [customId].
  void remove(String customId) {
    _listeners.remove(customId);
  }

  /// Prune all expired listeners. Call periodically if needed.
  void pruneExpired() {
    _listeners.removeWhere((_, entry) => entry.isExpired);
  }

  /// All currently registered (and non-expired) customIds.
  List<String> get activeCustomIds {
    pruneExpired();
    return _listeners.keys.toList();
  }
}
