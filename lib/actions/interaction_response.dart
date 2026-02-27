import 'package:nyxx/nyxx.dart';
import '../types/component.dart';
import '../utils/bot.dart'; // for updateString
import '../utils/interaction_listener_registry.dart';
import 'send_component_v2.dart';

/// Shared logic to determine and send the final response of a workflow execution.
/// Handles text, embeds, components, modals, and conditional logic.
Future<void> sendWorkflowResponse({
  required Interaction interaction,
  required Map<String, dynamic> response,
  required Map<String, String> runtimeVariables,
  required String botId,
  bool didDefer = false,
  bool isEphemeral = false,
  Future<void> Function(String, {required String botId})? onLog,
  Future<void> Function(String, {required String botId})? onDebugLog,
}) async {
  final workflowConditional = Map<String, dynamic>.from(
    (response['workflow']?['conditional'] as Map?)?.cast<String, dynamic>() ??
        const {},
  );

  final useCondition = workflowConditional['enabled'] == true;
  final conditionVariable =
      (workflowConditional['variable'] ?? '').toString().trim();
  final whenTrueType =
      (workflowConditional['whenTrueType'] ?? 'normal').toString();
  final whenFalseType =
      (workflowConditional['whenFalseType'] ?? 'normal').toString();
  final whenTrueText = (workflowConditional['whenTrueText'] ?? '').toString();
  final whenFalseText = (workflowConditional['whenFalseText'] ?? '').toString();
  final whenTrueEmbeds = List<Map<String, dynamic>>.from(
    (workflowConditional['whenTrueEmbeds'] as List?)?.whereType<Map>() ??
        const [],
  );
  final whenFalseEmbeds = List<Map<String, dynamic>>.from(
    (workflowConditional['whenFalseEmbeds'] as List?)?.whereType<Map>() ??
        const [],
  );

  var activeResponseType = (response['type'] ?? 'normal').toString();
  var activeModalJson = Map<String, dynamic>.from(
    (response['modal'] as Map?)?.cast<String, dynamic>() ?? const {},
  );
  var activeComponentsJson = Map<String, dynamic>.from(
    (response['components'] as Map?)?.cast<String, dynamic>() ?? const {},
  );
  String responseText = (response["text"] ?? "").toString();
  var embedsRaw =
      (response['embeds'] is List)
          ? List<Map<String, dynamic>>.from(
            (response['embeds'] as List).whereType<Map>().map(
              (embed) => Map<String, dynamic>.from(embed),
            ),
          )
          : <Map<String, dynamic>>[];

  if (useCondition && conditionVariable.isNotEmpty) {
    final variableValue = (runtimeVariables[conditionVariable] ?? '').trim();
    final conditionMatched = variableValue.isNotEmpty;
    onDebugLog?.call(
      'Condition variable=$conditionVariable matched=$conditionMatched',
      botId: botId,
    );

    if (conditionMatched) {
      activeResponseType = whenTrueType;
      if (whenTrueText.trim().isNotEmpty) responseText = whenTrueText;
      if (whenTrueEmbeds.isNotEmpty) {
        embedsRaw = List<Map<String, dynamic>>.from(whenTrueEmbeds);
      }
      activeModalJson = Map<String, dynamic>.from(
        (workflowConditional['whenTrueModal'] as Map?)
                ?.cast<String, dynamic>() ??
            const {},
      );
      activeComponentsJson = Map<String, dynamic>.from(
        (workflowConditional['whenTrueComponents'] as Map?)
                ?.cast<String, dynamic>() ??
            const {},
      );
    } else {
      activeResponseType = whenFalseType;
      if (whenFalseText.trim().isNotEmpty) responseText = whenFalseText;
      if (whenFalseEmbeds.isNotEmpty) {
        embedsRaw = List<Map<String, dynamic>>.from(whenFalseEmbeds);
      }
      activeModalJson = Map<String, dynamic>.from(
        (workflowConditional['whenFalseModal'] as Map?)
                ?.cast<String, dynamic>() ??
            const {},
      );
      activeComponentsJson = Map<String, dynamic>.from(
        (workflowConditional['whenFalseComponents'] as Map?)
                ?.cast<String, dynamic>() ??
            const {},
      );
    }
  }

  responseText = updateString(responseText, runtimeVariables);
  final isModal = activeResponseType == 'modal';

  if (isModal) {
    if (activeModalJson.isNotEmpty) {
      try {
        final definition = ModalDefinition.fromJson(activeModalJson);
        final modalBuilder = ModalBuilder(
          title: updateString(definition.title, runtimeVariables),
          customId: updateString(definition.customId, runtimeVariables),
          components:
              definition.inputs.map((input) {
                return ActionRowBuilder(
                  components: [
                    TextInputBuilder(
                      customId: updateString(input.customId, runtimeVariables),
                      label: updateString(input.label, runtimeVariables),
                      style:
                          input.style == BcTextInputStyle.paragraph
                              ? TextInputStyle.paragraph
                              : TextInputStyle.short,
                      placeholder:
                          input.placeholder.isNotEmpty
                              ? updateString(
                                input.placeholder,
                                runtimeVariables,
                              )
                              : null,
                      value:
                          input.defaultValue.isNotEmpty
                              ? updateString(
                                input.defaultValue,
                                runtimeVariables,
                              )
                              : null,
                      isRequired: input.required,
                      minLength: input.minLength,
                      maxLength: input.maxLength,
                    ),
                  ],
                );
              }).toList(),
        );

        if (interaction is ApplicationCommandInteraction) {
          await interaction.respondModal(modalBuilder);
        } else if (interaction is MessageComponentInteraction) {
          await interaction.respondModal(modalBuilder);
        } else {
          onLog?.call(
            'Error: This interaction type does not support modals',
            botId: botId,
          );
          return;
        }

        // Auto-register listener if onSubmitWorkflow is provided
        if (definition.onSubmitWorkflow != null &&
            definition.onSubmitWorkflow!.isNotEmpty) {
          InteractionListenerRegistry.instance.register(
            updateString(definition.customId, runtimeVariables),
            ListenerEntry(
              botId: botId,
              workflowName: definition.onSubmitWorkflow!,
              expiresAt: DateTime.now().add(const Duration(hours: 1)),
              type: 'modal',
              oneShot: true,
              guildId: interaction.guildId?.toString(),
              channelId: interaction.channelId?.toString(),
            ),
          );
        }

        onLog?.call('Modal envoyé', botId: botId);
      } catch (e) {
        onLog?.call('Erreur construction modal: $e', botId: botId);
      }
    }
  } else {
    // Standard text/embed/components reply
    if (embedsRaw.isEmpty) {
      final legacyEmbed = Map<String, dynamic>.from(
        (response['embed'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
      final hasLegacyEmbed =
          (legacyEmbed['title']?.toString().isNotEmpty ?? false) ||
          (legacyEmbed['description']?.toString().isNotEmpty ?? false) ||
          (legacyEmbed['url']?.toString().isNotEmpty ?? false);
      if (hasLegacyEmbed) {
        embedsRaw.add(legacyEmbed);
      }
    }

    final embeds = <EmbedBuilder>[];
    for (final embedJson in embedsRaw.take(10)) {
      embedJson.remove('video');
      embedJson.remove('provider');
      final embed = EmbedBuilder();
      final title = updateString(
        (embedJson['title'] ?? '').toString(),
        runtimeVariables,
      );
      final description = updateString(
        (embedJson['description'] ?? '').toString(),
        runtimeVariables,
      );
      final url = updateString(
        (embedJson['url'] ?? '').toString(),
        runtimeVariables,
      );

      if (title.isNotEmpty) embed.title = title;
      if (description.isNotEmpty) embed.description = description;
      if (url.isNotEmpty) embed.url = Uri.tryParse(url);

      final timestamp = DateTime.tryParse(
        (embedJson['timestamp'] ?? '').toString(),
      );
      if (timestamp != null) embed.timestamp = timestamp;

      final colorRaw = (embedJson['color'] ?? '').toString();
      if (colorRaw.isNotEmpty) {
        int? colorInt;
        if (colorRaw.startsWith('#')) {
          colorInt = int.tryParse(colorRaw.substring(1), radix: 16);
        } else {
          colorInt = int.tryParse(colorRaw);
        }
        if (colorInt != null) {
          embed.color = DiscordColor.fromRgb(
            (colorInt >> 16) & 0xFF,
            (colorInt >> 8) & 0xFF,
            colorInt & 0xFF,
          );
        }
      }

      final footerJson = Map<String, dynamic>.from(
        (embedJson['footer'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
      final footerText = (footerJson['text'] ?? '').toString();
      final footerIcon = (footerJson['icon_url'] ?? '').toString();
      if (footerText.isNotEmpty || footerIcon.isNotEmpty) {
        embed.footer = EmbedFooterBuilder(
          text: footerText,
          iconUrl: footerIcon.isNotEmpty ? Uri.tryParse(footerIcon) : null,
        );
      }

      final authorJson = Map<String, dynamic>.from(
        (embedJson['author'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
      final authorName = (authorJson['name'] ?? '').toString();
      final authorUrl = (authorJson['url'] ?? '').toString();
      final authorIcon =
          (authorJson['author_icon_url'] ?? authorJson['icon_url'] ?? '')
              .toString();
      if (authorName.isNotEmpty) {
        embed.author = EmbedAuthorBuilder(
          name: authorName,
          url: authorUrl.isNotEmpty ? Uri.tryParse(authorUrl) : null,
          iconUrl: authorIcon.isNotEmpty ? Uri.tryParse(authorIcon) : null,
        );
      }

      final imageJson = Map<String, dynamic>.from(
        (embedJson['image'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
      final imageUrl = (imageJson['url'] ?? '').toString();
      if (imageUrl.isNotEmpty) {
        embed.image = EmbedImageBuilder(url: Uri.parse(imageUrl));
      }

      final fieldList =
          (embedJson['fields'] as List?)?.whereType<Map>() ?? const [];
      for (final fieldJson in fieldList.take(25)) {
        final name = (fieldJson['name'] ?? '').toString();
        final value = (fieldJson['value'] ?? '').toString();
        if (name.isNotEmpty && value.isNotEmpty) {
          (embed.fields ??= []).add(
            EmbedFieldBuilder(
              name: name,
              value: value,
              isInline: fieldJson['inline'] == true,
            ),
          );
        }
      }

      embeds.add(embed);
    }

    List<ComponentBuilder>? componentNodes;
    if (activeResponseType == 'componentV2' || activeResponseType == 'normal') {
      if (activeComponentsJson.isNotEmpty) {
        try {
          final built = buildComponentNodes(
            definition: ComponentV2Definition.fromJson(activeComponentsJson),
            resolve: (s) => updateString(s, runtimeVariables),
          );
          if (built.isNotEmpty) componentNodes = built;
        } catch (e) {
          onLog?.call('Erreur construction components: $e', botId: botId);
        }
      }
    }

    // Safe check for acknowledgment state
    bool isResponded = false;
    try {
      // isAcknowledged exists on most Interactions in nyxx 6.x, but not all (e.g. ModalSubmitInteraction)
      isResponded = (interaction as dynamic).isAcknowledged == true;
    } catch (_) {
      isResponded = false;
    }

    final hasCustomResponse =
        responseText.isNotEmpty ||
        embeds.isNotEmpty ||
        (componentNodes?.isNotEmpty ?? false);

    // If no custom response and interaction already responded, just return
    if (isResponded && !hasCustomResponse) {
      onLog?.call(
        'Actions déjà traitées, pas de réponse par défaut',
        botId: botId,
      );
      return;
    }

    final finalText =
        responseText.isEmpty &&
                embeds.isEmpty &&
                (componentNodes?.isEmpty ?? true)
            ? 'Workflow executed successfully.'
            : responseText;

    if (didDefer) {
      final isV2 = activeResponseType == 'componentV2';
      final updateBuilder = MessageUpdateBuilder(
        content: isV2 ? null : (finalText.isEmpty ? null : finalText),
        components: componentNodes,
      );
      if (isV2) {
        updateBuilder.embeds = [];
      } else {
        updateBuilder.embeds = embeds;
      }

      if (interaction is MessageResponse ||
          interaction is ModalSubmitInteraction) {
        await (interaction as dynamic).updateOriginalResponse(updateBuilder);
        onLog?.call('Réponse éditée après defer', botId: botId);
      }
    } else {
      int flagValue = isEphemeral ? MessageFlags.ephemeral.value : 0;
      final isV2 = activeResponseType == 'componentV2';
      if (isV2) flagValue |= 32768; // IS_COMPONENTS_V2

      if (interaction is MessageResponse ||
          interaction is ModalSubmitInteraction) {
        await (interaction as dynamic).respond(
          MessageBuilder(
            content: isV2 ? null : (finalText.isEmpty ? null : finalText),
            embeds: isV2 ? null : (embeds.isEmpty ? null : embeds),
            components: componentNodes,
            flags: flagValue > 0 ? MessageFlags(flagValue) : null,
          ),
        );
        onLog?.call('Réponse envoyée', botId: botId);
      } else {}
    }

    // Auto-delete if requested
    final shouldDelete = runtimeVariables.entries.any(
      (e) =>
          (e.key.toLowerCase().endsWith('deleteitself') ||
              e.key.toLowerCase().endsWith('deleteresponse')) &&
          e.value.toLowerCase() == 'true',
    );

    if (shouldDelete) {
      try {
        if (interaction is MessageResponse ||
            interaction is ModalSubmitInteraction) {
          await (interaction as dynamic).deleteOriginalResponse();
          onLog?.call('Réponse supprimée automatiquement', botId: botId);
        }
      } catch (_) {}
    }
  }
}
