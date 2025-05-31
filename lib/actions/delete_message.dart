import 'package:nyxx/nyxx.dart';

Future<Map<String, String>> deleteMessage(
  NyxxGateway client,
  Snowflake channelId, {
  required int count,
  String onlyThisUserID = '',
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
      before: null, // You can specify a message ID to fetch messages before it
    );

    if (messages.isEmpty) {
      return {"count": "0"};
    }

    List<Snowflake> deletedMessages = [];
    int deletedOlderThan14Days = 0;
    for (final message in messages) {
      if (onlyThisUserID.isNotEmpty &&
          message.author.id.toString() != onlyThisUserID) {
        continue; // Skip messages not from the specified user
      }
      if (message.timestamp.isBefore(
        DateTime.now().subtract(Duration(days: 14)),
      )) {
        await message.delete();
        deletedOlderThan14Days++;
        continue; // Skip messages older than 14 days
      }
      deletedMessages.add(message.id);
    }

    if (deletedMessages.isEmpty) {
      return {"count": "0"};
    }

    await channel.messages.bulkDelete(deletedMessages);
    return {
      "count": (deletedMessages.length - deletedOlderThan14Days).toString(),
    };
  } catch (e) {
    return {"error": "Failed to delete messages: $e", "count": "0"};
  }
}
