import 'package:flutter/material.dart';

class WorkflowDocumentationPage extends StatelessWidget {
  const WorkflowDocumentationPage({super.key});

  Widget _section({
    required String title,
    required List<Widget> children,
    IconData icon = Icons.article_outlined,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _p(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(height: 1.35)),
    );
  }

  Widget _mono(String text) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: SelectableText(
        text,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Workflow Documentation')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section(
            title: 'What A Workflow Is',
            icon: Icons.account_tree_outlined,
            children: [
              _p(
                'A workflow is a reusable action pipeline. It can be called from command actions, button clicks, select menus, modal submit handlers, or another workflow.',
              ),
              _p(
                'This lets you centralize logic in one place and avoid duplicating the same actions across many commands.',
              ),
            ],
          ),
          _section(
            title: 'Entry Point',
            icon: Icons.route_outlined,
            children: [
              _p(
                'Each workflow has a default entry point. A caller can override it with a specific entry point name.',
              ),
              _p(
                'Use this to model multiple sub-routines inside a single workflow (for example: create / close / assign).',
              ),
              _mono(
                'Workflow: ticket_manager\n'
                'Default entry: main\n\n'
                'Caller A -> entryPoint: create\n'
                'Caller B -> entryPoint: close',
              ),
            ],
          ),
          _section(
            title: 'Arguments',
            icon: Icons.input_outlined,
            children: [
              _p(
                'Workflow arguments are call-time inputs. You can define required arguments and optional defaults.',
              ),
              _p(
                'At runtime, arguments are available through dynamic variables, such as:',
              ),
              _mono(
                '((arg.ticketId))\n'
                '((workflow.arg.ticketId))\n'
                '((workflow.args))',
              ),
              _p(
                'If an argument is missing and has no default, the workflow call can fail depending on your action flow.',
              ),
            ],
          ),
          _section(
            title: 'How Calls Work',
            icon: Icons.play_circle_outline,
            children: [
              _p(
                'When a component/action calls a workflow, the runtime resolves:',
              ),
              _p('1. Target workflow name'),
              _p('2. Entry point override (or default workflow entry point)'),
              _p('3. Call arguments merged with workflow argument defaults'),
              _p(
                'Then the selected workflow actions execute in the caller context.',
              ),
            ],
          ),
          _section(
            title: 'Caller Context',
            icon: Icons.hub_outlined,
            children: [
              _p(
                'A workflow called from a button/select/modal receives interaction context from that caller event.',
              ),
              _p(
                'This means you can write one shared workflow and reuse it from multiple components.',
              ),
              _mono(
                'Button "Close Ticket"\n'
                '  call workflow: ticket_manager\n'
                '  entryPoint: close\n'
                '  args: {"ticketId":"((channel.id))"}',
              ),
            ],
          ),
          _section(
            title: 'Recommended Design',
            icon: Icons.lightbulb_outline,
            children: [
              _p('Use one workflow per domain, not per button.'),
              _p(
                'Keep entry points explicit and stable: create, update, close, submit, confirm.',
              ),
              _p(
                'Pass only necessary arguments; avoid oversized JSON payloads.',
              ),
              _p(
                'Use defaults for optional arguments and mark critical args as required.',
              ),
            ],
          ),
          _section(
            title: 'Debug Checklist',
            icon: Icons.bug_report_outlined,
            children: [
              _p('If a call does not execute as expected, verify:'),
              _p('1. Workflow name exists and is spelled correctly'),
              _p('2. Entry point exists in your workflow logic'),
              _p('3. Required arguments are provided'),
              _p('4. Argument variable placeholders resolve to values'),
              _p('5. Action order and response/defer behavior are correct'),
            ],
          ),
        ],
      ),
    );
  }
}
