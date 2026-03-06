import 'package:nyxx/nyxx.dart';

Future<Map<String, String>> createChannel(
  NyxxGateway client,
  String name, {
  required Snowflake guildId,
  ChannelType type = ChannelType.guildText,
}) async {
  try {
    final guild = await client.guilds.get(guildId);

    GuildChannelBuilder channelBuilder = GuildChannelBuilder(
      name: name,
      type: type,
    );
    final channel = await guild.createChannel(channelBuilder);

    return {"channelId": channel.id.toString()};
  } catch (e) {
    return {"error": "Failed to create channel: $e", "channelId": ""};
  }
}
