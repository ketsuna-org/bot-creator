import '../../../types/action.dart' show BotCreatorActionType;

// Enum pour les types de paramètres
enum ParameterType {
  string,
  number,
  boolean,
  list,
  map,
  duration,
  color,
  url,
  userId,
  channelId,
  messageId,
  roleId,
  emoji,
  multiSelect,
}

enum VariableSuggestionKind { numeric, nonNumeric, unknown }

class VariableSuggestion {
  final String name;
  final VariableSuggestionKind kind;

  const VariableSuggestion({required this.name, required this.kind});

  bool get isNumeric => kind == VariableSuggestionKind.numeric;
  bool get isUnknown => kind == VariableSuggestionKind.unknown;
}

// Modèle pour définir un paramètre avec son type
class ParameterDefinition {
  final String key;
  final ParameterType type;
  final dynamic defaultValue;
  final String? hint;
  final List<String>? options; // Pour les select/multiselect
  final int? minValue;
  final int? maxValue;
  final bool required;

  ParameterDefinition({
    required this.key,
    required this.type,
    required this.defaultValue,
    this.hint,
    this.options,
    this.minValue,
    this.maxValue,
    this.required = false,
  });
}

// Modèle pour représenter une action
class ActionItem {
  final String id;
  final BotCreatorActionType type;
  bool enabled;
  String onErrorMode;
  final Map<String, dynamic> parameters;

  ActionItem({
    required this.id,
    required this.type,
    required this.parameters,
    this.enabled = true,
    this.onErrorMode = 'stop',
  });

  factory ActionItem.fromJson(Map<String, dynamic> json) {
    final parameters = Map<String, dynamic>.from(
      (json['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    final persistedKey = (json['key'] ?? '').toString().trim();
    if (persistedKey.isNotEmpty) {
      parameters['key'] = persistedKey;
    }

    return ActionItem(
      id: (json['id'] ?? '').toString(),
      type: BotCreatorActionType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => BotCreatorActionType.sendMessage,
      ),
      enabled: json['enabled'] as bool? ?? true,
      onErrorMode:
          (Map<String, dynamic>.from(
                    (json['error'] as Map?)?.cast<String, dynamic>() ??
                        const {},
                  )['mode'] ??
                  'stop')
              .toString(),
      parameters: parameters,
    );
  }

  Map<String, dynamic> toJson() {
    final actionKey = (parameters['key'] ?? id).toString();
    return {
      'id': id,
      'type': type.name,
      'enabled': enabled,
      'key': actionKey,
      'depend_on': <String>[],
      'error': {'mode': onErrorMode},
      'payload': parameters,
    };
  }
}
