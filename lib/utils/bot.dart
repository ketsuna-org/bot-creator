import 'package:cardia_kexa/main.dart';
import 'package:cardia_kexa/utils/database.dart';
import 'package:cbl/cbl.dart';
import 'package:cbl_flutter/cbl_flutter.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:nyxx/nyxx.dart';
import 'dart:developer' as developer;

String makeAvatarUrl(
  String userId, {
  String? avatarId,
  bool isAnimated = false,
  String legacyFormat = "webp",
  String? discriminator,
}) {
  if (avatarId == null || avatarId.isEmpty) {
    if (discriminator != null) {
      return "https://cdn.discordapp.com/embed/avatars/${int.parse(discriminator) % 5}.png";
    }
    return "https://cdn.discordapp.com/embed/avatars/${(int.parse(userId) >> 22) % 6}.png";
  }
  if (isAnimated && legacyFormat == "gif") {
    return "https://cdn.discordapp.com/avatars/$userId/$avatarId.gif?size=1024";
  }
  return "https://cdn.discordapp.com/avatars/$userId/$avatarId.$legacyFormat?size=1024";
}

String makeGuildIcon(String guildId, String? iconId) {
  if (guildId == "DM" || iconId == null || iconId.isEmpty) {
    return "https://cdn.discordapp.com/embed/avatars/0.png";
  }
  return "https://cdn.discordapp.com/icons/$guildId/$iconId.webp?size=1024";
}

@pragma('vm:entry-point')
String updateString(String initial, Map<String, String> updates) {
  String result = initial;
  // Iterate through the updates and replace the placeholders in the string
  for (var entry in updates.entries) {
    String placeholder = entry.key;
    String value = entry.value;
    // Replace the placeholder with the value they will be in the form of ((key))
    // so we need to replace the key with the value
    // as we can handle complexe case where key contain dots we need to escape them
    result = result.replaceAll(
      RegExp("\\(\\($placeholder\\)\\)", caseSensitive: false),
      value,
    );
  }
  return result;
}

@pragma('vm:entry-point')
Future<void> handleLocalCommands(
  InteractionCreateEvent event,
  AppManager manager,
) async {
  final interaction = event.interaction;
  final clientId = event.gateway.client.user.id.toString();
  manager.addLog("Interaction ${interaction.data.name} invoked", clientId);
  if (interaction is ApplicationCommandInteraction) {
    final command = interaction.data;
    PartialGuild? guild = interaction.guild;
    try {
      guild =
          (await interaction.guild?.fetch(withCounts: true) ??
                  interaction.guild!)
              as Guild?;
    } catch (e) {
      developer.log("Failed to fetch guild: $e", name: "handleLocalCommands");
    }
    PartialChannel? channel = interaction.channel;
    try {
      channel =
          (await interaction.channel?.fetch() ?? interaction.channel!)
              as Channel?;
    } catch (e) {
      developer.log("Failed to fetch channel: $e", name: "handleLocalCommands");
    }
    Member? user = interaction.member;
    try {
      if (user != null) {
        user = await interaction.member?.fetch();
      }
    } catch (e) {
      developer.log("Failed to fetch user: $e", name: "handleLocalCommands");
    }
    manager.addLog(
      "Command ${command.name} invoked by ${user?.user?.username}",
      clientId,
    );
    final action = await manager.getCommand(command.id.toString());

    if (action == null) {
      await interaction.respond(MessageBuilder(content: "Command not found"));
      return;
    } else if (action.string("id") == command.id.toString()) {
      final commandName = action.string("name");
      final guildName = (guild is Guild) ? guild.name : "DM";
      final userName = user?.user?.username ?? "Unknown User";
      final guildCount = (guild is Guild) ? guild.approximateMemberCount : 0;
      String channelName = "Unknown Channel";
      String channelType = "Unknown Channel Type";
      if (channel is GuildTextChannel) {
        channelName = channel.name;
        channelType = channel.type.toString();
      } else if (channel is GuildVoiceChannel) {
        channelName = channel.name;
        channelType = channel.type.toString();
      } else if (channel is ThreadsOnlyChannel) {
        channelName = channel.name;
        channelType = channel.type.toString();
      } else if (channel is GuildStageChannel) {
        channelName = channel.name;
        channelType = channel.type.toString();
      } else if (channel is DmChannel) {
        channelName = "DM";
        channelType = channel.type.toString();
      }

      String userAvatarUrl = "https://cdn.discordapp.com/embed/avatars/0.png";

      if (user != null) {
        if (user.user != null) {
          final userFinal = user.user!;
          userAvatarUrl = makeAvatarUrl(
            userFinal.id.toString(),
            avatarId: userFinal.avatar.hash,
            isAnimated: userFinal.avatar.isAnimated,
            legacyFormat: "webp",
            discriminator: userFinal.discriminator,
          );
        }
      }

      Map<String, String> listOfArgs = {
        "user": userName,
        "userId": user?.id.toString() ?? "Unknown User",
        "userUsername": user?.user?.username ?? "Unknown User",
        "userTag": user?.user?.discriminator ?? "Unknown User",
        "userAvatar": userAvatarUrl,
        "guildName": guildName,
        "guild": guildName,
        "guildIcon": makeGuildIcon(
          guild?.id.toString() ?? "DM",
          (guild is Guild) ? guild.icon?.hash : null,
        ),
        "guildId": guild?.id.toString() ?? "DM",
        "channelId": channel?.id.toString() ?? "DM",
        "guildCount": guildCount.toString(),
        "commandName": commandName ?? "Unknown Command",
        "commandId": command.id.toString(),
        "channelType": channelType,
        "channelName": channelName,
      };
      // extract the "reply" from the "data" field
      final value = action.value<Dictionary>("data")?.value<Dictionary>("data");
      if (value != null) {
        String response = value.string("response") ?? "No response found";
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
  appManager.addLog(
    "Interaction ${interaction.data.name} not handled",
    clientId,
  );
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
  ApplicationCommandBuilder commandBuilder, {
  Map<String, dynamic> data = const {},
}) async {
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
