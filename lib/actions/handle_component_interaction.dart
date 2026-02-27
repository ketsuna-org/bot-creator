import 'package:nyxx/nyxx.dart';
import 'package:bot_creator/utils/interaction_listener_registry.dart';
import 'package:bot_creator/utils/database.dart';
import 'package:bot_creator/types/action.dart';
import 'package:bot_creator/actions/handler.dart';

/// Called by the main bot event loop when a MessageComponentInteraction arrives.
/// Looks up the listener registry and if a matching workflow is found, runs it.
Future<void> handleComponentInteraction(
  NyxxGateway client,
  MessageComponentInteraction interaction,
  AppManager manager,
) async {
  final customId = interaction.data.customId;
  final entry = InteractionListenerRegistry.instance.get(customId);

  if (entry == null) {
    // No listener registered for this customId — ignore silently
    return;
  }

  // Defer acknowledgement immediately to avoid 3-second timeout
  await interaction.acknowledge();

  // Remove listener if one-shot
  if (entry.oneShot) {
    InteractionListenerRegistry.instance.remove(customId);
  }

  // Build variables for the workflow
  final variables = <String, String>{
    'interaction.customId': customId,
    'interaction.userId':
        interaction.user?.id.toString() ??
        interaction.member?.user?.id.toString() ??
        '',
    'interaction.guildId': interaction.guildId?.toString() ?? '',
    'interaction.channelId': interaction.channelId?.toString() ?? '',
    // For select menus, provide selected values as comma-separated list
    'interaction.values': interaction.data.values?.join(',') ?? '',
  };

  await _runListenerWorkflow(
    client: client,
    manager: manager,
    botId: entry.botId,
    workflowName: entry.workflowName,
    variables: variables,
  );
}

/// Called when a ModalSubmitInteraction arrives.
Future<void> handleModalSubmitInteraction(
  NyxxGateway client,
  ModalSubmitInteraction interaction,
  AppManager manager,
) async {
  final customId = interaction.data.customId;
  final entry = InteractionListenerRegistry.instance.get(customId);

  if (entry == null) return;

  // Always defer modal before doing anything else
  await interaction.acknowledge();
  InteractionListenerRegistry.instance.remove(customId);

  // Build variables: one per modal input field
  final variables = <String, String>{
    'modal.customId': customId,
    'interaction.userId':
        interaction.user?.id.toString() ??
        interaction.member?.user?.id.toString() ??
        '',
    'interaction.guildId': interaction.guildId?.toString() ?? '',
    'interaction.channelId': interaction.channelId?.toString() ?? '',
  };

  // Extract each text input's value from submitted components
  // ModalSubmitInteractionData.components is List<SubmittedComponent>
  // Each SubmittedComponent is typically an ActionRowComponent that contains
  // SubmittedTextInputComponents.
  for (final component in interaction.data.components) {
    if (component is SubmittedActionRowComponent) {
      for (final inner in component.components) {
        if (inner is SubmittedTextInputComponent) {
          variables['modal.${inner.customId}'] = inner.value ?? '';
        }
      }
    }
  }

  await _runListenerWorkflow(
    client: client,
    manager: manager,
    botId: entry.botId,
    workflowName: entry.workflowName,
    variables: variables,
  );
}

/// Shared helper that loads and executes a saved workflow with injected variables.
Future<void> _runListenerWorkflow({
  required NyxxGateway client,
  required AppManager manager,
  required String botId,
  required String workflowName,
  required Map<String, String> variables,
}) async {
  try {
    final workflow = await manager.getWorkflowByName(botId, workflowName);
    if (workflow == null) return;

    final actions = List<Action>.from(
      ((workflow['actions'] as List?) ?? const <dynamic>[])
          .whereType<Map>()
          .map((json) => Action.fromJson(Map<String, dynamic>.from(json))),
    );

    String resolveTemplate(String input) {
      String result = input;
      for (final e in variables.entries) {
        result = result.replaceAll('((${e.key}))', e.value);
      }
      return result;
    }

    await handleListenerWorkflowActions(
      client,
      actions: actions,
      manager: manager,
      botId: botId,
      variables: variables,
      resolveTemplate: resolveTemplate,
    );
  } catch (_) {
    // Swallow errors in background handlers
  }
}
