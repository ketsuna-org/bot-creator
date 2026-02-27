import 'package:flutter/material.dart';
import 'package:bot_creator/types/component.dart';
import 'package:bot_creator/types/variable_suggestion.dart';
import 'package:bot_creator/widgets/component_v2_builder/component_node_editor.dart';

/// Visual editor for traditional "normal" message components (only ActionRows containing Buttons/Selects).
/// Manages a [ComponentV2Definition] but strictly limits available types.
class NormalComponentEditorWidget extends StatefulWidget {
  final ComponentV2Definition definition;
  final ValueChanged<ComponentV2Definition> onChanged;
  final List<VariableSuggestion> variableSuggestions;

  const NormalComponentEditorWidget({
    super.key,
    required this.definition,
    required this.onChanged,
    required this.variableSuggestions,
  });

  @override
  State<NormalComponentEditorWidget> createState() =>
      _NormalComponentEditorWidgetState();
}

class _NormalComponentEditorWidgetState
    extends State<NormalComponentEditorWidget> {
  late List<ComponentNode> _components;

  @override
  void initState() {
    super.initState();
    _initFromWidget();
  }

  @override
  void didUpdateWidget(NormalComponentEditorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.definition != oldWidget.definition) {
      _initFromWidget();
    }
  }

  void _initFromWidget() {
    // Deep copy components via json serialization round-trip
    _components =
        widget.definition.components
            .map((c) => ComponentNode.fromJson(c.toJson()))
            // Ensure we strictly keep only ActionRows at root level
            .whereType<ActionRowNode>()
            .toList();
  }

  void _emit() {
    widget.onChanged(
      ComponentV2Definition(
        content: widget.definition.content,
        components:
            _components.map((c) => ComponentNode.fromJson(c.toJson())).toList(),
        ephemeral: widget.definition.ephemeral,
      ),
    );
  }

  void _addNode() {
    if (_components.length >= 5) {
      return; // Discord limit: max 5 Action Rows per message
    }
    setState(() => _components.add(ActionRowNode()));
    _emit();
  }

  void _removeNode(int index) {
    setState(() => _components.removeAt(index));
    _emit();
  }

  void _updateNode(int index, ComponentNode updated) {
    setState(() {
      _components[index] = updated;
    });
    _emit();
  }

  // A custom locked-down ActionRow editor for "Normal" message components.
  // It only allows Button and Select Menus inside the rows.
  Widget _buildNormalActionRowEditor(ActionRowNode row, int index) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.blueGrey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.view_stream, size: 16, color: Colors.blueGrey),
                const SizedBox(width: 8),
                const Text(
                  'Action Row',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                  onPressed: () => _removeNode(index),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...row.components.asMap().entries.map((e) {
                  final childIdx = e.key;
                  final child = e.value;
                  return ComponentNodeEditor(
                    node: child,
                    onChanged: (updated) {
                      final newChildren = List<ComponentNode>.from(
                        row.components,
                      );
                      newChildren[childIdx] = updated;
                      row.components = newChildren;
                      _updateNode(index, row);
                    },
                    onRemove: () {
                      final newChildren = List<ComponentNode>.from(
                        row.components,
                      )..removeAt(childIdx);
                      row.components = newChildren;
                      _updateNode(index, row);
                    },
                    variableSuggestions: widget.variableSuggestions,
                  );
                }),
                Builder(
                  builder: (context) {
                    final components = row.components;
                    final buttonCount =
                        components.whereType<ButtonNode>().length;
                    final hasSelect = components.any(
                      (c) => c is SelectMenuNode,
                    );

                    List<ComponentV2Type>? allowedTypes;
                    if (hasSelect) {
                      allowedTypes = [];
                    } else if (buttonCount > 0) {
                      if (buttonCount < 5) {
                        allowedTypes = [ComponentV2Type.button];
                      } else {
                        allowedTypes = [];
                      }
                    } else {
                      allowedTypes = [
                        ComponentV2Type.button,
                        ComponentV2Type.stringSelect,
                        ComponentV2Type.userSelect,
                        ComponentV2Type.roleSelect,
                        ComponentV2Type.mentionableSelect,
                        ComponentV2Type.channelSelect,
                      ];
                    }

                    if (allowedTypes.isEmpty) return const SizedBox.shrink();

                    return _buildAddComponentDropdown((newNode) {
                      row.components = [...row.components, newNode];
                      _updateNode(index, row);
                    }, allowedTypes: allowedTypes);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddComponentDropdown(
    ValueChanged<ComponentNode> onAdd, {
    List<ComponentV2Type>? allowedTypes,
  }) {
    final types =
        allowedTypes ??
        [
          ComponentV2Type.button,
          ComponentV2Type.stringSelect,
          ComponentV2Type.userSelect,
          ComponentV2Type.roleSelect,
          ComponentV2Type.mentionableSelect,
          ComponentV2Type.channelSelect,
        ];
    return PopupMenuButton<ComponentV2Type>(
      tooltip: 'Add Component',
      onSelected: (type) {
        ComponentNode newNode;
        switch (type) {
          case ComponentV2Type.button:
            newNode = ButtonNode();
            break;
          case ComponentV2Type.stringSelect:
            newNode = SelectMenuNode(
              type: ComponentV2Type.stringSelect,
              options: [SelectMenuOption(label: 'Hi', value: 'hi')],
            );
            break;
          case ComponentV2Type.userSelect:
            newNode = SelectMenuNode(type: ComponentV2Type.userSelect);
            break;
          case ComponentV2Type.roleSelect:
            newNode = SelectMenuNode(type: ComponentV2Type.roleSelect);
            break;
          case ComponentV2Type.mentionableSelect:
            newNode = SelectMenuNode(type: ComponentV2Type.mentionableSelect);
            break;
          case ComponentV2Type.channelSelect:
            newNode = SelectMenuNode(type: ComponentV2Type.channelSelect);
            break;
          default:
            return;
        }
        onAdd(newNode);
      },
      itemBuilder: (context) {
        return types
            .map(
              (t) => PopupMenuItem(
                value: t,
                child: Text(
                  t.name[0].toUpperCase() +
                      t.name
                          .substring(1)
                          .replaceAllMapped(
                            RegExp(r'[A-Z]'),
                            (m) => ' ${m.group(0)}',
                          ),
                ),
              ),
            )
            .toList();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.blueGrey.shade100, width: 2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, size: 16, color: Colors.blueGrey),
            SizedBox(width: 8),
            Text(
              'Add Button / Select Menu',
              style: TextStyle(
                color: Colors.blueGrey,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(
                Icons.dashboard_customize,
                size: 18,
                color: Colors.blue.shade600,
              ),
              const SizedBox(width: 8),
              Text(
                'Message Components',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
              const Spacer(),
              Text(
                '${_components.length}/5 Action Rows',
                style: TextStyle(color: Colors.blue.shade400, fontSize: 12),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.blue.shade200),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(8),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ..._components.asMap().entries.map((entry) {
                final index = entry.key;
                final node = entry.value as ActionRowNode;
                return _buildNormalActionRowEditor(node, index);
              }),
              const SizedBox(height: 8),
              if (_components.length < 5)
                InkWell(
                  onTap: _addNode,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blueGrey.shade300),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.add, size: 16, color: Colors.blueGrey),
                        SizedBox(width: 8),
                        Text(
                          'Add Action Row',
                          style: TextStyle(
                            color: Colors.blueGrey,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
