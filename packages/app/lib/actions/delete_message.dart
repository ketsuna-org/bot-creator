import 'package:nyxx/nyxx.dart';

Future<Map<String, String>> deleteMessage(
  NyxxGateway client,
  Snowflake channelId, {
  required int count,
  String onlyThisUserID = '',
  Snowflake? beforeMessageId,
  bool deleteItself = false,
  Snowflake? commandMessageId,
}) async {
  try {
    if (count <= 0) {
      return {"error": "Count must be greater than 0", "count": "0"};
    }

    if (count > 100) {
      return {"error": "Count must be less than or equal to 100", "count": "0"};
    }
    final channel = await client.channels.get(channelId);
    if (channel is! TextChannel) {
      return {"error": "Channel is not a text channel", "count": "0"};
    }

    final messages = await channel.messages.fetchMany(
      limit: count,
      before: beforeMessageId,
    );

    if (messages.isEmpty) {
      return {"count": "0"};
    }

    List<Snowflake> deletedMessages = [];
    int deletedOlderThan14Days = 0;
    for (final message in messages) {
      if (onlyThisUserID.isNotEmpty &&
          message.author.id.toString() != onlyThisUserID) {
        continue;
      }
      if (!deleteItself &&
          commandMessageId != null &&
          message.id == commandMessageId) {
        continue;
      }
      if (!deleteItself &&
          beforeMessageId != null &&
          message.id == beforeMessageId) {
        continue;
      }
      if (message.timestamp.isBefore(
        DateTime.now().subtract(Duration(days: 14)),
      )) {
        await message.delete();
        deletedOlderThan14Days++;
        continue;
      }
      deletedMessages.add(message.id);
    }

    if (deleteItself && beforeMessageId != null) {
      try {
        final selfMessage = await channel.messages.fetch(beforeMessageId);
        await selfMessage.delete();
        deletedOlderThan14Days++;
      } catch (e) {
        // Ignore error if message cannot be found or deleted
      }
    }

    if (deletedMessages.isNotEmpty) {
      await channel.messages.bulkDelete(deletedMessages);
    }

    final totalDeleted = deletedMessages.length + deletedOlderThan14Days;
    return {"count": totalDeleted.toString()};
  } catch (e) {
    return {"error": "Failed to delete messages: $e", "count": "0"};
  }
}
