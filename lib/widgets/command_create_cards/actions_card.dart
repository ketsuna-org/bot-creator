import 'package:bot_creator/routes/app/builder.response.dart';
import 'package:bot_creator/routes/app/global.variables.dart';
import 'package:bot_creator/routes/app/workflows.page.dart';
import 'package:bot_creator/main.dart';
import 'package:flutter/material.dart';

class ActionsCard extends StatelessWidget {
  final List<Map<String, dynamic>> actions;
  final ValueChanged<List<Map<String, dynamic>>> onActionsChanged;
  final List<dynamic>
  actionVariableSuggestions; // Defined as dynamic to avoid import issues if not public
  final String? botIdForConfig;

  const ActionsCard({
    super.key,
    required this.actions,
    required this.onActionsChanged,
    required this.actionVariableSuggestions,
    this.botIdForConfig,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Actions",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              "Build runtime actions for this command",
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
              ),
              onPressed: () async {
                // Ignore type warning for actionVariableSuggestions here if type is different in ActionsBuilderPage
                final nextActions =
                    await Navigator.push<List<Map<String, dynamic>>>(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => ActionsBuilderPage(
                              initialActions: actions,
                              variableSuggestions:
                                  actionVariableSuggestions as dynamic,
                            ),
                      ),
                    );

                if (nextActions != null) {
                  onActionsChanged(nextActions);
                }
              },
              child: Text("Build Actions (${actions.length})"),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed:
                      botIdForConfig == null || actions.isEmpty
                          ? null
                          : () async {
                            final controller = TextEditingController();
                            final workflowName = await showDialog<String>(
                              context: context,
                              builder:
                                  (dialogContext) => AlertDialog(
                                    title: const Text('Save as Workflow'),
                                    content: TextField(
                                      controller: controller,
                                      decoration: const InputDecoration(
                                        labelText: 'Workflow name',
                                        border: OutlineInputBorder(),
                                      ),
                                      autofocus: true,
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed:
                                            () => Navigator.pop(dialogContext),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        onPressed: () {
                                          final name =
                                              controller.text.trim();
                                          if (name.isEmpty) {
                                            return;
                                          }
                                          Navigator.pop(dialogContext, name);
                                        },
                                        child: const Text('Save'),
                                      ),
                                    ],
                                  ),
                            );

                            if (workflowName == null ||
                                workflowName.trim().isEmpty) {
                              return;
                            }

                            await appManager.saveWorkflow(
                              botIdForConfig!,
                              name: workflowName.trim(),
                              actions:
                                  actions
                                      .map((item) => Map<String, dynamic>.from(item))
                                      .toList(),
                            );

                            if (!context.mounted) {
                              return;
                            }

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Workflow "$workflowName" saved (${actions.length} action(s)).',
                                ),
                              ),
                            );
                          },
                  icon: const Icon(Icons.save_as),
                  label: const Text('Save as Workflow'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      botIdForConfig == null
                          ? null
                          : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => GlobalVariablesPage(
                                      botId: botIdForConfig!,
                                    ),
                              ),
                            );
                          },
                  icon: const Icon(Icons.key),
                  label: const Text('Global Variables'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      botIdForConfig == null
                          ? null
                          : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) =>
                                        WorkflowsPage(botId: botIdForConfig!),
                              ),
                            );
                          },
                  icon: const Icon(Icons.account_tree),
                  label: const Text('Workflows'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
