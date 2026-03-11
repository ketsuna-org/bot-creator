import 'dart:async';

import 'package:bot_creator_shared/actions/handle_component_interaction.dart';
import 'package:bot_creator_shared/actions/handler.dart';
import 'package:bot_creator_shared/actions/interaction_response.dart';
import 'package:bot_creator_shared/bot/bot_config.dart';
import 'package:bot_creator_shared/utils/global.dart';
import 'package:bot_creator_shared/utils/template_resolver.dart';
import 'package:bot_creator_shared/types/action.dart';
import 'package:nyxx/nyxx.dart';

import 'runner_data_store.dart';

final _log = Logger('BotRunner');

/// Connects to Discord via nyxx, registers command listeners, and dispatches
/// interactions to the shared action handlers — matching commands by their Discord ID.
class DiscordRunner {
  final BotConfig config;
  final RunnerDataStore store;

  NyxxGateway? _gateway;

  DiscordRunner(this.config) : store = RunnerDataStore(config);

  Future<void> start() async {
    _log.info('Starting runner with ${config.commands.length} command(s)...');

    final intents = _buildIntents(config.intents);
    _gateway = await Nyxx.connectGateway(
      config.token,
      intents,
      options: GatewayClientOptions(
        loggerName: 'BotCreatorRunner',
        plugins: [Logging(logLevel: Level.INFO)],
      ),
    );

    _gateway!.onReady.listen((event) {
      final botId = event.gateway.client.user.id.toString();
      _log.info('Bot ready — bot ID: $botId');
    });

    _gateway!.onInteractionCreate.listen((event) async {
      await _handleInteraction(event);
    });

    _log.info('Gateway connected — listening for interactions.');
  }

  Future<void> stop() async {
    await _gateway?.close();
    _gateway = null;
    _log.info('Runner stopped.');
  }

  // ── Internal ─────────────────────────────────────────────────────────────

  Future<void> _handleInteraction(InteractionCreateEvent event) async {
    final interaction = event.interaction;
    final client = event.gateway.client;
    final botId = client.user.id.toString();

    if (interaction is ApplicationCommandInteraction) {
      final commandId = interaction.data.id.toString();

      // Match by Discord command ID (same logic as bot.commands.dart)
      final commandData = _findCommand(commandId);
      if (commandData == null) {
        _log.warning('Command $commandId not found in config');
        await _safeRespond(
          interaction,
          'Command not found.',
          isEphemeral: true,
        );
        return;
      }

      await _executeCommand(
        client: client,
        botId: botId,
        interaction: interaction,
        commandData: commandData,
      );
    } else if (interaction is MessageComponentInteraction) {
      await handleComponentInteraction(client, interaction, store);
    } else if (interaction is ModalSubmitInteraction) {
      await handleModalSubmitInteraction(client, interaction, store);
    }
  }

  Map<String, dynamic>? _findCommand(String discordCommandId) {
    for (final cmd in config.commands) {
      if ((cmd['id'] ?? '').toString() == discordCommandId) {
        return cmd;
      }
    }
    return null;
  }

  Future<void> _executeCommand({
    required NyxxGateway client,
    required String botId,
    required ApplicationCommandInteraction interaction,
    required Map<String, dynamic> commandData,
  }) async {
    final data = Map<String, dynamic>.from(
      (commandData['data'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    final value = Map<String, dynamic>.from(
      (data['data'] as Map?)?.cast<String, dynamic>() ?? data,
    );
    final response = Map<String, dynamic>.from(
      (value['response'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    final workflow = Map<String, dynamic>.from(
      (response['workflow'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    final workflowConditional = Map<String, dynamic>.from(
      (workflow['conditional'] as Map?)?.cast<String, dynamic>() ?? const {},
    );

    // Build runtime variables from interaction
    final runtimeVariables = await generateKeyValues(interaction);
    final globalVars = await store.getGlobalVariables(botId);
    for (final entry in globalVars.entries) {
      runtimeVariables['global.${entry.key}'] = entry.value;
    }

    // Collect actions
    var actionsJson = List<Map<String, dynamic>>.from(
      (value['actions'] as List?)?.whereType<Map>().map(
            (e) => Map<String, dynamic>.from(e),
          ) ??
          const [],
    );

    // If empty, try to load from a named workflow
    final workflowName = (workflow['name'] ?? '').toString().trim();
    if (workflowName.isNotEmpty && actionsJson.isEmpty) {
      final saved = await store.getWorkflowByName(botId, workflowName);
      if (saved != null) {
        actionsJson = List<Map<String, dynamic>>.from(
          (saved['actions'] as List?)?.whereType<Map>().map(
                (e) => Map<String, dynamic>.from(e),
              ) ??
              const [],
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
          deferFlags |= 32768;
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
      }

      if (actionsJson.isNotEmpty) {
        final actions = actionsJson.map(Action.fromJson).toList();
        final actionResults = await handleActions(
          client,
          interaction,
          actions: actions,
          store: store,
          botId: botId,
          variables: runtimeVariables,
          resolveTemplate:
              (input) => resolveTemplatePlaceholders(
                input,
                Map<String, String>.from(runtimeVariables),
              ),
          onLog: (msg) => _log.info(msg),
        );
        for (final entry in actionResults.entries) {
          runtimeVariables['action.${entry.key}'] = entry.value;
        }
      }

      await sendWorkflowResponse(
        interaction: interaction,
        response: response,
        runtimeVariables: runtimeVariables,
        botId: botId,
        didDefer: didDefer,
        isEphemeral: isEphemeral,
        onLog: (msg, {required botId}) async => _log.info(msg),
        onDebugLog: (msg, {required botId}) async => _log.fine(msg),
      );
    } catch (e, st) {
      _log.severe('Error executing command ${commandData['name']}: $e', e, st);
      await _safeErrorResponse(
        interaction,
        didDefer: didDefer,
        isEphemeral: isEphemeral,
      );
    }
  }

  Future<void> _safeRespond(
    Interaction interaction,
    String text, {
    bool isEphemeral = false,
  }) async {
    try {
      await (interaction as dynamic).respond(
        MessageBuilder(
          content: text,
          flags: isEphemeral ? MessageFlags.ephemeral : null,
        ),
      );
    } catch (_) {}
  }

  Future<void> _safeErrorResponse(
    ApplicationCommandInteraction interaction, {
    required bool didDefer,
    required bool isEphemeral,
  }) async {
    const text = 'An error occurred while executing this command.';
    try {
      if (didDefer) {
        await interaction.updateOriginalResponse(
          MessageUpdateBuilder(content: text, embeds: const []),
        );
      } else {
        await interaction.respond(
          MessageBuilder(
            content: text,
            flags: isEphemeral ? MessageFlags.ephemeral : null,
          ),
        );
      }
    } catch (_) {}
  }

  Flags<GatewayIntents> _buildIntents(Map<String, bool> intentsMap) {
    if (intentsMap.isEmpty) return GatewayIntents.allUnprivileged;

    Flags<GatewayIntents> intents = GatewayIntents.none;
    if (intentsMap['Guild Presence'] == true) {
      intents = intents | GatewayIntents.guildPresences;
    }
    if (intentsMap['Guild Members'] == true) {
      intents = intents | GatewayIntents.guildMembers;
    }
    if (intentsMap['Message Content'] == true) {
      intents = intents | GatewayIntents.messageContent;
    }
    if (intentsMap['Direct Messages'] == true) {
      intents = intents | GatewayIntents.directMessages;
    }
    if (intentsMap['Guilds'] == true) {
      intents = intents | GatewayIntents.guilds;
    }
    if (intentsMap['Guild Messages'] == true) {
      intents = intents | GatewayIntents.guildMessages;
    }
    if (intentsMap['Guild Message Reactions'] == true) {
      intents = intents | GatewayIntents.guildMessageReactions;
    }
    if (intentsMap['Direct Message Reactions'] == true) {
      intents = intents | GatewayIntents.directMessageReactions;
    }
    if (intentsMap['Guild Message Typing'] == true) {
      intents = intents | GatewayIntents.guildMessageTyping;
    }
    if (intentsMap['Direct Message Typing'] == true) {
      intents = intents | GatewayIntents.directMessageTyping;
    }
    if (intentsMap['Guild Scheduled Events'] == true) {
      intents = intents | GatewayIntents.guildScheduledEvents;
    }
    if (intentsMap['Auto Moderation Configuration'] == true) {
      intents = intents | GatewayIntents.autoModerationConfiguration;
    }
    if (intentsMap['Auto Moderation Execution'] == true) {
      intents = intents | GatewayIntents.autoModerationExecution;
    }

    return intents == GatewayIntents.none
        ? GatewayIntents.allUnprivileged
        : intents;
  }
}
