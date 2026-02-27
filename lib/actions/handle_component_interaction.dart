import 'package:nyxx/nyxx.dart';
import 'package:bot_creator/utils/interaction_listener_registry.dart';
import 'package:bot_creator/utils/database.dart';
import 'package:bot_creator/utils/template_resolver.dart';
import 'package:bot_creator/types/action.dart';
import 'package:bot_creator/actions/handler.dart';
import 'package:bot_creator/actions/interaction_response.dart';

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

  // Remove listener if one-shot
  if (entry.oneShot) {
    InteractionListenerRegistry.instance.remove(customId);
  }

  // Build variables for the workflow
  final fallbackChannelId = (interaction as dynamic)?.channel?.id as Snowflake?;
  final guildId = (interaction as dynamic)?.guildId as Snowflake?;
  final variables = <String, String>{
    'interaction.customId': customId,
    'interaction.userId':
        interaction.user?.id.toString() ??
        interaction.member?.user?.id.toString() ??
        '',
    'interaction.guildId': guildId?.toString() ?? '',
    'interaction.channelId': fallbackChannelId?.toString() ?? '',
    // For select menus, provide selected values as comma-separated list
    'interaction.values': interaction.data.values?.join(',') ?? '',
  };

  await _runListenerWorkflow(
    client: client,
    manager: manager,
    botId: entry.botId,
    workflowName: entry.workflowName,
    variables: variables,
    interaction: interaction,
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

  if (entry == null) {
    return;
  }

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
    interaction: interaction,
  );
}

/// Shared helper that loads and executes a saved workflow with injected variables.
Future<void> _runListenerWorkflow({
  required NyxxGateway client,
  required AppManager manager,
  required String botId,
  required String workflowName,
  required Map<String, String> variables,
  Interaction? interaction,
}) async {
  try {
    final workflow = await manager.getWorkflowByName(botId, workflowName);
    if (workflow == null) return;

    // Merge variables with global ones if needed?
    // For now we assume they are passed or loaded by handleActions
    // But handleActions expects variables.

    final actions = List<Action>.from(
      ((workflow['actions'] as List?) ?? const <dynamic>[])
          .whereType<Map>()
          .map((json) => Action.fromJson(Map<String, dynamic>.from(json))),
    );

    String resolveTemplate(String input) =>
        resolveTemplatePlaceholders(input, variables);

    await handleListenerWorkflowActions(
      client,
      actions: actions,
      manager: manager,
      botId: botId,
      variables: variables,
      resolveTemplate: resolveTemplate,
      interaction: interaction,
    );

    // 3. Send final response (text, embeds, components, modal)
    // Configure response details from workflow JSON
    final response = Map<String, dynamic>.from(
      (workflow['response'] as Map?)?.cast<String, dynamic>() ?? const {},
    );

    if (interaction != null) {
      final isEphemeral =
          workflow['visibility']?.toString().toLowerCase() == 'ephemeral';

      await sendWorkflowResponse(
        interaction: interaction,
        response: response,
        runtimeVariables: variables,
        botId: botId,
        isEphemeral: isEphemeral,
        // didDefer is false here because we removed the blind acknowledge()
        didDefer: false,
      );
    }
  } catch (e) {
    // Swallow errors in background handlers
  }
}
