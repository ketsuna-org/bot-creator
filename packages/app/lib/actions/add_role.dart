import 'package:nyxx/nyxx.dart';

Snowflake? _toSnowflake(dynamic value) {
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    return null;
  }
  return Snowflake(parsed);
}

Future<Map<String, String>> addRoleAction(
  NyxxGateway client, {
  required Snowflake? guildId,
  required Map<String, dynamic> payload,
}) async {
  try {
    if (guildId == null) {
      return {'error': 'Missing guildId', 'userId': '', 'roleId': ''};
    }

    final userId =
        _toSnowflake(payload['userId']) ?? _toSnowflake(payload['memberId']);
    if (userId == null) {
      return {
        'error': 'Missing or invalid userId/memberId',
        'userId': '',
        'roleId': '',
      };
    }

    final roleId = _toSnowflake(payload['roleId']);
    if (roleId == null) {
      return {'error': 'Missing or invalid roleId', 'userId': '', 'roleId': ''};
    }

    final reason = payload['reason']?.toString().trim();
    final guild = await client.guilds.get(guildId);
    await guild.members[userId].addRole(
      roleId,
      auditLogReason:
          (reason != null && reason.isNotEmpty)
              ? reason
              : 'Add role via BotCreator action',
    );

    return {
      'userId': userId.toString(),
      'roleId': roleId.toString(),
      'status': 'added',
    };
  } catch (error) {
    return {'error': 'Failed to add role: $error', 'userId': '', 'roleId': ''};
  }
}
