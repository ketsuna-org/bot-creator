import 'package:nyxx/nyxx.dart';

Snowflake? _toSnowflake(dynamic value) {
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    return null;
  }
  return Snowflake(parsed);
}

Future<Map<String, String>> banUserAction(
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
    final deleteDaysRaw = int.tryParse(
      (payload['deleteMessageDays'] ?? '0').toString(),
    );
    final deleteDays = (deleteDaysRaw ?? 0).clamp(0, 7);

    final guild = await client.guilds.get(guildId);
    await guild.createBan(
      userId,
      deleteMessages:
          deleteDays > 0 ? Duration(days: deleteDays) : Duration.zero,
      auditLogReason:
          (reason != null && reason.isNotEmpty)
              ? reason
              : 'Ban via BotCreator action',
    );

    return {'userId': userId.toString()};
  } catch (error) {
    return {'error': 'Failed to ban user: $error', 'userId': ''};
  }
}
