import 'package:nyxx/nyxx.dart';

Snowflake? _toSnowflake(dynamic value) {
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    return null;
  }
  return Snowflake(parsed);
}

Future<Map<String, String>> pinMessageAction(
  NyxxGateway client, {
  required Map<String, dynamic> payload,
  required Snowflake? fallbackChannelId,
}) async {
  try {
    final channelId = _toSnowflake(payload['channelId']) ?? fallbackChannelId;
    final messageId = _toSnowflake(payload['messageId']);
    if (channelId == null || messageId == null) {
      return {'error': 'Missing channelId/messageId', 'messageId': ''};
    }

    final channel = await client.channels.get(channelId);
    if (channel is! TextChannel) {
      return {'error': 'Channel is not a text channel', 'messageId': ''};
    }

    final message = await channel.messages.fetch(messageId);
    final reason = payload['reason']?.toString().trim();
    await message.pin(
      auditLogReason:
          (reason != null && reason.isNotEmpty)
              ? reason
              : 'Pin via BotCreator action',
    );

    return {'messageId': message.id.toString(), 'status': 'pinned'};
  } catch (error) {
    return {'error': 'Failed to pin message: $error', 'messageId': ''};
  }
}
