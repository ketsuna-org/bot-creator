import 'dart:convert';

dynamic _extractJsonPath(dynamic data, String rawPath) {
  var path = rawPath.trim();
  if (path.isEmpty) {
    return null;
  }

  if (path.startsWith(r'$.')) {
    path = path.substring(2);
  } else if (path.startsWith(r'$')) {
    path = path.substring(1);
  }

  if (path.isEmpty) {
    return data;
  }

  final segments = <Object>[];
  final token = StringBuffer();

  void flushToken() {
    if (token.isNotEmpty) {
      segments.add(token.toString());
      token.clear();
    }
  }

  for (var index = 0; index < path.length; index++) {
    final char = path[index];
    if (char == '.') {
      flushToken();
      continue;
    }

    if (char == '[') {
      flushToken();
      final closing = path.indexOf(']', index + 1);
      if (closing == -1) {
        return null;
      }
      final indexText = path.substring(index + 1, closing).trim();
      final listIndex = int.tryParse(indexText);
      if (listIndex == null) {
        return null;
      }
      segments.add(listIndex);
      index = closing;
      continue;
    }

    token.write(char);
  }

  flushToken();

  dynamic current = data;
  for (final segment in segments) {
    if (segment is String) {
      if (segment.isEmpty) {
        continue;
      }
      if (current is Map && current.containsKey(segment)) {
        current = current[segment];
      } else {
        return null;
      }
      continue;
    }

    if (segment is int) {
      if (current is List && segment >= 0 && segment < current.length) {
        current = current[segment];
      } else {
        return null;
      }
    }
  }

  return current;
}

String? _resolveComputedVariable(String key, Map<String, String> updates) {
  final marker = '.body.';
  final markerIndex = key.indexOf(marker);
  if (markerIndex == -1) {
    return null;
  }

  final bodyVariableKey = key.substring(0, markerIndex + '.body'.length);
  final jsonPathRaw = key.substring(markerIndex + marker.length);
  if (!jsonPathRaw.startsWith(r'$')) {
    return null;
  }

  final rawBody = updates[bodyVariableKey];
  if (rawBody == null || rawBody.isEmpty) {
    return null;
  }

  dynamic decoded;
  try {
    decoded = jsonDecode(rawBody);
  } catch (_) {
    return null;
  }

  final extracted = _extractJsonPath(decoded, jsonPathRaw);
  if (extracted == null) {
    return null;
  }

  if (extracted is String) {
    return extracted;
  }
  if (extracted is num || extracted is bool) {
    return extracted.toString();
  }

  return jsonEncode(extracted);
}

String resolveTemplatePlaceholders(String initial, Map<String, String> updates) {
  final placeholderRegex = RegExp(r'\(\((.*?)\)\)', caseSensitive: false);

  return initial.replaceAllMapped(placeholderRegex, (match) {
    final content = match.group(1)!;
    final keys = content.split('|').map((k) => k.trim()).toList();

    for (final key in keys) {
      if (updates.containsKey(key)) {
        return updates[key]!;
      }

      final computed = _resolveComputedVariable(key, updates);
      if (computed != null) {
        return computed;
      }
    }

    return '';
  });
}
