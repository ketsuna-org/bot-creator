import 'package:bot_creator/main.dart';
import 'package:bot_creator/routes/app/builder.response.dart';
import 'package:bot_creator/utils/bot.dart';
import 'package:bot_creator/utils/analytics.dart';
import 'package:bot_creator/widgets/option_widget.dart';
import 'package:bot_creator/widgets/command_create_cards/basic_info_card.dart';
import 'package:bot_creator/widgets/command_create_cards/reply_card.dart';
import 'package:bot_creator/widgets/command_create_cards/actions_card.dart';
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
  String _commandName = "";
  String _commandDescription = "";
  List<CommandOptionBuilder> _options = [];
  String _response = "";
  final TextEditingController _responseController = TextEditingController();
  List<Map<String, dynamic>> _responseEmbeds = [];
  List<Map<String, dynamic>> _actions = [];
  Map<String, dynamic> _responseWorkflow = _defaultWorkflow();
  bool _isLoading = true;
  List<ApplicationIntegrationType> _integrationTypes = [
    ApplicationIntegrationType.guildInstall,
  ];
  List<InteractionContextType> _contexts = [InteractionContextType.guild];

  static Map<String, dynamic> _defaultWorkflow() {
    return {
      'autoDeferIfActions': true,
      'visibility': 'public',
      'onError': 'edit_error',
      'conditional': {
        'enabled': false,
        'variable': '',
        'whenTrueText': '',
        'whenFalseText': '',
        'whenTrueEmbeds': <Map<String, dynamic>>[],
        'whenFalseEmbeds': <Map<String, dynamic>>[],
      },
    };
  }

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
        'whenTrueText': (conditional['whenTrueText'] ?? '').toString(),
        'whenFalseText': (conditional['whenFalseText'] ?? '').toString(),
        'whenTrueEmbeds': _normalizeEmbedsPayload(
          conditional['whenTrueEmbeds'],
        ),
        'whenFalseEmbeds': _normalizeEmbedsPayload(
          conditional['whenFalseEmbeds'],
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
          _response = (response["text"] ?? "").toString();
          _responseController.text = _response;
          _responseEmbeds = embeds.take(10).toList();
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
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateOrCreate() async {
    // check if any field is empty
    if (_commandName.isEmpty || _commandDescription.isEmpty) {
      final dialog = AlertDialog(
        title: const Text("Error"),
        content: const Text("Please fill all fields"),
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
      return;
    }

    final commandData = {
      "version": 1,
      "response": {
        "mode": _responseEmbeds.isNotEmpty ? "embed" : "text",
        "text": _responseController.text,
        "embed":
            _responseEmbeds.isNotEmpty
                ? _responseEmbeds.first
                : {"title": "", "description": "", "url": ""},
        "embeds": _responseEmbeds.take(10).toList(),
        "workflow": _normalizeWorkflow(_responseWorkflow),
      },
      "actions": _actions,
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

        commandBuilder.integrationTypes = _integrationTypes;
        if (_contexts.isNotEmpty) {
          commandBuilder.contexts = _contexts;
        }
        if (_options.isNotEmpty) {
          commandBuilder.options = _options;
        }
        await createCommand(client, commandBuilder, data: commandData);
      } else {
        // Update the existing command
        final commandBuilder = ApplicationCommandUpdateBuilder(
          name: _commandName,
          description: _commandDescription,
        );
        commandBuilder.integrationTypes = _integrationTypes;
        if (_contexts.isNotEmpty) {
          commandBuilder.contexts = _contexts;
        } else {
          commandBuilder.contexts = [];
        }
        if (_options.isNotEmpty) {
          commandBuilder.options = _options;
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

  List<String> get _variableNames {
    final base = _argsList
        .map((e) => e['name'])
        .whereType<String>()
        .toList(growable: true);

    for (final option in _options) {
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

    for (var i = 0; i < _actions.length; i++) {
      final action = _actions[i];
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

    for (final option in _options) {
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

    for (var i = 0; i < _actions.length; i++) {
      final action = _actions[i];
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
                    title: const Text("Command Variables"),
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
            tooltip: "Show variables",
            icon: const Icon(Icons.info_outline),
          ),
          if (widget.id.isZero)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: "Create command",
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  _updateOrCreate();
                  // Form is valid, proceed with command creation
                } else {
                  // Form is invalid, show error message
                  final dialog = AlertDialog(
                    title: const Text("Error"),
                    content: const Text("Please fill all fields"),
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
                // Handle add action
                // You can implement the logic to add a new command here
              },
            ),
          IconButton(
            icon: Icon(
              widget.id.isZero ? Icons.cancel : Icons.save,
            ), // Change icon based on command existence
            tooltip: widget.id.isZero ? "Cancel" : "Save command",
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
                    title: const Text("Error"),
                    content: const Text("Please fill all fields"),
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
                // You can implement the logic to save the command here
              }
            },
          ),
          if (!widget.id.isZero)
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: "Delete command",
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
                              nameValidator: _validateName,
                            ),
                            const SizedBox(height: 12),
                            ReplyCard(
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
                              responseWorkflow: _responseWorkflow,
                              normalizeWorkflow: _normalizeWorkflow,
                              variableNames: _variableNames,
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
