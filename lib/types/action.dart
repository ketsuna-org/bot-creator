enum BotCreatorActionType {
  deleteMessages,
  createChannel,
  updateChannel,
  removeChannel,
  sendMessage,
  editMessage,
  addReaction,
  removeReaction,
  clearAllReactions,
  banUser,
  unbanUser,
  kickUser,
  muteUser,
  unmuteUser,
  pinMessage,
  updateAutoMod,
  updateGuild,
  listMembers,
  getMember,
  sendComponentV2,
  editComponentV2,
  sendWebhook,
  editWebhook,
  deleteWebhook,
  listWebhooks,
  getWebhook,
  makeList,
}

class Action {
  final BotCreatorActionType type;
  final String? key; // Optional key for identifying specific actions
  final List<String> dependOn = []; // List of actions this action depends on
  final Map<String, String> error = {}; // Error messages for the action
  final Map<String, dynamic> payload; // Additional data for the action

  Action({required this.type, this.key, required this.payload});

  @override
  String toString() {
    return 'Action(type: $type, key: $key, payload: $payload)';
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'key': key,
      'depend_on': dependOn,
      'error': error,
      'payload': payload,
    };
  }

  factory Action.fromJson(Map<String, dynamic> json) {
    return Action(
        type: BotCreatorActionType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse:
              () => throw ArgumentError('Invalid action type: ${json['type']}'),
        ),
        key: json['key'] as String?,
        payload: json['payload'] as Map<String, dynamic>,
      )
      ..dependOn.addAll(List<String>.from(json['depend_on'] ?? []))
      ..error.addAll(Map<String, String>.from(json['error'] ?? {}));
  }

  Action copyWith({
    BotCreatorActionType? type,
    String? key,
    List<String>? dependOn,
    Map<String, String>? error,
    Map<String, dynamic>? payload,
  }) {
    return Action(
        type: type ?? this.type,
        key: key ?? this.key,
        payload: payload ?? this.payload,
      )
      ..dependOn.addAll(dependOn ?? this.dependOn)
      ..error.addAll(error ?? this.error);
  }

  bool get hasError => error.isNotEmpty;
  bool get hasKey => key != null && key!.isNotEmpty;
  bool get hasDependOn => dependOn.isNotEmpty;
}
