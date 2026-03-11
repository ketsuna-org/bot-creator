import 'package:bot_creator/main.dart';
import 'package:bot_creator/routes/app/builder.response.dart';
import 'package:bot_creator/routes/app/workflow_docs.page.dart';
import 'package:bot_creator/utils/workflow_call.dart';
import 'package:flutter/material.dart';

class WorkflowsPage extends StatefulWidget {
  const WorkflowsPage({super.key, required this.botId});

  final String botId;

  @override
  State<WorkflowsPage> createState() => _WorkflowsPageState();
}

class _WorkflowsPageState extends State<WorkflowsPage> {
  List<Map<String, dynamic>> _workflows = <Map<String, dynamic>>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final workflows = await appManager.getWorkflows(widget.botId);
    if (!mounted) {
      return;
    }
    setState(() {
      _workflows = workflows;
      _loading = false;
    });
  }

  Future<void> _createOrEditWorkflow({Map<String, dynamic>? initial}) async {
    final nameController = TextEditingController(
      text: (initial?['name'] ?? '').toString(),
    );
    final entryPointController = TextEditingController(
      text: normalizeWorkflowEntryPoint(initial?['entryPoint']),
    );
    final editableArgs =
        parseWorkflowArgumentDefinitions(initial?['arguments']).map((
          definition,
        ) {
          return _EditableWorkflowArgument(
            name: definition.name,
            required: definition.required,
            defaultValue: definition.defaultValue,
          );
        }).toList();
    if (editableArgs.isEmpty) {
      editableArgs.add(const _EditableWorkflowArgument(name: ''));
    }

    final saveInfo = await showDialog<bool>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text(
                  initial == null ? 'Create Workflow' : 'Edit Workflow',
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Workflow Name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: entryPointController,
                          decoration: const InputDecoration(
                            labelText: 'Default Entry Point',
                            border: OutlineInputBorder(),
                            helperText: 'Used if caller does not override it',
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Arguments',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Add argument',
                              onPressed: () {
                                setDialogState(() {
                                  editableArgs.add(
                                    const _EditableWorkflowArgument(name: ''),
                                  );
                                });
                              },
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                        ...editableArgs.asMap().entries.map((entry) {
                          final index = entry.key;
                          final value = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: TextFormField(
                                    initialValue: value.name,
                                    decoration: const InputDecoration(
                                      labelText: 'Name',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    onChanged: (next) {
                                      editableArgs[index] = editableArgs[index]
                                          .copyWith(name: next.trim());
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 4,
                                  child: TextFormField(
                                    initialValue: value.defaultValue,
                                    decoration: const InputDecoration(
                                      labelText: 'Default value',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    onChanged: (next) {
                                      editableArgs[index] = editableArgs[index]
                                          .copyWith(defaultValue: next);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  children: [
                                    Checkbox(
                                      value: value.required,
                                      onChanged: (next) {
                                        editableArgs[index] =
                                            editableArgs[index].copyWith(
                                              required: next == true,
                                            );
                                        setDialogState(() {});
                                      },
                                    ),
                                    const Text(
                                      'Req',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  onPressed: () {
                                    setDialogState(() {
                                      editableArgs.removeAt(index);
                                      if (editableArgs.isEmpty) {
                                        editableArgs.add(
                                          const _EditableWorkflowArgument(
                                            name: '',
                                          ),
                                        );
                                      }
                                    });
                                  },
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          );
                        }),
                        const Text(
                          'Arguments become runtime variables as ((arg.name)) and ((workflow.arg.name)).',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Continue'),
                  ),
                ],
              );
            },
          ),
    );

    if (saveInfo != true) {
      return;
    }

    final name = nameController.text.trim();
    if (name.isEmpty) {
      return;
    }
    final entryPoint = normalizeWorkflowEntryPoint(entryPointController.text);
    final argumentDefinitions = editableArgs
        .where((item) => item.name.trim().isNotEmpty)
        .map(
          (item) => WorkflowArgumentDefinition(
            name: item.name.trim(),
            required: item.required,
            defaultValue: item.defaultValue,
          ),
        )
        .toList(growable: false);
    final workflowVariableSuggestions = <VariableSuggestion>[
      const VariableSuggestion(
        name: 'workflow.name',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      const VariableSuggestion(
        name: 'workflow.entryPoint',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      const VariableSuggestion(
        name: 'workflow.args',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      for (final arg in argumentDefinitions) ...[
        VariableSuggestion(
          name: 'arg.${arg.name}',
          kind: VariableSuggestionKind.unknown,
        ),
        VariableSuggestion(
          name: 'workflow.arg.${arg.name}',
          kind: VariableSuggestionKind.unknown,
        ),
      ],
    ];

    final initialActions = List<Map<String, dynamic>>.from(
      (initial?['actions'] as List?)?.whereType<Map>().map(
            (item) => Map<String, dynamic>.from(item),
          ) ??
          const <Map<String, dynamic>>[],
    );

    final nextActions = await Navigator.push<List<Map<String, dynamic>>>(
      context,
      MaterialPageRoute(
        builder:
            (context) => ActionsBuilderPage(
              initialActions: initialActions,
              botIdForConfig: widget.botId,
              variableSuggestions: workflowVariableSuggestions,
            ),
      ),
    );

    if (nextActions == null) {
      return;
    }

    await appManager.saveWorkflow(
      widget.botId,
      name: name,
      actions: nextActions,
      entryPoint: entryPoint,
      arguments: serializeWorkflowArgumentDefinitions(argumentDefinitions),
    );
    await _load();
  }

  Future<void> _deleteWorkflow(String name) async {
    await appManager.deleteWorkflow(widget.botId, name);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workflows'),
        actions: [
          IconButton(
            tooltip: 'Workflow Documentation',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const WorkflowDocumentationPage(),
                ),
              );
            },
            icon: const Icon(Icons.menu_book_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createOrEditWorkflow(),
        child: const Icon(Icons.add),
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _workflows.isEmpty
              ? const Center(child: Text('No workflows yet'))
              : ListView.separated(
                itemCount: _workflows.length,
                separatorBuilder:
                    (BuildContext context, int index) =>
                        const Divider(height: 1),
                itemBuilder: (context, index) {
                  final workflow = _workflows[index];
                  final name = (workflow['name'] ?? '').toString();
                  final actions =
                      (workflow['actions'] is List)
                          ? (workflow['actions'] as List).length
                          : 0;
                  final entryPoint = normalizeWorkflowEntryPoint(
                    workflow['entryPoint'],
                  );
                  final argsCount =
                      parseWorkflowArgumentDefinitions(
                        workflow['arguments'],
                      ).length;
                  return ListTile(
                    title: Text(name),
                    subtitle: Text(
                      '$actions action(s) • entry: $entryPoint • args: $argsCount',
                    ),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          onPressed:
                              () => _createOrEditWorkflow(initial: workflow),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          onPressed: () => _deleteWorkflow(name),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  );
                },
              ),
    );
  }
}

class _EditableWorkflowArgument {
  final String name;
  final bool required;
  final String defaultValue;

  const _EditableWorkflowArgument({
    required this.name,
    this.required = false,
    this.defaultValue = '',
  });

  _EditableWorkflowArgument copyWith({
    String? name,
    bool? required,
    String? defaultValue,
  }) {
    return _EditableWorkflowArgument(
      name: name ?? this.name,
      required: required ?? this.required,
      defaultValue: defaultValue ?? this.defaultValue,
    );
  }
}
