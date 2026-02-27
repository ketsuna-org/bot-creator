import 'package:flutter/material.dart';
import 'package:bot_creator/types/variable_suggestion.dart';
import 'package:bot_creator/widgets/variable_text_field.dart';
import 'package:bot_creator/routes/app/command.response_workflow.dart';
import 'package:bot_creator/widgets/response_embeds_editor.dart';
import 'package:bot_creator/widgets/component_v2_builder/component_v2_editor.dart';
import 'package:bot_creator/widgets/component_v2_builder/normal_component_editor.dart';
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
  final List<VariableSuggestion> variableSuggestions;
  final String? botIdForConfig;
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
    required this.variableSuggestions,
    this.botIdForConfig,
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
              VariableTextField(
                label: "Response Text",
                initialValue: responseController.text,
                maxLines: 4,
                suggestions: variableSuggestions,
                onChanged: (v) {
                  responseController.text = v;
                },
                helperText:
                    "Used as slash-command reply text. Supports ((variable)) syntax.",
              ),
              // external suggestion bar provided by parent (e.g. command creation page)
              variableSuggestionBar,
              const SizedBox(height: 12),
              ResponseEmbedsEditor(
                embeds: responseEmbeds,
                onChanged: onEmbedsChanged,
              ),
              const SizedBox(height: 12),
              ExpansionTile(
                title: const Text('Message Components (Buttons/Selects)'),
                collapsedBackgroundColor: Colors.grey.withValues(alpha: 0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                ),
                collapsedShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                ),
                childrenPadding: const EdgeInsets.all(8.0),
                children: [
                  NormalComponentEditorWidget(
                    definition: ComponentV2Definition.fromJson(
                      responseComponents,
                    ),
                    onChanged: (def) => onComponentsChanged(def.toJson()),
                    variableSuggestions: variableSuggestions,
                  ),
                ],
              ),
            ] else if (responseType == 'componentV2') ...[
              ComponentV2EditorWidget(
                definition: ComponentV2Definition.fromJson(responseComponents),
                onChanged: (def) => onComponentsChanged(def.toJson()),
                variableSuggestions: variableSuggestions,
              ),
            ] else if (responseType == 'modal') ...[
              ModalBuilderWidget(
                modal: ModalDefinition.fromJson(responseModal),
                onChanged: (def) => onModalChanged(def.toJson()),
                variableSuggestions: variableSuggestions,
                botIdForConfig: botIdForConfig,
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
                          variableSuggestions: variableSuggestions,
                          botIdForConfig: botIdForConfig,
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
