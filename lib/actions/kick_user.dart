import 'package:nyxx/nyxx.dart';

Snowflake? _toSnowflake(dynamic value) {
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    return null;
  }
  return Snowflake(parsed);
}

Future<Map<String, String>> kickUserAction(
  NyxxGateway client, {
  required Snowflake? guildId,
  required Map<String, dynamic> payload,
}) async {
  try {
    if (guildId == null) {
      return {'error': 'Missing guildId', 'userId': ''};
    }

    final userId = _toSnowflake(payload['userId']);
    if (userId == null) {
      return {'error': 'Missing or invalid userId', 'userId': ''};
    }

    final reason = payload['reason']?.toString().trim();
    final guild = await client.guilds.get(guildId);
    await guild.members[userId].delete(
      auditLogReason:
          (reason != null && reason.isNotEmpty)
              ? reason
              : 'Kick via BotCreator action',
    );

    return {'userId': userId.toString()};
  } catch (error) {
    return {'error': 'Failed to kick user: $error', 'userId': ''};
  }
}
