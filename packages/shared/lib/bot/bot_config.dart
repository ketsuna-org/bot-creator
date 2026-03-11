import 'dart:convert';

/// Immutable configuration loaded from a bot ZIP export.
/// This is the single source of truth for the runner.
class BotConfig {
  final String token;
  final Map<String, bool> intents;
  final Map<String, String> globalVariables;
  final List<Map<String, dynamic>> workflows;

  /// List of commands. Each entry looks like:
  /// { "id": "123456789", "name": "hello", "data": { "response": {...}, "actions": [...] } }
  final List<Map<String, dynamic>> commands;

  const BotConfig({
    required this.token,
    this.intents = const {},
    this.globalVariables = const {},
    this.workflows = const [],
    this.commands = const [],
  });

  factory BotConfig.fromJson(Map<String, dynamic> json) {
    return BotConfig(
      token: (json['token'] ?? '').toString(),
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
    'intents': intents,
    'globalVariables': globalVariables,
    'workflows': workflows,
    'commands': commands,
  };

  /// Validates the minimal required fields.
  void validate() {
    if (token.trim().isEmpty) {
      throw ArgumentError('BotConfig: token cannot be empty');
    }
  }

  @override
  String toString() =>
      'BotConfig(commands: ${commands.length}, workflows: ${workflows.length})';
}

/// Parses a [BotConfig] from raw JSON bytes or a JSON string.
BotConfig parseBotConfig(String jsonString) {
  final Map<String, dynamic> json =
      jsonDecode(jsonString) as Map<String, dynamic>;
  return BotConfig.fromJson(json);
}
