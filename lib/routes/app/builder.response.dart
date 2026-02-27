import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../types/action.dart' show BotCreatorActionType;
import 'builder/action_types.dart';
import 'builder/action_type_extension.dart';
import 'builder/action_card.dart';

export 'builder/action_types.dart';
export 'builder/action_type_extension.dart';
export 'builder/action_card.dart';

class ActionsBuilderPage extends StatefulWidget {
  final List<Map<String, dynamic>> initialActions;
  final List<VariableSuggestion> variableSuggestions;

  const ActionsBuilderPage({
    super.key,
    this.initialActions = const [],
    this.variableSuggestions = const [],
  });

  @override
  State<ActionsBuilderPage> createState() => _ActionsBuilderPageState();
}

class _ActionsBuilderPageState extends State<ActionsBuilderPage> {
  final List<ActionItem> _actions = [];
  final Map<String, int> _fieldRefreshVersions = {};
  int _actionCounter = 0;

  @override
  void initState() {
    super.initState();
    for (final action in widget.initialActions) {
      final item = ActionItem.fromJson(action);
      _actions.add(item);
      _actionCounter++;
    }
  }

  void _addAction(BotCreatorActionType type) {
    setState(() {
      _actions.add(
        ActionItem(
          id: 'action_${_actionCounter++}',
          type: type,
          parameters: Map.from(type.defaultParameters),
        ),
      );
    });
  }

  void _removeAction(String actionId) {
    setState(() {
      _actions.removeWhere((action) => action.id == actionId);
      _fieldRefreshVersions.removeWhere(
        (compositeKey, _) => compositeKey.startsWith('$actionId::'),
      );
    });
  }

  void _updateActionParameter(
    String actionId,
    String key,
    dynamic value, {
    bool forceFieldRefresh = false,
  }) {
    setState(() {
      final actionIndex = _actions.indexWhere(
        (action) => action.id == actionId,
      );
      if (actionIndex != -1) {
        if (key == '__enabled__') {
          _actions[actionIndex].enabled = value == true;
          return;
        }

        if (key == '__onErrorMode__') {
          _actions[actionIndex].onErrorMode =
              value == 'continue' ? 'continue' : 'stop';
          return;
        }

        _actions[actionIndex].parameters[key] = value;
        if (forceFieldRefresh) {
          final compositeKey = '$actionId::$key';
          _fieldRefreshVersions[compositeKey] =
              (_fieldRefreshVersions[compositeKey] ?? 0) + 1;
        }
      }
    });
  }

  void _saveActions() {
    for (final action in _actions) {
      for (final def in action.type.parameterDefinitions) {
        if (!def.required) {
          continue;
        }

        final value = action.parameters[def.key];
        if (value == null || (value is String && value.trim().isEmpty)) {
          showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('Missing Required Field'),
                  content: Text(
                    '${action.type.displayName}: ${def.key} is required.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
          );
          return;
        }
      }
    }

    final payload = _actions.map((action) => action.toJson()).toList();
    if (kDebugMode) {
      print('Saving actions payload: $payload');
    }
    Navigator.pop(context, payload);
  }

  void _showAddActionDialog() {
    final maxHeight = MediaQuery.of(context).size.height * 0.7;
    String searchQuery = '';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Rebuild the category list each time the search query changes
            final actionsByCategory = <String, List<BotCreatorActionType>>{};

            for (final actionType in BotCreatorActionType.values) {
              if (searchQuery.isNotEmpty &&
                  !actionType.displayName.toLowerCase().contains(
                    searchQuery.toLowerCase(),
                  )) {
                continue; // Skip if it doesn't match the search
              }
              final category = _getCategoryForAction(actionType);
              actionsByCategory.putIfAbsent(
                category,
                () => <BotCreatorActionType>[],
              );
              actionsByCategory[category]!.add(actionType);
            }

            for (final entry in actionsByCategory.entries) {
              entry.value.sort(
                (a, b) => a.displayName.compareTo(b.displayName),
              );
            }

            return AlertDialog(
              title: const Text('Add New Action'),
              content: SizedBox(
                width: double.maxFinite,
                height: maxHeight,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search actions...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          searchQuery = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child:
                          actionsByCategory.isEmpty
                              ? const Center(
                                child: Text('No actions match your search.'),
                              )
                              : SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ...actionsByCategory.entries.map(
                                      (entry) => _buildActionCategory(
                                        entry.key,
                                        entry.value,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _getCategoryForAction(BotCreatorActionType type) {
    switch (type) {
      case BotCreatorActionType.sendMessage:
      case BotCreatorActionType.editMessage:
      case BotCreatorActionType.deleteMessages:
      case BotCreatorActionType.pinMessage:
        return 'Messages';
      case BotCreatorActionType.addReaction:
      case BotCreatorActionType.removeReaction:
      case BotCreatorActionType.clearAllReactions:
        return 'Reactions';
      case BotCreatorActionType.createChannel:
      case BotCreatorActionType.updateChannel:
      case BotCreatorActionType.removeChannel:
        return 'Channels';
      case BotCreatorActionType.banUser:
      case BotCreatorActionType.unbanUser:
      case BotCreatorActionType.kickUser:
      case BotCreatorActionType.muteUser:
      case BotCreatorActionType.unmuteUser:
        return 'Moderation';
      case BotCreatorActionType.sendComponentV2:
      case BotCreatorActionType.editComponentV2:
        return 'Components';
      case BotCreatorActionType.sendWebhook:
      case BotCreatorActionType.editWebhook:
      case BotCreatorActionType.deleteWebhook:
      case BotCreatorActionType.listWebhooks:
      case BotCreatorActionType.getWebhook:
        return 'Webhooks';
      case BotCreatorActionType.updateGuild:
      case BotCreatorActionType.updateAutoMod:
      case BotCreatorActionType.listMembers:
      case BotCreatorActionType.getMember:
        return 'Guild & Members';
      case BotCreatorActionType.makeList:
        return 'Utilities';
      case BotCreatorActionType.httpRequest:
      case BotCreatorActionType.setGlobalVariable:
      case BotCreatorActionType.getGlobalVariable:
      case BotCreatorActionType.removeGlobalVariable:
      case BotCreatorActionType.listGlobalVariables:
        return 'HTTP & Variables';
      case BotCreatorActionType.runWorkflow:
        return 'Workflows';
      // ── Interactions ──
      case BotCreatorActionType.respondWithComponentV2:
      case BotCreatorActionType.editInteractionMessage:
        return 'Interactions';
      case BotCreatorActionType.respondWithModal:
      case BotCreatorActionType.listenForButtonClick:
      case BotCreatorActionType.listenForModalSubmit:
        return 'Interactions';
    }
  }

  Widget _buildActionCategory(
    String categoryName,
    List<BotCreatorActionType> actions,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            categoryName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ),
        ...actions.map((type) {
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 2),
            child: ListTile(
              dense: true,
              leading: Icon(
                type.icon,
                size: 20,
                color: _getCategoryColor(categoryName),
              ),
              title: Text(
                type.displayName,
                style: const TextStyle(fontSize: 14),
              ),
              subtitle: Text(
                _getActionDescription(type),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              onTap: () {
                Navigator.pop(context);
                _addAction(type);
              },
            ),
          );
        }),
        const SizedBox(height: 8),
      ],
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Messages':
        return Colors.green;
      case 'Reactions':
        return Colors.orange;
      case 'Channels':
        return Colors.blue;
      case 'Moderation':
        return Colors.red;
      case 'Components':
        return Colors.purple;
      case 'Webhooks':
        return Colors.teal;
      case 'Guild & Members':
        return Colors.indigo;
      case 'Utilities':
        return Colors.brown;
      case 'HTTP & Variables':
        return Colors.cyan;
      case 'Workflows':
        return Colors.deepPurple;
      case 'Interactions':
        return Colors.amber.shade700;
      default:
        return Colors.grey;
    }
  }

  String _getActionDescription(BotCreatorActionType type) {
    switch (type) {
      case BotCreatorActionType.sendMessage:
        return 'Send a message to a channel';
      case BotCreatorActionType.editMessage:
        return 'Edit an existing message';
      case BotCreatorActionType.deleteMessages:
        return 'Delete multiple messages';
      case BotCreatorActionType.pinMessage:
        return 'Pin a message in a channel';
      case BotCreatorActionType.addReaction:
        return 'Add emoji reaction to message';
      case BotCreatorActionType.removeReaction:
        return 'Remove specific reaction';
      case BotCreatorActionType.clearAllReactions:
        return 'Clear all reactions from message';
      case BotCreatorActionType.createChannel:
        return 'Create a new channel';
      case BotCreatorActionType.updateChannel:
        return 'Update channel settings';
      case BotCreatorActionType.removeChannel:
        return 'Delete a channel';
      case BotCreatorActionType.banUser:
        return 'Ban user from server';
      case BotCreatorActionType.unbanUser:
        return 'Remove ban from user';
      case BotCreatorActionType.kickUser:
        return 'Kick user from server';
      case BotCreatorActionType.muteUser:
        return 'Temporarily mute user';
      case BotCreatorActionType.unmuteUser:
        return 'Remove mute from user';
      case BotCreatorActionType.sendComponentV2:
        return 'Send interactive components';
      case BotCreatorActionType.editComponentV2:
        return 'Edit existing components';
      case BotCreatorActionType.sendWebhook:
        return 'Send message via webhook';
      case BotCreatorActionType.editWebhook:
        return 'Modify webhook settings';
      case BotCreatorActionType.deleteWebhook:
        return 'Delete a webhook';
      case BotCreatorActionType.listWebhooks:
        return 'List all webhooks';
      case BotCreatorActionType.getWebhook:
        return 'Get webhook information';
      case BotCreatorActionType.updateGuild:
        return 'Update server settings';
      case BotCreatorActionType.updateAutoMod:
        return 'Configure auto-moderation';
      case BotCreatorActionType.listMembers:
        return 'List server members';
      case BotCreatorActionType.getMember:
        return 'Get member information';
      case BotCreatorActionType.makeList:
        return 'Create formatted lists';
      case BotCreatorActionType.httpRequest:
        return 'Send HTTP request with dynamic URL, method, headers and body';
      case BotCreatorActionType.setGlobalVariable:
        return 'Create or update a global variable for this bot';
      case BotCreatorActionType.getGlobalVariable:
        return 'Read a global variable and inject into runtime variables';
      case BotCreatorActionType.removeGlobalVariable:
        return 'Delete a global variable';
      case BotCreatorActionType.listGlobalVariables:
        return 'List all global variables as JSON';
      case BotCreatorActionType.runWorkflow:
        return 'Execute a saved workflow by name';
      case BotCreatorActionType.respondWithComponentV2:
        return 'Reply to command with buttons/select menus';
      case BotCreatorActionType.respondWithModal:
        return 'Show a modal dialog to the user';
      case BotCreatorActionType.editInteractionMessage:
        return 'Edit the deferred or original interaction response';
      case BotCreatorActionType.listenForButtonClick:
        return 'Register a workflow to run when a button is clicked';
      case BotCreatorActionType.listenForModalSubmit:
        return 'Register a workflow to run when a modal is submitted';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Actions Builder'),
        actions: [
          if (_actions.isNotEmpty)
            IconButton(
              onPressed: _saveActions,
              icon: const Icon(Icons.save),
              tooltip: 'Save Actions',
            ),
        ],
      ),
      body:
          _actions.isEmpty
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_task, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No actions yet',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Tap the + button to add your first action',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              )
              : Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _actions.length,
                      itemBuilder: (context, index) {
                        final action = _actions[index];
                        final computedActionKey =
                            (action.parameters['key'] ?? action.id)
                                .toString()
                                .trim();
                        return ActionCard(
                          action: action,
                          actionKey:
                              computedActionKey.isNotEmpty
                                  ? computedActionKey
                                  : action.type.name,
                          onRemove: () => _removeAction(action.id),
                          variableSuggestions: widget.variableSuggestions,
                          fieldRefreshVersionOf:
                              (paramKey) =>
                                  _fieldRefreshVersions['${action.id}::$paramKey'] ??
                                  0,
                          onSuggestionSelected:
                              (key, value) => _updateActionParameter(
                                action.id,
                                key,
                                value,
                                forceFieldRefresh: true,
                              ),
                          onParameterChanged:
                              (key, value) =>
                                  _updateActionParameter(action.id, key, value),
                        );
                      },
                    ),
                  ),
                  if (_actions.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      child: ElevatedButton.icon(
                        onPressed: _saveActions,
                        icon: const Icon(Icons.save),
                        label: Text('Save ${_actions.length} Actions'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddActionDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
