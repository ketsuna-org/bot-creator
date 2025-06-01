import 'package:bot_creator/actions/delete_message.dart';
import 'package:bot_creator/actions/list.dart';
import 'package:nyxx/nyxx.dart';
import '../types/action.dart';

Future<Map<String, String>> handleActions(
  NyxxGateway client,
  Snowflake channelId, {
    required List<Action> actions,
  }) async {
  final results = <String, String>{};
  for (final action in actions) {
    try {
      switch (action.type) {
        case BotCreatorActionType.deleteMessages:
          final result = await deleteMessage(
            client,
            channelId,
            count: action.payload['count'] ?? 0,
            onlyThisUserID: action.payload['only_this_user_id'] ?? '',
          );
          results[action.key ?? 'deleteMessage'] = result['count'] ?? '0';
          break;
        case BotCreatorActionType.makeList:
          final result = formatList(
            action.payload['list'] ?? [],
            action.payload['format'] ?? '',
          );


        // Add more cases for other action types as needed
        default:
          results[action.key ?? action.type.name] = 'Unsupported action type';
      }
    } catch (e) {
      results[action.key ?? action.type.name] = 'Error: $e';
    }
  }
  return results;
}
