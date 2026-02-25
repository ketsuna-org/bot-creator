import 'package:nyxx/nyxx.dart';
import '../types/action.dart';

/// Helper pour exécuter une action simple et récupérer un résultat
Future<Map<String, String>> executeSimpleAction(
  Future<Map<String, String>> Function() action,
) async {
  try {
    return await action();
  } catch (error) {
    return {'error': 'Action failed: $error'};
  }
}

/// Helper pour exécuter une action avec validation de résultat
void validateActionResult(
  Map<String, String> result, {
  required Function(String) onError,
}) {
  if (result['error'] != null) {
    onError(result['error'] ?? 'Unknown error');
  }
}

/// Helper pour les actions sans guildId
Future<Map<String, String>> executeActionWithoutGuild(
  Future<Map<String, String>> Function() action,
) => action();

/// Helper pour les actions avec guildId
Future<Map<String, String>> executeActionWithGuild(
  Future<Map<String, String>> Function() action, {
  required Snowflake? guildId,
  String errorMessage = 'This action requires a guild context',
}) {
  if (guildId == null) {
    return Future.value({'error': errorMessage});
  }
  return action();
}

/// Helper pour les actions avec channelId
Future<Map<String, String>> executeActionWithChannel(
  Future<Map<String, String>> Function() action, {
  required Snowflake? channelId,
  String errorMessage = 'Missing or invalid channelId',
}) {
  if (channelId == null) {
    return Future.value({'error': errorMessage});
  }
  return action();
}

/// Extension pour simplifier l'accès aux résultats
extension ActionResultExtension on Map<String, String> {
  bool get hasError => containsKey('error');
  String? get error => this['error'];
  String getOrEmpty(String key) => this[key] ?? '';
}
