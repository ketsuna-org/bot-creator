/// Abstract interface over bot data storage.
/// Both [AppManager] (Flutter app) and [RunnerDataStore] (CLI runner) implement this.
abstract class BotDataStore {
  /// Returns all global variables for [botId].
  Future<Map<String, String>> getGlobalVariables(String botId);

  /// Returns a single global variable value, or null if not set.
  Future<String?> getGlobalVariable(String botId, String key);

  /// Persists or updates a global variable.
  Future<void> setGlobalVariable(String botId, String key, String value);

  /// Removes a global variable.
  Future<void> removeGlobalVariable(String botId, String key);

  /// Finds a workflow by name (case-insensitive), or null if not found.
  Future<Map<String, dynamic>?> getWorkflowByName(String botId, String name);
}
