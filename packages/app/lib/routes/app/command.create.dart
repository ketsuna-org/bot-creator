import 'package:bot_creator/main.dart';
import 'package:bot_creator/routes/app/builder.response.dart';
import 'package:bot_creator/utils/analytics.dart';
import 'package:bot_creator/utils/bot.dart';
import 'package:bot_creator/utils/i18n.dart';
import 'package:bot_creator/widgets/option_widget.dart';
import 'package:bot_creator/widgets/command_create_cards/basic_info_card.dart';
import 'package:bot_creator/widgets/command_create_cards/reply_card.dart';
import 'package:bot_creator/widgets/command_create_cards/actions_card.dart';
import 'package:bot_creator/widgets/response_embeds_editor.dart';
import 'package:bot_creator/types/variable_suggestion.dart';
import 'package:flutter/material.dart';
import 'package:nyxx/nyxx.dart';

class CommandCreatePage extends StatefulWidget {
  final NyxxRest? client;
  final Snowflake id;
  const CommandCreatePage({super.key, this.client, this.id = Snowflake.zero});

  @override
  State<CommandCreatePage> createState() => _CommandCreatePageState();
}

class _CommandCreatePageState extends State<CommandCreatePage> {
  static const String _editorModeSimple = 'simple';
  static const String _editorModeAdvanced = 'advanced';

  String _commandName = "";
  String _commandDescription = "";
  List<CommandOptionBuilder> _options = [];
  String _response = "";
  final TextEditingController _responseController = TextEditingController();
  String _responseType = 'normal';
  List<Map<String, dynamic>> _responseEmbeds = [];
  Map<String, dynamic> _responseComponents = {};
  Map<String, dynamic> _responseModal = {};
  List<Map<String, dynamic>> _actions = [];
  Map<String, dynamic> _responseWorkflow = _defaultWorkflow();
  bool _isLoading = true;
  List<ApplicationIntegrationType> _integrationTypes = [
    ApplicationIntegrationType.guildInstall,
  ];
  List<InteractionContextType> _contexts = [InteractionContextType.guild];
  String _defaultMemberPermissions = '';
  String _editorMode = _editorModeSimple;
  bool _simpleModeLocked = false;
  bool _simpleDeleteMessages = false;
  bool _simpleKickUser = false;
  bool _simpleBanUser = false;
  bool _simpleMuteUser = false;
  bool _simpleAddRole = false;
  bool _simpleRemoveRole = false;
  bool _simpleSendMessage = false;
  final TextEditingController _simpleSendMessageController =
      TextEditingController();

  static Map<String, dynamic> _defaultWorkflow() {
    return {
      'autoDeferIfActions': true,
      'visibility': 'public',
      'onError': 'edit_error',
      'conditional': {
        'enabled': false,
        'variable': '',
        'whenTrueType': 'normal',
        'whenFalseType': 'normal',
        'whenTrueText': '',
        'whenFalseText': '',
        'whenTrueEmbeds': <Map<String, dynamic>>[],
        'whenFalseEmbeds': <Map<String, dynamic>>[],
        'whenTrueNormalComponents': <String, dynamic>{},
        'whenFalseNormalComponents': <String, dynamic>{},
        'whenTrueComponents': <String, dynamic>{},
        'whenFalseComponents': <String, dynamic>{},
        'whenTrueModal': <String, dynamic>{},
        'whenFalseModal': <String, dynamic>{},
      },
    };
  }

  bool get _isSimpleMode => _editorMode == _editorModeSimple;

  bool get _requiresSimpleUserOption =>
      _simpleKickUser ||
      _simpleBanUser ||
      _simpleMuteUser ||
      _simpleAddRole ||
      _simpleRemoveRole;

  bool get _requiresSimpleRoleOption => _simpleAddRole || _simpleRemoveRole;

  Map<String, dynamic> _normalizeSimpleConfig(Map<String, dynamic> input) {
    return {
      'deleteMessages': input['deleteMessages'] == true,
      'kickUser': input['kickUser'] == true,
      'banUser': input['banUser'] == true,
      'muteUser': input['muteUser'] == true,
      'addRole': input['addRole'] == true,
      'removeRole': input['removeRole'] == true,
      'sendMessage': input['sendMessage'] == true,
      'sendMessageText': (input['sendMessageText'] ?? '').toString(),
    };
  }

  void _applySimpleConfig(Map<String, dynamic> config) {
    final normalized = _normalizeSimpleConfig(config);
    _simpleDeleteMessages = normalized['deleteMessages'] == true;
    _simpleKickUser = normalized['kickUser'] == true;
    _simpleBanUser = normalized['banUser'] == true;
    _simpleMuteUser = normalized['muteUser'] == true;
    _simpleAddRole = normalized['addRole'] == true;
    _simpleRemoveRole = normalized['removeRole'] == true;
    _simpleSendMessage = normalized['sendMessage'] == true;
    _simpleSendMessageController.text =
        (normalized['sendMessageText'] ?? '').toString();
  }

  Map<String, dynamic> _currentSimpleConfig() {
    return _normalizeSimpleConfig({
      'deleteMessages': _simpleDeleteMessages,
      'kickUser': _simpleKickUser,
      'banUser': _simpleBanUser,
      'muteUser': _simpleMuteUser,
      'addRole': _simpleAddRole,
      'removeRole': _simpleRemoveRole,
      'sendMessage': _simpleSendMessage,
      'sendMessageText': _simpleSendMessageController.text,
    });
  }

  List<CommandOptionBuilder> _buildSimpleModeOptions() {
    final options = <CommandOptionBuilder>[];

    if (_requiresSimpleUserOption) {
      options.add(
        CommandOptionBuilder(
          type: CommandOptionType.user,
          name: 'user',
          description: AppStrings.t('cmd_simple_option_user_desc'),
          isRequired: true,
        ),
      );
    }

    if (_requiresSimpleRoleOption) {
      options.add(
        CommandOptionBuilder(
          type: CommandOptionType.role,
          name: 'role',
          description: AppStrings.t('cmd_simple_option_role_desc'),
          isRequired: true,
        ),
      );
    }

    if (_simpleDeleteMessages) {
      options.add(
        CommandOptionBuilder(
          type: CommandOptionType.integer,
          name: 'count',
          description: AppStrings.t('cmd_simple_option_count_desc'),
          isRequired: false,
          minValue: 1,
          maxValue: 100,
        ),
      );
    }

    return options;
  }

  List<Map<String, dynamic>> _buildSimpleModeActions() {
    final actions = <Map<String, dynamic>>[];

    Map<String, dynamic> makeAction({
      required String key,
      required String type,
      required Map<String, dynamic> payload,
    }) {
      return {
        'id': key,
        'type': type,
        'enabled': true,
        'key': key,
        'depend_on': <String>[],
        'error': {'mode': 'stop'},
        'payload': payload,
      };
    }

    if (_simpleDeleteMessages) {
      actions.add(
        makeAction(
          key: 'delete_messages',
          type: 'deleteMessages',
          payload: {'channelId': '', 'messageCount': '((opts.count | 1))'},
        ),
      );
    }

    if (_simpleKickUser) {
      actions.add(
        makeAction(
          key: 'kick_user',
          type: 'kickUser',
          payload: {'userId': '((opts.user.id))', 'reason': ''},
        ),
      );
    }

    if (_simpleBanUser) {
      actions.add(
        makeAction(
          key: 'ban_user',
          type: 'banUser',
          payload: {
            'userId': '((opts.user.id))',
            'reason': '',
            'deleteMessageDays': 0,
          },
        ),
      );
    }

    if (_simpleMuteUser) {
      actions.add(
        makeAction(
          key: 'mute_user',
          type: 'muteUser',
          payload: {
            'userId': '((opts.user.id))',
            'duration': '10m',
            'reason': '',
          },
        ),
      );
    }

    if (_simpleAddRole) {
      actions.add(
        makeAction(
          key: 'add_role',
          type: 'addRole',
          payload: {
            'userId': '((opts.user.id))',
            'roleId': '((opts.role.id))',
            'reason': '',
          },
        ),
      );
    }

    if (_simpleRemoveRole) {
      actions.add(
        makeAction(
          key: 'remove_role',
          type: 'removeRole',
          payload: {
            'userId': '((opts.user.id))',
            'roleId': '((opts.role.id))',
            'reason': '',
          },
        ),
      );
    }

    if (_simpleSendMessage) {
      actions.add(
        makeAction(
          key: 'send_message',
          type: 'sendMessage',
          payload: {
            'channelId': '',
            'content': _simpleSendMessageController.text.trim(),
          },
        ),
      );
    }

    return actions;
  }

  List<CommandOptionBuilder> get _effectiveOptions =>
      _isSimpleMode ? _buildSimpleModeOptions() : _options;

  List<Map<String, dynamic>> get _effectiveActions =>
      _isSimpleMode ? _buildSimpleModeActions() : _actions;

  List<Map<String, dynamic>> _normalizeEmbedsPayload(dynamic rawEmbeds) {
    if (rawEmbeds is! List) {
      return <Map<String, dynamic>>[];
    }

    return rawEmbeds
        .whereType<Map>()
        .map((embed) {
          return Map<String, dynamic>.from(
            embed.map((key, value) => MapEntry(key.toString(), value)),
          );
        })
        .take(10)
        .toList(growable: false);
  }

  Map<String, dynamic> _normalizeWorkflow(Map<String, dynamic> input) {
    final conditional = Map<String, dynamic>.from(
      (input['conditional'] as Map?)?.cast<String, dynamic>() ?? const {},
    );

    return {
      'autoDeferIfActions': input['autoDeferIfActions'] != false,
      'visibility':
          (input['visibility']?.toString().toLowerCase() == 'ephemeral')
              ? 'ephemeral'
              : 'public',
      'onError': 'edit_error',
      'conditional': {
        'enabled': conditional['enabled'] == true,
        'variable': (conditional['variable'] ?? '').toString(),
        'whenTrueType': (conditional['whenTrueType'] ?? 'normal').toString(),
        'whenFalseType': (conditional['whenFalseType'] ?? 'normal').toString(),
        'whenTrueText': (conditional['whenTrueText'] ?? '').toString(),
        'whenFalseText': (conditional['whenFalseText'] ?? '').toString(),
        'whenTrueEmbeds': _normalizeEmbedsPayload(
          conditional['whenTrueEmbeds'],
        ),
        'whenFalseEmbeds': _normalizeEmbedsPayload(
          conditional['whenFalseEmbeds'],
        ),
        'whenTrueNormalComponents': Map<String, dynamic>.from(
          (conditional['whenTrueNormalComponents'] as Map?)
                  ?.cast<String, dynamic>() ??
              const {},
        ),
        'whenFalseNormalComponents': Map<String, dynamic>.from(
          (conditional['whenFalseNormalComponents'] as Map?)
                  ?.cast<String, dynamic>() ??
              const {},
        ),
        'whenTrueComponents': Map<String, dynamic>.from(
          (conditional['whenTrueComponents'] as Map?)
                  ?.cast<String, dynamic>() ??
              const {},
        ),
        'whenFalseComponents': Map<String, dynamic>.from(
          (conditional['whenFalseComponents'] as Map?)
                  ?.cast<String, dynamic>() ??
              const {},
        ),
        'whenTrueModal': Map<String, dynamic>.from(
          (conditional['whenTrueModal'] as Map?)?.cast<String, dynamic>() ??
              const {},
        ),
        'whenFalseModal': Map<String, dynamic>.from(
          (conditional['whenFalseModal'] as Map?)?.cast<String, dynamic>() ??
              const {},
        ),
      },
    };
  }

  String _workflowSummary() {
    final visibility =
        _responseWorkflow['visibility'] == 'ephemeral' ? 'Ephemeral' : 'Public';
    final autoDefer = _responseWorkflow['autoDeferIfActions'] != false;
    final conditional = Map<String, dynamic>.from(
      (_responseWorkflow['conditional'] as Map?)?.cast<String, dynamic>() ??
          const {},
    );
    final conditionEnabled = conditional['enabled'] == true;
    final conditionLabel = conditionEnabled ? 'Condition ON' : 'Condition OFF';

    return '${autoDefer ? 'Auto defer if actions' : 'No auto defer'} • $visibility • $conditionLabel';
  }

  String? get _botIdForConfig => widget.client?.user.id.toString();

  final List<Map<String, String>> _argsList = [
    {"name": "guildName", "description": "Name of the guild"},
    {"name": "guildId", "description": "ID of the guild"},
    {"name": "channelName", "description": "Name of the channel"},
    {"name": "channelId", "description": "ID of the channel"},
    {"name": "userName", "description": "Name of the user"},
    {"name": "userId", "description": "ID of the user"},
    {"name": "userTag", "description": "Tag of the user"},
    {"name": "userAvatar", "description": "Avatar of the user"},
    {"name": "guildIcon", "description": "Icon of the guild"},
    {"name": "guildCount", "description": "Number of members in the guild"},
    {"name": "commandName", "description": "Name of the command"},
    {"name": "commandId", "description": "ID of the command"},
    {
      "name": "opts",
      "description":
          "Contain options resolved from the command (ex: opts.user.avatar) (if the opt was of type 'User' and named 'user')",
    },
    // Add more options as needed
  ];

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _responseController.text = _response;
    _responseController.addListener(() {
      _response = _responseController.text;
      if (mounted) {
        setState(() {});
      }
    });
    _init();
    // Initialize any necessary data or state
  }

  @override
  void dispose() {
    _responseController.dispose();
    _simpleSendMessageController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await AppAnalytics.logScreenView(
      screenName: "CommandCreatePage",
      screenClass: "CommandCreatePage",
      parameters: {
        "command_id": widget.id.toString(),
        "command_name": widget.id.isZero ? "New Command" : _commandName,
        "is_new_command": widget.id.isZero ? "true" : "false",
        "client_id": widget.client?.user.id.toString() ?? "unknown",
      },
    );
    // first let's check if the command is already created or not
    if (!widget.id.isZero) {
      _editorMode = _editorModeAdvanced;
      _simpleModeLocked = true;
      ApplicationCommand? command;
      try {
        final commandsList = await widget.client?.commands.list(
          withLocalizations: true,
        );
        command = commandsList?.cast<ApplicationCommand?>().firstWhere(
          (c) => c?.id == widget.id,
          orElse: () => null,
        );
      } catch (_) {}

      command ??= await widget.client?.commands.fetch(widget.id);

      // check if we also have the command in the database
      final commandData = await appManager.getAppCommand(
        widget.client!.user.id.toString(),
        widget.id.toString(),
      );
      // let's set the command data to the fields
      final data = commandData["data"];
      if (data != null) {
        final normalized = appManager.normalizeCommandData(
          Map<String, dynamic>.from(commandData),
        );
        final normalizedData = Map<String, dynamic>.from(
          normalized["data"] ?? const {},
        );
        final persistedEditorMode =
            (normalizedData['editorMode'] ?? _editorModeAdvanced)
                .toString()
                .toLowerCase();
        final editorMode =
            persistedEditorMode == _editorModeSimple
                ? _editorModeSimple
                : _editorModeAdvanced;
        final simpleConfig = _normalizeSimpleConfig(
          Map<String, dynamic>.from(
            (normalizedData['simpleConfig'] as Map?)?.cast<String, dynamic>() ??
                const {},
          ),
        );
        final response = Map<String, dynamic>.from(
          (normalizedData["response"] as Map?)?.cast<String, dynamic>() ??
              const {},
        );
        final embeds =
            (response['embeds'] is List)
                ? List<Map<String, dynamic>>.from(
                  (response['embeds'] as List).whereType<Map>().map(
                    (embed) => Map<String, dynamic>.from(
                      embed.map(
                        (key, value) => MapEntry(key.toString(), value),
                      ),
                    ),
                  ),
                )
                : <Map<String, dynamic>>[];

        if (embeds.isEmpty) {
          final legacyEmbed = Map<String, dynamic>.from(
            (response['embed'] as Map?)?.cast<String, dynamic>() ?? const {},
          );
          final hasLegacyEmbed =
              (legacyEmbed['title']?.toString().isNotEmpty ?? false) ||
              (legacyEmbed['description']?.toString().isNotEmpty ?? false) ||
              (legacyEmbed['url']?.toString().isNotEmpty ?? false);
          if (hasLegacyEmbed) {
            embeds.add({
              'title': legacyEmbed['title']?.toString() ?? '',
              'description': legacyEmbed['description']?.toString() ?? '',
              'url': legacyEmbed['url']?.toString() ?? '',
            });
          }
        }

        setState(() {
          _editorMode = editorMode;
          _simpleModeLocked = editorMode == _editorModeAdvanced;
          _applySimpleConfig(simpleConfig);
          _responseType = (response['type'] ?? 'normal').toString();
          _response = (response["text"] ?? "").toString();
          _responseController.text = _response;
          _responseEmbeds = embeds.take(10).toList();
          _responseComponents = Map<String, dynamic>.from(
            (response['components'] as Map?)?.cast<String, dynamic>() ??
                const {},
          );
          _responseModal = Map<String, dynamic>.from(
            (response['modal'] as Map?)?.cast<String, dynamic>() ?? const {},
          );
          _responseWorkflow = _normalizeWorkflow(
            Map<String, dynamic>.from(
              (response['workflow'] as Map?)?.cast<String, dynamic>() ??
                  _defaultWorkflow(),
            ),
          );
          _actions = List<Map<String, dynamic>>.from(
            (normalizedData["actions"] as List?)?.whereType<Map>().map(
                  (e) => Map<String, dynamic>.from(e),
                ) ??
                const [],
          );
          _defaultMemberPermissions =
              (normalizedData['defaultMemberPermissions'] ?? '')
                  .toString()
                  .trim();
        });
      }
      if (command != null) {
        final currentCommand = command;
        setState(() {
          _commandName = currentCommand.name;
          _commandDescription = currentCommand.description;
          if (currentCommand.options != null) {
            _options =
                currentCommand.options!.map((e) {
                  final option = CommandOptionBuilder(
                    type: e.type,
                    name: e.name,
                    description: e.description,
                    isRequired: e.isRequired,
                    minValue: e.minValue,
                    maxValue: e.maxValue,
                    nameLocalizations: e.nameLocalizations,
                    descriptionLocalizations: e.descriptionLocalizations,
                  );
                  if (e.choices?.isNotEmpty ?? false) {
                    option.choices =
                        e.choices?.map((choice) {
                          return CommandOptionChoiceBuilder(
                            name: choice.name,
                            value: choice.value,
                          );
                        }).toList();
                  }
                  return option;
                }).toList();
          } else {
            _options = [];
          }
          _integrationTypes =
              currentCommand.integrationTypes.map((e) {
                if (e == ApplicationIntegrationType.guildInstall) {
                  return ApplicationIntegrationType.guildInstall;
                } else if (e == ApplicationIntegrationType.userInstall) {
                  return ApplicationIntegrationType.userInstall;
                } else {
                  return ApplicationIntegrationType.guildInstall;
                }
              }).toList();
          _contexts = [];
          if (currentCommand.contexts != null) {
            _contexts = currentCommand.contexts!.toList();
          } else {
            // legacy defaults to guild
            _contexts = [InteractionContextType.guild];
          }
          if (_defaultMemberPermissions.isEmpty &&
              currentCommand.defaultMemberPermissions != null) {
            _defaultMemberPermissions =
                currentCommand.defaultMemberPermissions!.value.toString();
          }
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _switchToAdvancedMode() async {
    if (_simpleModeLocked || !_isSimpleMode) {
      return;
    }

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text(AppStrings.t('cmd_editor_mode_switch_adv_title')),
                content: Text(
                  AppStrings.t('cmd_editor_mode_switch_adv_content'),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(AppStrings.t('cancel')),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(
                      AppStrings.t('cmd_editor_mode_switch_adv_confirm'),
                    ),
                  ),
                ],
              ),
        ) ??
        false;

    if (!confirmed || !mounted) {
      return;
    }

    setState(() {
      _editorMode = _editorModeAdvanced;
      _simpleModeLocked = true;
    });
  }

  Widget _buildSimpleActionToggle({
    required bool value,
    required String title,
    required String subtitle,
    required ValueChanged<bool> onChanged,
  }) {
    return CheckboxListTile(
      value: value,
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(subtitle),
      onChanged: (next) => onChanged(next == true),
    );
  }

  Widget _buildEditorModeCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppStrings.t('cmd_editor_mode_title'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              _isSimpleMode
                  ? AppStrings.t('cmd_editor_mode_simple_desc')
                  : AppStrings.t('cmd_editor_mode_advanced_desc'),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Icon(
                    _isSimpleMode ? Icons.auto_awesome : Icons.tune,
                    color:
                        _isSimpleMode
                            ? const Color.fromRGBO(106, 15, 162, 1)
                            : Colors.blueGrey,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _isSimpleMode
                          ? AppStrings.t('cmd_editor_mode_simple')
                          : AppStrings.t('cmd_editor_mode_advanced'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            if (_isSimpleMode) ...[
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: _simpleModeLocked ? null : _switchToAdvancedMode,
                icon: const Icon(Icons.upgrade),
                label: Text(AppStrings.t('cmd_editor_mode_switch_adv')),
              ),
            ] else ...[
              const SizedBox(height: 12),
              Text(
                AppStrings.t('cmd_editor_mode_locked'),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleActionsCard() {
    final generatedOptionLabels = <String>[];
    if (_requiresSimpleUserOption) {
      generatedOptionLabels.add(AppStrings.t('cmd_simple_option_user'));
    }
    if (_requiresSimpleRoleOption) {
      generatedOptionLabels.add(AppStrings.t('cmd_simple_option_role'));
    }
    if (_simpleDeleteMessages) {
      generatedOptionLabels.add(AppStrings.t('cmd_simple_option_count'));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppStrings.t('cmd_simple_actions_title'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              AppStrings.t('cmd_simple_actions_desc'),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            _buildSimpleActionToggle(
              value: _simpleDeleteMessages,
              title: AppStrings.t('cmd_simple_action_delete'),
              subtitle: AppStrings.t('cmd_simple_action_delete_desc'),
              onChanged: (value) {
                setState(() {
                  _simpleDeleteMessages = value;
                });
              },
            ),
            _buildSimpleActionToggle(
              value: _simpleKickUser,
              title: AppStrings.t('cmd_simple_action_kick'),
              subtitle: AppStrings.t('cmd_simple_action_kick_desc'),
              onChanged: (value) {
                setState(() {
                  _simpleKickUser = value;
                });
              },
            ),
            _buildSimpleActionToggle(
              value: _simpleBanUser,
              title: AppStrings.t('cmd_simple_action_ban'),
              subtitle: AppStrings.t('cmd_simple_action_ban_desc'),
              onChanged: (value) {
                setState(() {
                  _simpleBanUser = value;
                });
              },
            ),
            _buildSimpleActionToggle(
              value: _simpleMuteUser,
              title: AppStrings.t('cmd_simple_action_mute'),
              subtitle: AppStrings.t('cmd_simple_action_mute_desc'),
              onChanged: (value) {
                setState(() {
                  _simpleMuteUser = value;
                });
              },
            ),
            _buildSimpleActionToggle(
              value: _simpleAddRole,
              title: AppStrings.t('cmd_simple_action_add_role'),
              subtitle: AppStrings.t('cmd_simple_action_add_role_desc'),
              onChanged: (value) {
                setState(() {
                  _simpleAddRole = value;
                });
              },
            ),
            _buildSimpleActionToggle(
              value: _simpleRemoveRole,
              title: AppStrings.t('cmd_simple_action_remove_role'),
              subtitle: AppStrings.t('cmd_simple_action_remove_role_desc'),
              onChanged: (value) {
                setState(() {
                  _simpleRemoveRole = value;
                });
              },
            ),
            _buildSimpleActionToggle(
              value: _simpleSendMessage,
              title: AppStrings.t('cmd_simple_action_send_message'),
              subtitle: AppStrings.t('cmd_simple_action_send_message_desc'),
              onChanged: (value) {
                setState(() {
                  _simpleSendMessage = value;
                });
              },
            ),
            if (_simpleSendMessage) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _simpleSendMessageController,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: AppStrings.t(
                    'cmd_simple_action_send_message_label',
                  ),
                  hintText: AppStrings.t('cmd_simple_action_send_message_hint'),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) {
                  if (mounted) {
                    setState(() {});
                  }
                },
              ),
            ],
            const SizedBox(height: 12),
            Text(
              AppStrings.t('cmd_simple_generated_options'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (generatedOptionLabels.isEmpty)
              Text(
                AppStrings.t('cmd_simple_generated_none'),
                style: TextStyle(color: Colors.grey.shade600),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    generatedOptionLabels
                        .map((label) => Chip(label: Text(label)))
                        .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleResponseCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppStrings.t('cmd_simple_response_title'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              AppStrings.t('cmd_simple_response_desc'),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _responseController,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: AppStrings.t('cmd_simple_response_hint'),
                border: const OutlineInputBorder(),
              ),
            ),
            _buildVariableSuggestionBar(_responseController),
            const SizedBox(height: 12),
            Text(
              AppStrings.t('cmd_simple_response_embeds_title'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              AppStrings.t('cmd_simple_response_embeds_desc'),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            ResponseEmbedsEditor(
              embeds: _responseEmbeds,
              variableSuggestions: _actionVariableSuggestions,
              onChanged: (embeds) {
                setState(() {
                  _responseEmbeds = embeds;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateOrCreate() async {
    // check if any field is empty
    if (_commandName.isEmpty || _commandDescription.isEmpty) {
      final dialog = AlertDialog(
        title: Text(AppStrings.t('error')),
        content: Text(AppStrings.t('cmd_error_fill_fields')),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(AppStrings.t('ok')),
          ),
        ],
      );
      showDialog(context: context, builder: (context) => dialog);
      return;
    }

    if (_isSimpleMode &&
        _simpleSendMessage &&
        _simpleSendMessageController.text.trim().isEmpty) {
      final dialog = AlertDialog(
        title: Text(AppStrings.t('error')),
        content: Text(AppStrings.t('cmd_simple_send_message_required')),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(AppStrings.t('ok')),
          ),
        ],
      );
      showDialog(context: context, builder: (context) => dialog);
      return;
    }

    final effectiveOptions = _effectiveOptions;
    final effectiveActions = _effectiveActions;

    final commandData = {
      "version": 1,
      "editorMode": _editorMode,
      "simpleConfig": _currentSimpleConfig(),
      "defaultMemberPermissions": _defaultMemberPermissions.trim(),
      "response": {
        "mode": _responseEmbeds.isNotEmpty ? "embed" : "text",
        "type": _responseType,
        "text": _responseController.text,
        "embed":
            _responseEmbeds.isNotEmpty
                ? _responseEmbeds.first
                : {"title": "", "description": "", "url": ""},
        "embeds": _responseEmbeds.take(10).toList(),
        "components": _responseComponents,
        "modal": _responseModal,
        "workflow": _normalizeWorkflow(_responseWorkflow),
      },
      "actions": effectiveActions,
    };

    final client = widget.client;
    if (client == null) {
      // Handle error: client is null
      return;
    }
    try {
      if (widget.id.isZero) {
        // Create a new command
        final commandBuilder = ApplicationCommandBuilder(
          name: _commandName,
          description: _commandDescription,
          type: ApplicationCommandType.chatInput,
        );

        final parsedPermissions = _parseDefaultMemberPermissions(
          _defaultMemberPermissions,
        );
        commandBuilder.defaultMemberPermissions = parsedPermissions;

        commandBuilder.integrationTypes = _integrationTypes;
        if (_contexts.isNotEmpty) {
          commandBuilder.contexts = _contexts;
        }
        if (effectiveOptions.isNotEmpty) {
          commandBuilder.options = effectiveOptions;
        }
        await createCommand(client, commandBuilder, data: commandData);
      } else {
        // Update the existing command
        final commandBuilder = ApplicationCommandUpdateBuilder(
          name: _commandName,
          description: _commandDescription,
        );
        final parsedPermissions = _parseDefaultMemberPermissions(
          _defaultMemberPermissions,
        );
        commandBuilder.defaultMemberPermissions = parsedPermissions;
        commandBuilder.integrationTypes = _integrationTypes;
        if (_contexts.isNotEmpty) {
          commandBuilder.contexts = _contexts;
        } else {
          commandBuilder.contexts = [];
        }
        if (effectiveOptions.isNotEmpty) {
          commandBuilder.options = effectiveOptions;
        } else {
          commandBuilder.options = [];
        }

        await updateCommand(
          client,
          widget.id,
          commandBuilder: commandBuilder,
          data: commandData,
        );
      }
      Navigator.pop(context);
    } catch (e) {
      // Handle error
      final errorText = e.toString();
      final dialog = AlertDialog(
        title: const Text("Error"),
        content: Text(errorText),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text("OK"),
          ),
        ],
      );
      showDialog(context: context, builder: (context) => dialog);
    }
  }

  String? _validateName(String? value) {
    if (value!.isEmpty) {
      return "Please enter a command name";
    }
    if (value.length > 32) {
      return "Command name must be at most 32 characters long";
    }
    if (value.contains(" ")) {
      return "Command name cannot contain spaces";
    }
    if (value.contains(RegExp(r'[^a-zA-Z0-9_]'))) {
      return "Command name can only contain letters, numbers, and underscores";
    }
    if (value.startsWith("_")) {
      return "Command name cannot start with an underscore";
    }
    if (value.startsWith("!")) {
      return "Command name cannot start with an exclamation mark";
    }
    if (value.startsWith("/")) {
      return "Command name cannot start with a slash";
    }
    if (value.startsWith("#")) {
      return "Command name cannot start with a hash";
    }
    if (value.startsWith("@")) {
      return "Command name cannot start with an at sign";
    }
    if (value.startsWith("&")) {
      return "Command name cannot start with an ampersand";
    }
    if (value.startsWith("%")) {
      return "Command name cannot start with a percent sign";
    }
    return null; // No error
  }

  Permissions? _parseDefaultMemberPermissions(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final parsed = int.tryParse(trimmed);
    if (parsed == null || parsed < 0) {
      throw Exception(
        'Invalid default member permissions bitfield. Use a positive integer or leave empty.',
      );
    }
    return Permissions(parsed);
  }

  List<String> get _variableNames {
    final base = _argsList
        .map((e) => e['name'])
        .whereType<String>()
        .toList(growable: true);

    for (final option in _effectiveOptions) {
      final optionName = option.name;
      if (optionName.isEmpty) {
        continue;
      }

      base.add('opts.$optionName');

      switch (option.type) {
        case CommandOptionType.user:
        case CommandOptionType.mentionable:
          base.addAll(['opts.$optionName.id', 'opts.$optionName.avatar']);
          break;
        case CommandOptionType.channel:
          base.addAll(['opts.$optionName.id', 'opts.$optionName.type']);
          break;
        case CommandOptionType.role:
          base.add('opts.$optionName.id');
          break;
        default:
          break;
      }
    }

    base.addAll(_actionOutputVariableNames());

    return base.toSet().toList(growable: false)..sort();
  }

  String _resolveActionKey(Map<String, dynamic> action, int index) {
    final rootKey = (action['key'] ?? '').toString().trim();
    if (rootKey.isNotEmpty) {
      return rootKey;
    }

    final parameters = Map<String, dynamic>.from(
      (action['parameters'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    final parametersKey = (parameters['key'] ?? '').toString().trim();
    if (parametersKey.isNotEmpty) {
      return parametersKey;
    }

    final payload = Map<String, dynamic>.from(
      (action['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    final payloadKey = (payload['key'] ?? '').toString().trim();
    if (payloadKey.isNotEmpty) {
      return payloadKey;
    }

    return 'action_$index';
  }

  List<String> _actionOutputVariableNames() {
    final outputVariables = <String>{};

    final actions = _effectiveActions;
    for (var i = 0; i < actions.length; i++) {
      final action = actions[i];
      final actionKey = _resolveActionKey(action, i);
      if (actionKey.isEmpty) {
        continue;
      }

      outputVariables.add('action.$actionKey');

      final type = (action['type'] ?? '').toString();
      if (type == 'deleteMessages') {
        outputVariables.addAll([
          'action.$actionKey.count',
          '$actionKey.count',
          'action.$actionKey.deleteItself',
          '$actionKey.deleteItself',
        ]);
      }

      if (type == 'httpRequest') {
        outputVariables.addAll([
          'action.$actionKey.status',
          'action.$actionKey.body',
          'action.$actionKey.jsonPath',
          '$actionKey.status',
          '$actionKey.body',
          '$actionKey.jsonPath',
        ]);
      }
    }

    return outputVariables.toList(growable: false)..sort();
  }

  List<VariableSuggestion> get _actionVariableSuggestions {
    final suggestionsByName = <String, VariableSuggestion>{};

    void addSuggestion(String name, {required VariableSuggestionKind kind}) {
      final existing = suggestionsByName[name];
      if (existing == null) {
        suggestionsByName[name] = VariableSuggestion(name: name, kind: kind);
        return;
      }

      if (existing.kind == VariableSuggestionKind.numeric ||
          existing.kind == kind) {
        return;
      }

      if (kind == VariableSuggestionKind.numeric) {
        suggestionsByName[name] = VariableSuggestion(name: name, kind: kind);
      }
    }

    for (final arg in _argsList) {
      final name = (arg['name'] ?? '').toString().trim();
      if (name.isEmpty) {
        continue;
      }

      addSuggestion(
        name,
        kind:
            name == 'guildCount'
                ? VariableSuggestionKind.numeric
                : VariableSuggestionKind.nonNumeric,
      );
    }

    for (final option in _effectiveOptions) {
      final optionName = option.name.trim();
      if (optionName.isEmpty) {
        continue;
      }

      addSuggestion('opts.$optionName', kind: VariableSuggestionKind.unknown);

      switch (option.type) {
        case CommandOptionType.integer:
        case CommandOptionType.number:
          addSuggestion(
            'opts.$optionName',
            kind: VariableSuggestionKind.numeric,
          );
          break;
        case CommandOptionType.user:
        case CommandOptionType.mentionable:
          addSuggestion(
            'opts.$optionName.id',
            kind: VariableSuggestionKind.nonNumeric,
          );
          addSuggestion(
            'opts.$optionName.avatar',
            kind: VariableSuggestionKind.nonNumeric,
          );
          break;
        case CommandOptionType.channel:
          addSuggestion(
            'opts.$optionName.id',
            kind: VariableSuggestionKind.nonNumeric,
          );
          addSuggestion(
            'opts.$optionName.type',
            kind: VariableSuggestionKind.nonNumeric,
          );
          break;
        case CommandOptionType.role:
          addSuggestion(
            'opts.$optionName.id',
            kind: VariableSuggestionKind.nonNumeric,
          );
          break;
        default:
          break;
      }
    }

    final actions = _effectiveActions;
    for (var i = 0; i < actions.length; i++) {
      final action = actions[i];
      final actionKey = _resolveActionKey(action, i);
      if (actionKey.isEmpty) {
        continue;
      }
      addSuggestion('action.$actionKey', kind: VariableSuggestionKind.unknown);

      final type = (action['type'] ?? '').toString();
      if (type == 'httpRequest') {
        addSuggestion(
          'action.$actionKey.status',
          kind: VariableSuggestionKind.numeric,
        );
        addSuggestion(
          'action.$actionKey.body',
          kind: VariableSuggestionKind.nonNumeric,
        );
        addSuggestion(
          'action.$actionKey.jsonPath',
          kind: VariableSuggestionKind.nonNumeric,
        );
      }
    }

    addSuggestion('workflow.name', kind: VariableSuggestionKind.nonNumeric);
    addSuggestion(
      'workflow.entryPoint',
      kind: VariableSuggestionKind.nonNumeric,
    );
    addSuggestion('workflow.args', kind: VariableSuggestionKind.nonNumeric);
    addSuggestion('arg.yourArg', kind: VariableSuggestionKind.unknown);
    addSuggestion('workflow.arg.yourArg', kind: VariableSuggestionKind.unknown);

    final suggestions = suggestionsByName.values.toList(growable: false)
      ..sort((a, b) => a.name.compareTo(b.name));

    return suggestions;
  }

  String _currentVariableQuery(TextEditingController controller) {
    final selection = controller.selection;
    final cursor = selection.baseOffset;
    if (cursor < 0) {
      return '';
    }

    final beforeCursor = controller.text.substring(0, cursor);
    final start = beforeCursor.lastIndexOf('((');
    if (start == -1) {
      return '';
    }

    final alreadyClosed = beforeCursor.substring(start).contains('))');
    if (alreadyClosed) {
      return '';
    }

    final raw = beforeCursor.substring(start + 2);
    final parts = raw.split('|');
    return parts.last.trimLeft();
  }

  void _insertVariable(TextEditingController controller, String variableName) {
    final selection = controller.selection;
    final cursor = selection.baseOffset;
    if (cursor < 0) {
      return;
    }

    final beforeCursor = controller.text.substring(0, cursor);
    final afterCursor = controller.text.substring(cursor);
    final start = beforeCursor.lastIndexOf('((');
    if (start == -1) {
      final token = '(($variableName))';
      final nextText = '$beforeCursor$token$afterCursor';
      final nextCursor = beforeCursor.length + token.length;
      controller.value = TextEditingValue(
        text: nextText,
        selection: TextSelection.collapsed(offset: nextCursor),
      );
      return;
    }

    final rawInner = beforeCursor.substring(start + 2);
    final parts = rawInner.split('|');
    final prefixParts =
        parts.length > 1 ? parts.sublist(0, parts.length - 1) : <String>[];
    final previous =
        prefixParts.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final merged = [...previous, variableName];
    final inner = merged.join(' | ');

    final newBefore = '${beforeCursor.substring(0, start)}(($inner))';
    final nextText = '$newBefore$afterCursor';
    final nextCursor = newBefore.length;

    controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextCursor),
    );
  }

  Widget _buildVariableSuggestionBar(TextEditingController controller) {
    final query = _currentVariableQuery(controller).trim();
    final cursor = controller.selection.baseOffset;
    if (cursor < 0) {
      return const SizedBox.shrink();
    }

    final beforeCursor = controller.text.substring(0, cursor);
    final start = beforeCursor.lastIndexOf('((');
    if (start == -1) {
      return const SizedBox.shrink();
    }

    final inner = beforeCursor.substring(start + 2);
    final inFallbackMode = inner.contains('|');

    if (query.isEmpty && !inFallbackMode) {
      return const SizedBox.shrink();
    }

    final suggestions =
        _variableNames
            .where((name) => name.toLowerCase().contains(query.toLowerCase()))
            .take(8)
            .toList();

    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (inFallbackMode)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'Fallback mode: next variable is used if previous is empty.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  suggestions
                      .map(
                        (name) => ActionChip(
                          label: Text('(($name))'),
                          onPressed: () => _insertVariable(controller, name),
                        ),
                      )
                      .toList(),
            ),
          ],
        ),
      ),
    );
  }

  // Card helper removed.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(106, 15, 162, 1),
        actions: [
          IconButton(
            onPressed: () {
              final dialogFullscren = Dialog.fullscreen(
                child: Scaffold(
                  appBar: AppBar(
                    title: Text(AppStrings.t('cmd_variables_title')),
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  body: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: 2.0,
                    children: [
                      const SizedBox(height: 20),
                      Card(
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(
                            "You can use the following arguments in your command response.\nThey will be replaced with the actual values when the command is executed.\nFor example, if you use ((userName)) in your response, it will be replaced with the name of the user who executed the command.\nYou can also use every command option as an argument. (be sure to use the correct name)",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(1.0),
                          itemCount: _argsList.length,
                          itemBuilder: (context, index) {
                            final arg = _argsList[index];
                            return ListTile(
                              title: Text(arg["name"]!),
                              subtitle: Text(arg["description"]!),
                              style: ListTileStyle.list,
                              leading: const Icon(Icons.code),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              );

              showDialog(
                context: context,
                builder: (context) => dialogFullscren,
              );
            },
            tooltip: AppStrings.t('cmd_show_variables'),
            icon: const Icon(Icons.info_outline),
          ),
          if (widget.id.isZero)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: AppStrings.t('cmd_create_tooltip'),
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  _updateOrCreate();
                  // Form is valid, proceed with command creation
                } else {
                  // Form is invalid, show error message
                  final dialog = AlertDialog(
                    title: Text(AppStrings.t('error')),
                    content: Text(AppStrings.t('cmd_error_fill_fields')),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: Text(AppStrings.t('ok')),
                      ),
                    ],
                  );
                  showDialog(context: context, builder: (context) => dialog);
                }
                // Handle add action
                // You can implement the logic to add a new command here
              },
            ),
          IconButton(
            icon: Icon(
              widget.id.isZero ? Icons.cancel : Icons.save,
            ), // Change icon based on command existence
            tooltip:
                widget.id.isZero
                    ? AppStrings.t('cancel')
                    : AppStrings.t('cmd_create_tooltip'),
            onPressed: () async {
              if (widget.id.isZero) {
                Navigator.pop(context);
                // Handle cancel action
                // You can implement the logic to cancel the command creation here
              } else {
                if (_formKey.currentState!.validate()) {
                  _updateOrCreate();
                  AppAnalytics.logEvent(
                    name: "update_command",
                    parameters: {
                      "command_name": _commandName,
                      "command_id": widget.id.toString(),
                    },
                  );
                  // Form is valid, proceed with command creation
                } else {
                  // Form is invalid, show error message
                  final dialog = AlertDialog(
                    title: Text(AppStrings.t('error')),
                    content: Text(AppStrings.t('cmd_error_fill_fields')),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: Text(AppStrings.t('ok')),
                      ),
                    ],
                  );
                  showDialog(context: context, builder: (context) => dialog);
                }
                // You can implement the logic to save the command here
              }
            },
          ),
          if (!widget.id.isZero)
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: AppStrings.t('cmd_delete_tooltip'),
              onPressed: () async {
                await widget.client?.commands.delete(widget.id);
                await appManager.deleteAppCommand(
                  widget.client!.user.id.toString(),
                  widget.id.toString(),
                );
                Navigator.pop(context);
                // Handle delete action
                // You can implement the logic to delete the command here
              },
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final contentMaxWidth =
              constraints.maxWidth >= 1200
                  ? 980.0
                  : (constraints.maxWidth >= 900 ? 860.0 : 680.0);

          return Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentMaxWidth),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      widget.id.isZero
                          ? "Create a new command"
                          : "Update command",
                      style: const TextStyle(fontSize: 24),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    if (_isLoading)
                      const CircularProgressIndicator()
                    else
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            BasicInfoCard(
                              commandName: _commandName,
                              commandDescription: _commandDescription,
                              integrationTypes: _integrationTypes,
                              contexts: _contexts,
                              defaultMemberPermissions:
                                  _defaultMemberPermissions,
                              onNameChanged: (val) {
                                setState(() {
                                  _commandName = val;
                                });
                              },
                              onDescriptionChanged: (val) {
                                setState(() {
                                  _commandDescription = val;
                                });
                              },
                              onIntegrationTypesChanged: (val) {
                                setState(() {
                                  _integrationTypes = val;
                                });
                              },
                              onContextsChanged: (val) {
                                setState(() {
                                  _contexts = val;
                                });
                              },
                              onDefaultMemberPermissionsChanged: (value) {
                                setState(() {
                                  _defaultMemberPermissions = value;
                                });
                              },
                              nameValidator: _validateName,
                            ),
                            const SizedBox(height: 12),
                            _buildEditorModeCard(context),
                            const SizedBox(height: 12),
                            if (_isSimpleMode) ...[
                              _buildSimpleActionsCard(),
                              const SizedBox(height: 12),
                              _buildSimpleResponseCard(),
                            ] else ...[
                              ReplyCard(
                                responseType: _responseType,
                                onResponseTypeChanged: (type) {
                                  setState(() {
                                    _responseType = type;
                                  });
                                },
                                responseController: _responseController,
                                variableSuggestionBar:
                                    _buildVariableSuggestionBar(
                                      _responseController,
                                    ),
                                responseEmbeds: _responseEmbeds,
                                onEmbedsChanged: (embeds) {
                                  setState(() {
                                    _responseEmbeds = embeds;
                                  });
                                },
                                responseComponents: _responseComponents,
                                onComponentsChanged: (components) {
                                  setState(() {
                                    _responseComponents = components;
                                  });
                                },
                                responseModal: _responseModal,
                                onModalChanged: (modal) {
                                  setState(() {
                                    _responseModal = modal;
                                  });
                                },
                                responseWorkflow: _responseWorkflow,
                                normalizeWorkflow: _normalizeWorkflow,
                                variableSuggestions: _actionVariableSuggestions,
                                botIdForConfig: _botIdForConfig,
                                onWorkflowChanged: (workflow) {
                                  setState(() {
                                    _responseWorkflow = workflow;
                                  });
                                },
                                workflowSummary: _workflowSummary(),
                              ),
                              const SizedBox(height: 16),
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      const Text(
                                        "Command Options",
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Slash-command parameters",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      OptionWidget(
                                        initialOptions: _options,
                                        onChange: (options) {
                                          setState(() {
                                            _options = options;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              ActionsCard(
                                actions: _actions,
                                onActionsChanged: (val) {
                                  setState(() {
                                    _actions = val;
                                  });
                                },
                                actionVariableSuggestions:
                                    _actionVariableSuggestions,
                                botIdForConfig: _botIdForConfig,
                              ),
                            ],
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
