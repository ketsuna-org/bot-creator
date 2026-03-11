import 'package:nyxx/nyxx.dart';

Snowflake? _toSnowflake(dynamic value) {
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    return null;
  }
  return Snowflake(parsed);
}

Future<Map<String, String>> unmuteUserAction(
  NyxxGateway client, {
  required Snowflake? guildId,
  required Map<String, dynamic> payload,
}) async {
  try {
    if (guildId == null) {
      return {'error': 'Missing guildId', 'userId': ''};
    }

    final userId =
        _toSnowflake(payload['userId']) ?? _toSnowflake(payload['memberId']);
    if (userId == null) {
      return {'error': 'Missing or invalid userId/memberId', 'userId': ''};
    }

    final reason = payload['reason']?.toString().trim();
    final guild = await client.guilds.get(guildId);
    final member = await guild.members[userId].update(
      MemberUpdateBuilder(communicationDisabledUntil: null),
      auditLogReason:
          (reason != null && reason.isNotEmpty)
              ? reason
              : 'Remove timeout via BotCreator action',
    );

    return {'userId': member.id.toString(), 'status': 'unmuted'};
  } catch (error) {
    return {'error': 'Failed to unmute user: $error', 'userId': ''};
  }
}
