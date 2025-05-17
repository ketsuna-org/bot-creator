import 'package:cardia_kexa/main.dart';
import 'package:cardia_kexa/utils/database.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:nyxx/nyxx.dart';
import 'dart:developer' as developer;
import 'package:cardia_kexa/utils/global.dart';

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

      // extract the "reply" from the "data" field
      final value = action["data"];
      if (value != null) {
        String response = value["response"] ?? "No response found";
        response = updateString(response, listOfArgs);
        await interaction.respond(MessageBuilder(content: response));
      } else {
        await interaction.respond(MessageBuilder(content: "No data found"));
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
        gateway.onReady.listen((event) {
          isReady = true;
          developer.log("Bot is ready", name: "DiscordBotTaskHandler");
          gateway.onInteractionCreate.listen((event) async {
            // Traiter les interactions
            await handleLocalCommands(event, appManager);
            if (event.interaction is ApplicationCommandInteraction) {
              appManager.saveLog(
                gateway.user.id.toString(),
                "Command ${event.interaction.data.name} executed by ${event.interaction.user?.username}",
              );
            }
            appManager.saveLog(
              gateway.user.id.toString(),
              "Interaction ${event.interaction.data.name} received",
            );
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
