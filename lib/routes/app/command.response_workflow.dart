import 'package:flutter/material.dart';

class CommandResponseWorkflowPage extends StatefulWidget {
  const CommandResponseWorkflowPage({
    super.key,
    required this.initialWorkflow,
    required this.variableSuggestions,
  });

  final Map<String, dynamic> initialWorkflow;
  final List<String> variableSuggestions;

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
  late TextEditingController _whenTrueController;
  late TextEditingController _whenFalseController;

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
    _whenTrueController = TextEditingController(
      text: (conditional['whenTrueText'] ?? '').toString(),
    );
    _whenFalseController = TextEditingController(
      text: (conditional['whenFalseText'] ?? '').toString(),
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
        'whenTrueText': _whenTrueController.text,
        'whenFalseText': _whenFalseController.text,
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
                          widget.variableSuggestions.take(10).map((name) {
                            return ActionChip(
                              label: Text(name),
                              onPressed: () {
                                _variableController.text = name;
                              },
                            );
                          }).toList(),
                    ),
                  const SizedBox(height: 12),
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
                  TextFormField(
                    controller: _whenFalseController,
                    maxLines: 3,
                    minLines: 1,
                    decoration: const InputDecoration(
                      labelText: 'ELSE response text (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
