import 'package:flutter/material.dart';
import 'package:bot_creator/types/component.dart';

/// Widget for editing a full Modal definition (title, customId, text inputs).
class ModalBuilderWidget extends StatefulWidget {
  final ModalDefinition modal;
  final ValueChanged<ModalDefinition> onChanged;

  const ModalBuilderWidget({
    super.key,
    required this.modal,
    required this.onChanged,
  });

  @override
  State<ModalBuilderWidget> createState() => _ModalBuilderWidgetState();
}

class _ModalBuilderWidgetState extends State<ModalBuilderWidget> {
  late TextEditingController _titleCtrl;
  late TextEditingController _customIdCtrl;
  late List<ModalTextInputDefinition> _inputs;

  @override
  void initState() {
    super.initState();
    _initFromWidget();
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
      _inputs = List.from(widget.modal.inputs);
    }
  }

  void _initFromWidget() {
    _titleCtrl = TextEditingController(text: widget.modal.title);
    _customIdCtrl = TextEditingController(text: widget.modal.customId);
    _inputs = List.from(widget.modal.inputs);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _customIdCtrl.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChanged(
      ModalDefinition(
        title: _titleCtrl.text,
        customId: _customIdCtrl.text,
        inputs: List.from(_inputs),
      ),
    );
  }

  void _addInput() {
    if (_inputs.length >= 5) return;
    setState(() {
      _inputs.add(
        ModalTextInputDefinition(
          customId: 'field_${_inputs.length + 1}',
          label: 'Field ${_inputs.length + 1}',
        ),
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
                    child: TextFormField(
                      controller: _titleCtrl,
                      maxLength: 45,
                      decoration: const InputDecoration(
                        labelText: 'Modal Title',
                        border: OutlineInputBorder(),
                        isDense: true,
                        counterText: '',
                      ),
                      onChanged: (_) => _emit(),
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
              // Inputs list
              ..._inputs.asMap().entries.map((entry) {
                final index = entry.key;
                final input = entry.value;
                return _buildInputTile(index, input);
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

  Widget _buildInputTile(int index, ModalTextInputDefinition input) {
    final customIdCtrl = TextEditingController(text: input.customId);
    final labelCtrl = TextEditingController(text: input.label);
    final placeholderCtrl = TextEditingController(text: input.placeholder);
    final defaultValCtrl = TextEditingController(text: input.defaultValue);

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
                  input.label.isEmpty ? 'Input ${index + 1}' : input.label,
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
                        input.style.name,
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
                      onPressed: () => _removeInput(index),
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
                    controller: labelCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Label',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) {
                      _updateInput(
                        index,
                        ModalTextInputDefinition(
                          customId: input.customId,
                          label: v,
                          style: input.style,
                          placeholder: input.placeholder,
                          defaultValue: input.defaultValue,
                          required: input.required,
                          minLength: input.minLength,
                          maxLength: input.maxLength,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: customIdCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Custom ID',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) {
                      _updateInput(
                        index,
                        ModalTextInputDefinition(
                          customId: v,
                          label: input.label,
                          style: input.style,
                          placeholder: input.placeholder,
                          defaultValue: input.defaultValue,
                          required: input.required,
                          minLength: input.minLength,
                          maxLength: input.maxLength,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: placeholderCtrl,
              decoration: const InputDecoration(
                labelText: 'Placeholder',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) {
                _updateInput(
                  index,
                  ModalTextInputDefinition(
                    customId: input.customId,
                    label: input.label,
                    style: input.style,
                    placeholder: v,
                    defaultValue: input.defaultValue,
                    required: input.required,
                    minLength: input.minLength,
                    maxLength: input.maxLength,
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: defaultValCtrl,
              decoration: const InputDecoration(
                labelText: 'Default value',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) {
                _updateInput(
                  index,
                  ModalTextInputDefinition(
                    customId: input.customId,
                    label: input.label,
                    style: input.style,
                    placeholder: input.placeholder,
                    defaultValue: v,
                    required: input.required,
                    minLength: input.minLength,
                    maxLength: input.maxLength,
                  ),
                );
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
                                  selected: input.style == style,
                                  onSelected: (_) {
                                    _updateInput(
                                      index,
                                      ModalTextInputDefinition(
                                        customId: input.customId,
                                        label: input.label,
                                        style: style,
                                        placeholder: input.placeholder,
                                        defaultValue: input.defaultValue,
                                        required: input.required,
                                        minLength: input.minLength,
                                        maxLength: input.maxLength,
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
                      value: input.required,
                      onChanged: (v) {
                        _updateInput(
                          index,
                          ModalTextInputDefinition(
                            customId: input.customId,
                            label: input.label,
                            style: input.style,
                            placeholder: input.placeholder,
                            defaultValue: input.defaultValue,
                            required: v,
                            minLength: input.minLength,
                            maxLength: input.maxLength,
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
