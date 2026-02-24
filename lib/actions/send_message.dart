import 'package:nyxx/nyxx.dart';

Future<Map<String, String>> sendMessageToChannel(
  NyxxGateway client,
  Snowflake channelId, {
  required String content,
}) async {
  try {
    final channel = await client.channels.get(channelId);
    if (channel is! TextChannel) {
      return {'error': 'Channel is not a text channel', 'messageId': ''};
    }

    final message = await channel.sendMessage(MessageBuilder(content: content));
    return {'messageId': message.id.toString()};
  } catch (e) {
    return {'error': 'Failed to send message: $e', 'messageId': ''};
  }
}
