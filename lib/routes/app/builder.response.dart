import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../types/action.dart' show BotCreatorActionType;

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

// Extension pour obtenir les détails des actions
extension BotCreatorActionTypeExtension on BotCreatorActionType {
  String get displayName {
    switch (this) {
      case BotCreatorActionType.deleteMessages:
        return 'Delete Messages';
      case BotCreatorActionType.createChannel:
        return 'Create Channel';
      case BotCreatorActionType.updateChannel:
        return 'Update Channel';
      case BotCreatorActionType.removeChannel:
        return 'Remove Channel';
      case BotCreatorActionType.sendMessage:
        return 'Send Message';
      case BotCreatorActionType.editMessage:
        return 'Edit Message';
      case BotCreatorActionType.addReaction:
        return 'Add Reaction';
      case BotCreatorActionType.removeReaction:
        return 'Remove Reaction';
      case BotCreatorActionType.clearAllReactions:
        return 'Clear All Reactions';
      case BotCreatorActionType.banUser:
        return 'Ban User';
      case BotCreatorActionType.unbanUser:
        return 'Unban User';
      case BotCreatorActionType.kickUser:
        return 'Kick User';
      case BotCreatorActionType.muteUser:
        return 'Mute User';
      case BotCreatorActionType.unmuteUser:
        return 'Unmute User';
      case BotCreatorActionType.pinMessage:
        return 'Pin Message';
      case BotCreatorActionType.updateAutoMod:
        return 'Update AutoMod';
      case BotCreatorActionType.updateGuild:
        return 'Update Guild';
      case BotCreatorActionType.listMembers:
        return 'List Members';
      case BotCreatorActionType.getMember:
        return 'Get Member';
      case BotCreatorActionType.sendComponentV2:
        return 'Send Component V2';
      case BotCreatorActionType.editComponentV2:
        return 'Edit Component V2';
      case BotCreatorActionType.sendWebhook:
        return 'Send Webhook';
      case BotCreatorActionType.editWebhook:
        return 'Edit Webhook';
      case BotCreatorActionType.deleteWebhook:
        return 'Delete Webhook';
      case BotCreatorActionType.listWebhooks:
        return 'List Webhooks';
      case BotCreatorActionType.getWebhook:
        return 'Get Webhook';
      case BotCreatorActionType.makeList:
        return 'Make List';
      case BotCreatorActionType.httpRequest:
        return 'HTTP Request';
      case BotCreatorActionType.setGlobalVariable:
        return 'Set Global Variable';
      case BotCreatorActionType.getGlobalVariable:
        return 'Get Global Variable';
      case BotCreatorActionType.removeGlobalVariable:
        return 'Remove Global Variable';
      case BotCreatorActionType.listGlobalVariables:
        return 'List Global Variables';
      case BotCreatorActionType.runWorkflow:
        return 'Run Workflow';
    }
  }

  IconData get icon {
    switch (this) {
      case BotCreatorActionType.deleteMessages:
        return Icons.delete_sweep;
      case BotCreatorActionType.createChannel:
        return Icons.add_box;
      case BotCreatorActionType.updateChannel:
        return Icons.edit;
      case BotCreatorActionType.removeChannel:
        return Icons.remove_circle;
      case BotCreatorActionType.sendMessage:
        return Icons.send;
      case BotCreatorActionType.editMessage:
        return Icons.edit_note;
      case BotCreatorActionType.addReaction:
        return Icons.emoji_emotions;
      case BotCreatorActionType.removeReaction:
        return Icons.emoji_emotions_outlined;
      case BotCreatorActionType.clearAllReactions:
        return Icons.clear_all;
      case BotCreatorActionType.banUser:
        return Icons.block;
      case BotCreatorActionType.unbanUser:
        return Icons.person_add;
      case BotCreatorActionType.kickUser:
        return Icons.exit_to_app;
      case BotCreatorActionType.muteUser:
        return Icons.volume_off;
      case BotCreatorActionType.unmuteUser:
        return Icons.volume_up;
      case BotCreatorActionType.pinMessage:
        return Icons.push_pin;
      case BotCreatorActionType.updateAutoMod:
        return Icons.security;
      case BotCreatorActionType.updateGuild:
        return Icons.settings;
      case BotCreatorActionType.listMembers:
        return Icons.group;
      case BotCreatorActionType.getMember:
        return Icons.person;
      case BotCreatorActionType.sendComponentV2:
        return Icons.widgets;
      case BotCreatorActionType.editComponentV2:
        return Icons.build;
      case BotCreatorActionType.sendWebhook:
        return Icons.webhook;
      case BotCreatorActionType.editWebhook:
        return Icons.edit_attributes;
      case BotCreatorActionType.deleteWebhook:
        return Icons.delete_forever;
      case BotCreatorActionType.listWebhooks:
        return Icons.list;
      case BotCreatorActionType.getWebhook:
        return Icons.search;
      case BotCreatorActionType.makeList:
        return Icons.format_list_bulleted;
      case BotCreatorActionType.httpRequest:
        return Icons.http;
      case BotCreatorActionType.setGlobalVariable:
        return Icons.save_as;
      case BotCreatorActionType.getGlobalVariable:
        return Icons.key;
      case BotCreatorActionType.removeGlobalVariable:
        return Icons.key_off;
      case BotCreatorActionType.listGlobalVariables:
        return Icons.inventory_2;
      case BotCreatorActionType.runWorkflow:
        return Icons.account_tree;
    }
  }

  // Nouvelle méthode pour obtenir les définitions de paramètres typés
  List<ParameterDefinition> get parameterDefinitions {
    switch (this) {
      case BotCreatorActionType.deleteMessages:
        return [
          ParameterDefinition(
            key: 'channelId',
            type: ParameterType.channelId,
            defaultValue: '',
            hint: 'Optional: target channel (uses current channel if empty)',
          ),
          ParameterDefinition(
            key: 'messageCount',
            type: ParameterType.number,
            defaultValue: 10,
            hint: 'Number of messages to delete',
            minValue: 1,
            maxValue: 100,
          ),
          ParameterDefinition(
            key: 'onlyUserId',
            type: ParameterType.userId,
            defaultValue: '',
            hint: 'Optional: only delete messages from this user',
          ),
          ParameterDefinition(
            key: 'beforeMessageId',
            type: ParameterType.messageId,
            defaultValue: '',
            hint:
                'Optional: delete messages posted before the given message ID',
          ),
          ParameterDefinition(
            key: 'deleteItself',
            type: ParameterType.boolean,
            defaultValue: false,
            hint:
                'If true and beforeMessageId is set, also delete that message',
          ),
          ParameterDefinition(
            key: 'reason',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Reason for deletion',
          ),
          ParameterDefinition(
            key: 'filterBots',
            type: ParameterType.boolean,
            defaultValue: false,
            hint: 'Only delete bot messages',
          ),
          ParameterDefinition(
            key: 'filterUsers',
            type: ParameterType.boolean,
            defaultValue: false,
            hint: 'Only delete user messages',
          ),
        ];
      case BotCreatorActionType.createChannel:
        return [
          ParameterDefinition(
            key: 'name',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Channel name',
            required: true,
          ),
          ParameterDefinition(
            key: 'type',
            type: ParameterType.multiSelect,
            defaultValue: 'text',
            hint: 'Channel type',
            options: [
              'text',
              'voice',
              'announcement',
              'stage',
              'forum',
              'category',
            ],
          ),
          ParameterDefinition(
            key: 'categoryId',
            type: ParameterType.channelId,
            defaultValue: '',
            hint: 'Parent category',
          ),
          ParameterDefinition(
            key: 'topic',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Channel topic/description',
          ),
          ParameterDefinition(
            key: 'nsfw',
            type: ParameterType.boolean,
            defaultValue: false,
            hint: 'Age-restricted channel',
          ),
          ParameterDefinition(
            key: 'slowmode',
            type: ParameterType.duration,
            defaultValue: '0s',
            hint: 'Slowmode duration',
          ),
        ];
      case BotCreatorActionType.updateChannel:
        return [
          ParameterDefinition(
            key: 'channelId',
            type: ParameterType.channelId,
            defaultValue: '',
            hint: 'Channel to update',
            required: true,
          ),
          ParameterDefinition(
            key: 'name',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'New channel name',
          ),
          ParameterDefinition(
            key: 'topic',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'New channel topic/description',
          ),
          ParameterDefinition(
            key: 'nsfw',
            type: ParameterType.boolean,
            defaultValue: false,
            hint: 'Toggle NSFW status',
          ),
          ParameterDefinition(
            key: 'slowmode',
            type: ParameterType.duration,
            defaultValue: '0s',
            hint: 'New slowmode duration',
          ),
        ];
      case BotCreatorActionType.sendMessage:
        return [
          ParameterDefinition(
            key: 'channelId',
            type: ParameterType.channelId,
            defaultValue: '',
            hint: 'Target channel (optional: current command channel if empty)',
          ),
          ParameterDefinition(
            key: 'content',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Message content',
            required: true,
          ),
          ParameterDefinition(
            key: 'mentions',
            type: ParameterType.list,
            defaultValue: <String>[],
            hint: 'Users/roles to mention',
          ),
          ParameterDefinition(
            key: 'embeds',
            type: ParameterType.boolean,
            defaultValue: false,
            hint: 'Include embeds',
          ),
          ParameterDefinition(
            key: 'tts',
            type: ParameterType.boolean,
            defaultValue: false,
            hint: 'Text-to-speech',
          ),
          ParameterDefinition(
            key: 'ephemeral',
            type: ParameterType.boolean,
            defaultValue: false,
            hint: 'Only visible to user',
          ),
        ];
      case BotCreatorActionType.editMessage:
        return [
          ParameterDefinition(
            key: 'channelId',
            type: ParameterType.channelId,
            defaultValue: '',
            hint: 'Channel containing message',
            required: true,
          ),
          ParameterDefinition(
            key: 'messageId',
            type: ParameterType.messageId,
            defaultValue: '',
            hint: 'Message to edit',
            required: true,
          ),
          ParameterDefinition(
            key: 'content',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'New message content',
          ),
          ParameterDefinition(
            key: 'embeds',
            type: ParameterType.boolean,
            defaultValue: false,
            hint: 'Update embeds',
          ),
        ];
      case BotCreatorActionType.banUser:
        return [
          ParameterDefinition(
            key: 'userId',
            type: ParameterType.userId,
            defaultValue: '',
            hint: 'User to ban',
            required: true,
          ),
          ParameterDefinition(
            key: 'reason',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Ban reason',
          ),
          ParameterDefinition(
            key: 'deleteMessageDays',
            type: ParameterType.number,
            defaultValue: 1,
            hint: 'Days of messages to delete',
            minValue: 0,
            maxValue: 7,
          ),
        ];
      case BotCreatorActionType.makeList:
        return [
          ParameterDefinition(
            key: 'title',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'List title',
          ),
          ParameterDefinition(
            key: 'items',
            type: ParameterType.list,
            defaultValue: <String>[],
            hint: 'List items',
            required: true,
          ),
          ParameterDefinition(
            key: 'numbered',
            type: ParameterType.boolean,
            defaultValue: false,
            hint: 'Use numbered list',
          ),
          ParameterDefinition(
            key: 'separator',
            type: ParameterType.string,
            defaultValue: ', ',
            hint: 'Item separator',
          ),
        ];
      case BotCreatorActionType.updateAutoMod:
        return [
          ParameterDefinition(
            key: 'enabled',
            type: ParameterType.boolean,
            defaultValue: true,
            hint: 'Enable auto-moderation',
          ),
          ParameterDefinition(
            key: 'filterWords',
            type: ParameterType.list,
            defaultValue: <String>[],
            hint: 'Blocked words',
          ),
          ParameterDefinition(
            key: 'allowedRoles',
            type: ParameterType.list,
            defaultValue: <String>[],
            hint: 'Roles exempt from filtering',
          ),
          ParameterDefinition(
            key: 'maxMentions',
            type: ParameterType.number,
            defaultValue: 5,
            hint: 'Maximum mentions per message',
            minValue: 1,
            maxValue: 50,
          ),
        ];
      case BotCreatorActionType.httpRequest:
        return [
          ParameterDefinition(
            key: 'url',
            type: ParameterType.url,
            defaultValue: '',
            hint: 'Request URL (supports placeholders ((...)))',
            required: true,
          ),
          ParameterDefinition(
            key: 'method',
            type: ParameterType.string,
            defaultValue: 'GET',
            hint: 'GET/POST/PUT/PATCH/DELETE/HEAD (placeholder allowed)',
          ),
          ParameterDefinition(
            key: 'bodyMode',
            type: ParameterType.multiSelect,
            defaultValue: 'json',
            hint: 'Body format',
            options: ['json', 'text'],
          ),
          ParameterDefinition(
            key: 'bodyJson',
            type: ParameterType.map,
            defaultValue: <String, dynamic>{},
            hint: 'JSON body builder map',
          ),
          ParameterDefinition(
            key: 'bodyText',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Raw text body',
          ),
          ParameterDefinition(
            key: 'headers',
            type: ParameterType.map,
            defaultValue: <String, dynamic>{},
            hint: 'Custom headers',
          ),
          ParameterDefinition(
            key: 'saveBodyToGlobalVar',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Optional global var key to store response body',
          ),
          ParameterDefinition(
            key: 'saveStatusToGlobalVar',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Optional global var key to store status code',
          ),
          ParameterDefinition(
            key: 'extractJsonPath',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'JSON path to extract (ex: \$.data.access_token)',
          ),
          ParameterDefinition(
            key: 'saveJsonPathToGlobalVar',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Optional global var key to store extracted value',
          ),
        ];
      case BotCreatorActionType.setGlobalVariable:
        return [
          ParameterDefinition(
            key: 'key',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Global variable key',
            required: true,
          ),
          ParameterDefinition(
            key: 'value',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Value (supports placeholders ((...)))',
          ),
        ];
      case BotCreatorActionType.getGlobalVariable:
        return [
          ParameterDefinition(
            key: 'key',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Global variable key',
            required: true,
          ),
          ParameterDefinition(
            key: 'storeAs',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Runtime variable alias (ex: token)',
          ),
        ];
      case BotCreatorActionType.removeGlobalVariable:
        return [
          ParameterDefinition(
            key: 'key',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Global variable key',
            required: true,
          ),
        ];
      case BotCreatorActionType.listGlobalVariables:
        return [
          ParameterDefinition(
            key: 'storeAs',
            type: ParameterType.string,
            defaultValue: 'global.list',
            hint: 'Runtime variable key that stores JSON list',
          ),
        ];
      case BotCreatorActionType.runWorkflow:
        return [
          ParameterDefinition(
            key: 'workflowName',
            type: ParameterType.string,
            defaultValue: '',
            hint: 'Saved workflow name to execute',
            required: true,
          ),
        ];
      default:
        // Fallback pour les autres actions - convertir les anciens paramètres
        return _convertLegacyParameters();
    }
  }

  List<ParameterDefinition> _convertLegacyParameters() {
    final params = defaultParameters;
    return params.entries.map((entry) {
      ParameterType type = ParameterType.string;
      if (entry.value is bool) {
        type = ParameterType.boolean;
      } else if (entry.value is int || entry.value is double) {
        type = ParameterType.number;
      } else if (entry.value is List) {
        type = ParameterType.list;
      } else if (entry.key.toLowerCase().contains('id')) {
        type = ParameterType.string;
      } else if (entry.key.toLowerCase().contains('url')) {
        type = ParameterType.url;
      }
      return ParameterDefinition(
        key: entry.key,
        type: type,
        defaultValue: entry.value,
        hint: 'Enter ${entry.key}',
      );
    }).toList();
  }

  Map<String, dynamic> get defaultParameters {
    // Générer les paramètres par défaut à partir des définitions
    final Map<String, dynamic> params = {};
    for (final def in parameterDefinitions) {
      params[def.key] = def.defaultValue;
    }
    return params;
  }
}

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
    final actionsByCategory = <String, List<BotCreatorActionType>>{};

    for (final actionType in BotCreatorActionType.values) {
      final category = _getCategoryForAction(actionType);
      actionsByCategory.putIfAbsent(category, () => <BotCreatorActionType>[]);
      actionsByCategory[category]!.add(actionType);
    }

    for (final entry in actionsByCategory.entries) {
      entry.value.sort((a, b) => a.displayName.compareTo(b.displayName));
    }

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
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
                      // Implémentation de la recherche si nécessaire
                    },
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...actionsByCategory.entries.map(
                            (entry) =>
                                _buildActionCategory(entry.key, entry.value),
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
          ),
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

class ActionCard extends StatelessWidget {
  final ActionItem action;
  final String actionKey;
  final List<VariableSuggestion> variableSuggestions;
  final int Function(String paramKey) fieldRefreshVersionOf;
  final Function(String key, dynamic value) onSuggestionSelected;
  final VoidCallback onRemove;
  final Function(String key, dynamic value) onParameterChanged;

  const ActionCard({
    super.key,
    required this.action,
    required this.onRemove,
    required this.onParameterChanged,
    required this.onSuggestionSelected,
    required this.fieldRefreshVersionOf,
    required this.actionKey,
    required this.variableSuggestions,
  });

  Key _parameterInputKey(String paramKey) {
    final version = fieldRefreshVersionOf(paramKey);
    return ValueKey('param-input-${action.id}-$paramKey-v$version');
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(action.type.icon, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    action.type.displayName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete, color: Colors.red),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: ValueKey('action-key-${action.id}'),
              initialValue: actionKey,
              decoration: const InputDecoration(
                labelText: 'Action Key',
                border: OutlineInputBorder(),
              ),
              onChanged: (newValue) => onParameterChanged('key', newValue),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enabled'),
                    value: action.enabled,
                    onChanged:
                        (value) => onParameterChanged('__enabled__', value),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: action.onErrorMode,
                    decoration: const InputDecoration(
                      labelText: 'On Error',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'stop', child: Text('Stop')),
                      DropdownMenuItem(
                        value: 'continue',
                        child: Text('Continue'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        onParameterChanged('__onErrorMode__', value);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...action.type.parameterDefinitions.map((paramDef) {
              final currentValue = action.parameters[paramDef.key];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildParameterField(context, paramDef, currentValue),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildParameterField(
    BuildContext context,
    ParameterDefinition paramDef,
    dynamic currentValue,
  ) {
    switch (paramDef.type) {
      case ParameterType.boolean:
        return Row(
          children: [
            Expanded(
              child: Text(
                _formatParameterName(paramDef.key),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            Switch(
              value: currentValue ?? paramDef.defaultValue,
              onChanged:
                  (newValue) => onParameterChanged(paramDef.key, newValue),
            ),
          ],
        );

      case ParameterType.number:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _formatParameterName(paramDef.key),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                if (paramDef.required)
                  const Text(
                    ' *',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            TextFormField(
              key: _parameterInputKey(paramDef.key),
              initialValue: (currentValue ?? paramDef.defaultValue).toString(),
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                hintText: paramDef.hint,
                border: const OutlineInputBorder(),
                isDense: true,
                suffixText:
                    paramDef.minValue != null && paramDef.maxValue != null
                        ? '${paramDef.minValue}-${paramDef.maxValue}'
                        : null,
              ),
              onChanged: (newValue) {
                final trimmed = newValue.trim();
                if (trimmed.isEmpty) {
                  onParameterChanged(paramDef.key, '');
                  return;
                }

                final intValue = int.tryParse(trimmed);
                if (intValue != null) {
                  // Vérifier les limites
                  if (paramDef.minValue != null &&
                      intValue < paramDef.minValue!) {
                    return;
                  }
                  if (paramDef.maxValue != null &&
                      intValue > paramDef.maxValue!) {
                    return;
                  }
                  onParameterChanged(paramDef.key, intValue);
                  return;
                }

                onParameterChanged(paramDef.key, trimmed);
              },
            ),
            ..._buildVariableSuggestionsForParam(
              paramKey: paramDef.key,
              value: currentValue,
              isNumericField: true,
            ),
          ],
        );

      case ParameterType.list:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatParameterName(paramDef.key),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed:
                      () => _showListEditor(context, paramDef, currentValue),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (currentValue is List && currentValue.isNotEmpty)
                    ...currentValue.asMap().entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '${entry.key + 1}. ${entry.value}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      );
                    })
                  else
                    Text(
                      'No items - tap edit to add',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),
          ],
        );

      case ParameterType.multiSelect:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatParameterName(paramDef.key),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              initialValue:
                  currentValue?.toString() ?? paramDef.defaultValue.toString(),
              decoration: InputDecoration(
                hintText: paramDef.hint,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              items:
                  paramDef.options?.map((option) {
                    return DropdownMenuItem(value: option, child: Text(option));
                  }).toList(),
              onChanged:
                  (newValue) => onParameterChanged(paramDef.key, newValue),
            ),
            ..._buildVariableSuggestionsForParam(
              paramKey: paramDef.key,
              value: currentValue,
            ),
          ],
        );

      case ParameterType.duration:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatParameterName(paramDef.key),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            TextFormField(
              key: _parameterInputKey(paramDef.key),
              initialValue: (currentValue ?? paramDef.defaultValue).toString(),
              decoration: InputDecoration(
                hintText: paramDef.hint ?? 'e.g., 5m, 1h, 30s',
                border: const OutlineInputBorder(),
                isDense: true,
                suffixText: 's/m/h/d',
              ),
              onChanged:
                  (newValue) => onParameterChanged(paramDef.key, newValue),
            ),
            ..._buildVariableSuggestionsForParam(
              paramKey: paramDef.key,
              value: currentValue,
            ),
          ],
        );

      case ParameterType.url:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatParameterName(paramDef.key),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            TextFormField(
              key: _parameterInputKey(paramDef.key),
              initialValue: (currentValue ?? paramDef.defaultValue).toString(),
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                hintText: paramDef.hint ?? 'https://example.com',
                border: const OutlineInputBorder(),
                isDense: true,
                prefixIcon: const Icon(Icons.link, size: 20),
              ),
              onChanged:
                  (newValue) => onParameterChanged(paramDef.key, newValue),
            ),
            ..._buildVariableSuggestionsForParam(
              paramKey: paramDef.key,
              value: currentValue,
            ),
          ],
        );

      case ParameterType.userId:
      case ParameterType.channelId:
      case ParameterType.messageId:
      case ParameterType.roleId:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatParameterName(paramDef.key),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            TextFormField(
              key: _parameterInputKey(paramDef.key),
              initialValue: (currentValue ?? paramDef.defaultValue).toString(),
              decoration: InputDecoration(
                hintText: paramDef.hint ?? 'Enter ${paramDef.type.name}',
                border: const OutlineInputBorder(),
                isDense: true,
                prefixIcon: Icon(_getIconForIdType(paramDef.type), size: 20),
              ),
              onChanged:
                  (newValue) => onParameterChanged(paramDef.key, newValue),
            ),
          ],
        );

      case ParameterType.emoji:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatParameterName(paramDef.key),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: _parameterInputKey(paramDef.key),
                    initialValue:
                        (currentValue ?? paramDef.defaultValue).toString(),
                    decoration: InputDecoration(
                      hintText: paramDef.hint ?? 'Enter emoji or :name:',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: const Icon(Icons.emoji_emotions, size: 20),
                    ),
                    onChanged:
                        (newValue) =>
                            onParameterChanged(paramDef.key, newValue),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    currentValue?.toString() ?? '😀',
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ],
            ),
            ..._buildVariableSuggestionsForParam(
              paramKey: paramDef.key,
              value: currentValue,
            ),
          ],
        );

      case ParameterType.color:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatParameterName(paramDef.key),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: _parameterInputKey(paramDef.key),
                    initialValue:
                        (currentValue ?? paramDef.defaultValue).toString(),
                    decoration: InputDecoration(
                      hintText: paramDef.hint ?? '#FFFFFF or rgb(255,255,255)',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: const Icon(Icons.color_lens, size: 20),
                    ),
                    onChanged:
                        (newValue) =>
                            onParameterChanged(paramDef.key, newValue),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap:
                      () => _showColorPicker(context, paramDef, currentValue),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _parseColor(currentValue?.toString() ?? '#000000'),
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
            ..._buildVariableSuggestionsForParam(
              paramKey: paramDef.key,
              value: currentValue,
            ),
          ],
        );

      case ParameterType.map:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatParameterName(paramDef.key),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed:
                      () => _showMapEditor(context, paramDef, currentValue),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              child: _buildMapPreview(paramDef.key, currentValue),
            ),
          ],
        );

      default: // ParameterType.string
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _formatParameterName(paramDef.key),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                if (paramDef.required)
                  const Text(
                    ' *',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            TextFormField(
              key: _parameterInputKey(paramDef.key),
              initialValue: (currentValue ?? paramDef.defaultValue).toString(),
              maxLines: paramDef.key.toLowerCase().contains('content') ? 3 : 1,
              decoration: InputDecoration(
                hintText: paramDef.hint,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged:
                  (newValue) => onParameterChanged(paramDef.key, newValue),
            ),
            ..._buildVariableSuggestionsForParam(
              paramKey: paramDef.key,
              value: currentValue,
            ),
          ],
        );
    }
  }

  List<Widget> _buildVariableSuggestionsForParam({
    required String paramKey,
    required dynamic value,
    bool isNumericField = false,
  }) {
    final rawValue = value?.toString() ?? '';
    final query = _extractPlaceholderQuery(rawValue);
    if (query == null) {
      return const [];
    }

    final normalizedQuery = query.trim().toLowerCase();
    final filteredByKind =
        isNumericField
            ? variableSuggestions.where(
              (item) => item.isNumeric || item.isUnknown,
            )
            : variableSuggestions;

    final suggestions =
        filteredByKind
            .where(
              (item) =>
                  normalizedQuery.isEmpty ||
                  item.name.toLowerCase().contains(normalizedQuery),
            )
            .take(8)
            .toList();

    if (suggestions.isEmpty) {
      return const [];
    }

    return [
      const SizedBox(height: 8),
      Text(
        isNumericField
            ? 'Dynamic numeric suggestions'
            : 'Dynamic variable suggestions',
        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
      ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children:
            suggestions
                .map(
                  (item) => ActionChip(
                    label: Text('((${item.name}))'),
                    onPressed: () {
                      final nextValue = _insertVariableInOpenPlaceholder(
                        rawValue,
                        item.name,
                      );
                      onSuggestionSelected(paramKey, nextValue);
                    },
                  ),
                )
                .toList(),
      ),
    ];
  }

  String? _extractPlaceholderQuery(String input) {
    final start = input.lastIndexOf('((');
    if (start == -1) {
      return null;
    }

    final afterStart = input.substring(start + 2);
    if (afterStart.contains('))')) {
      return null;
    }

    final parts = afterStart.split('|');
    return parts.last.trimLeft();
  }

  String _insertVariableInOpenPlaceholder(String input, String variableName) {
    final start = input.lastIndexOf('((');
    if (start == -1) {
      return '(($variableName))';
    }

    final beforeStart = input.substring(0, start);
    final afterStart = input.substring(start + 2);

    if (afterStart.contains('))')) {
      return input;
    }

    final parts = afterStart.split('|');
    final prefixParts =
        parts.length > 1 ? parts.sublist(0, parts.length - 1) : <String>[];
    final previous = prefixParts
        .map((entry) => entry.trim())
        .where((e) => e.isNotEmpty);
    final merged = [...previous, variableName];
    final inner = merged.join(' | ');

    return '$beforeStart(($inner))';
  }

  // Méthodes utilitaires
  void _showListEditor(
    BuildContext context,
    ParameterDefinition paramDef,
    dynamic currentValue,
  ) {
    final maxHeight = MediaQuery.of(context).size.height * 0.55;
    final List<String> items = List<String>.from(currentValue ?? []);
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: Text('Edit ${_formatParameterName(paramDef.key)}'),
                  content: SizedBox(
                    width: double.maxFinite,
                    height: maxHeight,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: controller,
                                decoration: const InputDecoration(
                                  hintText: 'Add new item',
                                  border: OutlineInputBorder(),
                                ),
                                onSubmitted: (value) {
                                  if (value.trim().isNotEmpty) {
                                    setDialogState(() {
                                      items.add(value.trim());
                                      controller.clear();
                                    });
                                  }
                                },
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: () {
                                if (controller.text.trim().isNotEmpty) {
                                  setDialogState(() {
                                    items.add(controller.text.trim());
                                    controller.clear();
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: ListView.builder(
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              return ListTile(
                                title: Text(items[index]),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed:
                                      () => setDialogState(
                                        () => items.removeAt(index),
                                      ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        onParameterChanged(paramDef.key, items);
                        Navigator.pop(dialogContext);
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
          ),
    );
  }

  void _showColorPicker(
    BuildContext context,
    ParameterDefinition paramDef,
    dynamic currentValue,
  ) {
    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text('Choose ${_formatParameterName(paramDef.key)}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      [
                        '#FF0000',
                        '#00FF00',
                        '#0000FF',
                        '#FFFF00',
                        '#FF00FF',
                        '#00FFFF',
                        '#000000',
                        '#FFFFFF',
                        '#808080',
                        '#FFA500',
                        '#800080',
                        '#008000',
                      ].map((colorHex) {
                        return GestureDetector(
                          onTap: () {
                            onParameterChanged(paramDef.key, colorHex);
                            Navigator.pop(dialogContext);
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _parseColor(colorHex),
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );
  }

  void _showMapEditor(
    BuildContext context,
    ParameterDefinition paramDef,
    dynamic currentValue,
  ) {
    if (paramDef.key == 'headers') {
      _showHeadersEditor(context, paramDef, currentValue);
      return;
    }
    final maxHeight = MediaQuery.of(context).size.height * 0.7;
    final rawMap =
        (currentValue is Map)
            ? Map<String, dynamic>.from(currentValue.cast<String, dynamic>())
            : <String, dynamic>{};
    final TextEditingController jsonController = TextEditingController(
      text: const JsonEncoder.withIndent('  ').convert(rawMap),
    );

    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text('Edit ${_formatParameterName(paramDef.key)}'),
            content: SizedBox(
              width: double.maxFinite,
              height: maxHeight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'JSON object editor (supports nested objects/arrays)',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: TextField(
                      controller: jsonController,
                      maxLines: null,
                      expands: true,
                      keyboardType: TextInputType.multiline,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  try {
                    final decoded = jsonDecode(jsonController.text.trim());
                    if (decoded is! Map) {
                      throw const FormatException('Root must be a JSON object');
                    }

                    onParameterChanged(
                      paramDef.key,
                      Map<String, dynamic>.from(decoded),
                    );
                    Navigator.pop(dialogContext);
                  } catch (error) {
                    showDialog(
                      context: dialogContext,
                      builder:
                          (context) => AlertDialog(
                            title: const Text('Invalid JSON'),
                            content: Text(error.toString()),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                    );
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  Widget _buildMapPreview(String key, dynamic currentValue) {
    if (currentValue is Map && currentValue.isNotEmpty) {
      if (key == 'headers') {
        final entries = currentValue.entries.toList();
        final preview = entries
            .take(6)
            .map((entry) {
              final headerKey = entry.key.toString();
              final headerValue = entry.value?.toString() ?? '';
              return '$headerKey: $headerValue';
            })
            .join('\n');
        final extraCount = entries.length - 6;
        return SelectableText(
          extraCount > 0 ? '$preview\n… ($extraCount more)' : preview,
          style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
        );
      }

      return SelectableText(
        const JsonEncoder.withIndent('  ').convert(currentValue),
        style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
      );
    }

    return Text(
      key == 'headers'
          ? 'No headers - tap edit to add'
          : 'No properties - tap edit to configure',
      style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
    );
  }

  void _showHeadersEditor(
    BuildContext context,
    ParameterDefinition paramDef,
    dynamic currentValue,
  ) {
    final maxHeight = MediaQuery.of(context).size.height * 0.7;
    final rawMap =
        (currentValue is Map)
            ? Map<String, dynamic>.from(currentValue.cast<String, dynamic>())
            : <String, dynamic>{};

    final headers =
        rawMap.entries
            .map(
              (entry) => {
                'keyController': TextEditingController(
                  text: entry.key.toString(),
                ),
                'valueController': TextEditingController(
                  text: entry.value?.toString() ?? '',
                ),
              },
            )
            .toList();

    if (headers.isEmpty) {
      headers.add({
        'keyController': TextEditingController(),
        'valueController': TextEditingController(),
      });
    }

    final pasteController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: Text('Edit ${_formatParameterName(paramDef.key)}'),
                  content: SizedBox(
                    width: double.maxFinite,
                    height: maxHeight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add headers as key/value pairs.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.builder(
                            itemCount: headers.length,
                            itemBuilder: (context, index) {
                              final keyController =
                                  headers[index]['keyController']
                                      as TextEditingController;
                              final valueController =
                                  headers[index]['valueController']
                                      as TextEditingController;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 4,
                                      child: TextField(
                                        controller: keyController,
                                        decoration: const InputDecoration(
                                          hintText: 'Header name',
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 6,
                                      child: TextField(
                                        controller: valueController,
                                        decoration: const InputDecoration(
                                          hintText: 'Header value',
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: () {
                                        setDialogState(() {
                                          if (headers.length > 1) {
                                            headers.removeAt(index);
                                          } else {
                                            keyController.clear();
                                            valueController.clear();
                                          }
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                setDialogState(() {
                                  headers.add({
                                    'keyController': TextEditingController(),
                                    'valueController': TextEditingController(),
                                  });
                                });
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Add header'),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () {
                                setDialogState(() {
                                  for (final entry in headers) {
                                    (entry['keyController']
                                            as TextEditingController)
                                        .clear();
                                    (entry['valueController']
                                            as TextEditingController)
                                        .clear();
                                  }
                                });
                              },
                              child: const Text('Clear'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Paste headers (one per line: Key: Value)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: pasteController,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  hintText:
                                      'Authorization: Bearer ...\nAccept: application/json',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () {
                                final raw = pasteController.text.trim();
                                if (raw.isEmpty) {
                                  return;
                                }
                                final lines = raw.split(RegExp(r'\r?\n'));
                                setDialogState(() {
                                  for (final line in lines) {
                                    final separatorIndex = line.indexOf(':');
                                    if (separatorIndex <= 0) {
                                      continue;
                                    }
                                    final key =
                                        line
                                            .substring(0, separatorIndex)
                                            .trim();
                                    final value =
                                        line
                                            .substring(separatorIndex + 1)
                                            .trim();
                                    if (key.isEmpty) {
                                      continue;
                                    }
                                    headers.add({
                                      'keyController': TextEditingController(
                                        text: key,
                                      ),
                                      'valueController': TextEditingController(
                                        text: value,
                                      ),
                                    });
                                  }
                                  pasteController.clear();
                                });
                              },
                              child: const Text('Paste'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        final Map<String, dynamic> result = {};
                        for (final entry in headers) {
                          final key =
                              (entry['keyController'] as TextEditingController)
                                  .text
                                  .trim();
                          final value =
                              (entry['valueController']
                                      as TextEditingController)
                                  .text
                                  .trim();
                          if (key.isNotEmpty) {
                            result[key] = value;
                          }
                        }
                        onParameterChanged(paramDef.key, result);
                        Navigator.pop(dialogContext);
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
          ),
    );
  }

  IconData _getIconForIdType(ParameterType type) {
    switch (type) {
      case ParameterType.userId:
        return Icons.person;
      case ParameterType.channelId:
        return Icons.tag;
      case ParameterType.messageId:
        return Icons.message;
      case ParameterType.roleId:
        return Icons.admin_panel_settings;
      default:
        return Icons.tag;
    }
  }

  Color _parseColor(String colorString) {
    try {
      if (colorString.startsWith('#')) {
        return Color(
          int.parse(colorString.substring(1), radix: 16) + 0xFF000000,
        );
      }
      return Colors.black;
    } catch (e) {
      return Colors.black;
    }
  }

  String _formatParameterName(String key) {
    return key
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}
