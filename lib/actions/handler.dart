import 'package:bot_creator/actions/create_channel.dart';
import 'package:bot_creator/actions/delete_message.dart';
import 'package:bot_creator/actions/list.dart';
import 'package:bot_creator/actions/remove_channel.dart';
import 'package:bot_creator/actions/send_message.dart';
import 'package:nyxx/nyxx.dart';
import '../types/action.dart';

Snowflake? _toSnowflake(dynamic value) {
  if (value == null) {
    return null;
  }

  final parsed = int.tryParse(value.toString());
  if (parsed == null) {
    return null;
  }

  return Snowflake(parsed);
}

Future<Map<String, String>> handleActions(
  NyxxGateway client,
  ApplicationCommandInteraction interaction, {
  required List<Action> actions,
}) async {
  final results = <String, String>{};
  final fallbackChannelId = interaction.channel?.id;
  final guildId = interaction.guildId;

  for (var i = 0; i < actions.length; i++) {
    final action = actions[i];
    if (!action.enabled) {
      continue;
    }

    final resultKey = action.key ?? 'action_$i';

    try {
      switch (action.type) {
        case BotCreatorActionType.deleteMessages:
          final channelId =
              _toSnowflake(action.payload['channelId']) ?? fallbackChannelId;
          if (channelId == null) {
            throw Exception('Missing or invalid channelId for deleteMessages');
          }

          final result = await deleteMessage(
            client,
            channelId,
            count: action.payload['messageCount'] ?? 0,
            onlyThisUserID: action.payload['onlyUserId']?.toString() ?? '',
          );
          if (result['error'] != null) {
            throw Exception(result['error']);
          }
          results[resultKey] = result['count'] ?? '0';
          break;
        case BotCreatorActionType.createChannel:
          if (guildId == null) {
            throw Exception('This action requires a guild context');
          }

          final typeRaw = (action.payload['type'] ?? 'text').toString();
          final channelType =
              typeRaw == 'voice'
                  ? ChannelType.guildVoice
                  : ChannelType.guildText;
          final result = await createChannel(
            client,
            (action.payload['name'] ?? '').toString(),
            guildId: guildId,
            type: channelType,
          );
          if (result['error'] != null) {
            throw Exception(result['error']);
          }
          results[resultKey] = result['channelId'] ?? '';
          break;
        case BotCreatorActionType.removeChannel:
          final channelId = _toSnowflake(action.payload['channelId']);
          if (channelId == null) {
            throw Exception('Missing or invalid channelId for removeChannel');
          }

          final result = await removeChannel(client, channelId);
          if (result['error'] != null) {
            throw Exception(result['error']);
          }
          results[resultKey] = result['channelId'] ?? '';
          break;
        case BotCreatorActionType.sendMessage:
          final channelId =
              _toSnowflake(action.payload['channelId']) ?? fallbackChannelId;
          if (channelId == null) {
            throw Exception('Missing or invalid channelId for sendMessage');
          }

          final content = (action.payload['content'] ?? '').toString();
          if (content.trim().isEmpty) {
            throw Exception('content is required for sendMessage');
          }

          final result = await sendMessageToChannel(
            client,
            channelId,
            content: content,
          );
          if (result['error'] != null) {
            throw Exception(result['error']);
          }
          results[resultKey] = result['messageId'] ?? '';
          break;
        case BotCreatorActionType.makeList:
          final result = formatList(
            action.payload['list'] ?? [],
            action.payload['format']?.toString() ?? '',
          );
          results[resultKey] = result.toString();
          break;

        // Add more cases for other action types as needed
        default:
          results[resultKey] = 'Unsupported action type';
      }
    } catch (e) {
      results[resultKey] = 'Error: $e';
      if (action.onErrorMode == ActionOnErrorMode.stop) {
        break;
      }
    }
  }
  return results;
}
