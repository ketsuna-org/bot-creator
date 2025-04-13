import 'package:cardia_kexa/main.dart';
import 'package:cardia_kexa/utils/database.dart';
import 'package:cbl/cbl.dart';
import 'package:cbl_flutter/cbl_flutter.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:nyxx/nyxx.dart';
import 'dart:developer' as developer;

@pragma('vm:entry-point')
Future<void> handleLocalCommands(
  InteractionCreateEvent event,
  AppManager manager,
) async {
  final interaction = event.interaction;
  if (interaction is ApplicationCommandInteraction) {
    final command = interaction.data;
    final action = await manager.getCommand(command.id.toString());

    if (action == null) {
      await interaction.respond(MessageBuilder(content: "Command not found"));
      return;
    } else if (action.string("id") == command.id.toString()) {
      // extract the "reply" from the "data" field
      final value = action.value<Dictionary>("data")?.value<Dictionary>("data");
      if (value != null) {
        await interaction.respond(
          MessageBuilder(
            content: value.string("response") ?? "No response found",
          ),
        );
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
        await CouchbaseLiteFlutter.init();
        database = await Database.openAsync("cardia_kexa");
        appManager = AppManager();
        developer.log("Database opened", name: "DiscordBotTaskHandler");
        final gateway = await Nyxx.connectGateway(
          token,
          GatewayIntents.allUnprivileged,
          options: GatewayClientOptions(loggerName: "CardiaKexa"),
        );
        gateway.onReady.listen((event) {
          isReady = true;
          appManager.addLog(
            "Gateway is ready: ${event.user.username}",
            gateway.user.id.toString(),
          );
        });
        gateway.onInteractionCreate.listen((event) async {
          // Traiter les interactions
          await handleLocalCommands(event, appManager);
          // retrieve the user
          final user = event.interaction.member?.user;
          if (user != null) {
            // gather the interaction Name
            final interactionName = event.interaction.data?.name;
            appManager.addLog(
              "Interaction $interactionName invoked by ${user.username}",
              gateway.user.id.toString(),
            );
          } else {
            appManager.addLog(
              "Interaction invoked by unknown user",
              gateway.user.id.toString(),
            );
          }
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
  Future<void> onDestroy(DateTime timestamp) async {
    await client?.close();
    client = null;
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // TODO: implement onRepeatEvent
  }
}

Future<void> createCommand(
  NyxxRest client,
  String name,
  String description, {
  Map<String, dynamic> data = const {},
}) async {
  final commandBuilder = ApplicationCommandBuilder(
    name: name,
    description: description,
    type: ApplicationCommandType.chatInput,
  );
  try {
    final command = await client.commands.create(commandBuilder);
    Map<String, dynamic> commandData = {
      "name": command.name,
      "description": command.description,
      "id": command.id.toString(),
      "applicationId": command.applicationId.toString(),
      "createdAt": DateTime.now().toIso8601String(),
    };
    if (data.isNotEmpty) {
      commandData["data"] = data;
    }
    appManager.addCommand(command.id.toString(), commandData);
  } catch (e) {
    throw Exception("Failed to create command: $e");
  }
}

Future<void> updateCommand(
  NyxxRest client,
  Snowflake commandId, {
  String name = "",
  String description = "",
  Map<String, dynamic> data = const {},
}) async {
  // let's check what we are gonna update
  if (name.isEmpty && description.isEmpty) {
    throw Exception("Name and description cannot be empty");
  }
  final commandBuilder = ApplicationCommandUpdateBuilder();
  if (name.isNotEmpty) {
    commandBuilder.name = name;
  }
  if (description.isNotEmpty) {
    commandBuilder.description = description;
  }
  try {
    final command = await client.commands.update(commandId, commandBuilder);
    Map<String, dynamic> commandData = {
      "name": command.name,
      "description": command.description,
      "id": command.id.toString(),
      "applicationId": command.applicationId.toString(),
      "updatedAt": DateTime.now().toIso8601String(),
    };

    if (data.isNotEmpty) {
      commandData["data"] = data;
    }
    appManager.updateCommand(commandId.toString(), commandData);
  } catch (e) {
    throw Exception("Failed to update command: $e");
  }
}
