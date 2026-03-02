import 'package:flutter/material.dart';
import 'package:nyxx/nyxx.dart';

class BasicInfoCard extends StatefulWidget {
  final String commandName;
  final String commandDescription;
  final List<ApplicationIntegrationType> integrationTypes;
  final List<InteractionContextType> contexts;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onDescriptionChanged;
  final ValueChanged<List<ApplicationIntegrationType>>
  onIntegrationTypesChanged;
  final ValueChanged<List<InteractionContextType>> onContextsChanged;
  final String defaultMemberPermissions;
  final ValueChanged<String> onDefaultMemberPermissionsChanged;
  final String? Function(String?) nameValidator;

  const BasicInfoCard({
    super.key,
    required this.commandName,
    required this.commandDescription,
    required this.integrationTypes,
    required this.contexts,
    required this.onNameChanged,
    required this.onDescriptionChanged,
    required this.onIntegrationTypesChanged,
    required this.onContextsChanged,
    required this.defaultMemberPermissions,
    required this.onDefaultMemberPermissionsChanged,
    required this.nameValidator,
  });

  @override
  State<BasicInfoCard> createState() => _BasicInfoCardState();
}

class _BasicInfoCardState extends State<BasicInfoCard> {
  static final List<_PermissionItem> _permissionItems = [
    _PermissionItem(0, 'Create Invite'),
    _PermissionItem(1, 'Kick Members'),
    _PermissionItem(2, 'Ban Members'),
    _PermissionItem(3, 'Administrator'),
    _PermissionItem(4, 'Manage Channels'),
    _PermissionItem(5, 'Manage Server'),
    _PermissionItem(6, 'Add Reactions'),
    _PermissionItem(7, 'View Audit Log'),
    _PermissionItem(8, 'Priority Speaker'),
    _PermissionItem(9, 'Stream'),
    _PermissionItem(10, 'View Channel'),
    _PermissionItem(11, 'Send Messages'),
    _PermissionItem(12, 'Send TTS Messages'),
    _PermissionItem(13, 'Manage Messages'),
    _PermissionItem(14, 'Embed Links'),
    _PermissionItem(15, 'Attach Files'),
    _PermissionItem(16, 'Read Message History'),
    _PermissionItem(17, 'Mention Everyone'),
    _PermissionItem(18, 'Use External Emojis'),
    _PermissionItem(19, 'View Server Insights'),
    _PermissionItem(20, 'Connect (Voice)'),
    _PermissionItem(21, 'Speak (Voice)'),
    _PermissionItem(22, 'Mute Members'),
    _PermissionItem(23, 'Deafen Members'),
    _PermissionItem(24, 'Move Members'),
    _PermissionItem(25, 'Use Voice Activity'),
    _PermissionItem(26, 'Change Nickname'),
    _PermissionItem(27, 'Manage Nicknames'),
    _PermissionItem(28, 'Manage Roles'),
    _PermissionItem(29, 'Manage Webhooks'),
    _PermissionItem(30, 'Manage Expressions'),
    _PermissionItem(31, 'Use Application Commands'),
    _PermissionItem(32, 'Request To Speak'),
    _PermissionItem(33, 'Manage Events'),
    _PermissionItem(34, 'Manage Threads'),
    _PermissionItem(35, 'Create Public Threads'),
    _PermissionItem(36, 'Create Private Threads'),
    _PermissionItem(37, 'Use External Stickers'),
    _PermissionItem(38, 'Send Messages In Threads'),
    _PermissionItem(39, 'Use Embedded Activities'),
    _PermissionItem(40, 'Moderate Members'),
    _PermissionItem(41, 'View Monetization Analytics'),
    _PermissionItem(42, 'Use Soundboard'),
    _PermissionItem(43, 'Create Expressions'),
    _PermissionItem(44, 'Create Events'),
    _PermissionItem(45, 'Use External Sounds'),
    _PermissionItem(46, 'Send Voice Messages'),
    _PermissionItem(49, 'Send Polls'),
    _PermissionItem(50, 'Use External Apps'),
  ];

  late Set<int> _selectedPermissionOffsets;
  late BigInt _unknownBits;

  @override
  void initState() {
    super.initState();
    _selectedPermissionOffsets = <int>{};
    _unknownBits = BigInt.zero;
    _applyBitfield(widget.defaultMemberPermissions);
  }

  @override
  void didUpdateWidget(covariant BasicInfoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.defaultMemberPermissions != widget.defaultMemberPermissions) {
      _applyBitfield(widget.defaultMemberPermissions);
    }
  }

  void _applyBitfield(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      _selectedPermissionOffsets = <int>{};
      _unknownBits = BigInt.zero;
      return;
    }

    BigInt parsed;
    try {
      parsed = BigInt.parse(trimmed);
    } catch (_) {
      _selectedPermissionOffsets = <int>{};
      _unknownBits = BigInt.zero;
      return;
    }

    if (parsed < BigInt.zero) {
      parsed = BigInt.zero;
    }

    final selected = <int>{};
    BigInt knownMask = BigInt.zero;

    for (final item in _permissionItems) {
      final bit = BigInt.one << item.offset;
      knownMask |= bit;
      if ((parsed & bit) != BigInt.zero) {
        selected.add(item.offset);
      }
    }

    _selectedPermissionOffsets = selected;
    _unknownBits = parsed & ~knownMask;
  }

  String _computedBitfield() {
    BigInt value = _unknownBits;
    for (final offset in _selectedPermissionOffsets) {
      value |= (BigInt.one << offset);
    }
    return value == BigInt.zero ? '' : value.toString();
  }

  void _togglePermission(int offset, bool enabled) {
    setState(() {
      if (enabled) {
        _selectedPermissionOffsets.add(offset);
      } else {
        _selectedPermissionOffsets.remove(offset);
      }
    });
    widget.onDefaultMemberPermissionsChanged(_computedBitfield());
  }

  void _clearPermissions() {
    setState(() {
      _selectedPermissionOffsets.clear();
      _unknownBits = BigInt.zero;
    });
    widget.onDefaultMemberPermissionsChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final computedBitfield = _computedBitfield();
    final selectedNames = _permissionItems
        .where((item) => _selectedPermissionOffsets.contains(item.offset))
        .map((item) => item.label)
        .toList(growable: false);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Command Info',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Basic metadata and availability',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, innerConstraints) {
                final isWide = innerConstraints.maxWidth >= 760;
                final nameField = TextFormField(
                  autocorrect: false,
                  validator: widget.nameValidator,
                  initialValue: widget.commandName,
                  maxLength: 32,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: widget.onNameChanged,
                );

                final descriptionField = TextFormField(
                  autocorrect: false,
                  maxLength: 100,
                  maxLines: 3,
                  minLines: 1,
                  keyboardType: TextInputType.multiline,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a command description';
                    }
                    if (value.length > 100) {
                      return 'Command description must be at most 100 characters long';
                    }
                    return null;
                  },
                  initialValue: widget.commandDescription,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: widget.onDescriptionChanged,
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: nameField),
                          const SizedBox(width: 12),
                          Expanded(child: descriptionField),
                        ],
                      )
                    else ...[
                      nameField,
                      const SizedBox(height: 12),
                      descriptionField,
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Where this command can be used',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.start,
                      spacing: 20,
                      runSpacing: 8,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: widget.integrationTypes.contains(
                                ApplicationIntegrationType.guildInstall,
                              ),
                              onChanged: (value) {
                                final newTypes =
                                    List<ApplicationIntegrationType>.from(
                                      widget.integrationTypes,
                                    );
                                if (value == true) {
                                  newTypes.add(
                                    ApplicationIntegrationType.guildInstall,
                                  );
                                } else {
                                  newTypes.remove(
                                    ApplicationIntegrationType.guildInstall,
                                  );
                                }
                                widget.onIntegrationTypesChanged(newTypes);
                              },
                            ),
                            const Text('Guild Install'),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: widget.integrationTypes.contains(
                                ApplicationIntegrationType.userInstall,
                              ),
                              onChanged: (value) {
                                final newTypes =
                                    List<ApplicationIntegrationType>.from(
                                      widget.integrationTypes,
                                    );
                                if (value == true) {
                                  newTypes.add(
                                    ApplicationIntegrationType.userInstall,
                                  );
                                } else {
                                  newTypes.remove(
                                    ApplicationIntegrationType.userInstall,
                                  );
                                }
                                widget.onIntegrationTypesChanged(newTypes);
                              },
                            ),
                            const Text('User Install'),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Scope of the command (Contexts)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.start,
                      spacing: 20,
                      runSpacing: 8,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: widget.contexts.contains(
                                InteractionContextType.guild,
                              ),
                              onChanged: (value) {
                                final newContexts =
                                    List<InteractionContextType>.from(
                                      widget.contexts,
                                    );
                                if (value == true) {
                                  newContexts.add(InteractionContextType.guild);
                                } else {
                                  newContexts.remove(
                                    InteractionContextType.guild,
                                  );
                                }
                                widget.onContextsChanged(newContexts);
                              },
                            ),
                            const Text('Guild'),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: widget.contexts.contains(
                                InteractionContextType.botDm,
                              ),
                              onChanged: (value) {
                                final newContexts =
                                    List<InteractionContextType>.from(
                                      widget.contexts,
                                    );
                                if (value == true) {
                                  newContexts.add(InteractionContextType.botDm);
                                } else {
                                  newContexts.remove(
                                    InteractionContextType.botDm,
                                  );
                                }
                                widget.onContextsChanged(newContexts);
                              },
                            ),
                            const Text('Bot DM'),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: widget.contexts.contains(
                                InteractionContextType.privateChannel,
                              ),
                              onChanged: (value) {
                                final newContexts =
                                    List<InteractionContextType>.from(
                                      widget.contexts,
                                    );
                                if (value == true) {
                                  newContexts.add(
                                    InteractionContextType.privateChannel,
                                  );
                                } else {
                                  newContexts.remove(
                                    InteractionContextType.privateChannel,
                                  );
                                }
                                widget.onContextsChanged(newContexts);
                              },
                            ),
                            const Text('Group DM / Other'),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Default Member Permissions (optional)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                      childrenPadding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                      title: const Text('Select permissions'),
                      subtitle: Text(
                        _selectedPermissionOffsets.isEmpty
                            ? 'No selection (everyone can use command)'
                            : '${_selectedPermissionOffsets.length} permission(s) selected',
                        style: const TextStyle(fontSize: 12),
                      ),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children:
                                selectedNames
                                    .map((name) => Chip(label: Text(name)))
                                    .toList(),
                          ),
                        ),
                        if (selectedNames.isNotEmpty) const SizedBox(height: 8),
                        ..._permissionItems.map((item) {
                          final isSelected = _selectedPermissionOffsets
                              .contains(item.offset);
                          return CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            value: isSelected,
                            title: Text(item.label),
                            subtitle: Text(
                              'Bit ${item.offset}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            onChanged: (checked) {
                              _togglePermission(item.offset, checked == true);
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                          );
                        }),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: _clearPermissions,
                              icon: const Icon(Icons.clear),
                              label: const Text('Clear'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      key: ValueKey('permissions_bitfield_$computedBitfield'),
                      initialValue:
                          computedBitfield.isEmpty ? '0' : computedBitfield,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Calculated Permission Bitfield',
                        border: OutlineInputBorder(),
                        helperText:
                            'Automatically computed from selected permissions.',
                      ),
                    ),
                    if (_unknownBits != BigInt.zero) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Warning: unknown permission bits detected from saved data and preserved: ${_unknownBits.toString()}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                    if (_selectedPermissionOffsets.contains(3)) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Administrator selected: this bypasses other permission checks.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'Tip: leave all unchecked to make the command available to everyone by default.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionItem {
  final int offset;
  final String label;

  const _PermissionItem(this.offset, this.label);
}
