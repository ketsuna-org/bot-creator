import 'package:nyxx/nyxx.dart';
import 'dart:convert';

Snowflake? _toSnowflake(dynamic value) {
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    return null;
  }
  return Snowflake(parsed);
}

({Snowflake? id, String? token}) _extractWebhookRef(
  Map<String, dynamic> payload,
) {
  final directId = _toSnowflake(payload['webhookId']);
  final directToken = payload['token']?.toString().trim();

  final rawUrl = payload['webhookUrl']?.toString().trim() ?? '';
  final uri = Uri.tryParse(rawUrl);
  if (uri == null) {
    return (id: directId, token: directToken);
  }

  final segments = uri.pathSegments;
  final webhooksIndex = segments.indexOf('webhooks');
  if (webhooksIndex == -1 || webhooksIndex + 2 >= segments.length) {
    return (id: directId, token: directToken);
  }

  final parsedId = _toSnowflake(segments[webhooksIndex + 1]);
  final parsedToken = segments[webhooksIndex + 2].trim();

  return (
    id: parsedId ?? directId,
    token: parsedToken.isNotEmpty ? parsedToken : directToken,
  );
}

Future<Map<String, String>> getWebhookAction(
  NyxxGateway client, {
  required Map<String, dynamic> payload,
}) async {
  try {
    final ref = _extractWebhookRef(payload);
    if (ref.id == null) {
      return {'error': 'Missing webhookId (or webhookUrl)', 'webhook': ''};
    }

    final webhook = await client.webhooks.fetch(
      ref.id!,
      token: (ref.token != null && ref.token!.isNotEmpty) ? ref.token : null,
    );

    return {
      'webhook': jsonEncode({
        'id': webhook.id.toString(),
        'name': webhook.name,
        'channelId': webhook.channelId?.toString(),
        'guildId': webhook.guildId?.toString(),
        'type': webhook.type.value,
        'url': webhook.url,
        'hasToken': webhook.token != null,
      }),
      'webhookId': webhook.id.toString(),
    };
  } catch (error) {
    return {'error': 'Failed to get webhook: $error', 'webhook': ''};
  }
}
