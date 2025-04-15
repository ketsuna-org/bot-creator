import 'package:nyxx/nyxx.dart';
import 'dart:developer' as developer;

const String discordUrl = "https://discord.com/api/v10";

Future<User> getDiscordUser(String botToken) async {
  try {
    final client = await Nyxx.connectRest(botToken);
    return await client.user.fetch();
  } catch (e) {
    throw Exception("Failed to fetch user: $e");
  }
}

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

  if (avatarId == "0") {
    if (discriminator != null) {
      return "https://cdn.discordapp.com/embed/avatars/${int.parse(discriminator) % 5}.png";
    }
    return "https://cdn.discordapp.com/embed/avatars/${(int.parse(userId) >> 22) % 6}.png";
  }
  return "https://cdn.discordapp.com/avatars/$userId/$avatarId.$legacyFormat?size=1024";
}

String makeGuildIcon(String guildId, String? iconId) {
  if (guildId == "DM" || iconId == null || iconId.isEmpty) {
    return "https://cdn.discordapp.com/embed/avatars/0.png";
  }
  return "https://cdn.discordapp.com/icons/$guildId/$iconId.webp?size=1024";
}

Future<Map<String, String>> generateKeyValues(
  ApplicationCommandInteraction interaction,
) async {
  PartialGuild? guild = interaction.guild;
  try {
    guild =
        (await interaction.guild?.fetch(withCounts: true) ?? interaction.guild!)
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
  final guildName = (guild is Guild) ? guild.name : "DM";
  final userName = user?.user?.username ?? "Unknown User";
  final guildCount = (guild is Guild) ? guild.approximateMemberCount : 0;
  String channelName = getChannelName(channel);
  String channelType = channel is Channel ? channel.type.toString() : "DM";

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
    "userName": userName,
    "userId": user?.id.toString() ?? "Unknown User",
    "userUsername": user?.user?.username ?? "Unknown User",
    "userTag": user?.user?.discriminator ?? "Unknown User",
    "userAvatar": userAvatarUrl,
    "guildName": guildName,
    "channelName": channelName,
    "channelType": channelType,
    "guildIcon": makeGuildIcon(
      guild?.id.toString() ?? "DM",
      (guild is Guild) ? guild.icon?.hash : null,
    ),
    "guildId": guild?.id.toString() ?? "DM",
    "channelId": channel?.id.toString() ?? "DM",
    "guildCount": guildCount.toString(),
  };
  final command = interaction.data;
  listOfArgs["commandName"] = command.name;
  listOfArgs["commandId"] = command.id.toString();
  if (interaction.data.options is List<InteractionOption>) {
    final options = interaction.data.options as List<InteractionOption>;
    for (final option in options) {
      if (option.type == CommandOptionType.subCommand) {
        listOfArgs[option.name] = option.value.toString();
        final subOptions = option.options as List<InteractionOption>;
        for (final subOption in subOptions) {
          final subKeyValues = await generateKeyValuesFromInteractionOption(
            subOption,
            interaction,
          );
          // let's prefix them with opts to avoid conflicts
          // with other keys
          for (final entry in subKeyValues.entries) {
            listOfArgs["opts.${option.name}.${entry.key}"] = entry.value;
          }
        }
      } else if (option.type == CommandOptionType.subCommandGroup) {
        listOfArgs[option.name] = option.value.toString();
        final subCommandsOptions = option.options as List<InteractionOption>;
        for (final subCommandOption in subCommandsOptions) {
          final subOptions =
              subCommandOption.options as List<InteractionOption>;
          for (final subOption in subOptions) {
            final subKeyValues = await generateKeyValuesFromInteractionOption(
              subOption,
              interaction,
            );
            // let's prefix them with opts to avoid conflicts
            // with other keys
            for (final entry in subKeyValues.entries) {
              listOfArgs["opts.${option.name}.${subCommandOption.name}.${entry.key}"] =
                  entry.value;
            }
          }
        }
      } else {
        final keyValues = await generateKeyValuesFromInteractionOption(
          option,
          interaction,
        );
        // let's prefix them with opts to avoid conflicts
        // with other keys
        for (final entry in keyValues.entries) {
          listOfArgs["opts.${entry.key}"] = entry.value;
        }
      }
    }
  }
  print("List of args: $listOfArgs");
  return listOfArgs;
}

Future<Map<String, String>> generateKeyValuesFromInteractionOption(
  InteractionOption value,
  ApplicationCommandInteraction interaction,
) async {
  final client = interaction.manager.client;
  switch (value.type) {
    case CommandOptionType.string:
      return {value.name: value.value.toString()};
    case CommandOptionType.integer:
      return {value.name: value.value.toString()};
    case CommandOptionType.boolean:
      return {value.name: value.value.toString()};
    case CommandOptionType.user:
      final userId = Snowflake(int.parse(value.value.toString()));
      final user = await client.users.fetch(userId);
      return {
        value.name: user.username,
        "${value.name}.id": user.id.toString(),
        "${value.name}.avatar": makeAvatarUrl(
          user.id.toString(),
          avatarId: user.avatar.hash,
          isAnimated: user.avatar.isAnimated,
          legacyFormat: "webp",
          discriminator: user.discriminator,
        ),
      };
    case CommandOptionType.channel:
      final channelId = Snowflake(int.parse(value.value.toString()));
      final channel = await client.channels.fetch(channelId);
      return {
        value.name: getChannelName(channel),
        "${value.name}.id": channel.id.toString(),
        "${value.name}.type": channel.type.toString(),
      };
    case CommandOptionType.role:
      final role = await interaction.guild?.roles.fetch(
        value.value as Snowflake,
      );
      return {
        value.name: role?.name ?? "Unknown Role",
        "${value.name}.id": role?.id.toString() ?? "Unknown Role",
      };
    case CommandOptionType.mentionable:
      final mentionableId = Snowflake(int.parse(value.value.toString()));
      final mentionable = await client.users.fetch(mentionableId);
      return {
        value.name: mentionable.username,
        "${value.name}.id": mentionable.id.toString(),
        "${value.name}.avatar": makeAvatarUrl(
          mentionable.id.toString(),
          avatarId: mentionable.avatar.hash,
          isAnimated: mentionable.avatar.isAnimated,
          legacyFormat: "webp",
          discriminator: mentionable.discriminator,
        ),
      };
    case CommandOptionType.number:
      return {value.name: value.value.toString()};
  }
  return {value.name: value.value.toString()};
}

String getChannelName(PartialChannel? channel) {
  if (channel is GuildTextChannel) {
    return channel.name;
  } else if (channel is GuildVoiceChannel) {
    return channel.name;
  } else if (channel is ThreadsOnlyChannel) {
    return channel.name;
  } else if (channel is GuildStageChannel) {
    return channel.name;
  } else if (channel is DmChannel) {
    return "DM";
  }
  return "Unknown Channel";
}
