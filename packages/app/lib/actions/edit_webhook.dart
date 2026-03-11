import 'package:nyxx/nyxx.dart';

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

Future<Map<String, String>> editWebhookAction(
  NyxxGateway client, {
  required Map<String, dynamic> payload,
}) async {
  try {
    final ref = _extractWebhookRef(payload);
    if (ref.id == null) {
      return {'error': 'Missing webhookId (or webhookUrl)', 'webhookId': ''};
    }

    final name = payload['name']?.toString().trim();
    final channelId = _toSnowflake(payload['channelId']);
    final auditLogReason = payload['reason']?.toString().trim();

    final updated = await client.webhooks.update(
      ref.id!,
      WebhookUpdateBuilder(
        name: (name != null && name.isNotEmpty) ? name : null,
        channelId: channelId,
      ),
      token: (ref.token != null && ref.token!.isNotEmpty) ? ref.token : null,
      auditLogReason:
          (auditLogReason != null && auditLogReason.isNotEmpty)
              ? auditLogReason
              : null,
    );

    return {
      'webhookId': updated.id.toString(),
      'name': updated.name ?? '',
      'url': (updated.url ?? '').toString(),
    };
  } catch (error) {
    return {'error': 'Failed to edit webhook: $error', 'webhookId': ''};
  }
}
