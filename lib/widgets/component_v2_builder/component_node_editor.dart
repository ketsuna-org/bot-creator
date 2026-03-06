import 'package:flutter/material.dart';
import 'package:bot_creator/main.dart';
import 'package:bot_creator/routes/app/workflows.page.dart';
import 'package:bot_creator/types/component.dart';
import 'package:bot_creator/types/variable_suggestion.dart';
import 'dart:convert';
import 'package:bot_creator/widgets/variable_text_field.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class ComponentNodeEditor extends StatelessWidget {
  final ComponentNode node;
  final ValueChanged<ComponentNode> onChanged;
  final VoidCallback onRemove;
  final List<VariableSuggestion> variableSuggestions;
  final String? botIdForConfig;

  const ComponentNodeEditor({
    super.key,
    required this.node,
    required this.onChanged,
    required this.onRemove,
    required this.variableSuggestions,
    this.botIdForConfig,
  });

  @override
  Widget build(BuildContext context) {
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
                Icon(
                  _getIconForType(node.type),
                  size: 16,
                  color: Colors.blueGrey,
                ),
                const SizedBox(width: 8),
                Text(
                  _getTitleForType(node.type),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                  onPressed: onRemove,
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildEditorBody(context),
          ],
        ),
      ),
    );
  }

  IconData _getIconForType(ComponentV2Type type) {
    return switch (type) {
      ComponentV2Type.actionRow => Icons.view_stream,
      ComponentV2Type.button => Icons.smart_button,
      ComponentV2Type.stringSelect => Icons.list,
      ComponentV2Type.userSelect => Icons.person,
      ComponentV2Type.roleSelect => Icons.admin_panel_settings,
      ComponentV2Type.mentionableSelect => Icons.alternate_email,
      ComponentV2Type.channelSelect => Icons.tag,
      ComponentV2Type.section => Icons.view_agenda,
      ComponentV2Type.textDisplay => Icons.text_fields,
      ComponentV2Type.thumbnail => Icons.image,
      ComponentV2Type.mediaGallery => Icons.photo_library,
      ComponentV2Type.file => Icons.insert_drive_file,
      ComponentV2Type.separator => Icons.horizontal_rule,
      ComponentV2Type.container => Icons.aspect_ratio,
      ComponentV2Type.label => Icons.label,
      ComponentV2Type.fileUpload => Icons.upload_file,
      ComponentV2Type.radioGroup => Icons.radio_button_checked,
      ComponentV2Type.checkboxGroup => Icons.check_box,
      ComponentV2Type.checkbox => Icons.check_box_outline_blank,
    };
  }

  String _getTitleForType(ComponentV2Type type) {
    return type.name[0].toUpperCase() +
        type.name
            .substring(1)
            .replaceAllMapped(RegExp(r'[A-Z]'), (m) => ' ${m.group(0)}');
  }

  Widget _buildEditorBody(BuildContext context) {
    if (node is ActionRowNode) {
      return _buildActionRowEditor(node as ActionRowNode);
    }
    if (node is ButtonNode) return _buildButtonEditor(node as ButtonNode);
    if (node is SelectMenuNode) {
      return _buildSelectMenuEditor(node as SelectMenuNode);
    }
    if (node is TextDisplayNode) {
      return _buildTextDisplayEditor(node as TextDisplayNode);
    }
    if (node is SeparatorNode) {
      return _buildSeparatorEditor(node as SeparatorNode);
    }
    if (node is SectionNode) return _buildSectionEditor(node as SectionNode);
    if (node is ContainerNode) {
      return _buildContainerEditor(node as ContainerNode, context);
    }
    if (node is LabelNode) return _buildLabelEditor(node as LabelNode);
    if (node is CheckboxNode) return _buildCheckboxEditor(node as CheckboxNode);
    if (node is RadioGroupNode) {
      return _buildRadioGroupEditor(node as RadioGroupNode);
    }
    if (node is CheckboxGroupNode) {
      return _buildCheckboxGroupEditor(node as CheckboxGroupNode);
    }
    if (node is FileUploadNode) {
      return _buildFileUploadEditor(node as FileUploadNode);
    }
    if (node is FileNode) return _buildFileEditor(node as FileNode);
    if (node is ThumbnailNode) {
      return _buildThumbnailEditor(node as ThumbnailNode);
    }
    if (node is MediaGalleryNode) {
      return _buildMediaGalleryEditor(node as MediaGalleryNode);
    }
    return const Text('Editor not implemented yet');
  }

  Widget _buildResponsiveTwoFieldRow({
    required Widget first,
    required Widget second,
    int firstFlex = 1,
    int secondFlex = 1,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 520;
        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [first, const SizedBox(height: 8), second],
          );
        }

        return Row(
          children: [
            Expanded(flex: firstFlex, child: first),
            const SizedBox(width: 8),
            Expanded(flex: secondFlex, child: second),
          ],
        );
      },
    );
  }

  // --- Node Editors ---

  Widget _buildActionRowEditor(ActionRowNode row) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...row.components.asMap().entries.map((e) {
          final idx = e.key;
          final child = e.value;
          return ComponentNodeEditor(
            node: child,
            onChanged: (updated) {
              final newChildren = List<ComponentNode>.from(row.components);
              newChildren[idx] = updated;
              row.components = newChildren;
              onChanged(row);
            },
            onRemove: () {
              final newChildren = List<ComponentNode>.from(row.components)
                ..removeAt(idx);
              row.components = newChildren;
              onChanged(row);
            },
            variableSuggestions: variableSuggestions,
            botIdForConfig: botIdForConfig,
          );
        }),
        const SizedBox(height: 8),
        Builder(
          builder: (context) {
            final components = row.components;
            final buttonCount = components.whereType<ButtonNode>().length;
            final hasSelect = components.any((c) => c is SelectMenuNode);

            List<ComponentV2Type>? allowedTypes;
            if (hasSelect) {
              allowedTypes = []; // No more components allowed
            } else if (buttonCount > 0) {
              if (buttonCount < 5) {
                allowedTypes = [ComponentV2Type.button];
              } else {
                allowedTypes = []; // Max buttons reached
              }
            } else {
              // Empty or other? (Discord V1 Action Row should only have these)
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
              onChanged(row);
            }, allowedTypes: allowedTypes);
          },
        ),
      ],
    );
  }

  Widget _buildButtonEditor(ButtonNode btn) {
    return Column(
      children: [
        _buildResponsiveTwoFieldRow(
          first: VariableTextField(
            label: 'Label',
            initialValue: btn.label,
            suggestions: variableSuggestions,
            onChanged: (v) {
              btn.label = v;
              onChanged(btn);
            },
          ),
          second: DropdownButtonFormField<BcButtonStyle>(
            initialValue: btn.style,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Style',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items:
                BcButtonStyle.values
                    .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                    .toList(),
            onChanged: (v) {
              if (v != null) {
                btn.style = v;
                onChanged(btn);
              }
            },
          ),
        ),
        const SizedBox(height: 8),
        if (btn.style == BcButtonStyle.link)
          TextFormField(
            initialValue: btn.url,
            decoration: const InputDecoration(
              labelText: 'URL',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) {
              btn.url = v;
              onChanged(btn);
            },
          )
        else
          Column(
            children: [
              TextFormField(
                initialValue: btn.customId,
                decoration: const InputDecoration(
                  labelText: 'Custom ID *',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator:
                    (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                onChanged: (v) {
                  btn.customId = v;
                  onChanged(btn);
                },
              ),
              const SizedBox(height: 8),
              _WorkflowSelectorField(
                botIdForConfig: botIdForConfig,
                label: 'Call Workflow (optional)',
                fallbackHint: 'Saved workflow name to run on click',
                selectedWorkflow: btn.workflowName,
                entryPoint: btn.workflowEntryPoint,
                workflowArguments: btn.workflowArguments,
                variableSuggestions: variableSuggestions,
                successMessage: 'On click, the workflow',
                onChanged: (value) {
                  btn.workflowName = value ?? '';
                  onChanged(btn);
                },
                onEntryPointChanged: (value) {
                  btn.workflowEntryPoint = value ?? '';
                  onChanged(btn);
                },
                onArgumentsChanged: (value) {
                  btn.workflowArguments = Map<String, dynamic>.from(value);
                  onChanged(btn);
                },
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildSelectMenuEditor(SelectMenuNode menu) {
    return Column(
      children: [
        _buildResponsiveTwoFieldRow(
          first: TextFormField(
            initialValue: menu.customId,
            decoration: const InputDecoration(
              labelText: 'Custom ID',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) {
              menu.customId = v;
              onChanged(menu);
            },
          ),
          second: TextFormField(
            initialValue: menu.placeholder,
            decoration: const InputDecoration(
              labelText: 'Placeholder',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) {
              menu.placeholder = v;
              onChanged(menu);
            },
          ),
        ),
        const SizedBox(height: 8),
        _WorkflowSelectorField(
          botIdForConfig: botIdForConfig,
          label: 'Call Workflow (optional)',
          fallbackHint: 'Saved workflow name to run on selection',
          selectedWorkflow: menu.workflowName,
          entryPoint: menu.workflowEntryPoint,
          workflowArguments: menu.workflowArguments,
          variableSuggestions: variableSuggestions,
          successMessage: 'On select, the workflow',
          onChanged: (value) {
            menu.workflowName = value ?? '';
            onChanged(menu);
          },
          onEntryPointChanged: (value) {
            menu.workflowEntryPoint = value ?? '';
            onChanged(menu);
          },
          onArgumentsChanged: (value) {
            menu.workflowArguments = Map<String, dynamic>.from(value);
            onChanged(menu);
          },
        ),
        if (menu.type == ComponentV2Type.stringSelect) ...[
          const SizedBox(height: 8),
          const Text(
            'Options',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          ...menu.options.asMap().entries.map((e) {
            final idx = e.key;
            final opt = e.value;
            return Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 540;
                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          initialValue: opt.label,
                          decoration: const InputDecoration(
                            labelText: 'Label',
                            isDense: true,
                          ),
                          onChanged: (v) {
                            opt.label = v;
                            onChanged(menu);
                          },
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          initialValue: opt.value,
                          decoration: const InputDecoration(
                            labelText: 'Value',
                            isDense: true,
                          ),
                          onChanged: (v) {
                            opt.value = v;
                            onChanged(menu);
                          },
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            icon: const Icon(
                              Icons.remove_circle,
                              size: 16,
                              color: Colors.red,
                            ),
                            onPressed: () {
                              menu.options.removeAt(idx);
                              onChanged(menu);
                            },
                          ),
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: opt.label,
                          decoration: const InputDecoration(
                            labelText: 'Label',
                            isDense: true,
                          ),
                          onChanged: (v) {
                            opt.label = v;
                            onChanged(menu);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          initialValue: opt.value,
                          decoration: const InputDecoration(
                            labelText: 'Value',
                            isDense: true,
                          ),
                          onChanged: (v) {
                            opt.value = v;
                            onChanged(menu);
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.remove_circle,
                          size: 16,
                          color: Colors.red,
                        ),
                        onPressed: () {
                          menu.options.removeAt(idx);
                          onChanged(menu);
                        },
                      ),
                    ],
                  );
                },
              ),
            );
          }),
          TextButton.icon(
            onPressed: () {
              menu.options.add(
                SelectMenuOption(label: 'New Option', value: 'value'),
              );
              onChanged(menu);
            },
            icon: const Icon(Icons.add, size: 14),
            label: const Text('Add Option', style: TextStyle(fontSize: 12)),
          ),
        ],
      ],
    );
  }

  Widget _buildTextDisplayEditor(TextDisplayNode node) {
    return VariableTextField(
      label: 'Markdown Content',
      initialValue: node.content,
      maxLines: 3,
      suggestions: variableSuggestions,
      onChanged: (v) {
        node.content = v;
        onChanged(node);
      },
    );
  }

  Widget _buildSeparatorEditor(SeparatorNode node) {
    return Row(
      children: [
        Switch(
          value: node.isDivider,
          onChanged: (v) {
            node.isDivider = v;
            onChanged(node);
          },
        ),
        const Text('Visible Divider Line'),
        const Spacer(),
        DropdownButton<int>(
          value: node.spacing,
          items: const [
            DropdownMenuItem(value: 1, child: Text('Small Spacing')),
            DropdownMenuItem(value: 2, child: Text('Large Spacing')),
          ],
          onChanged: (v) {
            if (v != null) {
              node.spacing = v;
              onChanged(node);
            }
          },
        ),
      ],
    );
  }

  Widget _buildSectionEditor(SectionNode node) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Text Displays',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
        ...node.components.asMap().entries.map((e) {
          final idx = e.key;
          final child = e.value;
          return ComponentNodeEditor(
            node: child,
            onChanged: (updated) {
              final newChildren = List<TextDisplayNode>.from(node.components);
              newChildren[idx] = updated as TextDisplayNode;
              node.components = newChildren;
              onChanged(node);
            },
            onRemove: () {
              final newChildren = List<TextDisplayNode>.from(node.components)
                ..removeAt(idx);
              node.components = newChildren;
              onChanged(node);
            },
            variableSuggestions: variableSuggestions,
            botIdForConfig: botIdForConfig,
          );
        }),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () {
            node.components = [...node.components, TextDisplayNode()];
            onChanged(node);
          },
          icon: const Icon(Icons.add, size: 14),
          label: const Text('Add Text Display', style: TextStyle(fontSize: 12)),
        ),
        const Divider(),
        const Text(
          'Accessory Node (Optional)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
        if (node.accessory != null)
          ComponentNodeEditor(
            node: node.accessory!,
            onChanged: (updated) {
              node.accessory = updated;
              onChanged(node);
            },
            onRemove: () {
              node.accessory = null;
              onChanged(node);
            },
            variableSuggestions: variableSuggestions,
            botIdForConfig: botIdForConfig,
          )
        else
          _buildAddComponentDropdown((newNode) {
            node.accessory = newNode;
            onChanged(node);
          }, allowedTypes: [ComponentV2Type.button, ComponentV2Type.thumbnail]),
      ],
    );
  }

  Widget _buildContainerEditor(ContainerNode node, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                key: ValueKey('container_color_\${node.accentColor}'),
                initialValue: node.accentColor,
                decoration: const InputDecoration(
                  labelText: 'Accent Color (Hex, e.g. FF0000)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) {
                  node.accentColor = v;
                  onChanged(node);
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.color_lens, color: Colors.blueAccent),
              tooltip: 'Choose Color',
              onPressed: () {
                Color currentColor = Colors.blueGrey;
                if (node.accentColor.isNotEmpty) {
                  try {
                    final hex = node.accentColor.replaceAll('#', '');
                    if (hex.length == 6) {
                      currentColor = Color(int.parse('0xFF$hex'));
                    }
                  } catch (_) {}
                }
                showDialog(
                  context: context,
                  builder:
                      (ctx) => AlertDialog(
                        title: const Text('Pick Accent Color'),
                        content: SingleChildScrollView(
                          child: ColorPicker(
                            pickerColor: currentColor,
                            enableAlpha: false,
                            hexInputBar: true,
                            onColorChanged: (c) {
                              currentColor = c;
                            },
                          ),
                        ),
                        actions: [
                          TextButton(
                            child: const Text('Cancel'),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                          TextButton(
                            child: const Text('OK'),
                            onPressed: () {
                              node.accentColor =
                                  currentColor
                                      .toARGB32()
                                      .toRadixString(16)
                                      .substring(
                                        2,
                                      ) // remove trailing alpha usually if length 8
                                      .toUpperCase();
                              onChanged(node);
                              Navigator.of(ctx).pop();
                            },
                          ),
                        ],
                      ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...node.components.asMap().entries.map((e) {
          final idx = e.key;
          final child = e.value;
          return ComponentNodeEditor(
            node: child,
            onChanged: (updated) {
              final newChildren = List<ComponentNode>.from(node.components);
              newChildren[idx] = updated;
              node.components = newChildren;
              onChanged(node);
            },
            onRemove: () {
              final newChildren = List<ComponentNode>.from(node.components)
                ..removeAt(idx);
              node.components = newChildren;
              onChanged(node);
            },
            variableSuggestions: variableSuggestions,
            botIdForConfig: botIdForConfig,
          );
        }),
        const SizedBox(height: 8),
        _buildAddComponentDropdown(
          (newNode) {
            node.components = [...node.components, newNode];
            onChanged(node);
          },
          allowedTypes: [
            ComponentV2Type.actionRow,
            ComponentV2Type.textDisplay,
            ComponentV2Type.section,
            ComponentV2Type.mediaGallery,
            ComponentV2Type.separator,
            ComponentV2Type.file,
          ],
        ),
      ],
    );
  }

  Widget _buildLabelEditor(LabelNode node) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VariableTextField(
          label: 'Label Title',
          initialValue: node.label,
          suggestions: variableSuggestions,
          onChanged: (v) {
            node.label = v;
            onChanged(node);
          },
        ),
        const SizedBox(height: 8),
        VariableTextField(
          label: 'Description',
          initialValue: node.description,
          suggestions: variableSuggestions,
          onChanged: (v) {
            node.description = v;
            onChanged(node);
          },
        ),
        const SizedBox(height: 8),
        const Text(
          'Component to Wrap:',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        if (node.component != null)
          ComponentNodeEditor(
            node: node.component!,
            onChanged: (updated) {
              node.component = updated;
              onChanged(node);
            },
            onRemove: () {
              node.component = null;
              onChanged(node);
            },
            variableSuggestions: variableSuggestions,
            botIdForConfig: botIdForConfig,
          )
        else
          _buildAddComponentDropdown(
            (newNode) {
              node.component = newNode;
              onChanged(node);
            },
            allowedTypes: [
              ComponentV2Type.stringSelect,
              ComponentV2Type.userSelect,
              ComponentV2Type.roleSelect,
              ComponentV2Type.mentionableSelect,
              ComponentV2Type.channelSelect,
              ComponentV2Type.fileUpload,
              ComponentV2Type.radioGroup,
              ComponentV2Type.checkboxGroup,
              ComponentV2Type.checkbox,
            ],
          ),
      ],
    );
  }

  Widget _buildCheckboxEditor(CheckboxNode node) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            initialValue: node.customId,
            decoration: const InputDecoration(
              labelText: 'Custom ID',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) {
              node.customId = v;
              onChanged(node);
            },
          ),
        ),
        Switch(
          value: node.isDefault,
          onChanged: (v) {
            node.isDefault = v;
            onChanged(node);
          },
        ),
        const Text('Checked by default'),
      ],
    );
  }

  Widget _buildRadioGroupEditor(RadioGroupNode node) {
    return Column(
      children: [
        TextFormField(
          initialValue: node.customId,
          decoration: const InputDecoration(
            labelText: 'Custom ID',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) {
            node.customId = v;
            onChanged(node);
          },
        ),
        const SizedBox(height: 8),
        const Text(
          'Radio Options',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
        ...node.options.asMap().entries.map((e) {
          final idx = e.key;
          final opt = e.value;
          return Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: opt.label,
                    decoration: const InputDecoration(
                      labelText: 'Label',
                      isDense: true,
                    ),
                    onChanged: (v) {
                      opt.label = v;
                      onChanged(node);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: opt.value,
                    decoration: const InputDecoration(
                      labelText: 'Value',
                      isDense: true,
                    ),
                    onChanged: (v) {
                      opt.value = v;
                      onChanged(node);
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.remove_circle,
                    size: 16,
                    color: Colors.red,
                  ),
                  onPressed: () {
                    node.options.removeAt(idx);
                    onChanged(node);
                  },
                ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: () {
            node.options.add(
              RadioGroupOptionNode(label: 'New Radio', value: 'value'),
            );
            onChanged(node);
          },
          icon: const Icon(Icons.add, size: 14),
          label: const Text('Add Radio Option', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  Widget _buildCheckboxGroupEditor(CheckboxGroupNode node) {
    return Column(
      children: [
        TextFormField(
          initialValue: node.customId,
          decoration: const InputDecoration(
            labelText: 'Custom ID',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) {
            node.customId = v;
            onChanged(node);
          },
        ),
        const SizedBox(height: 8),
        const Text(
          'Checkbox Options',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
        ...node.options.asMap().entries.map((e) {
          final idx = e.key;
          final opt = e.value;
          return Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: opt.label,
                    decoration: const InputDecoration(
                      labelText: 'Label',
                      isDense: true,
                    ),
                    onChanged: (v) {
                      opt.label = v;
                      onChanged(node);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: opt.value,
                    decoration: const InputDecoration(
                      labelText: 'Value',
                      isDense: true,
                    ),
                    onChanged: (v) {
                      opt.value = v;
                      onChanged(node);
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.remove_circle,
                    size: 16,
                    color: Colors.red,
                  ),
                  onPressed: () {
                    node.options.removeAt(idx);
                    onChanged(node);
                  },
                ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: () {
            node.options.add(
              CheckboxGroupOptionNode(label: 'New Checkbox', value: 'value'),
            );
            onChanged(node);
          },
          icon: const Icon(Icons.add, size: 14),
          label: const Text(
            'Add Checkbox Option',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildFileUploadEditor(FileUploadNode node) {
    return TextFormField(
      initialValue: node.customId,
      decoration: const InputDecoration(
        labelText: 'Custom ID',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: (v) {
        node.customId = v;
        onChanged(node);
      },
    );
  }

  Widget _buildFileEditor(FileNode node) {
    return TextFormField(
      initialValue: node.file.url,
      decoration: const InputDecoration(
        labelText: 'File URL',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: (v) {
        node.file.url = v;
        onChanged(node);
      },
    );
  }

  Widget _buildThumbnailEditor(ThumbnailNode node) {
    return TextFormField(
      initialValue: node.media.url,
      decoration: const InputDecoration(
        labelText: 'Thumbnail URL',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: (v) {
        node.media.url = v;
        onChanged(node);
      },
    );
  }

  Widget _buildMediaGalleryEditor(MediaGalleryNode node) {
    return Column(
      children: [
        const Text(
          'Media URLs',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
        ...node.items.asMap().entries.map((e) {
          final idx = e.key;
          final opt = e.value;
          return Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: opt.media.url,
                    decoration: const InputDecoration(
                      labelText: 'Image / Video URL',
                      isDense: true,
                    ),
                    onChanged: (v) {
                      opt.media.url = v;
                      onChanged(node);
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.remove_circle,
                    size: 16,
                    color: Colors.red,
                  ),
                  onPressed: () {
                    node.items.removeAt(idx);
                    onChanged(node);
                  },
                ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: () {
            node.items.add(MediaGalleryItemNode());
            onChanged(node);
          },
          icon: const Icon(Icons.add, size: 14),
          label: const Text('Add Media Item', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  // --- Utility Component Adder ---

  Widget _buildAddComponentDropdown(
    ValueChanged<ComponentNode> onAdd, {
    List<ComponentV2Type>? allowedTypes,
  }) {
    final types = allowedTypes ?? ComponentV2Type.values;

    return Row(
      children: [
        Expanded(
          child: PopupMenuButton<ComponentV2Type>(
            tooltip: 'Add Child Component',
            onSelected: (v) {
              ComponentNode newNode = ActionRowNode();
              switch (v) {
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
                  newNode = SelectMenuNode(
                    type: ComponentV2Type.mentionableSelect,
                  );
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
                  newNode = LabelNode(
                    label: 'Label',
                    component: TextDisplayNode(),
                  );
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
              onAdd(newNode);
            },
            itemBuilder: (BuildContext context) {
              return types
                  .map(
                    (t) => PopupMenuItem(
                      value: t,
                      child: Text(_getTitleForType(t)),
                    ),
                  )
                  .toList();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blueGrey.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                children: [
                  Icon(Icons.add, size: 16, color: Colors.blueGrey),
                  SizedBox(width: 8),
                  Text(
                    'Add Child Component',
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
        ),
      ],
    );
  }
}

class _WorkflowSelectorField extends StatefulWidget {
  final String? botIdForConfig;
  final String label;
  final String fallbackHint;
  final String? selectedWorkflow;
  final String entryPoint;
  final Map<String, dynamic> workflowArguments;
  final List<VariableSuggestion> variableSuggestions;
  final ValueChanged<String?> onChanged;
  final ValueChanged<String?> onEntryPointChanged;
  final ValueChanged<Map<String, dynamic>> onArgumentsChanged;
  final String successMessage;

  const _WorkflowSelectorField({
    required this.botIdForConfig,
    required this.label,
    required this.fallbackHint,
    required this.selectedWorkflow,
    required this.entryPoint,
    required this.workflowArguments,
    required this.variableSuggestions,
    required this.onChanged,
    required this.onEntryPointChanged,
    required this.onArgumentsChanged,
    required this.successMessage,
  });

  @override
  State<_WorkflowSelectorField> createState() => _WorkflowSelectorFieldState();
}

class _WorkflowSelectorFieldState extends State<_WorkflowSelectorField> {
  late String _selectedWorkflow;
  late TextEditingController _entryPointCtrl;
  late Map<String, dynamic> _workflowArguments;
  List<String> _availableWorkflowNames = const [];
  bool _loadingWorkflows = false;

  @override
  void initState() {
    super.initState();
    _selectedWorkflow = (widget.selectedWorkflow ?? '').trim();
    _entryPointCtrl = TextEditingController(text: widget.entryPoint.trim());
    _workflowArguments = Map<String, dynamic>.from(widget.workflowArguments);
    _loadAvailableWorkflows();
  }

  @override
  void didUpdateWidget(covariant _WorkflowSelectorField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSelected = (widget.selectedWorkflow ?? '').trim();
    if (nextSelected != _selectedWorkflow) {
      _selectedWorkflow = nextSelected;
    }
    final nextEntryPoint = widget.entryPoint.trim();
    if (_entryPointCtrl.text != nextEntryPoint) {
      _entryPointCtrl.text = nextEntryPoint;
    }
    _workflowArguments = Map<String, dynamic>.from(widget.workflowArguments);
    if (widget.botIdForConfig != oldWidget.botIdForConfig) {
      _loadAvailableWorkflows();
    }
  }

  @override
  void dispose() {
    _entryPointCtrl.dispose();
    super.dispose();
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
      .toList(growable: false)..sort();

    setState(() {
      _availableWorkflowNames = names;
      _loadingWorkflows = false;
    });
  }

  Future<void> _editWorkflowArguments() async {
    final jsonController = TextEditingController(
      text:
          _workflowArguments.isEmpty
              ? '{}'
              : const JsonEncoder.withIndent('  ').convert(_workflowArguments),
    );
    String? error;

    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Workflow Call Arguments (JSON)'),
                content: SizedBox(
                  width: 520,
                  child: TextField(
                    controller: jsonController,
                    minLines: 8,
                    maxLines: 16,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      errorText: error,
                      helperText: 'Example: {"ticketId":"((opts.ticket))"}',
                    ),
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () {
                      final raw = jsonController.text.trim();
                      if (raw.isEmpty) {
                        setState(() {
                          _workflowArguments = <String, dynamic>{};
                        });
                        widget.onArgumentsChanged(_workflowArguments);
                        Navigator.pop(dialogContext);
                        return;
                      }

                      try {
                        final parsed = jsonDecode(raw);
                        if (parsed is! Map) {
                          setDialogState(() {
                            error = 'Root must be a JSON object';
                          });
                          return;
                        }

                        setState(() {
                          _workflowArguments = Map<String, dynamic>.from(
                            parsed.map(
                              (key, value) => MapEntry(key.toString(), value),
                            ),
                          );
                        });
                        widget.onArgumentsChanged(_workflowArguments);
                        Navigator.pop(dialogContext);
                      } catch (e) {
                        setDialogState(() {
                          error = e.toString();
                        });
                      }
                    },
                    child: const Text('Save'),
                  ),
                ],
              );
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final botId = widget.botIdForConfig?.trim();
    final hasBotContext = botId != null && botId.isNotEmpty;

    final selectedInList =
        _selectedWorkflow.isNotEmpty &&
                _availableWorkflowNames.contains(_selectedWorkflow)
            ? _selectedWorkflow
            : null;

    final workflowNameInput =
        hasBotContext
            ? Column(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final selector = DropdownButtonFormField<String>(
                      key: ValueKey(
                        'workflow_${widget.label}_${selectedInList}_${_availableWorkflowNames.length}',
                      ),
                      initialValue: selectedInList,
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
                                final next = (value ?? '').trim();
                                setState(() {
                                  _selectedWorkflow = next;
                                });
                                widget.onChanged(next.isEmpty ? null : next);
                              },
                      decoration: InputDecoration(
                        labelText: widget.label,
                        border: const OutlineInputBorder(),
                        isDense: true,
                        helperText:
                            _loadingWorkflows
                                ? 'Loading workflows...'
                                : (_availableWorkflowNames.isEmpty
                                    ? 'No saved workflows found'
                                    : 'Select a saved workflow'),
                      ),
                    );

                    final refreshButton = IconButton(
                      tooltip: 'Refresh workflows',
                      onPressed:
                          _loadingWorkflows ? null : _loadAvailableWorkflows,
                      icon: const Icon(Icons.refresh),
                    );

                    if (constraints.maxWidth < 440) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          selector,
                          Align(
                            alignment: Alignment.centerRight,
                            child: refreshButton,
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: selector),
                        const SizedBox(width: 8),
                        refreshButton,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 6),
                TextFormField(
                  key: ValueKey(
                    'workflow_manual_${widget.label}_$_selectedWorkflow',
                  ),
                  initialValue: _selectedWorkflow,
                  decoration: const InputDecoration(
                    labelText: 'Or type workflow name',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (value) {
                    final next = value.trim();
                    setState(() {
                      _selectedWorkflow = next;
                    });
                    widget.onChanged(next.isEmpty ? null : next);
                  },
                ),
              ],
            )
            : VariableTextField(
              label: widget.label,
              initialValue: _selectedWorkflow,
              hint: widget.fallbackHint,
              suggestions: widget.variableSuggestions,
              onChanged: (value) {
                final nextValue = value.trim();
                setState(() {
                  _selectedWorkflow = nextValue;
                });
                widget.onChanged(nextValue.isEmpty ? null : nextValue);
              },
            );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        workflowNameInput,
        if (hasBotContext) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed:
                _loadingWorkflows
                    ? null
                    : () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WorkflowsPage(botId: botId),
                        ),
                      );
                      await _loadAvailableWorkflows();
                    },
            icon: const Icon(Icons.account_tree),
            label: const Text('Manage Workflows'),
          ),
        ],
        if (_selectedWorkflow.isNotEmpty) ...[
          const SizedBox(height: 8),
          TextFormField(
            controller: _entryPointCtrl,
            decoration: const InputDecoration(
              labelText: 'Entry Point (optional)',
              border: OutlineInputBorder(),
              isDense: true,
              helperText: 'Defaults to workflow entry point when empty',
            ),
            onChanged: (value) => widget.onEntryPointChanged(value.trim()),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _editWorkflowArguments,
            icon: const Icon(Icons.data_object),
            label: Text(
              _workflowArguments.isEmpty
                  ? 'Set Call Arguments'
                  : 'Edit Call Arguments (${_workflowArguments.length})',
            ),
          ),
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
                    '${widget.successMessage} "$_selectedWorkflow" will be executed (entry: ${_entryPointCtrl.text.trim().isEmpty ? 'default' : _entryPointCtrl.text.trim()}, args: ${_workflowArguments.length}).',
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
        ],
      ],
    );
  }
}
