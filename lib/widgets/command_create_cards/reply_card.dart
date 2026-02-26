import 'package:bot_creator/routes/app/command.response_workflow.dart';
import 'package:bot_creator/widgets/response_embeds_editor.dart';
import 'package:flutter/material.dart';

class ReplyCard extends StatelessWidget {
  final TextEditingController responseController;
  final Widget variableSuggestionBar;
  final List<Map<String, dynamic>> responseEmbeds;
  final ValueChanged<List<Map<String, dynamic>>> onEmbedsChanged;
  final Map<String, dynamic> responseWorkflow;
  final Map<String, dynamic> Function(Map<String, dynamic>) normalizeWorkflow;
  final List<String> variableNames;
  final ValueChanged<Map<String, dynamic>> onWorkflowChanged;
  final String workflowSummary;

  const ReplyCard({
    super.key,
    required this.responseController,
    required this.variableSuggestionBar,
    required this.responseEmbeds,
    required this.onEmbedsChanged,
    required this.responseWorkflow,
    required this.normalizeWorkflow,
    required this.variableNames,
    required this.onWorkflowChanged,
    required this.workflowSummary,
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
              "Command Reply",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              "Text response + up to 10 embeds",
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            TextFormField(
              autocorrect: false,
              maxLines: 4,
              minLines: 2,
              keyboardType: TextInputType.multiline,
              controller: responseController,
              decoration: const InputDecoration(
                labelText: "Response Text",
                border: OutlineInputBorder(),
                helperText:
                    "Used as slash-command reply text. Supports placeholders like ((userName)).",
              ),
            ),
            variableSuggestionBar,
            const SizedBox(height: 12),
            ResponseEmbedsEditor(
              embeds: responseEmbeds,
              onChanged: onEmbedsChanged,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final nextWorkflow = await Navigator.push<Map<String, dynamic>>(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => CommandResponseWorkflowPage(
                          initialWorkflow: normalizeWorkflow(responseWorkflow),
                          variableSuggestions: variableNames,
                        ),
                  ),
                );

                if (nextWorkflow != null) {
                  onWorkflowChanged(normalizeWorkflow(nextWorkflow));
                }
              },
              icon: const Icon(Icons.account_tree_outlined),
              label: const Text('Configure Response Workflow'),
            ),
            const SizedBox(height: 6),
            Text(
              workflowSummary,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
