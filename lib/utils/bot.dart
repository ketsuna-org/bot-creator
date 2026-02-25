import 'dart:async';
import 'dart:convert';
import 'package:bot_creator/main.dart';
import 'package:bot_creator/actions/handler.dart';
import 'package:bot_creator/types/action.dart';
import 'package:bot_creator/utils/database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:logging/logging.dart';
import 'package:nyxx/nyxx.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:developer' as developer;
import 'package:bot_creator/utils/global.dart';

NyxxGateway? _desktopGateway;
StreamSubscription<LogRecord>? _desktopNyxxLogsSubscription;

const int _maxBotLogLines = 500;
final StreamController<List<String>> _botLogsController =
    StreamController<List<String>>.broadcast();
List<String> _botLogs = <String>[];
String? _activeBotLogBotId;
bool _debugBotLogsEnabled = false;

bool get isDesktopBotRunning => _desktopGateway != null;
bool get isBotDebugLogsEnabled => _debugBotLogsEnabled;

void setBotDebugLogsEnabled(bool enabled) {
  _debugBotLogsEnabled = enabled;
  appendBotLog(
    enabled ? 'Mode debug logs activé' : 'Mode debug logs désactivé',
  );
}

String _two(int value) => value < 10 ? '0$value' : '$value';

String _timestampNow() {
  final now = DateTime.now();
  return '${_two(now.hour)}:${_two(now.minute)}:${_two(now.second)}';
}

dynamic _extractJsonPath(dynamic data, String rawPath) {
  var path = rawPath.trim();
  if (path.isEmpty) {
    return null;
  }

  if (path.startsWith(r'$.')) {
    path = path.substring(2);
  } else if (path.startsWith(r'$')) {
    path = path.substring(1);
  }

  if (path.isEmpty) {
    return data;
  }

  final segments = <Object>[];
  final token = StringBuffer();

  void flushToken() {
    if (token.isNotEmpty) {
      segments.add(token.toString());
      token.clear();
    }
  }

  for (var index = 0; index < path.length; index++) {
    final char = path[index];
    if (char == '.') {
      flushToken();
      continue;
    }

    if (char == '[') {
      flushToken();
      final closing = path.indexOf(']', index + 1);
      if (closing == -1) {
        return null;
      }
      final indexText = path.substring(index + 1, closing).trim();
      final listIndex = int.tryParse(indexText);
      if (listIndex == null) {
        return null;
      }
      segments.add(listIndex);
      index = closing;
      continue;
    }

    token.write(char);
  }

  flushToken();

  dynamic current = data;
  for (final segment in segments) {
    if (segment is String) {
      if (segment.isEmpty) {
        continue;
      }
      if (current is Map && current.containsKey(segment)) {
        current = current[segment];
      } else {
        return null;
      }
      continue;
    }

    if (segment is int) {
      if (current is List && segment >= 0 && segment < current.length) {
        current = current[segment];
      } else {
        return null;
      }
    }
  }

  return current;
}

String? _resolveComputedVariable(String key, Map<String, String> updates) {
  final marker = '.body.';
  final markerIndex = key.indexOf(marker);
  if (markerIndex == -1) {
    return null;
  }

  final bodyVariableKey = key.substring(0, markerIndex + '.body'.length);
  final jsonPathRaw = key.substring(markerIndex + marker.length);
  if (!jsonPathRaw.startsWith(r'$')) {
    return null;
  }

  final rawBody = updates[bodyVariableKey];
  if (rawBody == null || rawBody.isEmpty) {
    return null;
  }

  dynamic decoded;
  try {
    decoded = jsonDecode(rawBody);
  } catch (_) {
    return null;
  }

  final extracted = _extractJsonPath(decoded, jsonPathRaw);
  if (extracted == null) {
    return null;
  }

  if (extracted is String) {
    return extracted;
  }
  if (extracted is num || extracted is bool) {
    return extracted.toString();
  }

  return jsonEncode(extracted);
}

void _publishBotLogs() {
  if (_botLogsController.isClosed) {
    return;
  }
  _botLogsController.add(List<String>.unmodifiable(_botLogs));
}

Stream<List<String>> getBotLogsStream() => _botLogsController.stream;

List<String> getBotLogsSnapshot() => List<String>.unmodifiable(_botLogs);

void startBotLogSession({required String botId}) {
  _activeBotLogBotId = botId;
  _botLogs = <String>[];
  appendBotLog('Session de logs démarrée', botId: botId);
}

void appendBotLog(String message, {String? botId}) {
  if (_activeBotLogBotId != null &&
      botId != null &&
      _activeBotLogBotId != botId) {
    return;
  }
  final line = '[${_timestampNow()}] $message';
  _botLogs.add(line);
  if (_botLogs.length > _maxBotLogLines) {
    _botLogs = _botLogs.sublist(_botLogs.length - _maxBotLogLines);
  }
  _publishBotLogs();
}

void appendBotDebugLog(String message, {String? botId}) {
  if (!_debugBotLogsEnabled) {
    return;
  }
  appendBotLog('DEBUG: $message', botId: botId);
}

String _formatNyxxLogRecord(LogRecord record) {
  final buffer = StringBuffer(
    '[${record.level.name}] [${record.loggerName}] ${record.message}',
  );
  if (record.error != null) {
    buffer.write(' | error=${record.error}');
  }
  return buffer.toString();
}

void _bindDesktopNyxxLogs({String? botId}) {
  _desktopNyxxLogsSubscription?.cancel();
  Logger.root.level = Level.ALL;
  _desktopNyxxLogsSubscription = Logger.root.onRecord.listen((record) {
    final name = record.loggerName;
    if (!name.startsWith('CardiaKexa')) {
      return;
    }
    appendBotDebugLog(_formatNyxxLogRecord(record), botId: botId);
  });
}

void consumeForegroundTaskDataForBotLogs(Object data) {
  if (data is! Map) {
    return;
  }
  final map = Map<String, dynamic>.from(data.cast<dynamic, dynamic>());
  if (map['type'] != 'bot_log') {
    return;
  }
  final botId = map['botId']?.toString();
  final message = map['message']?.toString();
  if (message == null || message.isEmpty) {
    return;
  }
  appendBotLog(message, botId: botId);
}

Future<void> _emitTaskLogToMain(String message, {String? botId}) async {
  try {
    FlutterForegroundTask.sendDataToMain(<String, dynamic>{
      'type': 'bot_log',
      'botId': botId,
      'message': message,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  } catch (_) {}
}

Future<void> _emitTaskDebugLogToMain(String message, {String? botId}) async {
  if (!_debugBotLogsEnabled) {
    return;
  }
  await _emitTaskLogToMain('DEBUG: $message', botId: botId);
}

/// Convert the intents configuration map to GatewayIntents
Flags<GatewayIntents> buildGatewayIntents(Map<String, bool>? intentsMap) {
  if (intentsMap == null || intentsMap.isEmpty) {
    return GatewayIntents.allUnprivileged;
  }

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

  // If no intents were selected, use allUnprivileged as default
  if (intents == GatewayIntents.none) {
    return GatewayIntents.allUnprivileged;
  }

  return intents;
}

Future<void> startDesktopBot(String token) async {
  if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
    throw Exception('Desktop bot mode is only available on desktop platforms.');
  }

  if (_desktopGateway != null) {
    appendBotLog('Le bot desktop est déjà en cours d’exécution');
    return;
  }
  appendBotLog('Démarrage du bot desktop...');
  appendBotDebugLog('Plateforme desktop détectée');

  // Get the bot's configured intents from the database
  final botUser = await getDiscordUser(token);
  final appData = await appManager.getApp(botUser.id.toString());
  final intentsMap = Map<String, bool>.from(appData['intents'] as Map? ?? {});
  final intents = buildGatewayIntents(intentsMap);
  _bindDesktopNyxxLogs(botId: botUser.id.toString());
  appendBotDebugLog(
    'Intents actifs: ${intentsMap.entries.where((e) => e.value).length}',
    botId: botUser.id.toString(),
  );

  final gateway = await Nyxx.connectGateway(
    token,
    intents,
    options: GatewayClientOptions(
      loggerName: 'CardiaKexaDesktop',
      plugins: [Logging(logLevel: Level.ALL)],
    ),
  );

  gateway.onReady.listen((event) async {
    appendBotLog(
      'Bot desktop connecté et prêt',
      botId: event.gateway.client.user.id.toString(),
    );
    appManager = AppManager();
    gateway.onInteractionCreate.listen((event) async {
      await handleLocalCommands(event, appManager);
    });
  });

  _desktopGateway = gateway;
}

Future<void> stopDesktopBot() async {
  appendBotLog('Arrêt du bot desktop demandé');
  await _desktopGateway?.close();
  _desktopGateway = null;
  await _desktopNyxxLogsSubscription?.cancel();
  _desktopNyxxLogsSubscription = null;
}

@pragma('vm:entry-point')
String updateString(String initial, Map<String, String> updates) {
  final placeholderRegex = RegExp(r'\(\((.*?)\)\)', caseSensitive: false);

  return initial.replaceAllMapped(placeholderRegex, (Match match) {
    final content = match.group(1)!;
    final keys = content.split('|').map((k) => k.trim()).toList();

    for (final key in keys) {
      if (updates.containsKey(key)) {
        return updates[key]!;
      }

      final computed = _resolveComputedVariable(key, updates);
      if (computed != null) {
        return computed;
      }
    }

    return ''; // Aucune clé trouvée -> remplacement par chaîne vide
  });
}

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
      final actionsJson = List<Map<String, dynamic>>.from(
        (value["actions"] as List?)?.whereType<Map>().map(
              (e) => Map<String, dynamic>.from(e),
            ) ??
            const [],
      );

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
          final actions = actionsJson.map(Action.fromJson).toList();
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
          );
          for (final entry in actionResults.entries) {
            runtimeVariables['action.${entry.key}'] = entry.value;
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

Future<void> startService() async {
  debugPrint('[Bot] startService() called');
  // Start the foreground service
  await FlutterForegroundTask.startService(
    serviceId: 110,
    notificationTitle: "Bot is running",
    notificationText: "Bot is running in the background",
    callback: startCallback,
    notificationButtons: [NotificationButton(id: "stop", text: "Stop")],
  );
}

@pragma('vm:entry-point')
void startCallback() {
  ui.DartPluginRegistrant.ensureInitialized();
  debugPrint('[Bot] startCallback() invoked');
  FlutterForegroundTask.setTaskHandler(DiscordBotTaskHandler());
}

@pragma('vm:entry-point')
void stopCallback() {
  FlutterForegroundTask.stopService();
}

@pragma('vm:entry-point')
class DiscordBotTaskHandler extends TaskHandler {
  NyxxGateway? client;
  bool isReady = false;
  AppManager? _manager;
  String? _botId;
  StreamSubscription<LogRecord>? _mobileNyxxLogsSubscription;

  void _bindMobileNyxxLogs() {
    unawaited(_mobileNyxxLogsSubscription?.cancel());
    Logger.root.level = Level.ALL;
    _mobileNyxxLogsSubscription = Logger.root.onRecord.listen((record) {
      final name = record.loggerName;
      if (!name.startsWith('CardiaKexa')) {
        return;
      }
      unawaited(
        _emitTaskDebugLogToMain(_formatNyxxLogRecord(record), botId: _botId),
      );
    });
  }

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter taskStarter) async {
    // Initialiser le client Discord
    ui.DartPluginRegistrant.ensureInitialized();
    debugPrint('[Bot] DiscordBotTaskHandler.onStart()');
    await _emitTaskLogToMain('Service mobile démarré');
    developer.log("Starting Discord bot", name: "DiscordBotTaskHandler");
    _manager ??= AppManager();

    final token = await FlutterForegroundTask.getData<String>(key: "token");
    debugPrint(
      '[Bot] token present: ${token != null && token.trim().isNotEmpty}',
    );
    if (token != null && token.toString().trim().isNotEmpty) {
      try {
        _bindMobileNyxxLogs();
        await _emitTaskLogToMain('Token trouvé, connexion en cours');
        await _emitTaskDebugLogToMain('Longueur token: ${token.length}');
        developer.log("Token: $token", name: "DiscordBotTaskHandler");

        // Get the bot's configured intents from the database
        final botUser = await getDiscordUser(token);
        _botId = botUser.id.toString();
        await _emitTaskLogToMain(
          'Authentification Discord réussie (${botUser.username})',
          botId: _botId,
        );
        final appData = await _manager!.getApp(botUser.id.toString());
        final intentsMap = Map<String, bool>.from(
          appData['intents'] as Map? ?? {},
        );
        final intents = buildGatewayIntents(intentsMap);
        await _emitTaskDebugLogToMain(
          'Intents actifs: ${intentsMap.entries.where((e) => e.value).length}',
          botId: _botId,
        );

        final gateway = await Nyxx.connectGateway(
          token,
          intents,
          options: GatewayClientOptions(
            loggerName: "CardiaKexa",
            plugins: [Logging(logLevel: Level.ALL)],
          ),
        );
        gateway.onReady.listen((event) async {
          debugPrint('[Bot] Gateway connected and ready');
          await _emitTaskLogToMain(
            'Bot mobile connecté et prêt',
            botId: _botId,
          );
          isReady = true;
          gateway.onInteractionCreate.listen((event) async {
            // Traiter les interactions
            await handleLocalCommands(event, _manager!);
          });
        });

        client = gateway;
      } catch (e) {
        debugPrint('[Bot] Failed to connect to Discord: $e');
        await _emitTaskLogToMain(
          'Échec de connexion Discord: $e',
          botId: _botId,
        );
        developer.log(
          "Failed to connect to Discord: $e",
          name: "DiscordBotTaskHandler",
        );
      }
    } else {
      debugPrint('[Bot] Token not found or empty');
      await _emitTaskLogToMain('Token absent ou vide');
      developer.log("Token not found or empty", name: "DiscordBotTaskHandler");
    }
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == "stop") {
      unawaited(
        _emitTaskLogToMain(
          'Arrêt demandé depuis la notification',
          botId: _botId,
        ),
      );
      stopCallback();
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _mobileNyxxLogsSubscription?.cancel();
    _mobileNyxxLogsSubscription = null;
    await client?.close();
    client = null;
    if (isTimeout) {
      // let's restart the service
      await _emitTaskLogToMain(
        'Service interrompu (timeout), redémarrage...',
        botId: _botId,
      );
      developer.log("Service timeout", name: "DiscordBotTaskHandler");
      await startService();
    } else {
      await _emitTaskLogToMain('Service arrêté', botId: _botId);
      developer.log("Service stopped", name: "DiscordBotTaskHandler");
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    unawaited(_emitTaskLogToMain('Heartbeat service', botId: _botId));
    developer.log("Repeat event", name: "DiscordBotTaskHandler");
  }
}

Future<void> createCommand(
  NyxxRest client,
  ApplicationCommandBuilder commandBuilder, {
  Map<String, dynamic> data = const {},
}) async {
  try {
    final command = await client.commands.create(commandBuilder);
    Map<String, dynamic> commandData = {
      "name": command.name,
      "description": command.description,
      "id": command.id.toString(),
      "createdAt": DateTime.now().toIso8601String(),
    };
    if (data.isNotEmpty) {
      commandData["data"] = data;
    }
    appManager.saveAppCommand(
      client.user.id.toString(),
      command.id.toString(),
      commandData,
    );
  } catch (e) {
    throw Exception("Failed to create command: $e");
  }
}

Future<void> updateCommand(
  NyxxRest client,
  Snowflake commandId, {
  required ApplicationCommandUpdateBuilder commandBuilder,
  Map<String, dynamic> data = const {},
}) async {
  // let's check what we are gonna update
  try {
    final command = await client.commands.update(commandId, commandBuilder);
    Map<String, dynamic> commandData = {
      "name": command.name,
      "description": command.description,
      "id": command.id.toString(),
      "updatedAt": DateTime.now().toIso8601String(),
    };

    if (data.isNotEmpty) {
      commandData["data"] = data;
    }
    appManager.saveAppCommand(
      client.user.id.toString(),
      command.id.toString(),
      commandData,
    );
  } catch (e) {
    throw Exception("Failed to update command: $e");
  }
}
