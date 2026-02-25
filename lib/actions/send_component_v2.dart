import 'package:nyxx/nyxx.dart';

Future<Map<String, String>> sendComponentV2Action(
  NyxxGateway client, {
  required Map<String, dynamic> payload,
  required Snowflake? fallbackChannelId,
}) async {
  return {
    'error':
        'sendComponentV2 is not implemented yet. fallbackChannelId=${fallbackChannelId?.toString() ?? 'null'} payload=${payload.keys.join(', ')}',
  };
}
