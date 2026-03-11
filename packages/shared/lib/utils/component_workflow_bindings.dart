import 'package:bot_creator_shared/types/component.dart';
import 'package:bot_creator_shared/utils/interaction_listener_registry.dart';
import 'package:bot_creator_shared/utils/workflow_call.dart';

class ComponentWorkflowBinding {
  final String customId;
  final String workflowName;
  final String workflowEntryPoint;
  final Map<String, String> workflowArguments;
  final String type;

  const ComponentWorkflowBinding({
    required this.customId,
    required this.workflowName,
    this.workflowEntryPoint = '',
    this.workflowArguments = const <String, String>{},
    required this.type,
  });
}

List<ComponentWorkflowBinding> extractComponentWorkflowBindings({
  required ComponentV2Definition definition,
  required String Function(String) resolve,
}) {
  final bindings = <ComponentWorkflowBinding>[];

  void collect(ComponentNode node) {
    if (node is ButtonNode) {
      if (node.style != BcButtonStyle.link &&
          node.customId.trim().isNotEmpty &&
          node.workflowName.trim().isNotEmpty) {
        bindings.add(
          ComponentWorkflowBinding(
            customId: resolve(node.customId).trim(),
            workflowName: resolve(node.workflowName).trim(),
            workflowEntryPoint: resolve(node.workflowEntryPoint).trim(),
            workflowArguments: resolveWorkflowCallArguments(
              node.workflowArguments,
              resolve,
            ),
            type: 'button',
          ),
        );
      }
      return;
    }

    if (node is SelectMenuNode) {
      if (node.customId.trim().isNotEmpty &&
          node.workflowName.trim().isNotEmpty) {
        bindings.add(
          ComponentWorkflowBinding(
            customId: resolve(node.customId).trim(),
            workflowName: resolve(node.workflowName).trim(),
            workflowEntryPoint: resolve(node.workflowEntryPoint).trim(),
            workflowArguments: resolveWorkflowCallArguments(
              node.workflowArguments,
              resolve,
            ),
            type: 'select',
          ),
        );
      }
      return;
    }

    if (node is ActionRowNode) {
      for (final child in node.components) {
        collect(child);
      }
      return;
    }

    if (node is ContainerNode) {
      for (final child in node.components) {
        collect(child);
      }
      return;
    }

    if (node is SectionNode) {
      for (final child in node.components) {
        collect(child);
      }
      if (node.accessory != null) {
        collect(node.accessory!);
      }
      return;
    }

    if (node is LabelNode && node.component != null) {
      collect(node.component!);
    }
  }

  for (final node in definition.components) {
    collect(node);
  }

  return bindings;
}

void registerComponentWorkflowBindings({
  required ComponentV2Definition definition,
  required String Function(String) resolve,
  required String botId,
  String? guildId,
  String? channelId,
  Duration ttl = const Duration(hours: 24),
}) {
  final bindings = extractComponentWorkflowBindings(
    definition: definition,
    resolve: resolve,
  );

  if (bindings.isEmpty) {
    return;
  }

  final expiresAt = DateTime.now().add(ttl);
  for (final binding in bindings) {
    if (binding.customId.isEmpty || binding.workflowName.isEmpty) {
      continue;
    }
    InteractionListenerRegistry.instance.register(
      binding.customId,
      ListenerEntry(
        botId: botId,
        workflowName: binding.workflowName,
        workflowEntryPoint: binding.workflowEntryPoint,
        workflowArguments: binding.workflowArguments,
        expiresAt: expiresAt,
        type: binding.type,
        oneShot: false,
        guildId: guildId,
        channelId: channelId,
      ),
    );
  }
}
