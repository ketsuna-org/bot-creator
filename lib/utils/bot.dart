import 'package:cardia_kexa/main.dart';
import 'package:cbl/cbl.dart';
import 'package:nyxx/nyxx.dart';

Future<void> handleLocalCommands(InteractionCreateEvent event) async {
  final interaction = event.interaction;
  if (interaction is ApplicationCommandInteraction) {
    final command = interaction.data;
    final action = await appManager.getCommand(command.id.toString());

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
