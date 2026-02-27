import 'package:flutter/material.dart';
import 'package:bot_creator/types/component.dart';
import 'package:bot_creator/types/variable_suggestion.dart';
import 'package:bot_creator/widgets/component_v2_builder/component_node_editor.dart';

/// Full visual editor for a ComponentV2 message (text + recursive component nodes).
/// Manages a [ComponentV2Definition] and notifies via [onChanged].
class ComponentV2EditorWidget extends StatefulWidget {
  final ComponentV2Definition definition;
  final ValueChanged<ComponentV2Definition> onChanged;
  final List<VariableSuggestion> variableSuggestions;

  const ComponentV2EditorWidget({
    super.key,
    required this.definition,
    required this.onChanged,
    required this.variableSuggestions,
  });

  @override
  State<ComponentV2EditorWidget> createState() =>
      _ComponentV2EditorWidgetState();
}

class _ComponentV2EditorWidgetState extends State<ComponentV2EditorWidget> {
  late List<ComponentNode> _components;
  late bool _ephemeral;

  @override
  void initState() {
    super.initState();
    _initFromWidget();
  }

  @override
  void didUpdateWidget(ComponentV2EditorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the external definition reference has changed, re-sync our local state
    // to prevent losing data visually when the parent redraws.
    if (widget.definition != oldWidget.definition) {
      _initFromWidget();
    }
  }

  void _initFromWidget() {
    // Deep copy components via json serialization round-trip
    _components =
        widget.definition.components
            .map((c) => ComponentNode.fromJson(c.toJson()))
            .toList();
    _ephemeral = widget.definition.ephemeral;
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _emit() {
    widget.onChanged(
      ComponentV2Definition(
        content: '',
        components:
            _components.map((c) => ComponentNode.fromJson(c.toJson())).toList(),
        ephemeral: _ephemeral,
      ),
    );
  }

  void _addNode(ComponentV2Type type) {
    ComponentNode newNode;
    switch (type) {
      case ComponentV2Type.actionRow:
        newNode = ActionRowNode();
        break;
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
      case ComponentV2Type.section:
        newNode = SectionNode(components: [TextDisplayNode()]);
        break;
      case ComponentV2Type.textDisplay:
        newNode = TextDisplayNode();
        break;
      case ComponentV2Type.thumbnail:
        newNode = ThumbnailNode();
        break;
      case ComponentV2Type.mediaGallery:
        newNode = MediaGalleryNode(items: [MediaGalleryItemNode()]);
        break;
      case ComponentV2Type.file:
        newNode = FileNode();
        break;
      case ComponentV2Type.separator:
        newNode = SeparatorNode();
        break;
      case ComponentV2Type.container:
        newNode = ContainerNode(components: [TextDisplayNode()]);
        break;
      case ComponentV2Type.label:
        newNode = LabelNode(label: 'Label', component: TextDisplayNode());
        break;
      case ComponentV2Type.fileUpload:
        newNode = FileUploadNode();
        break;
      case ComponentV2Type.radioGroup:
        newNode = RadioGroupNode(
          options: [RadioGroupOptionNode(label: 'A', value: 'a')],
        );
        break;
      case ComponentV2Type.checkboxGroup:
        newNode = CheckboxGroupNode(
          options: [CheckboxGroupOptionNode(label: 'A', value: 'a')],
        );
        break;
      case ComponentV2Type.checkbox:
        newNode = CheckboxNode();
        break;
    }
    setState(() => _components.add(newNode));
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

  String _getTitleForType(ComponentV2Type type) {
    return type.name[0].toUpperCase() +
        type.name
            .substring(1)
            .replaceAllMapped(RegExp(r'[A-Z]'), (m) => ' ${m.group(0)}');
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
            color: Colors.purple.shade50,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: Colors.purple.shade200),
          ),
          child: Row(
            children: [
              Icon(
                Icons.dashboard_customize,
                size: 18,
                color: Colors.purple.shade600,
              ),
              const SizedBox(width: 8),
              Text(
                'Full Component V2 Builder',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.purple.shade700,
                ),
              ),
              const Spacer(),
              Text(
                '${_components.length} Root Nodes',
                style: TextStyle(color: Colors.purple.shade400, fontSize: 12),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.purple.shade200),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(8),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text(
                  'Ephemeral (only visible to command user)',
                  style: TextStyle(fontSize: 13),
                ),
                value: _ephemeral,
                onChanged: (v) {
                  setState(() => _ephemeral = v);
                  _emit();
                },
              ),
              const Divider(height: 16),
              // Render root components
              ..._components.asMap().entries.map((entry) {
                final index = entry.key;
                final node = entry.value;
                return ComponentNodeEditor(
                  node: node,
                  onChanged: (updated) => _updateNode(index, updated),
                  onRemove: () => _removeNode(index),
                  variableSuggestions: widget.variableSuggestions,
                );
              }),
              const SizedBox(height: 8),
              // Add root component dropdown
              PopupMenuButton<ComponentV2Type>(
                tooltip: 'Add Root Component',
                onSelected: (v) {
                  _addNode(v);
                },
                itemBuilder: (BuildContext context) {
                  final rootTypes = [
                    ComponentV2Type.container,
                    ComponentV2Type.actionRow,
                    ComponentV2Type.section,
                    ComponentV2Type.textDisplay,
                    ComponentV2Type.mediaGallery,
                    ComponentV2Type.file,
                    ComponentV2Type.separator,
                  ];
                  return rootTypes
                      .map(
                        (t) => PopupMenuItem(
                          value: t,
                          child: Text(_getTitleForType(t)),
                        ),
                      )
                      .toList();
                },
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
                        'Add Root Component',
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
