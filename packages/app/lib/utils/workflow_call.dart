import 'dart:convert';

class WorkflowArgumentDefinition {
  final String name;
  final bool required;
  final String defaultValue;

  const WorkflowArgumentDefinition({
    required this.name,
    this.required = false,
    this.defaultValue = '',
  });

  factory WorkflowArgumentDefinition.fromJson(Map<String, dynamic> json) {
    return WorkflowArgumentDefinition(
      name: (json['name'] ?? '').toString().trim(),
      required: json['required'] == true,
      defaultValue: (json['defaultValue'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'required': required,
    'defaultValue': defaultValue,
  };
}

String normalizeWorkflowEntryPoint(dynamic raw, {String fallback = 'main'}) {
  final value = (raw ?? '').toString().trim();
  if (value.isNotEmpty) {
    return value;
  }
  final normalizedFallback = fallback.trim();
  return normalizedFallback.isEmpty ? 'main' : normalizedFallback;
}

List<WorkflowArgumentDefinition> parseWorkflowArgumentDefinitions(dynamic raw) {
  if (raw is! List) {
    return const [];
  }

  final byKey = <String, WorkflowArgumentDefinition>{};
  for (final item in raw) {
    WorkflowArgumentDefinition? definition;
    if (item is Map) {
      definition = WorkflowArgumentDefinition.fromJson(
        Map<String, dynamic>.from(
          item.map((key, value) => MapEntry(key.toString(), value)),
        ),
      );
    } else if (item is String) {
      final name = item.trim();
      if (name.isNotEmpty) {
        definition = WorkflowArgumentDefinition(name: name);
      }
    }

    if (definition == null || definition.name.isEmpty) {
      continue;
    }

    byKey[definition.name.toLowerCase()] = definition;
  }

  return byKey.values.toList(growable: false);
}

List<Map<String, dynamic>> serializeWorkflowArgumentDefinitions(
  List<WorkflowArgumentDefinition> definitions,
) {
  return definitions
      .where((definition) => definition.name.trim().isNotEmpty)
      .map((definition) => definition.toJson())
      .toList(growable: false);
}

Map<String, String> normalizeWorkflowCallArguments(dynamic raw) {
  if (raw is! Map) {
    return const <String, String>{};
  }

  final result = <String, String>{};
  for (final entry in raw.entries) {
    final key = entry.key.toString().trim();
    if (key.isEmpty) {
      continue;
    }
    result[key] = entry.value?.toString() ?? '';
  }
  return result;
}

Map<String, String> resolveWorkflowCallArguments(
  dynamic raw,
  String Function(String) resolve,
) {
  final normalized = normalizeWorkflowCallArguments(raw);
  if (normalized.isEmpty) {
    return normalized;
  }

  return Map<String, String>.fromEntries(
    normalized.entries.map((entry) {
      return MapEntry(entry.key, resolve(entry.value));
    }),
  );
}

Map<String, String> resolveWorkflowInvocationArguments({
  required List<WorkflowArgumentDefinition> definitions,
  required Map<String, String> providedArguments,
}) {
  if (definitions.isEmpty) {
    return Map<String, String>.from(providedArguments);
  }

  final resolved = <String, String>{};
  final providedByLowercase = <String, MapEntry<String, String>>{
    for (final entry in providedArguments.entries)
      entry.key.toLowerCase(): MapEntry(entry.key, entry.value),
  };

  for (final definition in definitions) {
    final fromProvided = providedByLowercase[definition.name.toLowerCase()];
    final value =
        fromProvided != null ? fromProvided.value : definition.defaultValue;
    if (definition.required && value.trim().isEmpty) {
      throw Exception(
        'Missing required workflow argument "${definition.name}"',
      );
    }
    resolved[definition.name] = value;
  }

  for (final entry in providedArguments.entries) {
    if (!resolved.containsKey(entry.key)) {
      resolved[entry.key] = entry.value;
    }
  }

  return resolved;
}

void applyWorkflowInvocationContext({
  required Map<String, String> variables,
  required String workflowName,
  required String entryPoint,
  required List<WorkflowArgumentDefinition> definitions,
  required Map<String, String> providedArguments,
}) {
  final args = resolveWorkflowInvocationArguments(
    definitions: definitions,
    providedArguments: providedArguments,
  );

  variables['workflow.name'] = workflowName;
  variables['workflow.entryPoint'] = entryPoint;
  variables['workflow.args'] = jsonEncode(args);

  for (final entry in args.entries) {
    variables['arg.${entry.key}'] = entry.value;
    variables['workflow.arg.${entry.key}'] = entry.value;
  }
}
