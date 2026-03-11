import 'package:bot_creator_shared/bot/bot_config.dart';
import 'package:bot_creator_shared/bot/bot_data_store.dart';
import 'package:bot_creator_shared/utils/workflow_call.dart';

/// In-memory implementation of [BotDataStore] backed by a [BotConfig].
///
/// Global variables are mutable at runtime (actions can set/remove them).
/// Workflows are read from the config.
class RunnerDataStore implements BotDataStore {
  final String botId;
  final Map<String, String> _globalVariables;
  final List<Map<String, dynamic>> _workflows;

  RunnerDataStore(BotConfig config)
    : botId = 'runner',
      _globalVariables = Map<String, String>.from(config.globalVariables),
      _workflows = List<Map<String, dynamic>>.from(config.workflows);

  @override
  Future<Map<String, String>> getGlobalVariables(String botId) async =>
      Map<String, String>.from(_globalVariables);

  @override
  Future<String?> getGlobalVariable(String botId, String key) async =>
      _globalVariables[key];

  @override
  Future<void> setGlobalVariable(String botId, String key, String value) async {
    _globalVariables[key] = value;
  }

  @override
  Future<void> removeGlobalVariable(String botId, String key) async {
    _globalVariables.remove(key);
  }

  @override
  Future<Map<String, dynamic>?> getWorkflowByName(
    String botId,
    String name,
  ) async {
    final lower = name.toLowerCase();
    for (final w in _workflows) {
      if ((w['name'] ?? '').toString().toLowerCase() == lower) {
        return _normalizeWorkflow(Map<String, dynamic>.from(w));
      }
    }
    return null;
  }

  Map<String, dynamic> _normalizeWorkflow(Map<String, dynamic> w) {
    final normalized = Map<String, dynamic>.from(w);
    normalized['name'] = (normalized['name'] ?? '').toString().trim();
    normalized['entryPoint'] = normalizeWorkflowEntryPoint(
      normalized['entryPoint'],
    );
    normalized['arguments'] = serializeWorkflowArgumentDefinitions(
      parseWorkflowArgumentDefinitions(normalized['arguments']),
    );
    normalized['actions'] = List<Map<String, dynamic>>.from(
      (normalized['actions'] as List?)?.whereType<Map>().map(
            (a) => Map<String, dynamic>.from(a),
          ) ??
          const [],
    );
    return normalized;
  }
}
