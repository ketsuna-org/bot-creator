import 'dart:convert';

import 'package:nyxx/nyxx.dart';

Snowflake? _toSnowflake(dynamic value) {
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    return null;
  }
  return Snowflake(parsed);
}

Map<String, dynamic> _memberToJson(Member member) {
  return {
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
  };
}

Future<Map<String, String>> listMembersAction(
  NyxxGateway client, {
  required Snowflake? guildId,
  required Map<String, dynamic> payload,
}) async {
  try {
    if (guildId == null) {
      return {
        'error': 'Missing guildId',
        'members': jsonEncode(<Map<String, dynamic>>[]),
      };
    }

    final guild = await client.guilds.get(guildId);

    final limitRaw = int.tryParse((payload['limit'] ?? '').toString());
    final limit = limitRaw?.clamp(1, 1000);
    final after = _toSnowflake(payload['after']);
    final query = (payload['query'] ?? '').toString().trim();

    List<Member> members;
    if (query.isNotEmpty) {
      members = await guild.members.search(query, limit: limit);
    } else {
      members = await guild.members.list(limit: limit, after: after);
    }

    final encoded = jsonEncode(members.map(_memberToJson).toList());
    return {'members': encoded, 'count': members.length.toString()};
  } catch (error) {
    return {
      'error': 'Failed to list members: $error',
      'members': jsonEncode(<Map<String, dynamic>>[]),
    };
  }
}
