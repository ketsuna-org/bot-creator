import 'package:bot_creator/main.dart';
import 'package:bot_creator/actions/handler.dart';
import 'package:bot_creator/types/action.dart';
import 'package:bot_creator/utils/database.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:nyxx/nyxx.dart';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:bot_creator/utils/global.dart';

NyxxGateway? _desktopGateway;

bool get isDesktopBotRunning => _desktopGateway != null;

Future<void> startDesktopBot(String token) async {
  if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
    throw Exception('Desktop bot mode is only available on desktop platforms.');
  }

  if (_desktopGateway != null) {
    return;
  }

  final gateway = await Nyxx.connectGateway(
    token,
    GatewayIntents.allUnprivileged,
    options: GatewayClientOptions(
      loggerName: 'CardiaKexaDesktop',
      plugins: [Logging(logLevel: Level.ALL)],
    ),
  );

  gateway.onReady.listen((event) async {
    appManager = AppManager();
    gateway.onInteractionCreate.listen((event) async {
      await handleLocalCommands(event, appManager);
    });
  });

  _desktopGateway = gateway;
}

Future<void> stopDesktopBot() async {
  await _desktopGateway?.close();
  _desktopGateway = null;
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
    final command = interaction.data;
    final action = await manager.getAppCommand(clientId, command.id.toString());

    if (action["id"] == command.id.toString()) {
      final listOfArgs = await generateKeyValues(interaction);

      final normalized = manager.normalizeCommandData(
        Map<String, dynamic>.from(action),
      );
      final value = Map<String, dynamic>.from(
        (normalized["data"] as Map?)?.cast<String, dynamic>() ?? const {},
      );
      final response = Map<String, dynamic>.from(
        (value["response"] as Map?)?.cast<String, dynamic>() ?? const {},
      );
      final actionsJson = List<Map<String, dynamic>>.from(
        (value["actions"] as List?)?.whereType<Map>().map(
              (e) => Map<String, dynamic>.from(e),
            ) ??
            const [],
      );

      if (actionsJson.isNotEmpty) {
        final actions = actionsJson.map(Action.fromJson).toList();
        await handleActions(
          event.gateway.client,
          interaction,
          actions: actions,
        );
      }

      String responseText = (response["text"] ?? "").toString();
      responseText = updateString(responseText, listOfArgs);

      final embedsRaw =
          (response['embeds'] is List)
              ? List<Map<String, dynamic>>.from(
                (response['embeds'] as List).whereType<Map>().map(
                  (embed) => Map<String, dynamic>.from(embed),
                ),
              )
              : <Map<String, dynamic>>[];

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
          listOfArgs,
        );
        final description = updateString(
          (embedJson['description'] ?? '').toString(),
          listOfArgs,
        );
        final url = updateString(
          (embedJson['url'] ?? '').toString(),
          listOfArgs,
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
          (embedJson['thumbnail'] as Map?)?.cast<String, dynamic>() ?? const {},
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

      if (embeds.isNotEmpty) {
        await interaction.respond(
          MessageBuilder(
            content: responseText.isEmpty ? null : responseText,
            embeds: embeds,
          ),
        );
      } else {
        await interaction.respond(
          MessageBuilder(
            content:
                responseText.isEmpty
                    ? 'Command executed successfully.'
                    : responseText,
          ),
        );
      }

      return;
    } else {
      await interaction.respond(MessageBuilder(content: "Command not found"));
      return;
    }
  }
}

Future<void> startService() async {
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

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter taskStarter) async {
    // Initialiser le client Discord
    developer.log("Starting Discord bot", name: "DiscordBotTaskHandler");
    final token = await FlutterForegroundTask.getData<String>(key: "token");
    if (token != null) {
      try {
        appManager = AppManager();
        developer.log("Token: $token", name: "DiscordBotTaskHandler");
        final gateway = await Nyxx.connectGateway(
          token,
          GatewayIntents.allUnprivileged,
          options: GatewayClientOptions(
            loggerName: "CardiaKexa",
            plugins: [Logging(logLevel: Level.ALL)],
          ),
        );
        gateway.onReady.listen((event) async {
          isReady = true;
          gateway.onInteractionCreate.listen((event) async {
            // Traiter les interactions
            await handleLocalCommands(event, appManager);
          });
        });

        client = gateway;
      } catch (e) {
        developer.log(
          "Failed to connect to Discord: $e",
          name: "DiscordBotTaskHandler",
        );
      }
    } else {
      developer.log("Token not found", name: "DiscordBotTaskHandler");
    }
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == "stop") {
      stopCallback();
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await client?.close();
    client = null;
    if (isTimeout) {
      // let's restart the service
      developer.log("Service timeout", name: "DiscordBotTaskHandler");
      await startService();
    } else {
      developer.log("Service stopped", name: "DiscordBotTaskHandler");
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
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
