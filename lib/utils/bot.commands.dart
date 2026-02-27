part of 'bot.dart';

@pragma('vm:entry-point')
Future<void> handleLocalCommands(
  InteractionCreateEvent event,
  AppManager manager,
) async {
  final interaction = event.interaction;
  final clientId = event.gateway.client.user.id.toString();
  if (interaction is ApplicationCommandInteraction) {
    appendBotLog('Commande reçue: ${interaction.data.name}', botId: clientId);
    await _emitTaskLogToMain(
      'Commande reçue: ${interaction.data.name}',
      botId: clientId,
    );
    final command = interaction.data;
    final action = await manager.getAppCommand(clientId, command.id.toString());
    appendBotDebugLog(
      'Lookup commande id=${command.id} trouvé=${action["id"] == command.id.toString()}',
      botId: clientId,
    );

    if (action["id"] == command.id.toString()) {
      final listOfArgs = await generateKeyValues(interaction);
      final runtimeVariables = <String, String>{...listOfArgs};
      final globalVars = await manager.getGlobalVariables(clientId);
      for (final entry in globalVars.entries) {
        runtimeVariables['global.${entry.key}'] = entry.value;
      }
      appendBotDebugLog(
        'Arguments générés: ${runtimeVariables.length}',
        botId: clientId,
      );

      final normalized = manager.normalizeCommandData(
        Map<String, dynamic>.from(action),
      );
      final value = Map<String, dynamic>.from(
        (normalized["data"] as Map?)?.cast<String, dynamic>() ?? const {},
      );
      final response = Map<String, dynamic>.from(
        (value["response"] as Map?)?.cast<String, dynamic>() ?? const {},
      );
      final workflow = Map<String, dynamic>.from(
        (response['workflow'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
      final workflowConditional = Map<String, dynamic>.from(
        (workflow['conditional'] as Map?)?.cast<String, dynamic>() ?? const {},
      );

      // Récupérer les actions : d'abord de la commande, puis du workflow sauvegardé si spécifié
      var actionsJson = List<Map<String, dynamic>>.from(
        (value["actions"] as List?)?.whereType<Map>().map(
              (e) => Map<String, dynamic>.from(e),
            ) ??
            const [],
      );

      appendBotDebugLog(
        'Actions trouvées dans la commande: ${actionsJson.length}',
        botId: clientId,
      );
      if (actionsJson.isNotEmpty) {
        for (var i = 0; i < actionsJson.length; i++) {
          final action = actionsJson[i];
          appendBotDebugLog(
            'Action $i: type=${action["type"]}, enabled=${action["enabled"]}',
            botId: clientId,
          );
        }
      }

      // Si un workflow sauvegardé est spécifié, le charger et utiliser ses actions
      final workflowName = (workflow['name'] ?? '').toString().trim();
      if (workflowName.isNotEmpty && actionsJson.isEmpty) {
        try {
          final savedWorkflows = await manager.getWorkflows(clientId);
          final savedWorkflow = savedWorkflows.firstWhere(
            (w) =>
                (w['name'] ?? '').toString().toLowerCase() ==
                workflowName.toLowerCase(),
            orElse: () => <String, dynamic>{},
          );
          if (savedWorkflow.isNotEmpty) {
            actionsJson = List<Map<String, dynamic>>.from(
              (savedWorkflow['actions'] as List?)?.whereType<Map>().map(
                    (e) => Map<String, dynamic>.from(e),
                  ) ??
                  const [],
            );
            appendBotDebugLog(
              'Workflow sauvegardé chargé: $workflowName avec ${actionsJson.length} actions',
              botId: clientId,
            );
          }
        } catch (e) {
          appendBotDebugLog(
            'Erreur lors du chargement du workflow $workflowName: $e',
            botId: clientId,
          );
        }
      }

      final responseType = (response['type'] ?? 'normal').toString();
      final isBaseModal = responseType == 'modal';

      final whenTrueType =
          (workflowConditional['whenTrueType'] ?? 'normal').toString();
      final whenFalseType =
          (workflowConditional['whenFalseType'] ?? 'normal').toString();
      final useCondition = workflowConditional['enabled'] == true;
      final conditionVariable =
          (workflowConditional['variable'] ?? '').toString().trim();
      final isConditionalModal =
          useCondition && (whenTrueType == 'modal' || whenFalseType == 'modal');

      final shouldDefer =
          actionsJson.isNotEmpty &&
          workflow['autoDeferIfActions'] != false &&
          !isBaseModal &&
          !isConditionalModal;
      final isEphemeral =
          workflow['visibility']?.toString().toLowerCase() == 'ephemeral';
      final whenTrueText =
          (workflowConditional['whenTrueText'] ?? '').toString();
      final whenFalseText =
          (workflowConditional['whenFalseText'] ?? '').toString();
      final whenTrueEmbeds =
          (workflowConditional['whenTrueEmbeds'] is List)
              ? List<Map<String, dynamic>>.from(
                (workflowConditional['whenTrueEmbeds'] as List)
                    .whereType<Map>()
                    .map((embed) => Map<String, dynamic>.from(embed)),
              )
              : <Map<String, dynamic>>[];
      final whenFalseEmbeds =
          (workflowConditional['whenFalseEmbeds'] is List)
              ? List<Map<String, dynamic>>.from(
                (workflowConditional['whenFalseEmbeds'] as List)
                    .whereType<Map>()
                    .map((embed) => Map<String, dynamic>.from(embed)),
              )
              : <Map<String, dynamic>>[];

      var didDefer = false;

      try {
        if (shouldDefer) {
          await interaction.acknowledge(isEphemeral: isEphemeral);
          didDefer = true;
          appendBotLog('Réponse différée (defer ACK)', botId: clientId);
          await _emitTaskLogToMain(
            'Réponse différée (defer ACK)',
            botId: clientId,
          );
        }

        if (actionsJson.isNotEmpty) {
          appendBotDebugLog(
            'Actions à exécuter: ${actionsJson.length}',
            botId: clientId,
          );
          try {
            final actions = actionsJson.map(Action.fromJson).toList();
            appendBotDebugLog(
              'Actions converties en Action objects: ${actions.length}',
              botId: clientId,
            );
            final actionResults = await handleActions(
              event.gateway.client,
              interaction,
              actions: actions,
              manager: manager,
              botId: clientId,
              variables: runtimeVariables,
              resolveTemplate:
                  (input) => updateString(
                    input,
                    Map<String, String>.from(runtimeVariables),
                  ),
              onLog: (msg) {
                appendBotLog(msg, botId: clientId);
                unawaited(_emitTaskLogToMain(msg, botId: clientId));
              },
            );
            appendBotDebugLog(
              'Actions exécutées, résultats: ${actionResults.length}',
              botId: clientId,
            );
            for (final entry in actionResults.entries) {
              runtimeVariables['action.${entry.key}'] = entry.value;
            }
            // Debug: log all action.* variables (include counts even if '0')
            final actionVars =
                runtimeVariables.entries
                    .where((e) => e.key.startsWith('action.'))
                    .map((e) => '${e.key}=${e.value}')
                    .toList();
            appendBotDebugLog(
              'Action runtime variables: $actionVars',
              botId: clientId,
            );
          } catch (e, st) {
            appendBotDebugLog(
              'Erreur lors de l\'exécution des actions: $e',
              botId: clientId,
            );
            appendBotDebugLog('Stack: $st', botId: clientId);
          }
        }

        var activeResponseType = responseType;
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
          final variableValue =
              (runtimeVariables[conditionVariable] ?? '').trim();
          final conditionMatched = variableValue.isNotEmpty;
          appendBotDebugLog(
            'Condition variable=$conditionVariable matched=$conditionMatched',
            botId: clientId,
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
                            customId: updateString(
                              input.customId,
                              runtimeVariables,
                            ),
                            // ignore: deprecated_member_use
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
              await interaction.respondModal(modalBuilder);
              appendBotLog('Modal envoyé', botId: clientId);
              await _emitTaskLogToMain('Modal envoyé', botId: clientId);
            } catch (e) {
              appendBotLog('Erreur construction modal: $e', botId: clientId);
            }
          }
        } else {
          appendBotDebugLog(
            'Embeds détectés: ${embedsRaw.length}',
            botId: clientId,
          );

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

            if (title.isNotEmpty) {
              embed.title = title;
            }
            if (description.isNotEmpty) {
              embed.description = description;
            }
            if (url.isNotEmpty) {
              embed.url = Uri.tryParse(url);
            }

            final timestampRaw = (embedJson['timestamp'] ?? '').toString();
            final timestamp = DateTime.tryParse(timestampRaw);
            if (timestamp != null) {
              embed.timestamp = timestamp;
            }

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
              (embedJson['footer'] as Map?)?.cast<String, dynamic>() ??
                  const {},
            );
            final footerText = (footerJson['text'] ?? '').toString();
            final footerIcon = (footerJson['icon_url'] ?? '').toString();
            if (footerText.isNotEmpty || footerIcon.isNotEmpty) {
              embed.footer = EmbedFooterBuilder(
                text: footerText,
                iconUrl:
                    footerIcon.isNotEmpty ? Uri.tryParse(footerIcon) : null,
              );
            }

            final authorJson = Map<String, dynamic>.from(
              (embedJson['author'] as Map?)?.cast<String, dynamic>() ??
                  const {},
            );
            final authorName = (authorJson['name'] ?? '').toString();
            final authorUrl = (authorJson['url'] ?? '').toString();
            final authorIcon = (authorJson['icon_url'] ?? '').toString();
            if (authorName.isNotEmpty ||
                authorUrl.isNotEmpty ||
                authorIcon.isNotEmpty) {
              embed.author = EmbedAuthorBuilder(
                name: authorName,
                url: authorUrl.isNotEmpty ? Uri.tryParse(authorUrl) : null,
                iconUrl:
                    authorIcon.isNotEmpty ? Uri.tryParse(authorIcon) : null,
              );
            }

            final imageJson = Map<String, dynamic>.from(
              (embedJson['image'] as Map?)?.cast<String, dynamic>() ?? const {},
            );
            final imageUrl = (imageJson['url'] ?? '').toString();
            if (imageUrl.isNotEmpty) {
              embed.image = EmbedImageBuilder(url: Uri.parse(imageUrl));
            }

            final thumbnailJson = Map<String, dynamic>.from(
              (embedJson['thumbnail'] as Map?)?.cast<String, dynamic>() ??
                  const {},
            );
            final thumbnailUrl = (thumbnailJson['url'] ?? '').toString();
            if (thumbnailUrl.isNotEmpty) {
              embed.thumbnail = EmbedThumbnailBuilder(
                url: Uri.parse(thumbnailUrl),
              );
            }

            final fields =
                (embedJson['fields'] is List)
                    ? List<Map<String, dynamic>>.from(
                      (embedJson['fields'] as List).whereType<Map>().map(
                        (field) => Map<String, dynamic>.from(field),
                      ),
                    )
                    : <Map<String, dynamic>>[];

            for (final field in fields.take(25)) {
              final fieldName = (field['name'] ?? '').toString();
              final fieldValue = (field['value'] ?? '').toString();
              if (fieldName.isEmpty || fieldValue.isEmpty) {
                continue;
              }

              (embed.fields ??= []).add(
                EmbedFieldBuilder(
                  name: fieldName,
                  value: fieldValue,
                  isInline: field['inline'] == true,
                ),
              );
            }

            embeds.add(embed);
          }

          List<ComponentBuilder>? componentNodes;
          if (activeResponseType == 'componentV2' ||
              activeResponseType == 'normal') {
            if (activeComponentsJson.isNotEmpty) {
              try {
                final built = buildComponentNodes(
                  definition: ComponentV2Definition.fromJson(
                    activeComponentsJson,
                  ),
                  resolve: (s) => updateString(s, runtimeVariables),
                );
                if (built.isNotEmpty) {
                  componentNodes = built;
                }
              } catch (e) {
                appendBotLog(
                  'Erreur construction components: $e',
                  botId: clientId,
                );
              }
            }
          }

          final finalText =
              responseText.isEmpty &&
                      embeds.isEmpty &&
                      (componentNodes?.isEmpty ?? true)
                  ? 'Command executed successfully.'
                  : responseText;

          if (didDefer) {
            final updateBuilder = MessageUpdateBuilder(
              content: finalText.isEmpty ? null : finalText,
              components: componentNodes,
            );
            if (embeds.isNotEmpty) {
              updateBuilder.embeds = embeds;
            } else {
              updateBuilder.embeds = [];
            }

            await interaction.updateOriginalResponse(updateBuilder);
            appendBotLog('Réponse éditée après defer', botId: clientId);
            await _emitTaskLogToMain(
              'Réponse éditée après defer',
              botId: clientId,
            );
            // deletion after defer if requested (only when action flagged deleteItself)
            final matching =
                runtimeVariables.entries
                    .where(
                      (entry) =>
                          (entry.key.toLowerCase().endsWith('deleteitself') ||
                              entry.key.toLowerCase().endsWith(
                                'deleteresponse',
                              )) &&
                          entry.value.toString().toLowerCase() == 'true',
                    )
                    .toList();
            if (matching.isNotEmpty) {
              appendBotLog(
                'Entries triggering delete: $matching',
                botId: clientId,
              );
              try {
                await interaction.deleteOriginalResponse();
                appendBotLog(
                  'Réponse supprimée automatiquement',
                  botId: clientId,
                );
              } catch (_) {}
            }
          } else {
            await interaction.respond(
              MessageBuilder(
                content: finalText.isEmpty ? null : finalText,
                embeds: embeds.isEmpty ? null : embeds,
                components: componentNodes,
                flags: isEphemeral ? MessageFlags.ephemeral : null,
              ),
            );
            appendBotLog('Réponse envoyée', botId: clientId);
            await _emitTaskLogToMain('Réponse envoyée', botId: clientId);

            // if any action requested deletion of the response itself, do it now
            final matching =
                runtimeVariables.entries
                    .where(
                      (entry) =>
                          (entry.key.toLowerCase().endsWith('deleteitself') ||
                              entry.key.toLowerCase().endsWith(
                                'deleteresponse',
                              )) &&
                          entry.value.toString().toLowerCase() == 'true',
                    )
                    .toList();
            if (matching.isNotEmpty) {
              appendBotLog(
                'Entries triggering delete: $matching',
                botId: clientId,
              );
              try {
                // with respond() we might not immediately have the message id, but deleteOriginalResponse works
                await interaction.deleteOriginalResponse();
                appendBotLog(
                  'Réponse supprimée automatiquement',
                  botId: clientId,
                );
              } catch (_) {
                // ignore; maybe already deleted or ephemeral
              }
            }
          }
        }
      } catch (error, stackTrace) {
        appendBotLog('Erreur workflow commande: $error', botId: clientId);
        appendBotDebugLog('$stackTrace', botId: clientId);
        final errorText = 'An error occurred while executing this command.';

        try {
          if (didDefer) {
            await interaction.updateOriginalResponse(
              MessageUpdateBuilder(
                content: errorText,
                embeds: const <EmbedBuilder>[],
              ),
            );
          } else {
            await interaction.respond(
              MessageBuilder(
                content: errorText,
                flags: isEphemeral ? MessageFlags.ephemeral : null,
              ),
            );
          }
        } catch (sendError) {
          appendBotLog(
            'Impossible d\'envoyer le message d\'erreur: $sendError',
            botId: clientId,
          );
        }
      }

      return;
    } else {
      await interaction.respond(MessageBuilder(content: "Command not found"));
      appendBotLog('Commande introuvable', botId: clientId);
      await _emitTaskLogToMain('Commande introuvable', botId: clientId);
      return;
    }
  } else if (interaction is MessageComponentInteraction) {
    // Route to the interaction listener registry
    await handleComponentInteraction(
      event.gateway.client,
      interaction,
      manager,
    );
  } else if (interaction is ModalSubmitInteraction) {
    // Route modal submit to the interaction listener registry
    await handleModalSubmitInteraction(
      event.gateway.client,
      interaction,
      manager,
    );
  }
}
