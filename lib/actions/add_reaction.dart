import 'package:nyxx/nyxx.dart';

Snowflake? _toSnowflake(dynamic value) {
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    return null;
  }
  return Snowflake(parsed);
}

ReactionBuilder? _parseReactionBuilder(String rawEmoji) {
  final emoji = rawEmoji.trim();
  if (emoji.isEmpty) {
    return null;
  }

  final customMatch = RegExp(r'^<a?:([^:>]+):(\d+)>$').firstMatch(emoji);
  if (customMatch != null) {
    final name = customMatch.group(1)!;
    final id = int.tryParse(customMatch.group(2)!);
    if (id != null) {
      return ReactionBuilder(name: name, id: Snowflake(id));
    }
  }

  return ReactionBuilder(name: emoji, id: null);
}

Future<Map<String, String>> addReactionAction(
  NyxxGateway client, {
  required Map<String, dynamic> payload,
  required Snowflake? fallbackChannelId,
}) async {
  try {
    final channelId = _toSnowflake(payload['channelId']) ?? fallbackChannelId;
    final messageId = _toSnowflake(payload['messageId']);
    final emojiText = (payload['emoji'] ?? '').toString();

    if (channelId == null || messageId == null) {
      return {'error': 'Missing channelId/messageId', 'status': ''};
    }

    final reaction = _parseReactionBuilder(emojiText);
    if (reaction == null) {
      return {'error': 'Invalid emoji format', 'status': ''};
    }

    final channel = await client.channels.get(channelId);
    if (channel is! TextChannel) {
      return {'error': 'Channel is not a text channel', 'status': ''};
    }

    final message = await channel.messages.fetch(messageId);
    await message.react(reaction);
    return {'status': 'OK'};
  } catch (error) {
    return {'error': 'Failed to add reaction: $error', 'status': ''};
  }
}
