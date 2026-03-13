import 'package:nyxx/nyxx.dart';
import '../types/component.dart';
import 'package:bot_creator_shared/utils/template_resolver.dart'; // for updateString
import '../utils/component_workflow_bindings.dart';
import '../utils/interaction_listener_registry.dart';
import '../utils/workflow_call.dart';
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
        ((activeResponseType == 'normal'
                        ? workflowConditional['whenTrueNormalComponents']
                        : workflowConditional['whenTrueComponents'])
                    as Map?)
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
        ((activeResponseType == 'normal'
                        ? workflowConditional['whenFalseNormalComponents']
                        : workflowConditional['whenFalseComponents'])
                    as Map?)
                ?.cast<String, dynamic>() ??
            const {},
      );
    }
  }

  responseText = resolveTemplatePlaceholders(responseText, runtimeVariables);
  final isModal = activeResponseType == 'modal';

  if (isModal) {
    if (activeModalJson.isNotEmpty) {
      try {
        final definition = ModalDefinition.fromJson(activeModalJson);
        final modalBuilder = ModalBuilder(
          title: resolveTemplatePlaceholders(
            definition.title,
            runtimeVariables,
          ),
          customId: resolveTemplatePlaceholders(
            definition.customId,
            runtimeVariables,
          ),
          components:
              definition.inputs.map((input) {
                return ActionRowBuilder(
                  components: [
                    TextInputBuilder(
                      customId: resolveTemplatePlaceholders(
                        input.customId,
                        runtimeVariables,
                      ),
                      label: resolveTemplatePlaceholders(
                        input.label,
                        runtimeVariables,
                      ),
                      style:
                          input.style == BcTextInputStyle.paragraph
                              ? TextInputStyle.paragraph
                              : TextInputStyle.short,
                      placeholder:
                          input.placeholder.isNotEmpty
                              ? resolveTemplatePlaceholders(
                                input.placeholder,
                                runtimeVariables,
                              )
                              : null,
                      value:
                          input.defaultValue.isNotEmpty
                              ? resolveTemplatePlaceholders(
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
          final onSubmitWorkflow =
              resolveTemplatePlaceholders(
                definition.onSubmitWorkflow!,
                runtimeVariables,
              ).trim();
          if (onSubmitWorkflow.isNotEmpty) {
            final onSubmitArguments = resolveWorkflowCallArguments(
              definition.onSubmitArguments,
              (value) => resolveTemplatePlaceholders(value, runtimeVariables),
            );
            InteractionListenerRegistry.instance.register(
              resolveTemplatePlaceholders(
                definition.customId,
                runtimeVariables,
              ),
              ListenerEntry(
                botId: botId,
                workflowName: onSubmitWorkflow,
                workflowEntryPoint:
                    resolveTemplatePlaceholders(
                      definition.onSubmitEntryPoint,
                      runtimeVariables,
                    ).trim(),
                workflowArguments: onSubmitArguments,
                expiresAt: DateTime.now().add(const Duration(hours: 1)),
                type: 'modal',
                oneShot: true,
                guildId: interaction.guildId?.toString(),
                channelId: interaction.channelId?.toString(),
              ),
            );
          }
        }

        onLog?.call('Modal envoyÃ©', botId: botId);
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

    Uri? resolveEmbedUri(dynamic raw) {
      final resolved =
          resolveTemplatePlaceholders(
            (raw ?? '').toString(),
            runtimeVariables,
          ).trim();
      if (resolved.isEmpty) {
        return null;
      }
      final uri = Uri.tryParse(resolved);
      if (uri == null || !uri.hasScheme) {
        return null;
      }
      return uri;
    }

    final embeds = <EmbedBuilder>[];
    for (final embedJson in embedsRaw.take(10)) {
      embedJson.remove('video');
      embedJson.remove('provider');
      final embed = EmbedBuilder();
      final title = resolveTemplatePlaceholders(
        (embedJson['title'] ?? '').toString(),
        runtimeVariables,
      );
      final description = resolveTemplatePlaceholders(
        (embedJson['description'] ?? '').toString(),
        runtimeVariables,
      );
      final embedUrl = resolveEmbedUri(embedJson['url']);

      if (title.isNotEmpty) embed.title = title;
      if (description.isNotEmpty) embed.description = description;
      if (embedUrl != null) embed.url = embedUrl;

      final timestamp = DateTime.tryParse(
        resolveTemplatePlaceholders(
          (embedJson['timestamp'] ?? '').toString(),
          runtimeVariables,
        ).trim(),
      );
      if (timestamp != null) embed.timestamp = timestamp;

      final colorRaw =
          resolveTemplatePlaceholders(
            (embedJson['color'] ?? '').toString(),
            runtimeVariables,
          ).trim();
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
      final footerText = resolveTemplatePlaceholders(
        (footerJson['text'] ?? '').toString(),
        runtimeVariables,
      );
      final footerIconUri = resolveEmbedUri(footerJson['icon_url']);
      if (footerText.isNotEmpty || footerIconUri != null) {
        embed.footer = EmbedFooterBuilder(
          text: footerText,
          iconUrl: footerIconUri,
        );
      }

      final authorJson = Map<String, dynamic>.from(
        (embedJson['author'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
      final authorName = resolveTemplatePlaceholders(
        (authorJson['name'] ?? '').toString(),
        runtimeVariables,
      );
      final authorUrlUri = resolveEmbedUri(authorJson['url']);
      final authorIconUri = resolveEmbedUri(
        authorJson['author_icon_url'] ?? authorJson['icon_url'],
      );
      if (authorName.isNotEmpty) {
        embed.author = EmbedAuthorBuilder(
          name: authorName,
          url: authorUrlUri,
          iconUrl: authorIconUri,
        );
      }

      final imageJson = Map<String, dynamic>.from(
        (embedJson['image'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
      final imageUri = resolveEmbedUri(imageJson['url']);
      if (imageUri != null) {
        embed.image = EmbedImageBuilder(url: imageUri);
      }

      final thumbnailJson = Map<String, dynamic>.from(
        (embedJson['thumbnail'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
      final thumbnailUri = resolveEmbedUri(thumbnailJson['url']);
      if (thumbnailUri != null) {
        embed.thumbnail = EmbedThumbnailBuilder(url: thumbnailUri);
      }

      final fieldList =
          (embedJson['fields'] as List?)?.whereType<Map>() ?? const [];
      for (final fieldJson in fieldList.take(25)) {
        final name = resolveTemplatePlaceholders(
          (fieldJson['name'] ?? '').toString(),
          runtimeVariables,
        );
        final value = resolveTemplatePlaceholders(
          (fieldJson['value'] ?? '').toString(),
          runtimeVariables,
        );
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
    ComponentV2Definition? activeComponentDefinition;
    if (activeResponseType == 'componentV2' || activeResponseType == 'normal') {
      if (activeComponentsJson.isNotEmpty) {
        try {
          activeComponentDefinition = ComponentV2Definition.fromJson(
            activeComponentsJson,
          );
          final built = buildComponentNodes(
            definition: activeComponentDefinition,
            resolve: (s) => resolveTemplatePlaceholders(s, runtimeVariables),
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
        'Actions dÃ©jÃ  traitÃ©es, pas de rÃ©ponse par dÃ©faut',
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
        onLog?.call('RÃ©ponse Ã©ditÃ©e aprÃ¨s defer', botId: botId);
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
        onLog?.call('RÃ©ponse envoyÃ©e', botId: botId);
      } else {}
    }

    if (activeComponentDefinition != null) {
      registerComponentWorkflowBindings(
        definition: activeComponentDefinition,
        resolve: (s) => resolveTemplatePlaceholders(s, runtimeVariables),
        botId: botId,
        guildId: interaction.guildId?.toString(),
        channelId: interaction.channelId?.toString(),
      );
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
          onLog?.call('RÃ©ponse supprimÃ©e automatiquement', botId: botId);
        }
      } catch (_) {}
    }
  }
}
