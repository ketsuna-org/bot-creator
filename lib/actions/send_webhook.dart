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

  if (directId != null && directToken != null && directToken.isNotEmpty) {
    return (id: directId, token: directToken);
  }

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

Future<Map<String, String>> sendWebhookAction(
  NyxxGateway client, {
  required Map<String, dynamic> payload,
}) async {
  try {
    final ref = _extractWebhookRef(payload);
    if (ref.id == null || ref.token == null || ref.token!.isEmpty) {
      return {
        'error': 'Missing webhookId/token (or webhookUrl)',
        'messageId': '',
      };
    }

    final content = payload['content']?.toString() ?? '';
    final username = payload['username']?.toString().trim();
    final avatarUrl = payload['avatarUrl']?.toString().trim();
    final waitRaw = payload['wait'];
    final wait =
        waitRaw is bool
            ? waitRaw
            : (waitRaw?.toString().toLowerCase() == 'true');
    final threadId = _toSnowflake(payload['threadId']);

    final message = await client.webhooks.execute(
      ref.id!,
      MessageBuilder(content: content),
      token: ref.token!,
      wait: wait,
      threadId: threadId,
      username: (username != null && username.isNotEmpty) ? username : null,
      avatarUrl: (avatarUrl != null && avatarUrl.isNotEmpty) ? avatarUrl : null,
    );

    return {
      'messageId': message?.id.toString() ?? '',
      'webhookId': ref.id.toString(),
      'status': wait ? 'sent' : 'queued',
    };
  } catch (error) {
    return {'error': 'Failed to send webhook message: $error', 'messageId': ''};
  }
}
