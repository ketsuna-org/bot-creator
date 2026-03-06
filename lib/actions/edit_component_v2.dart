import 'package:nyxx/nyxx.dart';

Future<Map<String, String>> editComponentV2Action(
  NyxxGateway client, {
  required Map<String, dynamic> payload,
}) async {
  return {
    'error':
        'editComponentV2 is not implemented yet. Payload received: ${payload.keys.join(', ')}',
  };
}
