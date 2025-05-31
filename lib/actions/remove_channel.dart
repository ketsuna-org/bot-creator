import 'package:nyxx/nyxx.dart';

Future<Map<String, String>> createChannel(
  NyxxGateway client,
  Snowflake channelId,
) async {
  try {
    final channel = await client.channels.get(channelId);

    await channel.delete();

    return {"channelId": channel.id.toString()};
  } catch (e) {
    return {"error": "Failed to delete channel: $e", "channelId": ""};
  }
}
