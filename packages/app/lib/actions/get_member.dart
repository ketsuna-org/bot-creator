import 'dart:convert';

import 'package:nyxx/nyxx.dart';

Snowflake? _toSnowflake(dynamic value) {
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    return null;
  }
  return Snowflake(parsed);
}

Future<Map<String, String>> getMemberAction(
  NyxxGateway client, {
  required Snowflake? guildId,
  required Map<String, dynamic> payload,
}) async {
  try {
    if (guildId == null) {
      return {'error': 'Missing guildId', 'member': ''};
    }

    final userId =
        _toSnowflake(payload['userId']) ?? _toSnowflake(payload['memberId']);
    if (userId == null) {
      return {'error': 'Missing or invalid userId/memberId', 'member': ''};
    }

    final guild = await client.guilds.get(guildId);
    final member = await guild.members.fetch(userId);

    final encoded = jsonEncode({
      'id': member.id.toString(),
      'userId': member.id.toString(),
      'username': member.user?.username,
      'globalName': member.user?.globalName,
      'displayName':
          member.nick ?? member.user?.globalName ?? member.user?.username,
      'nick': member.nick,
      'joinedAt': member.joinedAt.toIso8601String(),
      'isPending': member.isPending,
      'isDeaf': member.isDeaf,
      'isMute': member.isMute,
      'roleIds': member.roleIds.map((roleId) => roleId.toString()).toList(),
      'communicationDisabledUntil':
          member.communicationDisabledUntil?.toIso8601String(),
    });

    return {'member': encoded, 'userId': member.id.toString()};
  } catch (error) {
    return {'error': 'Failed to get member: $error', 'member': ''};
  }
}
