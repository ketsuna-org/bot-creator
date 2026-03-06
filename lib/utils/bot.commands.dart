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
      final isConditionalModal =
          useCondition && (whenTrueType == 'modal' || whenFalseType == 'modal');

      final shouldDefer =
          actionsJson.isNotEmpty &&
          workflow['autoDeferIfActions'] != false &&
          !isBaseModal &&
          !isConditionalModal;
      final isEphemeral =
          workflow['visibility']?.toString().toLowerCase() == 'ephemeral';

      var didDefer = false;

      try {
        if (shouldDefer) {
          int deferFlags = isEphemeral ? 64 : 0;
          if (responseType == 'componentV2' ||
              (useCondition &&
                  (whenTrueType == 'componentV2' ||
                      whenFalseType == 'componentV2'))) {
            deferFlags |= 32768; // IS_COMPONENTS_V2
          }

          if (deferFlags == 0 || deferFlags == 64) {
            await interaction.acknowledge(isEphemeral: isEphemeral);
          } else {
            final builder = InteractionResponseBuilder(
              type: InteractionCallbackType.deferredChannelMessageWithSource,
              data: {'flags': deferFlags},
            );
            await interaction.manager.createResponse(
              interaction.id,
              interaction.token,
              builder,
            );
          }

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

        await sendWorkflowResponse(
          interaction: interaction,
          response: response,
          runtimeVariables: runtimeVariables,
          botId: clientId,
          didDefer: didDefer,
          isEphemeral: isEphemeral,
          onLog: (msg, {required botId}) async {
            appendBotLog(msg, botId: botId);
          },
          onDebugLog: (msg, {required botId}) async {
            appendBotDebugLog(msg, botId: botId);
          },
        );
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
