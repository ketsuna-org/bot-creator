import 'dart:convert';

class BotStatusConfig {
  final String type;
  final String text;
  final int minIntervalSeconds;
  final int maxIntervalSeconds;

  const BotStatusConfig({
    required this.type,
    required this.text,
    required this.minIntervalSeconds,
    required this.maxIntervalSeconds,
  });

  factory BotStatusConfig.fromJson(Map<String, dynamic> json) {
    final minRaw = int.tryParse((json['minIntervalSeconds'] ?? '').toString());
    final maxRaw = int.tryParse((json['maxIntervalSeconds'] ?? '').toString());
    final min = (minRaw != null && minRaw > 0) ? minRaw : 60;
    final maxCandidate = (maxRaw != null && maxRaw > 0) ? maxRaw : min;
    final max = maxCandidate < min ? min : maxCandidate;

    return BotStatusConfig(
      type: (json['type'] ?? 'playing').toString().trim().toLowerCase(),
      text: (json['text'] ?? '').toString(),
      minIntervalSeconds: min,
      maxIntervalSeconds: max,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'text': text,
    'minIntervalSeconds': minIntervalSeconds,
    'maxIntervalSeconds': maxIntervalSeconds,
  };

  void validate() {
    if (text.trim().isEmpty) {
      throw ArgumentError('BotStatusConfig: text cannot be empty');
    }

    const allowedTypes = <String>{
      'playing',
      'streaming',
      'listening',
      'watching',
      'competing',
    };
    if (!allowedTypes.contains(type)) {
      throw ArgumentError('BotStatusConfig: unsupported type "$type"');
    }

    if (minIntervalSeconds <= 0 || maxIntervalSeconds <= 0) {
      throw ArgumentError(
        'BotStatusConfig: min/max interval must be greater than zero',
      );
    }

    if (maxIntervalSeconds < minIntervalSeconds) {
      throw ArgumentError(
        'BotStatusConfig: max interval cannot be smaller than min interval',
      );
    }
  }
}

/// Immutable configuration loaded from a bot ZIP export.
/// This is the single source of truth for the runner.
class BotConfig {
  final String token;
  final String? username;
  final String? avatarPath;
  final Map<String, bool> intents;
  final Map<String, String> globalVariables;
  final List<Map<String, dynamic>> workflows;
  final List<BotStatusConfig> statuses;

  /// List of commands. Each entry looks like:
  /// { "id": "123456789", "name": "hello", "data": { "response": {...}, "actions": [...] } }
  final List<Map<String, dynamic>> commands;

  const BotConfig({
    required this.token,
    this.username,
    this.avatarPath,
    this.intents = const {},
    this.globalVariables = const {},
    this.workflows = const [],
    this.statuses = const [],
    this.commands = const [],
  });

  factory BotConfig.fromJson(Map<String, dynamic> json) {
    return BotConfig(
      token: (json['token'] ?? '').toString(),
      username: _optionalString(json['username']),
      avatarPath: _optionalString(json['avatarPath']),
      intents: Map<String, bool>.from(
        (json['intents'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), v == true),
            ) ??
            const {},
      ),
      globalVariables: Map<String, String>.from(
        (json['globalVariables'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
            ) ??
            const {},
      ),
      workflows: List<Map<String, dynamic>>.from(
        (json['workflows'] as List?)?.whereType<Map>().map(
              (w) => Map<String, dynamic>.from(w),
            ) ??
            const [],
      ),
      statuses: List<BotStatusConfig>.from(
        (json['statuses'] as List?)?.whereType<Map>().map(
              (s) => BotStatusConfig.fromJson(Map<String, dynamic>.from(s)),
            ) ??
            const [],
      ),
      commands: List<Map<String, dynamic>>.from(
        (json['commands'] as List?)?.whereType<Map>().map(
              (c) => Map<String, dynamic>.from(c),
            ) ??
            const [],
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'token': token,
    if (username != null) 'username': username,
    if (avatarPath != null) 'avatarPath': avatarPath,
    'intents': intents,
    'globalVariables': globalVariables,
    'workflows': workflows,
    'statuses': statuses.map((s) => s.toJson()).toList(growable: false),
    'commands': commands,
  };

  /// Validates the minimal required fields.
  void validate() {
    if (token.trim().isEmpty) {
      throw ArgumentError('BotConfig: token cannot be empty');
    }

    if (username != null && username!.trim().isEmpty) {
      throw ArgumentError('BotConfig: username cannot be blank');
    }

    if (avatarPath != null && avatarPath!.trim().isEmpty) {
      throw ArgumentError('BotConfig: avatarPath cannot be blank');
    }

    for (final status in statuses) {
      status.validate();
    }
  }

  @override
  String toString() =>
      'BotConfig(commands: ${commands.length}, workflows: ${workflows.length})';
}

String? _optionalString(dynamic value) {
  final text = (value ?? '').toString().trim();
  return text.isEmpty ? null : text;
}

/// Parses a [BotConfig] from raw JSON bytes or a JSON string.
BotConfig parseBotConfig(String jsonString) {
  final Map<String, dynamic> json =
      jsonDecode(jsonString) as Map<String, dynamic>;
  return BotConfig.fromJson(json);
}
