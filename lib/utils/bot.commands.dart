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

      final shouldDefer =
          actionsJson.isNotEmpty && workflow['autoDeferIfActions'] != false;
      final isEphemeral =
          workflow['visibility']?.toString().toLowerCase() == 'ephemeral';
      final useCondition = workflowConditional['enabled'] == true;
      final conditionVariable =
          (workflowConditional['variable'] ?? '').toString().trim();
      final whenTrueText =
          (workflowConditional['whenTrueText'] ?? '').toString();
      final whenFalseText =
          (workflowConditional['whenFalseText'] ?? '').toString();

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
          } catch (e, st) {
            appendBotDebugLog(
              'Erreur lors de l\'exécution des actions: $e',
              botId: clientId,
            );
            appendBotDebugLog('Stack: $st', botId: clientId);
          }
        }

        String responseText = (response["text"] ?? "").toString();
        responseText = updateString(responseText, runtimeVariables);

        if (useCondition && conditionVariable.isNotEmpty) {
          final variableValue =
              (runtimeVariables[conditionVariable] ?? '').trim();
          final conditionMatched = variableValue.isNotEmpty;
          appendBotDebugLog(
            'Condition variable=$conditionVariable matched=$conditionMatched',
            botId: clientId,
          );

          if (conditionMatched && whenTrueText.trim().isNotEmpty) {
            responseText = updateString(whenTrueText, runtimeVariables);
          } else if (!conditionMatched && whenFalseText.trim().isNotEmpty) {
            responseText = updateString(whenFalseText, runtimeVariables);
          }
        }

        final embedsRaw =
            (response['embeds'] is List)
                ? List<Map<String, dynamic>>.from(
                  (response['embeds'] as List).whereType<Map>().map(
                    (embed) => Map<String, dynamic>.from(embed),
                  ),
                )
                : <Map<String, dynamic>>[];
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
            (embed as dynamic).timestamp = timestamp;
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
              (embed as dynamic).color = DiscordColor(colorInt);
            }
          }

          final footerJson = Map<String, dynamic>.from(
            (embedJson['footer'] as Map?)?.cast<String, dynamic>() ?? const {},
          );
          final footerText = (footerJson['text'] ?? '').toString();
          final footerIcon = (footerJson['icon_url'] ?? '').toString();
          if (footerText.isNotEmpty || footerIcon.isNotEmpty) {
            (embed as dynamic).footer = EmbedFooterBuilder(
              text: footerText,
              iconUrl: footerIcon.isNotEmpty ? Uri.tryParse(footerIcon) : null,
            );
          }

          final authorJson = Map<String, dynamic>.from(
            (embedJson['author'] as Map?)?.cast<String, dynamic>() ?? const {},
          );
          final authorName = (authorJson['name'] ?? '').toString();
          final authorUrl = (authorJson['url'] ?? '').toString();
          final authorIcon = (authorJson['icon_url'] ?? '').toString();
          if (authorName.isNotEmpty ||
              authorUrl.isNotEmpty ||
              authorIcon.isNotEmpty) {
            (embed as dynamic).author = EmbedAuthorBuilder(
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
            (embed as dynamic).image = EmbedImageBuilder(
              url: Uri.parse(imageUrl),
            );
          }

          final thumbnailJson = Map<String, dynamic>.from(
            (embedJson['thumbnail'] as Map?)?.cast<String, dynamic>() ??
                const {},
          );
          final thumbnailUrl = (thumbnailJson['url'] ?? '').toString();
          if (thumbnailUrl.isNotEmpty) {
            (embed as dynamic).thumbnail = EmbedThumbnailBuilder(
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

            (embed as dynamic).fields.add(
              EmbedFieldBuilder(
                name: fieldName,
                value: fieldValue,
                isInline: field['inline'] == true,
              ),
            );
          }

          embeds.add(embed);
        }

        final finalText =
            responseText.isEmpty && embeds.isEmpty
                ? 'Command executed successfully.'
                : responseText;

        if (didDefer) {
          await interaction.updateOriginalResponse(
            MessageUpdateBuilder(
              content: finalText.isEmpty ? null : finalText,
              embeds: embeds,
            ),
          );
          appendBotLog('Réponse éditée après defer', botId: clientId);
          await _emitTaskLogToMain(
            'Réponse éditée après defer',
            botId: clientId,
          );
        } else {
          await interaction.respond(
            MessageBuilder(
              content: finalText.isEmpty ? null : finalText,
              embeds: embeds.isEmpty ? null : embeds,
              flags: isEphemeral ? MessageFlags.ephemeral : null,
            ),
          );
          appendBotLog('Réponse envoyée', botId: clientId);
          await _emitTaskLogToMain('Réponse envoyée', botId: clientId);
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
  }
}
