import 'package:bot_creator/routes/app/command.response_workflow.dart';
import 'package:bot_creator/widgets/response_embeds_editor.dart';
import 'package:flutter/material.dart';
import 'package:bot_creator/widgets/component_v2_builder/component_v2_editor.dart';
import 'package:bot_creator/widgets/component_v2_builder/modal_builder.dart';
import 'package:bot_creator/types/component.dart';

class ReplyCard extends StatelessWidget {
  final String responseType;
  final ValueChanged<String> onResponseTypeChanged;
  final TextEditingController responseController;
  final Widget variableSuggestionBar;
  final List<Map<String, dynamic>> responseEmbeds;
  final ValueChanged<List<Map<String, dynamic>>> onEmbedsChanged;
  final Map<String, dynamic> responseComponents;
  final ValueChanged<Map<String, dynamic>> onComponentsChanged;
  final Map<String, dynamic> responseModal;
  final ValueChanged<Map<String, dynamic>> onModalChanged;
  final Map<String, dynamic> responseWorkflow;
  final Map<String, dynamic> Function(Map<String, dynamic>) normalizeWorkflow;
  final List<String> variableNames;
  final ValueChanged<Map<String, dynamic>> onWorkflowChanged;
  final String workflowSummary;

  const ReplyCard({
    super.key,
    required this.responseType,
    required this.onResponseTypeChanged,
    required this.responseController,
    required this.variableSuggestionBar,
    required this.responseEmbeds,
    required this.onEmbedsChanged,
    required this.responseComponents,
    required this.onComponentsChanged,
    required this.responseModal,
    required this.onModalChanged,
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
              "Choose the type of response to send",
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'normal',
                  icon: Icon(Icons.message),
                  label: Text('Normal Reply'),
                ),
                ButtonSegment(
                  value: 'componentV2',
                  icon: Icon(Icons.dashboard_customize),
                  label: Text('Component V2'),
                ),
                ButtonSegment(
                  value: 'modal',
                  icon: Icon(Icons.web_asset),
                  label: Text('Modal Form'),
                ),
              ],
              selected: {responseType},
              onSelectionChanged: (set) => onResponseTypeChanged(set.first),
            ),
            const SizedBox(height: 16),
            if (responseType == 'normal') ...[
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
              ExpansionTile(
                title: const Text('Message Components (Buttons/Selects)'),
                collapsedBackgroundColor: Colors.grey.withOpacity(0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                ),
                collapsedShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                ),
                childrenPadding: const EdgeInsets.all(8.0),
                children: [
                  ComponentV2EditorWidget(
                    definition: ComponentV2Definition.fromJson(
                      responseComponents,
                    ),
                    onChanged: (def) => onComponentsChanged(def.toJson()),
                  ),
                ],
              ),
            ] else if (responseType == 'componentV2') ...[
              ComponentV2EditorWidget(
                definition: ComponentV2Definition.fromJson(responseComponents),
                onChanged: (def) => onComponentsChanged(def.toJson()),
              ),
            ] else if (responseType == 'modal') ...[
              ModalBuilderWidget(
                modal: ModalDefinition.fromJson(responseModal),
                onChanged: (def) => onModalChanged(def.toJson()),
              ),
            ],
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
