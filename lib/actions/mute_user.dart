import 'package:nyxx/nyxx.dart';

Snowflake? _toSnowflake(dynamic value) {
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    return null;
  }
  return Snowflake(parsed);
}

Duration _resolveMuteDuration(Map<String, dynamic> payload) {
  final seconds = int.tryParse((payload['durationSeconds'] ?? '').toString());
  if (seconds != null) {
    return Duration(seconds: seconds);
  }

  final minutes = int.tryParse((payload['durationMinutes'] ?? '').toString());
  if (minutes != null) {
    return Duration(minutes: minutes);
  }

  final hours = int.tryParse((payload['durationHours'] ?? '').toString());
  if (hours != null) {
    return Duration(hours: hours);
  }

  final generic = int.tryParse((payload['duration'] ?? '').toString());
  if (generic != null) {
    return Duration(seconds: generic);
  }

  return const Duration(minutes: 10);
}

Future<Map<String, String>> muteUserAction(
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

    final now = DateTime.now().toUtc();
    DateTime? until;

    final explicitUntilRaw = payload['until']?.toString().trim();
    if (explicitUntilRaw != null && explicitUntilRaw.isNotEmpty) {
      until = DateTime.tryParse(explicitUntilRaw)?.toUtc();
      if (until == null) {
        return {'error': 'Invalid until datetime format', 'userId': ''};
      }
    }

    until ??= now.add(_resolveMuteDuration(payload));

    final maxUntil = now.add(const Duration(days: 28));
    if (until.isAfter(maxUntil)) {
      until = maxUntil;
    }
    if (!until.isAfter(now)) {
      until = now.add(const Duration(seconds: 1));
    }

    final reason = payload['reason']?.toString().trim();
    final guild = await client.guilds.get(guildId);
    final member = await guild.members[userId].update(
      MemberUpdateBuilder(communicationDisabledUntil: until),
      auditLogReason:
          (reason != null && reason.isNotEmpty)
              ? reason
              : 'Timeout via BotCreator action',
    );

    return {
      'userId': member.id.toString(),
      'until': until.toIso8601String(),
      'status': 'muted',
    };
  } catch (error) {
    return {'error': 'Failed to mute user: $error', 'userId': ''};
  }
}
