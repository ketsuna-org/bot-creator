import 'package:flutter/material.dart';
import 'package:bot_creator/main.dart';
import 'package:bot_creator/types/component.dart';
import 'package:bot_creator/types/variable_suggestion.dart';
import 'package:bot_creator/routes/app/workflows.page.dart';
import 'package:bot_creator/widgets/variable_text_field.dart';

/// Widget for editing a full Modal definition (title, customId, text inputs).
class ModalBuilderWidget extends StatefulWidget {
  final ModalDefinition modal;
  final ValueChanged<ModalDefinition> onChanged;
  final List<VariableSuggestion> variableSuggestions;
  final String? botIdForConfig;

  const ModalBuilderWidget({
    super.key,
    required this.modal,
    required this.onChanged,
    required this.variableSuggestions,
    this.botIdForConfig,
  });

  @override
  State<ModalBuilderWidget> createState() => _ModalBuilderWidgetState();
}

class _ModalBuilderWidgetState extends State<ModalBuilderWidget> {
  late TextEditingController _titleCtrl;
  late TextEditingController _customIdCtrl;
  late TextEditingController _onWorkflowCtrl;
  late List<ModalTextInputDefinition> _inputs;
  List<String> _availableWorkflowNames = const [];
  bool _loadingWorkflows = false;

  @override
  void initState() {
    super.initState();
    _initFromWidget();
    _loadAvailableWorkflows();
  }

  @override
  void didUpdateWidget(ModalBuilderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.modal != oldWidget.modal) {
      if (_titleCtrl.text != widget.modal.title) {
        _titleCtrl.text = widget.modal.title;
      }
      if (_customIdCtrl.text != widget.modal.customId) {
        _customIdCtrl.text = widget.modal.customId;
      }
      if (_onWorkflowCtrl.text != (widget.modal.onSubmitWorkflow ?? '')) {
        _onWorkflowCtrl.text = widget.modal.onSubmitWorkflow ?? '';
      }
      _inputs = List.from(widget.modal.inputs);
    }
    if (widget.botIdForConfig != oldWidget.botIdForConfig) {
      _loadAvailableWorkflows();
    }
  }

  void _initFromWidget() {
    _titleCtrl = TextEditingController(text: widget.modal.title);
    _customIdCtrl = TextEditingController(text: widget.modal.customId);
    _onWorkflowCtrl = TextEditingController(
      text: widget.modal.onSubmitWorkflow ?? '',
    );
    _inputs = List.from(widget.modal.inputs);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _customIdCtrl.dispose();
    _onWorkflowCtrl.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChanged(
      ModalDefinition(
        title: _titleCtrl.text,
        customId: _customIdCtrl.text,
        inputs: List.from(_inputs),
        onSubmitWorkflow:
            _onWorkflowCtrl.text.trim().isEmpty
                ? null
                : _onWorkflowCtrl.text.trim(),
      ),
    );
  }

  void _addInput() {
    if (_inputs.length >= 5) return;
    setState(() {
      _inputs.add(
        ModalTextInputDefinition(label: 'Field ${_inputs.length + 1}'),
      );
    });
    _emit();
  }

  void _removeInput(int index) {
    setState(() => _inputs.removeAt(index));
    _emit();
  }

  void _updateInput(int index, ModalTextInputDefinition updated) {
    setState(() => _inputs[index] = updated);
    _emit();
  }

  Future<void> _loadAvailableWorkflows() async {
    final botId = widget.botIdForConfig;
    if (botId == null || botId.trim().isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _availableWorkflowNames = const [];
        _loadingWorkflows = false;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _loadingWorkflows = true;
      });
    }

    final workflows = await appManager.getWorkflows(botId);
    if (!mounted) {
      return;
    }

    final names = workflows
        .map((workflow) => (workflow['name'] ?? '').toString().trim())
        .where((name) => name.isNotEmpty)
        .toList(growable: false)
      ..sort();

    setState(() {
      _availableWorkflowNames = names;
      _loadingWorkflows = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.indigo.shade50,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: Colors.indigo.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.dynamic_form, color: Colors.indigo.shade600, size: 18),
              const SizedBox(width: 8),
              Text(
                'Modal Builder',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo.shade700,
                ),
              ),
              const Spacer(),
              Text(
                '${_inputs.length}/5 inputs',
                style: TextStyle(color: Colors.indigo.shade400, fontSize: 12),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.indigo.shade200),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(8),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title & customId
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: VariableTextField(
                      label: 'Modal Title',
                      initialValue: widget.modal.title,
                      suggestions: widget.variableSuggestions,
                      onChanged: (v) {
                        _titleCtrl.text = v;
                        _emit();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _customIdCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Custom ID',
                        border: OutlineInputBorder(),
                        isDense: true,
                        helperText: 'Used to identify this modal',
                      ),
                      onChanged: (_) => _emit(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (widget.botIdForConfig != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue:
                            _onWorkflowCtrl.text.trim().isEmpty
                                ? null
                                : (_availableWorkflowNames.contains(
                                  _onWorkflowCtrl.text.trim(),
                                )
                                ? _onWorkflowCtrl.text.trim()
                                : null),
                        isExpanded: true,
                        items:
                            _availableWorkflowNames
                                .map(
                                  (name) => DropdownMenuItem<String>(
                                    value: name,
                                    child: Text(name),
                                  ),
                                )
                                .toList(),
                        onChanged:
                            _loadingWorkflows
                                ? null
                                : (value) {
                                  setState(() {
                                    _onWorkflowCtrl.text = (value ?? '').trim();
                                  });
                                  _emit();
                                },
                        decoration: InputDecoration(
                          labelText: 'Workflow to run on submit (optional)',
                          border: const OutlineInputBorder(),
                          isDense: true,
                          helperText:
                              _loadingWorkflows
                                  ? 'Loading workflows...'
                                  : (_availableWorkflowNames.isEmpty
                                      ? 'No saved workflows found'
                                      : 'Select a saved workflow'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Refresh workflows',
                      onPressed: _loadingWorkflows ? null : _loadAvailableWorkflows,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ] else ...[
                VariableTextField(
                  label: 'Workflow to run on submit (optional)',
                  initialValue: widget.modal.onSubmitWorkflow ?? '',
                  hint: 'e.g. handle_form_submit',
                  suggestions: widget.variableSuggestions,
                  onChanged: (v) {
                    _onWorkflowCtrl.text = v;
                    _emit();
                  },
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed:
                        widget.botIdForConfig == null
                            ? null
                            : () async {
                              final botId = widget.botIdForConfig;
                              if (botId == null) {
                                return;
                              }
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => WorkflowsPage(botId: botId),
                                ),
                              );
                              await _loadAvailableWorkflows();
                            },
                    icon: const Icon(Icons.account_tree),
                    label: const Text('Manage Workflows'),
                  ),
                ],
              ),
              if (_onWorkflowCtrl.text.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: Colors.green.shade700,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'On submit, the workflow "${_onWorkflowCtrl.text.trim()}" will be executed.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Note: If no workflow is selected, submitting this modal will do nothing.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              // Inputs list
              ..._inputs.asMap().entries.map((entry) {
                final index = entry.key;
                final input = entry.value;
                return _ModalTextInputTile(
                  key: ValueKey(
                    input.customId,
                  ), // Critical for preserving state
                  index: index,
                  input: input,
                  onChanged: (updated) => _updateInput(index, updated),
                  onRemove: () => _removeInput(index),
                  variableSuggestions: widget.variableSuggestions,
                );
              }),
              // Add input button
              if (_inputs.length < 5)
                TextButton.icon(
                  onPressed: _addInput,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Text Input'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ModalTextInputTile extends StatefulWidget {
  final int index;
  final ModalTextInputDefinition input;
  final ValueChanged<ModalTextInputDefinition> onChanged;
  final VoidCallback onRemove;
  final List<VariableSuggestion> variableSuggestions;

  const _ModalTextInputTile({
    super.key,
    required this.index,
    required this.input,
    required this.onChanged,
    required this.onRemove,
    required this.variableSuggestions,
  });

  @override
  State<_ModalTextInputTile> createState() => _ModalTextInputTileState();
}

class _ModalTextInputTileState extends State<_ModalTextInputTile> {
  late TextEditingController _customIdCtrl;
  late TextEditingController _labelCtrl;
  late TextEditingController _placeholderCtrl;
  late TextEditingController _defaultValCtrl;

  @override
  void initState() {
    super.initState();
    _customIdCtrl = TextEditingController(text: widget.input.customId);
    _labelCtrl = TextEditingController(text: widget.input.label);
    _placeholderCtrl = TextEditingController(text: widget.input.placeholder);
    _defaultValCtrl = TextEditingController(text: widget.input.defaultValue);
  }

  @override
  void didUpdateWidget(_ModalTextInputTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.input.customId != oldWidget.input.customId &&
        _customIdCtrl.text != widget.input.customId) {
      _customIdCtrl.text = widget.input.customId;
    }
    if (widget.input.label != oldWidget.input.label &&
        _labelCtrl.text != widget.input.label) {
      _labelCtrl.text = widget.input.label;
    }
    if (widget.input.placeholder != oldWidget.input.placeholder &&
        _placeholderCtrl.text != widget.input.placeholder) {
      _placeholderCtrl.text = widget.input.placeholder;
    }
    if (widget.input.defaultValue != oldWidget.input.defaultValue &&
        _defaultValCtrl.text != widget.input.defaultValue) {
      _defaultValCtrl.text = widget.input.defaultValue;
    }
  }

  @override
  void dispose() {
    _customIdCtrl.dispose();
    _labelCtrl.dispose();
    _placeholderCtrl.dispose();
    _defaultValCtrl.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChanged(
      ModalTextInputDefinition(
        customId: _customIdCtrl.text,
        label: _labelCtrl.text,
        style: widget.input.style,
        placeholder: _placeholderCtrl.text,
        defaultValue: _defaultValCtrl.text,
        required: widget.input.required,
        minLength: widget.input.minLength,
        maxLength: widget.input.maxLength,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.input.label.isEmpty
                      ? 'Input ${widget.index + 1}'
                      : widget.input.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Chip(
                      label: Text(
                        widget.input.style.name,
                        style: const TextStyle(fontSize: 11),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete,
                        size: 16,
                        color: Colors.red,
                      ),
                      onPressed: widget.onRemove,
                    ),
                  ],
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _labelCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Label',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) => _emit(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _customIdCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Custom ID',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) => _emit(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _placeholderCtrl,
              decoration: const InputDecoration(
                labelText: 'Placeholder',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => _emit(),
            ),
            const SizedBox(height: 8),
            VariableTextField(
              label: 'Default value',
              initialValue: widget.input.defaultValue,
              suggestions: widget.variableSuggestions,
              onChanged: (v) {
                _defaultValCtrl.text = v;
                _emit();
              },
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                // Style picker
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Style:', style: TextStyle(fontSize: 12)),
                      Row(
                        children:
                            BcTextInputStyle.values.map((style) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: FilterChip(
                                  label: Text(
                                    style.name,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  selected: widget.input.style == style,
                                  onSelected: (_) {
                                    widget.onChanged(
                                      ModalTextInputDefinition(
                                        customId: _customIdCtrl.text,
                                        label: _labelCtrl.text,
                                        style: style,
                                        placeholder: _placeholderCtrl.text,
                                        defaultValue: _defaultValCtrl.text,
                                        required: widget.input.required,
                                        minLength: widget.input.minLength,
                                        maxLength: widget.input.maxLength,
                                      ),
                                    );
                                  },
                                ),
                              );
                            }).toList(),
                      ),
                    ],
                  ),
                ),
                // Required toggle
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Required', style: TextStyle(fontSize: 12)),
                    Switch(
                      value: widget.input.required,
                      onChanged: (v) {
                        widget.onChanged(
                          ModalTextInputDefinition(
                            customId: _customIdCtrl.text,
                            label: _labelCtrl.text,
                            style: widget.input.style,
                            placeholder: _placeholderCtrl.text,
                            defaultValue: _defaultValCtrl.text,
                            required: v,
                            minLength: widget.input.minLength,
                            maxLength: widget.input.maxLength,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
