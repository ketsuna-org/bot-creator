import 'package:nyxx/nyxx.dart';

Snowflake? _toSnowflake(dynamic value) {
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    return null;
  }
  return Snowflake(parsed);
}

bool? _toBool(dynamic value) {
  if (value is bool) {
    return value;
  }
  final text = value?.toString().trim().toLowerCase();
  if (text == 'true') {
    return true;
  }
  if (text == 'false') {
    return false;
  }
  return null;
}

Duration? _parseDuration(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return Duration(seconds: value.toInt());
  }

  final text = value.toString().trim();
  if (text.isEmpty) {
    return null;
  }

  final asInt = int.tryParse(text);
  if (asInt != null) {
    return Duration(seconds: asInt);
  }

  final match = RegExp(r'^(\d+)\s*([smhd])$').firstMatch(text.toLowerCase());
  if (match == null) {
    return null;
  }

  final amount = int.parse(match.group(1)!);
  final unit = match.group(2)!;
  switch (unit) {
    case 's':
      return Duration(seconds: amount);
    case 'm':
      return Duration(minutes: amount);
    case 'h':
      return Duration(hours: amount);
    case 'd':
      return Duration(days: amount);
    default:
      return null;
  }
}

Future<Map<String, String>> updateChannelAction(
  NyxxGateway client, {
  required Map<String, dynamic> payload,
}) async {
  try {
    final channelId = _toSnowflake(payload['channelId']);
    if (channelId == null) {
      return {'error': 'Missing or invalid channelId', 'channelId': ''};
    }

    final channel = await client.channels.get(channelId);

    final name = payload['name']?.toString().trim();
    final topic = payload['topic']?.toString();
    final nsfw = _toBool(payload['nsfw']);
    final slowmode = _parseDuration(payload['slowmode']);

    if (channel is GuildTextChannel) {
      await channel.update(
        GuildTextChannelUpdateBuilder(
          name: (name != null && name.isNotEmpty) ? name : null,
          topic: topic,
          isNsfw: nsfw,
          rateLimitPerUser: slowmode,
        ),
      );
    } else if (channel is GuildAnnouncementChannel) {
      await channel.update(
        GuildAnnouncementChannelUpdateBuilder(
          name: (name != null && name.isNotEmpty) ? name : null,
          topic: topic,
          isNsfw: nsfw,
        ),
      );
    } else if (channel is ForumChannel) {
      await channel.update(
        ForumChannelUpdateBuilder(
          name: (name != null && name.isNotEmpty) ? name : null,
          topic: topic,
          isNsfw: nsfw,
          rateLimitPerUser: slowmode,
        ),
      );
    } else if (channel is GuildVoiceChannel) {
      await channel.update(
        GuildVoiceChannelUpdateBuilder(
          name: (name != null && name.isNotEmpty) ? name : null,
          isNsfw: nsfw,
        ),
      );
    } else if (channel is GuildStageChannel) {
      await channel.update(
        GuildStageChannelUpdateBuilder(
          name: (name != null && name.isNotEmpty) ? name : null,
          isNsfw: nsfw,
        ),
      );
    } else if (channel is GuildCategory) {
      await channel.update(
        GuildCategoryUpdateBuilder(
          name: (name != null && name.isNotEmpty) ? name : null,
        ),
      );
    } else if (channel is GuildChannel) {
      await channel.update(
        GuildChannelUpdateBuilder<GuildChannel>(
          name: (name != null && name.isNotEmpty) ? name : null,
        ),
      );
    } else {
      return {
        'error': 'Unsupported channel type for update: ${channel.runtimeType}',
        'channelId': '',
      };
    }

    return {'channelId': channelId.toString(), 'status': 'updated'};
  } catch (error) {
    return {'error': 'Failed to update channel: $error', 'channelId': ''};
  }
}
