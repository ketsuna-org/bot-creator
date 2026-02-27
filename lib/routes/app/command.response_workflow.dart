import 'package:flutter/material.dart';
import 'package:bot_creator/widgets/response_embeds_editor.dart';
import 'package:bot_creator/widgets/component_v2_builder/component_v2_editor.dart';
import 'package:bot_creator/widgets/component_v2_builder/normal_component_editor.dart';
import 'package:bot_creator/widgets/component_v2_builder/modal_builder.dart';
import 'package:bot_creator/types/component.dart';
import 'package:bot_creator/types/variable_suggestion.dart';

class CommandResponseWorkflowPage extends StatefulWidget {
  const CommandResponseWorkflowPage({
    super.key,
    required this.initialWorkflow,
    required this.variableSuggestions,
    this.botIdForConfig,
  });

  final Map<String, dynamic> initialWorkflow;
  final List<VariableSuggestion> variableSuggestions;
  final String? botIdForConfig;

  @override
  State<CommandResponseWorkflowPage> createState() =>
      _CommandResponseWorkflowPageState();
}

class _CommandResponseWorkflowPageState
    extends State<CommandResponseWorkflowPage> {
  late bool _autoDeferIfActions;
  late String _visibility;
  late String _onError;
  late bool _conditionEnabled;
  late TextEditingController _variableController;
  late String _whenTrueType;
  late String _whenFalseType;
  late TextEditingController _whenTrueController;
  late TextEditingController _whenFalseController;
  late List<Map<String, dynamic>> _whenTrueEmbeds;
  late List<Map<String, dynamic>> _whenFalseEmbeds;
  late Map<String, dynamic> _whenTrueNormalComponents;
  late Map<String, dynamic> _whenFalseNormalComponents;
  late Map<String, dynamic> _whenTrueComponents;
  late Map<String, dynamic> _whenFalseComponents;
  late Map<String, dynamic> _whenTrueModal;
  late Map<String, dynamic> _whenFalseModal;

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

  @override
  void initState() {
    super.initState();
    final conditional = Map<String, dynamic>.from(
      (widget.initialWorkflow['conditional'] as Map?)
              ?.cast<String, dynamic>() ??
          const {},
    );

    _autoDeferIfActions = widget.initialWorkflow['autoDeferIfActions'] != false;
    _visibility =
        (widget.initialWorkflow['visibility']?.toString().toLowerCase() ==
                'ephemeral')
            ? 'ephemeral'
            : 'public';
    _onError = 'edit_error';
    _conditionEnabled = conditional['enabled'] == true;
    _variableController = TextEditingController(
      text: (conditional['variable'] ?? '').toString(),
    );
    _whenTrueType = (conditional['whenTrueType'] ?? 'normal').toString();
    _whenFalseType = (conditional['whenFalseType'] ?? 'normal').toString();
    _whenTrueController = TextEditingController(
      text: (conditional['whenTrueText'] ?? '').toString(),
    );
    _whenFalseController = TextEditingController(
      text: (conditional['whenFalseText'] ?? '').toString(),
    );
    _whenTrueEmbeds = _normalizeEmbedsPayload(conditional['whenTrueEmbeds']);
    _whenFalseEmbeds = _normalizeEmbedsPayload(conditional['whenFalseEmbeds']);
    _whenTrueNormalComponents = Map<String, dynamic>.from(
      (conditional['whenTrueNormalComponents'] as Map?)
              ?.cast<String, dynamic>() ??
          const {},
    );
    _whenFalseNormalComponents = Map<String, dynamic>.from(
      (conditional['whenFalseNormalComponents'] as Map?)
              ?.cast<String, dynamic>() ??
          const {},
    );
    _whenTrueComponents = Map<String, dynamic>.from(
      (conditional['whenTrueComponents'] as Map?)?.cast<String, dynamic>() ??
          const {},
    );
    _whenFalseComponents = Map<String, dynamic>.from(
      (conditional['whenFalseComponents'] as Map?)?.cast<String, dynamic>() ??
          const {},
    );
    _whenTrueModal = Map<String, dynamic>.from(
      (conditional['whenTrueModal'] as Map?)?.cast<String, dynamic>() ??
          const {},
    );
    _whenFalseModal = Map<String, dynamic>.from(
      (conditional['whenFalseModal'] as Map?)?.cast<String, dynamic>() ??
          const {},
    );
  }

  @override
  void dispose() {
    _variableController.dispose();
    _whenTrueController.dispose();
    _whenFalseController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildResult() {
    return {
      'autoDeferIfActions': _autoDeferIfActions,
      'visibility': _visibility,
      'onError': _onError,
      'conditional': {
        'enabled': _conditionEnabled,
        'variable': _variableController.text.trim(),
        'whenTrueType': _whenTrueType,
        'whenFalseType': _whenFalseType,
        'whenTrueText': _whenTrueController.text,
        'whenFalseText': _whenFalseController.text,
        'whenTrueEmbeds': _whenTrueEmbeds,
        'whenFalseEmbeds': _whenFalseEmbeds,
        'whenTrueNormalComponents': _whenTrueNormalComponents,
        'whenFalseNormalComponents': _whenFalseNormalComponents,
        'whenTrueComponents': _whenTrueComponents,
        'whenFalseComponents': _whenFalseComponents,
        'whenTrueModal': _whenTrueModal,
        'whenFalseModal': _whenFalseModal,
      },
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Response Workflow'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _buildResult()),
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Deferred reply',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Auto defer if actions exist'),
                    subtitle: const Text(
                      'Acknowledge quickly, execute actions, then edit final response.',
                    ),
                    value: _autoDeferIfActions,
                    onChanged: (value) {
                      setState(() {
                        _autoDeferIfActions = value;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _visibility,
                    decoration: const InputDecoration(
                      labelText: 'Visibility',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'public', child: Text('Public')),
                      DropdownMenuItem(
                        value: 'ephemeral',
                        child: Text('Ephemeral (only command user)'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _visibility = value;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.info_outline),
                    title: Text('Error policy'),
                    subtitle: Text(
                      'When an action fails, edit the deferred message with an error.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Conditional response (MVP)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable condition'),
                    subtitle: const Text(
                      'If variable exists and is not empty => use THEN text, otherwise ELSE text.',
                    ),
                    value: _conditionEnabled,
                    onChanged: (value) {
                      setState(() {
                        _conditionEnabled = value;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _variableController,
                    decoration: const InputDecoration(
                      labelText: 'Variable key (ex: opts.userId)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (widget.variableSuggestions.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          widget.variableSuggestions.take(10).map((suggestion) {
                            return ActionChip(
                              label: Text(suggestion.name),
                              onPressed: () {
                                _variableController.text = suggestion.name;
                              },
                            );
                          }).toList(),
                    ),
                  const SizedBox(height: 16),
                  const Text(
                    'THEN Response',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'normal',
                        icon: Icon(Icons.message),
                        label: Text('Normal'),
                      ),
                      ButtonSegment(
                        value: 'componentV2',
                        icon: Icon(Icons.dashboard_customize),
                        label: Text('Component'),
                      ),
                      ButtonSegment(
                        value: 'modal',
                        icon: Icon(Icons.web_asset),
                        label: Text('Modal'),
                      ),
                    ],
                    selected: {_whenTrueType},
                    onSelectionChanged: (set) {
                      setState(() {
                        _whenTrueType = set.first;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  if (_whenTrueType == 'normal') ...[
                    TextFormField(
                      controller: _whenTrueController,
                      maxLines: 3,
                      minLines: 1,
                      decoration: const InputDecoration(
                        labelText: 'THEN response text (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ResponseEmbedsEditor(
                      embeds: _whenTrueEmbeds,
                      onChanged: (embeds) {
                        setState(() {
                          _whenTrueEmbeds = embeds;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    NormalComponentEditorWidget(
                      definition: ComponentV2Definition.fromJson(
                        _whenTrueNormalComponents,
                      ),
                      onChanged: (def) {
                        setState(() {
                          _whenTrueNormalComponents = def.toJson();
                        });
                      },
                      variableSuggestions: widget.variableSuggestions,
                    ),
                  ] else if (_whenTrueType == 'componentV2') ...[
                    ComponentV2EditorWidget(
                      definition: ComponentV2Definition.fromJson(
                        _whenTrueComponents,
                      ),
                      onChanged: (def) {
                        setState(() {
                          _whenTrueComponents = def.toJson();
                        });
                      },
                      variableSuggestions: widget.variableSuggestions,
                    ),
                  ] else if (_whenTrueType == 'modal') ...[
                    ModalBuilderWidget(
                      modal: ModalDefinition.fromJson(_whenTrueModal),
                      onChanged: (def) {
                        setState(() {
                          _whenTrueModal = def.toJson();
                        });
                      },
                      variableSuggestions: widget.variableSuggestions,
                      botIdForConfig: widget.botIdForConfig,
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text(
                    'ELSE Response',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'normal',
                        icon: Icon(Icons.message),
                        label: Text('Normal'),
                      ),
                      ButtonSegment(
                        value: 'componentV2',
                        icon: Icon(Icons.dashboard_customize),
                        label: Text('Component'),
                      ),
                      ButtonSegment(
                        value: 'modal',
                        icon: Icon(Icons.web_asset),
                        label: Text('Modal'),
                      ),
                    ],
                    selected: {_whenFalseType},
                    onSelectionChanged: (set) {
                      setState(() {
                        _whenFalseType = set.first;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  if (_whenFalseType == 'normal') ...[
                    TextFormField(
                      controller: _whenFalseController,
                      maxLines: 3,
                      minLines: 1,
                      decoration: const InputDecoration(
                        labelText: 'ELSE response text (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ResponseEmbedsEditor(
                      embeds: _whenFalseEmbeds,
                      onChanged: (embeds) {
                        setState(() {
                          _whenFalseEmbeds = embeds;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    NormalComponentEditorWidget(
                      definition: ComponentV2Definition.fromJson(
                        _whenFalseNormalComponents,
                      ),
                      onChanged: (def) {
                        setState(() {
                          _whenFalseNormalComponents = def.toJson();
                        });
                      },
                      variableSuggestions: widget.variableSuggestions,
                    ),
                  ] else if (_whenFalseType == 'componentV2') ...[
                    ComponentV2EditorWidget(
                      definition: ComponentV2Definition.fromJson(
                        _whenFalseComponents,
                      ),
                      onChanged: (def) {
                        setState(() {
                          _whenFalseComponents = def.toJson();
                        });
                      },
                      variableSuggestions: widget.variableSuggestions,
                    ),
                  ] else if (_whenFalseType == 'modal') ...[
                    ModalBuilderWidget(
                      modal: ModalDefinition.fromJson(_whenFalseModal),
                      onChanged: (def) {
                        setState(() {
                          _whenFalseModal = def.toJson();
                        });
                      },
                      variableSuggestions: widget.variableSuggestions,
                      botIdForConfig: widget.botIdForConfig,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
