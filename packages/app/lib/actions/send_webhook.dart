import 'package:nyxx/nyxx.dart';
import '../types/component.dart';
import 'send_component_v2.dart';

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
  String Function(String)? resolve,
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

    List<ComponentBuilder>? components;
    bool isRichV2 = false;
    if (payload.containsKey('componentV2') && payload['componentV2'] is Map) {
      try {
        final def = ComponentV2Definition.fromJson(
          Map<String, dynamic>.from(payload['componentV2']),
        );
        isRichV2 = def.isRichV2;
        components = buildComponentNodes(
          definition: def,
          resolve: resolve ?? (s) => s,
        );
      } catch (_) {}
    }

    final message = await client.webhooks.execute(
      ref.id!,
      MessageBuilder(
        content: content.isNotEmpty ? content : null,
        components: components,
        flags: isRichV2 ? MessageFlags(32768) : null,
      ),
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
