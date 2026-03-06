import 'package:nyxx/nyxx.dart';

Snowflake? _toSnowflake(dynamic value) {
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    return null;
  }
  return Snowflake(parsed);
}

Future<Map<String, String>> clearAllReactionsAction(
  NyxxGateway client, {
  required Map<String, dynamic> payload,
  required Snowflake? fallbackChannelId,
}) async {
  try {
    final channelId = _toSnowflake(payload['channelId']) ?? fallbackChannelId;
    final messageId = _toSnowflake(payload['messageId']);
    if (channelId == null || messageId == null) {
      return {'error': 'Missing channelId/messageId', 'status': ''};
    }

    final channel = await client.channels.get(channelId);
    if (channel is! TextChannel) {
      return {'error': 'Channel is not a text channel', 'status': ''};
    }

    final message = await channel.messages.fetch(messageId);
    await message.deleteAllReactions();
    return {'status': 'OK'};
  } catch (error) {
    return {'error': 'Failed to clear reactions: $error', 'status': ''};
  }
}
