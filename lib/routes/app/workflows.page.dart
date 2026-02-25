import 'package:bot_creator/main.dart';
import 'package:bot_creator/routes/app/builder.response.dart';
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

    final saveInfo = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(initial == null ? 'Create Workflow' : 'Edit Workflow'),
            content: TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Workflow Name',
                border: OutlineInputBorder(),
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
          ),
    );

    if (saveInfo != true) {
      return;
    }

    final name = nameController.text.trim();
    if (name.isEmpty) {
      return;
    }

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
            (context) => ActionsBuilderPage(initialActions: initialActions),
      ),
    );

    if (nextActions == null) {
      return;
    }

    await appManager.saveWorkflow(
      widget.botId,
      name: name,
      actions: nextActions,
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
      appBar: AppBar(title: const Text('Workflows')),
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
                  return ListTile(
                    title: Text(name),
                    subtitle: Text('$actions action(s)'),
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
