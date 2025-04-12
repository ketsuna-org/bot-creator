import 'package:cardia_kexa/main.dart';
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
      await interaction.respond(MessageBuilder(content: "Command found"));
    } else {
      await interaction.respond(MessageBuilder(content: "Command not found"));
    }
    return;
  }
}

Future<void> createCommand(
  NyxxRest client,
  String name,
  String description,
) async {
  final commandBuilder = ApplicationCommandBuilder(
    name: name,
    description: description,
    type: ApplicationCommandType.chatInput,
  );
  try {
    final command = await client.commands.create(commandBuilder);
    appManager.addCommand(command.id.toString(), {
      "name": command.name,
      "description": command.description,
      "id": command.id.toString(),
      "applicationId": command.applicationId.toString(),
      "createdAt": DateTime.now().toIso8601String(),
    });
  } catch (e) {
    throw Exception("Failed to create command: $e");
  }
}

Future<void> updateCommand(
  NyxxRest client,
  Snowflake commandId, {
  String name = "",
  String description = "",
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
    appManager.updateCommand(commandId.toString(), {
      "name": name,
      "description": description,
      "id": commandId.toString(),
      "applicationId": command.applicationId.toString(),
      "updatedAt": DateTime.now().toIso8601String(),
    });
  } catch (e) {
    throw Exception("Failed to update command: $e");
  }
}
