import 'dart:convert';

import 'package:nyxx/nyxx.dart';

Snowflake? _toSnowflake(dynamic value) {
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    return null;
  }
  return Snowflake(parsed);
}

Map<String, dynamic> _toSimpleWebhook(Webhook webhook) {
  return {
    'id': webhook.id.toString(),
    'name': webhook.name,
    'channelId': webhook.channelId?.toString(),
    'guildId': webhook.guildId?.toString(),
    'type': webhook.type.value,
    'url': webhook.url,
    'hasToken': webhook.token != null,
  };
}

Future<Map<String, String>> listWebhooksAction(
  NyxxGateway client, {
  required Map<String, dynamic> payload,
  required Snowflake? fallbackChannelId,
  required Snowflake? fallbackGuildId,
}) async {
  try {
    final channelId = _toSnowflake(payload['channelId']) ?? fallbackChannelId;
    final guildId = _toSnowflake(payload['guildId']) ?? fallbackGuildId;

    List<Webhook> webhooks;
    if (channelId != null) {
      webhooks = await client.webhooks.fetchChannelWebhooks(channelId);
    } else if (guildId != null) {
      webhooks = await client.webhooks.fetchGuildWebhooks(guildId);
    } else {
      return {
        'error': 'Missing channelId/guildId',
        'webhooks': jsonEncode(<Map<String, dynamic>>[]),
      };
    }

    final encoded = jsonEncode(webhooks.map(_toSimpleWebhook).toList());
    return {'webhooks': encoded, 'count': webhooks.length.toString()};
  } catch (error) {
    return {
      'error': 'Failed to list webhooks: $error',
      'webhooks': jsonEncode(<Map<String, dynamic>>[]),
    };
  }
}
