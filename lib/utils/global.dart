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
      listOfArgs[option.name] = option.value.toString();
    }
  }

  return listOfArgs;
}
